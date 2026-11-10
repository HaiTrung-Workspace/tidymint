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

// MARK: - Applications (Uninstaller, Leftovers, Installers)

struct AppEntry: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let bundleID: String
    var size: Int64
    var lastUsed: Date?
    var related: [CleanItem] = []
    /// Listed but not removable here: protected by the user, or on the read-only macOS volume.
    var lock: String? = nil
    /// Chromium browsers "install" a website as a tiny launcher app (bundle id <browser>.app.<id>, e.g. Google Password
    /// Manager, Docs). It only opens the site; the data stays in the browser profile and the account, which Tidymint never touches.
    var webAppBrowser: String? {
        let hosts = [("com.google.Chrome", "Chrome"), ("com.google.Chrome.beta", "Chrome"), ("com.microsoft.edgemac", "Edge"),
                     ("com.brave.Browser", "Brave"), ("org.chromium.Chromium", "Chromium"), ("com.vivaldi.Vivaldi", "Vivaldi"),
                     ("com.coccoc.Coccoc", "Cốc Cốc"), ("com.operasoftware.Opera", "Opera")]
        guard let b = hosts.first(where: { bundleID.hasPrefix($0.0 + ".app.") })?.1 else { return nil }
        // Only the real launcher shape counts: a single app_mode_loader binary, nothing else that could hold data.
        let bin = url.appendingPathComponent("Contents/MacOS")
        guard (try? FileManager.default.contentsOfDirectory(atPath: bin.path)) == ["app_mode_loader"] else { return nil }
        return b
    }
    /// Installed for every user (owned by root, as the App Store and most .pkg installers do): moving it to the Trash needs an
    /// administrator password, which macOS asks for in Finder. Tidymint never asks for or handles passwords.
    var needsAdmin: Bool {
        let owner = (try? FileManager.default.attributesOfItem(atPath: url.path)[.ownerAccountID] as? NSNumber)?.intValue
        return owner == 0 || access(url.path, W_OK) != 0
    }
    var fromAppStore: Bool { FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/_MASReceipt").path) }
}
func adminNote(_ a: AppEntry) -> String {
    t("\(a.name) was installed for every user of this Mac\(a.fromAppStore ? " by the App Store" : ""). When you uninstall it, Tidymint asks Finder to move it to the Trash and macOS asks for an administrator password in its own window. Tidymint never asks for or sees your password.\(a.fromAppStore ? "" : " If the app came with its own uninstaller, use that first: Apple says it also removes the helpers the app installed.")",
      "\(a.name) được cài cho mọi tài khoản trên máy\(a.fromAppStore ? " qua App Store" : ""). Khi gỡ, Tidymint nhờ Finder chuyển app vào Thùng rác và macOS hỏi mật khẩu quản trị trong hộp thoại của macOS. Tidymint không hỏi và không thấy mật khẩu của bạn.\(a.fromAppStore ? "" : " Nếu app có trình gỡ cài đặt riêng, dùng trình đó trước: theo Apple, cách này gỡ cả các thành phần phụ app đã cài.")")
}

/// Finder does the moves that need an administrator password: macOS shows its own password window, Tidymint never sees it.
/// Runs osascript as a child process so the wait for the password never blocks Tidymint's window.
enum FinderOps {
    enum Result { case ok(String), cancelled, notAllowed, failed(String) }
    static func q(_ p: String) -> String { p.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") }
    static func run(_ script: String) -> Result {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript"); p.arguments = ["-e", script]
        let out = Pipe(), err = Pipe(); p.standardOutput = out; p.standardError = err
        do { try p.run() } catch { return .failed(error.localizedDescription) }
        let o = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let e = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        p.waitUntilExit()
        if p.terminationStatus == 0 { return .ok(o) }
        if e.contains("-128") { return .cancelled }
        if e.contains("-1743") { return .notAllowed }
        return .failed(e.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    /// Moves one item to the Trash through Finder. Returns the item's path in the Trash.
    static func trash(_ path: String) -> Result {
        run("with timeout of 600 seconds\ntell application \"Finder\"\nset r to delete (POSIX file \"\(q(path))\" as alias)\nreturn POSIX path of (r as alias)\nend tell\nend timeout")
    }
    /// Moves an item back into a folder through Finder (Undo for items that needed a password to leave).
    static func move(_ path: String, into folder: String) -> Result {
        run("with timeout of 600 seconds\ntell application \"Finder\"\nset r to move (POSIX file \"\(q(path))\" as alias) to (POSIX file \"\(q(folder))\" as alias)\nreturn POSIX path of (r as alias)\nend tell\nend timeout")
    }
}

/// Status tag (warning, state, "Keep"): one look everywhere. Tags sit in a column at the RIGHT of a row, before the size,
/// so they line up from row to row (style guide 1f), never after a name or path of varying length.
struct StatusTag: View {
    let text: String; let color: Color
    init(_ text: String, _ color: Color) { self.text = text; self.color = color }
    var body: some View {
        Text(text).font(.system(size: fs(10), weight: .semibold)).foregroundColor(color)
            .padding(.horizontal, 6).padding(.vertical, 1).background(Capsule().fill(color.opacity(0.15))).fixedSize()
    }
}

/// Small grey tag for a browser web app, with the reassurance as a tooltip.
struct WebAppTag: View {
    let browser: String
    var body: some View {
        Text(t("\(browser) web app", "Web app của \(browser)")).font(.system(size: fs(10), weight: .semibold)).foregroundColor(Theme.sub)
            .padding(.horizontal, 6).padding(.vertical, 1).background(Capsule().fill(Theme.sub.opacity(0.15)))
            .fixedSize()
            .tip(webAppNote(browser))
    }
}
func webAppNote(_ browser: String) -> String {
    t("A shortcut \(browser) made when you installed a website as an app. It holds only an icon and a launcher. Passwords and site data are kept by \(browser) in your account or on this Mac, not here. Deleting the shortcut does not remove the app from \(browser), which recreates it the next time you open the app. To remove it completely: open the app › ⋮ menu › Uninstall.",
      "Lối tắt do \(browser) tạo khi bạn cài một trang web thành app, chỉ chứa icon và lệnh mở trang. Mật khẩu và dữ liệu trang được \(browser) lưu trong tài khoản hoặc trên máy, không nằm ở đây. Xoá lối tắt không gỡ app khỏi \(browser), lần sau mở app \(browser) sẽ tạo lại. Muốn gỡ hẳn: mở app › menu ⋮ › Gỡ cài đặt.")
}

enum Apps {
    static let L = Scanner.lib
    /// Tidymint itself is the only app left off the list (it cannot move itself to the Trash while running;
    /// the install page explains how to remove it).
    static let ownPrefixes = ["com.haitrung.diskcleanup", Bundle.main.bundleIdentifier ?? "com.haitrung.diskcleanup"]
    static func isOwn(_ id: String) -> Bool { ownPrefixes.contains { id.hasPrefix($0) } }
    /// Why an app is listed but cannot be uninstalled here, or nil.
    static func lockReason(_ u: URL, id: String, name: String) -> String? {
        if Prefs.protectedKeywords.contains(where: { !$0.isEmpty && (u.path.localizedCaseInsensitiveContains($0) || id.localizedCaseInsensitiveContains($0) || name.localizedCaseInsensitiveContains($0)) }) {
            return t("Protected", "Được bảo vệ")
        }
        if (try? u.resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly) == true { return t("Part of macOS", "Thuộc macOS") }
        // System Integrity Protection marks some apps outside the system volume as restricted (cannot be moved).
        var st = stat()
        if lstat(u.path, &st) == 0, st.st_flags & UInt32(SF_RESTRICTED) != 0 { return t("Part of macOS", "Thuộc macOS") }
        return nil
    }

    static func list() -> [AppEntry] {
        var urls: [URL] = []
        for r in [URL(fileURLWithPath: "/Applications"), Scanner.home.appendingPathComponent("Applications")] {
            for c in Scanner.children(r) {
                if c.pathExtension == "app" { urls.append(c) }
                else if (try? c.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    urls += Scanner.children(c).filter { $0.pathExtension == "app" }
                }
            }
        }
        var out = [AppEntry?](repeating: nil, count: urls.count)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: urls.count) { i in
            let u = urls[i]
            guard let b = Bundle(url: u), let id = b.bundleIdentifier, !isOwn(id) else { return }
            let name = (b.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (b.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? u.deletingPathExtension().lastPathComponent
            let last = NSMetadataItem(url: u)?.value(forAttribute: "kMDItemLastUsedDate") as? Date
            var e = AppEntry(url: u, name: u.deletingPathExtension().lastPathComponent.isEmpty ? name : u.deletingPathExtension().lastPathComponent,
                             bundleID: id, size: Cloud.localSize(u.path), lastUsed: last)
            e.lock = lockReason(u, id: id, name: e.name)
            lock.lock(); out[i] = e; lock.unlock()
        }
        return out.compactMap { $0 }.sorted { $0.size > $1.size }
    }

    /// Folder names shared by many apps of one vendor, or too generic to prove ownership. Never offered by name.
    static let sharedNames: Set<String> = ["google", "microsoft", "adobe", "jetbrains", "mozilla", "apple", "logs", "cache", "caches", "data", "app", "application support"]

    /// Files that belong to an app. Bundle-id matches are pre-selected; name matches are listed but left for the user,
    /// and anything holding a database is never pre-selected (the data-loss pattern behind most cleaner complaints).
    /// `strict` (an app the user trashed in Finder): bundle-id matches only, and nothing is pre-selected.
    static func related(_ a: AppEntry, strict: Bool = false) -> [CleanItem] {
        let id = a.bundleID, n = a.name
        var byID: [URL] = [
            L.appendingPathComponent("Application Support/\(id)"),
            L.appendingPathComponent("Caches/\(id)"),
            L.appendingPathComponent("Preferences/\(id).plist"),
            L.appendingPathComponent("Containers/\(id)"),
            L.appendingPathComponent("Application Scripts/\(id)"),
            L.appendingPathComponent("Saved Application State/\(id).savedState"),
            L.appendingPathComponent("HTTPStorages/\(id)"), L.appendingPathComponent("HTTPStorages/\(id).binarycookies"),
            L.appendingPathComponent("WebKit/\(id)"),
        ]
        // The user's own cache and temp folders under /private/var/folders (confstr(3): cache is never cleaned by the
        // system, temp files unused for 3 days may be). Only the folder named exactly like this app's bundle id.
        for key in [_CS_DARWIN_USER_CACHE_DIR, _CS_DARWIN_USER_TEMP_DIR] {
            var buf = [CChar](repeating: 0, count: 1024)
            if confstr(key, &buf, buf.count) > 0, !id.isEmpty { byID.append(URL(fileURLWithPath: String(cString: buf)).appendingPathComponent(id)) }
        }
        // Whole-id matches only: "com.x.App" must not take "com.x.AppBeta.plist" or "group.com.y.com.x.AppOther"
        // (seen in review 11/2026: VS Code and VS Code Insiders).
        byID += Scanner.children(L.appendingPathComponent("Group Containers")).filter { let n = $0.lastPathComponent; return n == id || n.hasSuffix("." + id) }
        byID += Scanner.children(L.appendingPathComponent("LaunchAgents")).filter { let n = $0.lastPathComponent; return n == id + ".plist" || n.hasPrefix(id + ".") }
        // App extensions (widgets, Safari, share extensions) get sandbox folders under their own bundle ids, which
        // start with the app's id ("app.x.Y.widget"). Read those ids from the app's own .appex bundles, and also match
        // "<id>." in Containers and Application Scripts, so a removed app leaves none of them behind.
        if !id.isEmpty {
            var extIDs = Set<String>()
            for dir in ["Contents/PlugIns", "Contents/Extensions"] {
                for u in Scanner.children(a.url.appendingPathComponent(dir)) where u.pathExtension == "appex" {
                    // Read from Info.plist: Bundle(url:) caches, and may answer for a copy that has moved.
                    if let b = TrashHint.plistID(u)?.id { extIDs.insert(b) }
                }
            }
            for d in ["Containers", "Application Scripts"] {
                byID += Scanner.children(L.appendingPathComponent(d)).filter {
                    let n = $0.lastPathComponent
                    return n.hasPrefix(id + ".") || extIDs.contains(n)
                }
            }
        }
        // A folder that is, or sits under, the id of another app still installed ("com.x.App.pro" next to "com.x.App",
        // an App Store edition "….MacAppStore") belongs to that app: never offered here. Found by the 11/2026 self-test.
        let others = TrashHint.installedIDs().subtracting([id])
        byID.removeAll { u in
            var n = u.lastPathComponent
            for ext in [".plist", ".savedState", ".binarycookies"] where n.hasSuffix(ext) { n = String(n.dropLast(ext.count)) }
            // Only ids more specific than this app's: while "com.x.App" is installed, "com.x.App.pro.widget" still goes with "com.x.App.pro".
            if n == id { return false }
            if others.contains(where: { n == $0 || ($0.hasPrefix(id + ".") && n.hasPrefix($0 + ".")) }) { return true }
            // The same for an app installed outside the Applications folders (LaunchServices knows those).
            guard n.hasPrefix(id + ".") else { return false }
            var parts = n.split(separator: ".").map(String.init)
            while parts.count > id.split(separator: ".").count {
                let cand = parts.joined(separator: ".")
                if NSWorkspace.shared.urlsForApplications(withBundleIdentifier: cand).contains(where: { !$0.path.contains("/.Trash") && !$0.path.hasPrefix(a.url.path + "/") && FileManager.default.fileExists(atPath: $0.path) }) { return true }
                parts.removeLast()
            }
            return false
        }
        var byName: [URL] = []
        if !strict && n.count >= 4 && !sharedNames.contains(n.lowercased()) {
            byName = ["Application Support", "Caches", "Logs"].map { L.appendingPathComponent("\($0)/\(n)") }
        }
        var seen = Set<String>(), out: [CleanItem] = []
        let groupRoot = L.appendingPathComponent("Group Containers").path + "/"
        let dataRoots = ["Containers", "Application Support"].map { L.appendingPathComponent($0).path + "/" } + [groupRoot]
        for (list, weak) in [(byID, false), (byName, true)] {
            for u in list where FileManager.default.fileExists(atPath: u.path) && !seen.contains(u.path) && !Scanner.blocked(u.path) {
                seen.insert(u.path)
                // App data folders hide their database a few levels down, so look deeper there.
                let deep = dataRoots.contains { u.path.hasPrefix($0) }
                let db = deep ? Scanner.holdsDatabaseDeep(u) : Scanner.holdsDatabase(u)
                // Group Containers are shared by apps of the same developer and macOS never removes them: listed, not ticked.
                let shared = u.path.hasPrefix(groupRoot)
                var it = CleanItem(url: u, size: Cloud.localSize(u.path), selected: !strict && !weak && !db && !shared)
                it.nameMatch = weak; it.hasDB = db
                if shared && !db { it.reason = t("Shared by apps from the same developer, check first", "Dùng chung cho các app cùng hãng, kiểm tra trước") }
                out.append(it)
            }
        }
        return out.sorted { $0.size > $1.size }
    }

    static func leftovers() -> [CleanItem] {
        let installed = Set(list().map(\.bundleID))
        let vendors = Set(installed.map { $0.split(separator: ".").prefix(2).joined(separator: ".") })
        let dirs = ["Containers", "Application Scripts", "Saved Application State", "HTTPStorages", "WebKit", "Caches", "Preferences", "Application Support"]
        let re = try! NSRegularExpression(pattern: "^[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+){2,}$")
        var out: [CleanItem] = []
        for d in dirs {
            for u in Scanner.children(L.appendingPathComponent(d)) {
                var id = u.lastPathComponent
                for ext in [".plist", ".savedState", ".binarycookies"] where id.hasSuffix(ext) { id = String(id.dropLast(ext.count)) }
                guard re.firstMatch(in: id, range: NSRange(id.startIndex..., in: id)) != nil else { continue }
                let vendor = id.split(separator: ".").prefix(2).joined(separator: ".")
                let shared = ["group.", "systemgroup.", "org.cups.", "org.sparkle-project.", "net.java.", "com.oracle.", "org.python.", "com.microsoft.autoupdate"]
                if isOwn(id) || id.contains(".apple.") || shared.contains(where: { id.hasPrefix($0) }) || installed.contains(id) { continue }
                // Extensions and helpers of an installed app ("net.whatsapp.WhatsApp.Intents", "com.microsoft.VSCode.ShipIt") are not leftovers.
                if installed.contains(where: { id.hasPrefix($0 + ".") }) { continue }
                if NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil { continue }
                if Scanner.skip(u.path) { continue }
                let s = Cloud.localSize(u.path)
                guard s > 0 else { continue }
                let db = ["Containers", "Application Support"].contains(d) ? Scanner.holdsDatabaseDeep(u) : Scanner.holdsDatabase(u)
                // Only what an app rebuilds is ticked; its data and settings wait for the user (they may reinstall).
                let rebuildable = ["Caches", "Saved Application State", "HTTPStorages", "WebKit"].contains(d)
                let sibling = vendors.contains(vendor)
                var it = CleanItem(url: u, size: s, selected: rebuildable && !db && !sibling); it.hasDB = db
                if sibling { it.reason = t("Another app from this maker is installed, may be shared", "Còn app khác cùng hãng trên máy, có thể dùng chung") }
                else if !rebuildable && !db { it.reason = t("App data or settings, keep it if you may reinstall", "Dữ liệu hoặc cài đặt của app, giữ lại nếu có thể cài lại") }
                out.append(it)
            }
        }
        return out.sorted { $0.size > $1.size }
    }

    static func installers() -> [CleanItem] {
        var out: [CleanItem] = []
        let exts = ["dmg", "pkg", "mpkg", "xip"]
        for r in ["Downloads", "Desktop", "Documents"].map({ Scanner.home.appendingPathComponent($0) }) {
            guard let en = FileManager.default.enumerator(at: r, includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
                                                          options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, _ in true }) else { continue }
            for case let f as URL in en {
                if en.level > 3 { en.skipDescendants(); continue }
                guard exts.contains(f.pathExtension.lowercased()), !Scanner.skip(f.path) else { continue }
                let v = try? f.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .addedToDirectoryDateKey, .contentModificationDateKey])
                let s = Int64(v?.totalFileAllocatedSize ?? 0)
                // Ticked only in Downloads or Desktop and only when added more than 14 days ago; Documents is where people keep things.
                let added = v?.addedToDirectoryDate ?? v?.contentModificationDate ?? Date()
                let inDocs = r.lastPathComponent == "Documents"
                let old = added < Date().addingTimeInterval(-14 * 86400)
                let inProj = Prefs.inProject(f.path)
                var it = CleanItem(url: f, size: s, selected: !inDocs && old && !inProj)
                it.date = added
                if inProj { it.reason = t("Inside a project folder", "Nằm trong thư mục dự án") }
                else if inDocs { it.reason = t("In Documents, you may be keeping it", "Nằm trong Documents, có thể bạn đang giữ") }
                else if !old { it.reason = t("Added in the last 14 days", "Mới tải trong 14 ngày qua") }
                out.append(it)
            }
        }
        return out.sorted { $0.size > $1.size }
    }
}

// MARK: - Uninstaller page

struct AppsView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(t("Uninstaller", "Gỡ app")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text)
                Spacer()
                Picker("", selection: $vm.appsTab) {
                    Text(t("Apps", "App") + " (\(vm.apps.count))").tag(0)
                    Text(t("Leftovers", "File sót") + " (\(vm.leftovers.count))").tag(1)
                    Text(t("Installers", "File cài đặt") + " (\(vm.installers.count))").tag(2)
                }.pickerStyle(.segmented).controlSize(.small).fixedSize()
                if vm.appsBusy { ProgressView().controlSize(.small).tint(Theme.text).padding(.leading, 6) }
                Button { vm.scanApps() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.icon).tip(t("Scan again", "Quét lại"), trailing: true).foregroundColor(Theme.text).padding(.leading, 6)
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 10)
            DoneBanner(vm: vm, page: .apps)
            TrashHintCard(vm: vm)
            if !vm.appsMsg.isEmpty {
                Text(vm.appsMsg).font(.system(size: fs(12))).foregroundColor(vm.appsMsgErr ? Theme.warn : Theme.green).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.bottom, 6)
            }
            if vm.appsBusy && vm.apps.isEmpty {
                Scanning(text: t("Looking at your apps...", "Đang xem các app...")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.appsTab == 0 {
                appsTab
            } else {
                listTab(vm.appsTab)
            }
        }
        .onAppear { if vm.apps.isEmpty && !vm.appsBusy { vm.scanApps() } }
    }

    var appsTab: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
            TextField(t("Search apps", "Tìm app"), text: $vm.appsQuery)
                .textFieldStyle(.roundedBorder).controlSize(.small).padding(.horizontal, 12).padding(.top, 8)
            HStack(spacing: 8) {
                Menu {
                    ForEach(0..<6, id: \.self) { f in
                        Button(filterName(f) + " (\(vm.appsMatching(f).count))") { vm.appsFilter = f }
                    }
                } label: {
                    Text(filterName(vm.appsFilter) + " (\(vm.appsMatching(vm.appsFilter).count))").font(.system(size: fs(12), weight: .semibold))
                }.menuStyle(.borderlessButton).fixedSize().padding(.horizontal, 6).padding(.vertical, 3).hoverTile()
                Spacer()
                Menu {
                    Button(t("Size", "Dung lượng")) { vm.appsSort = 0 }
                    Button(t("Name", "Tên")) { vm.appsSort = 1 }
                    Button(t("Last opened", "Lâu không mở")) { vm.appsSort = 2 }
                } label: {
                    Text(t("Sort: ", "Xếp: ") + [t("Size", "Dung lượng"), t("Name", "Tên"), t("Last opened", "Lâu không mở")][vm.appsSort]).font(.system(size: fs(12)))
                }.menuStyle(.borderlessButton).fixedSize().padding(.horizontal, 6).padding(.vertical, 3).hoverTile()
            }.padding(.horizontal, 18).padding(.vertical, 10)
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(vm.appsShown) { a in
                        HStack(spacing: 10) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: a.url.path)).resizable().frame(width: 26, height: 26)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(a.name).foregroundColor(Theme.text).font(.system(size: fs(13))).lineLimit(1)
                                HStack(spacing: 6) {
                                    if let d = a.lastUsed {
                                        Text(t("Last opened ", "Mở lần cuối ") + shortDate(d)).foregroundColor(Theme.sub).font(.system(size: fs(10))).lineLimit(1)
                                    } else {
                                        Text(t("No last-opened date", "Chưa có ngày mở")).foregroundColor(Theme.sub).font(.system(size: fs(10))).lineLimit(1)
                                            .tip(t("macOS (Spotlight) has no record of when this app was last opened.", "macOS (Spotlight) không ghi lại lần mở cuối của app này."))
                                    }
                                }
                            }
                            Spacer(minLength: 8)
                            if let b = a.webAppBrowser { WebAppTag(browser: b) }
                            if let l = a.lock { StatusTag(l, Theme.sub) }
                            Text(fmt(a.size)).foregroundColor(Theme.sub).font(.system(size: fs(12)).monospacedDigit())
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(vm.selApp == a.id ? Theme.cardHi : Color.clear))
                        .hoverBG(8, Theme.ink.opacity(0.07))
                        .contentShape(Rectangle())
                        .onTapGesture { vm.loadRelated(a.id) }
                        .contextMenu { FileMenu(url: a.url, vm: vm, openWith: false, quickLook: false) }
                    }
                }.padding(.horizontal, 12)
            }
            }.frame(width: 320 * uiScale).background(Theme.shade.opacity(0.15))

            if let i = vm.apps.firstIndex(where: { $0.id == vm.selApp }) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: vm.apps[i].url.path)).resizable().frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vm.apps[i].name).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text)
                            Text(vm.apps[i].bundleID).font(.system(size: fs(11))).foregroundColor(Theme.sub)
                        }
                    }.padding(20)
                    if vm.apps[i].needsAdmin {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lock").foregroundColor(Theme.warn)
                            Text(adminNote(vm.apps[i])).font(.system(size: fs(12))).foregroundColor(Theme.sub).fixedSize(horizontal: false, vertical: true)
                        }.padding(.horizontal, 20).padding(.bottom, 12).padding(.top, -8)
                    }
                    if let b = vm.apps[i].webAppBrowser {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle").foregroundColor(Theme.sub)
                            Text(webAppNote(b)).font(.system(size: fs(12))).foregroundColor(Theme.sub).fixedSize(horizontal: false, vertical: true)
                        }.padding(.horizontal, 20).padding(.bottom, 12).padding(.top, -8)
                    }
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            HStack(spacing: 12) {
                                CheckBox(state: 2)
                                Image(nsImage: NSWorkspace.shared.icon(forFile: vm.apps[i].url.path)).resizable().frame(width: 22, height: 22)
                                Text(t("Application", "Ứng dụng")).foregroundColor(Theme.text).font(.system(size: fs(13)))
                                Spacer()
                                Text(fmt(vm.apps[i].size)).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .medium).monospacedDigit())
                            }.padding(.vertical, 6).padding(.horizontal, 12)
                            ForEach($vm.apps[i].related) { $it in ItemRow(item: $it, vm: vm) }
                            if vm.relatedLoading == vm.apps[i].id {
                                Text(t("Looking for related files...", "Đang tìm file liên quan..."))
                                    .font(.system(size: fs(12))).foregroundColor(Theme.sub).padding(12)
                            } else if vm.apps[i].related.isEmpty {
                                Text(t("No related files found in Library.", "Không thấy file liên quan trong Library."))
                                    .font(.system(size: fs(12))).foregroundColor(Theme.sub).padding(12)
                            }
                        }.padding(.horizontal, 12)
                    }
                    HStack {
                        let tot = vm.apps[i].size + vm.apps[i].related.filter(\.selected).reduce(0) { $0 + $1.size }
                        Text(selLabel(1 + vm.apps[i].related.filter(\.selected).count, tot)).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                        Spacer()
                        if let l = vm.apps[i].lock {
                            Text(l == t("Part of macOS", "Thuộc macOS")
                                 ? t("Part of macOS: it sits on the read-only system volume and cannot be removed.", "Thuộc macOS: nằm trên ổ hệ thống chỉ đọc, không gỡ được.")
                                 : t("Protected: matches a word in your protected list.", "Được bảo vệ: khớp một từ trong danh sách bảo vệ của bạn."))
                                .foregroundColor(Theme.sub).font(.system(size: fs(12)))
                        } else {
                            PrimaryButton(title: t("Uninstall", "Gỡ app"), action: { vm.uninstall(vm.apps[i].id) }).disabled(vm.appsBusy || vm.relatedLoading == vm.apps[i].id)
                        }
                    }.padding(.horizontal, 20).padding(.vertical, 14).background(Theme.shade.opacity(0.25))
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "shippingbox").font(.system(size: fs(44))).foregroundStyle(Theme.accent)
                    Text(t("Select an app to see everything it installed.", "Chọn một app để xem mọi thứ nó cài lên máy.")).foregroundColor(Theme.sub)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    func filterName(_ f: Int) -> String {
        [t("All apps", "Tất cả app"), t("Not opened in 6 months", "6 tháng chưa mở"), t("Over 500 MB", "Trên 500 MB"),
         t("From the App Store", "Từ App Store"), t("Other sources", "Nguồn khác"), t("No last-opened date", "Chưa có ngày mở")][f]
    }

    func listTab(_ which: Int) -> some View {
        let items = which == 1 ? $vm.leftovers : $vm.installers
        let sel = (which == 1 ? vm.leftovers : vm.installers).filter(\.selected).reduce(0) { $0 + $1.size }
        return VStack(spacing: 0) {
            Text(which == 1
                 ? t("Files left behind by apps that are no longer installed. Only rebuildable caches are ticked. Apple's own folders and shared frameworks (Java, Python, Sparkle) are not listed.",
                     "File do các app đã gỡ để lại. Chỉ tick sẵn bộ nhớ đệm app tự tạo lại được. Không liệt kê thư mục của Apple và thư viện dùng chung (Java, Python, Sparkle).")
                 : t("Installer files (.dmg, .pkg) in Downloads, Desktop and Documents, up to 3 folders deep. Ticked only in Downloads and Desktop when added more than 14 days ago.",
                     "File cài đặt (.dmg, .pkg) trong Downloads, Desktop, Documents, sâu tối đa 3 tầng thư mục. Chỉ tick sẵn file trong Downloads, Desktop đã tải hơn 14 ngày."))
                .font(.system(size: fs(12))).foregroundColor(Theme.sub).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.bottom, 8)
            if items.wrappedValue.isEmpty {
                Text(t("Nothing found.", "Không tìm thấy gì.")).foregroundColor(Theme.sub).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(items) { $it in ItemRow(item: $it, vm: vm).background(RoundedRectangle(cornerRadius: 10).fill(Theme.card)) }
                    }.padding(.horizontal, 24)
                }
            }
            HStack {
                Text(selLabel((which == 1 ? vm.leftovers : vm.installers).filter(\.selected).count, sel)).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                Spacer()
                PrimaryButton(title: t("Move to Trash", "Chuyển vào Thùng rác"), action: { vm.cleanList(which) }, disabled: sel == 0)
            }.padding(.horizontal, 24).padding(.vertical, 14).background(Theme.shade.opacity(0.25))
        }
    }
}
