import Foundation

// MARK: - Dependencies of projects left alone (Cleanup)

/// Finds dependency and build folders (node_modules, a Python venv, Cargo's target...) in projects nobody has touched
/// for a long time. Only inside the project folders set in Settings, never pre-selected, and only when the project
/// itself proves the folder can be rebuilt. Whenever something cannot be checked, the folder is simply not listed.
/// Sources: research/52 (official docs of npm, Python venv, Cargo, SwiftPM; how other cleaners got this wrong).
enum DevDeps {
    static var fm: FileManager { Scanner.fm }

    /// Days a project must be untouched. Stored as a real number; a missing or tiny value means the default, never "all".
    static var days: Int {
        let v = UserDefaults.standard.integer(forKey: "devStaleDays")
        return v >= 30 ? v : 180
    }

    struct Kind {
        let names: Set<String>
        /// Files beside the folder that prove the project can rebuild it: every group needs at least one present.
        let beside: [[String]]
        /// A file inside the folder that proves what it is (nil: not needed).
        let inside: String?
        let howEN: String, howVI: String
    }
    static let kinds: [Kind] = [
        // npm ci and friends rebuild node_modules from the lockfile (docs.npmjs.com/cli/commands/npm-ci).
        Kind(names: ["node_modules"], beside: [["package.json"], ["package-lock.json", "npm-shrinkwrap.json", "yarn.lock", "pnpm-lock.yaml", "bun.lock", "bun.lockb"]],
             inside: nil, howEN: "reinstall with your package manager", howVI: "cài lại bằng trình quản lý gói"),
        // A venv is disposable and should be recreated, not moved (docs.python.org/3/library/venv.html).
        Kind(names: [".venv", "venv"], beside: [["requirements.txt", "pyproject.toml", "Pipfile.lock", "poetry.lock", "uv.lock"]],
             inside: "pyvenv.cfg", howEN: "recreate the environment and reinstall", howVI: "tạo lại môi trường rồi cài lại"),
        // Cargo marks its build folder with CACHEDIR.TAG.
        Kind(names: ["target"], beside: [["Cargo.toml"]], inside: "CACHEDIR.TAG", howEN: "cargo build makes it again", howVI: "cargo build sẽ tạo lại"),
        Kind(names: [".build"], beside: [["Package.swift"]], inside: nil, howEN: "swift build makes it again", howVI: "swift build sẽ tạo lại"),
        Kind(names: [".next", ".nuxt", ".turbo"], beside: [["package.json"]], inside: nil, howEN: "the next build makes it again", howVI: "lần build sau sẽ tạo lại"),
    ]
    static let allNames: Set<String> = kinds.reduce(into: []) { $0.formUnion($1.names) }

    /// Working folders of this user's running processes (a dev server left running in a project that looks idle).
    /// nil when the list cannot be read: then nothing is listed.
    static func workingDirs() -> [String]? {
        guard let s = lsofOutput(["-a", "-d", "cwd", "-F", "n", "-u", String(getuid())]), !s.isEmpty else { return nil }
        let dirs = s.split(separator: "\n").filter { $0.hasPrefix("n/") }.map { String($0.dropFirst()) }
        // A path lsof still had to escape cannot be compared: not sure, so nothing is listed.
        if dirs.contains(where: { $0.contains("\\x") }) { return nil }
        return dirs
    }

    /// Newest change in the project outside its dependency folders, or nil when that cannot be told for sure.
    static func lastTouched(_ project: URL) -> Date? {
        var newest = Date.distantPast, seen = 0
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isDirectoryKey, .isSymbolicLinkKey]
        var failed = false
        guard let en = fm.enumerator(at: project, includingPropertiesForKeys: keys, options: [], errorHandler: { _, _ in failed = true; return true }) else { return nil }
        for case let f as URL in en {
            seen += 1
            if seen > 20_000 { return nil }   // too big to be sure
            let name = f.lastPathComponent
            guard let v = try? f.resourceValues(forKeys: Set(keys)) else { return nil }
            if v.isDirectory == true {
                if allNames.contains(name) || name == ".git" || v.isSymbolicLink == true { en.skipDescendants() }
                continue
            }
            if name == ".DS_Store" { continue }
            if let m = v.contentModificationDate, m > newest { newest = m }
        }
        if failed { return nil }
        // Git activity counts as touching the project (a commit, a checkout, a fetch).
        for g in ["HEAD", "index", "FETCH_HEAD", "ORIG_HEAD", "logs/HEAD"] {
            let u = project.appendingPathComponent(".git/" + g)
            if let m = (try? u.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate, m > newest { newest = m }
        }
        return newest == .distantPast ? nil : newest
    }

    /// Why this folder may be listed, or nil when it must not be.
    static func verdict(_ folder: URL, cwds: [String], now: Date = Date()) -> (kind: Kind, proof: String, months: Int)? {
        let project = folder.deletingLastPathComponent()
        guard let kind = kinds.first(where: { $0.names.contains(folder.lastPathComponent) }) else { return nil }
        guard (try? folder.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink != true else { return nil }
        var proof = ""
        for group in kind.beside {
            guard let hit = group.first(where: { fm.fileExists(atPath: project.appendingPathComponent($0).path) }) else { return nil }
            proof = hit
        }
        if let inside = kind.inside, !fm.fileExists(atPath: folder.appendingPathComponent(inside).path) { return nil }
        if fm.fileExists(atPath: project.appendingPathComponent(".git/index.lock").path) { return nil }   // git is working here
        let root = project.resolvingSymlinksInPath().path
        if cwds.contains(where: { $0 == root || $0.hasPrefix(root + "/") }) { return nil }               // something runs inside
        guard var touched = lastTouched(project) else { return nil }
        // The folder itself counts too: dependencies installed again yesterday mean the project is in use, even when
        // no source file changed (found in review 11/2026).
        if let v = try? folder.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey]) {
            for d in [v.creationDate, v.contentModificationDate] { if let d, d > touched { touched = d } }
        } else { return nil }
        let age = now.timeIntervalSince(touched) / 86400
        guard age >= Double(days) else { return nil }
        return (kind, proof, Int(age / 30))
    }

    /// What moving the folder to the Trash really frees. pnpm hard-links packages from its store, so those files stay
    /// on disk after the folder is gone: only files with a single link are counted.
    static func freed(_ folder: URL) -> Int64 {
        guard fm.fileExists(atPath: folder.appendingPathComponent(".pnpm").path) else { return Scanner.size(folder) }
        // pnpm shares package files with its store: hard links on most systems, APFS clones on a Mac (measured 11/2026:
        // every file had link count 1 and the same clone id as a file in ~/Library/pnpm/store). Neither frees space.
        let store = pnpmStoreIDs()
        var total: Int64 = 0
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isRegularFileKey, .linkCountKey]
        guard let en = fm.enumerator(at: folder, includingPropertiesForKeys: keys, options: [], errorHandler: { _, _ in true }) else { return 0 }
        for case let f as URL in en {
            guard let v = try? f.resourceValues(forKeys: Set(keys)), v.isRegularFile == true, (v.linkCount ?? 1) == 1 else { continue }
            if let c = Dupes.cloneID(f.path), store.contains(c) { continue }
            total += Int64(v.totalFileAllocatedSize ?? 0)
        }
        return total
    }
    private static var storeIDs: Set<UInt64>? = nil
    private static let storeLock = NSLock()
    /// Clone ids of the files in pnpm's store (its default place on macOS), read once per run; empty when there is none.
    static func pnpmStoreIDs() -> Set<UInt64> {
        storeLock.lock(); defer { storeLock.unlock() }
        if let s = storeIDs { return s }
        var ids = Set<UInt64>(), n = 0
        let root = Scanner.home.appendingPathComponent("Library/pnpm/store")
        if let en = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [], errorHandler: { _, _ in true }) {
            for case let f as URL in en {
                n += 1; if n > 600_000 { break }
                if (try? f.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true, let c = Dupes.cloneID(f.path) { ids.insert(c) }
            }
        }
        storeIDs = ids; return ids
    }

    /// Every folder with one of the known names under the project folders (hidden ones included: .venv, .build, .next).
    static func candidates(_ projects: [URL]) -> [URL] {
        var found: [URL] = []
        func walk(_ u: URL, _ d: Int) {
            guard d <= 6, !Scanner.blocked(u.path) else { return }
            for c in Scanner.children(u, hidden: true) {
                guard let v = try? c.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]), v.isDirectory == true, v.isSymbolicLink != true else { continue }
                let n = c.lastPathComponent
                if allNames.contains(n) { found.append(c) }           // never look inside one for more
                else if !n.hasPrefix(".") && n != "Library" { walk(c, d + 1) }
            }
        }
        projects.forEach { walk($0, 1) }
        return found
    }
    /// Test helper (`--devdeps <folder>`): one line per candidate, LISTED or hidden.
    static func report(_ projects: [URL]) -> String {
        guard let cwds = workingDirs() else { return "cannot read working folders: nothing is listed" }
        return candidates(projects).map { f in
            if let v = verdict(f, cwds: cwds) { return "LISTED  \(f.path)  \(v.months) months, \(v.proof), frees \(freed(f))" }
            return "hidden  \(f.path)"
        }.sorted().joined(separator: "\n")
    }

    static func scan(_ projects: [URL]) -> [CleanItem] {
        guard !projects.isEmpty, let cwds = workingDirs() else { return [] }
        let found = candidates(projects)
        var out: [CleanItem] = []
        for f in found where !Scanner.skip(f.path) {
            guard let v = verdict(f, cwds: cwds) else { continue }
            let size = freed(f)
            guard size > 0 else { continue }
            let pnpm = fm.fileExists(atPath: f.appendingPathComponent(".pnpm").path)
            let why = t("Project untouched for \(v.months) months · has \(v.proof) · \(v.kind.howEN)", "Dự án không đổi \(v.months) tháng · có \(v.proof) · \(v.kind.howVI)")
                + (!pnpm ? "" : pnpmStoreIDs().isEmpty
                    ? t(" · may share its data with a pnpm store, so less space may be freed", " · có thể dùng chung dữ liệu với kho pnpm, nên dung lượng giải phóng có thể ít hơn")
                    : t(" · size counts only what is not shared with the pnpm store", " · dung lượng chỉ tính phần không dùng chung với kho pnpm"))
            out.append(CleanItem(url: f, size: size, selected: false, reason: why))
        }
        return out.sorted { $0.size > $1.size }
    }

    // MARK: Git worktrees left behind
    // A linked worktree is a folder whose ".git" is a FILE saying "gitdir: <repo>/.git/worktrees/<name>" (git-worktree docs).
    // AI coding tools make many of them (Claude Code: <repo>/.claude/worktrees/<name>; Codex: ~/.codex/worktrees;
    // Cursor: ~/.cursor/worktrees, the last one unverified). Only the ORPHANED ones are listed: the repository no longer
    // has that entry, so git itself cannot reach the folder any more. A worktree git still knows is never shown here
    // (telling whether its work is committed and pushed needs git itself). Nothing is pre-selected: files that were
    // never committed exist only in that folder.
    static func worktreeTarget(_ folder: URL) -> String? {
        let dotGit = folder.appendingPathComponent(".git")
        guard let v = try? dotGit.resourceValues(forKeys: [.isRegularFileKey]), v.isRegularFile == true,
              let text = try? String(contentsOf: dotGit, encoding: .utf8) else { return nil }
        guard let line = text.split(whereSeparator: \.isNewline).first, line.hasPrefix("gitdir:") else { return nil }
        var path = line.dropFirst("gitdir:".count).trimmingCharacters(in: .whitespaces)
        if !path.hasPrefix("/") { path = folder.appendingPathComponent(path).standardizedFileURL.path }
        return path
    }
    /// true: orphaned and safe to show. false or nil-like cases (not a worktree, still known to git, unsure) are hidden.
    static func orphaned(_ folder: URL, cwds: [String]) -> Bool {
        guard let target = worktreeTarget(folder) else { return false }
        let parts = target.split(separator: "/").map(String.init)
        // Must be <something>/.git/worktrees/<name>: a submodule points at .git/modules/... and is not ours to judge.
        guard parts.count >= 3, parts[parts.count - 2] == "worktrees", parts[parts.count - 3] == ".git" else { return false }
        if fm.fileExists(atPath: target) { return false }                                   // git still knows it
        // The repository itself must still be where the link says. When it was renamed or moved, git may still track
        // this copy from the new place (git worktree repair); when it was deleted, this copy may be all that is left.
        // Either way nothing can be said, so it is not listed.
        let repoGit = "/" + parts.dropLast(2).joined(separator: "/")
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: repoGit, isDirectory: &isDir), isDir.boolValue else { return false }
        // The repository may sit on a drive that is not plugged in right now: then nothing can be said.
        if parts.first == "Volumes", parts.count > 1, !fm.fileExists(atPath: "/Volumes/" + parts[1]) { return false }
        let root = folder.resolvingSymlinksInPath().path
        if cwds.contains(where: { $0 == root || $0.hasPrefix(root + "/") }) { return false } // something works inside
        return true
    }
    static func worktreeCandidates(_ projects: [URL]) -> [URL] {
        var found: [URL] = []
        func walk(_ u: URL, _ d: Int, _ limit: Int) {
            guard d <= limit, !Scanner.blocked(u.path) else { return }
            for c in Scanner.children(u, hidden: true) {
                guard let v = try? c.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]), v.isDirectory == true, v.isSymbolicLink != true else { continue }
                let n = c.lastPathComponent
                if allNames.contains(n) || n == ".git" || n == "Library" { continue }
                if worktreeTarget(c) != nil { found.append(c); continue }                   // never look inside one for more
                if !n.hasPrefix(".") || n == ".claude" { walk(c, d + 1, limit) }
            }
        }
        projects.forEach { walk($0, 1, 7) }
        for tool in [".codex/worktrees", ".cursor/worktrees"] { walk(Scanner.home.appendingPathComponent(tool), 1, 3) }
        return found
    }
    static func worktrees(_ projects: [URL]) -> [CleanItem] {
        guard let cwds = workingDirs() else { return [] }
        return worktreeCandidates(projects).filter { !Scanner.skip($0.path) && orphaned($0, cwds: cwds) }.compactMap { f in
            let size = Scanner.size(f)
            return size > 0 ? CleanItem(url: f, size: size, selected: false,
                                        reason: t("Git no longer tracks this copy. Files never committed exist only here: open it first", "Git không còn theo dõi bản này. File chưa commit chỉ nằm ở đây: mở xem trước")) : nil
        }.sorted { $0.size > $1.size }
    }
    static func worktreeReport(_ projects: [URL]) -> String {
        guard let cwds = workingDirs() else { return "cannot read working folders: nothing is listed" }
        return worktreeCandidates(projects).map { (orphaned($0, cwds: cwds) ? "LISTED  " : "hidden  ") + $0.path }.sorted().joined(separator: "\n")
    }
}
