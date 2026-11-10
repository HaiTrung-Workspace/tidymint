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

// Trash and Undo: every clean goes through here. Items only move to the Trash, each run is recorded so it can be put back.

extension Scanner {
    /// Refuse paths that resolve outside the user's home (symlink escape), or that are too shallow to be junk.
    /// `_CS_DARWIN_USER_CACHE_DIR` and `_CS_DARWIN_USER_TEMP_DIR`, symlinks resolved, without the trailing slash.
    static let userVarDirs: [String] = [_CS_DARWIN_USER_CACHE_DIR, _CS_DARWIN_USER_TEMP_DIR].compactMap { key in
        var buf = [CChar](repeating: 0, count: 1024)
        guard confstr(key, &buf, buf.count) > 0 else { return nil }
        let p = URL(fileURLWithPath: String(cString: buf)).resolvingSymlinksInPath().path
        return p.count > 20 ? (p.hasSuffix("/") ? String(p.dropLast()) : p) : nil
    }
    /// Files in iCloud "Desktop & Documents" are moved to the Trash by the File Provider daemon, which first asks macOS
    /// whether this app may use the Documents (or Desktop) folder. Asked cold, that check answers "would require prompt" and
    /// fails with error 513; once refused, the process stays refused. A Spotlight lookup on the folder settles the folder
    /// permission first (Full Disk Access covers it), and the move then works. Verified on macOS 26, 05/11/2026:
    /// without the lookup 0/4 runs passed, with it 3/3. Runs once per launch, only for paths inside these folders.
    private nonisolated(unsafe) static var warmed = Set<String>()
    static func warmProtectedFolders(for urls: [URL]) {
        for name in ["Documents", "Desktop"] {
            let dir = home.appendingPathComponent(name).path
            guard !warmed.contains(dir), urls.contains(where: { $0.path == dir || $0.path.hasPrefix(dir + "/") }) else { continue }
            warmed.insert(dir)
            _ = NSMetadataItem(url: URL(fileURLWithPath: dir))?.value(forAttribute: kMDItemContentModificationDate as String)
        }
    }
    static let protectedHomeItems: Set<String> = ["Library", "Desktop", "Documents", "Downloads", "Pictures", "Movies", "Music",
        "Applications", "Public", ".Trash", "Library/Mobile Documents", "Library/Mobile Documents/com~apple~CloudDocs", "Library/CloudStorage"]
    static func safeToTrash(_ u: URL) -> Bool {
        let real = u.resolvingSymlinksInPath().path
        let homeReal = home.resolvingSymlinksInPath().path
        // This user's own cache and temp folders under /private/var/folders (confstr(3)): only items inside them.
        if userVarDirs.contains(where: { real.hasPrefix($0 + "/") }) { return true }
        guard real.hasPrefix(homeReal + "/") || real.hasPrefix("/Volumes/") else { return false }
        let depth = real.split(separator: "/").count
        guard depth >= 3 else { return false }   // /Users/name/x is the shallowest thing allowed
        // Never the standard folders of the home folder themselves, the Trash, the iCloud Drive roots, or a drive's own Trash
        // (Space Lens lists them as bubbles and turns strict off; Finder refuses to delete these too).
        if real.hasPrefix(homeReal + "/") {
            let rest = String(real.dropFirst(homeReal.count + 1))
            if protectedHomeItems.contains(rest) || rest.hasPrefix(".Trash/") { return false }
        } else {
            let parts = real.split(separator: "/")
            if parts.count >= 3, parts[2] == ".Trashes" || parts[2] == ".Trash" { return false }
        }
        return true
    }
}

extension VM {
    /// A drive's ".Trashes" made by macOS: owned by root or with the sticky bit (mode 1333). On drives mounted with
    /// "ignore ownership" the owner reads as the user, so the sticky bit decides; FAT/exFAT have no Unix modes, accept.
    /// A ".Trashes" made by a script (mode 755, seen 04/11/2026) is neither shown nor emptied by Finder, so skip it.
    nonisolated static func isRealDriveTrash(_ trashes: URL) -> Bool {
        var st = stat(); guard stat(trashes.path, &st) == 0 else { return false }
        if st.st_uid == 0 || (st.st_mode & S_ISVTX) != 0 { return true }
        var fs = statfs(); guard statfs(trashes.path, &fs) == 0 else { return false }
        let type = withUnsafeBytes(of: fs.f_fstypename) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
        return ["msdos", "exfat"].contains(type)
    }

    func refreshTrash(done: (() -> Void)? = nil) {
        let t = Scanner.trashURL
        trashGen += 1; let gen = trashGen
        Task.detached {
            // Finder's Empty Trash also empties the Trash on each mounted drive (.Trashes/<uid>), so count those too.
            let vols = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeIsLocalKey], options: [.skipHiddenVolumes]) ?? []
            let uid = getuid()
            // iCloud Drive items (and iCloud Desktop & Documents) go to a separate Trash that Finder shows merged with ~/.Trash.
            // Seen 05/11/2026: files and folders trashed from ~/Documents landed in ~/Library/Mobile Documents/.Trash.
            // Not yet verified: whether Finder's Empty Trash also empties that folder.
            let icloud = Scanner.home.appendingPathComponent("Library/Mobile Documents/.Trash")
            let local = [t] + (FileManager.default.fileExists(atPath: icloud.path) ? [icloud] : [])
            let trashes = local + vols.filter { $0.path.hasPrefix("/Volumes/") && (try? $0.resourceValues(forKeys: [.volumeIsLocalKey]))?.volumeIsLocal == true }
                .map { $0.appendingPathComponent(".Trashes/\(uid)") }
                .filter { FileManager.default.fileExists(atPath: $0.path) && VM.isRealDriveTrash($0.deletingLastPathComponent()) }
            // One walk per Trash: (count, size). Both skip hidden files: Finder leaves a .DS_Store in an empty drive Trash
            // (seen 06/11/2026), which made an empty Trash read "8 KB".
            // Hidden folders count (a trashed .venv or .build is real data, found in review 11/2026); only Finder's own
            // bookkeeping files are left out.
            let each = trashes.map { tr -> (Int, Int64) in
                let kids = Scanner.children(tr, hidden: true).filter { let n = $0.lastPathComponent; return n != ".DS_Store" && !n.hasPrefix("._") && n != ".localized" }
                return (kids.count, kids.reduce(Int64(0)) { $0 + Scanner.size($1) })
            }
            let s = each.reduce(Int64(0)) { $0 + $1.1 }, c = each.reduce(0) { $0 + $1.0 }
            let drives: [(String, Int, Int64)] = zip(trashes, each).dropFirst(local.count).compactMap { u, e in
                e.0 == 0 ? nil : (u.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent, e.0, e.1)
            }
            await MainActor.run {
                guard gen == self.trashGen else { return }   // a newer refresh started: drop this older result
                self.trashSize = s; self.trashCount = c; self.trashOnDrives = drives
                if c == 0 { self.trashLeftNote = nil }
                done?()
            }
        }
    }

    /// Move items to the Trash and remember where each one went, so the whole run can be undone.
    /// `strict` refuses paths outside the home folder or too close to its root (off only for a folder the user picked by hand).
    func trash(_ urls: [URL], label: String = "", strict: Bool = true, alsoUndo: [Journal.Entry] = [], sizes: [URL: Int64] = [:]) -> (Int, Int) {
        var ok = 0, fail = 0
        var errDetail = ""
        lastOK = []; lastErr = ""
        TrashHint.quiet()
        if Demo.active { lastErr = t("demo mode, nothing is moved", "chế độ demo, không chuyển gì"); return (0, urls.count) }
        var moved: [Journal.Entry] = alsoUndo
        // An item inside another item of the same run goes with its parent (a node_modules inside a folder that is
        // listed too): moved on its own first, Undo would rebuild an empty parent and then skip the real one.
        let all = Set(urls.map { $0.standardizedFileURL.path })
        let urls = urls.filter { u in
            var p = u.standardizedFileURL.deletingLastPathComponent().path
            while p.count > 1 { if all.contains(p) { return false }; p = (p as NSString).deletingLastPathComponent }
            return true
        }
        Scanner.warmProtectedFolders(for: urls)
        for u in urls {
            if IgnoreList.contains(u.path) {
                fail += 1
                if lastErr.isEmpty { lastErr = t("in the Ignore list", "nằm trong danh sách Bỏ qua") }
                continue
            }
            if strict && !Scanner.safeToTrash(u) {
                fail += 1
                if lastErr.isEmpty { lastErr = t("refused, path is outside the safe area", "từ chối, đường dẫn nằm ngoài vùng an toàn") }
                continue
            }
            let size = sizes[u] ?? Scanner.size(u)   // known sizes skip a full re-walk of the folder on the main thread
            var dest: NSURL?
            do { try FileManager.default.trashItem(at: u, resultingItemURL: &dest); ok += 1; lastOK.insert(u)
                 if let d = dest as URL? { moved.append(Journal.Entry(from: u.path, to: d.path, size: size)) } }
            catch {
                // iCloud Drive file: the standard Trash refused, move it into ~/.Trash directly.
                // Only for iCloud Drive on the startup volume: anything else (external or network drive, other errors)
                // is reported, never copied across drives. Source: research/nguon-chinh-thuc/macos-thung-rac.md
                if isICloudDriveOnHomeVolume(u), FileManager.default.fileExists(atPath: u.path), let d = try? moveToUserTrash(u) {
                    ok += 1; lastOK.insert(u)
                    let ns = error as NSError
                    log(t("Trash refused \(u.lastPathComponent) (\(ns.domain) \(ns.code)), moved it into ~/.Trash directly.",
                          "macOS từ chối đưa \(u.lastPathComponent) vào Thùng rác (\(ns.domain) \(ns.code)), đã chuyển thẳng vào ~/.Trash."))
                    moved.append(Journal.Entry(from: u.path, to: d.path, size: size))
                    continue
                }
                fail += 1
                if lastErr.isEmpty {
                    let ns = error as NSError
                    let why: String
                    if !FileManager.default.fileExists(atPath: u.path) { why = t("file no longer exists (already moved?)", "file không còn ở đó (có thể đã xoá trước)") }
                    else if ns.code == NSFileWriteNoPermissionError || ns.code == 513 || ns.code == 257 {
                        why = t("no permission. Open System Settings > Privacy & Security > Full Disk Access, turn Tidymint off and on again", "không có quyền. Vào Cài đặt hệ thống > Quyền riêng tư & Bảo mật > Truy cập toàn bộ ổ đĩa, tắt rồi bật lại Tidymint")
                    } else { why = ns.localizedDescription }
                    lastErr = why
                    let under = (ns.userInfo[NSUnderlyingErrorKey] as? NSError).map { " < \($0.domain) \($0.code)" } ?? ""
                    errDetail = "\(ns.domain) \(ns.code)\(under) at \(u.path)"
                }
            }
        }
        if !lastErr.isEmpty { log("ERROR trash: \(lastErr)" + (errDetail.isEmpty ? "" : " [\(errDetail)]")) }
        if !moved.isEmpty { undoable = Journal.save(Journal.Session(date: Date(), label: label, entries: moved)) }
        return (ok, fail)
    }

    /// Put everything from the last run back where it was (only items still sitting in the Trash).
    func undoLast() {
        guard let s = undoable else { return }
        // Demo sessions live only in memory: never touch the real Undo journal or activity log.
        if Demo.active { undoable = nil; return }
        let needsPassword = s.entries.contains { ((try? FileManager.default.attributesOfItem(atPath: $0.to)[.ownerAccountID] as? NSNumber)?.intValue) == 0 }
        guard confirm(t("Undo the last clean\(sessionName(s))?", "Hoàn tác lần dọn vừa rồi\(sessionName(s))?"),
                      t("\(s.entries.count) items (\(fmt(s.size))) go back to where they were.", "\(s.entries.count) mục (\(fmt(s.size))) sẽ trở về chỗ cũ.")
                        + (needsPassword ? t(" An app installed for every user goes back through Finder: macOS asks for an administrator password in its own window.", " App cài cho mọi tài khoản được Finder trả về: macOS hỏi mật khẩu quản trị trong hộp thoại của macOS.") : ""),
                      t("Put Back", "Trả về chỗ cũ")) else { return }
        let r = Journal.restore(s)
        lastResult = t("Put back \(r.ok) items\(sessionName(s)).", "Đã trả về \(r.ok) mục\(sessionName(s)).") + (r.skipped > 0 ? t(" \(r.skipped) were already gone or replaced.", " \(r.skipped) mục đã mất hoặc đã có file mới ở chỗ cũ.") : "")
        undoNote = (page == .trash ? .trash : (doneInfo?.page ?? page), lastResult)
        log(t("Undo: put back \(r.ok) items, skipped \(r.skipped).", "Hoàn tác: đã trả về \(r.ok) mục, bỏ qua \(r.skipped)."))
        undoable = nil; Journal.clear()
        refreshTrash(); refreshDisk()
    }

    func emptyTrash() {
        guard confirm(t("Empty Trash?", "Đổ Thùng rác?"), t("\(trashCount) items, \(fmt(trashSize)). This cannot be undone.", "\(trashCount) mục, \(fmt(trashSize)). Đổ rồi không lấy lại được."), t("Empty Trash", "Đổ Thùng rác")) else { return }
        // Off the main thread with a long timeout: a large Trash can take Finder minutes, and a 60 s Apple event timeout (-1712)
        // used to be shown as a missing Automation permission while Finder kept emptying.
        let before = trashSize
        Task.detached {
            let r = FinderOps.run("with timeout of 3600 seconds\ntell application \"Finder\" to empty trash\nend timeout")
            await MainActor.run { [weak self] in self?.afterEmptyTrash(r, before: before) }
        }
    }

    private func afterEmptyTrash(_ r: FinderOps.Result, before: Int64) {
        switch r {
        case .cancelled:
            break   // The person cancelled Finder's own confirmation: nothing happened, nothing to report.
        case .notAllowed:
            log("ERROR empty Trash: Automation not allowed")
            _ = confirm(t("Could not empty the Trash", "Chưa đổ được Thùng rác"),
                        t("Allow Tidymint to control Finder in System Settings > Privacy & Security > Automation, then try again.",
                          "Cho phép Tidymint điều khiển Finder trong Cài đặt hệ thống > Quyền riêng tư & Bảo mật > Tự động hoá, rồi thử lại."), "OK")
        case .failed(let msg) where msg.contains("-1712"):
            log("Empty Trash: Finder is still working (timeout)")
            trashLeftNote = t("Finder is still emptying the Trash. The numbers update when it is done.", "Finder vẫn đang đổ Thùng rác. Số liệu sẽ cập nhật khi xong.")
        case .failed(let msg):
            log("ERROR empty Trash: \(msg)")
            _ = confirm(t("Could not empty the Trash", "Chưa đổ được Thùng rác"),
                        t("Finder did not empty it (\(msg)). Try again, or empty it from Finder.", "Finder chưa đổ (\(msg)). Thử lại, hoặc đổ từ Finder."), "OK")
        case .ok:
            log(t("Emptied Trash: \(fmt(before))", "Đã dọn sạch Thùng rác: \(fmt(before))"))
            // Finder can leave items behind (seen 04/11/2026). Check again once Finder is done: if the Trash is empty,
            // Undo can no longer put anything back; if not, say what is left and keep Undo.
            trashLeftNote = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.refreshTrash { [weak self] in
                    guard let self else { return }
                    if self.trashCount == 0 { self.undoable = nil; Journal.clear(); return }
                    self.trashLeftNote = t("Finder did not empty everything: \(self.trashCount) items are still there. Open the Trash in Finder to see them, then empty it again.",
                                           "Finder chưa đổ hết: còn \(self.trashCount) mục. Mở Thùng rác trong Finder để xem, rồi đổ lại.")
                    // Usually an app still holds a file open (seen 08/11/2026: a virtual machine holding files in the
                    // iCloud Trash). Name it, so the person knows what to quit.
                    Task.detached {
                        let who = trashHolders()
                        guard !who.isEmpty else { return }
                        await MainActor.run { [weak self] in
                            guard let self, self.trashLeftNote != nil, self.trashCount > 0 else { return }
                            let names = who.prefix(3).joined(separator: ", ")
                            self.trashLeftNote = t("Finder did not empty everything: \(self.trashCount) items are still there, held open by \(names). Quit it, then empty the Trash again.",
                                                   "Finder chưa đổ hết: còn \(self.trashCount) mục, đang bị \(names) giữ. Tắt app đó rồi đổ lại.")
                        }
                    }
                }
            }
        }
        refreshTrash(); refreshDisk()
    }

}

/// Run lsof (read-only) and return its output, or nil when it could not run. A UTF-8 locale is set because without one
/// lsof prints non-ASCII bytes as \xNN (measured 11/2026 on lsof 4.91: "Dự án" came back as "D\xe1\xbb\xb1 \xc3\xa1n"), and
/// -n -P -l keep it from looking up host, port and user names (no network lookups, and faster).
func lsofOutput(_ args: [String]) -> String? {
    let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
    p.arguments = ["-n", "-P", "-l"] + args
    var env = ProcessInfo.processInfo.environment; env["LC_ALL"] = "en_US.UTF-8"; p.environment = env
    let out = Pipe(); p.standardOutput = out; p.standardError = FileHandle.nullDevice
    guard (try? p.run()) != nil else { return nil }
    let d = out.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
    return String(data: d, encoding: .utf8)
}

/// Names of this user's apps that hold a file open inside a Trash folder. Empty when none or unknown.
func trashHolders() -> [String] {
    guard let s = lsofOutput(["-u", String(getuid()), "-F", "pcn"]) else { return [] }
    var pid: pid_t = 0, cmd = "", found: [String] = []
    for line in s.split(separator: "\n") {
        if line.hasPrefix("p") { pid = pid_t(line.dropFirst()) ?? 0 }
        else if line.hasPrefix("c") { cmd = String(line.dropFirst()) }
        else if line.hasPrefix("n/"), line.contains("/.Trash/") || line.contains("/.Trashes/"), !cmd.isEmpty {
            // The app's own name when macOS knows it (lsof gives the process name, often cut short).
            let name = NSRunningApplication(processIdentifier: pid)?.localizedName ?? cmd
            if !found.contains(name) { found.append(name) }
        }
    }
    return found
}

/// Move a file into ~/.Trash directly (used when the standard Trash refuses, e.g. iCloud Drive files).
/// True for an iCloud Drive file (inside ~/Library/Mobile Documents, or ~/Desktop and ~/Documents synced to iCloud) on the same volume as the home folder.
func isICloudDriveOnHomeVolume(_ u: URL) -> Bool {
    let home = URL(fileURLWithPath: NSHomeDirectory())
    let icloud = home.appendingPathComponent("Library/Mobile Documents").resolvingSymlinksInPath().path + "/"
    // Also iCloud "Desktop & Documents Folders": ~/Desktop and ~/Documents stay in place but are iCloud items.
    var fresh = URL(fileURLWithPath: u.path); fresh.removeAllCachedResourceValues()
    let ubiquitous = (try? fresh.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) == true
    guard ubiquitous || u.resolvingSymlinksInPath().path.hasPrefix(icloud) else { return false }
    let a = try? u.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier as? NSObject
    let b = try? home.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier as? NSObject
    guard let a, let b else { return false }
    return a.isEqual(b)
}

func moveToUserTrash(_ u: URL) throws -> URL {
    let trash = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash")
    var dest = trash.appendingPathComponent(u.lastPathComponent)
    var n = 2
    let base = u.deletingPathExtension().lastPathComponent, ext = u.pathExtension
    while FileManager.default.fileExists(atPath: dest.path) {
        dest = trash.appendingPathComponent(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"); n += 1
    }
    try FileManager.default.moveItem(at: u, to: dest)
    return dest
}

/// Undo journal: where the last clean moved each item. One session only, stored as JSON next to the activity log.
enum Journal {
    struct Entry: Codable { let from: String; let to: String; let size: Int64 }
    struct Session: Codable {
        let date: Date; let label: String; let entries: [Entry]
        var size: Int64 { entries.reduce(0) { $0 + $1.size } }
    }
    static var path: String { Stats.dir + "/last-clean.json" }
    static func load() -> Session? {
        guard let d = FileManager.default.contents(atPath: path), let s = try? JSONDecoder().decode(Session.self, from: d) else { return nil }
        // Only worth offering while something from that run is still in the Trash.
        return s.entries.contains { FileManager.default.fileExists(atPath: $0.to) } ? s : nil
    }
    @discardableResult static func save(_ s: Session) -> Session {
        _ = Stats.path
        if let d = try? JSONEncoder().encode(s) { try? d.write(to: URL(fileURLWithPath: path)) }
        return s
    }
    static func clear() { try? FileManager.default.removeItem(atPath: path) }
    static func restore(_ s: Session) -> (ok: Int, skipped: Int) {
        var ok = 0, skipped = 0
        let fm = FileManager.default
        // Parents first: putting a child back creates its parent folder, and the parent's own entry would then be skipped.
        let entries = s.entries.enumerated().sorted { a, b in
            let da = a.element.from.split(separator: "/").count, db = b.element.from.split(separator: "/").count
            return da != db ? da < db : a.offset < b.offset
        }.map(\.element)
        for e in entries {
            // lstat, not fileExists: a relative symlink is dangling while it sits in the Trash, and fileExists follows links
            // (seen 10/11/2026: Ollama's manifests-v2 link was skipped on Undo).
            func present(_ p: String) -> Bool { (try? fm.attributesOfItem(atPath: p)) != nil }
            guard present(e.to), !present(e.from) else { skipped += 1; continue }
            try? fm.createDirectory(atPath: (e.from as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            do { try fm.moveItem(atPath: e.to, toPath: e.from); ok += 1 } catch {
                // An app owned by root needs a password to go back too: Finder moves it and macOS asks. Same name only.
                let folder = (e.from as NSString).deletingLastPathComponent
                if (e.to as NSString).lastPathComponent == (e.from as NSString).lastPathComponent,
                   case .ok = FinderOps.move(e.to, into: folder), fm.fileExists(atPath: e.from) { ok += 1 } else { skipped += 1 }
            }
        }
        return (ok, skipped)
    }
}
