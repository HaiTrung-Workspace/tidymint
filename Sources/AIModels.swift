import Foundation

// MARK: - Local AI models (Clean by App)

/// Lists the AI models kept on this Mac by Ollama, Hugging Face and LM Studio, one row per model with its real name
/// and size. Nothing is ever pre-selected. Each row carries exactly the files that belong to that model alone, and
/// whenever something cannot be read the code offers less, never more.
/// Sources and measurements: research/51 (official docs, source code of the tools, a real Mac, 11/2026).
enum AIModels {
    static var home: URL { Scanner.home }
    static var fm: FileManager { Scanner.fm }
    private static func size(_ u: URL) -> Int64 {
        Int64((try? u.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
    }
    private static func isLink(_ u: URL) -> Bool { (try? u.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true }
    private static func isDir(_ u: URL) -> Bool { (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
    private static func json(_ u: URL) -> [String: Any]? {
        guard let d = try? Data(contentsOf: u) else { return nil }
        return (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
    }
    private static func short(_ u: URL) -> String {
        let h = home.path + "/"
        return u.path.hasPrefix(h) ? "~/" + u.path.dropFirst(h.count) : u.path
    }

    /// An environment variable as the tools see it: this process first, then launchd (the documented way to set one for a
    /// Mac app, e.g. `launchctl setenv OLLAMA_MODELS`). A variable that only lives in a shell profile is not seen.
    private static var envCache: [String: String] = [:]
    static func env(_ name: String) -> String? {
        if let v = ProcessInfo.processInfo.environment[name], !v.isEmpty { return v }
        if let c = envCache[name] { return c.isEmpty ? nil : c }
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/launchctl"); p.arguments = ["getenv", name]
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        var v = ""
        if (try? p.run()) != nil {
            let d = out.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
            v = String(data: d, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        envCache[name] = v
        return v.isEmpty ? nil : v
    }
    private static func dir(_ path: String) -> URL { URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true) }

    // MARK: Ollama
    // Checked on a real Mac (Ollama 0.40.15 from Homebrew, 11/2026) and against Ollama's source (manifest/manifest.go):
    //   models/manifests/<host>/<namespace>/<model>/<tag>      older layout: a JSON file
    //   models/manifests-v2/<host>/<namespace>/<model>/<tag>   newer layout: a symlink to the manifest's own blob.
    //                                                          Writing it REMOVES the entry under manifests/.
    //   models/blobs/sha256-<hex>                              the data, named by hash and SHARED between models
    //   models/metadata/sha256-<hex>.json                      details Ollama keeps per weights blob
    // A manifest is either one image (config + layers) or a list ("manifests": children, one per runner).
    // The host is "registry.ollama.ai" in the older tree and "ollama.com" in the newer one for the same model.
    // The folder moves with OLLAMA_MODELS. ~/.ollama also holds this Mac's private key: only files under models/ are listed.
    // Moving one model's entries and its own blobs to the Trash and back was tried: Ollama lists and runs it again.
    // Folders are never moved (Ollama recreates an empty "manifests" at once, which would block a put-back).
    static var ollamaRoot: URL { env("OLLAMA_MODELS").map(dir) ?? home.appendingPathComponent(".ollama/models") }
    static var ollamaPresent: Bool { fm.fileExists(atPath: ollamaRoot.appendingPathComponent("blobs").path) }

    /// `digests`: what the model is made of (config, layers). `own`: the blobs holding its manifest (newer layout), which
    /// differ between two names of the same model.
    struct OllamaModel { var name: String; var entries: [URL] = []; var digests: Set<String> = []; var own: Set<String> = [] }

    /// Every model with the blobs it needs, or nil when any entry cannot be read (then nothing is offered at all:
    /// an unread manifest may be the one that still needs a blob).
    static func ollamaModels(_ root: URL) -> [OllamaModel]? {
        func blob(_ digest: String) -> URL { root.appendingPathComponent("blobs/" + digest.replacingOccurrences(of: ":", with: "-")) }
        /// Digests one manifest needs: its config and layers, or for a list each child manifest and what that one needs.
        func needs(_ j: [String: Any], depth: Int = 0) -> Set<String>? {
            var out: Set<String> = []
            if let c = j["config"] as? [String: Any], let g = c["digest"] as? String { out.insert(g) }
            for l in j["layers"] as? [[String: Any]] ?? [] { if let g = l["digest"] as? String { out.insert(g) } }
            // A manifest list: one child per runner (mlx, llamacpp...). Ollama's struct nests whole manifests here;
            // a child given only by digest (a separate blob) is followed too. Anything else: unknown, offer nothing.
            for m in j["manifests"] as? [[String: Any]] ?? [] {
                guard depth < 3 else { return nil }
                if m["config"] != nil || m["layers"] != nil || m["manifests"] != nil {
                    guard let more = needs(m, depth: depth + 1) else { return nil }
                    out.formUnion(more)
                } else if let g = m["digest"] as? String {
                    out.insert(g)
                    let child = blob(g)
                    guard fm.fileExists(atPath: child.path) else { continue }   // a runner that was never pulled
                    guard let cj = json(child), let more = needs(cj, depth: depth + 1) else { return nil }
                    out.formUnion(more)
                } else { return nil }
            }
            return out
        }
        var byKey: [String: OllamaModel] = [:]
        // A folder that cannot be read may hold a model sharing files with the ones that can: then nothing is listed.
        var unreadable = false
        for tree in ["manifests", "manifests-v2"] {
            let base = root.appendingPathComponent(tree)
            guard fm.fileExists(atPath: base.path) else { continue }
            guard let en = fm.enumerator(at: base, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .isDirectoryKey], options: [], errorHandler: { _, _ in unreadable = true; return true }) else { return nil }
            for case let f as URL in en {
                if unreadable { return nil }
                if f.lastPathComponent.hasPrefix(".") { continue }
                let link = isLink(f)
                if !link && isDir(f) { continue }
                let rel = f.path.dropFirst(base.path.count + 1).split(separator: "/").map(String.init)
                guard rel.count == 4 else { return nil }   // not <host>/<namespace>/<model>/<tag>: a layout this code does not know
                var needed: Set<String> = [], ownBlob: String? = nil
                var source = f
                if link {
                    guard let dest = try? fm.destinationOfSymbolicLink(atPath: f.path) else { return nil }
                    let name = (dest as NSString).lastPathComponent
                    guard name.hasPrefix("sha256-") else { return nil }
                    source = root.appendingPathComponent("blobs/" + name)
                    ownBlob = name.replacingOccurrences(of: "sha256-", with: "sha256:")   // the manifest's own blob
                }
                guard let j = json(source), let more = needs(j) else { return nil }
                needed.formUnion(more)
                guard !needed.isEmpty else { return nil }
                let host = (rel[0] == "registry.ollama.ai" || rel[0] == "ollama.com") ? "" : rel[0] + "/"
                let key = host + rel[1] + "/" + rel[2] + ":" + rel[3]
                var m = byKey[key] ?? OllamaModel(name: host + (rel[1] == "library" ? "" : rel[1] + "/") + rel[2] + ":" + rel[3])
                if link { m.entries.insert(f, at: 0) } else { m.entries.append(f) }   // links first: a dangling link would be skipped
                m.digests.formUnion(needed)
                if let o = ownBlob { m.own.insert(o) }
                byKey[key] = m
            }
            if unreadable { return nil }
        }
        return Array(byKey.values)
    }

    static func ollamaRows() -> [AppRow] {
        let root = ollamaRoot
        guard let all = ollamaModels(root) else { return [] }
        // Names that need exactly the same blobs (ollama cp, or two tags of one model) are one row: one tick frees it all.
        var merged: [Set<String>: OllamaModel] = [:], aliases: [Set<String>: [String]] = [:]
        for m in all.sorted(by: { $0.name < $1.name }) {
            if var first = merged[m.digests] { first.entries += m.entries; first.own.formUnion(m.own); merged[m.digests] = first; aliases[m.digests, default: []].append(m.name) }
            else { merged[m.digests] = m }
        }
        let models = Array(merged.values)
        var uses: [String: Int] = [:]
        for m in models { for d in m.digests.union(m.own) { uses[d, default: 0] += 1 } }
        return models.map { m in
            var urls = m.entries
            var own: Int64 = m.entries.filter { !isLink($0) }.reduce(0) { $0 + size($1) }, shared: Int64 = 0
            var parts: [String: SharedPart] = [:]
            for d in m.digests.union(m.own).sorted() {
                let b = root.appendingPathComponent("blobs/" + d.replacingOccurrences(of: ":", with: "-"))
                guard fm.fileExists(atPath: b.path) else { continue }
                if uses[d] == 1 {
                    urls.append(b); own += size(b)
                    let meta = root.appendingPathComponent("metadata/" + b.lastPathComponent + ".json")
                    if fm.fileExists(atPath: meta.path) { urls.append(meta) }
                } else {
                    shared += size(b)
                    let meta = root.appendingPathComponent("metadata/" + b.lastPathComponent + ".json")
                    parts[d] = SharedPart(size: size(b), urls: [b] + (fm.fileExists(atPath: meta.path) ? [meta] : []))
                }
            }
            // The row's number is exactly what ticking it frees; the shared part has its own line under the rows.
            let also = aliases[m.digests] ?? []
            var notes: [String] = []
            if !also.isEmpty { notes.append(t("Also named: ", "Còn có tên: ") + also.joined(separator: ", ")) }
            if shared > 0 {
                let partners = models.filter { o in o.name != m.name && !o.digests.isDisjoint(with: m.digests.filter { (uses[$0] ?? 0) > 1 }) }.map(\.name).sorted()
                let who = partners.prefix(3).joined(separator: ", ") + (partners.count > 3 ? "…" : "")
                notes.append(t("Shares \(fmt(shared)) more with \(who)", "Dùng chung thêm \(fmt(shared)) với \(who)"))
            }
            let sub = notes.isEmpty ? t("Get it back any time with ollama pull", "Tải lại bất cứ lúc nào bằng ollama pull") : notes.joined(separator: " · ")
            // Links first: a dangling link would be skipped.
            urls = urls.filter { isLink($0) } + urls.filter { !isLink($0) }
            return AppRow(id: "ollama|" + m.name, title: m.name, sub: sub, size: own, count: 1, urls: urls, month: nil, selected: false, shared: parts)
        }.filter { $0.size > 0 || !$0.shared.isEmpty }.sorted { $0.size > $1.size }
    }
    /// Shown locked: the key Ollama signs in with.
    static func ollamaKeyRows() -> [AppRow] {
        ["id_ed25519", "id_ed25519.pub"].map { home.appendingPathComponent(".ollama/" + $0) }.filter { fm.fileExists(atPath: $0.path) }
            .map { AppRow(id: "ollama-key|" + $0.path, title: $0.lastPathComponent, sub: short($0), size: size($0), count: 1, urls: [$0], month: nil, selected: false) }
    }

    // MARK: Hugging Face
    // Checked on a real Mac (huggingface_hub CLI, 11/2026) and against the hub cache guide:
    //   <hub>/models--<org>--<name>/{blobs,snapshots,refs,trees}   one folder per repo; snapshots link into its blobs/
    //   <hub>/blobs/<2 hex>/<xet hash>  (+ .refs, .lock)            shared store: large files live HERE, the repo's blobs/
    //                                                                entry is only a link to it. Seen: repo folder 560 KB,
    //                                                                its data in the shared store 26 MB.
    //   <hash>.refs lists every "<repo folder>/blobs/<name>" that uses the file, one per line.
    // A shared file goes with a repo only when that repo is its sole user. The hub folder moves with HF_HUB_CACHE,
    // HF_HOME or XDG_CACHE_HOME. The sign-in token sits in HF_HOME and is never listed for cleaning.
    static var hfHome: URL {
        if let v = env("HF_HOME") { return dir(v) }
        if let x = env("XDG_CACHE_HOME") { return dir(x).appendingPathComponent("huggingface") }
        return home.appendingPathComponent(".cache/huggingface")
    }
    static var hfHub: URL { env("HF_HUB_CACHE").map(dir) ?? hfHome.appendingPathComponent("hub") }
    static var hfPresent: Bool { fm.fileExists(atPath: hfHub.path) }

    static func huggingFaceRows() -> [AppRow] {
        let hub = hfHub, store = hub.appendingPathComponent("blobs").resolvingSymlinksInPath().path + "/"
        let repos = ((try? fm.contentsOfDirectory(at: hub, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []).filter { isDir($0) && !isLink($0) }
        return repos.compactMap { repo -> AppRow? in
            let p = repo.lastPathComponent.components(separatedBy: "--")
            guard p.count >= 2, ["models", "datasets", "spaces"].contains(p[0]), !Scanner.skip(repo.path) else { return nil }
            var urls: [URL] = [], own = Scanner.size(repo), shared: Int64 = 0
            let entries = (try? fm.contentsOfDirectory(at: repo.appendingPathComponent("blobs"), includingPropertiesForKeys: [.isSymbolicLinkKey], options: [])) ?? []
            for e in entries where isLink(e) {
                let target = e.resolvingSymlinksInPath()
                guard target.path.hasPrefix(store), fm.fileExists(atPath: target.path) else { continue }
                let refs = URL(fileURLWithPath: target.path + ".refs")
                let users = (try? String(contentsOf: refs, encoding: .utf8))?.split(whereSeparator: \.isNewline).map(String.init) ?? []
                if !users.isEmpty, users.allSatisfy({ $0.hasPrefix(repo.lastPathComponent + "/") }) {
                    urls.append(target); own += size(target)
                    for extra in [refs, URL(fileURLWithPath: target.path + ".lock")] where fm.fileExists(atPath: extra.path) { urls.append(extra) }
                } else { shared += size(target) }   // used by another repo too, or no list of users: it stays
            }
            urls.insert(repo, at: 0)   // the folder (with its links) first, then the files those links pointed to
            let name = p.dropFirst().joined(separator: "/") + (p[0] == "models" ? "" : " (\(p[0]))")
            let sub = shared > 0 ? t("Shares \(fmt(shared)) more with other repos; that part stays", "Dùng chung thêm \(fmt(shared)) với kho khác, phần đó được giữ lại")
                                 : t("Downloaded again when a tool asks for it", "Tự tải lại khi công cụ cần")
            return own > 0 ? AppRow(id: "hf|" + repo.path, title: name, sub: sub, size: own, count: 1, urls: urls, month: nil, selected: false) : nil
        }.sorted { $0.size > $1.size }
    }
    static func hfTokenRows() -> [AppRow] {
        ["token", "stored_tokens"].map { hfHome.appendingPathComponent($0) }.filter { fm.fileExists(atPath: $0.path) }
            .map { AppRow(id: "hf-token|" + $0.path, title: $0.lastPathComponent, sub: short($0), size: size($0), count: 1, urls: [$0], month: nil, selected: false) }
    }

    // MARK: LM Studio
    // Checked on a real Mac (0.4.28, 11/2026) and against the `lms` CLI source:
    //   home: the path written in ~/.lmstudio-home-pointer, else ~/.cache/lm-studio when it exists, else ~/.lmstudio
    //   models: "downloadsFolder" in <home>/settings.json (the user can move it), else <home>/models,
    //           as <publisher>/<model>/<file>. `lms import` MOVES a file in, so a model may exist nowhere else.
    //   engines: <home>/extensions/backends/<name>-<version>/backend-manifest.json; the versions in use are in
    //            <home>/.internal/backend-preferences-v2.json ("versions"). An update keeps the old version on disk,
    //            and `lms runtime select` can pin an older one, so "in use" is read from that file, never guessed.
    //   vendor bundles: extensions/backends/vendor/_amphibian/<name>@<n>, named inside engine manifests
    //            as "_amphibian/<name>@<n>" ("vendor_lib_package_names"). Seen: engine 1.13.1 and its two bundles, 1.1 GB, beside the active 1.14.0.
    static var lmsHome: URL? {
        let pointer = home.appendingPathComponent(".lmstudio-home-pointer")
        if let s = try? String(contentsOf: pointer, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            return fm.fileExists(atPath: s) ? dir(s) : nil
        }
        for rel in [".cache/lm-studio", ".lmstudio"] {
            let u = home.appendingPathComponent(rel)
            if fm.fileExists(atPath: u.path) { return u }
        }
        return nil
    }
    static var lmsPresent: Bool { lmsHome != nil }

    static func lmStudioRows() -> [AppRow] {
        guard let h = lmsHome else { return [] }
        let folder = (json(h.appendingPathComponent("settings.json"))?["downloadsFolder"] as? String).map(dir) ?? h.appendingPathComponent("models")
        var level = [folder]
        for _ in 0..<2 {
            level = level.flatMap { d in ((try? fm.contentsOfDirectory(at: d, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []).filter { isDir($0) && !isLink($0) } }
        }
        let sub = t("Download it again in LM Studio. A model you imported yourself may exist only here", "Tải lại được trong LM Studio. Model bạn tự nhập có thể chỉ còn ở đây")
        return level.compactMap { d -> AppRow? in
            guard !Scanner.skip(d.path) else { return nil }
            let s = Scanner.size(d)
            let name = d.deletingLastPathComponent().lastPathComponent + "/" + d.lastPathComponent
            return s > 0 ? AppRow(id: "lms|" + d.path, title: name, sub: sub, size: s, count: 1, urls: [d], month: nil, selected: false) : nil
        }.sorted { $0.size > $1.size }
    }

    struct LMSEngine { let folder: URL; let name: String; let version: String; let bundles: Set<String> }
    static func versionParts(_ v: String) -> [Int]? {
        let p = v.split(separator: ".").map { Int($0) }
        return p.isEmpty || p.contains(where: { $0 == nil }) ? nil : p.map { $0! }
    }
    static func older(_ a: [Int], than b: [Int]) -> Bool {
        for i in 0..<max(a.count, b.count) { let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0; if x != y { return x < y } }
        return false
    }
    /// Every vendor bundle named anywhere in a JSON value: "_amphibian/<name>@<n>" (seen under "vendor_lib_package_names").
    private static func bundleRefs(_ v: Any) -> Set<String> {
        if let s = v as? String {
            for prefix in ["_amphibian/", "amphibian/"] where s.hasPrefix(prefix) && s.contains("@") { return [String(s.dropFirst(prefix.count))] }
            return []
        }
        if let a = v as? [Any] { return a.reduce(into: Set<String>()) { $0.formUnion(bundleRefs($1)) } }
        if let d = v as? [String: Any] { return d.values.reduce(into: Set<String>()) { $0.formUnion(bundleRefs($1)) } }
        return []
    }
    /// Bundles named in a text file (a bundle's pyvenv.cfg points at the Python bundle it runs on).
    private static func bundleRefs(text: String) -> Set<String> {
        guard let re = try? NSRegularExpression(pattern: #"_amphibian/([A-Za-z0-9._-]+@[0-9]+)"#) else { return [] }
        let ns = text as NSString
        return Set(re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range(at: 1)) })
    }
    /// (superseded engines with the vendor bundles only they use, engines kept). Nothing is ever offered when the
    /// preferences file or any engine manifest cannot be read.
    static func lmsEngines() -> (old: [AppRow], kept: [AppRow]) {
        guard let h = lmsHome else { return ([], []) }
        let backends = h.appendingPathComponent("extensions/backends")
        let vendor = backends.appendingPathComponent("vendor/_amphibian")
        let folders = ((try? fm.contentsOfDirectory(at: backends, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? [])
            .filter { isDir($0) && !isLink($0) && $0.lastPathComponent != "vendor" }
        guard !folders.isEmpty else { return ([], []) }
        var engines: [LMSEngine] = [], unreadable = false
        for f in folders {
            guard let m = json(f.appendingPathComponent("backend-manifest.json")) else { unreadable = true; continue }
            // Name and version from the folder ("<name>-<version>"); the manifest's own fields win when present.
            let base = f.lastPathComponent
            guard let cut = base.lastIndex(of: "-") else { unreadable = true; continue }
            let name = (m["name"] as? String) ?? String(base[..<cut])
            let version = (m["version"] as? String) ?? String(base[base.index(after: cut)...])
            guard versionParts(version) != nil, base == name + "-" + version else { unreadable = true; continue }
            engines.append(LMSEngine(folder: f, name: name, version: version, bundles: bundleRefs(m)))
        }
        let prefs = json(h.appendingPathComponent(".internal/backend-preferences-v2.json"))?["versions"] as? [String: String] ?? [:]
        func keptRow(_ e: LMSEngine, _ why: String) -> AppRow {
            AppRow(id: "lms-engine|" + e.folder.path, title: e.name + " " + e.version, sub: why, size: Scanner.size(e.folder), count: 1, urls: [e.folder], month: nil, selected: false)
        }
        let inUse = t("In use", "Đang dùng"), unsure = t("Kept: LM Studio's choice could not be read", "Giữ lại: không đọc được lựa chọn của LM Studio")
        guard !unreadable, !prefs.isEmpty else { return ([], engines.map { keptRow($0, unsure) }) }
        var old: [LMSEngine] = [], kept: [(LMSEngine, String)] = []
        for (name, group) in Dictionary(grouping: engines, by: \.name) {
            // An engine never chosen, or whose chosen version is not on disk: keep the whole group.
            guard let chosen = prefs[name], let cv = versionParts(chosen), group.contains(where: { $0.version == chosen }) else {
                kept += group.map { ($0, unsure) }; continue
            }
            for e in group {
                if e.version == chosen { kept.append((e, inUse)) }
                else if let v = versionParts(e.version), older(v, than: cv) { old.append(e) }
                else { kept.append((e, t("Newer than the one in use", "Mới hơn bản đang dùng"))) }
            }
        }
        // A vendor bundle goes with an old engine only when no kept engine names it, directly or through a kept bundle.
        var keep = kept.reduce(into: Set<String>()) { $0.formUnion($1.0.bundles) }
        // Other extensions (extensions/frameworks) use vendor bundles too. One that cannot be read: offer no bundle at all.
        var bundlesSafe = true
        for f in (try? fm.contentsOfDirectory(at: h.appendingPathComponent("extensions/frameworks"), includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? [] where isDir(f) {
            if let j = json(f.appendingPathComponent("backend-manifest.json")) { keep.formUnion(bundleRefs(j)) } else { bundlesSafe = false }
        }
        var frontier = keep
        while !frontier.isEmpty {
            var next: Set<String> = []
            for b in frontier {
                let files = (try? fm.contentsOfDirectory(at: vendor.appendingPathComponent(b), includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
                for f in files where f.pathExtension == "json" { if let j = json(f) { next.formUnion(bundleRefs(j)) } }
                if let cfg = try? String(contentsOf: vendor.appendingPathComponent(b + "/pyvenv.cfg"), encoding: .utf8) { next.formUnion(bundleRefs(text: cfg)) }
            }
            frontier = next.subtracting(keep); keep.formUnion(next)
        }
        var owners: [String: Int] = [:]
        for e in old { for b in e.bundles where !keep.contains(b) { owners[b, default: 0] += 1 } }
        let oldRows = old.map { e -> AppRow in
            let mine = e.bundles.filter { bundlesSafe && !keep.contains($0) && owners[$0] == 1 }.sorted()
                .map { vendor.appendingPathComponent($0) }.filter { fm.fileExists(atPath: $0.path) }
            let urls = [e.folder] + mine
            let total = urls.reduce(Int64(0)) { $0 + Scanner.size($1) }
            return AppRow(id: "lms-old|" + e.folder.path, title: e.name + " " + e.version,
                          sub: t("Replaced by \(prefs[e.name] ?? ""). Get it back in LM Studio: Runtime", "Đã được thay bằng \(prefs[e.name] ?? ""). Tải lại trong LM Studio: Runtime"),
                          size: total, count: urls.count, urls: urls, month: nil, selected: false)
        }.filter { $0.size > 0 }.sorted { $0.size > $1.size }
        let keptRows = kept.map { e, why -> AppRow in
            var r = keptRow(e, why)
            let extra = e.bundles.map { vendor.appendingPathComponent($0) }.filter { fm.fileExists(atPath: $0.path) }.reduce(Int64(0)) { $0 + Scanner.size($1) }
            r = AppRow(id: r.id, title: r.title, sub: r.sub, size: r.size + extra, count: 1, urls: r.urls, month: nil, selected: false)
            return r
        }.sorted { $0.size > $1.size }
        return (oldRows, keptRows)
    }
}
