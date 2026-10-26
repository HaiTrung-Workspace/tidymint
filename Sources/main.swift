// Disk Cleanup: a free, open-source disk cleaner for macOS, built for people who work with AI tools.
// Author: Hai Trung. License: MIT (see LICENSE). Provided "as is", without warranty.
// Safety rules: items are only moved to the Trash (the "Empty Trash" button asks first);
// cloud libraries, Photos, Mail, keychains, browser profiles and Apple system caches are never touched.
// Note: no @State anywhere (the @State macro needs an Xcode-only plugin); use Flag/ObservableObject instead.
import SwiftUI
import AppKit
import UserNotifications
import ServiceManagement
import CryptoKit

// MARK: - Theme

/// Colour themes. Palettes are inspired by Apple's 2026 colours (approximate values, not official hex codes).
struct Palette {
    let id: String, nameEN: String, nameVI: String
    let bg: [UInt32]          // window gradient, top-left to bottom-right
    let accent: [UInt32]      // buttons, progress, selection
    let link: UInt32          // small text buttons
    let bubbles: [UInt32]     // Space Lens
    let icon: [UInt32]        // app icon background, top to bottom
}

let palettes: [Palette] = [
    Palette(id: "nightsky", nameEN: "Night Sky", nameVI: "Night Sky (xanh đêm)",
            bg: [0x05070f, 0x0f1a33, 0x1d2f5a], accent: [0x9fd3ff, 0x4f7cff], link: 0x9fd3ff,
            bubbles: [0x4f7cff, 0x9fd3ff, 0x6c5ce7, 0x5fd3c6, 0xa29bfe, 0x74b9ff, 0x81ecec, 0xdfe6e9],
            icon: [0x0f1a33, 0x23407f, 0x5b8cff]),
    Palette(id: "burgundy", nameEN: "Burgundy", nameVI: "Burgundy (đỏ rượu vang)",
            bg: [0x14070b, 0x3d1020, 0x6e1d33], accent: [0xf2a7b0, 0xb8324f], link: 0xf2a7b0,
            bubbles: [0xb8324f, 0xf2a7b0, 0xd9776b, 0xe8c07d, 0x8e3b5f, 0xc96f8a, 0xf5d0c5, 0x7a4a6a],
            icon: [0x2a0a15, 0x6e1d33, 0xc4455f]),
    Palette(id: "goldengate", nameEN: "Golden Gate", nameVI: "Golden Gate (hoàng hôn)",
            bg: [0x110c0a, 0x35200f, 0x7d3a19], accent: [0xffcf73, 0xff7a3d], link: 0xffcf73,
            bubbles: [0xff7a3d, 0xffcf73, 0xe85d4a, 0xf2a65a, 0x5b8bd9, 0xc9a96e, 0xff9f80, 0x8fb3e0],
            icon: [0x3a1f12, 0xb5532a, 0xffb15c]),
    Palette(id: "pride", nameEN: "Pride", nameVI: "Pride (cầu vồng)",
            bg: [0x14111c, 0x1f1830, 0x2b2044], accent: [0xff5e5e, 0xffa94d, 0xffe066, 0x69db7c, 0x4dabf7, 0xb197fc], link: 0xffe066,
            bubbles: [0xff5e5e, 0xffa94d, 0xffe066, 0x69db7c, 0x4dabf7, 0xb197fc, 0xf783ac, 0x63e6be],
            icon: [0xe8414a, 0xf5902e, 0xf7d33a, 0x3fb36b, 0x3c7bf0, 0x8e4fd6]),
]

var appTheme: String = UserDefaults.standard.string(forKey: "theme").flatMap { id in palettes.contains { $0.id == id } ? id : nil } ?? "nightsky"

enum Theme {
    static var p: Palette { palettes.first { $0.id == appTheme } ?? palettes[0] }
    static var bg: LinearGradient { LinearGradient(colors: p.bg.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing) }
    static let sidebar = Color.black.opacity(0.22)
    static let card = Color.white.opacity(0.08)
    static let cardHi = Color.white.opacity(0.14)
    static var accent: LinearGradient { LinearGradient(colors: p.accent.map { Color(hex: $0) }, startPoint: .leading, endPoint: .trailing) }
    static var accentSolid: Color { Color(hex: p.accent[p.accent.count - 1]) }
    static var link: Color { Color(hex: p.link) }
    static let green = Color(hex: 0x6ee7a8)
    static let warn = Color(hex: 0xffc56b)
    static let danger = Color(hex: 0xff6b6b)
    static let sub = Color.white.opacity(0.62)
    static var bubbles: [Color] { p.bubbles.map { Color(hex: $0) } }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }
}

func fmt(_ b: Int64) -> String {
    let f = ByteCountFormatter(); f.countStyle = .file; f.allowedUnits = [.useKB, .useMB, .useGB]
    return f.string(fromByteCount: b)
}

// MARK: - Language (VI/EN)

var appLang: String = UserDefaults.standard.string(forKey: "lang")
    ?? ((Locale.preferredLanguages.first ?? "en").hasPrefix("vi") ? "vi" : "en")
func t(_ en: String, _ vi: String) -> String { appLang == "vi" ? vi : en }

/// Replacement for @State.
final class Flag: ObservableObject { @Published var v = false }

/// macOS-style hover: soft highlight behind the row.
struct HoverBG: ViewModifier {
    var radius: CGFloat = 8
    var color: Color = Color.white.opacity(0.08)
    @StateObject private var h = Flag()
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius).fill(h.v ? color : Color.clear))
            .onHover { v in withAnimation(.easeOut(duration: 0.12)) { h.v = v } }
    }
}
/// Button hover: brighten and lift slightly.
struct HoverLift: ViewModifier {
    @StateObject private var h = Flag()
    func body(content: Content) -> some View {
        content
            .brightness(h.v ? 0.08 : 0)
            .scaleEffect(h.v ? 1.02 : 1)
            .onHover { v in withAnimation(.easeOut(duration: 0.12)) { h.v = v } }
    }
}
extension View {
    func hoverBG(_ radius: CGFloat = 8, _ color: Color = Color.white.opacity(0.08)) -> some View { modifier(HoverBG(radius: radius, color: color)) }
    func hoverLift() -> some View { modifier(HoverLift()) }
}

/// Menu bar popover row: system accent highlight with white text on hover, like a macOS menu.
struct MenuRow: View {
    let title: String
    var disabled = false
    let action: () -> Void
    @StateObject private var h = Flag()
    var body: some View {
        Button(action: action) {
            HStack { Text(title).font(.system(size: 13)); Spacer() }
                .foregroundColor(disabled ? .secondary : (h.v ? .white : .primary))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 5).fill(h.v && !disabled ? Color.accentColor : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(disabled)
        .onHover { v in h.v = v }
    }
}

// MARK: - Ignore list

/// User settings stored in UserDefaults.
enum Prefs {
    /// Folders where the user keeps projects (code, AI workspaces). Used to look for drafts,
    /// to never pre-select duplicates inside them, and to check links before deleting.
    static var projectFolders: [String] {
        get { UserDefaults.standard.stringArray(forKey: "projectFolders") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "projectFolders") }
    }
    /// Extra path keywords that must never be touched (e.g. a browser-profile folder name).
    static var protectedKeywords: [String] { UserDefaults.standard.stringArray(forKey: "protectedKeywords") ?? [] }
    static func inProject(_ p: String) -> Bool { projectFolders.contains { p == $0 || p.hasPrefix($0 + "/") } }
}

enum IgnoreList {
    static let key = "ignoredPaths"
    static var paths: [String] {
        get { UserDefaults.standard.stringArray(forKey: key) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
    static func add(_ p: String) { if !paths.contains(p) { paths.append(p) } }
    static func remove(_ p: String) { paths.removeAll { $0 == p } }
    static func contains(_ p: String) -> Bool { paths.contains { p == $0 || p.hasPrefix($0 + "/") } }
}

// MARK: - Model

struct CleanItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let size: Int64
    var selected: Bool
    var running = false
    var refStrong: [String] = []   // referenced by a script or skill
    var refWeak: [String] = []     // only mentioned in notes
    var note: String {
        if running { return t("App is open, quit it first", "App đang mở, tắt app rồi dọn") }
        if !refStrong.isEmpty { return t("Used by \(refStrong.count) script/skill", "Script/skill đang dùng (\(refStrong.count))") }
        if !refWeak.isEmpty { return t("Mentioned in \(refWeak.count) notes", "Được nhắc trong \(refWeak.count) ghi chú") }
        return ""
    }
    var noteColor: Color { !refStrong.isEmpty ? Theme.danger : Theme.warn }
    var refHelp: String { (refStrong + refWeak).map { $0.replacingOccurrences(of: NSHomeDirectory(), with: "~") }.joined(separator: "\n") }
    var date: Date? = nil
    var name: String { url.lastPathComponent }
    var shortPath: String { url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
}

struct Category: Identifiable {
    let id: String
    let titleEN: String, titleVI: String
    let icon: String
    let descEN: String, descVI: String
    var title: String { t(titleEN, titleVI) }
    var desc: String { t(descEN, descVI) }
    var items: [CleanItem]
    var expanded = false
    var total: Int64 { items.reduce(0) { $0 + $1.size } }
    var selectedSize: Int64 { items.filter(\.selected).reduce(0) { $0 + $1.size } }
    var state: Int {
        let n = items.filter(\.selected).count
        return n == 0 ? 0 : (n == items.count ? 2 : 1)
    }
}

struct Node: Identifiable {
    let id = UUID()
    let url: URL
    let size: Int64
    let isDir: Bool
    var otherCount = 0          // > 0: the "Other" bubble that groups small items
    var name: String { otherCount > 0 ? t("Other (\(otherCount))", "Khác (\(otherCount))") : url.lastPathComponent }
}

/// Group items under 1% of the total into one "Other" bubble (at most 40 separate bubbles).
func lensBubbles(_ nodes: [Node], folder: URL?) -> [Node] {
    let total = nodes.reduce(0) { $0 + $1.size }
    guard total > 0 else { return [] }
    var big: [Node] = [], small: [Node] = []
    for n in nodes { if Double(n.size) >= Double(total) * 0.01 && big.count < 40 { big.append(n) } else { small.append(n) } }
    if !small.isEmpty, let f = folder {
        big.append(Node(url: f, size: small.reduce(0) { $0 + $1.size }, isDir: false, otherCount: small.count))
    }
    return big
}

// MARK: - Scanner

enum Scanner {
    static let home = URL(fileURLWithPath: NSHomeDirectory())
    static let lib = home.appendingPathComponent("Library")
    static let fm = FileManager.default

    static let neverBase = ["/Application Support/Claude/", "Gologin", "CloudStorage", "Photos Library",
                            "/Caches/com.apple.", "Mobile Documents", "Keychain", "Passwords", "/Library/Mail/"]
    static var never: [String] { neverBase + Prefs.protectedKeywords }

    static func size(_ url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        if !isDir.boolValue {
            let v = try? url.resourceValues(forKeys: Set(keys))
            return Int64(v?.totalFileAllocatedSize ?? v?.fileAllocatedSize ?? 0)
        }
        var total: Int64 = 0
        if let en = fm.enumerator(at: url, includingPropertiesForKeys: keys, options: [], errorHandler: { _, _ in true }) {
            for case let f as URL in en {
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
            case n.contains("Chrome"): k += ["/Google/", "com.google.Chrome"]
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
            default: break
            }
            if !b.isEmpty { k.append(b) }
        }
        return k
    }

    static func blocked(_ p: String) -> Bool { never.contains { p.contains($0) } }
    static func skip(_ p: String) -> Bool { blocked(p) || IgnoreList.contains(p) }

    static func make(_ urls: [URL], running: [String], defaultOn: Bool = true, minSize: Int64 = 512 * 1024) -> [CleanItem] {
        var out: [CleanItem] = []
        for u in urls where !skip(u.path) {
            let s = size(u)
            guard s >= minSize else { continue }
            let isRunning = running.contains { u.path.contains($0) }
            out.append(CleanItem(url: u, size: s, selected: defaultOn && !isRunning, running: isRunning))
        }
        return out.sorted { $0.size > $1.size }
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

    static func scanJunk() -> [Category] {
        let run = runningKeys()
        let AS = lib.appendingPathComponent("Application Support")
        let appRoots = [AS, lib.appendingPathComponent("Containers"), lib.appendingPathComponent("Group Containers")]
        var cats: [Category] = []

        cats.append(Category(id: "usercache", titleEN: "User Cache Files", titleVI: "Bộ nhớ đệm người dùng", icon: "internaldrive",
                             descEN: "Temporary files apps rebuild on their own", descVI: "File tạm, app tự tạo lại khi cần",
                             items: make(children(lib.appendingPathComponent("Caches")), running: run)))

        let appCacheNames: Set<String> = ["Cache", "Code Cache", "GPUCache", "DawnCache", "DawnGraphiteCache", "GraphiteDawnCache",
                                          "ShaderCache", "CacheStorage", "CachedData", "CachedExtensionVSIXs", "Crashpad"]
        cats.append(Category(id: "appcache", titleEN: "App Caches", titleVI: "Bộ nhớ đệm trong app", icon: "square.stack.3d.up",
                             descEN: "Web and graphics caches from Chrome, Slack, Notion, VS Code...", descVI: "Bộ nhớ đệm web, đồ hoạ của Chrome, Slack, Notion, VS Code...",
                             items: make(findDirs(appRoots, names: appCacheNames, depth: 6), running: run)))

        let logs = [lib.appendingPathComponent("Logs")] + findDirs(appRoots, names: ["logs", "Logs"], depth: 6)
        cats.append(Category(id: "logs", titleEN: "Log Files", titleVI: "Nhật ký (log)", icon: "doc.text",
                             descEN: "Error and activity logs, safe to remove", descVI: "Nhật ký lỗi và hoạt động, xoá an toàn",
                             items: make(logs, running: run)))

        var dev: [URL] = []
        let npm = home.appendingPathComponent(".npm/_cacache"); if fm.fileExists(atPath: npm.path) { dev.append(npm) }
        let aer = AS.appendingPathComponent("com.apple.wallpaper/aerials"); if fm.fileExists(atPath: aer.path) { dev.append(aer) }
        cats.append(Category(id: "dev", titleEN: "Developer & Wallpaper Junk", titleVI: "Công cụ và hình nền", icon: "hammer",
                             descEN: "npm cache, downloaded aerial wallpapers", descVI: "Bộ nhớ đệm npm, hình nền động đã tải",
                             items: make(dev, running: run)))

        let projects = Prefs.projectFolders.map { URL(fileURLWithPath: $0) }
        cats.append(Category(id: "drafts", titleEN: "Project Drafts", titleVI: "Nháp trong thư mục dự án", icon: "tray.full",
                             descEN: "_to_delete and _tmp folders in your project folders (set them in Settings)",
                             descVI: "Thư mục _to_delete, _tmp trong thư mục dự án (chọn ở Cài đặt)",
                             items: make(findDirs(projects, names: ["_to_delete", "_to-delete", "_tmp"], depth: 5), running: run, minSize: 1)))

        let cutoff = Date().addingTimeInterval(-14 * 86400)
        let dls = children(home.appendingPathComponent("Downloads")).filter {
            ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()) < cutoff
        }
        cats.append(Category(id: "downloads", titleEN: "Old Downloads (14+ days)", titleVI: "Downloads cũ hơn 14 ngày", icon: "arrow.down.circle",
                             descEN: "Not selected by default. Review before removing", descVI: "Mặc định không tick, xem rồi chọn",
                             items: make(dls, running: run, defaultOn: false, minSize: 1)))

        return cats.filter { !$0.items.isEmpty }
    }

    static func scanLarge(minMB: Int64 = 100) -> [CleanItem] {
        let roots = ["Documents", "Downloads", "Desktop", "Movies", "Music", "Pictures"].map { home.appendingPathComponent($0) }
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey, .contentAccessDateKey, .contentModificationDateKey]
        var out: [CleanItem] = []
        for r in roots {
            guard let en = fm.enumerator(at: r, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles, .skipsPackageDescendants],
                                         errorHandler: { _, _ in true }) else { continue }
            for case let f as URL in en {
                if skip(f.path) { en.skipDescendants(); continue }
                guard let v = try? f.resourceValues(forKeys: keys), v.isRegularFile == true else { continue }
                let s = Int64(v.totalFileAllocatedSize ?? 0)
                if s >= minMB * 1024 * 1024 {
                    out.append(CleanItem(url: f, size: s, selected: false, date: v.contentAccessDate ?? v.contentModificationDate))
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

// MARK: - Circle packing (greedy)

struct Bubble { let node: Node; var x: CGFloat; var y: CGFloat; var r: CGFloat; let color: Color }

func pack(_ nodes: [Node], in size: CGSize) -> [Bubble] {
    // Bubble area is proportional to size (radius = square root); no forced minimum size.
    guard !nodes.isEmpty, size.width > 50 else { return [] }
    let maxS = Double(nodes.map(\.size).max() ?? 1)
    var bs: [Bubble] = []
    for (i, n) in nodes.enumerated() {
        let r = CGFloat(100 * sqrt(Double(n.size) / maxS))
        guard r > 0.5 else { continue }
        let col = n.otherCount > 0 ? Color.white.opacity(0.35) : Theme.bubbles[i % Theme.bubbles.count]
        if bs.isEmpty { bs.append(Bubble(node: n, x: 0, y: 0, r: r, color: col)); continue }
        var best: (CGFloat, CGFloat, CGFloat)? = nil
        for b in bs {
            for a in stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 36) {
                let d = b.r + r + 2
                let x = b.x + CGFloat(cos(a)) * d, y = b.y + CGFloat(sin(a)) * d
                if bs.allSatisfy({ hypot($0.x - x, $0.y - y) >= $0.r + r + 1.5 }) {
                    let dist = hypot(x * 0.75, y)
                    if best == nil || dist < best!.2 { best = (x, y, dist) }
                }
            }
        }
        if best == nil { // fallback: spiral outwards until there is room, so no item is dropped
            var rad: CGFloat = 0, a = 0.0
            while best == nil {
                rad += 2; a += 0.35
                let x = rad * CGFloat(cos(a)), y = rad * CGFloat(sin(a))
                if bs.allSatisfy({ hypot($0.x - x, $0.y - y) >= $0.r + r + 1.5 }) { best = (x, y, 0) }
            }
        }
        bs.append(Bubble(node: n, x: best!.0, y: best!.1, r: r, color: col))
    }
    let minX = bs.map { $0.x - $0.r }.min()!, maxX = bs.map { $0.x + $0.r }.max()!
    let minY = bs.map { $0.y - $0.r }.min()!, maxY = bs.map { $0.y + $0.r }.max()!
    let s = min((size.width - 20) / (maxX - minX), (size.height - 20) / (maxY - minY))
    let cx = (minX + maxX) / 2, cy = (minY + maxY) / 2
    return bs.map { Bubble(node: $0.node, x: ($0.x - cx) * s + size.width / 2, y: ($0.y - cy) * s + size.height / 2, r: $0.r * s, color: $0.color) }
}

// MARK: - Applications (Uninstaller, Leftovers, Installers)

struct AppEntry: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let bundleID: String
    var size: Int64
    var lastUsed: Date?
    var related: [CleanItem] = []
}

enum Apps {
    static let L = Scanner.lib
    static let protectedPrefixes = ["com.apple.", "com.anthropic.", Bundle.main.bundleIdentifier ?? "com.haitrung.diskcleanup"]
    static func isProtected(_ id: String) -> Bool { protectedPrefixes.contains { id.hasPrefix($0) } || id.lowercased().contains("claude") }

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
            guard let b = Bundle(url: u), let id = b.bundleIdentifier, !isProtected(id) else { return }
            let name = (b.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (b.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? u.deletingPathExtension().lastPathComponent
            let last = NSMetadataItem(url: u)?.value(forAttribute: "kMDItemLastUsedDate") as? Date
            let e = AppEntry(url: u, name: u.deletingPathExtension().lastPathComponent.isEmpty ? name : u.deletingPathExtension().lastPathComponent,
                             bundleID: id, size: Cloud.localSize(u.path), lastUsed: last)
            lock.lock(); out[i] = e; lock.unlock()
        }
        return out.compactMap { $0 }.sorted { $0.size > $1.size }
    }

    static func related(_ a: AppEntry) -> [CleanItem] {
        let id = a.bundleID, n = a.name
        var c: [URL] = [
            L.appendingPathComponent("Application Support/\(id)"), L.appendingPathComponent("Application Support/\(n)"),
            L.appendingPathComponent("Caches/\(id)"), L.appendingPathComponent("Caches/\(n)"),
            L.appendingPathComponent("Preferences/\(id).plist"),
            L.appendingPathComponent("Containers/\(id)"),
            L.appendingPathComponent("Application Scripts/\(id)"),
            L.appendingPathComponent("Saved Application State/\(id).savedState"),
            L.appendingPathComponent("HTTPStorages/\(id)"), L.appendingPathComponent("HTTPStorages/\(id).binarycookies"),
            L.appendingPathComponent("WebKit/\(id)"),
            L.appendingPathComponent("Logs/\(n)"),
        ]
        c += Scanner.children(L.appendingPathComponent("Group Containers")).filter { $0.lastPathComponent.hasSuffix(id) }
        c += Scanner.children(L.appendingPathComponent("LaunchAgents")).filter { $0.lastPathComponent.hasPrefix(id) }
        var seen = Set<String>(), out: [CleanItem] = []
        for u in c where FileManager.default.fileExists(atPath: u.path) && !seen.contains(u.path) && !Scanner.blocked(u.path) {
            seen.insert(u.path)
            out.append(CleanItem(url: u, size: Cloud.localSize(u.path), selected: true))
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
                if isProtected(id) || id.contains(".apple.") || shared.contains(where: { id.hasPrefix($0) }) || installed.contains(id) || vendors.contains(vendor) { continue }
                if NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil { continue }
                if Scanner.skip(u.path) { continue }
                let s = Cloud.localSize(u.path)
                if s > 0 { out.append(CleanItem(url: u, size: s, selected: true)) }
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
                let s = Int64((try? f.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize) ?? 0)
                out.append(CleanItem(url: f, size: s, selected: true))
            }
        }
        return out.sorted { $0.size > $1.size }
    }
}

// MARK: - Duplicates

struct DupGroup: Identifiable {
    let id = UUID()
    let size: Int64
    var items: [CleanItem]
    var expanded = false
    var wasted: Int64 { size * Int64(max(0, items.count - 1)) }
    var selectedSize: Int64 { items.filter(\.selected).reduce(0) { $0 + $1.size } }
}

enum Dupes {
    static let roots = ["Documents", "Downloads", "Desktop", "Pictures", "Movies", "Music"].map { Scanner.home.appendingPathComponent($0) }
    static let skipDirs: Set<String> = [".git", "node_modules", "__pycache__", ".venv", "venv", "build", "DerivedData"]

    static func hash(_ u: URL, limit: Int? = nil) -> String? {
        guard let h = try? FileHandle(forReadingFrom: u) else { return nil }
        defer { try? h.close() }
        var hasher = SHA256(); var read = 0
        while true {
            let want = limit.map { min(1 << 20, $0 - read) } ?? (1 << 20)
            if want <= 0 { break }
            guard let d = try? h.read(upToCount: want), !d.isEmpty else { break }
            hasher.update(data: d); read += d.count
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Which copy to keep: not in Downloads/Desktop/_tmp, then shorter path, then older.
    static func keepScore(_ u: URL) -> (Int, Int) {
        let p = u.path
        let temp = ["/Downloads/", "/Desktop/", "/_tmp", "/_to_delete", "/_to-delete"].contains { p.contains($0) } ? 1 : 0
        return (temp, p.count)
    }

    static func scan(minBytes: Int64 = 1 << 20, progress: @escaping (Int) -> Void) -> [DupGroup] {
        var bySize: [Int64: [URL]] = [:]
        var count = 0
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey, .isDirectoryKey]
        for r in roots {
            guard let en = FileManager.default.enumerator(at: r, includingPropertiesForKeys: Array(keys),
                                                          options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, _ in true }) else { continue }
            for case let f as URL in en {
                if skipDirs.contains(f.lastPathComponent) || Scanner.skip(f.path) { en.skipDescendants(); continue }
                guard let v = try? f.resourceValues(forKeys: keys), v.isRegularFile == true, let sz = v.fileSize, Int64(sz) >= minBytes else { continue }
                bySize[Int64(sz), default: []].append(f)
                count += 1; if count % 500 == 0 { progress(count) }
            }
        }
        var groups: [DupGroup] = []
        for (sz, urls) in bySize where urls.count > 1 {
            var byHead: [String: [URL]] = [:]
            for u in urls { if let h = hash(u, limit: 65536) { byHead[h, default: []].append(u) } }
            for (_, us) in byHead where us.count > 1 {
                var byFull: [String: [URL]] = [:]
                for u in us { if let h = hash(u) { byFull[h, default: []].append(u) } }
                for (_, same) in byFull where same.count > 1 {
                    let sorted = same.sorted { keepScore($0) < keepScore($1) }
                    let items = sorted.enumerated().map { i, u -> CleanItem in
                        let d = (try? u.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                        // Keep the first copy; pre-select extra copies only outside project folders (Downloads, Desktop...).
                        return CleanItem(url: u, size: sz, selected: i > 0 && !Prefs.inProject(u.path), date: d)
                    }
                    groups.append(DupGroup(size: sz, items: items))
                }
            }
        }
        return groups.sorted { $0.wasted > $1.wasted }
    }
}

// MARK: - Cloud

struct CloudProvider: Identifiable {
    let id = UUID()
    let name: String        // Google Drive, iCloud Drive, Dropbox...
    let account: String
    let root: URL
    let isICloud: Bool
    var local: Int64 = 0
    var items: [Node] = []
    var expanded = false
}

enum Cloud {
    static func providers() -> [CloudProvider] {
        var out: [CloudProvider] = []
        let cs = Scanner.lib.appendingPathComponent("CloudStorage")
        for d in Scanner.children(cs) {
            let n = d.lastPathComponent
            var name = n, acc = ""
            if let r = n.range(of: "-") { name = String(n[..<r.lowerBound]); acc = String(n[r.upperBound...]) }
            name = name.replacingOccurrences(of: "GoogleDrive", with: "Google Drive").replacingOccurrences(of: "OneDrive", with: "OneDrive")
            out.append(CloudProvider(name: name, account: acc, root: d, isICloud: false))
        }
        let ic = Scanner.lib.appendingPathComponent("Mobile Documents/com~apple~CloudDocs")
        if FileManager.default.fileExists(atPath: ic.path) {
            out.append(CloudProvider(name: "iCloud Drive", account: "", root: ic, isICloud: true))
        }
        return out
    }
    /// Size actually stored on this Mac (cloud-only files count as 0 and are not downloaded).
    static func localSize(_ path: String) -> Int64 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        p.arguments = ["-skx", path]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return 0 }
        let d = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        let str = String(data: d, encoding: .utf8) ?? ""
        return (Int64(str.split(whereSeparator: { $0 == "\t" || $0 == " " }).first ?? "0") ?? 0) * 1024
    }
    /// First-level folders (for Google Drive, also open "My Drive").
    static func topItems(_ root: URL) -> [URL] {
        var out: [URL] = []
        for c in Scanner.children(root) {
            let n = c.lastPathComponent
            if ["My Drive", "Drive của tôi"].contains(n) { out += Scanner.children(c) } else { out.append(c) }
        }
        return out
    }
    /// iCloud only: remove the local download, keep the file in the cloud.
    static func evict(_ url: URL) -> (Int, Int) {
        var ok = 0, fail = 0
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        let files: [URL]
        if isDir.boolValue {
            var f: [URL] = []
            if let en = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                for case let u as URL in en where (try? u.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true { f.append(u) }
            }
            files = f
        } else { files = [url] }
        for f in files { do { try FileManager.default.evictUbiquitousItem(at: f); ok += 1 } catch { fail += 1 } }
        return (ok, fail)
    }
}

func ramInfo() -> (used: Double, total: Double) {
    var stats = vm_statistics64()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
    let r = withUnsafeMutablePointer(to: &stats) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
    }
    let total = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
    guard r == KERN_SUCCESS else { return (0, total) }
    let ps = Double(getpagesize())
    let pages = Double(stats.internal_page_count) - Double(stats.purgeable_count) + Double(stats.wire_count) + Double(stats.compressor_page_count)
    return (max(0, pages * ps / 1_073_741_824), total)
}

// MARK: - ViewModel

enum Page: String, CaseIterable, Identifiable {
    case smart = "Smart Scan", cleanup = "Cleanup", large = "Large & Old Files", lens = "Space Lens", trash = "Trash", ignore = "Ignore List", cloud = "Cloud Cleanup", settings = "Settings", apps = "Uninstaller", dupes = "Duplicates", startup = "Startup", stats = "Stats", contact = "Contact"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .smart: return t("Smart Scan", "Quét thông minh")
        case .cleanup: return t("Cleanup", "Dọn rác")
        case .large: return t("Large & Old Files", "File lớn và cũ")
        case .lens: return t("Space Lens", "Bản đồ ổ đĩa")
        case .trash: return t("Trash", "Thùng rác")
        case .ignore: return t("Ignore List", "Danh sách bỏ qua")
        case .cloud: return t("Cloud Cleanup", "Dữ liệu đám mây")
        case .settings: return t("Settings", "Cài đặt")
        case .apps: return t("Uninstaller", "Gỡ app")
        case .dupes: return t("Duplicates", "File trùng")
        case .startup: return t("Startup Items", "Tự chạy khi bật máy")
        case .stats: return t("Statistics", "Thống kê")
        case .contact: return t("Contact", "Liên hệ")
        }
    }
    var icon: String {
        switch self {
        case .smart: return "sparkles"
        case .cleanup: return "trash.slash"
        case .large: return "doc.on.doc"
        case .lens: return "circle.hexagongrid"
        case .trash: return "trash"
        case .ignore: return "eye.slash"
        case .cloud: return "icloud"
        case .settings: return "gearshape"
        case .apps: return "app.badge.checkmark"
        case .dupes: return "square.on.square"
        case .startup: return "power"
        case .stats: return "chart.bar"
        case .contact: return "envelope"
        }
    }
}

enum Phase { case idle, scanning, summary, review, done }

@MainActor final class VM: ObservableObject {
    @Published var page: Page = .smart
    @Published var phase: Phase = .idle
    @Published var cats: [Category] = []
    @Published var large: [CleanItem] = []
    @Published var largePhase: Phase = .idle
    @Published var trashSize: Int64 = 0
    @Published var trashCount = 0
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

    func setLang(_ l: String) { appLang = l; UserDefaults.standard.set(l, forKey: "lang"); lang = l }
    @Published var theme: String = appTheme
    func setTheme(_ id: String) {
        appTheme = id; UserDefaults.standard.set(id, forKey: "theme"); theme = id
        NSApp.applicationIconImage = makeAppIcon(Theme.p)
    }
    @Published var projects: [String] = Prefs.projectFolders
    func addProjectFolder() {
        let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false; p.allowsMultipleSelection = true
        p.prompt = t("Add", "Thêm")
        guard p.runModal() == .OK else { return }
        var list = Prefs.projectFolders
        for u in p.urls where !list.contains(u.path) { list.append(u.path) }
        Prefs.projectFolders = list; projects = list
    }
    func removeProjectFolder(_ path: String) { Prefs.projectFolders.removeAll { $0 == path }; projects = Prefs.projectFolders }

    // Monitor (menu bar)
    @Published var ramUsed: Double = 0
    @Published var ramTotal: Double = 0
    @Published var lowSpaceGB: Double = UserDefaults.standard.object(forKey: "lowSpaceGB") as? Double ?? 30
    @Published var ramAlert: Bool = UserDefaults.standard.object(forKey: "ramAlert") as? Bool ?? true
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

    func scanApps() {
        appsBusy = true; appsMsg = ""
        Task.detached {
            let a = Apps.list(); let l = Apps.leftovers(); let i = Apps.installers()
            await MainActor.run { self.apps = a; self.leftovers = l; self.installers = i; self.appsBusy = false }
        }
    }
    func loadRelated(_ id: UUID) {
        selApp = id
        guard let i = apps.firstIndex(where: { $0.id == id }), apps[i].related.isEmpty else { return }
        let a = apps[i]
        Task.detached {
            let r = Apps.related(a)
            await MainActor.run { if let j = self.apps.firstIndex(where: { $0.id == id }) { self.apps[j].related = r } }
        }
    }
    func uninstall(_ id: UUID) {
        guard let i = apps.firstIndex(where: { $0.id == id }) else { return }
        let a = apps[i]
        if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == a.bundleID }) {
            _ = confirm(t("Quit \(a.name) first", "Tắt \(a.name) trước"), t("The app is running. Quit it, then try again.", "App đang mở. Tắt app rồi bấm lại."), "OK"); return
        }
        let extra = a.related.filter(\.selected)
        let total = a.size + extra.reduce(0) { $0 + $1.size }
        guard confirm(t("Uninstall \(a.name)?", "Gỡ \(a.name)?"),
                      t("The app and \(extra.count) related items (\(fmt(total))) will be moved to the Trash.",
                        "App và \(extra.count) mục liên quan (\(fmt(total))) sẽ được chuyển vào Thùng rác."),
                      t("Uninstall", "Gỡ")) else { return }
        NSWorkspace.shared.recycle([a.url]) { _, err in
            Task { @MainActor in
                let (ok, _) = self.trash(extra.map(\.url))
                if err == nil {
                    self.apps.removeAll { $0.id == id }; self.selApp = nil
                    self.appsMsg = t("Uninstalled \(a.name) and \(ok) related items (\(fmt(total))).", "Đã gỡ \(a.name) và \(ok) mục liên quan (\(fmt(total))).")
                } else {
                    self.appsMsg = t("Could not move \(a.name) to the Trash: \(err!.localizedDescription)", "Không chuyển được \(a.name) vào Thùng rác: \(err!.localizedDescription)")
                }
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
        dupBusy = true; dupMsg = ""; dupCount = 0; dupes = []
        Task.detached {
            let g = Dupes.scan { n in DispatchQueue.main.async { self.dupCount = n } }
            await MainActor.run { self.dupes = g; self.dupBusy = false }
        }
    }
    /// Whether every extra copy (all except "Keep") is selected
    var dupAllExtrasSelected: Bool { !dupes.isEmpty && dupes.allSatisfy { g in g.items.dropFirst().allSatisfy(\.selected) } }
    func dupGroupState(_ g: DupGroup) -> Int {
        let n = g.items.dropFirst().filter(\.selected).count
        return n == 0 ? 0 : (n == g.items.count - 1 ? 2 : 1)
    }
    func dupToggleGroup(_ id: UUID) {
        guard let i = dupes.firstIndex(where: { $0.id == id }) else { return }
        let on = dupGroupState(dupes[i]) != 2
        for j in dupes[i].items.indices { dupes[i].items[j].selected = on && j > 0 }
    }
    func dupAutoSelect(all: Bool) {
        for i in dupes.indices { for j in dupes[i].items.indices { dupes[i].items[j].selected = all ? j > 0 : false } }
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
        for g in dupes {
            var sel = g.items.filter(\.selected)
            if sel.count == g.items.count { sel.removeFirst() }   // always keep at least one copy
            picked += sel
        }
        guard !picked.isEmpty else { dupMsg = t("Nothing left to delete.", "Không còn file nào để xoá."); return }
        let (ok, fail) = trash(picked.map(\.url))
        let size = okSize(picked)
        dupMsg = t("Moved \(ok) duplicates (\(fmt(size))) to the Trash.", "Đã chuyển \(ok) file trùng (\(fmt(size))) vào Thùng rác.") + (fail > 0 ? t(" \(fail) failed.", " \(fail) file lỗi.") + failNote : "")
        log(dupMsg)
        let gone = lastOK
        for i in dupes.indices { dupes[i].items.removeAll { gone.contains($0.url) } }
        dupes.removeAll { $0.items.count < 2 }
        refreshTrash(); refreshDisk()
    }

    // Startup items (LaunchAgents / LaunchDaemons)
    @Published var launch: [LaunchEntry] = []
    @Published var launchMsg = ""
    func scanLaunch() {
        launch = Startup.scan()
        launchMsg = ""
    }
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
        let (ok, fail) = trash(sel.map(\.url))
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

    func refreshRAM() { let r = ramInfo(); ramUsed = r.used; ramTotal = r.total }
    var tickCount = 0
    func tick() {
        refreshRAM(); tickCount += 1
        if tickCount % 6 == 0 { refreshDisk() }
        if freeGB > 0 && freeGB < lowSpaceGB && Date().timeIntervalSince(lastDiskAlert) > 6 * 3600 {
            lastDiskAlert = Date()
            notify(t("Low disk space", "Ổ sắp đầy"),
                   String(format: t("Only %.0f GB left. Open Disk Cleanup to free up space.", "Chỉ còn %.0f GB. Mở Disk Cleanup để dọn."), freeGB))
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
    func setLowSpace(_ v: Double) { lowSpaceGB = v; UserDefaults.standard.set(v, forKey: "lowSpaceGB") }
    func setRamAlert(_ v: Bool) { ramAlert = v; UserDefaults.standard.set(v, forKey: "ramAlert") }
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
            await MainActor.run { self.clouds = res.sorted { $0.local > $1.local }; self.cloudBusy = false }
        }
    }
    func evictICloud(_ u: URL) {
        let (ok, fail) = Cloud.evict(u)
        cloudMsg = t("Removed local copies of \(ok) files (still in iCloud).", "Đã xoá bản trên máy của \(ok) file (vẫn còn trên iCloud).") + (fail > 0 ? t(" \(fail) failed.", " \(fail) file lỗi.") : "")
        log("Cloud: evict \(u.path) ok \(ok) fail \(fail)")
        scanCloud(); refreshDisk()
    }

    var junkTotal: Int64 { cats.reduce(0) { $0 + $1.total } }
    var junkSelected: Int64 { cats.reduce(0) { $0 + $1.selectedSize } }
    var largeSelected: Int64 { large.filter(\.selected).reduce(0) { $0 + $1.size } }

    func refreshDisk() {
        let v = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
        freeGB = Double(v?.volumeAvailableCapacityForImportantUsage ?? 0) / 1_000_000_000
        totalGB = Double(v?.volumeTotalCapacity ?? 0) / 1_000_000_000
    }

    func refreshTrash() {
        let t = Scanner.trashURL
        Task.detached {
            let s = Scanner.size(t)
            let c = Scanner.children(t, hidden: false).count
            await MainActor.run { self.trashSize = s; self.trashCount = c }
        }
    }

    func scanJunk(thenReview: Bool = false) {
        phase = .scanning
        Task.detached {
            let r = Scanner.scanJunk()
            await MainActor.run { self.cats = r; self.phase = thenReview ? .review : .summary }
        }
    }

    func scanLarge() {
        largePhase = .scanning
        Task.detached {
            let r = Scanner.scanLarge()
            await MainActor.run { self.large = r; self.largePhase = .review }
        }
    }

    func smartScan() {
        phase = .scanning; largePhase = .scanning
        refreshTrash(); refreshDisk()
        Task.detached {
            let j = Scanner.scanJunk()
            let l = Scanner.scanLarge()
            await MainActor.run { self.cats = j; self.large = l; self.phase = .summary; self.largePhase = .review }
        }
    }

    func toggleCat(_ id: String) {
        guard let i = cats.firstIndex(where: { $0.id == id }) else { return }
        let on = cats[i].state != 2
        for j in cats[i].items.indices { cats[i].items[j].selected = on }
    }

    func setAll(_ on: Bool) {
        for i in cats.indices { for j in cats[i].items.indices { cats[i].items[j].selected = on } }
    }

    var lastOK = Set<URL>()
    var lastErr = ""
    func trash(_ urls: [URL]) -> (Int, Int) {
        var ok = 0, fail = 0
        lastOK = []; lastErr = ""
        for u in urls {
            do { try FileManager.default.trashItem(at: u, resultingItemURL: nil); ok += 1; lastOK.insert(u) }
            catch where FileManager.default.fileExists(atPath: u.path) && ((try? moveToUserTrash(u)) != nil) {
                ok += 1; lastOK.insert(u)   // iCloud Drive file: the standard Trash refused, move it into ~/.Trash directly
            }
            catch {
                fail += 1
                if lastErr.isEmpty {
                    let ns = error as NSError
                    let why: String
                    if !FileManager.default.fileExists(atPath: u.path) { why = t("file no longer exists (already moved?)", "file không còn ở đó (có thể đã xoá trước)") }
                    else if ns.code == NSFileWriteNoPermissionError || ns.code == 513 || ns.code == 257 {
                        why = t("no permission. Open System Settings > Privacy & Security > Full Disk Access, turn Disk Cleanup off and on again", "không có quyền. Vào Cài đặt hệ thống > Quyền riêng tư & Bảo mật > Truy cập toàn bộ ổ đĩa, tắt rồi bật lại Disk Cleanup")
                    } else { why = ns.localizedDescription }
                    lastErr = why
                }
            }
        }
        if !lastErr.isEmpty { log("ERROR trash: \(lastErr)") }
        return (ok, fail)
    }
    func okSize(_ items: [CleanItem]) -> Int64 { items.filter { lastOK.contains($0.url) }.reduce(0) { $0 + $1.size } }
    var failNote: String { lastErr.isEmpty ? "" : t(" Reason: ", " Lý do: ") + lastErr }

    func cleanJunk() {
        let sel = cats.flatMap { $0.items.filter(\.selected) }
        let size = sel.reduce(0) { $0 + $1.size }
        let (ok, fail) = trash(sel.map(\.url)); _ = size
        lastResult = t("Moved \(ok) items (\(fmt(okSize(sel)))) to the Trash.", "Đã chuyển \(ok) mục (\(fmt(okSize(sel)))) vào Thùng rác.") + (fail > 0 ? t(" Skipped \(fail) items.", " Bỏ qua \(fail) mục.") + failNote : "")
        log(lastResult)
        phase = .done
        refreshTrash(); refreshDisk()
    }

    func cleanLarge() {
        let sel = large.filter(\.selected)
        let size = sel.reduce(0) { $0 + $1.size }
        let (ok, fail) = trash(sel.map(\.url)); _ = size
        lastResult = t("Moved \(ok) large files (\(fmt(okSize(sel)))) to the Trash.", "Đã chuyển \(ok) file lớn (\(fmt(okSize(sel)))) vào Thùng rác.") + (fail > 0 ? t(" \(fail) failed.", " \(fail) file lỗi.") + failNote : "")
        log(lastResult)
        large.removeAll { lastOK.contains($0.url) }
        refreshTrash(); refreshDisk()
    }

    func confirm(_ title: String, _ text: String, _ ok: String) -> Bool {
        let a = NSAlert()
        a.messageText = title; a.informativeText = text
        a.addButton(withTitle: ok); a.addButton(withTitle: t("Cancel", "Huỷ"))
        a.alertStyle = .warning
        return a.runModal() == .alertFirstButtonReturn
    }

    func emptyTrash() {
        guard confirm(t("Empty Trash?", "Đổ Thùng rác?"), t("\(trashCount) items, \(fmt(trashSize)). This cannot be undone.", "\(trashCount) mục, \(fmt(trashSize)). Đổ rồi không lấy lại được."), t("Empty Trash", "Đổ Thùng rác")) else { return }
        var err: NSDictionary?
        NSAppleScript(source: "tell application \"Finder\" to empty trash")?.executeAndReturnError(&err)
        log("Emptied Trash: \(fmt(trashSize))")
        refreshTrash(); refreshDisk()
    }

    // Ignore list
    func ignore(_ u: URL) {
        IgnoreList.add(u.path); ignored = IgnoreList.paths
        for i in cats.indices { cats[i].items.removeAll { $0.url == u } }
        cats.removeAll { $0.items.isEmpty }
        large.removeAll { $0.url == u }
        lensNodes.removeAll { $0.url == u }
    }
    func unignore(_ p: String) { IgnoreList.remove(p); ignored = IgnoreList.paths }

    // Space Lens
    func openLens(_ u: URL) {
        lensPath.append(u); loadLens()
    }
    func lensUp(to i: Int) { lensPath = Array(lensPath.prefix(i + 1)); loadLens() }
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
                    if self.lensDone >= self.lensTotal { self.lensBusy = false; self.lensCurrent = "" }
                }
            }
        }
    }
    func stopLens() { lensToken = UUID(); lensBusy = false; lensCurrent = "" }
    func rescanLens() { if let u = lensPath.last { sizeCache = sizeCache.filter { !$0.key.hasPrefix(u.path) } }; loadLens() }
    func trashNode(_ n: Node) {
        guard confirm(t("Move to Trash?", "Chuyển vào Thùng rác?"), "\(n.name), \(fmt(n.size))", t("Move to Trash", "Chuyển vào Thùng rác")) else { return }
        let (ok, _) = trash([n.url])
        if ok > 0 { lensNodes.removeAll { $0.id == n.id }; log("Space Lens: moved \(n.url.path) (\(fmt(n.size))) to Trash") }
        refreshTrash(); refreshDisk()
    }

    func reveal(_ u: URL) { NSWorkspace.shared.activateFileViewerSelecting([u]) }

    func log(_ s: String) {
        let p = Stats.path
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm"
        let line = "\(df.string(from: Date())) | \(s) | free \(String(format: "%.0f", freeGB)) GB\n"
        if let h = FileHandle(forWritingAtPath: p) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close() }
        else { try? line.write(toFile: p, atomically: true, encoding: .utf8) }
    }
}

/// Move a file into ~/.Trash directly (used when the standard Trash refuses, e.g. iCloud Drive files).
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

// MARK: - Startup model

struct LaunchEntry: Identifiable {
    let id = UUID()
    let url: URL
    let label: String
    let program: String
    let scope: Int          // 0: this user (~/Library), 1: all users agent, 2: all users daemon (needs admin)
    let running: Bool?
    let orphan: Bool
    var selected = false
    var owner: String {
        let l = label.lowercased()
        let known: [(String, String)] = [("google", "Google (Chrome/Drive)"), ("adobe", "Adobe"), ("microsoft", "Microsoft"), ("teamviewer", "TeamViewer"),
            ("macpaw", "CleanMyMac"), ("p5sys", "Jump Desktop"), ("mullvad", "Mullvad VPN"), ("alt-tab", "AltTab"), ("sunshine", "Sunshine"),
            ("dropbox", "Dropbox"), ("zoom", "Zoom"), ("spotify", "Spotify")]
        for (k, v) in known where l.contains(k) { return v }
        if let app = program.range(of: ".app/") { return ((String(program[..<app.lowerBound]) as NSString).lastPathComponent) }
        return label
    }
}

enum Startup {
    static func scan() -> [LaunchEntry] {
        let fm = FileManager.default
        // labels loaded in the user session
        var loaded = Set<String>()
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/launchctl"); p.arguments = ["list"]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        if (try? p.run()) != nil {
            let d = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
            for line in (String(data: d, encoding: .utf8) ?? "").split(separator: "\n") {
                if let last = line.split(separator: "\t").last { loaded.insert(String(last)) }
            }
        }
        let dirs: [(String, Int)] = [(NSHomeDirectory() + "/Library/LaunchAgents", 0), ("/Library/LaunchAgents", 1), ("/Library/LaunchDaemons", 2)]
        var out: [LaunchEntry] = []
        for (dir, scope) in dirs {
            for f in (try? fm.contentsOfDirectory(atPath: dir)) ?? [] where f.hasSuffix(".plist") {
                let u = URL(fileURLWithPath: dir).appendingPathComponent(f)
                let d = NSDictionary(contentsOf: u) as? [String: Any] ?? [:]
                let label = d["Label"] as? String ?? String(f.dropLast(6))
                let prog = d["Program"] as? String ?? (d["ProgramArguments"] as? [String])?.first ?? ""
                let orphan = prog.hasPrefix("/") && !prog.hasPrefix("/usr/") && !prog.hasPrefix("/bin/") && !prog.hasPrefix("/System/") && !fm.fileExists(atPath: prog)
                out.append(LaunchEntry(url: u, label: label, program: prog, scope: scope,
                                       running: scope == 2 ? nil : loaded.contains(label), orphan: orphan, selected: orphan && scope == 0))
            }
        }
        return out.sorted { ($0.scope, $0.owner.lowercased()) < ($1.scope, $1.owner.lowercased()) }
    }
}

// MARK: - Folder explanations (Space Lens)

func folderInfo(_ u: URL) -> String? {
    let n = u.lastPathComponent, p = u.path
    let m: [String: (String, String)] = [
        "Caches": ("Temporary app data. Safe to clear, apps rebuild it.", "Dữ liệu tạm của app. Xoá được, app tự tạo lại."),
        "Application Support": ("App data and settings. Delete only for apps you removed.", "Dữ liệu và cài đặt của app. Chỉ xoá phần của app đã gỡ."),
        "Containers": ("Data of App Store apps. Delete only for apps you removed.", "Dữ liệu app tải từ App Store. Chỉ xoá phần của app đã gỡ."),
        "Group Containers": ("Data shared between apps of one maker (Office, Messages...).", "Dữ liệu dùng chung giữa các app cùng hãng (Office, Tin nhắn...)."),
        "Mobile Documents": ("iCloud Drive files kept on this Mac.", "File iCloud Drive đang lưu trên máy."),
        "CloudStorage": ("Google Drive / OneDrive / Dropbox files on this Mac. Use Cloud Cleanup.", "File Google Drive / OneDrive / Dropbox trên máy. Dọn ở mục Dữ liệu đám mây."),
        "Developer": ("Xcode data, simulators and build files. Often large, mostly safe to clear.", "Dữ liệu Xcode, máy ảo, file build. Thường nặng, phần lớn xoá được."),
        "DerivedData": ("Xcode build files. Safe to clear.", "File build của Xcode. Xoá được."),
        "CoreSimulator": ("iPhone simulators. Delete old ones in Xcode.", "Máy ảo iPhone. Xoá bản cũ trong Xcode."),
        "Logs": ("Log files. Safe to clear.", "File nhật ký. Xoá được."),
        "Mail": ("Mail messages and attachments. Manage in the Mail app.", "Thư và tệp đính kèm. Dọn trong app Mail."),
        "Messages": ("Messages history and attachments. Manage in Settings > General > Storage.", "Lịch sử Tin nhắn và tệp đính kèm. Dọn trong Cài đặt > Cài đặt chung > Dung lượng."),
        "Downloads": ("Things you downloaded. Usually full of installers you no longer need.", "File đã tải về. Thường đầy file cài đặt không còn cần."),
        "Movies": ("Videos. Check for old exports and screen recordings.", "Video. Soi các bản xuất và quay màn hình cũ."),
        "Pictures": ("Photos and the Photos library.", "Ảnh và thư viện Ảnh."),
        "Music": ("Music and GarageBand / Logic files.", "Nhạc và file GarageBand / Logic."),
        "Desktop": ("Files on your desktop.", "File trên màn hình chính."),
        "Documents": ("Your documents.", "Tài liệu của bạn."),
        "Library": ("System and app data for your account. Be careful here.", "Dữ liệu hệ thống và app của tài khoản. Cẩn thận khi xoá."),
        "node_modules": ("Code packages of a project. Re-installable with npm install.", "Gói code của dự án. Cài lại được bằng npm install."),
        ".npm": ("npm download cache. Safe to clear.", "Bộ nhớ tạm của npm. Xoá được."),
        ".cache": ("Cache of command-line tools. Safe to clear.", "Bộ nhớ tạm của công cụ dòng lệnh. Xoá được."),
        ".Trash": ("The Trash.", "Thùng rác."),
        "Photos Library.photoslibrary": ("Photos library. Do not delete here, manage in Photos.", "Thư viện Ảnh. Đừng xoá ở đây, dọn trong app Ảnh."),
        "Saved Application State": ("Window positions of apps. Safe to clear.", "Vị trí cửa sổ app. Xoá được."),
        "iOS DeviceSupport": ("Debug files for each iPhone you plugged in. Safe to clear.", "File gỡ lỗi cho từng iPhone từng cắm. Xoá được."),
        "Draw Things": ("Draw Things AI models. Large; remove unused models inside the app.", "Model AI của Draw Things. Rất nặng, gỡ model không dùng ngay trong app."),
        "huggingface": ("Downloaded AI models (Hugging Face). Re-downloadable.", "Model AI tải từ Hugging Face. Tải lại được."),
        ".ollama": ("Ollama AI models. Remove unused ones with 'ollama rm'.", "Model AI của Ollama. Gỡ model không dùng bằng 'ollama rm'."),
        "LM Studio": ("LM Studio AI models. Manage them inside the app.", "Model AI của LM Studio. Quản lý trong app.")
    ]
    if let v = m[n] { return t(v.0, v.1) }
    if p.contains("/Library/Containers/") || p.contains("/Library/Application Support/") { return t("Data of one app.", "Dữ liệu của một app.") }
    return nil
}

// MARK: - Stats (from the activity log)

struct LogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let text: String
    let freed: Int64
    let freeGB: Double?
}

enum Stats {
    static let dir = NSHomeDirectory() + "/Library/Application Support/Disk Cleanup"
    static var path: String {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir + "/activity.log"
    }
    static func load() -> [LogEntry] {
        guard let s = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm"
        var out: [LogEntry] = []
        for line in s.split(separator: "\n") {
            let parts = line.components(separatedBy: " | ")
            guard parts.count >= 2, let d = df.date(from: parts[0].trimmingCharacters(in: .whitespaces)) else { continue }
            let msg = parts[1]
            var free: Double? = nil
            if parts.count >= 3 {
                let digits = parts[2].filter { $0.isNumber || $0 == "." }
                free = Double(digits)
            }
            out.append(LogEntry(date: d, text: msg, freed: freedBytes(msg), freeGB: free))
        }
        return out
    }
    /// Bytes freed by one log line. Lines that moved 0 files count as 0.
    static func freedBytes(_ m: String) -> Int64 {
        if m.hasPrefix("ERROR") { return 0 }
        let isUninstall = m.hasPrefix("Uninstalled") || m.hasPrefix("Đã gỡ")
        if !isUninstall {
            let firstNum = m.split(whereSeparator: { !$0.isNumber }).first.flatMap { Int($0) } ?? 0
            if firstNum == 0 { return 0 }
        }
        guard let open = m.firstIndex(of: "("), let close = m[open...].firstIndex(of: ")") else { return 0 }
        let inner = m[m.index(after: open)..<close].replacingOccurrences(of: ",", with: ".")
        let bits = inner.split(separator: " ")
        guard bits.count == 2, let v = Double(bits[0]) else { return 0 }
        let mult: Double = ["bytes": 1, "KB": 1e3, "MB": 1e6, "GB": 1e9, "TB": 1e12][String(bits[1])] ?? 0
        return Int64(v * mult)
    }
}

// MARK: - Components

struct CheckBox: View {
    let state: Int
    var body: some View {
        Image(systemName: state == 2 ? "checkmark.square.fill" : (state == 1 ? "minus.square.fill" : "square"))
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(state == 0 ? AnyShapeStyle(Color.white.opacity(0.5)) : AnyShapeStyle(Theme.accent))
    }
}

struct PrimaryButton: View {
    let title: String; let action: () -> Void
    var disabled = false
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                .padding(.horizontal, 28).padding(.vertical, 11)
                .background(Capsule().fill(Theme.accent)).opacity(disabled ? 0.4 : 1)
                .shadow(color: Theme.accentSolid.opacity(0.4), radius: 12, y: 4)
        }.buttonStyle(.plain).disabled(disabled).hoverLift()
    }
}

struct GhostButton: View {
    let title: String; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                .padding(.horizontal, 22).padding(.vertical, 10)
                .background(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
                .hoverBG(20, Color.white.opacity(0.1))
        }.buttonStyle(.plain).hoverLift()
    }
}

struct BigScanButton: View {
    let label: String; let action: () -> Void
    @StateObject private var pulse = Flag()
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.25)).frame(width: 190, height: 190).scaleEffect(pulse.v ? 1.06 : 1.0)
                Circle().fill(Theme.accent).frame(width: 150, height: 150).shadow(color: Theme.accentSolid.opacity(0.5), radius: 24)
                Text(label).font(.system(size: 22, weight: .bold)).foregroundColor(.white)
            }
        }.buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.25)) { pulse.v = h } }
    }
}

struct Header: View {
    let title: String; let sub: String
    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: 28, weight: .bold)).foregroundColor(.white)
            Text(sub).font(.system(size: 14)).foregroundColor(Theme.sub).multilineTextAlignment(.center)
        }
    }
}

struct Scanning: View {
    let text: String
    var body: some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large).tint(.white)
            Text(text).foregroundColor(Theme.sub)
        }
    }
}

struct ItemRow: View {
    @Binding var item: CleanItem
    let vm: VM
    var showDate = false
    var body: some View {
        HStack(spacing: 12) {
            Button { item.selected.toggle() } label: { CheckBox(state: item.selected ? 2 : 0) }.buttonStyle(.plain)
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path)).resizable().frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).foregroundColor(.white).font(.system(size: 13)).lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.shortPath).foregroundColor(Theme.sub).font(.system(size: 11)).lineLimit(1).truncationMode(.middle)
                    if !item.note.isEmpty {
                        Text(item.note).font(.system(size: 10, weight: .semibold)).foregroundColor(item.noteColor)
                            .padding(.horizontal, 6).padding(.vertical, 1).background(Capsule().fill(item.noteColor.opacity(0.15)))
                            .help(item.refHelp)
                    }
                }
            }
            Spacer()
            if showDate, let d = item.date {
                Text("Last opened ").foregroundColor(Theme.sub).font(.system(size: 11)) + Text(d, style: .date).foregroundColor(Theme.sub).font(.system(size: 11))
            }
            Text(fmt(item.size)).foregroundColor(.white).font(.system(size: 13, weight: .medium).monospacedDigit()).frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 6).padding(.horizontal, 12)
        .hoverBG(8, Color.white.opacity(0.07))
        .contentShape(Rectangle())
        .contextMenu {
            Button(t("Reveal in Finder", "Mở trong Finder")) { vm.reveal(item.url) }
            Button(item.selected ? t("Deselect", "Bỏ chọn") : t("Select", "Chọn")) { item.selected.toggle() }
            Divider()
            Button(t("Ignore (don't show again)", "Bỏ qua (không hiện lại)")) { let u = item.url; DispatchQueue.main.async { vm.ignore(u) } }
        }
    }
}

// MARK: - Pages

struct Tile: View {
    let icon: String, title: String, value: String, sub: String
    let action: () -> Void
    @StateObject private var hover = Flag()
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).font(.system(size: 26)).foregroundStyle(Theme.accent)
                Text(title).foregroundColor(Theme.sub).font(.system(size: 13))
                Text(value).foregroundColor(.white).font(.system(size: 24, weight: .bold))
                Text(sub).foregroundColor(Theme.sub).font(.system(size: 12))
                Text("Review").font(.system(size: 12, weight: .semibold)).foregroundColor(.white).padding(.top, 4)
            }
            .padding(20).frame(width: 200, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(hover.v ? Theme.cardHi : Theme.card))
        }.buttonStyle(.plain).onHover { hover.v = $0 }
    }
}

struct SmartView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(spacing: 28) {
            switch vm.phase {
            case .scanning:
                Scanning(text: t("Scanning your Mac...", "Đang quét máy..."))
            case .idle:
                Header(title: t("Welcome back", "Dọn máy chút nhé?"), sub: t("Scan for safe junk, large files and the Trash.\nNothing is removed until you click Clean.", "Quét rác an toàn, file lớn và Thùng rác.\nChưa xoá gì cho tới khi bạn bấm Dọn."))
                BigScanButton(label: t("Scan", "Quét")) { vm.smartScan() }
                Text(String(format: t("%.0f GB available", "Trống %.0f GB"), vm.freeGB)).foregroundColor(Theme.sub)
            default:
                Header(title: t("Scan Results", "Kết quả quét"), sub: String(format: t("%.0f GB available", "Trống %.0f GB"), vm.freeGB))
                HStack(spacing: 16) {
                    Tile(icon: "trash.slash", title: t("Safe Junk", "Rác an toàn"), value: fmt(vm.junkSelected), sub: t("selected of \(fmt(vm.junkTotal))", "đã chọn / \(fmt(vm.junkTotal))")) { vm.page = .cleanup; vm.phase = .review }
                    Tile(icon: "doc.on.doc", title: t("Large Files", "File lớn"), value: t("\(vm.large.count) files", "\(vm.large.count) file"), sub: fmt(vm.large.reduce(0) { $0 + $1.size })) { vm.page = .large }
                    Tile(icon: "trash", title: t("Trash", "Thùng rác"), value: fmt(vm.trashSize), sub: t("\(vm.trashCount) items", "\(vm.trashCount) mục")) { vm.page = .trash }
                }
                HStack(spacing: 14) {
                    GhostButton(title: t("Review Details", "Xem chi tiết")) { vm.page = .cleanup; vm.phase = .review }
                    PrimaryButton(title: t("Clean Selected (\(fmt(vm.junkSelected)))", "Dọn rác đã chọn (\(fmt(vm.junkSelected)))"), action: { vm.cleanJunk(); vm.page = .cleanup }, disabled: vm.junkSelected == 0)
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CleanupView: View {
    @ObservedObject var vm: VM
    var body: some View {
        switch vm.phase {
        case .idle:
            VStack(spacing: 28) {
                Header(title: t("Cleanup", "Dọn rác"), sub: t("Find caches, logs, drafts and old downloads.\nItems are moved to the Trash, not deleted.", "Tìm bộ nhớ đệm, nhật ký, nháp và Downloads cũ.\nChỉ chuyển vào Thùng rác, chưa xoá hẳn."))
                BigScanButton(label: t("Scan", "Quét")) { vm.scanJunk() }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .scanning:
            Scanning(text: t("Looking for junk...", "Đang tìm rác...")).frame(maxWidth: .infinity, maxHeight: .infinity)
        case .summary:
            VStack(spacing: 24) {
                Text(fmt(vm.junkTotal)).font(.system(size: 54, weight: .bold)).foregroundColor(.white)
                Text("of junk found. \(fmt(vm.junkSelected)) is safe and pre-selected.").foregroundColor(Theme.sub)
                HStack(spacing: 14) {
                    GhostButton(title: t("Review Details", "Xem chi tiết")) { vm.phase = .review }
                    PrimaryButton(title: t("Clean", "Dọn"), action: { vm.cleanJunk() }, disabled: vm.junkSelected == 0)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .review:
            ReviewView(vm: vm)
        case .done:
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundColor(Theme.green)
                Text(t("All done!", "Xong rồi!")).font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                Text(vm.lastResult).foregroundColor(Theme.sub).multilineTextAlignment(.center)
                Text(t("Last step: review the Trash, then empty it.", "Bước cuối: xem lại Thùng rác rồi đổ.")).foregroundColor(Theme.sub)
                HStack(spacing: 14) {
                    GhostButton(title: t("Scan Again", "Quét lại")) { vm.scanJunk() }
                    PrimaryButton(title: t("Go to Trash", "Mở mục Thùng rác"), action: { vm.page = .trash })
                }
                if Invite.shouldShow() { InviteCard(source: "after-clean").frame(maxWidth: 520).padding(.top, 8) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ReviewView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { vm.phase = .summary } label: { Label(t("Back", "Quay lại"), systemImage: "chevron.left") }.buttonStyle(.plain).foregroundColor(.white)
                Spacer()
                Text("Cleanup Details").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Menu(t("Select", "Chọn")) {
                    Button(t("Select All", "Chọn tất cả")) { vm.setAll(true) }
                    Button(t("Deselect All", "Bỏ chọn tất cả")) { vm.setAll(false) }
                    Button(t("Smart Selection", "Chọn thông minh")) { vm.scanJunk(thenReview: true) }
                }.menuStyle(.borderlessButton).frame(width: 70).foregroundColor(.white)
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 14)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach($vm.cats) { $cat in
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Button { vm.toggleCat(cat.id) } label: { CheckBox(state: cat.state) }.buttonStyle(.plain)
                                Image(systemName: cat.icon).font(.system(size: 18)).foregroundStyle(Theme.accent).frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.title).foregroundColor(.white).font(.system(size: 14, weight: .semibold))
                                    Text(cat.desc).foregroundColor(Theme.sub).font(.system(size: 11))
                                }
                                Spacer()
                                Text("\(cat.items.count) items").foregroundColor(Theme.sub).font(.system(size: 12))
                                Text(fmt(cat.selectedSize) + " / " + fmt(cat.total)).foregroundColor(.white)
                                    .font(.system(size: 13, weight: .medium).monospacedDigit()).frame(width: 150, alignment: .trailing)
                                Image(systemName: "chevron.down").rotationEffect(.degrees(cat.expanded ? 0 : -90)).foregroundColor(Theme.sub)
                            }
                            .padding(14).hoverBG(14, Color.white.opacity(0.06)).contentShape(Rectangle())
                            .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { cat.expanded.toggle() } }

                            if cat.expanded {
                                Divider().background(Color.white.opacity(0.1))
                                ForEach($cat.items) { $it in ItemRow(item: $it, vm: vm) }.padding(.leading, 26)
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                    }
                }.padding(.horizontal, 24).padding(.bottom, 16)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(fmt(vm.junkSelected)) selected").foregroundColor(.white).font(.system(size: 15, weight: .semibold))
                    Text("Moved to the Trash, not deleted yet. Right-click an item for more.").foregroundColor(Theme.sub).font(.system(size: 11))
                }
                Spacer()
                PrimaryButton(title: t("Clean", "Dọn"), action: { vm.cleanJunk() }, disabled: vm.junkSelected == 0)
            }.padding(.horizontal, 24).padding(.vertical, 14).background(Color.black.opacity(0.25))
        }
    }
}

struct LargeView: View {
    @ObservedObject var vm: VM
    @StateObject private var sortByDate = Flag()
    var body: some View {
        VStack(spacing: 0) {
            switch vm.largePhase {
            case .idle:
                VStack(spacing: 28) {
                    Header(title: t("Large & Old Files", "File lớn và cũ"), sub: t("Files over 100 MB in Documents, Downloads, Desktop, Movies, Music and Pictures.\nNothing is selected by default.", "File trên 100 MB trong Documents, Downloads, Desktop, Movies, Music, Pictures.\nMặc định không tick, bạn tự chọn."))
                    BigScanButton(label: t("Scan", "Quét")) { vm.scanLarge() }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            case .scanning:
                Scanning(text: t("Looking for large files...", "Đang tìm file lớn...")).frame(maxWidth: .infinity, maxHeight: .infinity)
            default:
                HStack {
                    Text("Large Files (\(vm.large.count))").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Picker("", selection: $sortByDate.v) { Text("By Size").tag(false); Text("Oldest Opened").tag(true) }
                        .pickerStyle(.segmented).frame(width: 240)
                    Button { vm.scanLarge() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).foregroundColor(.white).padding(.leading, 8)
                }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 14)
                if vm.large.isEmpty {
                    Text("No files over 100 MB.").foregroundColor(Theme.sub).frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(sortedIdx(), id: \.self) { i in
                                ItemRow(item: $vm.large[i], vm: vm, showDate: true)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                            }
                        }.padding(.horizontal, 24)
                    }
                }
                HStack {
                    Text("\(fmt(vm.largeSelected)) selected").foregroundColor(.white).font(.system(size: 15, weight: .semibold))
                    Spacer()
                    PrimaryButton(title: t("Move to Trash", "Chuyển vào Thùng rác"), action: { vm.cleanLarge() }, disabled: vm.largeSelected == 0)
                }.padding(.horizontal, 24).padding(.vertical, 14).background(Color.black.opacity(0.25))
            }
        }
    }
    func sortedIdx() -> [Int] {
        let idx = Array(vm.large.indices)
        if sortByDate.v { return idx.sorted { (vm.large[$0].date ?? .distantFuture) < (vm.large[$1].date ?? .distantFuture) } }
        return idx.sorted { vm.large[$0].size > vm.large[$1].size }
    }
}

struct LensView: View {
    @ObservedObject var vm: VM
    var body: some View {
        if vm.lensPath.isEmpty {
            VStack(spacing: 28) {
                Header(title: t("Space Lens", "Bản đồ ổ đĩa"), sub: t("See what takes up space, folder by folder.\nClick a bubble to look inside.", "Xem thư mục nào chiếm chỗ.\nBấm vào bong bóng để xem bên trong."))
                BigScanButton(label: t("Scan", "Quét")) { vm.openLens(Scanner.home) }
                HStack(spacing: 12) {
                    GhostButton(title: "Library") { vm.openLens(Scanner.lib) }
                    GhostButton(title: "Documents") { vm.openLens(Scanner.home.appendingPathComponent("Documents")) }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                // breadcrumb
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Button { vm.stopLens(); vm.lensPath = []; vm.lensNodes = [] } label: { Image(systemName: "house") }.buttonStyle(.plain).foregroundColor(.white)
                        ForEach(Array(vm.lensPath.enumerated()), id: \.offset) { i, u in
                            Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(Theme.sub)
                            Button(i == 0 && u.path == NSHomeDirectory() ? t("Home", "Nhà") : u.lastPathComponent) { vm.lensUp(to: i) }
                                .buttonStyle(.plain).foregroundColor(i == vm.lensPath.count - 1 ? .white : Theme.sub)
                        }
                    }
                }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 10)

                if vm.lensBusy {
                    HStack(spacing: 10) {
                        ProgressView(value: Double(vm.lensDone), total: Double(max(vm.lensTotal, 1))).tint(Theme.accentSolid).frame(width: 160)
                        Text(t("Measured \(vm.lensDone)/\(vm.lensTotal)", "Đã đo \(vm.lensDone)/\(vm.lensTotal)") + (vm.lensCurrent.isEmpty ? "" : t(" · now: ", " · đang đo: ") + vm.lensCurrent))
                            .font(.system(size: 11)).foregroundColor(Theme.sub).lineLimit(1)
                        Spacer()
                        Button(t("Stop", "Dừng")) { vm.stopLens() }.buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).foregroundColor(.white)
                    }.padding(.horizontal, 24).padding(.bottom, 8)
                }
                if vm.lensBusy && vm.lensNodes.isEmpty {
                    Scanning(text: t("Measuring folders...", "Đang đo thư mục...")).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 0) {
                        // list
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(vm.lensNodes) { n in
                                    HStack(spacing: 10) {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: n.url.path)).resizable().frame(width: 20, height: 20)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(n.name).foregroundColor(.white).font(.system(size: 12)).lineLimit(1)
                                            if n.otherCount == 0, let info = folderInfo(n.url) {
                                                Text(info).foregroundColor(Theme.sub).font(.system(size: 10)).lineLimit(1)
                                            }
                                        }.help(n.otherCount == 0 ? (folderInfo(n.url) ?? "") : "")
                                        Spacer()
                                        Text(fmt(n.size)).foregroundColor(Theme.sub).font(.system(size: 12).monospacedDigit())
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(vm.hoverNode == n.id ? Theme.cardHi : Color.clear))
                                    .contentShape(Rectangle())
                                    .onTapGesture { if n.isDir { vm.openLens(n.url) } }
                                    .onHover { h in vm.hoverNode = h ? n.id : nil }
                                    .contextMenu { nodeMenu(n) }
                                }
                            }.padding(.horizontal, 12)
                        }.frame(width: 280).background(Color.black.opacity(0.15))
                        // bubbles
                        GeometryReader { g in
                            let total = max(vm.lensNodes.reduce(0) { $0 + $1.size }, 1)
                            let bs = pack(lensBubbles(vm.lensNodes, folder: vm.lensPath.last), in: g.size)
                            ZStack {
                                ForEach(bs, id: \.node.id) { b in
                                    ZStack {
                                        Circle().fill(b.color.opacity(vm.hoverNode == b.node.id ? 0.95 : 0.7))
                                        Circle().stroke(Color.white.opacity(0.35), lineWidth: 1)
                                        let pct = Double(b.node.size) / Double(total) * 100
                                        let pctText = pct < 1 ? "<1%" : String(format: "%.0f%%", pct)
                                        if b.r > 34 {
                                            VStack(spacing: 2) {
                                                Text(b.node.name).font(.system(size: max(9, min(14, b.r / 5)), weight: .semibold)).lineLimit(1)
                                                Text(fmt(b.node.size) + " · " + pctText).font(.system(size: max(8, min(12, b.r / 6))))
                                            }.foregroundColor(.white).frame(width: b.r * 1.6)
                                        } else if b.r > 14 {
                                            Text(pctText).font(.system(size: 9, weight: .semibold)).foregroundColor(.white)
                                        }
                                    }
                                    .frame(width: b.r * 2, height: b.r * 2)
                                    .position(x: b.x, y: b.y)
                                    .onTapGesture { if b.node.isDir && b.node.otherCount == 0 { vm.openLens(b.node.url) } }
                                    .onHover { h in vm.hoverNode = h ? b.node.id : nil }
                                    .contextMenu { if b.node.otherCount == 0 { nodeMenu(b.node) } }
                                    .help(b.node.otherCount > 0
                                          ? t("\(b.node.otherCount) small items (under 1% each), \(fmt(b.node.size)). See the list on the left.",
                                              "\(b.node.otherCount) mục nhỏ (mỗi mục dưới 1%), \(fmt(b.node.size)). Xem ở danh sách bên trái.")
                                          : "\(b.node.name): \(fmt(b.node.size))" + (folderInfo(b.node.url).map { "\n" + $0 } ?? ""))
                                }
                            }
                        }.padding(12)
                    }
                }
                HStack {
                    Text("Total: \(fmt(vm.lensNodes.reduce(0) { $0 + $1.size }))").foregroundColor(.white).font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("Click to open a folder. Right-click for Reveal, Move to Trash, Ignore.").foregroundColor(Theme.sub).font(.system(size: 11))
                }.padding(.horizontal, 24).padding(.vertical, 12).background(Color.black.opacity(0.25))
            }
        }
    }
    @ViewBuilder func nodeMenu(_ n: Node) -> some View {
        Button(t("Reveal in Finder", "Mở trong Finder")) { vm.reveal(n.url) }
        if n.isDir { Button(t("Open", "Mở")) { vm.openLens(n.url) } }
        Divider()
        if Scanner.blocked(n.url.path) {
            Text("Protected: cannot be removed here")
        } else {
            Button(t("Move to Trash...", "Chuyển vào Thùng rác...")) { DispatchQueue.main.async { vm.trashNode(n) } }
        }
        Button(t("Ignore", "Bỏ qua")) { let u = n.url; DispatchQueue.main.async { vm.ignore(u) } }
    }
}

struct TrashView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: vm.trashCount == 0 ? "trash" : "trash.fill").font(.system(size: 70)).foregroundStyle(Theme.accent)
            Text(fmt(vm.trashSize)).font(.system(size: 46, weight: .bold)).foregroundColor(.white)
            Text(vm.trashCount == 0 ? t("The Trash is empty.", "Thùng rác trống.") : t("\(vm.trashCount) items in the Trash", "\(vm.trashCount) mục trong Thùng rác")).foregroundColor(Theme.sub)
            HStack(spacing: 14) {
                GhostButton(title: t("Open Trash", "Mở Thùng rác")) { NSWorkspace.shared.open(Scanner.trashURL) }
                PrimaryButton(title: t("Empty Trash", "Đổ Thùng rác"), action: { vm.emptyTrash() }, disabled: vm.trashCount == 0)
            }
            Text("Emptying cannot be undone. Take a quick look first.").font(.system(size: 12)).foregroundColor(Theme.sub)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { vm.refreshTrash() }
    }
}

struct IgnoreView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ignore List").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                Text("Items here are never shown in scans. Right-click any item in Cleanup, Large Files or Space Lens to add it.")
                    .foregroundColor(Theme.sub).font(.system(size: 12))
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 16)
            if vm.ignored.isEmpty {
                Text("Nothing ignored yet.").foregroundColor(Theme.sub).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(vm.ignored, id: \.self) { p in
                            HStack(spacing: 10) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: p)).resizable().frame(width: 20, height: 20)
                                Text(p.replacingOccurrences(of: NSHomeDirectory(), with: "~")).foregroundColor(.white).font(.system(size: 12))
                                    .lineLimit(1).truncationMode(.middle)
                                Spacer()
                                Button(t("Remove", "Gỡ")) { vm.unignore(p) }.buttonStyle(.plain).foregroundColor(Theme.link)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                            .hoverBG(10, Color.white.opacity(0.06))
                        }
                    }.padding(.horizontal, 24)
                }
            }
        }
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 10, weight: .semibold)).tracking(0.8)
            .foregroundColor(Theme.sub.opacity(0.8))
            .padding(.horizontal, 12).padding(.top, 14).padding(.bottom, 4)
    }
}

struct NavItem: View {
    let p: Page
    @ObservedObject var vm: VM
    var body: some View {
        Button { vm.page = p } label: {
            HStack(spacing: 10) {
                Image(systemName: p.icon).frame(width: 20)
                Text(p.label).lineLimit(1).minimumScaleFactor(0.85)
                Spacer()
            }
            .font(.system(size: 13, weight: vm.page == p ? .semibold : .regular))
            .foregroundColor(.white.opacity(vm.page == p ? 1 : 0.75))
            .padding(.horizontal, 12).padding(.vertical, 8)
            // Selected item uses the theme colour; Smart Scan always keeps a light theme tint as the main entry point.
            .background(RoundedRectangle(cornerRadius: 8).fill(vm.page == p ? AnyShapeStyle(Theme.accentSolid.opacity(0.8))
                : (p == .smart ? AnyShapeStyle(Theme.accentSolid.opacity(0.22)) : AnyShapeStyle(Color.clear))))
            .hoverBG(8, Color.white.opacity(0.07))
            .contentShape(Rectangle())
        }.buttonStyle(.plain).id(p)
    }
}

/// Compact language switch: 20pt tall, 10pt text.
struct LangSwitch: View {
    @ObservedObject var vm: VM
    var body: some View {
        HStack(spacing: 0) {
            ForEach(["vi", "en"], id: \.self) { l in
                Button { vm.setLang(l) } label: {
                    Text(l.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(vm.lang == l ? 1 : 0.55))
                        .frame(width: 22, height: 16)
                        .background(RoundedRectangle(cornerRadius: 4).fill(vm.lang == l ? Color.white.opacity(0.22) : .clear))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.2), lineWidth: 1))
        .help(vm.lang == "vi" ? "Ngôn ngữ" : "Language")
    }
}

// MARK: - Root

/// Tracks whether the sidebar menu has more items above or below the visible area.
final class ScrollEdges: ObservableObject {
    @Published var view: CGRect = .zero      // visible scroll area (global coordinates)
    @Published var content: CGRect = .zero   // menu content (global coordinates)
    var moreBelow: Bool { view.height > 0 && content.maxY > view.maxY + 4 }
    var moreAbove: Bool { view.height > 0 && content.minY < view.minY - 4 }
}

struct Sidebar: View {
    @ObservedObject var vm: VM
    @StateObject private var edges = ScrollEdges()
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fixed header, kept clear of the window's traffic-light buttons.
            HStack(spacing: 8) {
                Image(nsImage: cachedIcon(Theme.p)).resizable().frame(width: 28, height: 28)
                Text("Disk Cleanup").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
            }.padding(.top, 44).padding(.bottom, 12)
            // The menu scrolls when the window is short, so nothing overlaps.
            // A fade and a "More" chevron show that items are hidden below (and a fade at the top when scrolled).
            ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 2) {
            NavItem(p: .smart, vm: vm)
            SectionTitle(text: t("CLEANUP", "DỌN DẸP"))
            NavItem(p: .cleanup, vm: vm)
            NavItem(p: .apps, vm: vm)
            NavItem(p: .trash, vm: vm)
            SectionTitle(text: t("SPACE", "DUNG LƯỢNG"))
            NavItem(p: .large, vm: vm)
            NavItem(p: .dupes, vm: vm)
            NavItem(p: .lens, vm: vm)
            NavItem(p: .cloud, vm: vm)
            SectionTitle(text: t("SYSTEM", "HỆ THỐNG"))
            NavItem(p: .startup, vm: vm)
            NavItem(p: .stats, vm: vm)
            SectionTitle(text: t("SETTINGS", "CÀI ĐẶT"))
            NavItem(p: .ignore, vm: vm)
            NavItem(p: .settings, vm: vm)
            NavItem(p: .contact, vm: vm)
            }.padding(.bottom, 34)   // room so the "More" chip never covers the last item
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { edges.content = g.frame(in: .global) }
                    .onChange(of: g.frame(in: .global)) { _, r in edges.content = r }
            })
            }
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { edges.view = g.frame(in: .global) }
                    .onChange(of: g.frame(in: .global)) { _, r in edges.view = r }
            })
            .onAppear { DispatchQueue.main.async { proxy.scrollTo(vm.page, anchor: .center) } }
            .onChange(of: vm.page) { _, pg in withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(pg, anchor: .center) } }
            .overlay(alignment: .top) {
                if edges.moreAbove {
                    LinearGradient(colors: [Color.black.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 22).allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottom) {
                if edges.moreBelow {
                    ZStack(alignment: .bottom) {
                        LinearGradient(colors: [.clear, Color.black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
                            .frame(height: 40).allowsHitTesting(false)
                        Button { withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(Page.contact, anchor: .bottom) } } label: {
                            HStack(spacing: 4) {
                                Text(t("More", "Xem thêm")).font(.system(size: 10, weight: .semibold))
                                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.14)))
                        }.buttonStyle(.plain).hoverLift().padding(.bottom, 4)
                    }
                }
            }
            }
            Divider().overlay(Color.white.opacity(0.08)).padding(.bottom, 10)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Macintosh HD").font(.system(size: 11)).foregroundColor(Theme.sub)
                    Spacer()
                    LangSwitch(vm: vm)
                }
                (Text(String(format: t("%.0f GB free", "Trống %.0f GB"), vm.freeGB)).font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                 + Text(String(format: " / %.0f GB", vm.totalGB)).font(.system(size: 12)).foregroundColor(Theme.sub))
                DiskBar(free: vm.freeGB, total: vm.totalGB, low: vm.freeGB > 0 && vm.freeGB < vm.lowSpaceGB,
                        usedColor: Color.white.opacity(0.28))
                Text(String(format: t("%.0f GB used", "Đã dùng %.0f GB"), max(0, vm.totalGB - vm.freeGB)))
                    .font(.system(size: 10)).foregroundColor(Theme.sub)
            }.padding(.bottom, 16)
        }
        .padding(.horizontal, 14).frame(width: 210).background(Theme.sidebar)
    }
}

struct RootView: View {
    @ObservedObject var vm: VM
    var body: some View {
        HStack(spacing: 0) {
            Sidebar(vm: vm)
            Group {
                switch vm.page {
                case .smart: SmartView(vm: vm)
                case .cleanup: CleanupView(vm: vm)
                case .large: LargeView(vm: vm)
                case .lens: LensView(vm: vm)
                case .trash: TrashView(vm: vm)
                case .ignore: IgnoreView(vm: vm)
                case .cloud: CloudView(vm: vm)
                case .settings: SettingsView(vm: vm)
                case .apps: AppsView(vm: vm)
                case .dupes: DupesView(vm: vm)
                case .startup: StartupView(vm: vm)
                case .stats: StatsView(vm: vm)
                case .contact: ContactView(vm: vm)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.bg)
        .frame(minWidth: 980, minHeight: 600)
        .id(vm.theme)
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
    }
}

// MARK: - Uninstaller page

struct AppsView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(t("Uninstaller", "Gỡ app")).font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                Spacer()
                Picker("", selection: $vm.appsTab) {
                    Text(t("Apps", "App") + " (\(vm.apps.count))").tag(0)
                    Text(t("Leftovers", "File sót") + " (\(vm.leftovers.count))").tag(1)
                    Text(t("Installers", "File cài đặt") + " (\(vm.installers.count))").tag(2)
                }.pickerStyle(.segmented).frame(width: 360)
                if vm.appsBusy { ProgressView().controlSize(.small).tint(.white).padding(.leading, 6) }
                Button { vm.scanApps() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).foregroundColor(.white).padding(.leading, 6)
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 10)
            if !vm.appsMsg.isEmpty {
                Text(vm.appsMsg).font(.system(size: 12)).foregroundColor(Theme.green).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.bottom, 6)
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
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(vm.apps) { a in
                        HStack(spacing: 10) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: a.url.path)).resizable().frame(width: 26, height: 26)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(a.name).foregroundColor(.white).font(.system(size: 13)).lineLimit(1)
                                if let d = a.lastUsed {
                                    (Text(t("Last opened ", "Mở lần cuối ")) + Text(d, style: .date)).foregroundColor(Theme.sub).font(.system(size: 10))
                                } else {
                                    Text(t("Never opened", "Chưa mở lần nào")).foregroundColor(Theme.sub).font(.system(size: 10))
                                }
                            }
                            Spacer()
                            Text(fmt(a.size)).foregroundColor(Theme.sub).font(.system(size: 12).monospacedDigit())
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(vm.selApp == a.id ? Theme.cardHi : Color.clear))
                        .hoverBG(8, Color.white.opacity(0.07))
                        .contentShape(Rectangle())
                        .onTapGesture { vm.loadRelated(a.id) }
                    }
                }.padding(.horizontal, 12)
            }.frame(width: 320).background(Color.black.opacity(0.15))

            if let i = vm.apps.firstIndex(where: { $0.id == vm.selApp }) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: vm.apps[i].url.path)).resizable().frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vm.apps[i].name).font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                            Text(vm.apps[i].bundleID).font(.system(size: 11)).foregroundColor(Theme.sub)
                        }
                    }.padding(20)
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            HStack(spacing: 12) {
                                CheckBox(state: 2)
                                Image(nsImage: NSWorkspace.shared.icon(forFile: vm.apps[i].url.path)).resizable().frame(width: 22, height: 22)
                                Text(t("Application", "Ứng dụng")).foregroundColor(.white).font(.system(size: 13))
                                Spacer()
                                Text(fmt(vm.apps[i].size)).foregroundColor(.white).font(.system(size: 13, weight: .medium).monospacedDigit())
                            }.padding(.vertical, 6).padding(.horizontal, 12)
                            ForEach($vm.apps[i].related) { $it in ItemRow(item: $it, vm: vm) }
                            if vm.apps[i].related.isEmpty {
                                Text(t("No related files found in Library.", "Không thấy file liên quan trong Library."))
                                    .font(.system(size: 12)).foregroundColor(Theme.sub).padding(12)
                            }
                        }.padding(.horizontal, 12)
                    }
                    HStack {
                        let tot = vm.apps[i].size + vm.apps[i].related.filter(\.selected).reduce(0) { $0 + $1.size }
                        Text(t("Total ", "Tổng ") + fmt(tot)).foregroundColor(.white).font(.system(size: 15, weight: .semibold))
                        Spacer()
                        PrimaryButton(title: t("Uninstall", "Gỡ app"), action: { vm.uninstall(vm.apps[i].id) })
                    }.padding(.horizontal, 20).padding(.vertical, 14).background(Color.black.opacity(0.25))
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "app.badge.checkmark").font(.system(size: 44)).foregroundStyle(Theme.accent)
                    Text(t("Select an app to see everything it installed.", "Chọn một app để xem mọi thứ nó cài lên máy.")).foregroundColor(Theme.sub)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    func listTab(_ which: Int) -> some View {
        let items = which == 1 ? $vm.leftovers : $vm.installers
        let sel = (which == 1 ? vm.leftovers : vm.installers).filter(\.selected).reduce(0) { $0 + $1.size }
        return VStack(spacing: 0) {
            Text(which == 1
                 ? t("Files left behind by apps that are no longer installed.", "File do các app đã gỡ để lại.")
                 : t("Installer files (.dmg, .pkg) in Downloads, Desktop and Documents. Safe to remove once the app is installed.",
                     "File cài đặt (.dmg, .pkg) trong Downloads, Desktop, Documents. Cài xong app rồi thì xoá được."))
                .font(.system(size: 12)).foregroundColor(Theme.sub).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.bottom, 8)
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
                Text(t("\(fmt(sel)) selected", "Đã chọn \(fmt(sel))")).foregroundColor(.white).font(.system(size: 15, weight: .semibold))
                Spacer()
                PrimaryButton(title: t("Move to Trash", "Chuyển vào Thùng rác"), action: { vm.cleanList(which) }, disabled: sel == 0)
            }.padding(.horizontal, 24).padding(.vertical, 14).background(Color.black.opacity(0.25))
        }
    }
}

// MARK: - Duplicates page

struct DupesView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Duplicates", "File trùng")).font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                    Text(t("Identical files (same content, any name) over 1 MB in Documents, Downloads, Desktop, Pictures, Movies, Music.",
                           "File giống hệt nhau về nội dung (dù khác tên), trên 1 MB, trong Documents, Downloads, Desktop, Pictures, Movies, Music."))
                        .font(.system(size: 12)).foregroundColor(Theme.sub)
                }
                Spacer()
                Menu(t("Select", "Chọn")) {
                    Button(t("Select all duplicates (keep one)", "Chọn mọi bản trùng (giữ 1 bản)")) { vm.dupAutoSelect(all: true) }
                    Button(t("Deselect all", "Bỏ chọn tất cả")) { vm.dupAutoSelect(all: false) }
                }.menuStyle(.borderlessButton).frame(width: 70).foregroundColor(.white)
                Button { vm.scanDupes() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).foregroundColor(.white).padding(.leading, 6)
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 10)
            if !vm.dupMsg.isEmpty {
                Text(vm.dupMsg).font(.system(size: 12)).foregroundColor(Theme.green).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.bottom, 6)
            }
            if vm.dupBusy {
                Scanning(text: t("Comparing files... \(vm.dupCount) checked", "Đang so file... đã xem \(vm.dupCount)")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.dupes.isEmpty {
                VStack(spacing: 24) {
                    BigScanButton(label: t("Scan", "Quét")) { vm.scanDupes() }
                    Text(t("Files inside your project folders are never pre-selected.", "File trong thư mục dự án không bao giờ được tick sẵn.")).font(.system(size: 12)).foregroundColor(Theme.sub)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text(t("\(vm.dupes.count) groups, \(fmt(vm.dupWasted)) taken by extra copies. The first file of each group is the one suggested to keep.",
                       "\(vm.dupes.count) nhóm, \(fmt(vm.dupWasted)) bị chiếm bởi các bản thừa. File đầu tiên mỗi nhóm là bản đề xuất giữ lại."))
                    .font(.system(size: 12)).foregroundColor(Theme.sub).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.bottom, 8)
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach($vm.dupes) { $g in
                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    Button { vm.dupToggleGroup(g.id) } label: { CheckBox(state: vm.dupGroupState(g)) }.buttonStyle(.plain)
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: g.items[0].url.path)).resizable().frame(width: 26, height: 26)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(g.items[0].name).foregroundColor(.white).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                                        Text(t("\(g.items.count) copies × \(fmt(g.size))", "\(g.items.count) bản × \(fmt(g.size))")).foregroundColor(Theme.sub).font(.system(size: 11))
                                    }
                                    Spacer()
                                    Text(t("extra ", "thừa ") + fmt(g.wasted)).foregroundColor(.white).font(.system(size: 13, weight: .medium).monospacedDigit())
                                    Image(systemName: "chevron.down").rotationEffect(.degrees(g.expanded ? 0 : -90)).foregroundColor(Theme.sub)
                                }
                                .padding(12).hoverBG(14, Color.white.opacity(0.06)).contentShape(Rectangle())
                                .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { g.expanded.toggle() } }
                                if g.expanded {
                                    Divider().background(Color.white.opacity(0.1))
                                    ForEach(Array($g.items.enumerated()), id: \.element.id) { idx, $it in
                                        HStack(spacing: 0) {
                                            ItemRow(item: $it, vm: vm, showDate: true)
                                            if idx == 0 {
                                                Text(t("Keep", "Giữ")).font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.green)
                                                    .padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(Theme.green.opacity(0.15))).padding(.trailing, 10)
                                            }
                                        }
                                    }.padding(.leading, 14)
                                }
                            }.background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                        }
                    }.padding(.horizontal, 24).padding(.bottom, 16)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("\(fmt(vm.dupSelected)) selected", "Đã chọn \(fmt(vm.dupSelected))")).foregroundColor(.white).font(.system(size: 15, weight: .semibold))
                        Text(t("At least one copy of every file is always kept.", "Mỗi file luôn giữ lại ít nhất một bản.")).foregroundColor(Theme.sub).font(.system(size: 11))
                    }
                    Spacer()
                    if vm.refsBusy { ProgressView().controlSize(.small).tint(.white).padding(.trailing, 6) }
                    GhostButton(title: vm.dupAllExtrasSelected ? t("Deselect all", "Bỏ chọn tất cả") : t("Select all extra copies", "Chọn mọi bản thừa")) {
                        vm.dupAutoSelect(all: !vm.dupAllExtrasSelected)
                    }.padding(.trailing, 8)
                    PrimaryButton(title: t("Move to Trash", "Chuyển vào Thùng rác"), action: { vm.cleanDupes() }, disabled: vm.dupSelected == 0)
                }.padding(.horizontal, 24).padding(.vertical, 14).background(Color.black.opacity(0.25))
            }
        }
    }
}

// MARK: - Cloud page

struct CloudView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Cloud Cleanup", "Dữ liệu đám mây")).font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                    Text(t("How much of Google Drive, iCloud and other cloud folders is stored on this Mac. Files that live only in the cloud count as 0.",
                           "Google Drive, iCloud và các thư mục mây đang chiếm bao nhiêu trên máy. File chỉ nằm trên mây tính là 0."))
                        .foregroundColor(Theme.sub).font(.system(size: 12))
                }
                Spacer()
                if vm.cloudBusy { ProgressView().controlSize(.small).tint(.white) }
                Button { vm.scanCloud() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).foregroundColor(.white)
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 12)
            if !vm.cloudMsg.isEmpty {
                Text(vm.cloudMsg).font(.system(size: 12)).foregroundColor(Theme.green).padding(.horizontal, 24).padding(.bottom, 8)
            }
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach($vm.clouds) { $p in
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Image(systemName: p.isICloud ? "icloud.fill" : "externaldrive.connected.to.line.below")
                                    .font(.system(size: 18)).foregroundStyle(Theme.accent).frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).foregroundColor(.white).font(.system(size: 14, weight: .semibold))
                                    if !p.account.isEmpty { Text(p.account).foregroundColor(Theme.sub).font(.system(size: 11)) }
                                }
                                Spacer()
                                Text(t("on this Mac: ", "trên máy: ")).foregroundColor(Theme.sub).font(.system(size: 12))
                                Text(fmt(p.local)).foregroundColor(.white).font(.system(size: 14, weight: .semibold).monospacedDigit())
                                Image(systemName: "chevron.down").rotationEffect(.degrees(p.expanded ? 0 : -90)).foregroundColor(Theme.sub)
                            }
                            .padding(14).hoverBG(14, Color.white.opacity(0.06)).contentShape(Rectangle())
                            .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { p.expanded.toggle() } }
                            if p.expanded {
                                Divider().background(Color.white.opacity(0.1))
                                if !p.isICloud {
                                    Text(t("macOS only lets the Drive app remove downloads. Click Show in Finder, then right-click > Remove Download.",
                                           "macOS chỉ cho app Drive gỡ bản tải xuống. Bấm Mở trong Finder, rồi chuột phải > Remove Download (Xoá bản tải xuống)."))
                                        .font(.system(size: 11)).foregroundColor(Theme.warn).padding(.horizontal, 14).padding(.top, 8)
                                }
                                if p.items.isEmpty {
                                    Text(t("Nothing stored locally.", "Không có gì lưu trên máy.")).font(.system(size: 12)).foregroundColor(Theme.sub).padding(14)
                                }
                                ForEach(p.items) { n in
                                    HStack(spacing: 10) {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: n.url.path)).resizable().frame(width: 20, height: 20)
                                        Text(n.url.lastPathComponent).foregroundColor(.white).font(.system(size: 12)).lineLimit(1)
                                        Spacer()
                                        Text(fmt(n.size)).foregroundColor(Theme.sub).font(.system(size: 12).monospacedDigit())
                                        if p.isICloud {
                                            Button(t("Remove Download", "Xoá bản trên máy")) { vm.evictICloud(n.url) }
                                                .buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.link)
                                        }
                                        Button(t("Show in Finder", "Mở trong Finder")) { vm.reveal(n.url) }
                                            .buttonStyle(.plain).font(.system(size: 11)).foregroundColor(.white.opacity(0.8))
                                    }.padding(.horizontal, 14).padding(.vertical, 6).hoverBG(8, Color.white.opacity(0.07))
                                }
                            }
                        }.background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                    }
                }.padding(.horizontal, 24).padding(.bottom, 16)
            }
        }
        .onAppear { if vm.clouds.isEmpty { vm.scanCloud() } }
    }
}

// MARK: - Settings page

struct SettingsView: View {
    @ObservedObject var vm: VM
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            Text(t("Settings", "Cài đặt")).font(.system(size: 22, weight: .bold)).foregroundColor(.white).padding(.top, 34)
            settingRow(t("Theme", "Giao diện màu"), t("Inspired by Apple's 2026 colours.", "Lấy cảm hứng từ bảng màu Apple 2026.")) {
                HStack(spacing: 10) {
                    ForEach(palettes, id: \.id) { pl in
                        Button { vm.setTheme(pl.id) } label: {
                            VStack(spacing: 4) {
                                Circle().fill(LinearGradient(colors: pl.bg.map { Color(hex: $0) } + pl.accent.suffix(1).map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 30, height: 30)
                                    .overlay(Circle().stroke(Color.white.opacity(vm.theme == pl.id ? 0.95 : 0.25), lineWidth: vm.theme == pl.id ? 2 : 1))
                                Text(appLang == "vi" ? pl.nameVI.components(separatedBy: " (").first ?? pl.nameVI : pl.nameEN)
                                    .font(.system(size: 10)).foregroundColor(vm.theme == pl.id ? .white : Theme.sub)
                            }
                        }.buttonStyle(.plain).hoverLift().help(appLang == "vi" ? pl.nameVI : pl.nameEN)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("Project folders", "Thư mục dự án")).foregroundColor(.white).font(.system(size: 14, weight: .semibold))
                        Text(t("Where you keep code or AI workspaces. Drafts (_tmp, _to_delete) are found here, duplicates here are never pre-selected, and links are checked here before deleting.",
                               "Nơi chứa code hoặc thư mục làm việc với AI. App tìm nháp (_tmp, _to_delete) ở đây, không tick sẵn file trùng ở đây, và kiểm tra liên kết ở đây trước khi xoá."))
                            .foregroundColor(Theme.sub).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    GhostButton(title: t("Add folder...", "Thêm thư mục...")) { vm.addProjectFolder() }
                }
                ForEach(vm.projects, id: \.self) { p in
                    HStack(spacing: 8) {
                        Image(systemName: "folder").foregroundColor(Theme.link)
                        Text(p.replacingOccurrences(of: NSHomeDirectory(), with: "~")).foregroundColor(.white).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button(t("Remove", "Gỡ")) { vm.removeProjectFolder(p) }.buttonStyle(.plain).font(.system(size: 12)).foregroundColor(Theme.link)
                    }.padding(.horizontal, 10).padding(.vertical, 5).hoverBG(8, Color.white.opacity(0.06))
                }
            }.padding(14).background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            settingRow(t("Open at login", "Mở cùng máy"),
                       t("Keeps the menu bar monitor running after restart.", "Giữ biểu tượng theo dõi trên thanh menu sau khi khởi động lại máy.")) {
                Toggle("", isOn: Binding(get: { vm.openAtLogin }, set: { vm.setOpenAtLogin($0) })).toggleStyle(.switch).labelsHidden()
            }
            settingRow(t("Low disk space alert", "Cảnh báo ổ sắp đầy"),
                       String(format: t("Notify when free space drops below %.0f GB (at most every 6 hours).", "Báo khi dung lượng trống dưới %.0f GB (tối đa 6 giờ báo một lần)."), vm.lowSpaceGB)) {
                Stepper("", value: Binding(get: { vm.lowSpaceGB }, set: { vm.setLowSpace($0) }), in: 10...100, step: 5).labelsHidden()
            }
            settingRow(t("High memory alert", "Cảnh báo RAM cao"),
                       t("Notify when more than 90% of RAM is in use (at most once an hour).", "Báo khi RAM dùng trên 90% (tối đa 1 giờ báo một lần).")) {
                Toggle("", isOn: Binding(get: { vm.ramAlert }, set: { vm.setRamAlert($0) })).toggleStyle(.switch).labelsHidden()
            }
        }.padding(.horizontal, 24).padding(.bottom, 24).frame(maxWidth: .infinity, alignment: .leading) }
    }
    func settingRow<C: View>(_ title: String, _ sub: String, @ViewBuilder _ control: () -> C) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).foregroundColor(.white).font(.system(size: 14, weight: .semibold))
                Text(sub).foregroundColor(Theme.sub).font(.system(size: 11))
            }
            Spacer()
            control()
        }.padding(14).background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
    }
}

// MARK: - Menu bar

/// Capacity bar like macOS Storage (used for disk and RAM): used part in neutral grey on the left,
/// free part highlighted in the theme colour on the right (red when nearly full).
struct DiskBar: View {
    let free: Double, total: Double, low: Bool
    var usedColor: Color = Color.primary.opacity(0.28)
    var body: some View {
        GeometryReader { g in
            let f = total > 0 ? max(0.02, min(1, free / total)) : 0
            let fw = g.size.width * CGFloat(f)
            HStack(spacing: 2) {
                Capsule().fill(usedColor)
                Capsule().fill(low ? AnyShapeStyle(Color.red) : AnyShapeStyle(Theme.accent)).frame(width: fw)
            }
        }.frame(height: 6)
    }
}

struct Meter: View {
    let label: String, value: String, frac: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(label).foregroundColor(.secondary); Spacer(); Text(value).fontWeight(.semibold) }.font(.system(size: 12))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12))
                    Capsule().fill(frac > 0.9 ? AnyShapeStyle(Color.red) : AnyShapeStyle(Theme.accent)).frame(width: g.size.width * CGFloat(max(0, min(1, frac))))
                }
            }.frame(height: 6)
        }
    }
}

struct MenuView: View {
    @ObservedObject var vm: VM
    @Environment(\.openWindow) var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 22, height: 22)
                Text("Disk Cleanup").font(.system(size: 13, weight: .bold))
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text(t("Disk", "Ổ đĩa")).foregroundColor(.secondary); Spacer()
                    Text(String(format: t("%.0f GB free / %.0f GB", "Trống %.0f / %.0f GB"), vm.freeGB, vm.totalGB)).fontWeight(.semibold) }
                    .font(.system(size: 12))
                DiskBar(free: vm.freeGB, total: vm.totalGB, low: vm.freeGB > 0 && vm.freeGB < vm.lowSpaceGB)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text("RAM").foregroundColor(.secondary); Spacer()
                    Text(String(format: t("%.1f GB free / %.0f GB", "Trống %.1f / %.0f GB"), max(0, vm.ramTotal - vm.ramUsed), vm.ramTotal)).fontWeight(.semibold) }
                    .font(.system(size: 12))
                DiskBar(free: max(0, vm.ramTotal - vm.ramUsed), total: vm.ramTotal, low: vm.ramTotal > 0 && vm.ramUsed / vm.ramTotal > 0.9)
            }
            HStack { Text(t("Trash", "Thùng rác")).foregroundColor(.secondary); Spacer(); Text(fmt(vm.trashSize)).fontWeight(.semibold) }.font(.system(size: 12))
            Divider()
            VStack(spacing: 1) {
                MenuRow(title: t("Open Disk Cleanup", "Mở Disk Cleanup")) { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
                MenuRow(title: t("Smart Scan", "Quét thông minh")) { vm.page = .smart; openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true); vm.smartScan() }
                MenuRow(title: t("Empty Trash...", "Đổ Thùng rác..."), disabled: vm.trashCount == 0) { NSApp.activate(ignoringOtherApps: true); vm.emptyTrash() }
            }.padding(.horizontal, -8)
            Divider()
            MenuRow(title: t("Quit", "Thoát")) { NSApp.terminate(nil) }.padding(.horizontal, -8)
        }
        .padding(14).frame(width: 280)
        .onAppear { vm.refreshRAM(); vm.refreshDisk(); vm.refreshTrash() }
    }
}

/// Menu bar icon: a hard drive with the free space (e.g. "75GB") inside the upper part,
/// a divider line and an activity light at the bottom. The shaded part shows free space
/// like a battery level; red when the disk is nearly full.
func menuBarImage(free: Double, total: Double, low: Bool) -> NSImage {
    // 75GB, 123GB, then 1.2TB from 1000 GB up, so the icon never grows past 3 digits.
    let text = free >= 999.5 ? String(format: "%.1fTB", free / 1000) : String(format: "%.0fGB", free)
    let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    let ink: NSColor = low ? (dark ? .white : .black) : .black
    let font = NSFont.systemFont(ofSize: 9, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
    let ts = (text as NSString).size(withAttributes: attrs)
    let bw: CGFloat = max(30, ceil(ts.width) + 7), bh: CGFloat = 16
    let W = bw + 1, H: CGFloat = 18
    let img = NSImage(size: NSSize(width: W, height: H), flipped: true) { _ in
        let body = NSRect(x: 0.5, y: 1, width: bw, height: bh)
        let outline = NSBezierPath(roundedRect: body, xRadius: 3.5, yRadius: 3.5)
        ink.withAlphaComponent(0.75).setStroke(); outline.lineWidth = 1.1; outline.stroke()
        // upper compartment with the free-space fill
        let upper = NSRect(x: body.minX + 1.6, y: body.minY + 1.6, width: body.width - 3.2, height: 10)
        let frac = total > 0 ? max(0.06, min(1, free / total)) : 0
        (low ? NSColor.systemRed.withAlphaComponent(0.85) : ink.withAlphaComponent(0.28)).setFill()
        NSBezierPath(roundedRect: NSRect(x: upper.minX, y: upper.minY, width: upper.width * frac, height: upper.height), xRadius: 2, yRadius: 2).fill()
        // divider and activity light
        let y = body.minY + 12.3
        let line = NSBezierPath(); line.move(to: NSPoint(x: body.minX, y: y)); line.line(to: NSPoint(x: body.maxX, y: y))
        line.lineWidth = 1; line.stroke()
        ink.setFill()
        NSBezierPath(ovalIn: NSRect(x: body.maxX - 5.2, y: y + 0.9, width: 2, height: 2)).fill()
        // label
        (text as NSString).draw(at: NSPoint(x: body.midX - ts.width / 2, y: upper.midY - ts.height / 2), withAttributes: attrs)
        return true
    }
    img.isTemplate = !low
    return img
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationDidFinishLaunching(_ n: Notification) {
        // Developer helper: `DiskCleanup --export-icon <theme> <out.png>` writes the 1024px icon and quits.
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "--export-icon"), i + 2 < a.count,
           let pal = palettes.first(where: { $0.id == a[i + 1] }),
           let tiff = makeAppIcon(pal).tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: a[i + 2])); exit(0)
        }
        // Developer helper: `DiskCleanup --export-menubar <freeGB> <out.png>` writes the menu bar icon at 8x and quits.
        if let i = a.firstIndex(of: "--export-menubar"), i + 2 < a.count, let f = Double(a[i + 1]) {
            let im = menuBarImage(free: f, total: 245, low: false)
            let px = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(im.size.width * 8), pixelsHigh: Int(im.size.height * 8),
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            px.size = im.size
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: px)
            im.draw(in: NSRect(origin: .zero, size: im.size)); NSGraphicsContext.restoreGraphicsState()
            try? px.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: a[i + 2])); exit(0)
        }
        NSApp.applicationIconImage = makeAppIcon(Theme.p)
        // Developer helper for README screenshots: `--page <name> --window <W>x<H>` opens a page at a fixed size.
        if let i = a.firstIndex(of: "--page"), i + 1 < a.count,
           let pg = Page.allCases.first(where: { "\($0)" == a[i + 1] }) {
            sharedVM.page = pg
        }
        if let i = a.firstIndex(of: "--window"), i + 1 < a.count {
            let wh = a[i + 1].split(separator: "x").compactMap { Double($0) }
            if wh.count == 2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    for w in NSApp.windows where w.title == "Disk Cleanup" || w.identifier?.rawValue.contains("main") == true {
                        w.setContentSize(NSSize(width: wh[0], height: wh[1])); w.center()
                    }
                }
            }
        }
    }
}

// MARK: - App icon (drawn in code so it follows the theme)

/// Front view of a Mac mini (2024): two USB-C ports on the left; on the right,
/// the white status light sits just left of the headphone jack. 1024 x 1024 canvas, macOS icon grid (824 px rounded square).
private var iconCache: [String: NSImage] = [:]
func cachedIcon(_ p: Palette) -> NSImage {
    if let i = iconCache[p.id] { return i }
    let i = makeAppIcon(p); iconCache[p.id] = i; return i
}

func makeAppIcon(_ p: Palette) -> NSImage {
    let img = NSImage(size: NSSize(width: 1024, height: 1024), flipped: true) { _ in
        let dark = NSColor(hex: p.bg[0])
        let body = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 190, yRadius: 190)
        NSGraphicsContext.saveGraphicsState()
        let sh = NSShadow(); sh.shadowOffset = NSSize(width: 0, height: -16); sh.shadowBlurRadius = 40
        sh.shadowColor = NSColor.black.withAlphaComponent(0.4); sh.set()
        dark.setFill(); body.fill()
        NSGraphicsContext.restoreGraphicsState()
        let cols = p.icon.map { NSColor(hex: $0) }
        let locs = (0..<cols.count).map { CGFloat($0) / CGFloat(max(cols.count - 1, 1)) }
        NSGradient(colors: cols, atLocations: locs, colorSpace: .sRGB)?.draw(in: body, angle: 90)
        NSGradient(colors: [NSColor.white.withAlphaComponent(0.14), NSColor.white.withAlphaComponent(0)],
                   atLocations: [0, 0.45], colorSpace: .sRGB)?.draw(in: body, angle: 90)
        // recessed foot
        dark.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: NSRect(x: 262, y: 688, width: 500, height: 22), xRadius: 10, yRadius: 10).fill()
        // body (2.54:1)
        let mini = NSBezierPath(roundedRect: NSRect(x: 222, y: 460, width: 580, height: 228), xRadius: 40, yRadius: 40)
        NSGraphicsContext.saveGraphicsState(); sh.shadowColor = NSColor.black.withAlphaComponent(0.35); sh.set()
        NSColor.white.withAlphaComponent(0.92).setFill(); mini.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(colors: [NSColor.white.withAlphaComponent(0.0), dark.withAlphaComponent(0.18)], atLocations: [0, 1], colorSpace: .sRGB)?
            .draw(in: mini, angle: -45)
        NSColor.white.withAlphaComponent(0.8).setFill()
        NSBezierPath(roundedRect: NSRect(x: 262, y: 466, width: 500, height: 6), xRadius: 3, yRadius: 3).fill()
        // two USB-C ports (vertical), left
        dark.withAlphaComponent(0.85).setFill()
        NSBezierPath(roundedRect: NSRect(x: 304, y: 547, width: 18, height: 56), xRadius: 9, yRadius: 9).fill()
        NSBezierPath(roundedRect: NSRect(x: 348, y: 547, width: 18, height: 56), xRadius: 9, yRadius: 9).fill()
        // white status light, just left of the headphone jack
        dark.withAlphaComponent(0.55).setFill()
        NSBezierPath(ovalIn: NSRect(x: 656, y: 565, width: 20, height: 20)).fill()
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow(); glow.shadowBlurRadius = 10; glow.shadowOffset = .zero; glow.shadowColor = NSColor.white; glow.set()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: 660, y: 569, width: 12, height: 12)).fill()
        NSGraphicsContext.restoreGraphicsState()
        // headphone jack, right
        dark.withAlphaComponent(0.85).setFill()
        NSBezierPath(ovalIn: NSRect(x: 707, y: 560, width: 30, height: 30)).fill()
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: 715, y: 568, width: 14, height: 14)).fill()
        // sparkles
        func sparkle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ k: CGFloat, _ alpha: CGFloat) {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: cx, y: cy - r))
            path.curve(to: NSPoint(x: cx + r, y: cy), controlPoint1: NSPoint(x: cx + r * k * 0.12, y: cy - r * 0.3), controlPoint2: NSPoint(x: cx + r * 0.3, y: cy - r * k * 0.12))
            path.curve(to: NSPoint(x: cx, y: cy + r), controlPoint1: NSPoint(x: cx + r * 0.3, y: cy + r * k * 0.12), controlPoint2: NSPoint(x: cx + r * k * 0.12, y: cy + r * 0.3))
            path.curve(to: NSPoint(x: cx - r, y: cy), controlPoint1: NSPoint(x: cx - r * k * 0.12, y: cy + r * 0.3), controlPoint2: NSPoint(x: cx - r * 0.3, y: cy + r * k * 0.12))
            path.curve(to: NSPoint(x: cx, y: cy - r), controlPoint1: NSPoint(x: cx - r * 0.3, y: cy - r * k * 0.12), controlPoint2: NSPoint(x: cx - r * k * 0.12, y: cy - r * 0.3))
            NSColor.white.withAlphaComponent(alpha).setFill(); path.fill()
        }
        sparkle(640, 330, 100, 1, 1)
        sparkle(410, 290, 40, 1, 0.85)
        return true
    }
    return img
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1)
    }
}

let sharedVM = MainActor.assumeIsolated { VM() }

@main
struct DiskCleanupApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @ObservedObject var vm = sharedVM
    var body: some Scene {
        Window("Disk Cleanup", id: "main") { RootView(vm: vm) }
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width: 1080, height: 700)
        MenuBarExtra {
            MenuView(vm: vm).id(vm.theme)
        } label: {
            Image(nsImage: menuBarImage(free: vm.freeGB, total: vm.totalGB, low: vm.freeGB > 0 && vm.freeGB < vm.lowSpaceGB))
        }
        .menuBarExtraStyle(.window)
    }
}


// MARK: - Startup page

struct StartupView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("Startup Items", "Tự chạy khi bật máy")).font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                Text(t("Background helpers that start with your Mac. Many come from updaters you do not need running all the time.",
                       "Các tiến trình chạy ngầm khi bật máy. Nhiều mục là trình tự cập nhật, không cần chạy suốt."))
                    .foregroundColor(Theme.sub).font(.system(size: 12))
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 12)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach([0, 1, 2], id: \.self) { sc in
                        let rows = vm.launch.indices.filter { vm.launch[$0].scope == sc }
                        if !rows.isEmpty {
                            Text(sc == 0 ? t("YOUR ACCOUNT (can remove here)", "CỦA TÀI KHOẢN CHÚ (gỡ được ở đây)")
                                 : sc == 1 ? t("ALL USERS · AGENTS (needs admin, remove via the app or Settings)", "CẢ MÁY · AGENT (cần quyền admin, gỡ bằng app gốc hoặc Cài đặt)")
                                 : t("ALL USERS · SYSTEM SERVICES (needs admin)", "CẢ MÁY · DỊCH VỤ HỆ THỐNG (cần quyền admin)"))
                                .font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundColor(Theme.sub).padding(.top, 10).padding(.leading, 4)
                            ForEach(rows, id: \.self) { i in LaunchRow(e: $vm.launch[i], vm: vm) }
                        }
                    }
                }.padding(.horizontal, 24).padding(.bottom, 12)
            }
            HStack(spacing: 12) {
                Text(vm.launchMsg.isEmpty ? t("\(vm.launch.count) items", "\(vm.launch.count) mục") : vm.launchMsg)
                    .foregroundColor(.white).font(.system(size: 13)).lineLimit(2)
                Spacer()
                GhostButton(title: t("Open Login Items settings", "Mở cài đặt Mục đăng nhập")) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
                }
                PrimaryButton(title: t("Remove selected", "Gỡ mục đã chọn"), action: { vm.removeLaunch() },
                              disabled: !vm.launch.contains { $0.selected && $0.scope == 0 })
            }.padding(.horizontal, 24).padding(.vertical, 12).background(Color.black.opacity(0.25))
        }
        .onAppear { vm.scanLaunch() }
    }
}

struct LaunchRow: View {
    @Binding var e: LaunchEntry
    let vm: VM
    var body: some View {
        HStack(spacing: 12) {
            if e.scope == 0 {
                Button { e.selected.toggle() } label: { CheckBox(state: e.selected ? 2 : 0) }.buttonStyle(.plain)
            } else {
                Image(systemName: "lock.fill").font(.system(size: 12)).foregroundColor(Theme.sub).frame(width: 17)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(e.owner).foregroundColor(.white).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    if e.orphan { badge(t("App removed", "App đã gỡ"), Theme.danger) }
                    if e.running == true { badge(t("Running", "Đang chạy"), Theme.green) }
                }
                Text(e.label).foregroundColor(Theme.sub).font(.system(size: 11)).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Button(t("Reveal", "Xem file")) { vm.reveal(e.url) }.buttonStyle(.plain).font(.system(size: 12)).foregroundColor(Theme.link)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
        .hoverBG(10, Color.white.opacity(0.06))
        .help(e.program)
    }
    func badge(_ s: String, _ c: Color) -> some View {
        Text(s).font(.system(size: 10, weight: .semibold)).foregroundColor(c)
            .padding(.horizontal, 6).padding(.vertical, 1).background(Capsule().fill(c.opacity(0.15)))
    }
}

// MARK: - Stats page

struct StatsView: View {
    @ObservedObject var vm: VM
    @StateObject private var tick = Flag()
    var body: some View {
        let log = Stats.load()
        let freed = log.reduce(0) { $0 + $1.freed }
        let runs = log.filter { $0.freed > 0 }.count
        let points = log.compactMap { e in e.freeGB.map { (e.date, $0) } }
        let df: DateFormatter = { let f = DateFormatter(); f.dateFormat = "dd/MM HH:mm"; return f }()
        VStack(alignment: .leading, spacing: 16) {
            Text(t("Statistics", "Thống kê")).font(.system(size: 22, weight: .bold)).foregroundColor(.white).padding(.top, 34)
            HStack(spacing: 12) {
                statCard(t("Freed in total", "Tổng đã giải phóng"), fmt(freed))
                statCard(t("Cleanups", "Số lần dọn"), "\(runs)")
                statCard(t("Free now", "Đang trống"), String(format: "%.0f GB", vm.freeGB))
                statCard(t("Trash now", "Thùng rác"), fmt(vm.trashSize))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(t("Free space over time (GB)", "Dung lượng trống theo thời gian (GB)")).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.sub)
                GeometryReader { g in
                    let vals = points.suffix(30).map { $0.1 }
                    let mx = max(vals.max() ?? 1, 1)
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(Array(vals.enumerated()), id: \.offset) { _, v in
                            VStack(spacing: 2) {
                                Text(String(format: "%.0f", v)).font(.system(size: 9)).foregroundColor(Theme.sub)
                                RoundedRectangle(cornerRadius: 3).fill(Theme.accent)
                                    .frame(height: max(4, CGFloat(v / mx) * (g.size.height - 16)))
                            }.frame(maxWidth: 28)
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }.frame(height: 120)
            }.padding(14).background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            HStack {
                Text(t("Recent activity", "Hoạt động gần đây")).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.sub)
                Spacer()
                Button(t("Open log file", "Mở file nhật ký")) { NSWorkspace.shared.open(URL(fileURLWithPath: Stats.path)) }
                    .buttonStyle(.plain).font(.system(size: 12)).foregroundColor(Theme.link)
            }
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(log.reversed().prefix(60)) { e in
                        HStack(alignment: .top, spacing: 10) {
                            Text(df.string(from: e.date)).font(.system(size: 11).monospacedDigit()).foregroundColor(Theme.sub).frame(width: 78, alignment: .leading)
                            Text(e.text).font(.system(size: 12)).foregroundColor(e.text.hasPrefix("ERROR") ? Theme.danger : .white).lineLimit(2)
                            Spacer()
                            if e.freed > 0 { Text("+" + fmt(e.freed)).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.green) }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .hoverBG(8, Color.white.opacity(0.06))
                    }
                }
            }
        }
        .padding(.horizontal, 24).padding(.bottom, 16)
        .onAppear { vm.refreshTrash(); vm.refreshDisk(); tick.v.toggle() }
    }
    func statCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11)).foregroundColor(Theme.sub)
            Text(value).font(.system(size: 22, weight: .bold)).foregroundColor(.white)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .hoverBG(12, Color.white.opacity(0.05))
    }
}


// MARK: - Feedback & newsletter

/// Where feedback and newsletter sign-ups go. `endpoint` is a Google Apps Script web app that appends
/// one row per submission to a Google Sheet (see backend/Code.gs). No email address is published on purpose.
enum Backend {
    static let endpoint = "https://script.google.com/macros/s/AKfycbz07aYQ8kI0u0OV842dt-LxeN5TedqfOzNvhmuVAPmgXdcIGtpzI-GNwLE_kiUMiGDKag/exec"
    /// Public privacy policy (PRIVACY.md on GitHub). The link is hidden while empty.
    static let privacyURL = "https://github.com/HaiTrung-Workspace/disk-cleanup/blob/main/PRIVACY.md"
    static let consentVersion = "2026-10"
    static var newsletterText: String {
        t("Get the latest updates. Unsubscribe any time.",
          "Nhận thông tin cập nhật mới nhất. Huỷ bất kỳ lúc nào.")
    }
    static var systemInfo: [String: String] {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        var model = "Mac"
        var size = 0; sysctlbyname("hw.model", nil, &size, nil, 0)
        if size > 0 { var buf = [CChar](repeating: 0, count: size); sysctlbyname("hw.model", &buf, &size, nil, 0); model = String(cString: buf) }
        return ["app": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
                "macos": "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)", "model": model, "lang": appLang]
    }
    static func send(_ fields: [String: String], done: @escaping @MainActor (Bool) -> Void) {
        guard let url = URL(string: endpoint), !endpoint.isEmpty else { Task { @MainActor in done(false) }; return }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 20
        req.setValue("text/plain;charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: fields)
        URLSession.shared.dataTask(with: req) { data, resp, err in
            let ok = err == nil && ((resp as? HTTPURLResponse)?.statusCode ?? 0) < 400
                && (String(data: data ?? Data(), encoding: .utf8) ?? "").contains("ok")
            Task { @MainActor in done(ok) }
        }.resume()
    }
    static func validEmail(_ e: String) -> Bool {
        e.range(of: #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

/// When to show the newsletter invitation after a cleanup: never again after signing up or "Don't ask again",
/// otherwise at most once every 14 days.
enum Invite {
    static func shouldShow() -> Bool {
        let d = UserDefaults.standard
        if ["subscribed", "never"].contains(d.string(forKey: "inviteState") ?? "") { return false }
        if let last = d.object(forKey: "inviteLast") as? Date, Date().timeIntervalSince(last) < 14 * 86400 { return false }
        return true
    }
    static func later() { UserDefaults.standard.set(Date(), forKey: "inviteLast") }
    static func never() { UserDefaults.standard.set("never", forKey: "inviteState") }
    static func subscribed() { UserDefaults.standard.set("subscribed", forKey: "inviteState") }
}

final class FormState: ObservableObject {
    @Published var email = UserDefaults.standard.string(forKey: "contactEmail") ?? ""
    @Published var kind = "feedback"
    @Published var message = ""
    @Published var includeInfo = true
    @Published var sending = false
    @Published var result = ""
    @Published var ok = false
    @Published var hidden = false
}

struct FieldBox<C: View>: View {
    let title: String
    @ViewBuilder let content: () -> C
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.sub)
            content()
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.25)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
    }
}

struct ContactView: View {
    @ObservedObject var vm: VM
    @StateObject private var f = FormState()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Contact the developer", "Liên hệ nhà phát triển")).font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                    Text(t("Feedback, bug reports and questions go straight to Hai Trung. An email address is needed so you can get a reply.",
                           "Góp ý, báo lỗi, câu hỏi đều tới thẳng Hải Trung. Cần email để có thể trả lời bạn."))
                        .foregroundColor(Theme.sub).font(.system(size: 12))
                }.padding(.top, 34)
                HStack(spacing: 8) {
                    ForEach([("feedback", t("Feedback", "Góp ý")), ("bug", t("Bug report", "Báo lỗi")), ("question", t("Question", "Câu hỏi"))], id: \.0) { k, label in
                        Button { f.kind = k } label: {
                            Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(.white)
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(Capsule().fill(f.kind == k ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.card)))
                        }.buttonStyle(.plain).hoverLift()
                    }
                }
                FieldBox(title: t("Your email (required)", "Email của bạn (bắt buộc)")) {
                    TextField("name@example.com", text: $f.email).textFieldStyle(.plain).foregroundColor(.white)
                        .onSubmit { submit(newsletter: true) }
                }
                FieldBox(title: t("Message", "Nội dung")) {
                    TextEditor(text: $f.message).font(.system(size: 13)).foregroundColor(.white)
                        .scrollContentBackground(.hidden).frame(minHeight: 140)
                }
                Toggle(isOn: $f.includeInfo) {
                    Text(t("Attach app version, macOS version and Mac model", "Kèm phiên bản app, phiên bản macOS và đời máy"))
                        .font(.system(size: 12)).foregroundColor(Theme.sub)
                }.toggleStyle(.checkbox)
                if !f.result.isEmpty {
                    Text(f.result).font(.system(size: 13, weight: .medium)).foregroundColor(f.ok ? Theme.green : Theme.warn)
                }
                HStack(spacing: 10) {
                    if f.sending { ProgressView().controlSize(.small).tint(.white) }
                    Spacer()
                    // Return (outside the message box) = the main button.
                    Button { submit(newsletter: true) } label: {
                        Text(t("Send & get the newsletter", "Gửi và nhận bản tin")).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                            .padding(.horizontal, 28).padding(.vertical, 11)
                            .background(Capsule().fill(Theme.accent)).shadow(color: Theme.accentSolid.opacity(0.4), radius: 12, y: 4)
                    }.buttonStyle(.plain).hoverLift().disabled(f.sending).keyboardShortcut(.defaultAction)
                    Button { submit(newsletter: false) } label: {
                        Text(t("Send only", "Chỉ gửi")).font(.system(size: 12)).foregroundColor(Theme.sub)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    }.buttonStyle(.plain).hoverBG(14, Color.white.opacity(0.08)).disabled(f.sending)
                }
                HStack(spacing: 6) {
                    Spacer()
                    Text(Backend.newsletterText).font(.system(size: 11)).foregroundColor(Theme.sub)
                    if let u = URL(string: Backend.privacyURL), !Backend.privacyURL.isEmpty {
                        Link(t("Privacy", "Quyền riêng tư"), destination: u).font(.system(size: 11)).foregroundColor(Theme.link)
                    }
                }
            }.padding(.horizontal, 24).padding(.bottom, 24)
        }
    }
    func submit(newsletter: Bool) {
        let email = f.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let msg = f.message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Backend.validEmail(email) else { f.ok = false; f.result = t("Please enter a valid email.", "Bạn nhập email hợp lệ giúp nhé."); return }
        guard !msg.isEmpty else { f.ok = false; f.result = t("Please write a message.", "Bạn viết nội dung giúp nhé."); return }
        UserDefaults.standard.set(email, forKey: "contactEmail")
        var fields = ["source": "contact", "type": f.kind, "email": email, "message": msg,
                      "newsletter": newsletter ? "yes" : "no", "consent": newsletter ? Backend.newsletterText : "",
                      "consentVersion": Backend.consentVersion]
        if f.includeInfo { fields.merge(Backend.systemInfo) { a, _ in a } }
        f.sending = true; f.result = ""
        Backend.send(fields) { ok in
            f.sending = false
            if ok {
                f.ok = true; f.message = ""
                f.result = t("Sent. Thank you!", "Đã gửi. Cảm ơn bạn!") + (newsletter ? t(" You're on the newsletter list.", " Bạn đã có tên trong danh sách nhận bản tin.") : "")
                if newsletter { Invite.subscribed() }
            } else {
                f.ok = false
                // Keep the text so nothing is lost; the user can simply press Send again.
                f.result = t("Could not send right now. Check your connection and try again; your message is kept.",
                             "Chưa gửi được lúc này. Bạn kiểm tra mạng rồi bấm gửi lại nhé, nội dung vẫn được giữ nguyên.")
            }
        }
    }
}

/// Newsletter invitation shown after a successful cleanup.
struct InviteCard: View {
    let source: String
    @StateObject private var f = FormState()
    var body: some View {
        if !f.hidden {
            VStack(alignment: .leading, spacing: 10) {
                Text(t("Want monthly tips to keep your Mac lean?", "Nhận mẹo giữ máy gọn mỗi tháng?")).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Text(Backend.newsletterText).font(.system(size: 11)).foregroundColor(Theme.sub).fixedSize(horizontal: false, vertical: true)
                if f.ok {
                    Text(t("Thanks! You're on the list.", "Cảm ơn bạn! Đã đăng ký.")).foregroundColor(Theme.green).font(.system(size: 13, weight: .medium))
                } else {
                    HStack(spacing: 8) {
                        TextField("name@example.com", text: $f.email).textFieldStyle(.plain).foregroundColor(.white)
                            .onSubmit { join() }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.25)))
                        if f.sending { ProgressView().controlSize(.small).tint(.white) }
                        Button { join() } label: {
                            Text(t("Subscribe", "Nhận bản tin")).font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                                .padding(.horizontal, 16).padding(.vertical, 7).background(Capsule().fill(Theme.accent))
                        }.buttonStyle(.plain).hoverLift()
                    }
                    if !f.result.isEmpty { Text(f.result).font(.system(size: 11)).foregroundColor(Theme.warn) }
                    HStack(spacing: 14) {
                        Button(t("Later", "Để sau")) { Invite.later(); f.hidden = true }
                        Button(t("Don't ask again", "Không hỏi lại")) { Invite.never(); f.hidden = true }
                    }.buttonStyle(.plain).font(.system(size: 11)).foregroundColor(Theme.sub)
                }
            }
            .padding(16).background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
    }
    func join() {
        let email = f.email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Backend.validEmail(email) else { f.result = t("Please enter a valid email.", "Bạn nhập email hợp lệ giúp nhé."); return }
        UserDefaults.standard.set(email, forKey: "contactEmail")
        f.sending = true; f.result = ""
        var fields = ["source": source, "type": "newsletter", "email": email, "message": "", "newsletter": "yes",
                      "consent": Backend.newsletterText, "consentVersion": Backend.consentVersion]
        fields.merge(Backend.systemInfo) { a, _ in a }
        Backend.send(fields) { ok in
            f.sending = false
            if ok { f.ok = true; Invite.subscribed() }
            else { f.result = t("Could not sign up right now. Please try again later.", "Chưa đăng ký được lúc này. Bạn thử lại sau nhé.") }
        }
    }
}
