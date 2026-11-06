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

// MARK: - ViewModel

enum Page: String, CaseIterable, Identifiable {
    case smart = "Smart Scan", cleanup = "Cleanup", byapp = "Clean by App", large = "Large & Old Files", lens = "Space Lens", trash = "Trash", ignore = "Ignore List", cloud = "Cloud Cleanup", settings = "Settings", apps = "Uninstaller", dupes = "Duplicates", startup = "Startup", stats = "Stats", contact = "Contact", windows = "Mintangle", shelf = "Mintdrop"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .smart: return t("Clean Now", "Dọn ngay")
        case .cleanup: return t("Cleanup Details", "Dọn rác chi tiết")
        case .byapp: return t("Clean by App", "Dọn theo ứng dụng")
        case .large: return t("Large Files", "File lớn")
        case .lens: return t("Space Lens", "Bản đồ ổ đĩa")
        case .trash: return t("Trash", "Thùng rác")
        case .ignore: return t("Ignore List", "Bỏ qua")
        case .cloud: return t("Cloud", "Đám mây")
        case .settings: return t("Settings", "Cài đặt")
        case .apps: return t("Uninstaller", "Gỡ app")
        case .dupes: return t("Duplicates", "File trùng")
        case .startup: return t("Startup Items", "Khởi động cùng máy")
        case .stats: return t("Statistics", "Thống kê")
        case .contact: return t("Contact", "Liên hệ")
        case .windows: return "Mintangle"
        case .shelf: return "Mintdrop"
        }
    }
    var icon: String {
        switch self {
        case .smart: return "sparkles"
        case .cleanup: return "trash.slash"
        case .byapp: return "square.grid.2x2"
        case .large: return "scalemass"
        case .lens: return "chart.pie"
        case .trash: return "trash"
        case .ignore: return "eye.slash"
        case .cloud: return "icloud"
        case .settings: return "gearshape"
        case .apps: return "shippingbox"
        case .dupes: return "square.on.square"
        case .startup: return "power"
        case .stats: return "chart.bar"
        case .contact: return "envelope"
        case .windows: return "rectangle.lefthalf.inset.filled"
        case .shelf: return "tray.and.arrow.down"
        }
    }
}

enum Phase { case idle, scanning, summary, review, done }

@MainActor final class VM: ObservableObject {
    @Published var page: Page = .smart {
        didSet {
            if VM.advancedPages.contains(page), !advancedOpen { advancedOpen = true }
            fresh.remove(page)
            hoverFile = nil; fileQL = nil   // a row of the old page may never report the pointer leaving
            if page == .settings { seenVersion = newVersion }
        }
    }
    /// Sidebar badges: pages whose scan finished while another page was open, until they are opened.
    @Published var fresh = Set<Page>()
    @Published var seenVersion: String? = nil
    func markDone(_ p: Page) { if page != p { fresh.insert(p) } }
    func isBusy(_ p: Page) -> Bool {
        switch p {
        case .smart, .cleanup: return phase == .scanning
        case .large: return largePhase == .scanning
        case .dupes: return dupBusy
        case .lens: return lensBusy
        case .cloud: return cloudBusy
        case .byapp: return appBusy
        case .apps: return appsBusy
        case .startup: return launchBusy
        default: return false
        }
    }
    var hasUnseenUpdate: Bool { newVersion != nil && seenVersion != newVersion && page != .settings }
    /// Things waiting in Settings: a new version not seen yet, Full Disk Access still off. Shown as a number on the Settings row.
    var settingsPending: Int { (hasUnseenUpdate ? 1 : 0) + (fullDiskAccess ? 0 : 1) }
    @Published var phase: Phase = .idle
    @Published var cats: [Category] = []
    @Published var large: [CleanItem] = []
    @Published var largePhase: Phase = .idle
    @Published var trashSize: Int64 = 0
    @Published var trashCount = 0
    /// What is in the Trash on each external drive (name, items, size); the Mac's own Trash is the rest.
    @Published var trashOnDrives: [(String, Int, Int64)] = []
    /// Set after Empty Trash when something stayed behind, so the page can say so instead of looking stuck.
    @Published var trashLeftNote: String? = nil
    @Published var freeGB: Double = 0
    @Published var totalGB: Double = 0
    @Published var lastResult = ""
    @Published var ignored: [String] = IgnoreList.paths
    // Space Lens
    @Published var lensPath: [URL] = []
    @Published var lensNodes: [Node] = []
    @Published var lensBusy = false
    @Published var hoverNode: UUID? = nil
    @Published var lang: String = appLang
    static let advancedPages: Set<Page> = [.large, .dupes, .lens, .cloud, .startup, .stats, .ignore]
    /// Folded on every launch so the first screen stays simple; opens when the user asks or an advanced page is shown.
    @Published var advancedOpen: Bool = false
    func setAdvanced(_ on: Bool) { advancedOpen = on }

    func setLang(_ l: String) { appLang = l; UserDefaults.standard.set(l, forKey: "lang"); lang = l }
    @Published var textSize: String = appTextSize
    func setTextSize(_ v: String) {
        let old = uiScale
        appTextSize = v; UserDefaults.standard.set(v, forKey: "textSize"); textSize = v
        theme = appTheme   // the root view is keyed on this; re-assigning rebuilds every view with the new sizes
        fitWindow(from: old)
    }
    /// After a text-size change, grow or shrink the main window by the same ratio, so the layout keeps its proportions
    /// instead of leaving empty space (Small) or squeezing (Large). Top-left corner stays put; never larger than the screen.
    /// Like System Settings: the window widens only up to a set width (sidebar + a ~950 pt content area, scaled with the
    /// text size), so content never floats in wide empty margins. Set on the NSWindow directly: a SwiftUI max frame with
    /// content-size resizability made the scene update loop and crash (04/11/2026).
    static var maxWindowWidth: CGFloat { (120 + 140 * uiScale) + 950 * uiScale }
    func applyWindowLimits() {
        guard let w = mainWindow else { return }
        // SwiftUI rewrites contentMaxSize on every layout, so set the frame limit (maxSize) too, and clamp after any
        // resize as a last guard (e.g. a resize that does not go through the size limits).
        w.maxSize = NSSize(width: VM.maxWindowWidth, height: CGFloat.greatestFiniteMagnitude)
        w.contentMaxSize = NSSize(width: VM.maxWindowWidth, height: CGFloat.greatestFiniteMagnitude)
        clampWindow(w)
        if resizeObs == nil {
            resizeObs = NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: w, queue: .main) { [weak self] n in
                MainActor.assumeIsolated { if let w = n.object as? NSWindow { self?.clampWindow(w) } }
            }
        }
    }
    private var resizeObs: NSObjectProtocol?
    func clampWindow(_ w: NSWindow) {
        guard w.frame.width > VM.maxWindowWidth + 1 else { return }
        var f = w.frame; f.size.width = VM.maxWindowWidth; w.setFrame(f, display: true)
    }
    /// The main window, handed over by WindowGrabber (SwiftUI's window has no stable title or identifier to search by).
    weak var mainWindow: NSWindow?
    func fitWindow(from old: CGFloat) {
        applyWindowLimits()
        guard let w = mainWindow, old > 0 else { return }
        let r = uiScale / old
        guard abs(r - 1) > 0.01 else { return }
        let vf = (w.screen ?? NSScreen.main)?.visibleFrame ?? w.frame
        var f = w.frame
        let top = f.maxY
        f.size.width = min(vf.width, VM.maxWindowWidth, max(980 * uiScale, f.width * r))
        f.size.height = min(vf.height, max(600, f.height * r))
        f.origin.y = max(vf.minY, top - f.height)
        f.origin.x = min(max(vf.minX, f.origin.x), vf.maxX - f.width)
        w.setFrame(f, display: true, animate: true)
    }
    @Published var theme: String = appTheme
    func setTheme(_ id: String) {
        appTheme = id; UserDefaults.standard.set(id, forKey: "theme"); theme = id
        NSApp.applicationIconImage = dockIcon(Theme.p)
    }
    @Published var projects: [String] = Prefs.projectFolders
    func addProjectFolder() {
        let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false; p.allowsMultipleSelection = true
        p.prompt = t("Add", "Thêm")
        guard p.runModal() == .OK else { return }
        var list = Prefs.projectFolders
        for u in p.urls { Prefs.rememberVolume(of: u.path); let q = Prefs.canonical(u.path); if !list.contains(q) { list.append(q) } }
        Prefs.projectFolders = list; projects = list
    }
    func removeProjectFolder(_ path: String) { Prefs.projectFolders.removeAll { $0 == path }; projects = Prefs.projectFolders }
    @Published var extras: [String] = Prefs.extraFolders
    /// Extra folders whose drive is not plugged in right now; refreshed when the list changes and when Settings opens.
    @Published var extrasMissing = Set<String>()
    func refreshExtras() { extrasMissing = Set(Prefs.extraFolders.filter { Prefs.resolveExtra($0) == nil }) }
    func addExtraFolder() {
        let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false; p.allowsMultipleSelection = true
        p.directoryURL = URL(fileURLWithPath: "/Volumes"); p.prompt = t("Add", "Thêm")
        guard p.runModal() == .OK else { return }
        var list = Prefs.extraFolders
        var ids = Prefs.extraVolumeIDs
        var refused: [Prefs.ExtraCheck] = []
        for u in p.urls {
            let c = Prefs.extraCheck(u)
            guard c == .ok else { refused.append(c); continue }
            let path = u.resolvingSymlinksInPath().path
            if !list.contains(path) { list.append(path) }
            if Prefs.onOtherDrive(path), let id = (try? u.resourceValues(forKeys: [.volumeUUIDStringKey]))?.volumeUUIDString { ids[path] = id; Prefs.rememberVolume(of: path) }
        }
        Prefs.extraVolumeIDs = ids; Prefs.extraFolders = list; extras = list; refreshExtras()
        if let c = refused.first {
            let a = NSAlert()
            switch c {
            case .network:
                a.messageText = t("Network drives are not supported", "Chưa hỗ trợ ổ mạng")
                a.informativeText = t("macOS has no Trash on a network drive, so Tidymint could not move files there safely.", "macOS không có Thùng rác trên ổ mạng, nên Tidymint không chuyển file ở đó vào Thùng rác một cách an toàn được.")
            case .readOnly:
                a.messageText = t("This drive is read-only", "Ổ này chỉ đọc")
                a.informativeText = t("Files on it cannot be moved to the Trash (common for NTFS drives formatted on Windows).", "Không chuyển được file trên ổ này vào Thùng rác (hay gặp với ổ NTFS định dạng trên Windows).")
            case .timeMachine:
                a.messageText = t("This is a Time Machine backup", "Đây là ổ sao lưu Time Machine")
                a.informativeText = t("macOS manages old backups on its own. Remove them in Time Machine, not here.", "macOS tự quản lý bản sao lưu cũ. Muốn xoá thì làm trong Time Machine, không làm ở đây.")
            default:
                a.messageText = t("Pick an external drive or a folder in your home folder", "Chọn một ổ ngoài hoặc một thư mục trong thư mục người dùng")
                a.informativeText = t("Library, system folders and the startup disk as a whole are not scanned.", "Tidymint không quét thư mục Library, thư mục hệ thống hay cả ổ khởi động.")
            }
            a.runModal()
        }
    }
    func removeExtraFolder(_ path: String) {
        Prefs.extraFolders.removeAll { $0 == path }; Prefs.extraVolumeIDs[path] = nil; extras = Prefs.extraFolders; refreshExtras()
    }
    @Published var crossKeep: String = Prefs.crossKeep
    func setCrossKeep(_ v: String) { Prefs.crossKeep = v; crossKeep = v }

    // Monitor (menu bar)
    @Published var ramUsed: Double = 0
    @Published var ramTotal: Double = 0
    @Published var lowSpaceGB: Double = UserDefaults.standard.object(forKey: "lowSpaceGB") as? Double ?? 30
    @Published var ramAlert: Bool = UserDefaults.standard.object(forKey: "ramAlert") as? Bool ?? true
    /// Daily check for a new version (asked for on MacRumors, 04/11/2026). Off: no automatic check; "Check Now" still works.
    @Published var autoUpdateCheck: Bool = UserDefaults.standard.object(forKey: "autoUpdateCheck") as? Bool ?? true
    @Published var openAtLogin: Bool = SMAppService.mainApp.status == .enabled
    var lastDiskAlert = Date.distantPast, lastRamAlert = Date.distantPast
    var timer: Timer?

    // Applications
    @Published var apps: [AppEntry] = []
    @Published var appsBusy = false
    @Published var selApp: UUID? = nil
    @Published var appsTab = 0            // 0 apps, 1 leftovers, 2 installers
    @Published var leftovers: [CleanItem] = []
    @Published var installers: [CleanItem] = []
    @Published var appsMsg = ""
    @Published var appsMsgErr = false

    func scanApps() {
        CheckIn.shared.used()
        appsBusy = true; appsMsg = ""; appsMsgErr = false
        Task.detached {
            let a = Apps.list(); let l = Apps.leftovers(); let i = Apps.installers()
            await MainActor.run { self.apps = a; self.leftovers = l; self.installers = i; self.appsBusy = false; self.markDone(.apps) }
        }
    }
    /// App whose related files are still being searched: Uninstall waits, so the app is not removed without its data.
    @Published var relatedLoading: UUID? = nil
    func loadRelated(_ id: UUID) {
        selApp = id
        guard let i = apps.firstIndex(where: { $0.id == id }), apps[i].related.isEmpty else { return }
        let a = apps[i]
        relatedLoading = id
        Task.detached {
            let r = Apps.related(a)
            await MainActor.run {
                if let j = self.apps.firstIndex(where: { $0.id == id }) { self.apps[j].related = r }
                if self.relatedLoading == id { self.relatedLoading = nil }
            }
        }
    }
    /// Close the detail pane first, then drop the app from the list on the next turn of the run loop. Removing it in the
    /// same update crashed (index out of range): the detail pane still held bindings to the old array position.
    func dropApp(_ id: UUID) {
        selApp = nil
        DispatchQueue.main.async { self.apps.removeAll { $0.id == id } }
    }
    /// The result line counts only what really went to the Trash (up to 0.4.0 it reported the planned total).
    func reportUninstall(_ a: AppEntry, extra: [CleanItem], ok: Int, fail: Int) {
        let moved = a.size + extra.filter { lastOK.contains($0.url) }.reduce(0) { $0 + $1.size }
        finished(.apps, ok + 1, moved, fail)
        appsMsgErr = fail > 0
        appsMsg = (ok == 0 ? t("Uninstalled \(a.name) (\(fmt(moved))).", "Đã gỡ \(a.name) (\(fmt(moved))).")
            : t("Uninstalled \(a.name) and \(ok) related items (\(fmt(moved))).", "Đã gỡ \(a.name) và \(ok) mục liên quan (\(fmt(moved)))."))
            + (fail > 0 ? t(" \(fail) could not be moved: \(lastErr).", " \(fail) mục không chuyển được: \(lastErr).") : "")
    }

    func uninstall(_ id: UUID) {
        guard let i = apps.firstIndex(where: { $0.id == id }) else { return }
        let a = apps[i]
        guard a.lock == nil else { return }
        if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == a.bundleID }) {
            _ = confirm(t("Quit \(a.name) first", "Tắt \(a.name) trước"), t("The app is running. Quit it, then try again.", "App đang mở. Tắt app rồi bấm lại."), "OK"); return
        }
        let extra = a.related.filter(\.selected)
        let total = a.size + extra.reduce(0) { $0 + $1.size }
        guard confirm(t("Uninstall \(a.name)?", "Gỡ \(a.name)?"),
                      (extra.isEmpty ? t("The app (\(fmt(total))) will be moved to the Trash.", "App (\(fmt(total))) sẽ được chuyển vào Thùng rác.") : t("The app and \(extra.count) related items (\(fmt(total))) will be moved to the Trash.", "App và \(extra.count) mục liên quan (\(fmt(total))) sẽ được chuyển vào Thùng rác."))
                        + (a.needsAdmin ? t(" macOS will ask for an administrator password in its own window; Tidymint never sees it.", " macOS sẽ hỏi mật khẩu quản trị trong hộp thoại của macOS; Tidymint không thấy mật khẩu.") : ""),
                      t("Uninstall", "Gỡ")) else { return }
        if a.needsAdmin { uninstallWithFinder(a, extra: extra, total: total); return }
        NSWorkspace.shared.recycle([a.url]) { newURLs, err in
            Task { @MainActor in
                guard err == nil else {
                    // The app itself could not go to the Trash: leave its related files where they are.
                    self.log(t("Uninstall \(a.name) failed: ", "Gỡ \(a.name) thất bại: ") + err!.localizedDescription)
                    self.appsMsgErr = true
                    self.appsMsg = t("Could not move \(a.name) to the Trash: macOS did not allow it. Nothing was moved. You can drag the app to the Trash in Finder.",
                                     "Không chuyển được \(a.name) vào Thùng rác: macOS không cho phép. Chưa có gì bị chuyển đi. Bạn có thể kéo app vào Thùng rác trong Finder.")
                    return
                }
                // Record the app in the Undo journal together with its related files, so Undo puts all of it back.
                let appEntry = newURLs[a.url].map { [Journal.Entry(from: a.url.path, to: $0.path, size: a.size)] } ?? []
                let (ok, fail) = self.trash(extra.map(\.url), label: a.name, alsoUndo: appEntry)
                self.dropApp(id)
                self.reportUninstall(a, extra: extra, ok: ok, fail: fail)
                self.log(self.appsMsg); self.refreshTrash(); self.refreshDisk()
            }
        }
    }
    /// Apps owned by root: Finder moves the app (macOS asks for the password), then the related files go the usual way.
    func uninstallWithFinder(_ a: AppEntry, extra: [CleanItem], total: Int64) {
        appsBusy = true
        Task.detached {
            let r = FinderOps.trash(a.url.path)
            await MainActor.run {
                self.appsBusy = false
                switch r {
                case .ok(let to) where !FileManager.default.fileExists(atPath: a.url.path) && FileManager.default.fileExists(atPath: to):
                    let appEntry = [Journal.Entry(from: a.url.path, to: to, size: a.size)]
                    let (ok, fail) = self.trash(extra.map(\.url), label: a.name, alsoUndo: appEntry)
                    self.dropApp(a.id)
                    self.reportUninstall(a, extra: extra, ok: ok, fail: fail)
                case .cancelled:
                    self.appsMsgErr = true
                    self.appsMsg = t("\(a.name) was not uninstalled: the password window was cancelled. Nothing was moved.", "Chưa gỡ \(a.name): hộp hỏi mật khẩu đã bị huỷ. Chưa có gì bị chuyển đi.")
                case .notAllowed:
                    self.appsMsgErr = true
                    self.appsMsg = t("\(a.name) was not uninstalled: Tidymint is not allowed to ask Finder. Turn it on in System Settings > Privacy & Security > Automation > Tidymint > Finder. Nothing was moved.",
                                     "Chưa gỡ \(a.name): Tidymint chưa được phép nhờ Finder. Bật trong Cài đặt hệ thống > Quyền riêng tư & Bảo mật > Tự động hoá > Tidymint > Finder. Chưa có gì bị chuyển đi.")
                default:
                    self.appsMsgErr = true
                    self.appsMsg = t("Could not move \(a.name) to the Trash. Nothing was moved. You can drag the app to the Trash in Finder.", "Không chuyển được \(a.name) vào Thùng rác. Chưa có gì bị chuyển đi. Bạn có thể kéo app vào Thùng rác trong Finder.")
                }
                if case .failed(let e) = r { self.log(t("Uninstall \(a.name) through Finder failed: \(e)", "Gỡ \(a.name) qua Finder thất bại: \(e)")) }
                self.log(self.appsMsg); self.refreshTrash(); self.refreshDisk()
            }
        }
    }
    func cleanList(_ which: Int) {
        let sel = (which == 1 ? leftovers : installers).filter(\.selected)
        let size = sel.reduce(0) { $0 + $1.size }
        let (ok, fail) = trash(sel.map(\.url)); _ = size
        appsMsg = t("Moved \(ok) items (\(fmt(okSize(sel)))) to the Trash.", "Đã chuyển \(ok) mục (\(fmt(okSize(sel)))) vào Thùng rác.") + (fail > 0 ? t(" \(fail) failed.", " \(fail) mục lỗi.") + failNote : "")
        log(appsMsg)
        finished(.apps, ok, okSize(sel), fail); appsMsg = ""
        if which == 1 { leftovers.removeAll { lastOK.contains($0.url) } } else { installers.removeAll { lastOK.contains($0.url) } }
        refreshTrash(); refreshDisk()
    }

    // Duplicates
    @Published var dupes: [DupGroup] = []
    @Published var dupBusy = false
    @Published var dupCount = 0
    @Published var dupMsg = ""
    var dupWasted: Int64 { dupes.reduce(0) { $0 + $1.wasted } }
    var dupSelected: Int64 { dupes.reduce(0) { $0 + $1.selectedSize } }

    func scanDupes() {
        CheckIn.shared.used()
        dupBusy = true; dupMsg = ""; dupCount = 0; dupes = []
        if doneInfo?.page == .dupes { doneInfo = nil }
        Task.detached {
            let g = Dupes.scan { n in DispatchQueue.main.async { self.dupCount = n } }
            await MainActor.run { self.dupes = g; self.dupBusy = false; self.markDone(.dupes) }
        }
    }
    /// Whether every extra copy (all except "Keep") is selected
    /// True when every copy the automatic pick may take is ticked. Copies it never takes (APFS clones, project files,
    /// files scripts use, cross-drive groups set to "ask") do not count, otherwise the button could never switch to Deselect.
    var dupAllExtrasSelected: Bool {
        var any = false
        for g in dupes {
            let ask = g.isCross && Prefs.crossKeep == "ask"
            for it in g.items.dropFirst() where Dupes.autoPick(it, ask: ask) { if !it.selected { return false }; any = true }
        }
        return any
    }
    func dupGroupState(_ g: DupGroup) -> Int {
        let n = g.items.dropFirst().filter(\.selected).count
        return n == 0 ? 0 : (n == g.items.count - 1 ? 2 : 1)
    }
    func dupToggleGroup(_ id: UUID) {
        guard let i = dupes.firstIndex(where: { $0.id == id }) else { return }
        let ask = dupes[i].isCross && Prefs.crossKeep == "ask"
        let on = dupes[i].items.indices.contains { j in j > 0 && !dupes[i].items[j].selected && Dupes.autoPick(dupes[i].items[j], ask: ask) }
        for j in dupes[i].items.indices { dupes[i].items[j].selected = on && j > 0 && Dupes.autoPick(dupes[i].items[j], ask: ask) }
    }
    /// Re-apply a keep rule to the groups that span the Mac and an external drive (menu on the Duplicates page).
    func dupApplyCross(_ rule: String) {
        for i in dupes.indices where dupes[i].isCross { dupes[i].items = Dupes.arrange(dupes[i].items, rule: rule) }
    }
    func dupAutoSelect(all: Bool) {
        for i in dupes.indices {
            let ask = dupes[i].isCross && Prefs.crossKeep == "ask"
            for j in dupes[i].items.indices { dupes[i].items[j].selected = all && j > 0 && Dupes.autoPick(dupes[i].items[j], ask: ask) }
        }
    }
    @Published var refsBusy = false

    /// Search the project folders for files that mention the selected duplicates by name (one grep pass).
    /// Does not change selection; only adds labels and returns the selected files used by a script or skill.
    func checkRefs(_ done: @escaping @MainActor ([URL]) -> Void) {
        let roots = Prefs.projectFolders
        guard !roots.isEmpty else { done([]); return }
        let names = Set(dupes.flatMap { $0.items.filter(\.selected).map(\.name) })
        guard !names.isEmpty else { done([]); return }
        refsBusy = true
        dupMsg = t("Checking links in your project folders...", "Đang kiểm tra liên kết trong thư mục dự án...")
        Task.detached {
            let pats = NSTemporaryDirectory() + "dc-pats.txt"
            try? names.joined(separator: "\n").write(toFile: pats, atomically: true, encoding: .utf8)
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/grep")
            var args = ["-rIHoF", "-f", pats, "--exclude-dir=.git", "--exclude-dir=node_modules"]
            for e in ["md", "py", "sh", "js", "ts", "swift", "json", "html", "txt", "csv", "yml", "yaml", "command", "applescript"] { args.append("--include=*.\(e)") }
            args += roots
            p.arguments = args
            let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
            try? p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
            var map: [String: Set<String>] = [:]
            for line in (String(data: data, encoding: .utf8) ?? "").split(separator: "\n") {
                guard let r = line.range(of: ":", options: .backwards) else { continue }
                map[String(line[r.upperBound...]), default: []].insert(String(line[..<r.lowerBound]))
            }
            let found = map
            await MainActor.run {
                var hits: [URL] = []
                let strongExt: Set<String> = ["py", "sh", "js", "ts", "swift", "yml", "yaml", "command", "applescript"]
                for i in self.dupes.indices {
                    for j in self.dupes[i].items.indices {
                        let it = self.dupes[i].items[j]
                        let files = Array(found[it.name] ?? []).filter { $0 != it.url.path }
                        let strong = files.filter { strongExt.contains(($0 as NSString).pathExtension.lowercased()) || ($0 as NSString).lastPathComponent == "SKILL.md" }
                        self.dupes[i].items[j].refStrong = strong
                        self.dupes[i].items[j].refWeak = files.filter { !strong.contains($0) }
                        if it.selected && !strong.isEmpty { hits.append(it.url) }
                    }
                }
                self.refsBusy = false; self.dupMsg = ""
                done(hits)
            }
        }
    }

    /// "Move to Trash": offer a link check first, then delete.
    func cleanDupes() {
        let (n, size) = dupPending()
        guard n > 0 else { return }
        let a = NSAlert()
        a.messageText = t("Move \(n) duplicates (\(fmt(size))) to Trash?", "Chuyển \(n) file trùng (\(fmt(size))) vào Thùng rác?")
        a.informativeText = Prefs.projectFolders.isEmpty
            ? t("Tip: add your project folders in Settings to check whether a script still uses these files. One copy of each file is always kept.",
                "Mẹo: thêm thư mục dự án ở Cài đặt để kiểm tra script nào còn dùng các file này. Mỗi file luôn giữ lại ít nhất một bản.")
            : t("Check first whether any script or skill in your project folders still uses these files? One copy of each file is always kept.",
                "Kiểm tra trước xem có script hay skill nào trong thư mục dự án đang dùng các file này không? Mỗi file luôn giữ lại ít nhất một bản.")
        a.addButton(withTitle: t("Check links, then delete", "Kiểm tra rồi xoá"))
        a.addButton(withTitle: t("Delete now", "Xoá luôn"))
        a.addButton(withTitle: t("Cancel", "Huỷ"))
        a.alertStyle = .warning
        switch a.runModal() {
        case .alertFirstButtonReturn:
            checkRefs { hits in self.afterCheck(hits) }
        case .alertSecondButtonReturn:
            doTrashDupes()
        default: return
        }
    }

    private func afterCheck(_ hits: [URL]) {
        guard !hits.isEmpty else { doTrashDupes(); return }
        let home = NSHomeDirectory()
        var lines: [String] = []
        for g in dupes { for it in g.items where hits.contains(it.url) {
            let users = it.refStrong.prefix(3).map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")
            lines.append("• " + it.url.path.replacingOccurrences(of: home, with: "~") + "\n   " + t("used by: ", "đang dùng bởi: ") + users)
        } }
        let shown = lines.prefix(12).joined(separator: "\n") + (lines.count > 12 ? t("\n...and \(lines.count - 12) more", "\n...và \(lines.count - 12) file khác") : "")
        let a = NSAlert()
        a.messageText = t("\(hits.count) files are still used by a script/skill", "\(hits.count) file đang được script/skill dùng")
        a.informativeText = shown + "\n\n" + t("Untick these and delete the rest?", "Bỏ tick các file này và xoá phần còn lại?")
        a.addButton(withTitle: t("Untick & delete the rest", "Bỏ tick, xoá phần còn lại"))
        a.addButton(withTitle: t("Delete all anyway", "Vẫn xoá hết"))
        a.addButton(withTitle: t("Cancel", "Huỷ"))
        a.alertStyle = .warning
        switch a.runModal() {
        case .alertFirstButtonReturn:
            let set = Set(hits)
            for i in dupes.indices { for j in dupes[i].items.indices where set.contains(dupes[i].items[j].url) { dupes[i].items[j].selected = false } }
            doTrashDupes()
        case .alertSecondButtonReturn:
            doTrashDupes()
        default:
            dupMsg = t("Cancelled. Files used by a script/skill are marked in red.", "Đã huỷ. File đang được script/skill dùng có nhãn đỏ trong danh sách.")
        }
    }

    private func dupPending() -> (Int, Int64) {
        var n = 0, size: Int64 = 0
        for g in dupes {
            var sel = g.items.filter(\.selected)
            if sel.count == g.items.count { sel.removeFirst() }
            n += sel.count; size += sel.reduce(0) { $0 + $1.size }
        }
        return (n, size)
    }

    private func doTrashDupes() {
        var picked: [CleanItem] = []
        var skippedGroups = 0
        let fm = FileManager.default
        for g in dupes {
            var sel = g.items.filter(\.selected)
            if sel.count == g.items.count { sel.removeFirst() }   // always keep at least one copy
            guard !sel.isEmpty else { continue }
            // The copy that stays must still be there, unchanged in size (a drive may have been unplugged since the scan).
            let kept = g.items.filter { k in !sel.contains { $0.url == k.url } }
            let alive = kept.contains { k in ((try? fm.attributesOfItem(atPath: k.url.path)[.size]) as? NSNumber)?.int64Value == g.size }
            guard alive else { skippedGroups += 1; continue }
            picked += sel
        }
        guard !picked.isEmpty else {
            dupMsg = skippedGroups > 0 ? t("Skipped: the copy to keep is no longer there (drive unplugged?). Scan again.", "Bỏ qua: bản giữ lại không còn ở đó (ổ đã rút?). Quét lại nhé.")
                                       : t("Nothing left to delete.", "Không còn file nào để xoá.")
            return
        }
        let (ok, fail) = trash(picked.map(\.url), sizes: Dictionary(picked.map { ($0.url, $0.size) }, uniquingKeysWith: { a, _ in a }))
        let size = okSize(picked)
        dupMsg = t("Moved \(ok) duplicates (\(fmt(size))) to the Trash.", "Đã chuyển \(ok) file trùng (\(fmt(size))) vào Thùng rác.") + (fail > 0 ? t(" \(fail) failed.", " \(fail) file lỗi.") + failNote : "")
            + (skippedGroups > 0 ? t(" Skipped \(skippedGroups) groups whose kept copy is gone.", " Bỏ qua \(skippedGroups) nhóm vì bản giữ lại không còn.") : "")
        log(dupMsg)
        finished(.dupes, ok, size, fail); dupMsg = ""
        let gone = lastOK
        for i in dupes.indices { dupes[i].items.removeAll { gone.contains($0.url) } }
        dupes.removeAll { $0.items.count < 2 }
        refreshTrash(); refreshDisk()
    }

    // Startup items (LaunchAgents / LaunchDaemons)
    @Published var launch: [LaunchEntry] = []
    @Published var launchMsg = ""
    @Published var launchBusy = false
    func scanLaunch() {
        launch = Startup.scan()
        launchBusy = true
        let snapshot = launch
        Task.detached(priority: .utility) {
            var results: [UUID: (SignState, [LaunchFlag])] = [:]
            for e in snapshot { results[e.id] = Startup.inspect(e) }
            let r = results
            await MainActor.run {
                for i in self.launch.indices { if let v = r[self.launch[i].id] { self.launch[i].sign = v.0; self.launch[i].flags = v.1 } }
                self.launchBusy = false; self.markDone(.startup)
            }
        }
    }
    var launchAttention: Int { launch.filter(\.attention).count }
    func removeLaunch() {
        let sel = launch.filter { $0.selected && $0.scope == 0 }
        guard !sel.isEmpty, confirm(t("Remove \(sel.count) startup items?", "Gỡ \(sel.count) mục tự chạy?"),
                                    t("They will be stopped and their files moved to the Trash. The apps themselves are not touched. If an app still needs it, it will re-create it next time it opens.",
                                      "Mục sẽ được dừng và file cấu hình chuyển vào Thùng rác. App gốc không bị đụng tới. Nếu app vẫn cần, lần mở sau app sẽ tự tạo lại."),
                                    t("Remove", "Gỡ")) else { return }
        let uid = getuid()
        for e in sel {
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            p.arguments = ["bootout", "gui/\(uid)", e.url.path]
            p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
            try? p.run(); p.waitUntilExit()
        }
        let (ok, fail) = trash(sel.map(\.url), label: "startup")
        launchMsg = t("Removed \(ok) startup items.", "Đã gỡ \(ok) mục tự chạy.") + (fail > 0 ? t(" \(fail) failed.", " \(fail) mục lỗi.") + failNote : "")
        log(launchMsg)
        launch.removeAll { lastOK.contains($0.url) }
        refreshTrash()
    }

    // Cloud
    @Published var clouds: [CloudProvider] = []
    @Published var cloudBusy = false
    @Published var cloudMsg = ""

    init() {
        refreshDisk(); refreshTrash(); refreshRAM()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    /// Assign only on a visible change: every assignment of a published value redraws every open page.
    func refreshRAM() {
        let r = ramInfo()
        if abs(r.used - ramUsed) >= 0.05 { ramUsed = r.used }
        if r.total != ramTotal { ramTotal = r.total }
    }
    var tickCount = 0
    func tick() {
        refreshRAM(); tickCount += 1
        if tickCount % 6 == 0 { refreshDisk() }
        if lowSpaceGB > 0 && freeGB > 0 && freeGB < lowSpaceGB && Date().timeIntervalSince(lastDiskAlert) > 6 * 3600 {
            lastDiskAlert = Date()
            notify(t("Low disk space", "Ổ sắp đầy"),
                   String(format: t("Only %.0f GB left. Open Tidymint to free up space.", "Chỉ còn %.0f GB. Mở Tidymint để dọn."), freeGB))
        }
        if ramAlert && ramTotal > 0 && ramUsed / ramTotal > 0.9 && Date().timeIntervalSince(lastRamAlert) > 3600 {
            lastRamAlert = Date()
            notify(t("Memory is almost full", "RAM sắp đầy"),
                   String(format: t("%.1f of %.0f GB in use. Quit apps you are not using.", "Đang dùng %.1f / %.0f GB. Tắt bớt app không dùng."), ramUsed, ramTotal))
        }
    }
    func notify(_ title: String, _ body: String) {
        let c = UNMutableNotificationContent(); c.title = title; c.body = body; c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }
    /// 0 fine, 1 getting low (under 1.25x the warning level), 2 low (under the warning level). 0 when the warning is off.
    var diskLevel: Int {
        guard freeGB > 0, lowSpaceGB > 0 else { return 0 }
        return freeGB < lowSpaceGB ? 2 : (freeGB < lowSpaceGB * 1.25 ? 1 : 0)
    }
    func setLowSpace(_ v: Double) { lowSpaceGB = v; UserDefaults.standard.set(v, forKey: "lowSpaceGB") }
    func setRamAlert(_ v: Bool) { ramAlert = v; UserDefaults.standard.set(v, forKey: "ramAlert") }
    func setAutoUpdateCheck(_ v: Bool) { autoUpdateCheck = v; UserDefaults.standard.set(v, forKey: "autoUpdateCheck"); if v { checkUpdates() } }
    func setOpenAtLogin(_ v: Bool) {
        do { if v { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch { }
        openAtLogin = SMAppService.mainApp.status == .enabled
    }

    func scanCloud() {
        cloudBusy = true; cloudMsg = ""
        let ps = Cloud.providers()
        clouds = ps
        Task.detached {
            var res: [CloudProvider] = []
            for var p in ps {
                p.local = Cloud.localSize(p.root.path)
                let tops = Cloud.topItems(p.root)
                var nodes = [Node](repeating: Node(url: p.root, size: 0, isDir: true), count: tops.count)
                DispatchQueue.concurrentPerform(iterations: tops.count) { i in
                    var isDir: ObjCBool = false
                    FileManager.default.fileExists(atPath: tops[i].path, isDirectory: &isDir)
                    nodes[i] = Node(url: tops[i], size: Cloud.localSize(tops[i].path), isDir: isDir.boolValue)
                }
                p.items = nodes.filter { $0.size > 0 }.sorted { $0.size > $1.size }
                res.append(p)
                let snap = res
                await MainActor.run { self.clouds = snap + ps.dropFirst(snap.count) }
            }
            await MainActor.run { self.clouds = res.sorted { $0.local > $1.local }; self.cloudBusy = false; self.markDone(.cloud) }
        }
    }
    func evictICloud(_ u: URL) {
        guard !cloudBusy else { return }
        cloudBusy = true   // a folder with many files took seconds on the main thread
        Task.detached {
            let (ok, fail) = Cloud.evict(u)
            await MainActor.run { [weak self] in self?.cloudBusy = false; self?.evictDone(u, ok: ok, fail: fail) }
        }
    }
    private func evictDone(_ u: URL, ok: Int, fail: Int) {
        cloudMsg = t("Removed local copies of \(ok) files (still in iCloud).", "Đã xoá bản trên máy của \(ok) file (vẫn còn trên iCloud).") + (fail > 0 ? t(" \(fail) failed.", " \(fail) file lỗi.") : "")
        log(t("Cloud: removed local copy of \(u.path), ok \(ok), failed \(fail)", "Đám mây: gỡ bản tải về của \(u.path), được \(ok), lỗi \(fail)"))
        scanCloud(); refreshDisk()
    }

    var junkTotal: Int64 { cats.reduce(0) { $0 + $1.total } }
    var junkSelected: Int64 { cats.reduce(0) { $0 + $1.selectedSize } }
    var largeSelected: Int64 { large.filter(\.selected).reduce(0) { $0 + $1.size } }

    func refreshDisk() {
        let v = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
        let f = Double(v?.volumeAvailableCapacityForImportantUsage ?? 0) / 1_000_000_000
        let tot = Double(v?.volumeTotalCapacity ?? 0) / 1_000_000_000
        if abs(f - freeGB) >= 0.05 { freeGB = f }
        if abs(tot - totalGB) >= 0.05 { totalGB = tot }
        if freeGB > 0 { DiskHistory.record(freeGB) }
    }

    var trashGen = 0   // used by refreshTrash (Trash.swift)

    func scanJunk(thenReview: Bool = false) {
        phase = .scanning; scanStep = 0; scanDetail = ""
        let cb = stepCallback()
        Task.detached {
            let r = Scanner.scanJunk(step: cb)
            await MainActor.run { self.cats = r; self.phase = thenReview ? .review : .summary; self.markDone(.cleanup) }
        }
    }

    func scanLarge() {
        CheckIn.shared.used()
        if doneInfo?.page == .large { doneInfo = nil }
        largePhase = .scanning
        Task.detached {
            let r = Scanner.scanLarge(extras: true)
            await MainActor.run { self.large = r; self.largePhase = .review; self.markDone(.large) }
        }
    }

    func smartScan() {
        CheckIn.shared.used()
        let withExtras = !Prefs.extraFolders.isEmpty   // then the Large page keeps its own result, Smart Scan does not touch it
        phase = .scanning; if !withExtras { largePhase = .scanning }; scanStep = 0; scanDetail = ""
        refreshTrash(); refreshDisk()
        let cb = stepCallback()
        Task.detached {
            let j = Scanner.scanJunk(step: cb)
            cb(6, "~/Documents, Downloads, Desktop, Movies, Music, Pictures")
            // With extra drives set, the Large page scans them itself; a quick scan without them would show a partial list.
            let l = withExtras ? [] : Scanner.scanLarge()
            await MainActor.run {
                self.cats = j; self.phase = .summary
                if !withExtras { self.large = l; self.largePhase = .review }
                self.markDone(.smart)
            }
        }
    }

    @Published var lastFreed: Int64 = 0
    @Published var lastCount = 0
    struct DoneInfo { let page: Page; let count: Int; let size: Int64; let fail: Int; var session: Date? = nil }
    @Published var doneInfo: DoneInfo? = nil
    /// What the last Undo put back, shown on the page it was started from (and on the Trash page) until the next clean.
    @Published var undoNote: (page: Page, text: String)? = nil
    func finished(_ p: Page, _ count: Int, _ size: Int64, _ fail: Int) { undoNote = nil; doneInfo = count > 0 ? DoneInfo(page: p, count: count, size: size, fail: fail, session: undoable?.date) : nil }
    /// The banner's Undo only belongs to the clean it reports: a later clean elsewhere replaces the Undo journal.
    var bannerCanUndo: Bool { guard let d = doneInfo, let u = undoable else { return false }; return d.session == nil || d.session == u.date }
    /// Undo from a list page: put the files back, then measure that page again so the list shows them.
    func undoFromBanner() {
        guard let d = doneInfo else { return }
        let before = undoable
        undoLast()
        guard undoable == nil, before != nil else { return }
        doneInfo = nil
        switch d.page {
        case .large: scanLarge()
        case .dupes: scanDupes()
        case .apps: scanApps()
        case .byapp: scanByApp()
        case .lens: if sysOpen { scanSys() } else { rescanLens() }
        default: break
        }
    }
    // Scan steps shown while scanning (Clean Now / Cleanup)
    @Published var scanStep = 0
    @Published var scanDetail = ""
    static var junkSteps: [String] { [t("User caches", "Bộ nhớ đệm người dùng"), t("App caches", "Bộ nhớ đệm trong app"), t("Logs", "Nhật ký"),
                                      t("Developer tools", "Công cụ lập trình"), t("Project drafts", "Nháp dự án"), t("Old downloads", "Downloads cũ")] }
    nonisolated func stepCallback() -> (Int, String) -> Void {
        { i, d in DispatchQueue.main.async { self.scanStep = i; self.scanDetail = d } }
    }
    // System Data explainer (a view inside Space Lens)
    @Published var sysOpen = false
    @Published var sysBusy = false
    @Published var sysParts: [SysPart] = []
    @Published var sysPurgeable: Int64 = 0
    func openSys() { sysOpen = true; if sysParts.isEmpty { scanSys() } }
    func scanSys() {
        sysBusy = true
        Task.detached {
            let (parts, purge) = SysData.scan()
            await MainActor.run { self.sysParts = parts; self.sysPurgeable = purge; self.sysBusy = false }
        }
    }
    func trashSys() {
        let picked = sysParts.flatMap { $0.items.filter(\.selected) }.filter { !Scanner.blocked($0.url.path) }
        guard !picked.isEmpty else { return }
        guard confirm(t("Move \(picked.count) items to the Trash?", "Chuyển \(picked.count) mục vào Thùng rác?"),
                      picked.prefix(8).map { "• \($0.name), \(fmt($0.size))" }.joined(separator: "\n") + (picked.count > 8 ? "\n…" : ""),
                      t("Move to Trash", "Chuyển vào Thùng rác")) else { return }
        let (ok, fail) = trash(picked.map(\.url), label: "sysdata", sizes: Dictionary(picked.map { ($0.url, $0.size) }, uniquingKeysWith: { a, _ in a }))
        let freed = okSize(picked)
        log(t("System Data: moved \(ok) items (\(fmt(freed))) to the Trash.", "Dữ liệu hệ thống: đã chuyển \(ok) mục (\(fmt(freed))) vào Thùng rác."))
        finished(.lens, ok, freed, fail)
        scanSys(); refreshTrash(); refreshDisk()
    }
    // Space Lens selection and history
    @Published var lensSel = Set<URL>()
    @Published var lensFwd: [URL] = []
    var lensSelSize: Int64 { lensNodes.filter { lensSel.contains($0.url) }.reduce(0) { $0 + $1.size } }
    func lensBack() { guard lensPath.count > 1 else { return }; lensFwd.append(lensPath.removeLast()); lensSel = []; loadLens() }
    func lensForward() { guard let u = lensFwd.popLast() else { return }; lensPath.append(u); lensSel = []; loadLens() }
    func trashLensSelection() {
        let picked = lensNodes.filter { lensSel.contains($0.url) && !Scanner.blocked($0.url.path) }
        guard !picked.isEmpty else { return }
        let size = picked.reduce(0) { $0 + $1.size }
        guard confirm(t("Move \(picked.count) items to the Trash?", "Chuyển \(picked.count) mục vào Thùng rác?"),
                      picked.prefix(8).map { "• \($0.name), \(fmt($0.size))" }.joined(separator: "\n") + (picked.count > 8 ? "\n…" : ""),
                      t("Move to Trash", "Chuyển vào Thùng rác")) else { return }
        let (ok, fail) = trash(picked.map(\.url), label: "lens", strict: false)
        let gone = lastOK
        let freed = picked.filter { gone.contains($0.url) }.reduce(0) { $0 + $1.size }
        lensNodes.removeAll { gone.contains($0.url) }
        for u in gone { sizeCache.removeValue(forKey: u.path) }
        lensSel = []
        log(t("Space Lens: moved \(ok) items (\(fmt(freed))) to the Trash.", "Bản đồ ổ đĩa: đã chuyển \(ok) mục (\(fmt(freed))) vào Thùng rác.")); _ = size
        finished(.lens, ok, freed, fail)
        refreshTrash(); refreshDisk()
    }
    // Uninstaller filters
    /// Uninstaller: filter the app list by name (matches ignoring case and accents), on top of appsFilter.
    @Published var appsQuery = ""
    @Published var appsFilter = 0   // 0 all, 1 not opened in 6 months, 2 over 500 MB, 3 App Store, 4 other sources
    /// Remembered between launches (asked for on MacRumors, 04/11/2026).
    @Published var appsSort = min(max(UserDefaults.standard.integer(forKey: "appsSort"), 0), 2) {   // 0 size, 1 name, 2 last opened
        didSet { UserDefaults.standard.set(appsSort, forKey: "appsSort") }
    }
    private static var masMemo: [String: Bool] = [:]
    /// Cached: the Uninstaller filters call it for every app on every redraw.
    static func fromAppStore(_ u: URL) -> Bool {
        if let v = masMemo[u.path] { return v }
        let v = FileManager.default.fileExists(atPath: u.appendingPathComponent("Contents/_MASReceipt/receipt").path)
        masMemo[u.path] = v; return v
    }
    func appsMatching(_ f: Int) -> [AppEntry] {
        let old = Date().addingTimeInterval(-182 * 86400)
        switch f {
        case 1: return apps.filter { $0.lastUsed.map { $0 < old } ?? false }
        case 5: return apps.filter { $0.lastUsed == nil }
        case 2: return apps.filter { $0.size >= 500_000_000 }
        case 3: return apps.filter { VM.fromAppStore($0.url) }
        case 4: return apps.filter { !VM.fromAppStore($0.url) }
        default: return apps
        }
    }
    var appsShown: [AppEntry] {
        let q = appsQuery.trimmingCharacters(in: .whitespaces)
        let a = appsMatching(appsFilter).filter { q.isEmpty || $0.name.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        switch appsSort {
        case 1: return a.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case 2: return a.sorted { ($0.lastUsed ?? .distantPast) < ($1.lastUsed ?? .distantPast) }
        default: return a.sorted { $0.size > $1.size }
        }
    }

    func toggleCat(_ id: String) {
        guard let i = cats.firstIndex(where: { $0.id == id }) else { return }
        // Tick when something tickable is still unticked; otherwise clear. Items of an open app are never ticked here,
        // so "all ticked" is judged without them (or the box could never be cleared).
        let on = cats[i].items.contains { !$0.selected && !$0.running }
        for j in cats[i].items.indices where !(on && cats[i].items[j].running) { cats[i].items[j].selected = on }
    }

    func setAll(_ on: Bool) {
        for i in cats.indices { for j in cats[i].items.indices where !(on && cats[i].items[j].running) { cats[i].items[j].selected = on } }
    }

    var lastOK = Set<URL>()
    var lastErr = ""
    @Published var undoable: Journal.Session? = Journal.load()

    func okSize(_ items: [CleanItem]) -> Int64 { items.filter { lastOK.contains($0.url) }.reduce(0) { $0 + $1.size } }
    var failNote: String { lastErr.isEmpty ? "" : t(" Reason: ", " Lý do: ") + lastErr }

    func cleanJunk() {
        let sel = cats.flatMap { $0.items.filter(\.selected) }
        let size = sel.reduce(0) { $0 + $1.size }
        let (ok, fail) = trash(sel.map(\.url), label: "cleanup", sizes: Dictionary(sel.map { ($0.url, $0.size) }, uniquingKeysWith: { a, _ in a })); _ = size
        lastFreed = okSize(sel); lastCount = ok
        lastResult = t("Moved \(ok) items (\(fmt(okSize(sel)))) to the Trash.", "Đã chuyển \(ok) mục (\(fmt(okSize(sel)))) vào Thùng rác.") + (fail > 0 ? t(" Skipped \(fail) items.", " Bỏ qua \(fail) mục.") + failNote : "")
        log(lastResult)
        phase = .done
        refreshTrash(); refreshDisk()
    }

    func cleanLarge() {
        let sel = large.filter(\.selected)
        let size = sel.reduce(0) { $0 + $1.size }
        let (ok, fail) = trash(sel.map(\.url), label: "large", sizes: Dictionary(sel.map { ($0.url, $0.size) }, uniquingKeysWith: { a, _ in a })); _ = size
        lastResult = t("Moved \(ok) large files (\(fmt(okSize(sel)))) to the Trash.", "Đã chuyển \(ok) file lớn (\(fmt(okSize(sel)))) vào Thùng rác.") + (fail > 0 ? t(" \(fail) failed.", " \(fail) file lỗi.") + failNote : "")
        log(lastResult)
        finished(.large, ok, okSize(sel), fail)
        large.removeAll { lastOK.contains($0.url) }
        refreshTrash(); refreshDisk()
    }

    // Clean by app
    @Published var appReports: [AppReport] = []
    @Published var appBusy = false
    @Published var appScanned = false
    @Published var appSel: String? = nil
    @Published var appMsg = ""
    @Published var appAge = 0      // months; 0 = no age filter applied
    /// Month viewer: the by-month row being looked at (nil = closed), its photos/videos/files newest first,
    /// companion files that are not media (Zalo's .rescache indexes), the focused file, the files ticked here, Quick Look.
    @Published var monthRef: MonthRef? = nil
    @Published var monthItems: [MonthItem] = []
    @Published var monthExtras: [URL] = []
    @Published var monthExtrasSize: Int64 = 0
    @Published var monthPick = Set<String>()
    @Published var monthFocus: String? = nil
    @Published var monthLoading = false
    @Published var monthCollapsed = Set<Int>()   // weeks folded in the month viewer
    var monthAnchor: String? = nil               // last file clicked, for Shift-click ranges
    @Published var qlURL: URL? = nil
    /// File lists (Large Files, Duplicates, leftovers...): Quick Look of one file (click, or Space over a row).
    @Published var fileQL: URL? = nil
    /// The file row under the pointer, for Space. Not published: only read when Space is pressed.
    var hoverFile: URL? = nil
    func openMonth(_ app: String, _ g: String, _ row: String) {
        guard let r = appReports.first(where: { $0.id == app }), let grp = r.groups.first(where: { $0.id == g }),
              let rw = grp.rows.first(where: { $0.id == row }), rw.month != nil else { return }
        monthItems = []; monthExtras = []; monthExtrasSize = 0; monthFocus = nil; qlURL = nil; monthLoading = true; monthCollapsed = []; monthAnchor = nil
        monthRef = MonthRef(app: app, group: g, row: row)
        let urls = rw.urls, sel = rw.selected, picked = rw.picked
        Task.detached(priority: .userInitiated) {
            let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .contentModificationDateKey]
            var items: [MonthItem] = [], extras: [URL] = [], extraSize: Int64 = 0
            var groups: [String: [(URL, Int64, Date)]] = [:]
            for u in urls {
                let v = try? u.resourceValues(forKeys: keys)
                let sz = Int64(v?.totalFileAllocatedSize ?? 0), d = v?.contentModificationDate ?? .distantPast
                if MonthItem.isCompanion(u) { extras.append(u); extraSize += sz; continue }
                if let k = MonthItem.variantKey(u) { groups[k, default: []].append((u, sz, d)); continue }
                items.append(MonthItem(url: u, size: sz, date: d, kind: FileKind.of(u), tgSticker: MonthItem.isTelegramSticker(u)))
            }
            // One cell per photo: show the largest copy, carry the others along.
            for (_, g) in groups {
                let best = g.max { $0.1 < $1.1 }!
                items.append(MonthItem(url: best.0, size: g.reduce(0) { $0 + $1.1 }, date: g.map(\.2).max() ?? best.2, kind: FileKind.of(best.0),
                                       variants: g.filter { $0.0 != best.0 }.map(\.0), tgSticker: MonthItem.isTelegramSticker(best.0)))
            }
            items.sort { $0.date > $1.date }
            let pick: Set<String> = !sel ? [] : (picked.map { p in Set(items.filter { p.contains($0.id) }.map(\.id)) } ?? Set(items.map(\.id)))
            await MainActor.run {
                guard self.monthRef == MonthRef(app: app, group: g, row: row) else { return }
                self.monthItems = items; self.monthExtras = extras; self.monthExtrasSize = extraSize
                self.monthPick = pick; self.monthLoading = false
            }
        }
    }
    func closeMonth() { qlURL = nil; monthRef = nil; monthItems = []; monthExtras = []; monthPick = []; monthFocus = nil; PreviewLinks.clear() }
    /// Quick Look the given file (or the focused one, or the first).
    func previewMonth(_ path: String? = nil) {
        guard let p = path ?? monthFocus ?? monthItems.first?.id, let it = monthItems.first(where: { $0.id == p }) else { return }
        monthFocus = p; qlURL = it.previewURL
    }
    /// A click on a file: toggles it, or with Shift ticks every file between the last click and this one.
    func clickMonth(_ id: String, shift: Bool) {
        monthFocus = id
        if shift, let a = monthAnchor, let i = monthItems.firstIndex(where: { $0.id == a }), let j = monthItems.firstIndex(where: { $0.id == id }) {
            setMonthPick(monthItems[min(i, j)...max(i, j)].map(\.id), on: true)
        } else {
            setMonthPick([id], on: !monthPick.contains(id))
        }
        monthAnchor = id
    }
    /// Tick or untick files in the month viewer, then write the choice back to the month row.
    func setMonthPick(_ ids: [String], on: Bool) {
        if on { monthPick.formUnion(ids) } else { monthPick.subtract(ids) }
        guard let ref = monthRef, let i = appReports.firstIndex(where: { $0.id == ref.app }),
              let j = appReports[i].groups.firstIndex(where: { $0.id == ref.group }),
              let k = appReports[i].groups[j].rows.firstIndex(where: { $0.id == ref.row }) else { return }
        if monthPick.isEmpty {
            appReports[i].groups[j].rows[k].selected = false; appReports[i].groups[j].rows[k].picked = nil
        } else if monthPick.count == monthItems.count {
            appReports[i].groups[j].rows[k].selected = true; appReports[i].groups[j].rows[k].picked = nil   // whole month, companions too
        } else {
            appReports[i].groups[j].rows[k].selected = true
            let chosen = monthItems.filter { monthPick.contains($0.id) }
            appReports[i].groups[j].rows[k].picked = Set(chosen.flatMap(\.allPaths))
            appReports[i].groups[j].rows[k].pickedSize = chosen.reduce(0) { $0 + $1.size }
            appReports[i].groups[j].rows[k].pickedCount = chosen.count
        }
    }
    func scanByApp() {
        CheckIn.shared.used()
        appBusy = true; appMsg = ""
        Task.detached(priority: .userInitiated) {
            let r = AppRules.scan()
            await MainActor.run { self.appReports = r; self.appBusy = false; self.appScanned = true; self.appAge = 0; self.markDone(.byapp) }
        }
    }
    func refreshAppRunning() { for i in appReports.indices { appReports[i].running = Scanner.running(appReports[i].rule.bundleIDs) != nil } }
    func quitApp(_ id: String) {
        guard let r = appReports.first(where: { $0.id == id }) else { return }
        Scanner.quit(r.rule.bundleIDs)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.refreshAppRunning() }
    }
    func toggleAppGroup(_ app: String, _ g: String) {
        guard let i = appReports.firstIndex(where: { $0.id == app }), let j = appReports[i].groups.firstIndex(where: { $0.id == g }) else { return }
        guard appReports[i].groups[j].section.safety != .locked else { return }
        let on = appReports[i].groups[j].state != 2
        for k in appReports[i].groups[j].rows.indices { appReports[i].groups[j].rows[k].selected = on; appReports[i].groups[j].rows[k].picked = nil }
    }
    /// Tick every by-age row older than `months` (0 clears them), leaving "safe" groups as they are.
    func selectOlder(_ app: String, months: Int) {
        appAge = months
        guard let i = appReports.firstIndex(where: { $0.id == app }) else { return }
        let cutoff = Calendar.current.date(byAdding: .month, value: -months, to: AppRules.monthStart(Date())) ?? Date()
        for j in appReports[i].groups.indices where appReports[i].groups[j].section.byAge {
            for k in appReports[i].groups[j].rows.indices {
                let m = appReports[i].groups[j].rows[k].month ?? Date()
                appReports[i].groups[j].rows[k].selected = months > 0 && m < cutoff
                appReports[i].groups[j].rows[k].picked = nil
            }
        }
    }
    func toggleAppExpand(_ app: String, _ g: String) {
        guard let i = appReports.firstIndex(where: { $0.id == app }), let j = appReports[i].groups.firstIndex(where: { $0.id == g }) else { return }
        withAnimation(.easeOut(duration: 0.2)) { appReports[i].groups[j].expanded.toggle() }
    }
    func toggleAppRow(_ app: String, _ g: String, _ row: String) {
        guard let i = appReports.firstIndex(where: { $0.id == app }), let j = appReports[i].groups.firstIndex(where: { $0.id == g }),
              let k = appReports[i].groups[j].rows.firstIndex(where: { $0.id == row }) else { return }
        let on = appReports[i].groups[j].rows[k].checkState != 2
        appReports[i].groups[j].rows[k].selected = on; appReports[i].groups[j].rows[k].picked = nil
    }
    func cleanApp(_ id: String) {
        guard let i = appReports.firstIndex(where: { $0.id == id }) else { return }
        let r = appReports[i]
        refreshAppRunning()
        if appReports[i].running {
            _ = confirm(t("Quit \(r.rule.name) first", "Tắt \(r.rule.name) trước"), t("The app is open and may be writing these files. Quit it, then clean.", "App đang mở, có thể đang ghi vào các file này. Tắt app rồi dọn."), "OK"); return
        }
        let rows = r.groups.filter { $0.section.safety != .locked }.flatMap { $0.rows.filter(\.selected) }
        let urls = rows.flatMap(\.selURLs)
        let size = rows.reduce(0) { $0 + $1.selSize }
        let risky = r.groups.contains { $0.section.safety == .review && $0.rows.contains(where: \.selected) }
        let body = risky
            ? t("\(urls.count) items (\(fmt(size))) go to the Trash. Photos, videos and files you ticked are removed from this Mac; put them back from the Trash if you change your mind.",
                "\(urls.count) mục (\(fmt(size))) sẽ vào Thùng rác. Ảnh, video, file đã tick sẽ mất trên máy này; đổi ý thì trả về từ Thùng rác.")
            : t("\(urls.count) items (\(fmt(size))) go to the Trash.", "\(urls.count) mục (\(fmt(size))) sẽ vào Thùng rác.")
        guard confirm(t("Clean \(r.rule.name)?", "Dọn \(r.rule.name)?"), body, t("Move to Trash", "Chuyển vào Thùng rác")) else { return }
        let (ok, fail) = trash(urls, label: "app:" + id)
        appMsg = t("\(r.rule.name): moved \(ok) items (\(fmt(size))) to the Trash.", "\(r.rule.name): đã chuyển \(ok) mục (\(fmt(size))) vào Thùng rác.") + (fail > 0 ? t(" Skipped \(fail).", " Bỏ qua \(fail).") + failNote : "")
        log(appMsg)
        finished(.byapp, ok, size, fail); appMsg = ""
        // Re-measure just this app.
        Task.detached(priority: .userInitiated) {
            let fresh = AppRules.scan().first { $0.id == id }
            await MainActor.run {
                // Look the row up again: a rescan may have replaced the list meanwhile.
                if let j = self.appReports.firstIndex(where: { $0.id == id }) {
                    if let f = fresh { self.appReports[j] = f } else { self.appReports.remove(at: j); self.appSel = nil }
                }
                self.refreshTrash(); self.refreshDisk()
            }
        }
    }

    // Full Disk Access. Without it macOS hides Mail, Safari, Messages and similar folders from the scan,
    // silently, so the numbers look smaller than they are. Checked at launch and whenever the app comes back
    // to the front (the user usually returns straight from System Settings).
    @Published var fullDiskAccess = true
    static let fdaSettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
    func checkFullDiskAccess() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let probes = ["/Library/Safari", "/Library/Mail", "/Library/Messages", "/Library/Cookies"].map { home + $0 }
        var denied = false
        defer { Scanner.limited = !fullDiskAccess }
        for p in probes where FileManager.default.fileExists(atPath: p) {
            do { _ = try FileManager.default.contentsOfDirectory(atPath: p); fullDiskAccess = true; return }
            catch { denied = true }
        }
        // No protected folder exists at all (fresh account): nothing to prove either way, do not nag.
        fullDiskAccess = !denied
    }

    // Updates
    @Published var newVersion: String? = nil
    @Published var updChecking = false
    func checkUpdates(force: Bool = false) {
        guard force || !updChecking else { return }
        guard force || autoUpdateCheck else { return }   // automatic check turned off in Settings: no request at all
        updChecking = true
        Updates.check(force: force) { v in self.newVersion = v; self.updChecking = false }
    }

    func confirm(_ title: String, _ text: String, _ ok: String) -> Bool {
        let a = NSAlert()
        a.messageText = title; a.informativeText = text
        a.addButton(withTitle: ok); a.addButton(withTitle: t("Cancel", "Huỷ"))
        a.alertStyle = .warning
        return a.runModal() == .alertFirstButtonReturn
    }

    // Ignore list
    /// Ignore list: pick files or folders by hand (Finder dialog), besides right-click in the scan lists.
    func addIgnoredByPicker() {
        let p = NSOpenPanel()
        p.canChooseFiles = true; p.canChooseDirectories = true; p.allowsMultipleSelection = true
        p.prompt = t("Choose", "Chọn"); p.message = t("Files and folders you pick will never show up in scans.", "File và thư mục bạn chọn sẽ không bao giờ hiện trong kết quả quét.")
        if p.runModal() == .OK { for u in p.urls { ignore(u) } }
    }
    func ignore(_ u: URL) {
        IgnoreList.add(u.path); ignored = IgnoreList.paths
        for i in cats.indices { cats[i].items.removeAll { $0.url == u } }
        cats.removeAll { $0.items.isEmpty }
        large.removeAll { $0.url == u }
        lensNodes.removeAll { $0.url == u }
        let under = { (x: URL) in x == u || x.path.hasPrefix(u.path + "/") }
        leftovers.removeAll { under($0.url) }
        installers.removeAll { under($0.url) }
        for i in apps.indices { apps[i].related.removeAll { under($0.url) } }
        for i in dupes.indices { dupes[i].items.removeAll { under($0.url) } }
        dupes.removeAll { $0.items.count < 2 }
        for i in sysParts.indices { sysParts[i].items.removeAll { under($0.url) } }
    }
    func unignore(_ p: String) { IgnoreList.remove(p); ignored = IgnoreList.paths }

    // Space Lens
    func openLens(_ u: URL) {
        if lensPath.isEmpty { CheckIn.shared.used() }
        lensPath.append(u); lensFwd = []; lensSel = []; loadLens()
    }
    func lensUp(to i: Int) { lensPath = Array(lensPath.prefix(i + 1)); lensFwd = []; lensSel = []; loadLens() }
    // Measure with /usr/bin/du in parallel, show results progressively, cache by path.
    var lensToken = UUID()
    var sizeCache: [String: Int64] = [:]
    @Published var lensDone = 0
    @Published var lensTotal = 0
    @Published var lensCurrent = ""

    nonisolated static func du(_ path: String) -> Int64 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        p.arguments = ["-skx", "-I", "CloudStorage", "-I", "Mobile Documents", path]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return 0 }
        let d = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let str = String(data: d, encoding: .utf8) ?? ""
        return (Int64(str.split(whereSeparator: { $0 == "\t" || $0 == " " }).first ?? "0") ?? 0) * 1024
    }

    func loadLens() {
        guard let u = lensPath.last else { return }
        let token = UUID(); lensToken = token
        let kids = Scanner.children(u, hidden: true).filter { !IgnoreList.contains($0.path) }
        lensNodes = []; lensDone = 0; lensTotal = kids.count; lensBusy = !kids.isEmpty; lensCurrent = ""
        let cloud = ["CloudStorage", "Mobile Documents"]
        var todo: [URL] = []
        for k in kids {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: k.path, isDirectory: &isDir)
            let dir = isDir.boolValue && k.pathExtension.lowercased() != "app"
            if cloud.contains(k.lastPathComponent) { lensDone += 1; continue }          // cloud files, not counted
            if let c = sizeCache[k.path] {
                if c > 0 { lensNodes.append(Node(url: k, size: c, isDir: dir)) }
                lensDone += 1
            } else { todo.append(k) }
        }
        lensNodes.sort { $0.size > $1.size }
        if todo.isEmpty { lensBusy = false; return }
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.concurrentPerform(iterations: todo.count) { i in
                let k = todo[i]
                DispatchQueue.main.async { if self.lensToken == token { self.lensCurrent = k.lastPathComponent } }
                let sz = VM.du(k.path)
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: k.path, isDirectory: &isDir)
                let node = Node(url: k, size: sz, isDir: isDir.boolValue && k.pathExtension.lowercased() != "app")
                DispatchQueue.main.async {
                    guard self.lensToken == token else { return }
                    self.sizeCache[k.path] = sz
                    if sz > 0 { self.lensNodes.append(node); self.lensNodes.sort { $0.size > $1.size } }
                    self.lensDone += 1
                    if self.lensDone >= self.lensTotal { self.lensBusy = false; self.lensCurrent = ""; self.markDone(.lens) }
                }
            }
        }
    }
    func stopLens() { lensToken = UUID(); lensBusy = false; lensCurrent = "" }
    // Main window lifecycle (SwiftUI tears the view down when the window closes).
    private var trimLater: DispatchWorkItem?
    func windowShown() { trimLater?.cancel(); trimLater = nil }
    func windowGone() {
        trimLater?.cancel()
        trimMemory(deep: false)
        let w = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.trimMemory(deep: true) } }
        trimLater = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 900, execute: w)
    }
    /// Called when the main window closes: give memory back while Tidymint sits in the menu bar.
    /// Thumbnails go at once (cheap to rebuild). After 15 minutes closed, idle Space Lens and Duplicates results go too;
    /// both pages then show their normal start state. Smart Clean and Large Files keep their results.
    func trimMemory(deep: Bool) {
        ThumbStore.cache.removeAllObjects()
        FileKind.clearMemo()
        if deep {
            if !lensBusy { stopLens(); lensPath = []; lensNodes = []; lensSel = []; lensFwd = []; sizeCache = [:] }
            if !dupBusy { dupes = []; dupMsg = "" }
        }
        malloc_zone_pressure_relief(nil, 0)   // hand freed pages back to macOS so the footprint really drops
    }
    func rescanLens() { if let u = lensPath.last { sizeCache = sizeCache.filter { !$0.key.hasPrefix(u.path) } }; loadLens() }
    func trashNode(_ n: Node) {
        guard confirm(t("Move to Trash?", "Chuyển vào Thùng rác?"), "\(n.name), \(fmt(n.size))", t("Move to Trash", "Chuyển vào Thùng rác")) else { return }
        let (ok, fail) = trash([n.url], label: "lens", strict: false)
        if ok > 0 { lensNodes.removeAll { $0.id == n.id }; lensSel.remove(n.url); sizeCache.removeValue(forKey: n.url.path); log(t("Space Lens: moved \(n.url.path) (\(fmt(n.size))) to the Trash.", "Bản đồ ổ đĩa: đã chuyển \(n.url.path) (\(fmt(n.size))) vào Thùng rác.")) }
        finished(.lens, ok, ok > 0 ? n.size : 0, fail)
        refreshTrash(); refreshDisk()
    }

    func reveal(_ u: URL) { NSWorkspace.shared.activateFileViewerSelecting([u]) }
    /// Opens a file in the app the user set for its type; with no app set, macOS itself asks which app to use.
    func openFile(_ u: URL) { NSWorkspace.shared.open(u) }
    func openFile(_ u: URL, with app: URL) { NSWorkspace.shared.open([u], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration()) }

    func log(_ s: String) {
        let p = Stats.path
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm"
        let line = "\(df.string(from: Date())) | \(s) | free \(String(format: "%.0f", freeGB)) GB\n"
        if let h = FileHandle(forWritingAtPath: p) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close() }
        else { try? line.write(toFile: p, atomically: true, encoding: .utf8) }
    }
}
