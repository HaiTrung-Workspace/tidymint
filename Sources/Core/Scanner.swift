import SwiftUI
import AppKit
import UserNotifications
import ServiceManagement
import CryptoKit
import QuickLookThumbnailing
import QuickLook
import Vision
import PDFKit
import Charts
import ImageIO
import AVFoundation

// MARK: - Scanner

enum Scanner {
    static let home = URL(fileURLWithPath: NSHomeDirectory())
    static let lib = home.appendingPathComponent("Library")
    static let fm = FileManager.default

    /// Places Tidymint never lists or touches: cloud-synced roots, iCloud Drive internals, keychains, Mail, Apple's own caches.
    /// Anchored to ~/Library (up to 0.4 these were loose words, so a file named "Passwords export.csv" vanished from every scan).
    static let neverPrefixes = ["Library/CloudStorage/", "Library/Mobile Documents/", "Library/Keychains/", "Library/Mail/", "Library/Caches/com.apple."]
        .map { home.path + "/" + $0 }

    static func size(_ url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir), !isLibrary(url.path) else { return 0 }
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        if !isDir.boolValue {
            let v = try? url.resourceValues(forKeys: Set(keys))
            return Int64(v?.totalFileAllocatedSize ?? v?.fileAllocatedSize ?? 0)
        }
        var total: Int64 = 0
        if let en = fm.enumerator(at: url, includingPropertiesForKeys: keys, options: [], errorHandler: { _, _ in true }) {
            for case let f as URL in en {
                if isLibrary(f.path) { en.skipDescendants(); continue }
                if let v = try? f.resourceValues(forKeys: Set(keys)) {
                    total += Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
                }
            }
        }
        return total
    }

    static func children(_ url: URL, hidden: Bool = false) -> [URL] {
        (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: hidden ? [] : [.skipsHiddenFiles])) ?? []
    }

    static func runningKeys() -> [String] {
        var k: [String] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let n = app.localizedName ?? ""
            let b = app.bundleIdentifier ?? ""
            switch true {
            case n.contains("Chrome"): k += ["/Google/", "/Caches/Google", "com.google.Chrome"]   // ~/Library/Caches/Google itself ends in "Google"
            case n.contains("Slack"): k += ["slack", "Slack"]
            case n.contains("Zalo"): k += ["Zalo", "zalo"]
            case n.contains("Telegram"): k += ["keepcoder", "Telegram"]
            case n.contains("Edge"): k += ["Edge"]
            case n.contains("Notion"): k += ["Notion", "notion"]
            case n == "Code" || b.contains("VSCode"): k += ["/Code/", "vscode"]
            case n.contains("Safari"): k += ["Safari"]
            case n.contains("Outlook"): k += ["Outlook"]
            case n.contains("WhatsApp"): k += ["whatsapp", "WhatsApp"]
            case n.contains("Firefox"): k += ["Firefox", "Mozilla"]
            // Xcode and Simulator: their data lives under Developer/, which holds no bundle id to match.
            case b == "com.apple.dt.Xcode" || b == "com.apple.iphonesimulator": k += ["/Developer/Xcode/", "/Developer/CoreSimulator/"]
            default: break
            }
            if !b.isEmpty { k.append(b) }
        }
        return k
    }

    /// Without Full Disk Access, touching the Photos or Music libraries makes macOS pop a permission dialog
    /// for each, even though the app only measures them. They are never cleaned, so in that case they are left out.
    static var limited = false
    static let libraries = ["Photos Library.photoslibrary", "/Pictures/Photos Library", "/Music/Music/", "/Music/iTunes/", ".musiclibrary"]
    static func isLibrary(_ p: String) -> Bool { limited && libraries.contains { p.contains($0) } }

    /// Fixed places above, any Photos library, and the words the user added in Settings › Protected (matched anywhere).
    static func blocked(_ p: String) -> Bool {
        let q = p + "/"
        if neverPrefixes.contains(where: { q.hasPrefix($0) }) { return true }
        if p.split(separator: "/").contains(where: { $0.hasSuffix(".photoslibrary") }) { return true }
        return Prefs.protectedKeywords.contains { !$0.isEmpty && p.localizedCaseInsensitiveContains($0) }
    }
    static func skip(_ p: String) -> Bool { blocked(p) || isLibrary(p) || IgnoreList.contains(p) }

    /// Chat and app databases with their journals. A folder holding one is never offered as a whole.
    static let dbExts: Set<String> = ["db", "sqlite", "sqlite3", "db-wal", "db-shm", "sqlite-wal", "sqlite-shm", "wal", "shm", "realm"]
    /// Also catches databases named without an extension, like Telegram's "db_sqlite", "db_sqlite-wal", "db_sqlite-shm", "db_sqlite-guard".
    static func isDatabase(_ u: URL) -> Bool {
        if dbExts.contains(u.pathExtension.lowercased()) { return true }
        let n = u.lastPathComponent.lowercased()
        return n.range(of: #"(sqlite3?|realm|\.db)(-wal|-shm|-journal|-guard)?$"#, options: .regularExpression) != nil
    }
    /// True when the item is a database file or a folder with a database among its direct children.
    static func holdsDatabase(_ u: URL) -> Bool {
        if isDatabase(u) { return true }
        return children(u, hidden: true).contains { isDatabase($0) }
    }
    /// Same question for the whole folder, every level down (sandboxed apps keep their database under Data/Library/...).
    /// Stops at the first database found; no depth or count limit, so the answer is never a guess. Runs off the main thread.
    static func holdsDatabaseDeep(_ u: URL) -> Bool {
        if isDatabase(u) { return true }
        guard let en = fm.enumerator(at: u, includingPropertiesForKeys: nil, options: [], errorHandler: { _, _ in true }) else { return false }
        for case let f as URL in en where isDatabase(f) { return true }
        return false
    }

    /// Running state by bundle id (exact), the reliable way to tell "Zalo" from "Zalo Helper".
    static func running(_ bundleIDs: [String]) -> NSRunningApplication? {
        for b in bundleIDs { if let a = NSRunningApplication.runningApplications(withBundleIdentifier: b).first { return a } }
        return nil
    }
    static func quit(_ bundleIDs: [String]) { bundleIDs.forEach { NSRunningApplication.runningApplications(withBundleIdentifier: $0).forEach { $0.terminate() } } }

    /// Every non-empty folder is listed (since 0.5.0; up to 0.4 anything under 512 KB was silently left out).
    /// Small ones are grouped on screen, see `Category.smallLimit`.
    /// Folders macOS keeps on every volume (a drive's Trash, Spotlight index, file system events...). Large Files lists hidden
    /// files since 0.5.0, but these are never the user's files and "moving" a file from a drive's Trash to the Trash frees nothing.
    static let systemHiddenDirs: Set<String> = [".Trashes", ".Trash", ".Spotlight-V100", ".fseventsd", ".TemporaryItems", ".DocumentRevisions-V100", "$RECYCLE.BIN"]
    /// Folders in ~/Library/Caches that hold downloaded AI models (many GB, not rebuilt on their own), so they are
    /// never part of "User Cache Files": Hugging Face models of Mac apps, GGUF files llama.cpp fetched, Whisper models of Buzz.
    static let modelCaches: Set<String> = ["huggingface", "llama.cpp", "Buzz"]
    static func make(_ urls: [URL], running: [String], defaultOn: Bool = true, minSize: Int64 = 1) -> [CleanItem] {
        var out: [CleanItem] = []
        for u in urls where !skip(u.path) {
            let s = size(u)
            guard s >= minSize else { continue }
            let isRunning = running.contains { u.path.contains($0) }
            out.append(CleanItem(url: u, size: s, selected: defaultOn && !isRunning, running: isRunning))
        }
        return out.sorted { $0.size > $1.size }
    }

    /// A folder named "logs" inside an app's data can hold more than logs. Outside ~/Library/Logs it is ticked only when
    /// everything in it looks like a log (.log, .txt, .gz, .jsonl, .crash, .ips, .diag); otherwise listed with a note.
    static func logItems(_ items: [CleanItem]) -> [CleanItem] {
        let logRoot = lib.appendingPathComponent("Logs").path + "/"
        let exts: Set<String> = ["log", "txt", "gz", "jsonl", "crash", "ips", "diag", "old", ""]
        return items.map { it in
            var it = it
            guard !(it.url.path + "/").hasPrefix(logRoot) else { return it }
            var onlyLogs = true
            if let en = fm.enumerator(at: it.url, includingPropertiesForKeys: [.isRegularFileKey], options: [], errorHandler: { _, _ in true }) {
                var n = 0
                for case let f as URL in en {
                    n += 1; if n > 5000 { onlyLogs = false; break }
                    if (try? f.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                       !exts.contains(f.pathExtension.lowercased()) && !f.lastPathComponent.contains(".log") { onlyLogs = false; break }
                }
            }
            if !onlyLogs {
                it.selected = false
                it.reason = t("Holds more than log files, check first", "Có cả file không phải nhật ký, kiểm tra trước")
            }
            return it
        }
    }

    static func findDirs(_ roots: [URL], names: Set<String>, depth: Int) -> [URL] {
        var found: [URL] = []
        func walk(_ u: URL, _ d: Int) {
            guard d <= depth, !blocked(u.path) else { return }
            for c in children(u) {
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: c.path, isDirectory: &isDir), isDir.boolValue else { continue }
                if names.contains(c.lastPathComponent) { found.append(c) } else { walk(c, d + 1) }
            }
        }
        roots.forEach { walk($0, 1) }
        return found
    }

    static func scanJunk(step: (Int, String) -> Void = { _, _ in }) -> [Category] {
        step(0, "~/Library/Caches")
        let run = runningKeys()
        let AS = lib.appendingPathComponent("Application Support")
        let appRoots = [AS, lib.appendingPathComponent("Containers"), lib.appendingPathComponent("Group Containers")]
        var cats: [Category] = []

        cats.append(Category(id: "usercache", titleEN: "User Cache Files", titleVI: "Bộ nhớ đệm người dùng", icon: "internaldrive",
                             descEN: "Temporary files apps rebuild on their own", descVI: "File tạm, app tự tạo lại khi cần",
                             whyEN: "Apps rebuild these. The first launch after cleaning may be a little slower.", whyVI: "App tự tạo lại. Lần mở đầu sau khi dọn có thể chậm hơn một chút.",
                             items: make(children(lib.appendingPathComponent("Caches")).filter { !modelCaches.contains($0.lastPathComponent) }, running: run)))

        step(1, "~/Library/Application Support, Containers")
        let appCacheNames: Set<String> = ["Cache", "Code Cache", "GPUCache", "DawnCache", "DawnGraphiteCache", "GraphiteDawnCache",
                                          "ShaderCache", "CacheStorage", "CachedData", "CachedExtensionVSIXs", "Crashpad"]
        cats.append(Category(id: "appcache", titleEN: "App Caches", titleVI: "Bộ nhớ đệm trong app", icon: "square.stack.3d.up",
                             descEN: "Web and graphics caches from Chrome, Slack, Notion, VS Code...", descVI: "Bộ nhớ đệm web, đồ hoạ của Chrome, Slack, Notion, VS Code...",
                             whyEN: "Pages and images load from the network again. Logins and settings are not touched.", whyVI: "Trang web, ảnh sẽ tải lại từ mạng. Đăng nhập và cài đặt không bị đụng.",
                             items: make(findDirs(appRoots, names: appCacheNames, depth: 6), running: run)))

        step(2, "~/Library/Logs")
        let logs = [lib.appendingPathComponent("Logs")] + findDirs(appRoots, names: ["logs", "Logs"], depth: 6)
        cats.append(Category(id: "logs", titleEN: "Log Files", titleVI: "Nhật ký (log)", icon: "doc.text",
                             descEN: "Error and activity logs, safe to remove", descVI: "Nhật ký lỗi và hoạt động, xoá an toàn",
                             whyEN: "Only useful when debugging a problem.", whyVI: "Chỉ cần khi đang tìm lỗi.",
                             items: logItems(make(logs, running: run))))

        step(3, "~/.npm, wallpapers")
        var dev: [URL] = []
        let npm = home.appendingPathComponent(".npm/_cacache"); if fm.fileExists(atPath: npm.path) { dev.append(npm) }
        let aer = AS.appendingPathComponent("com.apple.wallpaper/aerials"); if fm.fileExists(atPath: aer.path) { dev.append(aer) }
        cats.append(Category(id: "dev", titleEN: "Developer & Wallpaper Junk", titleVI: "Công cụ và hình nền", icon: "hammer",
                             descEN: "npm cache, downloaded aerial wallpapers", descVI: "Bộ nhớ đệm npm, hình nền động đã tải",
                             items: make(dev, running: run)))

        let derived = lib.appendingPathComponent("Developer/Xcode/DerivedData")
        if fm.fileExists(atPath: derived.path) {
            cats.append(Category(id: "xcode", titleEN: "Xcode Build Data", titleVI: "Dữ liệu build Xcode", icon: "hammer.circle",
                                 descEN: "DerivedData, one folder per project. Not selected by default", descVI: "DerivedData, mỗi dự án một thư mục. Mặc định không tick",
                                 safety: .review, whyEN: "Xcode rebuilds it. The next build of that project takes longer.", whyVI: "Xcode tự tạo lại. Lần build sau của dự án đó sẽ lâu hơn.",
                                 items: make(children(derived), running: run, defaultOn: false)))
        }

        let projects = Prefs.projectFolders.map { URL(fileURLWithPath: $0) }
        step(4, projects.first.map { $0.path.replacingOccurrences(of: NSHomeDirectory(), with: "~") } ?? "")
        cats.append(Category(id: "drafts", titleEN: "Project Drafts", titleVI: "Nháp trong thư mục dự án", icon: "tray.full",
                             descEN: "_to_delete and _tmp folders in your project folders (set them in Settings)",
                             descVI: "Thư mục _to_delete, _tmp trong thư mục dự án (chọn ở Cài đặt)",
                             safety: .review, whyEN: "Your own drafts. Check the folder before cleaning.", whyVI: "Nháp của chính bạn. Xem lại thư mục trước khi dọn.",
                             items: make(findDirs(projects, names: ["_to_delete", "_to-delete", "_tmp"], depth: 5), running: run, defaultOn: false, minSize: 1)))

        let deps = DevDeps.scan(projects)
        if !deps.isEmpty {
            cats.append(Category(id: "devdeps", titleEN: "Dependencies of Old Projects", titleVI: "Thư viện của dự án lâu không đụng", icon: "shippingbox",
                                 descEN: "node_modules, Python venv, build folders in projects untouched for \(DevDeps.days / 30)+ months. Not selected by default",
                                 descVI: "node_modules, venv Python, thư mục build trong dự án không đổi từ \(DevDeps.days / 30) tháng. Mặc định không tick",
                                 safety: .review, whyEN: "The project's own files say how to rebuild these. Reinstalling takes time and a network connection.",
                                 whyVI: "Chính file của dự án cho biết cách tạo lại. Cài lại cần thời gian và mạng.",
                                 items: deps))
        }

        let trees = DevDeps.worktrees(projects)
        if !trees.isEmpty {
            cats.append(Category(id: "worktrees", titleEN: "Git Worktrees Left Behind", titleVI: "Thư mục làm việc Git bị bỏ lại", icon: "arrow.triangle.branch",
                                 descEN: "Copies of a project made by git or an AI coding tool that git no longer tracks. Not selected by default",
                                 descVI: "Bản sao dự án do git hoặc công cụ AI tạo ra, git không còn theo dõi. Mặc định không tick",
                                 safety: .review, whyEN: "Work that was never committed exists only in these folders. Look inside before cleaning.",
                                 whyVI: "Phần việc chưa commit chỉ nằm trong các thư mục này. Mở xem trước khi dọn.",
                                 items: trees))
        }

        step(5, "~/Downloads")
        let cutoff = Date().addingTimeInterval(-14 * 86400)
        // "Date Added" as Finder shows it (a file unzipped today can carry an old modification date).
        let dls = children(home.appendingPathComponent("Downloads")).filter {
            let v = try? $0.resourceValues(forKeys: [.addedToDirectoryDateKey, .contentModificationDateKey])
            return (v?.addedToDirectoryDate ?? v?.contentModificationDate ?? Date()) < cutoff
        }
        cats.append(Category(id: "downloads", titleEN: "Old Downloads (14+ days)", titleVI: "Downloads cũ hơn 14 ngày", icon: "arrow.down.circle",
                             descEN: "Not selected by default. Review before removing", descVI: "Mặc định không tick, xem rồi chọn",
                             safety: .review, whyEN: "Files you downloaded. Once the Trash is emptied they are gone.", whyVI: "File bạn đã tải. Đổ Thùng rác rồi là mất.",
                             items: make(dls, running: run, defaultOn: false, minSize: 1)))

        return cats.filter { !$0.items.isEmpty }
    }

    /// Scan roots without overlap: resolved paths, and a folder already inside another root is dropped,
    /// so no file is counted twice (it would otherwise show up as its own duplicate).
    static func scanRoots(_ base: [URL], extras: Bool = true) -> [URL] {
        // Base folders stay as written (~/Documents even if it is a link elsewhere), so project folders and
        // the ignore list, saved with those paths, still match. Only the extra folders are resolved.
        let all = base.map(\.standardizedFileURL) + (extras ? Prefs.extraRoots.map { $0.resolvingSymlinksInPath().standardizedFileURL } : [])
        var kept: [URL] = []
        for u in all.sorted(by: { $0.path.count < $1.path.count }) where fm.fileExists(atPath: u.path) {
            if kept.contains(where: { u.path == $0.path || u.path.hasPrefix($0.path + "/") }) { continue }
            kept.append(u)
        }
        return kept
    }

    /// `extras`: also walk the drives and folders added in Settings (the Large & Old Files page). Smart Scan leaves them out
    /// so the quick scan stays quick even with a big external drive attached.
    static func scanLarge(minMB: Int64 = 100, extras: Bool = false) -> [CleanItem] {
        let roots = scanRoots(["Documents", "Downloads", "Desktop", "Movies", "Music", "Pictures"].map { home.appendingPathComponent($0) }, extras: extras)
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey, .contentAccessDateKey, .contentModificationDateKey]
        var out: [CleanItem] = []
        for r in roots {
            // Hidden files are included and tagged; packages (app bundles, Final Cut or iMovie libraries...) are listed
            // as one item, never opened, since their insides must be managed by the app that owns them.
            guard let en = fm.enumerator(at: r, includingPropertiesForKeys: Array(keys) + [.isHiddenKey, .isPackageKey], options: [.skipsPackageDescendants],
                                         errorHandler: { _, _ in true }) else { continue }
            for case let f as URL in en {
                if skip(f.path) || systemHiddenDirs.contains(f.lastPathComponent) { en.skipDescendants(); continue }
                guard let v = try? f.resourceValues(forKeys: keys.union([.isHiddenKey, .isPackageKey])) else { continue }
                if v.isPackage == true {
                    let s = size(f)
                    if s >= minMB * 1_000_000 {
                        var it = CleanItem(url: f, size: s, selected: false, date: v.contentAccessDate ?? v.contentModificationDate)
                        it.reason = t("Package (app or library), manage it in its own app", "Gói của app hoặc thư viện, nên dọn trong app của nó")
                        out.append(it)
                    }
                    continue
                }
                guard v.isRegularFile == true else { continue }
                let s = Int64(v.totalFileAllocatedSize ?? 0)
                if s >= minMB * 1_000_000 {   // base-10 MB, like the label and Finder
                    // "Last opened" as Finder shows it (Spotlight), falling back to the file system dates.
                    let opened = NSMetadataItem(url: f)?.value(forAttribute: "kMDItemLastUsedDate") as? Date
                    var it = CleanItem(url: f, size: s, selected: false, date: opened ?? v.contentAccessDate ?? v.contentModificationDate)
                    // A hidden file is usually something an app or tool keeps on purpose (a VM disk, a sync cache).
                    it.hasDB = isDatabase(f)   // e.g. an app's .db file kept in Movies: flagged like everywhere else
                    if v.isHidden == true || f.path.contains("/.") { it.reason = t("Hidden file, often kept by an app or tool", "File ẩn, thường do app hoặc công cụ giữ") }
                    out.append(it)
                }
            }
        }
        return out.sorted { $0.size > $1.size }
    }

    /// Space Lens: sizes of the direct children of a folder, computed in parallel.
    static func lens(_ url: URL) -> [Node] {
        let kids = children(url, hidden: true)
        var sizes = [Int64](repeating: 0, count: kids.count)
        var dirs = [Bool](repeating: false, count: kids.count)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: kids.count) { i in
            var isDir: ObjCBool = false
            fm.fileExists(atPath: kids[i].path, isDirectory: &isDir)
            let s = size(kids[i])
            lock.lock(); sizes[i] = s; dirs[i] = isDir.boolValue && !kids[i].pathExtension.lowercased().hasSuffix("app"); lock.unlock()
        }
        return kids.indices.map { Node(url: kids[$0], size: sizes[$0], isDir: dirs[$0]) }
            .filter { $0.size > 0 }.sorted { $0.size > $1.size }
    }

    static var trashURL: URL { home.appendingPathComponent(".Trash") }
}
