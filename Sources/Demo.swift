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

// MARK: - Sample data for screenshots (--demo). Nothing here touches real files.

@MainActor enum Demo {
    /// Sample rows point at real paths; nothing may be moved while demo data is on screen.
    static var active = false
    static let H = NSHomeDirectory()
    static func u(_ p: String) -> URL { URL(fileURLWithPath: H + "/" + p) }
    static func gb(_ x: Double) -> Int64 { Int64(x * 1_000_000_000) }
    static func mb(_ x: Double) -> Int64 { Int64(x * 1_000_000) }
    static func item(_ p: String, _ size: Int64, _ sel: Bool, running: Bool = false, days: Double = 0) -> CleanItem {
        var c = CleanItem(url: u(p), size: size, selected: sel, running: running)
        if days > 0 { c.date = Date().addingTimeInterval(-days * 86400) }
        return c
    }
    static func apps(_ vm: VM, detail: Bool) {
        func month(_ back: Int) -> Date { Calendar.current.date(byAdding: .month, value: -back, to: AppRules.monthStart(Date()))! }
        func ageRows(_ sec: String, _ sizes: [(Int, Double, Int)]) -> [AppRow] {
            sizes.map { AppRow(id: sec + "\($0.0)", title: AppRules.monthLabel(month($0.0)), sub: t("\($0.2) files", "\($0.2) file"), size: mb($0.1), count: $0.2, urls: [], month: month($0.0), selected: false) }
        }
        // `--demo-photos <dir>`: last month's Zalo row shows sample photos from <dir> (stock photos, never personal ones),
        // so the month viewer has something to show in screenshots. `--demo-month` opens that viewer right away.
        func demoPhotoRows(_ rows: [AppRow]) -> [AppRow] {
            let a = CommandLine.arguments
            guard let i = a.firstIndex(of: "--demo-photos"), i + 1 < a.count,
                  let files = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: a[i + 1]), includingPropertiesForKeys: [.totalFileAllocatedSizeKey]) else { return rows }
            let urls = files.filter { !$0.lastPathComponent.hasPrefix(".") }.sorted { $0.path < $1.path }
            let size = urls.reduce(Int64(0)) { $0 + Int64((try? $1.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize) ?? 0) }
            return rows.map { r in
                guard r.id == "p1" else { return r }
                return AppRow(id: r.id, title: r.title, sub: t("\(urls.count) files", "\(urls.count) file"), size: size, count: urls.count, urls: urls, month: r.month, selected: false)
            }
        }
        func row(_ p: String, _ size: Double, _ sel: Bool) -> AppRow { AppRow(id: p, title: (p as NSString).lastPathComponent, sub: "~/" + p, size: mb(size), count: 1, urls: [u(p)], month: nil, selected: sel) }
        let zalo = AppRules.all[0], chrome = AppRules.all[1], capcut = AppRules.all[4]
        let z = "Library/Application Support/ZaloData/"
        let zaloReport = AppReport(rule: zalo, groups: [
                AppGroup(id: "cache", section: zalo.sections[0], rows: [row(z + "media/update", 312, true), row(z + "Cache", 210, true), row(z + "media/1234567890123456789/ZaloDownloads/fileThumb", 101, true), row(z + "resp_cache", 1.4, true)], expanded: true),
                AppGroup(id: "picture", section: zalo.sections[1], rows: demoPhotoRows(ageRows("p", [(0, 180, 412), (1, 260, 590), (2, 310, 702), (4, 420, 1210), (7, 390, 980), (13, 530, 1430)])), expanded: true),
                AppGroup(id: "video", section: zalo.sections[2], rows: ageRows("v", [(1, 96, 3), (6, 240, 7)])),
                AppGroup(id: "file", section: zalo.sections[3], rows: ageRows("f", [(0, 12, 9), (3, 40, 22)])),
                AppGroup(id: "db", section: zalo.sections[4], rows: [row(z + "Database", 520, false)]),
            ], running: true)
        let en = appLang == "en"
        let chromeReport = AppReport(rule: chrome, groups: [
                AppGroup(id: "cache", section: chrome.sections[0], rows: [row("Library/Caches/Google/Chrome/Default/Code Cache", 300, true), row("Library/Application Support/Google/Chrome/Default/Service Worker/CacheStorage", 1300, true), row("Library/Application Support/Google/Chrome/component_crx_cache", 240, true)], expanded: en),
                AppGroup(id: "ai", section: chrome.sections[1], rows: [row("Library/Application Support/Google/Chrome/OptGuideOnDeviceModel", 4000, false)], expanded: en),
                AppGroup(id: "profile", section: chrome.sections[2], rows: [row("Library/Application Support/Google/Chrome/Default/History", 48, false)], expanded: en),
            ], running: en)
        let c = "Movies/CapCut/User Data/"
        let capcutReport = AppReport(rule: capcut, groups: [
                AppGroup(id: "cache", section: capcut.sections[0], rows: [row(c + "Cache/frameThumbnail", 860, true), row(c + "Cache/audioWave", 95, true)]),
                AppGroup(id: "speech", section: capcut.sections.first { $0.id == "speech" }!, rows: [row(c + "Cache/recognize", 410, false)]),
                AppGroup(id: "render", section: capcut.sections.first { $0.id == "render" }!, rows: [row(c + "Cache/prerender", 1200, false), row(c + "Cache/agencycache", 600, false)]),
                AppGroup(id: "projects", section: capcut.sections.first { $0.id == "projects" }!, rows: [row(c + "Projects", 6200, false)]),
            ], running: false)
        // More apps so the list looks like a real, lived-in Mac. Sizes are sample values (MB per section, 0 = empty).
        func extra(_ id: String, _ sizes: [Double], running: Bool = false) -> AppReport? {
            guard let r = AppRules.all.first(where: { $0.id == id }) else { return nil }
            var gs: [AppGroup] = []
            for (i, sec) in r.sections.enumerated() where i < sizes.count && sizes[i] > 0 {
                let mbv = sizes[i]
                let rows: [AppRow] = sec.byAge
                    ? ageRows(id + sec.id, [(0, mbv * 0.2, 120), (2, mbv * 0.3, 260), (6, mbv * 0.5, 410)])
                    : [row((sec.paths.first ?? "Library").replacingOccurrences(of: "*", with: "Default"), mbv, sec.safety == .safe)]
                gs.append(AppGroup(id: sec.id, section: sec, rows: rows))
            }
            return AppReport(rule: r, groups: gs, running: running)
        }
        let more: [String: AppReport] = [
            "telegram": extra("telegram", [380, 2400, 640]), "whatsapp": extra("whatsapp", [150, 1800, 420]),
            "slack": extra("slack", [920, 210], running: true), "vscode": extra("vscode", [1100, 2300, 640, 380]),
            "edge": extra("edge", [900, 0, 60]),
        ].compactMapValues { $0 }
        func pick(_ ids: [String]) -> [AppReport] { ids.compactMap { more[$0] } }
        // English screenshots lead with apps a US reader knows; Vietnamese ones lead with Zalo.
        vm.appReports = en ? [chromeReport, capcutReport] + pick(["vscode", "slack", "telegram", "whatsapp", "edge"]) + [zaloReport]
                           : [zaloReport, chromeReport, capcutReport] + pick(["telegram", "vscode", "slack", "edge", "whatsapp"])
        vm.appScanned = true
        if detail {
            if en { vm.appSel = "chrome" } else { vm.appSel = "zalo"; vm.selectOlder("zalo", months: 6) }
        }
        if CommandLine.arguments.contains("--demo-month") { vm.appSel = "zalo"; vm.openMonth("zalo", "picture", "p1") }
    }
    static func load(_ vm: VM) {
        active = true
        vm.cats = [
            Category(id: "usercache", titleEN: "User Cache Files", titleVI: "Bộ nhớ đệm người dùng", icon: "internaldrive",
                     descEN: "Temporary files apps rebuild on their own", descVI: "File tạm, app tự tạo lại khi cần",
                     items: [item("Library/Caches/com.google.Chrome", mb(2140), true),
                             item("Library/Caches/com.spotify.client", mb(1380), true),
                             item("Library/Caches/com.tinyspeck.slackmacgap", mb(612), false, running: true),
                             item("Library/Caches/pip", mb(840), true),
                             item("Library/Caches/Homebrew", mb(1210), true)], expanded: true),
            Category(id: "appcache", titleEN: "App Caches", titleVI: "Bộ nhớ đệm trong app", icon: "square.stack.3d.up",
                     descEN: "Web and graphics caches from Chrome, Slack, Notion, VS Code...", descVI: "Bộ nhớ đệm web, đồ hoạ của Chrome, Slack, Notion, VS Code...",
                     items: [item("Library/Application Support/Code/CachedData", mb(930), true),
                             item("Library/Application Support/Notion/Cache", mb(455), true),
                             item("Library/Application Support/discord/Cache", mb(388), true),
                             item("Library/Application Support/Google/Chrome/Default/GPUCache", mb(126), true)], expanded: true),
            Category(id: "logs", titleEN: "Log Files", titleVI: "Nhật ký (log)", icon: "doc.text",
                     descEN: "Error and activity logs, safe to remove", descVI: "Nhật ký lỗi và hoạt động, xoá an toàn",
                     items: [item("Library/Logs/DiagnosticReports", mb(212), true), item("Library/Logs/JetBrains", mb(96), true)]),
            Category(id: "dev", titleEN: "Developer & Wallpaper Junk", titleVI: "Công cụ và hình nền", icon: "hammer",
                     descEN: "npm cache, downloaded aerial wallpapers", descVI: "Bộ nhớ đệm npm, hình nền động đã tải",
                     items: [item(".npm/_cacache", mb(3420), true), item("Library/Application Support/com.apple.wallpaper/aerials", gb(6.8), true)]),
            Category(id: "drafts", titleEN: "Project Drafts", titleVI: "Nháp trong thư mục dự án", icon: "tray.full",
                     descEN: "_to_delete and _tmp folders in your project folders", descVI: "Thư mục _to_delete, _tmp trong thư mục dự án",
                     safety: .review, items: [item("Projects/ai-video/_tmp", mb(2860), false), item("Projects/landing-page/_to_delete", mb(418), false)]),
            Category(id: "downloads", titleEN: "Old Downloads (14+ days)", titleVI: "Downloads cũ hơn 14 ngày", icon: "arrow.down.circle",
                     descEN: "Not selected by default. Review before removing", descVI: "Mặc định không tick, xem rồi chọn",
                     safety: .review, items: [item("Downloads/Figma-125.4.dmg", mb(412), false, days: 41), item("Downloads/Zoom.pkg", mb(98), false, days: 63),
                             item("Downloads/dataset-v2.zip", gb(2.4), false, days: 28)]),
        ]
        vm.phase = .summary
        // Screenshot helpers: --demo-review opens the list of items, --demo-done the result screen with Undo (an in-memory
        // session only, nothing on disk; Undo there finds no files and changes nothing).
        let args = CommandLine.arguments
        if args.contains("--demo-review") { vm.phase = .review }
        if args.contains("--demo-done") {
            let sel = vm.cats.flatMap { $0.items.filter(\.selected) }
            let freed = sel.reduce(0) { $0 + $1.size }
            vm.lastFreed = freed; vm.lastCount = sel.count
            vm.lastResult = t("Moved \(sel.count) items (\(fmt(freed))) to the Trash.", "Đã chuyển \(sel.count) mục (\(fmt(freed))) vào Thùng rác.")
            vm.undoable = Journal.Session(date: Date(), label: "cleanup", entries: sel.map { Journal.Entry(from: $0.url.path, to: "/nonexistent/demo", size: $0.size) })
            vm.phase = .done
        }
        vm.large = [item("Movies/Screen Recording 2026-09-14.mov", gb(8.2), false, days: 42),
                    item("Downloads/sdxl-base-1.0.safetensors", gb(6.9), false, days: 77),
                    item("Documents/Footage/interview-raw.mp4", gb(4.1), false, days: 120),
                    item("Downloads/ubuntu-24.04-desktop-arm64.iso", gb(3.2), false, days: 160),
                    item("Pictures/Exports/product-shoot-4k.zip", gb(1.9), false, days: 33),
                    item("Documents/Backups/site-backup-2026-06.tar.gz", gb(1.4), false, days: 118),
                    item("Music/Logic/Podcast EP12.logicx", mb(860), false, days: 54)]
        vm.largePhase = .review
        var d1 = DupGroup(size: mb(46), items: [item("Projects/brand/hero-banner.psd", mb(46), false),
                                                  item("Downloads/hero-banner.psd", mb(46), true),
                                                  item("Desktop/hero-banner copy.psd", mb(46), true)])
        d1.expanded = true
        var d2 = DupGroup(size: mb(18), items: [item("Projects/ai-video/assets/intro.mp4", mb(18), false),
                                                  item("Downloads/intro.mp4", mb(18), true)])
        d2.items[0].refStrong = [H + "/Projects/ai-video/render.py"]
        d2.expanded = true
        var d3 = DupGroup(size: mb(12), items: [item("Pictures/IMG_2041.HEIC", mb(12), false), item("Desktop/IMG_2041.HEIC", mb(12), true)])
        d3.items[1].refWeak = [H + "/Projects/blog/notes.md"]
        d3.expanded = true
        vm.dupes = [d1, d2, d3, DupGroup(size: mb(9), items: [item("Documents/contract-v3.pdf", mb(9), false), item("Downloads/contract-v3 (1).pdf", mb(9), true)])]
        vm.lensPath = [URL(fileURLWithPath: H)]
        vm.lensNodes = [("Library", 48.3), ("Documents", 31.2), ("Movies", 18.4), (".ollama", 12.6), ("Downloads", 9.1),
                        ("Pictures", 7.4), ("Developer", 6.2), ("Projects", 5.8), ("Desktop", 2.3), ("Music", 1.1), (".npm", 0.9), (".cache", 0.6)]
            .map { Node(url: u($0.0), size: gb($0.1), isDir: true) }
        // Apps that are installed on the capture Mac, so Finder supplies real icons (a missing .app shows a blank page icon).
        func app(_ n: String, _ bid: String, _ size: Int64, _ days: Double, _ rel: [CleanItem] = []) -> AppEntry {
            AppEntry(url: URL(fileURLWithPath: "/Applications/\(n).app"), name: n, bundleID: bid, size: size,
                     lastUsed: Date().addingTimeInterval(-days * 86400), related: rel)
        }
        let slack = app("Slack", "com.tinyspeck.slackmacgap", mb(535), 75,
                        [item("Library/Application Support/Slack", mb(640), true),
                         item("Library/Caches/com.tinyspeck.slackmacgap", mb(118), true),
                         item("Library/Preferences/com.tinyspeck.slackmacgap.plist", 36_000, true),
                         item("Library/Logs/Slack", mb(14), true),
                         item("Library/Saved Application State/com.tinyspeck.slackmacgap.savedState", 380_000, true)])
        let zalo = app("Zalo", "com.vng.zalo", mb(762), 0,
                       [item("Library/Application Support/ZaloData", gb(2.9), true),
                        item("Library/Caches/com.vng.zalo", mb(103), true),
                        item("Library/Preferences/com.vng.zalo.plist", 28_000, true),
                        item("Library/Saved Application State/com.vng.zalo.savedState", 290_000, true)])
        let rest = [app("Microsoft Outlook", "com.microsoft.Outlook", gb(2.4), 40),
                    app("CapCut", "com.lemon.lvoverseas", gb(1.9), 9),
                    app("Google Chrome", "com.google.Chrome", gb(1.5), 0),
                    app("Visual Studio Code", "com.microsoft.VSCode", gb(1.4), 2),
                    app("Microsoft Edge", "com.microsoft.edgemac", gb(1.1), 120),
                    app("WhatsApp", "net.whatsapp.WhatsApp", mb(734), 6),
                    app("Claude", "com.anthropic.claudefordesktop", mb(619), 0),
                    app("Telegram", "ru.keepcoder.Telegram", mb(346), 4),
                    app("Rectangle", "com.knollsoft.Rectangle", mb(11), 1)]
        let pickApp = appLang == "en" ? slack : zalo
        vm.apps = [pickApp] + rest + [appLang == "en" ? zalo : slack]
        vm.selApp = pickApp.id
    }
}
