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
    /// App whose related files are still being searched: Uninstall waits, so the app is not removed without its data.
    @Published var relatedLoading: UUID? = nil
    /// Apps dragged to the Trash in Finder left these behind (optional hint, see TrashHint). Newest first, a few at most.
    @Published var trashHints: [TrashHintInfo] = []
    /// Shown in place of a card when a clicked notification has nothing left to offer.
    @Published var trashHintNote = ""
    /// Cards whose full list is open.
    @Published var trashHintOpen = Set<String>()
    @Published var trashHintOn: Bool = UserDefaults.standard.bool(forKey: "trashHint")

    // Duplicates
    @Published var dupes: [DupGroup] = []
    @Published var dupBusy = false
    @Published var dupCount = 0
    @Published var dupMsg = ""
    var dupWasted: Int64 { dupes.reduce(0) { $0 + $1.wasted } }
    var dupSelected: Int64 { dupes.reduce(0) { $0 + $1.selectedSize } }
    @Published var refsBusy = false

    // Startup items (LaunchAgents / LaunchDaemons)
    @Published var launch: [LaunchEntry] = []
    @Published var launchMsg = ""
    @Published var launchBusy = false
    var launchAttention: Int { launch.filter(\.attention).count }

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
    // Space Lens selection and history
    @Published var lensSel = Set<URL>()
    @Published var lensFwd: [URL] = []
    var lensSelSize: Int64 { lensNodes.filter { lensSel.contains($0.url) }.reduce(0) { $0 + $1.size } }
    // Uninstaller filters
    /// Uninstaller: filter the app list by name (matches ignoring case and accents), on top of appsFilter.
    @Published var appsQuery = ""
    @Published var appsFilter = 0   // 0 all, 1 not opened in 6 months, 2 over 500 MB, 3 App Store, 4 other sources
    /// Remembered between launches (asked for on MacRumors, 04/11/2026).
    @Published var appsSort = min(max(UserDefaults.standard.integer(forKey: "appsSort"), 0), 2) {   // 0 size, 1 name, 2 last opened
        didSet { UserDefaults.standard.set(appsSort, forKey: "appsSort") }
    }

    var lastOK = Set<URL>()
    var lastErr = ""
    @Published var undoable: Journal.Session? = Journal.load()
    var failNote: String { lastErr.isEmpty ? "" : t(" Reason: ", " Lý do: ") + lastErr }

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

    // Full Disk Access. Without it macOS hides Mail, Safari, Messages and similar folders from the scan,
    // silently, so the numbers look smaller than they are. Checked at launch and whenever the app comes back
    // to the front (the user usually returns straight from System Settings).
    @Published var fullDiskAccess = true
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
    /// Result line of the last manual "Check Now" when nothing newer was found (nil: show the usual hint).
    @Published var updResult: String? = nil
    @Published var updChecking = false
    func checkUpdates(force: Bool = false) {
        guard force || !updChecking else { return }
        guard force || autoUpdateCheck else { return }   // automatic check turned off in Settings: no request at all
        updChecking = true; if force { updResult = nil }
        let started = Date()
        Updates.check(force: force) { v in
            self.newVersion = v; self.updChecking = false
            guard force, v == nil else { return }
            // Manual check with nothing newer: say so, and tell "up to date" apart from "no answer" (record() stamps upd-last).
            let reached = (UserDefaults.standard.object(forKey: "upd-last") as? Date ?? .distantPast) >= started
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            self.updResult = reached
                ? t("You have the latest version (\(Updates.current)). Checked at \(f.string(from: Date())).",
                    "Bạn đang dùng bản mới nhất (\(Updates.current)). Đã kiểm lúc \(f.string(from: Date())).")
                : t("Could not reach the update server. Check your internet connection and try again.",
                    "Không kết nối được máy chủ cập nhật. Kiểm tra mạng rồi thử lại.")
        }
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
    // Measure with /usr/bin/du in parallel, show results progressively, cache by path.
    var lensToken = UUID()
    var sizeCache: [String: Int64] = [:]
    @Published var lensDone = 0
    @Published var lensTotal = 0
    @Published var lensCurrent = ""
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
