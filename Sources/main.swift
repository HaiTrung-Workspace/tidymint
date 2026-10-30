// Tidymint: a free, open-source disk cleaner for macOS, built for people who work with AI tools.
// "Keep your Mac in mint condition."
// Author: Tidymint contributors. License: MIT (see LICENSE). Provided "as is", without warranty.
// Safety rules: items are only moved to the Trash (the "Empty Trash" button asks first);
// cloud libraries, Photos, Mail, keychains, browser profiles and Apple system caches are never touched.
// Note: no @State anywhere (the @State macro needs an Xcode-only plugin); use Flag/ObservableObject instead.
import SwiftUI
import AppKit
import UserNotifications
import ServiceManagement
import CryptoKit
import QuickLookThumbnailing
import Vision
import PDFKit
import Charts
import ImageIO

// MARK: - Theme

/// Colour themes. Palettes are inspired by Apple's 2026 colours (approximate values, not official hex codes).
struct Palette {
    let id: String, nameEN: String, nameVI: String
    let bg: [UInt32]          // window gradient, top-left to bottom-right
    let accent: [UInt32]      // buttons, progress, selection
    let link: UInt32          // small text buttons
    let bubbles: [UInt32]     // Space Lens
    let icon: [UInt32]        // app icon background, top to bottom
    var leaf: UInt32 = 0x5ff0c0   // mint leaf on the app icon
    var light = false             // light background: text and overlays flip to dark ink
}

let palettes: [Palette] = [
    Palette(id: "mint", nameEN: "Mint", nameVI: "Mint (xanh bạc hà)",
            bg: [0x030c09, 0x061712, 0x0a2a21], accent: [0x2fd39f, 0x0f8f68], link: 0x7ef2c8,
            bubbles: [0x14a57a, 0x7ef2c8, 0x3ec7a0, 0xb8fbe3, 0x5fb4ff, 0xa3e48a, 0x2e8f74, 0xd6f5c9],
            icon: [0x0d2b24, 0x145c47, 0x1d7a5d], leaf: 0x5ff0c0),
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
    Palette(id: "starwhite", nameEN: "Star White", nameVI: "Star White (trắng ánh sao)",
            bg: [0xfafaf8, 0xeef0ee, 0xdfe4e1], accent: [0x0a7556, 0x086b4e], link: 0x086b4e,
            bubbles: [0x0f8f68, 0x2fd39f, 0x3b82f6, 0x8b5cf6, 0xf59e0b, 0x14b8a6, 0x6366f1, 0x84cc16],
            icon: [0xe9fbf3, 0xcdf1e2, 0xa8e3cd], leaf: 0x2fd39f, light: true),
]

/// Text size setting: Small / Default / Large (macOS wording). One multiplier applied to every font size in the app.
var appTextSize: String = ["small", "default", "large"].contains(UserDefaults.standard.string(forKey: "textSize") ?? "") ? UserDefaults.standard.string(forKey: "textSize")! : "default"
/// "Default" follows the Mac's own text size (System Settings > Accessibility > Display > Text size): body text is 13 pt
/// unless the user enlarged it there. Small and Large are 20% steps from that.
var systemTextScale: CGFloat { min(1.4, max(0.9, NSFont.preferredFont(forTextStyle: .body).pointSize / 13)) }
var uiScale: CGFloat { systemTextScale * (appTextSize == "small" ? 0.8 : (appTextSize == "large" ? 1.2 : 1.0)) }
func fs(_ v: CGFloat) -> CGFloat { v * uiScale }
/// Sponsor page on the website (not GitHub directly), so the destination can change without a new app release.
/// Sponsor page with UTM so GA4 can tell clicks from the app (place: "button" or "menubar").
func sponsorURL(_ place: String) -> URL {
    URL(string: t("https://tidymint.app/sponsor/", "https://tidymint.app/vi/ung-ho/") + "?utm_source=tidymint&utm_medium=app&utm_campaign=sponsor&utm_content=\(place)")!
}

var appTheme: String = UserDefaults.standard.string(forKey: "theme").flatMap { id in palettes.contains { $0.id == id } ? id : nil } ?? "mint"

enum Theme {
    static var p: Palette { palettes.first { $0.id == appTheme } ?? palettes[0] }
    static var bg: LinearGradient { LinearGradient(colors: p.bg.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing) }
    /// Text and overlay colour: white on dark themes, near-black on light ones.
    static var ink: Color { p.light ? Color(hex: 0x0b1f18) : .white }
    static var text: Color { ink }
    /// Dark overlay for bars and the sidebar (a light theme uses a soft grey instead of black).
    static var shade: Color { p.light ? Color(hex: 0x9aa39f) : .black }
    static var sidebar: Color { shade.opacity(p.light ? 0.16 : 0.22) }
    static var card: Color { ink.opacity(p.light ? 0.06 : 0.08) }
    static var cardHi: Color { ink.opacity(p.light ? 0.11 : 0.14) }
    static var accent: LinearGradient { LinearGradient(colors: p.accent.map { Color(hex: $0) }, startPoint: .leading, endPoint: .trailing) }
    static var accentSolid: Color { Color(hex: p.accent[p.accent.count - 1]) }
    static var link: Color { Color(hex: p.link) }
    /// Status colours: pastel on dark themes, deeper on light ones so they keep contrast on a pale background.
    static var green: Color { p.light ? Color(hex: 0x0a7556) : Color(hex: 0x6ee7a8) }
    static var warn: Color { p.light ? Color(hex: 0xa15c00) : Color(hex: 0xffc56b) }
    static var danger: Color { p.light ? Color(hex: 0xb91c1c) : Color(hex: 0xff6b6b) }
    static var sub: Color { ink.opacity(p.light ? 0.7 : 0.62) }
    /// "mint" in the wordmark: the leaf colour on dark themes, the (darker) link green on light ones so it stays readable.
    static var brandMint: Color { p.light ? link : Color(hex: p.leaf) }
    static var bubbles: [Color] { p.bubbles.map { Color(hex: $0) } }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }
}

func ago(_ d: Date) -> String {
    let m = Int(Date().timeIntervalSince(d) / 60)
    if m < 1 { return t("just now", "vừa xong") }
    if m < 60 { return t("\(m) min ago", "\(m) phút trước") }
    if m < 60 * 48 { return t("\(m / 60) h ago", "\(m / 60) giờ trước") }
    return t("\(m / 1440) days ago", "\(m / 1440) ngày trước")
}

/// Sizes in decimal units like Finder (1 GB = 1,000,000,000 bytes), one decimal at most, decimal comma in Vietnamese.
func fmt(_ b: Int64) -> String {
    let v = Double(max(b, 0)), k = 1000.0
    let (n, unit): (Double, String) = v >= k * k * k ? (v / (k * k * k), "GB") : (v >= k * k ? (v / (k * k), "MB") : (v / k, "KB"))
    var s = (n >= 100 || unit == "KB") ? String(format: "%.0f", n.rounded()) : String(format: "%.1f", n)
    if unit == "KB" && b > 0 && n < 1 { s = "1" }
    if s.hasSuffix(".0") { s.removeLast(2) }
    if appLang == "vi" { s = s.replacingOccurrences(of: ".", with: ",") }
    return s + " " + unit
}
/// "12 selected · 1.5 GB" for the action bar at the bottom of every list.
func selLabel(_ n: Int, _ size: Int64) -> String { n == 0 ? t("Nothing selected", "Chưa chọn mục nào") : t("\(n) selected · \(fmt(size))", "Đã chọn \(n) mục · \(fmt(size))") }

// MARK: - Language (VI/EN)

var appLang: String = UserDefaults.standard.string(forKey: "lang")
    ?? ((Locale.preferredLanguages.first ?? "en").hasPrefix("vi") ? "vi" : "en")
func t(_ en: String, _ vi: String) -> String { appLang == "vi" ? vi : en }
/// Date in the app language (e.g. "Sep 15, 2026" / "15 thg 9, 2026").
func shortDate(_ d: Date) -> String {
    let f = DateFormatter(); f.locale = Locale(identifier: appLang == "vi" ? "vi_VN" : "en_US"); f.dateStyle = .medium; f.timeStyle = .none
    return f.string(from: d)
}

/// Replacement for @State.
final class Flag: ObservableObject { @Published var v = false }

/// Tooltip drawn by the app itself. macOS help tags often never appear on SwiftUI views that also track the mouse
/// (hover tiles, cursors), so every tooltip in Tidymint uses this: a small bubble under the control after half a second.
final class TipState: ObservableObject {
    @Published var shown = false
    private var item: DispatchWorkItem?
    func hover(_ inside: Bool) {
        item?.cancel(); item = nil
        guard inside else { shown = false; return }
        let i = DispatchWorkItem { [weak self] in withAnimation(.easeOut(duration: 0.12)) { self?.shown = true } }
        item = i; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: i)
    }
}
struct Tip: ViewModifier {
    let text: String
    var trailing = false   // controls near the right edge: the bubble grows to the left so the window does not cut it
    @StateObject private var st = TipState()
    func body(content: Content) -> some View {
        content
            .onHover { st.hover($0 && !text.isEmpty) }
            .overlay(alignment: trailing ? .bottomTrailing : .bottom) {
                if st.shown {
                    Text(text).font(.system(size: fs(11))).foregroundColor(Color(nsColor: .labelColor))
                        .multilineTextAlignment(.leading).frame(maxWidth: 280, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .windowBackgroundColor)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                        .fixedSize()
                        .alignmentGuide(.bottom) { $0[.top] - 6 }
                        .allowsHitTesting(false).transition(.opacity)
                }
            }
            .zIndex(st.shown ? 100 : 0)
    }
}
extension View {
    func tip(_ text: String, trailing: Bool = false) -> some View { modifier(Tip(text: text, trailing: trailing)) }
}

/// macOS-style hover: soft highlight behind the row.
struct HoverBG: ViewModifier {
    var radius: CGFloat = 8
    var color: Color = Theme.ink.opacity(0.08)
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
/// Soft tile behind a small control on hover, hand cursor: shows it is clickable without a permanent border.
struct HoverTile: ViewModifier {
    var enabled = true
    @StateObject private var h = Flag()
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.text.opacity(h.v && enabled ? 0.12 : 0)))
            .contentShape(Rectangle())
            .onHover { v in
                withAnimation(.easeOut(duration: 0.12)) { h.v = v }
                if enabled { (v ? NSCursor.pointingHand : NSCursor.arrow).set() }
            }
    }
}
extension View { func hoverTile(_ enabled: Bool = true) -> some View { modifier(HoverTile(enabled: enabled)) } }
/// Icon-only buttons: the whole square takes the click (not only the icon's strokes), tile on hover, slight press.
struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { IconBody(configuration: configuration) }
    struct IconBody: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var enabled
        var body: some View {
            configuration.label
                .padding(.horizontal, 5).frame(minWidth: 26 * uiScale, minHeight: 24 * uiScale)
                .hoverTile(enabled)
                .scaleEffect(configuration.isPressed ? 0.92 : 1)
                .opacity(enabled ? 1 : 0.35)
        }
    }
}
extension ButtonStyle where Self == IconButtonStyle { static var icon: IconButtonStyle { IconButtonStyle() } }

/// Clickable text: link colour, underline + brighter + hand cursor on hover, so it reads as a link.
struct TextLink: View {
    let title: String
    var size: CGFloat = 12
    var weight: Font.Weight = .medium
    var color: Color = Theme.link
    let action: () -> Void
    @StateObject private var h = Flag()
    init(_ title: String, size: CGFloat = 12, weight: Font.Weight = .medium, color: Color = Theme.link, action: @escaping () -> Void) {
        self.title = title; self.size = size; self.weight = weight; self.color = color; self.action = action
    }
    init(_ title: String, url: URL, size: CGFloat = 12, weight: Font.Weight = .medium, color: Color = Theme.link) {
        self.init(title, size: size, weight: weight, color: color) { NSWorkspace.shared.open(url) }
    }
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: size, weight: weight)).foregroundColor(h.v ? Theme.text : color).underline(h.v)
        }.buttonStyle(.plain)
        .onHover { v in withAnimation(.easeOut(duration: 0.12)) { h.v = v }; if v { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
    }
}
/// Hover feedback for composite clickable text (brighten + hand cursor).
struct LinkHover: ViewModifier {
    @StateObject private var h = Flag()
    func body(content: Content) -> some View {
        content.brightness(h.v ? 0.15 : 0)
            .onHover { v in withAnimation(.easeOut(duration: 0.12)) { h.v = v }; if v { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
    }
}
extension View {
    func hoverBG(_ radius: CGFloat = 8, _ color: Color = Theme.ink.opacity(0.08)) -> some View { modifier(HoverBG(radius: radius, color: color)) }
    func hoverLift() -> some View { modifier(HoverLift()) }
    func linkHover() -> some View { modifier(LinkHover()) }
}

/// Menu bar popover row: system accent highlight with white text on hover, like a macOS menu.
struct MenuRow: View {
    let title: String
    var disabled = false
    let action: () -> Void
    @StateObject private var h = Flag()
    var body: some View {
        Button(action: action) {
            HStack { Text(title).font(.system(size: fs(13))); Spacer() }
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
    var nameMatch = false          // found by app name, not bundle id: could belong to something else
    var hasDB = false              // a database sits inside: may be the user's own data
    var note: String {
        if running { return t("App is open, quit it first", "App đang mở, tắt app rồi dọn") }
        if hasDB { return t("Has a database inside, may be your data", "Có database bên trong, có thể là dữ liệu của bạn") }
        if nameMatch { return t("Matched by name only, check first", "Khớp theo tên app, kiểm tra trước") }
        if !refStrong.isEmpty { return t("Used by \(refStrong.count) script/skill", "Script/skill đang dùng (\(refStrong.count))") }
        if !refWeak.isEmpty { return t("Mentioned in \(refWeak.count) notes", "Được nhắc trong \(refWeak.count) ghi chú") }
        return ""
    }
    var noteColor: Color { !refStrong.isEmpty || hasDB ? Theme.danger : Theme.warn }
    var refHelp: String { (refStrong + refWeak).map { $0.replacingOccurrences(of: NSHomeDirectory(), with: "~") }.joined(separator: "\n") }
    var date: Date? = nil
    var label: String? = nil       // friendlier name than the file name (e.g. "My iPhone · Oct 2, 2026")
    var name: String { label ?? url.lastPathComponent }
    var shortPath: String { url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
}

/// How safe it is to move a group of items to the Trash.
enum Safety: Int, Comparable {
    case safe = 0     // the app rebuilds it on its own: pre-selected
    case review       // user data or app state: the user ticks it
    case locked       // never offered (databases, messages, settings)
    static func < (a: Safety, b: Safety) -> Bool { a.rawValue < b.rawValue }
    var label: String {
        switch self {
        case .safe: return t("Safe", "An toàn")
        case .review: return t("You choose", "Bạn tự chọn")
        case .locked: return t("Locked", "Khoá")
        }
    }
    var color: Color { self == .safe ? Theme.green : (self == .review ? Theme.warn : Theme.danger) }
    var icon: String { self == .safe ? "checkmark.shield" : (self == .review ? "hand.raised" : "lock") }
}

struct Category: Identifiable {
    let id: String
    let titleEN: String, titleVI: String
    let icon: String
    let descEN: String, descVI: String
    var safety: Safety = .safe
    /// What happens after cleaning (shown on hover of the safety badge).
    var whyEN = "", whyVI = ""
    var title: String { t(titleEN, titleVI) }
    var desc: String { t(descEN, descVI) }
    var why: String { t(whyEN, whyVI) }
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

    /// Without Full Disk Access, touching the Photos or Music libraries makes macOS pop a permission dialog
    /// for each, even though the app only measures them. They are never cleaned, so in that case they are left out.
    static var limited = false
    static let libraries = ["Photos Library.photoslibrary", "/Pictures/Photos Library", "/Music/Music/", "/Music/iTunes/", ".musiclibrary"]
    static func isLibrary(_ p: String) -> Bool { limited && libraries.contains { p.contains($0) } }

    static func blocked(_ p: String) -> Bool { never.contains { p.contains($0) } }
    static func skip(_ p: String) -> Bool { blocked(p) || isLibrary(p) || IgnoreList.contains(p) }

    /// Chat and app databases with their journals. A folder holding one is never offered as a whole.
    static let dbExts: Set<String> = ["db", "sqlite", "sqlite3", "db-wal", "db-shm", "sqlite-wal", "sqlite-shm", "wal", "shm", "realm"]
    static func isDatabase(_ u: URL) -> Bool { dbExts.contains(u.pathExtension.lowercased()) }
    /// True when the item is a database file or a folder with a database among its direct children.
    static func holdsDatabase(_ u: URL) -> Bool {
        if isDatabase(u) { return true }
        return children(u, hidden: true).contains { isDatabase($0) }
    }

    /// Running state by bundle id (exact), the reliable way to tell "Zalo" from "Zalo Helper".
    static func running(_ bundleIDs: [String]) -> NSRunningApplication? {
        for b in bundleIDs { if let a = NSRunningApplication.runningApplications(withBundleIdentifier: b).first { return a } }
        return nil
    }
    static func quit(_ bundleIDs: [String]) { bundleIDs.forEach { NSRunningApplication.runningApplications(withBundleIdentifier: $0).forEach { $0.terminate() } } }

    /// Refuse paths that resolve outside the user's home (symlink escape), or that are too shallow to be junk.
    static func safeToTrash(_ u: URL) -> Bool {
        let real = u.resolvingSymlinksInPath().path
        let homeReal = home.resolvingSymlinksInPath().path
        guard real.hasPrefix(homeReal + "/") || real.hasPrefix("/Volumes/") else { return false }
        let depth = real.split(separator: "/").count
        return depth >= 3   // /Users/name/x is the shallowest thing allowed
    }

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

    static func scanJunk(step: (Int, String) -> Void = { _, _ in }) -> [Category] {
        step(0, "~/Library/Caches")
        let run = runningKeys()
        let AS = lib.appendingPathComponent("Application Support")
        let appRoots = [AS, lib.appendingPathComponent("Containers"), lib.appendingPathComponent("Group Containers")]
        var cats: [Category] = []

        cats.append(Category(id: "usercache", titleEN: "User Cache Files", titleVI: "Bộ nhớ đệm người dùng", icon: "internaldrive",
                             descEN: "Temporary files apps rebuild on their own", descVI: "File tạm, app tự tạo lại khi cần",
                             whyEN: "Apps rebuild these. The first launch after cleaning may be a little slower.", whyVI: "App tự tạo lại. Lần mở đầu sau khi dọn có thể chậm hơn một chút.",
                             items: make(children(lib.appendingPathComponent("Caches")), running: run)))

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
                             items: make(logs, running: run)))

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
                             items: make(findDirs(projects, names: ["_to_delete", "_to-delete", "_tmp"], depth: 5), running: run, minSize: 1)))

        step(5, "~/Downloads")
        let cutoff = Date().addingTimeInterval(-14 * 86400)
        let dls = children(home.appendingPathComponent("Downloads")).filter {
            ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()) < cutoff
        }
        cats.append(Category(id: "downloads", titleEN: "Old Downloads (14+ days)", titleVI: "Downloads cũ hơn 14 ngày", icon: "arrow.down.circle",
                             descEN: "Not selected by default. Review before removing", descVI: "Mặc định không tick, xem rồi chọn",
                             safety: .review, whyEN: "Files you downloaded. Once the Trash is emptied they are gone.", whyVI: "File bạn đã tải. Đổ Thùng rác rồi là mất.",
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

// MARK: - Clean by app (rules)

/// One group of paths inside an app's data, with its own safety level and a plain explanation.
struct AppSection {
    let id: String
    let titleEN: String, titleVI: String
    /// Home-relative templates. A single "*" component matches every child folder (accounts, profiles).
    let paths: [String]
    let safety: Safety
    let whyEN: String, whyVI: String
    /// Offer the files by month so old media can be cleaned first.
    var byAge = false
    /// Skip a matched folder entirely if a database file sits directly inside it.
    var dbGuard = true
    var title: String { t(titleEN, titleVI) }
    var why: String { t(whyEN, whyVI) }
}

struct AppRule: Identifiable {
    let id: String
    let nameEN: String, nameVI: String
    let bundleIDs: [String]
    /// Folder whose presence means the app has data on this Mac.
    let marker: String
    let sections: [AppSection]
    var name: String { t(nameEN, nameVI) }
}

enum AppRules {
    /// Expand a home-relative template, resolving one "*" level, to the folders that exist.
    static func expand(_ template: String) -> [URL] {
        let parts = template.split(separator: "/").map(String.init)
        var urls = [Scanner.home]
        for p in parts {
            var next: [URL] = []
            for u in urls {
                if p == "*" { next += Scanner.children(u, hidden: true).filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true } }
                else { let c = u.appendingPathComponent(p); if Scanner.fm.fileExists(atPath: c.path) { next.append(c) } }
            }
            urls = next
            if urls.isEmpty { return [] }
        }
        return urls
    }

    /// Items for one section: every matched folder, minus anything a database guard or the ignore list rejects.
    static func items(_ s: AppSection) -> [CleanItem] {
        var out: [CleanItem] = []
        for tpl in s.paths {
            for u in expand(tpl) where !Scanner.skip(u.path) {
                if s.dbGuard && Scanner.holdsDatabase(u) { continue }
                let size = Scanner.size(u)
                guard size > 0 else { continue }
                out.append(CleanItem(url: u, size: size, selected: s.safety == .safe))
            }
        }
        return out.sorted { $0.size > $1.size }
    }

    static func installed() -> [AppRule] { all.filter { Scanner.fm.fileExists(atPath: Scanner.home.appendingPathComponent($0.marker).path) } }

    // Rules below were measured on a real Mac (macOS 26, Oct 2026) unless marked "unverified".
    // Chromium browsers keep the HTTP cache under ~/Library/Caches/<vendor>/<profile> and the rest inside the profile.
    static func chromium(id: String, nameEN: String, nameVI: String, bundle: String, support: String, caches: String, aiModel: Bool = false) -> AppRule {
        var secs: [AppSection] = [
            AppSection(id: "cache", titleEN: "Browser cache", titleVI: "Bộ nhớ đệm trình duyệt",
                       paths: ["Library/Caches/\(caches)/*/Cache", "Library/Caches/\(caches)/*/Code Cache",
                               "Library/Application Support/\(support)/*/Cache", "Library/Application Support/\(support)/*/Code Cache",
                               "Library/Application Support/\(support)/*/GPUCache", "Library/Application Support/\(support)/*/DawnGraphiteCache",
                               "Library/Application Support/\(support)/*/DawnWebGPUCache", "Library/Application Support/\(support)/*/Service Worker/CacheStorage",
                               "Library/Application Support/\(support)/GrShaderCache", "Library/Application Support/\(support)/GraphiteDawnCache",
                               "Library/Application Support/\(support)/ShaderCache", "Library/Application Support/\(support)/component_crx_cache",
                               "Library/Application Support/\(support)/extensions_crx_cache", "Library/Application Support/\(support)/Crashpad/completed"],
                       safety: .safe,
                       whyEN: "Pages, scripts and images load from the network again. Logins, history and passwords are not touched.",
                       whyVI: "Trang web, script và ảnh sẽ tải lại từ mạng. Đăng nhập, lịch sử, mật khẩu không bị đụng.")]
        if aiModel {
            secs.append(AppSection(id: "ai", titleEN: "On-device AI models", titleVI: "Mô hình AI chạy tại máy",
                       paths: ["Library/Application Support/\(support)/OptGuideOnDeviceModel", "Library/Application Support/\(support)/OptGuideOnDeviceClassifierModel",
                               "Library/Application Support/\(support)/optimization_guide_model_store"],
                       safety: .review,
                       whyEN: "Models the browser downloaded for AI features (a few GB). It downloads them again when a feature needs them.",
                       whyVI: "Mô hình trình duyệt tải về cho tính năng AI (vài GB). Khi cần, trình duyệt sẽ tải lại."))
        }
        secs.append(AppSection(id: "profile", titleEN: "Logins, history, passwords", titleVI: "Đăng nhập, lịch sử, mật khẩu",
                       paths: ["Library/Application Support/\(support)/*/Cookies", "Library/Application Support/\(support)/*/History",
                               "Library/Application Support/\(support)/*/Login Data", "Library/Application Support/\(support)/*/Local Storage",
                               "Library/Application Support/\(support)/*/IndexedDB", "Library/Application Support/\(support)/*/Bookmarks"],
                       safety: .locked, whyEN: "Tidymint never touches these.", whyVI: "Tidymint không bao giờ đụng vào đây.", dbGuard: false))
        return AppRule(id: id, nameEN: nameEN, nameVI: nameVI, bundleIDs: [bundle], marker: "Library/Application Support/\(support)", sections: secs)
    }

    static let all: [AppRule] = [
        AppRule(id: "zalo", nameEN: "Zalo", nameVI: "Zalo", bundleIDs: ["com.vng.zalo"], marker: "Library/Application Support/ZaloData", sections: [
            AppSection(id: "cache", titleEN: "Cache, thumbnails, old installers", titleVI: "Bộ nhớ đệm, ảnh thu nhỏ, bản cài cũ",
                       paths: ["Library/Application Support/ZaloData/Cache", "Library/Application Support/ZaloData/Code Cache",
                               "Library/Application Support/ZaloData/GPUCache", "Library/Application Support/ZaloData/DawnCache",
                               "Library/Application Support/ZaloData/resp_cache", "Library/Application Support/ZaloData/media/temp",
                               "Library/Application Support/ZaloData/media/update",
                               "Library/Application Support/ZaloData/media/*/ZaloDownloads/Cache", "Library/Application Support/ZaloData/media/*/ZaloDownloads/fileThumb",
                               "Library/Application Support/ZaloData/media/*/ZaloDownloads/richThumb", "Library/Application Support/ZaloData/media/*/ZaloDownloads/sticker"],
                       safety: .safe,
                       whyEN: "Zalo rebuilds these on its own. The installer is re-downloaded at the next update.",
                       whyVI: "Zalo tự tạo lại. Bản cài sẽ tải lại khi có bản cập nhật mới."),
            AppSection(id: "picture", titleEN: "Photos in chats", titleVI: "Ảnh trong tin nhắn",
                       paths: ["Library/Application Support/ZaloData/media/*/ZaloDownloads/picture", "Library/Application Support/ZaloData/media/*/ZaloDownloads/resource"],
                       safety: .review,
                       whyEN: "Cleaning removes them from this Mac. Recent photos usually download again when you open the chat; old ones may be gone for good. Text messages are not affected.",
                       whyVI: "Dọn là mất trên máy này. Ảnh gần đây thường tải lại được khi mở lại cuộc trò chuyện, ảnh cũ có thể mất hẳn. Tin nhắn chữ không ảnh hưởng.",
                       byAge: true),
            AppSection(id: "video", titleEN: "Videos in chats", titleVI: "Video trong tin nhắn",
                       paths: ["Library/Application Support/ZaloData/media/*/ZaloDownloads/video"],
                       safety: .review,
                       whyEN: "May be gone for good on this Mac. Save the ones you want to keep first.",
                       whyVI: "Có thể mất hẳn trên máy này. Muốn giữ thì tải về trước.", byAge: true),
            AppSection(id: "file", titleEN: "Files and voice messages", titleVI: "File và tin nhắn thoại",
                       paths: ["Library/Application Support/ZaloData/media/*/ZaloDownloads/file", "Library/Application Support/ZaloData/media/*/ZaloDownloads/voice"],
                       safety: .review,
                       whyEN: "May be gone for good on this Mac. Save the ones you want to keep first.",
                       whyVI: "Có thể mất hẳn trên máy này. Muốn giữ thì tải về trước.", byAge: true),
            AppSection(id: "db", titleEN: "Messages", titleVI: "Tin nhắn",
                       paths: ["Library/Application Support/ZaloData/Database"],
                       safety: .locked, whyEN: "Your chat history. Tidymint never touches it.", whyVI: "Lịch sử trò chuyện. Tidymint không bao giờ đụng vào.", dbGuard: false),
        ]),
        chromium(id: "chrome", nameEN: "Google Chrome", nameVI: "Google Chrome", bundle: "com.google.Chrome", support: "Google/Chrome", caches: "Google/Chrome", aiModel: true),
        chromium(id: "edge", nameEN: "Microsoft Edge", nameVI: "Microsoft Edge", bundle: "com.microsoft.edgemac", support: "Microsoft Edge", caches: "Microsoft Edge", aiModel: true),
        // Unverified on a real Mac: folder names taken from the Chromium layout and public tooling that reads Cốc Cốc profiles.
        chromium(id: "coccoc", nameEN: "Cốc Cốc", nameVI: "Cốc Cốc", bundle: "com.coccoc.Coccoc", support: "Coccoc", caches: "Coccoc"),
        // Checked on a real Mac (App Store build, 10/2026): data in ~/Movies/CapCut/User Data, Settings > Draft and > Performance
        // offer their own delete buttons for Cache, rendering cache (prerender), proxies (agencycache) and remux files.
        // Other Cache subfolders can hold imported media, so they are left alone.
        AppRule(id: "capcut", nameEN: "CapCut", nameVI: "CapCut", bundleIDs: ["com.lemon.lvoverseas"], marker: "Movies/CapCut/User Data", sections: [
            AppSection(id: "cache", titleEN: "Scratch files", titleVI: "File tạm khi dựng video",
                       paths: ["recognize", "frameThumbnail", "audioWave", "AlgorithmCache", "ILASDKDB", "ttsTemp", "tmp"].map { "Movies/CapCut/User Data/Cache/\($0)" }
                              + ["Movies/CapCut/User Data/Log"],
                       safety: .safe,
                       whyEN: "Thumbnails, waveforms, analysis caches and logs. CapCut rebuilds them when you open a project.",
                       whyVI: "Ảnh thu nhỏ, sóng âm, dữ liệu phân tích, nhật ký. CapCut tự tạo lại khi mở dự án."),
            AppSection(id: "render", titleEN: "Rendering cache and proxies", titleVI: "Bản dựng sẵn và proxy",
                       paths: ["prerender", "agencycache", "RemuxCache"].map { "Movies/CapCut/User Data/Cache/\($0)" },
                       safety: .review,
                       whyEN: "Pre-rendered previews and low-res copies of your clips. CapCut makes them again, but previews may lag until it does. Same as the delete buttons in CapCut Settings > Performance.",
                       whyVI: "Bản dựng sẵn để xem trước và bản sao độ phân giải thấp của video. CapCut tạo lại, nhưng xem trước có thể giật cho tới khi tạo xong. Giống nút xoá trong Cài đặt › Performance của CapCut."),
            AppSection(id: "projects", titleEN: "Projects", titleVI: "Dự án",
                       paths: ["Movies/CapCut/User Data/Projects"],
                       safety: .locked, whyEN: "Your edits. Tidymint never touches them.", whyVI: "Dự án bạn đang dựng. Tidymint không bao giờ đụng vào.", dbGuard: false),
        ]),
        // Measured on a real Mac (App Store build, 10/2026): media cache in postbox/media, chat database in postbox/db.
        AppRule(id: "telegram", nameEN: "Telegram", nameVI: "Telegram", bundleIDs: ["ru.keepcoder.Telegram"],
                marker: "Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/stable", sections: [
            AppSection(id: "cache", titleEN: "Temporary files and logs", titleVI: "File tạm và nhật ký",
                       paths: ["Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/stable/temp",
                               "Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/stable/logs",
                               "Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/stable/trlottie-animations"],
                       safety: .safe, whyEN: "Telegram rebuilds these on its own.", whyVI: "Telegram tự tạo lại."),
            AppSection(id: "media", titleEN: "Photos, videos and files in chats", titleVI: "Ảnh, video, file trong tin nhắn",
                       paths: ["Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/stable/*/postbox/media"],
                       safety: .review,
                       whyEN: "Local copies of media you viewed. Telegram downloads them again from its servers when you open the chat. Messages are not affected.",
                       whyVI: "Bản lưu trên máy của ảnh, video đã xem. Mở lại cuộc trò chuyện Telegram sẽ tải lại từ máy chủ. Tin nhắn không ảnh hưởng.",
                       byAge: true),
            AppSection(id: "db", titleEN: "Messages and login", titleVI: "Tin nhắn và đăng nhập",
                       paths: ["Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/stable/*/postbox/db"],
                       safety: .locked, whyEN: "Your chat history. Tidymint never touches it.", whyVI: "Lịch sử trò chuyện. Tidymint không bao giờ đụng vào.", dbGuard: false),
        ]),
        AppRule(id: "whatsapp", nameEN: "WhatsApp", nameVI: "WhatsApp", bundleIDs: ["net.whatsapp.WhatsApp"],
                marker: "Library/Group Containers/group.net.whatsapp.WhatsApp.shared", sections: [
            AppSection(id: "cache", titleEN: "Cache", titleVI: "Bộ nhớ đệm",
                       paths: ["Library/Containers/net.whatsapp.WhatsApp/Data/Library/Caches"],
                       safety: .safe, whyEN: "WhatsApp rebuilds this on its own.", whyVI: "WhatsApp tự tạo lại."),
            AppSection(id: "media", titleEN: "Photos, videos and files in chats", titleVI: "Ảnh, video, file trong tin nhắn",
                       paths: ["Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Message/Media"],
                       safety: .review,
                       whyEN: "Cleaning removes them from this Mac. They stay on your phone if the chat is still there; otherwise they may be gone for good.",
                       whyVI: "Dọn là mất trên máy này. Còn trên điện thoại nếu cuộc trò chuyện còn, không thì có thể mất hẳn.",
                       byAge: true),
            AppSection(id: "db", titleEN: "Messages and login", titleVI: "Tin nhắn và đăng nhập",
                       paths: ["Library/Group Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite"],
                       safety: .locked, whyEN: "Your chat history. Tidymint never touches it.", whyVI: "Lịch sử trò chuyện. Tidymint không bao giờ đụng vào.", dbGuard: false),
        ]),
        AppRule(id: "slack", nameEN: "Slack", nameVI: "Slack", bundleIDs: ["com.tinyspeck.slackmacgap"],
                marker: "Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application Support/Slack", sections: [
            AppSection(id: "cache", titleEN: "Cache and logs", titleVI: "Bộ nhớ đệm và nhật ký",
                       paths: ["Cache", "Code Cache", "GPUCache", "GPUPersistentCache", "DawnGraphiteCache", "DawnWebGPUCache", "GraphiteDawnCache",
                               "Service Worker/CacheStorage", "logs", "Crashpad/completed"].map { "Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application Support/Slack/\($0)" },
                       safety: .safe,
                       whyEN: "Pages, images and scripts load again from Slack's servers. Logins and messages are not touched.",
                       whyVI: "Giao diện, ảnh, script sẽ tải lại từ máy chủ Slack. Đăng nhập và tin nhắn không bị đụng."),
            AppSection(id: "profile", titleEN: "Login and workspace data", titleVI: "Đăng nhập và dữ liệu workspace",
                       paths: ["IndexedDB", "Local Storage", "Cookies", "storage"].map { "Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application Support/Slack/\($0)" },
                       safety: .locked, whyEN: "Tidymint never touches these.", whyVI: "Tidymint không bao giờ đụng vào.", dbGuard: false),
        ]),
        AppRule(id: "vscode", nameEN: "Visual Studio Code", nameVI: "Visual Studio Code", bundleIDs: ["com.microsoft.VSCode"],
                marker: "Library/Application Support/Code", sections: [
            AppSection(id: "cache", titleEN: "Cache and logs", titleVI: "Bộ nhớ đệm và nhật ký",
                       paths: ["Cache", "CachedData", "CachedExtensionVSIXs", "CachedProfilesData", "Code Cache", "GPUCache", "DawnGraphiteCache", "DawnWebGPUCache", "logs", "Crashpad/completed"].map { "Library/Application Support/Code/\($0)" }
                              + ["Library/Caches/com.microsoft.VSCode"],
                       safety: .safe,
                       whyEN: "VS Code rebuilds these on next launch. Settings, extensions and projects are not touched.",
                       whyVI: "VS Code tự tạo lại khi mở. Cài đặt, tiện ích mở rộng, dự án không bị đụng."),
            AppSection(id: "agent", titleEN: "AI agent SDK cache", titleVI: "Bộ nhớ đệm SDK trợ lý AI",
                       paths: ["Library/Application Support/Code/agent-host/sdk-cache"],
                       safety: .review,
                       whyEN: "Downloaded by the built-in AI agent features. Re-downloaded when needed.",
                       whyVI: "Tính năng trợ lý AI tải về. Khi cần sẽ tải lại."),
            AppSection(id: "workspace", titleEN: "Per-project state", titleVI: "Trạng thái từng dự án",
                       paths: ["Library/Application Support/Code/User/workspaceStorage", "Library/Application Support/Code/User/History"],
                       safety: .review,
                       whyEN: "Open editors, unsaved-file history and extension state per project. Cleaning loses that memory, not your files.",
                       whyVI: "Tab đang mở, lịch sử file chưa lưu, trạng thái tiện ích của từng dự án. Dọn là mất phần ghi nhớ này, không mất file."),
            AppSection(id: "settings", titleEN: "Settings and extensions", titleVI: "Cài đặt và tiện ích mở rộng",
                       paths: ["Library/Application Support/Code/User/settings.json", "Library/Application Support/Code/User/globalStorage", ".vscode/extensions"],
                       safety: .locked, whyEN: "Tidymint never touches these.", whyVI: "Tidymint không bao giờ đụng vào.", dbGuard: false),
        ]),
        AppRule(id: "outlook", nameEN: "Microsoft Outlook", nameVI: "Microsoft Outlook", bundleIDs: ["com.microsoft.Outlook"],
                marker: "Library/Group Containers/UBF8T346G9.Office/Outlook", sections: [
            AppSection(id: "cache", titleEN: "Cache and logs", titleVI: "Bộ nhớ đệm và nhật ký",
                       paths: ["Library/Containers/com.microsoft.Outlook/Data/Library/Caches", "Library/Containers/com.microsoft.Outlook/Data/Library/Logs"],
                       safety: .safe, whyEN: "Outlook rebuilds these on its own.", whyVI: "Outlook tự tạo lại."),
            AppSection(id: "addins", titleEN: "Add-in packages", titleVI: "Gói tiện ích bổ sung",
                       paths: ["Library/Group Containers/UBF8T346G9.Office/SolutionPackages", "Library/Group Containers/UBF8T346G9.Office/Outlook/Outlook 15 Profiles/*/Osa"],
                       safety: .review,
                       whyEN: "Office add-ins downloaded for Outlook. They download again the next time an add-in is used.",
                       whyVI: "Tiện ích bổ sung Office tải về cho Outlook. Lần sau dùng tiện ích sẽ tải lại."),
            AppSection(id: "mail", titleEN: "Mail, attachments and accounts", titleVI: "Thư, tệp đính kèm, tài khoản",
                       paths: ["Library/Group Containers/UBF8T346G9.Office/Outlook/Outlook 15 Profiles"],
                       safety: .locked,
                       whyEN: "Your mailbox. Tidymint never touches it; to shrink it, use Outlook's own storage settings.",
                       whyVI: "Hộp thư của bạn. Tidymint không bao giờ đụng vào; muốn giảm thì dùng mục lưu trữ trong Outlook.", dbGuard: false),
        ]),
    ]
}

/// What the clean-by-app scan produces.
struct AppRow: Identifiable {
    let id: String
    let title: String, sub: String
    let size: Int64
    let count: Int
    let urls: [URL]
    let month: Date?          // for by-age rows: the first day of that month
    var selected: Bool
}
struct AppGroup: Identifiable {
    let id: String
    let section: AppSection
    var rows: [AppRow]
    var expanded = false
    var total: Int64 { rows.reduce(0) { $0 + $1.size } }
    var selected: Int64 { rows.filter(\.selected).reduce(0) { $0 + $1.size } }
    var state: Int { let n = rows.filter(\.selected).count; return n == 0 ? 0 : (n == rows.count ? 2 : 1) }
}
struct AppReport: Identifiable {
    let rule: AppRule
    var groups: [AppGroup]
    var running: Bool
    var id: String { rule.id }
    var total: Int64 { groups.reduce(0) { $0 + $1.total } }
    var cleanable: Int64 { groups.filter { $0.section.safety != .locked }.reduce(0) { $0 + $1.total } }
    var selected: Int64 { groups.reduce(0) { $0 + $1.selected } }
}

extension AppRules {
    static func monthStart(_ d: Date) -> Date {
        let c = Calendar.current
        return c.date(from: c.dateComponents([.year, .month], from: d)) ?? d
    }
    static func monthLabel(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: appLang == "vi" ? "vi_VN" : "en_US"); f.dateFormat = appLang == "vi" ? "'Tháng' M/yyyy" : "MMMM yyyy"
        return f.string(from: d)
    }

    /// Rows for one section: one per matched folder, or one per month when the section is split by age.
    static func rows(_ s: AppSection) -> [AppRow] {
        let home = Scanner.home.path + "/"
        func short(_ u: URL) -> String { u.path.hasPrefix(home) ? "~/" + u.path.dropFirst(home.count) : u.path }
        if !s.byAge {
            return items(s).map { AppRow(id: $0.url.path, title: $0.name, sub: short($0.url), size: $0.size, count: 1, urls: [$0.url], month: nil, selected: $0.selected) }
        }
        var bucket: [Date: (size: Int64, urls: [URL])] = [:]
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey, .contentModificationDateKey]
        for tpl in s.paths {
            for folder in expand(tpl) where !Scanner.skip(folder.path) {
                if s.dbGuard && Scanner.holdsDatabase(folder) { continue }
                guard let en = Scanner.fm.enumerator(at: folder, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, _ in true }) else { continue }
                for case let f as URL in en {
                    guard let v = try? f.resourceValues(forKeys: keys), v.isRegularFile == true, !Scanner.isDatabase(f) else { continue }
                    let m = monthStart(v.contentModificationDate ?? Date())
                    bucket[m, default: (0, [])].size += Int64(v.totalFileAllocatedSize ?? 0)
                    bucket[m, default: (0, [])].urls.append(f)
                }
            }
        }
        return bucket.keys.sorted(by: >).map { m in
            let b = bucket[m]!
            return AppRow(id: s.id + "|" + ISO8601DateFormatter().string(from: m), title: monthLabel(m),
                          sub: t("\(b.urls.count) files", "\(b.urls.count) file"), size: b.size, count: b.urls.count, urls: b.urls, month: m, selected: false)
        }.filter { $0.size > 0 }
    }

    static func scan() -> [AppReport] {
        installed().compactMap { rule in
            let groups = rule.sections.map { AppGroup(id: $0.id, section: $0, rows: rows($0)) }.filter { !$0.rows.isEmpty }
            guard groups.contains(where: { $0.section.safety != .locked }) else { return nil }
            return AppReport(rule: rule, groups: groups, running: Scanner.running(rule.bundleIDs) != nil)
        }
    }
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
        let col = n.otherCount > 0 ? Theme.ink.opacity(0.35) : Theme.bubbles[i % Theme.bubbles.count]
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

/// Space Lens bubble in the "glass bubble" style of CleanMyMac's Space Lens: a translucent fill, a brighter rim that
/// fades toward the centre, a thin light outline and a soft coloured glow. No specular highlight, no drop shadow.
struct Sphere: View {
    let color: Color; let r: CGFloat; var hot = false
    static func mix(_ c: Color, _ other: NSColor, _ f: CGFloat) -> Color {
        Color(NSColor(c).usingColorSpace(.sRGB)?.blended(withFraction: f, of: other) ?? NSColor(c))
    }
    var body: some View {
        let edge = Sphere.mix(color, .white, 0.2)
        ZStack {
            // One continuous radial gradient: darkest in the centre, getting lighter towards the edge with no hard step.
            let k: Double = hot ? 1.25 : 1
            Circle().fill(RadialGradient(gradient: Gradient(stops: [
                .init(color: color.opacity(0.14 * k), location: 0.0),
                .init(color: color.opacity(0.18 * k), location: 0.45),
                .init(color: color.opacity(0.28 * k), location: 0.72),
                .init(color: color.opacity(0.42 * k), location: 0.90),
                .init(color: edge.opacity(0.55 * k), location: 1.0)]),
                center: .center, startRadius: 0, endRadius: r))
            Circle().fill(LinearGradient(colors: [Theme.ink.opacity(0.06), Theme.ink.opacity(0)], startPoint: .top, endPoint: .center))
            Circle().strokeBorder(edge.opacity(hot ? 0.55 : 0.32), lineWidth: 0.75)
        }
        .shadow(color: color.opacity(hot ? 0.5 : 0.3), radius: max(3, r * 0.12))
    }
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

    /// Folder names shared by many apps of one vendor, or too generic to prove ownership. Never offered by name.
    static let sharedNames: Set<String> = ["google", "microsoft", "adobe", "jetbrains", "mozilla", "apple", "logs", "cache", "caches", "data", "app", "application support"]

    /// Files that belong to an app. Bundle-id matches are pre-selected; name matches are listed but left for the user,
    /// and anything holding a database is never pre-selected (the data-loss pattern behind most cleaner complaints).
    static func related(_ a: AppEntry) -> [CleanItem] {
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
        byID += Scanner.children(L.appendingPathComponent("Group Containers")).filter { $0.lastPathComponent.hasSuffix(id) }
        byID += Scanner.children(L.appendingPathComponent("LaunchAgents")).filter { $0.lastPathComponent.hasPrefix(id) }
        var byName: [URL] = []
        if n.count >= 4 && !sharedNames.contains(n.lowercased()) {
            byName = ["Application Support", "Caches", "Logs"].map { L.appendingPathComponent("\($0)/\(n)") }
        }
        var seen = Set<String>(), out: [CleanItem] = []
        for (list, weak) in [(byID, false), (byName, true)] {
            for u in list where FileManager.default.fileExists(atPath: u.path) && !seen.contains(u.path) && !Scanner.blocked(u.path) {
                seen.insert(u.path)
                let db = Scanner.holdsDatabase(u)
                var it = CleanItem(url: u, size: Cloud.localSize(u.path), selected: !weak && !db)
                it.nameMatch = weak; it.hasDB = db
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
                if isProtected(id) || id.contains(".apple.") || shared.contains(where: { id.hasPrefix($0) }) || installed.contains(id) || vendors.contains(vendor) { continue }
                if NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil { continue }
                if Scanner.skip(u.path) { continue }
                let s = Cloud.localSize(u.path)
                guard s > 0 else { continue }
                let db = Scanner.holdsDatabase(u)
                var it = CleanItem(url: u, size: s, selected: !db); it.hasDB = db
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
    case smart = "Smart Scan", cleanup = "Cleanup", byapp = "Clean by App", large = "Large & Old Files", lens = "Space Lens", trash = "Trash", ignore = "Ignore List", cloud = "Cloud Cleanup", settings = "Settings", apps = "Uninstaller", dupes = "Duplicates", startup = "Startup", stats = "Stats", contact = "Contact", organize = "Organize"
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
        case .organize: return t("Organize", "Sắp xếp thư mục")
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
        case .organize: return "folder.badge.gearshape"
        }
    }
}

enum Phase { case idle, scanning, summary, review, done }

@MainActor final class VM: ObservableObject {
    @Published var page: Page = .smart {
        didSet {
            if VM.advancedPages.contains(page), !advancedOpen { advancedOpen = true }
            fresh.remove(page)
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
        case .organize: return sharedOrg.phase == .scanning
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
        appTextSize = v; UserDefaults.standard.set(v, forKey: "textSize"); textSize = v
        theme = appTheme   // the root view is keyed on this; re-assigning rebuilds every view with the new sizes
    }
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
            await MainActor.run { self.apps = a; self.leftovers = l; self.installers = i; self.appsBusy = false; self.markDone(.apps) }
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
                    self.finished(.apps, ok + 1, total, 0)
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
        dupBusy = true; dupMsg = ""; dupCount = 0; dupes = []
        if doneInfo?.page == .dupes { doneInfo = nil }
        Task.detached {
            let g = Dupes.scan { n in DispatchQueue.main.async { self.dupCount = n } }
            await MainActor.run { self.dupes = g; self.dupBusy = false; self.markDone(.dupes) }
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
        launchMsg = ""
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
            await MainActor.run { self.clouds = res.sorted { $0.local > $1.local }; self.cloudBusy = false; self.markDone(.cloud) }
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
        if freeGB > 0 { DiskHistory.record(freeGB) }
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
        phase = .scanning; scanStep = 0; scanDetail = ""
        let cb = stepCallback()
        Task.detached {
            let r = Scanner.scanJunk(step: cb)
            await MainActor.run { self.cats = r; self.phase = thenReview ? .review : .summary; self.markDone(.cleanup) }
        }
    }

    func scanLarge() {
        if doneInfo?.page == .large { doneInfo = nil }
        largePhase = .scanning
        Task.detached {
            let r = Scanner.scanLarge()
            await MainActor.run { self.large = r; self.largePhase = .review; self.markDone(.large) }
        }
    }

    func smartScan() {
        phase = .scanning; largePhase = .scanning; scanStep = 0; scanDetail = ""
        refreshTrash(); refreshDisk()
        let cb = stepCallback()
        Task.detached {
            let j = Scanner.scanJunk(step: cb)
            cb(6, "~/Documents, Downloads, Desktop, Movies, Music, Pictures")
            let l = Scanner.scanLarge()
            await MainActor.run { self.cats = j; self.large = l; self.phase = .summary; self.largePhase = .review; self.markDone(.smart) }
        }
    }

    @Published var lastFreed: Int64 = 0
    @Published var lastCount = 0
    struct DoneInfo { let page: Page; let count: Int; let size: Int64; let fail: Int }
    @Published var doneInfo: DoneInfo? = nil
    func finished(_ p: Page, _ count: Int, _ size: Int64, _ fail: Int) { doneInfo = count > 0 ? DoneInfo(page: p, count: count, size: size, fail: fail) : nil }
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
    func openSys() { if doneInfo?.page == .lens { doneInfo = nil }; sysOpen = true; if sysParts.isEmpty { scanSys() } }
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
        let (ok, fail) = trash(picked.map(\.url), label: "sysdata")
        let freed = okSize(picked)
        log("System Data: moved \(ok) items (\(fmt(freed))) to Trash")
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
        log("Space Lens: moved \(ok) items (\(fmt(freed))) to Trash"); _ = size
        finished(.lens, ok, freed, fail)
        refreshTrash(); refreshDisk()
    }
    // Uninstaller filters
    @Published var appsFilter = 0   // 0 all, 1 not opened in 6 months, 2 over 500 MB, 3 App Store, 4 other sources
    @Published var appsSort = 0     // 0 size, 1 name, 2 last opened
    static func fromAppStore(_ u: URL) -> Bool { FileManager.default.fileExists(atPath: u.appendingPathComponent("Contents/_MASReceipt/receipt").path) }
    func appsMatching(_ f: Int) -> [AppEntry] {
        let old = Date().addingTimeInterval(-182 * 86400)
        switch f {
        case 1: return apps.filter { ($0.lastUsed ?? .distantPast) < old }
        case 2: return apps.filter { $0.size >= 500_000_000 }
        case 3: return apps.filter { VM.fromAppStore($0.url) }
        case 4: return apps.filter { !VM.fromAppStore($0.url) }
        default: return apps
        }
    }
    var appsShown: [AppEntry] {
        let a = appsMatching(appsFilter)
        switch appsSort {
        case 1: return a.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case 2: return a.sorted { ($0.lastUsed ?? .distantPast) < ($1.lastUsed ?? .distantPast) }
        default: return a.sorted { $0.size > $1.size }
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
    @Published var undoable: Journal.Session? = Journal.load()
    /// Move items to the Trash and remember where each one went, so the whole run can be undone.
    /// `strict` refuses paths outside the home folder or too close to its root (off only for a folder the user picked by hand).
    func trash(_ urls: [URL], label: String = "", strict: Bool = true) -> (Int, Int) {
        var ok = 0, fail = 0
        lastOK = []; lastErr = ""
        var moved: [Journal.Entry] = []
        for u in urls {
            if strict && !Scanner.safeToTrash(u) {
                fail += 1
                if lastErr.isEmpty { lastErr = t("refused, path is outside the safe area", "từ chối, đường dẫn nằm ngoài vùng an toàn") }
                continue
            }
            let size = Scanner.size(u)
            var dest: NSURL?
            do { try FileManager.default.trashItem(at: u, resultingItemURL: &dest); ok += 1; lastOK.insert(u)
                 if let d = dest as URL? { moved.append(Journal.Entry(from: u.path, to: d.path, size: size)) } }
            catch {
                // iCloud Drive file: the standard Trash refused, move it into ~/.Trash directly
                if FileManager.default.fileExists(atPath: u.path), let d = try? moveToUserTrash(u) {
                    ok += 1; lastOK.insert(u)
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
                }
            }
        }
        if !lastErr.isEmpty { log("ERROR trash: \(lastErr)") }
        if !moved.isEmpty { undoable = Journal.save(Journal.Session(date: Date(), label: label, entries: moved)) }
        return (ok, fail)
    }

    /// Put everything from the last run back where it was (only items still sitting in the Trash).
    func undoLast() {
        guard let s = undoable else { return }
        guard confirm(t("Undo the last clean?", "Hoàn tác lần dọn vừa rồi?"),
                      t("\(s.entries.count) items (\(fmt(s.size))) go back to where they were.", "\(s.entries.count) mục (\(fmt(s.size))) sẽ trở về chỗ cũ."),
                      t("Put Back", "Trả về chỗ cũ")) else { return }
        let r = Journal.restore(s)
        lastResult = t("Put back \(r.ok) items.", "Đã trả về \(r.ok) mục.") + (r.skipped > 0 ? t(" \(r.skipped) were already gone or replaced.", " \(r.skipped) mục đã mất hoặc đã có file mới ở chỗ cũ.") : "")
        log("Undo: put back \(r.ok) items, skipped \(r.skipped)")
        undoable = nil; Journal.clear()
        refreshTrash(); refreshDisk()
    }
    func okSize(_ items: [CleanItem]) -> Int64 { items.filter { lastOK.contains($0.url) }.reduce(0) { $0 + $1.size } }
    var failNote: String { lastErr.isEmpty ? "" : t(" Reason: ", " Lý do: ") + lastErr }

    func cleanJunk() {
        let sel = cats.flatMap { $0.items.filter(\.selected) }
        let size = sel.reduce(0) { $0 + $1.size }
        let (ok, fail) = trash(sel.map(\.url), label: "cleanup"); _ = size
        lastFreed = okSize(sel); lastCount = ok
        lastResult = t("Moved \(ok) items (\(fmt(okSize(sel)))) to the Trash.", "Đã chuyển \(ok) mục (\(fmt(okSize(sel)))) vào Thùng rác.") + (fail > 0 ? t(" Skipped \(fail) items.", " Bỏ qua \(fail) mục.") + failNote : "")
        log(lastResult)
        phase = .done
        refreshTrash(); refreshDisk()
    }

    func cleanLarge() {
        let sel = large.filter(\.selected)
        let size = sel.reduce(0) { $0 + $1.size }
        let (ok, fail) = trash(sel.map(\.url), label: "large"); _ = size
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
    func scanByApp() {
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
        for k in appReports[i].groups[j].rows.indices { appReports[i].groups[j].rows[k].selected = on }
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
        appReports[i].groups[j].rows[k].selected.toggle()
    }
    func cleanApp(_ id: String) {
        guard let i = appReports.firstIndex(where: { $0.id == id }) else { return }
        let r = appReports[i]
        refreshAppRunning()
        if appReports[i].running {
            _ = confirm(t("Quit \(r.rule.name) first", "Tắt \(r.rule.name) trước"), t("The app is open and may be writing these files. Quit it, then clean.", "App đang mở, có thể đang ghi vào các file này. Tắt app rồi dọn."), "OK"); return
        }
        let rows = r.groups.filter { $0.section.safety != .locked }.flatMap { $0.rows.filter(\.selected) }
        let urls = rows.flatMap(\.urls)
        let size = rows.reduce(0) { $0 + $1.size }
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
                if let f = fresh { self.appReports[i] = f } else { self.appReports.remove(at: i); self.appSel = nil }
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
    func rescanLens() { if let u = lensPath.last { sizeCache = sizeCache.filter { !$0.key.hasPrefix(u.path) } }; loadLens() }
    func trashNode(_ n: Node) {
        guard confirm(t("Move to Trash?", "Chuyển vào Thùng rác?"), "\(n.name), \(fmt(n.size))", t("Move to Trash", "Chuyển vào Thùng rác")) else { return }
        let (ok, fail) = trash([n.url], label: "lens", strict: false)
        if ok > 0 { lensNodes.removeAll { $0.id == n.id }; lensSel.remove(n.url); sizeCache.removeValue(forKey: n.url.path); log("Space Lens: moved \(n.url.path) (\(fmt(n.size))) to Trash") }
        finished(.lens, ok, ok > 0 ? n.size : 0, fail)
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

/// Code-signing state of the program a launch item starts. Facts from codesign/spctl, no verdict.
enum SignState {
    case unknown, apple, developer(String), adhoc, unsigned, invalid, script, empty
    var label: String {
        switch self {
        case .unknown: return ""
        case .empty: return t("Empty, does nothing", "Rỗng, không làm gì")
        case .apple: return "Apple"
        case .developer(let n): return n
        case .adhoc: return t("Ad-hoc signed", "Ký tạm")
        case .unsigned: return t("Unsigned", "Chưa ký")
        case .invalid: return t("Signature invalid or revoked", "Chữ ký hỏng hoặc bị thu hồi")
        case .script: return t("Script", "Script")
        }
    }
    var color: Color {
        switch self {
        case .unknown, .apple, .adhoc, .script, .empty: return Theme.sub
        case .developer: return Theme.green
        case .unsigned: return Theme.warn
        case .invalid: return Theme.danger
        }
    }
    var help: String {
        switch self {
        case .apple: return t("Signed by Apple.", "Do Apple ký.")
        case .developer: return t("Signed with an Apple Developer ID. The maker is known.", "Ký bằng Developer ID của Apple. Biết được hãng làm ra.")
        case .adhoc: return t("Signed without a registered identity. Common for tools from Homebrew or built locally; fine if you installed it yourself.", "Ký không có danh tính đăng ký. Thường gặp ở tool cài qua Homebrew hoặc tự build; ổn nếu bạn tự cài.")
        case .unsigned: return t("No signature, so the maker cannot be confirmed. Check that it belongs to software you know.", "Không có chữ ký nên không xác nhận được ai làm ra. Kiểm tra xem nó thuộc phần mềm bạn biết không.")
        case .invalid: return t("The signature does not verify, or Apple revoked the certificate. Apple revokes certificates when it finds a problem.", "Chữ ký không khớp, hoặc Apple đã thu hồi chứng chỉ. Apple thu hồi khi phát hiện có vấn đề.")
        case .script: return t("Starts a script. Scripts cannot be signed, so make sure it belongs to software you know.", "Khởi động một script. Script không ký được, hãy chắc nó thuộc phần mềm bạn biết.")
        case .empty: return t("The file names no program, so it starts nothing. Usually left behind by an updater that removed itself. Safe to remove.", "File không ghi chương trình nào nên không khởi động gì. Thường là vỏ còn lại của trình cập nhật đã tự gỡ. Gỡ được.")
        case .unknown: return ""
        }
    }
}

/// Structural red flags, the patterns adware uses to persist. Each one is "worth a look", never "malware".
enum LaunchFlag: Hashable {
    case fakeApple, hiddenDir, tempDir, randomName, inlineScript
    var label: String {
        switch self {
        case .fakeApple: return t("Looks like an Apple name", "Tên giống của Apple")
        case .hiddenDir: return t("In a hidden folder", "Nằm trong thư mục ẩn")
        case .tempDir: return t("In a temp or shared folder", "Nằm trong thư mục tạm")
        case .randomName: return t("Random-looking name", "Tên như chuỗi ngẫu nhiên")
        case .inlineScript: return t("Runs a shell command", "Chạy thẳng lệnh shell")
        }
    }
    var help: String {
        switch self {
        case .fakeApple: return t("The label starts with com.apple but the program is not in an Apple system folder. Apple never installs items here.", "Nhãn bắt đầu bằng com.apple nhưng chương trình không nằm trong thư mục hệ thống của Apple. Apple không bao giờ cài mục ở đây.")
        case .hiddenDir: return t("Normal software does not hide its program in a dot-folder.", "Phần mềm bình thường không giấu chương trình trong thư mục có dấu chấm.")
        case .tempDir: return t("Anything can write to temp and shared folders; normal software does not run from there at startup.", "Ai cũng ghi được vào thư mục tạm và thư mục chia sẻ; phần mềm bình thường không khởi động từ đó.")
        case .randomName: return t("Generated-looking names are a common way to avoid being recognised.", "Tên sinh ngẫu nhiên là cách phổ biến để tránh bị nhận ra.")
        case .inlineScript: return t("Runs a command through a shell instead of an app, so there is nothing to sign.", "Chạy lệnh qua shell thay vì mở app, nên không có gì để ký.")
        }
    }
}

struct LaunchEntry: Identifiable {
    let id = UUID()
    let url: URL
    let label: String
    let program: String
    let scope: Int          // 0: this user (~/Library), 1: all users agent, 2: all users daemon (needs admin)
    let running: Bool?
    let orphan: Bool
    var sign: SignState = .unknown
    var flags: [LaunchFlag] = []
    var attention: Bool {
        if case .invalid = sign { return true }
        return !flags.isEmpty
    }
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

    static func run(_ exe: String, _ args: [String]) -> (Int32, String) {
        let p = Process(); p.executableURL = URL(fileURLWithPath: exe); p.arguments = args
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        do { try p.run() } catch { return (-1, "") }
        let d = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        return (p.terminationStatus, String(data: d, encoding: .utf8) ?? "")
    }

    static let interpreters: Set<String> = ["sh", "bash", "zsh", "python", "python3", "perl", "ruby", "osascript", "node"]

    /// The thing to check with codesign: the .app bundle when the program sits inside one, else the program itself.
    static func signTarget(_ program: String) -> String {
        if let r = program.range(of: ".app/") { return String(program[..<r.upperBound].dropLast()) }
        return program
    }

    /// Signature state and red flags for one item. Facts only; runs codesign and spctl, so call it off the main thread.
    static func inspect(_ e: LaunchEntry) -> (SignState, [LaunchFlag]) {
        var flags: [LaunchFlag] = []
        let d = NSDictionary(contentsOf: e.url) as? [String: Any] ?? [:]
        let args = d["ProgramArguments"] as? [String] ?? []
        let prog = e.program
        let exeName = (prog as NSString).lastPathComponent
        let isInterp = interpreters.contains(exeName)
        if isInterp && args.contains("-c") { flags.append(.inlineScript) }
        let appleDirs = ["/System/", "/usr/", "/bin/", "/sbin/", "/Library/Apple/", "/Applications/Safari.app", "/Applications/Xcode.app"]
        if e.label.hasPrefix("com.apple."), !prog.isEmpty, !appleDirs.contains(where: { prog.hasPrefix($0) }) { flags.append(.fakeApple) }
        let comps = prog.split(separator: "/").map(String.init)
        if comps.dropLast().contains(where: { $0.hasPrefix(".") }) { flags.append(.hiddenDir) }
        for tmp in ["/tmp/", "/private/tmp/", "/var/folders/", "/private/var/folders/", "/Users/Shared/", "/private/var/tmp/"] where prog.hasPrefix(tmp) { flags.append(.tempDir); break }
        let last = e.label.split(separator: ".").last.map(String.init) ?? e.label
        let lettersDigits = last.filter { $0.isLetter || $0.isNumber }
        if lettersDigits.count >= 14, last.contains(where: { $0.isNumber }), !last.contains("-"), last.lowercased() == last, Set(last).count > 8 {
            flags.append(.randomName)
        }
        // Signature
        var sign: SignState = .unknown
        let scriptExts: Set<String> = ["sh", "py", "rb", "pl", "scpt", "applescript", "js", "command"]
        let target = isInterp ? (args.dropFirst().first { !$0.hasPrefix("-") } ?? prog) : signTarget(prog)
        if prog.isEmpty && args.isEmpty {
            sign = .empty
        } else if isInterp || scriptExts.contains((target as NSString).pathExtension.lowercased()) {
            sign = .script
        } else if !prog.isEmpty, FileManager.default.fileExists(atPath: target) {
            let (code, out) = run("/usr/bin/codesign", ["-dv", "--verbose=2", target])
            if code != 0 && out.contains("not signed") { sign = .unsigned }
            else if code != 0 { sign = .invalid }
            else if out.contains("Signature=adhoc") { sign = .adhoc }
            else if out.contains("Authority=Software Signing") && out.contains("Authority=Apple Root CA") && !out.contains("Developer ID") { sign = .apple }
            else if let line = out.split(separator: "\n").first(where: { $0.hasPrefix("Authority=Developer ID Application:") || $0.hasPrefix("Authority=Apple Development:") || $0.hasPrefix("Authority=Apple Distribution:") }) {
                var n = String(line.split(separator: ":", maxSplits: 1).last ?? "").trimmingCharacters(in: .whitespaces)
                if let p = n.range(of: " (") { n = String(n[..<p.lowerBound]) }
                sign = .developer(n)
            } else if out.contains("Authority=Apple Mac OS Application Signing") || out.contains("Authority=Apple Worldwide Developer Relations") { sign = .developer(t("App Store app", "App từ App Store")) }
            else { sign = .developer(t("Signed", "Có ký")) }
            // A signed program that verifies but Gatekeeper rejects usually means a revoked certificate.
            if case .developer = sign {
                let (vc, _) = run("/usr/bin/codesign", ["-v", target])
                if vc != 0 { sign = .invalid }
                else {
                    let (_, so) = run("/usr/sbin/spctl", ["-a", "-t", "exec", "-vv", target])
                    if so.contains("rejected") && (so.contains("revoked") || so.contains("CSSMERR_TP_CERT_REVOKED")) { sign = .invalid }
                }
            }
        }
        return (sign, flags)
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
        "LM Studio": ("LM Studio AI models. Manage them inside the app.", "Model AI của LM Studio. Quản lý trong app."),
        "CapCut": ("CapCut data. Clear caches in CapCut Settings; never delete Projects.", "Dữ liệu CapCut. Xoá bộ nhớ đệm trong Cài đặt của CapCut, đừng xoá Projects."),
        "com.lveditor.draft": ("CapCut projects. Do not delete here; remove old projects inside CapCut.", "Dự án CapCut. Đừng xoá ở đây, xoá dự án cũ ngay trong CapCut."),
        "prerender": ("Rendering cache (CapCut). Clear in CapCut Settings > Performance.", "Bản dựng sẵn của CapCut. Xoá trong Cài đặt › Performance của CapCut."),
        "agencycache": ("Proxy copies of your clips (CapCut). Clear in CapCut Settings > Performance.", "Bản proxy video của CapCut. Xoá trong Cài đặt › Performance của CapCut."),
        "Homebrew": ("Homebrew downloads. Run 'brew cleanup' to clear what is no longer needed.", "File tải của Homebrew. Chạy 'brew cleanup' để dọn phần không cần."),
        "com.docker.docker": ("Docker data. Shrink it with 'docker system prune'; don't delete files by hand.", "Dữ liệu Docker. Thu gọn bằng 'docker system prune', đừng xoá tay."),
        "Docker.raw": ("Docker's disk image. Shrink it with 'docker system prune'; deleting it wipes all containers and images.", "Ổ đĩa ảo của Docker. Thu gọn bằng 'docker system prune'; xoá file này là mất hết container và image.")
    ]
    if p.hasSuffix("/Developer/Xcode/Archives") {
        return t("Xcode archives. Keep the ones you shipped: you need them to read crash reports.", "Bản archive Xcode. Giữ các bản đã phát hành: cần để đọc báo cáo lỗi.")
    }
    if let v = m[n] {
        if Scanner.limited && (n == "Pictures" || n == "Music") {
            return t(v.0, v.1) + t(" Library not counted: needs Full Disk Access.", " Chưa tính thư viện: cần quyền Truy cập toàn bộ ổ đĩa.")
        }
        return t(v.0, v.1)
    }
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
    static let dir = NSHomeDirectory() + "/Library/Application Support/Tidymint"
    static let oldDir = NSHomeDirectory() + "/Library/Application Support/Disk Cleanup"   // name before the rename
    static var path: String {
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir) && fm.fileExists(atPath: oldDir) { try? fm.moveItem(atPath: oldDir, toPath: dir) }
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
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

/// Free space once per day (the last reading of the day), kept on this Mac for the Statistics chart. Nothing is sent anywhere.
enum DiskHistory {
    static var path: String { Stats.dir + "/disk-history.json" }
    static let key: DateFormatter = { let d = DateFormatter(); d.dateFormat = "yyyy-MM-dd"; d.locale = Locale(identifier: "en_US_POSIX"); return d }()
    static func load() -> [String: Double] {
        guard let d = FileManager.default.contents(atPath: path), let m = try? JSONDecoder().decode([String: Double].self, from: d) else { return [:] }
        return m
    }
    static func record(_ gb: Double) {
        var m = load()
        m[key.string(from: Date())] = (gb * 10).rounded() / 10
        if m.count > 400 { for k in m.keys.sorted().prefix(m.count - 400) { m.removeValue(forKey: k) } }
        _ = Stats.path
        if let d = try? JSONEncoder().encode(m) { try? d.write(to: URL(fileURLWithPath: path)) }
    }
    struct Day: Identifiable { let date: Date; let free: Double; let freed: Int64; var id: Date { date } }
    /// One point per day for the last `days` days: the daily record, or the last value from the activity log for days before it existed.
    static func series(days: Int, log: [LogEntry]) -> [Day] {
        let cal = Calendar.current
        var free: [String: Double] = [:]
        var cleaned: [String: Int64] = [:]
        for e in log {   // the log is in time order, so the last reading of each day wins
            let k = key.string(from: e.date)
            if let f = e.freeGB { free[k] = f }
            cleaned[k, default: 0] += e.freed
        }
        for (k, v) in load() { free[k] = v }   // the daily record is preferred where it exists
        let today = cal.startOfDay(for: Date())
        return (0..<days).reversed().compactMap { back in
            guard let d = cal.date(byAdding: .day, value: -back, to: today) else { return nil }
            let k = key.string(from: d)
            guard let f = free[k] else { return nil }
            return Day(date: d, free: f, freed: cleaned[k] ?? 0)
        }
    }
}

final class RangePick: ObservableObject { @Published var days = 30; @Published var sel: Date? = nil }

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
        for e in s.entries {
            guard fm.fileExists(atPath: e.to), !fm.fileExists(atPath: e.from) else { skipped += 1; continue }
            try? fm.createDirectory(atPath: (e.from as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            do { try fm.moveItem(atPath: e.to, toPath: e.from); ok += 1 } catch { skipped += 1 }
        }
        return (ok, skipped)
    }
}

// MARK: - Components

struct SafetyBadge: View {
    let level: Safety; var why = ""
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: level.icon).font(.system(size: fs(9), weight: .bold))
            Text(level.label).font(.system(size: fs(10), weight: .semibold))
        }
        .foregroundColor(level.color).padding(.horizontal, 7).padding(.vertical, 2)
        .background(Capsule().fill(level.color.opacity(0.15)))
        .tip(why)
    }
}

struct CheckBox: View {
    let state: Int
    var body: some View {
        Image(systemName: state == 2 ? "checkmark.square.fill" : (state == 1 ? "minus.square.fill" : "square"))
            .font(.system(size: fs(17), weight: .medium))
            .foregroundStyle(state == 0 ? AnyShapeStyle(Theme.ink.opacity(0.5)) : AnyShapeStyle(Theme.accent))
            // The whole square takes the click, not only the outline; hand cursor, no hover colour (lists stay calm).
            .contentShape(Rectangle())
            .onHover { ($0 ? NSCursor.pointingHand : NSCursor.arrow).set() }
    }
}

// Pill buttons share one size (14 pt text, 22/10 padding) so primary and ghost line up side by side.
// `width` fixes the pill width for places where several buttons sit in a column (Settings rows).
enum Pill { static var font: Font { Font.system(size: fs(14), weight: .semibold) }; static let padH: CGFloat = 22; static let padV: CGFloat = 10; static var rowWidth: CGFloat { 150 * max(uiScale, 1) + (uiScale > 1 ? 12 : 0) } }   // never narrower than at default size, so labels fit at Small

struct PrimaryButton: View {
    let title: String; let action: () -> Void
    var disabled = false
    var width: CGFloat? = nil
    var body: some View {
        Button(action: action) {
            Text(title).font(Pill.font).foregroundColor(.white).lineLimit(1)
                .frame(width: width.map { $0 - 2 * Pill.padH })
                .padding(.horizontal, Pill.padH).padding(.vertical, Pill.padV)
                .background(Capsule().fill(Theme.accent)).opacity(disabled ? 0.4 : 1)
                .shadow(color: Theme.accentSolid.opacity(0.4), radius: 12, y: 4)
        }.buttonStyle(.plain).disabled(disabled).hoverLift()
    }
}

struct GhostButton: View {
    let title: String; let action: () -> Void
    var width: CGFloat? = nil
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: fs(14), weight: .medium)).foregroundColor(Theme.text).lineLimit(1)
                .frame(width: width.map { $0 - 2 * Pill.padH })
                .padding(.horizontal, Pill.padH).padding(.vertical, Pill.padV)
                .background(Capsule().stroke(Theme.ink.opacity(0.35), lineWidth: 1))
                .hoverBG(20, Theme.ink.opacity(0.1))
        }.buttonStyle(.plain).hoverLift()
    }
}

struct BigScanButton: View {
    let label: String; let action: () -> Void
    @StateObject private var pulse = Flag()   // hover
    @StateObject private var breath = Flag()  // slow idle breathing, off when Reduce Motion is on
    var body: some View {
        let still = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        Button(action: action) {
            ZStack {
                Circle().fill(Theme.accent.opacity(breath.v ? 0.30 : 0.18)).frame(width: 190, height: 190)
                    .scaleEffect(pulse.v ? 1.08 : (breath.v ? 1.05 : 0.97))
                Circle().fill(Theme.accent).frame(width: 150, height: 150)
                    .shadow(color: Theme.accentSolid.opacity(breath.v || pulse.v ? 0.6 : 0.35), radius: breath.v ? 30 : 20)
                Text(label).font(.system(size: fs(22), weight: .bold)).foregroundColor(.white)
            }
        }.buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.25)) { pulse.v = h } }
        // Breathe three times after the page appears, then rest. A forever animation kept the CPU at ~10% even with the
        // window closed, so the cue is finite: finished animations cost nothing.
        .task {
            guard !still else { return }
            for _ in 0..<3 {
                withAnimation(.easeInOut(duration: 2.4)) { breath.v = true }
                try? await Task.sleep(nanoseconds: 2_400_000_000)
                withAnimation(.easeInOut(duration: 2.4)) { breath.v = false }
                try? await Task.sleep(nanoseconds: 2_400_000_000)
            }
        }
    }
}

struct Header: View {
    let title: String; let sub: String
    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: fs(28), weight: .bold)).foregroundColor(Theme.text)
            Text(sub).font(.system(size: fs(14))).foregroundColor(Theme.sub).multilineTextAlignment(.center)
        }
    }
}

struct Scanning: View {
    let text: String
    var body: some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large).tint(Theme.text)
            Text(text).foregroundColor(Theme.sub)
        }
    }
}

/// Real thumbnail for photos and videos (Quick Look), the Finder icon for everything else. Cached per path.
final class ThumbStore: ObservableObject {
    @Published var image: NSImage?
    static let cache = NSCache<NSString, NSImage>()
    static let media: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "tif", "bmp", "raw", "dng", "cr2", "nef", "arw",
                                     "psd", "mov", "mp4", "m4v", "avi", "mkv", "webm", "pdf"]
    func load(_ url: URL, side: CGFloat) {
        let key = url.path as NSString
        if let c = ThumbStore.cache.object(forKey: key) { image = c; return }
        image = NSWorkspace.shared.icon(forFile: url.path)
        guard ThumbStore.media.contains(url.pathExtension.lowercased()), FileManager.default.fileExists(atPath: url.path) else { return }
        let req = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: side, height: side),
                                               scale: NSScreen.main?.backingScaleFactor ?? 2, representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { rep, _ in
            guard let img = rep?.nsImage else { return }
            ThumbStore.cache.setObject(img, forKey: key)
            DispatchQueue.main.async { self.image = img }
        }
    }
}

struct FileThumb: View {
    let url: URL; var side: CGFloat = 22
    @StateObject private var store = ThumbStore()
    var body: some View {
        Group {
            if let img = store.image {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
            } else { Color.clear }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .onAppear { store.load(url, side: side) }
    }
}

struct ItemRow: View {
    @Binding var item: CleanItem
    let vm: VM
    var showDate = false
    var body: some View {
        HStack(spacing: 12) {
            Button { item.selected.toggle() } label: { CheckBox(state: item.selected ? 2 : 0) }.buttonStyle(.plain)
            FileThumb(url: item.url, side: 26 * uiScale)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).foregroundColor(Theme.text).font(.system(size: fs(14))).lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.shortPath).foregroundColor(Theme.sub).font(.system(size: fs(11))).lineLimit(1).truncationMode(.middle)
                    if !item.note.isEmpty {
                        Text(item.note).font(.system(size: fs(10), weight: .semibold)).foregroundColor(item.noteColor)
                            .padding(.horizontal, 6).padding(.vertical, 1).background(Capsule().fill(item.noteColor.opacity(0.15)))
                            .tip(item.refHelp)
                    }
                }
            }
            Spacer()
            if showDate, let d = item.date {
                Text(t("Last opened ", "Mở lần cuối ") + shortDate(d)).foregroundColor(Theme.sub).font(.system(size: fs(11)))
            }
            Text(fmt(item.size)).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .medium).monospacedDigit()).frame(width: 80 * uiScale, alignment: .trailing)
        }
        .padding(.vertical, 9).padding(.horizontal, 12)
        .hoverBG(8, Theme.ink.opacity(0.07))
        .contentShape(Rectangle())
        .contextMenu {
            Button(t("Reveal in Finder", "Mở trong Finder")) { vm.reveal(item.url) }
            Button(item.selected ? t("Deselect", "Bỏ chọn") : t("Select", "Chọn")) { item.selected.toggle() }
            Divider()
            Button(t("Ignore (don't show again)", "Bỏ qua (không hiện lại)")) { let u = item.url; DispatchQueue.main.async { vm.ignore(u) } }
        }
    }
}

/// Shown at the top of a list page right after a clean: how much got tidier, Undo, and the way to the Trash.
struct DoneBanner: View {
    @ObservedObject var vm: VM
    let page: Page
    var body: some View {
        if let d = vm.doneInfo, d.page == page {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: fs(30))).foregroundColor(Theme.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text(d.size > 0 ? t("\(fmt(d.size)) tidier", "Gọn thêm \(fmt(d.size))") : t("Done", "Xong"))
                        .font(.system(size: fs(20), weight: .bold)).foregroundColor(Theme.text)
                    Text(t("\(d.count) items moved to the Trash. Empty the Trash to free the space for real.",
                           "\(d.count) mục đã vào Thùng rác. Đổ Thùng rác thì ổ mới trống thật.") + (d.fail > 0 ? t(" \(d.fail) skipped.", " Bỏ qua \(d.fail) mục.") : ""))
                        .font(.system(size: fs(12))).foregroundColor(Theme.sub).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if vm.undoable != nil { GhostButton(title: t("Undo", "Hoàn tác")) { vm.undoFromBanner() } }
                GhostButton(title: t("Open Trash", "Xem Thùng rác")) { vm.doneInfo = nil; vm.page = .trash }
                Button { vm.doneInfo = nil } label: { Image(systemName: "xmark").font(.system(size: fs(12), weight: .semibold)) }
                    .buttonStyle(.icon).foregroundColor(Theme.sub).tip(t("Close", "Đóng"), trailing: true)
            }
            .padding(16).background(RoundedRectangle(cornerRadius: 14).fill(Theme.green.opacity(0.12)))
            .padding(.horizontal, 24).padding(.bottom, 10)
        }
    }
}

/// Scan progress: the steps of the scan, ticked one by one, plus what is being read right now.
struct ScanSteps: View {
    let title: String, steps: [String], current: Int
    var detail = ""
    var body: some View {
        VStack(spacing: 18) {
            Text(title).font(.system(size: fs(24), weight: .bold)).foregroundColor(Theme.text)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                    HStack(spacing: 10) {
                        Group {
                            if i < current { Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.green) }
                            else if i == current { ProgressView().controlSize(.small).tint(Theme.text) }
                            else { Image(systemName: "circle").foregroundColor(Theme.sub.opacity(0.6)) }
                        }.frame(width: 18)
                        Text(s).font(.system(size: fs(14), weight: i == current ? .semibold : .regular))
                            .foregroundColor(i <= current ? Theme.text : Theme.sub)
                    }
                }
            }.padding(20).frame(width: 340 * uiScale, alignment: .leading).background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
            Text(detail).font(.system(size: fs(11))).foregroundColor(Theme.sub).lineLimit(1).truncationMode(.middle).frame(maxWidth: 420)
        }
    }
}

/// One group of the Clean Now result: big size, what it is, who decides. Tapping opens the full list at that group.
struct JunkCard: View {
    let cat: Category; let action: () -> Void
    @StateObject private var hover = Flag()
    var body: some View {
        let picked = cat.selectedSize > 0
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: cat.icon).font(.system(size: fs(17))).foregroundStyle(Theme.accent)
                        .frame(width: 34, height: 34).background(Circle().fill(Theme.accent.opacity(0.14)))
                    Spacer()
                    SafetyBadge(level: cat.safety, why: cat.why)
                }
                Text(fmt(picked ? cat.selectedSize : cat.total)).font(.system(size: fs(24), weight: .bold).monospacedDigit()).foregroundColor(Theme.text)
                Text(cat.title).font(.system(size: fs(14), weight: .semibold)).foregroundColor(Theme.text).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text(cat.desc).font(.system(size: fs(12))).foregroundColor(Theme.sub).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text(picked ? t("Selected · Review", "Đã chọn · Xem") : t("Not selected · Review", "Chưa chọn · Xem"))
                    .font(.system(size: fs(12), weight: .semibold)).foregroundColor(picked ? Theme.text : Theme.sub)
            }
            .padding(16).frame(maxWidth: .infinity, minHeight: 168 * uiScale, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 16).fill(hover.v ? Theme.cardHi : Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.accentSolid.opacity(picked ? 0.35 : 0), lineWidth: 1))
        }.buttonStyle(.plain).onHover { hover.v = $0 }
    }
}

// MARK: - System Data explainer (inside Space Lens)

/// One piece of what macOS lumps into "System Data", with what can be done about it.
struct SysPart: Identifiable {
    enum Kind { case clean, elsewhere, system }
    enum Action { case none, url(URL), page(Page) }
    let id: String
    let icon: String
    let title: String
    let note: String
    var size: Int64              // -1 = macOS does not report it
    var kind: Kind
    var items: [CleanItem] = []
    var detail = ""
    var actionTitle = ""
    var action: Action = .none
    var selectedSize: Int64 { items.filter(\.selected).reduce(0) { $0 + $1.size } }
    var state: Int { let n = items.filter(\.selected).count; return n == 0 ? 0 : (n == items.count ? 2 : 1) }
}

enum SysData {
    static let fm = FileManager.default
    static var lib: URL { Scanner.lib }
    static func dir(_ rel: String) -> URL { lib.appendingPathComponent(rel) }
    static func sz(_ u: URL) -> Int64 { fm.fileExists(atPath: u.path) ? Scanner.size(u) : 0 }
    static func modDate(_ u: URL) -> Date? { try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }

    static func item(_ u: URL, on: Bool, label: String? = nil, minSize: Int64 = 1_000_000) -> CleanItem? {
        guard !Scanner.skip(u.path) else { return nil }
        let s = Scanner.size(u)
        guard s >= minSize else { return nil }
        var it = CleanItem(url: u, size: s, selected: on)
        it.label = label
        return it
    }

    /// Time Machine snapshots kept on the startup disk ("com.apple.TimeMachine.2026-10-28-101500.local").
    static func snapshots() -> [String] {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil"); p.arguments = ["listlocalsnapshots", "/"]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return [] }
        let d = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        return String(decoding: d, as: UTF8.self).split(separator: "\n").map(String.init).filter { $0.contains("com.apple.TimeMachine.") }
    }
    static func snapshotDate(_ s: String) -> Date? {
        guard let r = s.range(of: #"\d{4}-\d{2}-\d{2}-\d{6}"#, options: .regularExpression) else { return nil }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd-HHmmss"
        return f.date(from: String(s[r]))
    }

    /// Space macOS counts as free for big jobs (updates, installs) but is still held by purgeable data such as snapshots.
    static func purgeable() -> Int64 {
        let v = try? Scanner.home.resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        let important = Int64(v?.volumeAvailableCapacityForImportantUsage ?? 0), plain = Int64(v?.volumeAvailableCapacity ?? 0)
        return max(0, important - plain)
    }

    static func scan() -> ([SysPart], Int64) {
        var clean: [SysPart] = [], other: [SysPart] = []

        // iPhone / iPad backups made through Finder
        let bk = dir("Application Support/MobileSync/Backup")
        let backups: [CleanItem] = Scanner.children(bk).compactMap { d in
            let info = NSDictionary(contentsOf: d.appendingPathComponent("Info.plist"))
            let name = (info?["Device Name"] as? String) ?? (info?["Display Name"] as? String) ?? d.lastPathComponent
            let date = (info?["Last Backup Date"] as? Date) ?? modDate(d)
            return item(d, on: false, label: name + (date.map { " · " + shortDate($0) } ?? ""))
        }.sorted { $0.size > $1.size }
        if !backups.isEmpty {
            clean.append(SysPart(id: "backups", icon: "iphone", title: t("iPhone and iPad backups", "Bản sao lưu iPhone, iPad"),
                                 note: t("Made by Finder when the phone was plugged in. Keep the newest one of each device you still use; old devices and old copies can go.",
                                         "Finder tạo khi cắm điện thoại vào máy. Giữ bản mới nhất của máy còn dùng; máy cũ và bản cũ thì bỏ được."),
                                 size: backups.reduce(0) { $0 + $1.size }, kind: .clean, items: backups))
        }

        // iOS update files (downloaded again when needed)
        let ipsw: [CleanItem] = ["iTunes/iPhone Software Updates", "iTunes/iPad Software Updates", "iTunes/iPod Software Updates"].flatMap { r in
            Scanner.children(dir(r)).filter { $0.pathExtension.lowercased() == "ipsw" }.compactMap { item($0, on: true) }
        }
        if !ipsw.isEmpty {
            clean.append(SysPart(id: "ipsw", icon: "arrow.down.circle", title: t("iOS update files", "File cập nhật iOS"),
                                 note: t("Firmware downloaded to update or restore a device. Downloaded again when needed.", "Bản cài iOS tải về để cập nhật hay khôi phục máy. Cần thì tải lại."),
                                 size: ipsw.reduce(0) { $0 + $1.size }, kind: .clean, items: ipsw))
        }

        // Xcode leftovers
        var xc: [CleanItem] = []
        if let i = item(dir("Developer/Xcode/DerivedData"), on: false, label: t("Build files (DerivedData)", "File build (DerivedData)")) { xc.append(i) }
        if let i = item(dir("Developer/CoreSimulator/Caches"), on: true, label: t("Simulator caches", "Bộ nhớ đệm máy ảo")) { xc.append(i) }
        for r in ["iOS DeviceSupport", "watchOS DeviceSupport", "tvOS DeviceSupport", "visionOS DeviceSupport"] {
            xc += Scanner.children(dir("Developer/Xcode/" + r)).compactMap { item($0, on: false, label: r.replacingOccurrences(of: "DeviceSupport", with: "") + $0.lastPathComponent) }
        }
        xc += Scanner.children(dir("Developer/Xcode/Archives")).compactMap { item($0, on: false, label: t("Archive ", "Bản lưu trữ ") + $0.lastPathComponent) }
        if !xc.isEmpty {
            clean.append(SysPart(id: "xcode", icon: "hammer", title: t("Xcode leftovers", "Rác của Xcode"),
                                 note: t("Build files rebuild on their own. Device support files are fetched again when a device is plugged in. Archives are builds you shipped: keep the ones you still need.",
                                         "File build tự tạo lại. File hỗ trợ thiết bị tải lại khi cắm máy. Bản lưu trữ là bản build đã nộp: giữ bản còn cần."),
                                 size: xc.reduce(0) { $0 + $1.size }, kind: .clean, items: xc.sorted { $0.size > $1.size }))
        }

        // Things that are cleaned elsewhere
        let cache = sz(dir("Caches")) + sz(dir("Logs"))
        if cache >= 50_000_000 {
            other.append(SysPart(id: "caches", icon: "internaldrive", title: t("Caches and logs", "Bộ nhớ đệm và nhật ký"),
                                 note: t("Part of System Data too. Clean them on the Clean Now page, where each item says what happens after.",
                                         "Cũng nằm trong System Data. Dọn ở trang Dọn ngay, mỗi mục ghi rõ dọn xong thì sao."),
                                 size: cache, kind: .elsewhere, actionTitle: Page.smart.label, action: .page(.smart)))
        }
        let sims = sz(dir("Developer/CoreSimulator/Devices"))
        if sims >= 50_000_000 {
            other.append(SysPart(id: "sims", icon: "ipad.and.iphone", title: t("iPhone simulators", "Máy ảo iPhone"),
                                 note: t("Delete old ones in Xcode: Window > Devices and Simulators. Removing the folder by hand confuses Xcode.",
                                         "Xoá máy ảo cũ trong Xcode: Window > Devices and Simulators. Xoá tay thư mục sẽ làm Xcode lỗi."),
                                 size: sims, kind: .elsewhere))
        }
        let docker = sz(dir("Containers/com.docker.docker/Data/vms"))
        if docker >= 50_000_000 {
            other.append(SysPart(id: "docker", icon: "shippingbox", title: t("Docker disk", "Ổ ảo của Docker"),
                                 note: t("One big file holding every image and container. Shrink it from Docker Desktop (Troubleshoot > Clean / Purge data) or with docker system prune.",
                                         "Một file lớn chứa mọi image, container. Thu nhỏ trong Docker Desktop (Troubleshoot > Clean / Purge data) hoặc lệnh docker system prune."),
                                 size: docker, kind: .elsewhere))
        }
        let msg = sz(dir("Messages/Attachments"))
        if msg >= 50_000_000 {
            other.append(SysPart(id: "messages", icon: "message", title: t("Messages attachments", "Ảnh, file trong Tin nhắn"),
                                 note: t("Photos and files from iMessage chats. Remove them in Messages (Settings > General > Keep messages) so the chats stay intact.",
                                         "Ảnh, file trong các cuộc trò chuyện iMessage. Xoá trong app Tin nhắn (Cài đặt > Chung > Giữ tin nhắn) để cuộc trò chuyện không bị hỏng."),
                                 size: msg, kind: .elsewhere))
        }

        // Things macOS manages itself
        let snaps = snapshots()
        let tmURL = URL(string: "x-apple.systempreferences:com.apple.Time-Machine-Settings.extension")!
        let last = snaps.compactMap(snapshotDate).max()
        other.append(SysPart(id: "snapshots", icon: "clock.arrow.circlepath", title: t("Time Machine snapshots on this Mac", "Bản sao lưu Time Machine nằm trên máy"),
                             note: snaps.isEmpty
                                ? t("None right now. When Time Machine is on and the backup disk is not plugged in, macOS keeps hourly snapshots here and removes them by itself.",
                                    "Hiện không có. Khi bật Time Machine mà không cắm ổ sao lưu, macOS giữ bản sao lưu theo giờ ở đây và tự xoá.")
                                : t("Kept when Time Machine runs without the backup disk. macOS removes them after about a day, or sooner when it needs space. Tidymint leaves them alone: deleting one is permanent and cannot go to the Trash.",
                                    "Có khi Time Machine chạy mà chưa cắm ổ sao lưu. macOS tự xoá sau khoảng một ngày, hoặc sớm hơn khi cần chỗ. Tidymint không xoá phần này: xoá là mất hẳn, không vào Thùng rác được."),
                             size: -1, kind: snaps.isEmpty ? .system : .elsewhere,
                             detail: snaps.isEmpty ? "" : t("\(snaps.count) snapshots", "\(snaps.count) bản") + (last.map { t(", newest ", ", mới nhất ") + shortDate($0) } ?? ""),
                             actionTitle: t("Time Machine Settings", "Mở cài đặt Time Machine"), action: .url(tmURL)))

        var vm: Int64 = 0
        for u in Scanner.children(URL(fileURLWithPath: "/private/var/vm"), hidden: true) {
            vm += Int64((try? u.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize) ?? 0)
        }
        if vm > 0 {
            other.append(SysPart(id: "vm", icon: "memorychip", title: t("Swap and sleep files", "Bộ nhớ ảo và file ngủ"),
                                 note: t("Used when memory runs short and when the Mac sleeps. macOS creates and removes them; a restart usually shrinks them. Do not delete.",
                                         "Dùng khi thiếu RAM và khi máy ngủ. macOS tự tạo, tự xoá; khởi động lại máy thường nhỏ đi. Không nên xoá."),
                                 size: vm, kind: .system))
        }
        return (clean.sorted { $0.size > $1.size } + other, purgeable())
    }
}

final class OpenSet: ObservableObject { @Published var v = Set<String>() }

struct SysPartCard: View {
    @Binding var part: SysPart
    @ObservedObject var vm: VM
    @ObservedObject var open: OpenSet
    var badge: (String, Color) {
        switch part.kind {
        case .clean: return (t("Can clean here", "Dọn được ở đây"), Theme.green)
        case .elsewhere: return (t("Handled elsewhere", "Dọn ở chỗ khác"), Theme.warn)
        case .system: return (t("Leave to macOS", "Để macOS lo"), Theme.sub)
        }
    }
    var body: some View {
        let isOpen = open.v.contains(part.id)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                if part.kind == .clean {
                    Button { let on = part.state != 2; for i in part.items.indices { part.items[i].selected = on } } label: { CheckBox(state: part.state) }
                        .buttonStyle(.plain).padding(.top, 8)
                }
                Image(systemName: part.icon).font(.system(size: fs(15))).foregroundStyle(Theme.accent)
                    .frame(width: 32, height: 32).background(Circle().fill(Theme.accent.opacity(0.14)))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(part.title).font(.system(size: fs(14), weight: .semibold)).foregroundColor(Theme.text)
                        Text(badge.0).font(.system(size: fs(10), weight: .semibold)).foregroundColor(badge.1)
                            .padding(.horizontal, 7).padding(.vertical, 2).background(Capsule().fill(badge.1.opacity(0.15)))
                    }
                    Text(part.note).font(.system(size: fs(12))).foregroundColor(Theme.sub).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 14) {
                        if part.kind == .clean {
                            TextLink(isOpen ? t("Hide items", "Ẩn danh sách") : t("Show \(part.items.count) items", "Xem \(part.items.count) mục"), size: fs(12), weight: .semibold) {
                                if isOpen { open.v.remove(part.id) } else { open.v.insert(part.id) }
                            }
                        }
                        if !part.actionTitle.isEmpty {
                            TextLink(part.actionTitle, size: fs(12), weight: .semibold) {
                                switch part.action {
                                case .url(let u): NSWorkspace.shared.open(u)
                                case .page(let p): vm.page = p
                                case .none: break
                                }
                            }
                        }
                    }.padding(.top, 2)
                }
                Spacer(minLength: 8)
                if part.size >= 0 || !part.detail.isEmpty { VStack(alignment: .trailing, spacing: 2) {
                    Text(part.size < 0 ? part.detail : fmt(part.size))
                        .font(.system(size: fs(part.size < 0 ? 13 : 17), weight: .bold).monospacedDigit()).foregroundColor(Theme.text)
                    if part.size < 0 && !part.detail.isEmpty {
                        Text(t("size not reported by macOS", "macOS không báo dung lượng")).font(.system(size: fs(10))).foregroundColor(Theme.sub)
                    }
                } }
            }.padding(14)
            if isOpen && part.kind == .clean {
                VStack(spacing: 2) {
                    ForEach($part.items) { $it in ItemRow(item: $it, vm: vm) }
                }.padding(.horizontal, 8).padding(.bottom, 8)
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
    }
}

struct SysDataView: View {
    @ObservedObject var vm: VM
    @StateObject private var open = OpenSet()
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { vm.sysOpen = false } label: { Image(systemName: "chevron.left") }.buttonStyle(.icon).foregroundColor(Theme.text).tip(t("Back", "Lùi"))
                Text(t("What is in System Data", "System Data gồm những gì")).font(.system(size: fs(20), weight: .bold)).foregroundColor(Theme.text)
                Spacer()
                if !vm.sysBusy { TextLink(t("Scan again", "Quét lại"), size: fs(12), weight: .semibold, color: Theme.text) { vm.scanSys() } }
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 6)
            Text(t("macOS puts everything it cannot file under Apps, Documents or Photos into System Data. These are the parts Tidymint can measure: the ones with a checkbox can be cleaned here, the rest say where to handle them or to leave them alone.",
                   "macOS gom mọi thứ không xếp được vào Ứng dụng, Tài liệu, Ảnh vào System Data. Đây là những phần Tidymint đo được: phần có ô chọn thì dọn được ở đây, phần còn lại ghi rõ dọn ở đâu hoặc nên để yên."))
                .font(.system(size: fs(12))).foregroundColor(Theme.sub).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.bottom, 12)
            DoneBanner(vm: vm, page: .lens)
            if vm.sysBusy && vm.sysParts.isEmpty {
                Scanning(text: t("Looking inside System Data...", "Đang xem System Data gồm những gì...")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        if vm.sysPurgeable >= 1_000_000_000 {
                            HStack(spacing: 10) {
                                Image(systemName: "info.circle").foregroundColor(Theme.link)
                                Text(t("About \(fmt(vm.sysPurgeable)) is held by data macOS can free on its own (snapshots, iCloud copies, caches). It is released when an update or a big file needs the room.",
                                       "Khoảng \(fmt(vm.sysPurgeable)) đang bị giữ bởi dữ liệu macOS tự giải phóng được (bản sao lưu tạm, bản iCloud, bộ nhớ đệm). Khi cài bản cập nhật hay chép file lớn cần chỗ, macOS sẽ tự nhả ra."))
                                    .font(.system(size: fs(12))).foregroundColor(Theme.text).fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }.padding(14).background(RoundedRectangle(cornerRadius: 14).fill(Theme.link.opacity(0.10)))
                        }
                        ForEach($vm.sysParts) { $p in SysPartCard(part: $p, vm: vm, open: open) }
                        Text(t("The rest of System Data is macOS itself: system files, the Spotlight index, system caches. macOS looks after it; Tidymint does not touch it.",
                               "Phần còn lại của System Data là của chính macOS: file hệ thống, chỉ mục Spotlight, bộ nhớ đệm hệ thống. macOS tự quản, Tidymint không đụng tới."))
                            .font(.system(size: fs(11))).foregroundColor(Theme.sub).fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                    }.padding(.horizontal, 24).padding(.bottom, 16)
                }
            }
            HStack {
                let sel = vm.sysParts.flatMap { $0.items.filter(\.selected) }
                if sel.isEmpty {
                    Text(t("Tick items to move them to the Trash.", "Tick mục muốn chuyển vào Thùng rác.")).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                    Spacer()
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selLabel(sel.count, sel.reduce(0) { $0 + $1.size })).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                        Text(t("Moved to the Trash, not deleted yet.", "Chỉ chuyển vào Thùng rác, chưa xoá hẳn.")).foregroundColor(Theme.sub).font(.system(size: fs(11)))
                    }
                    Spacer()
                    PrimaryButton(title: t("Move to Trash", "Chuyển vào Thùng rác"), action: { vm.trashSys() })
                }
            }.padding(.horizontal, 24).padding(.vertical, 12).background(Theme.shade.opacity(0.25))
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
                Image(systemName: icon).font(.system(size: fs(26))).foregroundStyle(Theme.accent)
                Text(title).foregroundColor(Theme.sub).font(.system(size: fs(13)))
                Text(value).foregroundColor(Theme.text).font(.system(size: fs(24), weight: .bold))
                Text(sub).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                Text(t("Review", "Xem")).font(.system(size: fs(12), weight: .semibold)).foregroundColor(Theme.text).padding(.top, 4)
            }
            .padding(20).frame(width: 200 * uiScale, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(hover.v ? Theme.cardHi : Theme.card))
        }.buttonStyle(.plain).onHover { hover.v = $0 }
    }
}

struct SmartView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(spacing: 22) {
            if !vm.fullDiskAccess && vm.phase != .scanning {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.warn)
                    Text(t("Full Disk Access is off, so Mail, Safari and Messages stay hidden from the scan. Turn on Tidymint in System Settings, then come back.",
                           "Chưa có quyền Truy cập toàn bộ ổ đĩa, nên Mail, Safari, Tin nhắn bị ẩn khỏi lượt quét. Bật Tidymint trong Cài đặt hệ thống rồi quay lại."))
                        .font(.system(size: fs(12))).foregroundColor(Theme.text).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    GhostButton(title: t("Open Settings", "Mở Cài đặt")) { NSWorkspace.shared.open(VM.fdaSettings) }
                }.padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Theme.warn.opacity(0.12))).frame(maxWidth: 620)
            }
            switch vm.phase {
            case .scanning:
                ScanSteps(title: t("Scanning your Mac...", "Đang quét máy..."), steps: VM.junkSteps + [t("Large files", "File lớn")], current: vm.scanStep, detail: vm.scanDetail)
            case .idle:
                Header(title: t("Tidy up a little?", "Dọn máy chút nhé?"),
                       sub: t("Scan finds the safe part: caches, logs, old installers. You see what it is, then press Clean.\nEverything goes to the Trash first, so you can change your mind.",
                              "Quét sẽ tìm phần an toàn: bộ nhớ đệm, nhật ký, file cài đặt cũ. Bạn xem rồi mới bấm Dọn.\nMọi thứ vào Thùng rác trước, đổi ý thì lấy lại được."))
                if let v = vm.newVersion {
                    Button { NSWorkspace.shared.open(Updates.page) } label: {
                        Label(t("Tidymint \(v) is available. Download", "Đã có Tidymint \(v). Tải về"), systemImage: "arrow.down.circle")
                            .font(.system(size: fs(12), weight: .medium)).foregroundColor(Theme.text)
                            .padding(.horizontal, 12).padding(.vertical, 6).background(Capsule().fill(Theme.ink.opacity(0.12)))
                    }.buttonStyle(.plain).hoverLift()
                }
                BigScanButton(label: t("Scan", "Quét")) { vm.smartScan() }
                Text(t("Nothing is moved until you press Clean.", "Chưa dọn gì cho tới khi bạn bấm Dọn.")).font(.system(size: fs(12))).foregroundColor(Theme.sub)
                HStack(spacing: 14) {
                    HomeCard(title: t("Chrome, Slack, Telegram...", "Zalo, Chrome, Telegram..."), value: t("Clean by App", "Dọn theo ứng dụng"), sub: t("by type and by month", "theo loại, theo tháng")) { vm.page = .byapp }
                    HomeCard(title: t("Photos, videos, old files", "Ảnh, video, file cũ"), value: t("Large Files", "File lớn"), sub: t("you choose", "bạn tự chọn")) { vm.page = .large }
                    HomeCard(title: t("Trash", "Thùng rác"), value: fmt(vm.trashSize), sub: t("empty it to delete for good", "đổ là xoá sạch")) { vm.page = .trash }
                }.padding(.top, 6)
            case .done:
                Image(systemName: "checkmark.circle.fill").font(.system(size: fs(54))).foregroundColor(Theme.green)
                Text(vm.lastFreed > 0 ? t("\(fmt(vm.lastFreed)) tidier", "Gọn thêm \(fmt(vm.lastFreed))") : t("Already tidy", "Máy đang gọn rồi"))
                    .font(.system(size: fs(40), weight: .bold)).foregroundColor(Theme.text)
                Text(vm.lastFreed > 0
                     ? t("\(vm.lastCount) items moved to the Trash. Nothing is lost yet: empty the Trash to free the space for real, or undo if you change your mind.",
                         "Đã chuyển \(vm.lastCount) mục vào Thùng rác. Chưa mất gì cả: đổ Thùng rác thì ổ mới trống thật, hoặc bấm Hoàn tác nếu đổi ý.")
                     : t("Nothing safe to clean right now. Try Clean by App or Large Files for things only you can decide on.",
                         "Không có gì an toàn để dọn lúc này. Thử Dọn theo ứng dụng hoặc File lớn, là phần chỉ bạn quyết được."))
                    .foregroundColor(Theme.sub).multilineTextAlignment(.center).frame(maxWidth: 520)
                HStack(spacing: 12) {
                    if vm.undoable != nil { GhostButton(title: t("Undo", "Hoàn tác")) { vm.undoLast(); vm.phase = .idle } }
                    GhostButton(title: t("Open Trash", "Xem Thùng rác")) { vm.page = .trash }
                    PrimaryButton(title: t("Empty Trash", "Đổ Thùng rác"), action: { vm.emptyTrash() }, disabled: vm.trashCount == 0)
                }
                Button { vm.page = .byapp } label: {
                    (Text(t("Want more room? ", "Muốn gọn hơn nữa? ")).foregroundColor(Theme.sub)
                     + Text(t("Clean by App", "Dọn theo ứng dụng")).foregroundColor(Theme.text).underline()
                     + Text(t(" lists what Zalo, Chrome and CapCut keep.", " cho xem Zalo, Chrome, CapCut đang giữ gì.")).foregroundColor(Theme.sub))
                        .font(.system(size: fs(12)))
                }.buttonStyle(.plain).linkHover().padding(.top, 6)
                if Invite.shouldShow() { InviteCard(source: "after-clean").frame(maxWidth: 520).padding(.top, 8) }
                if ConCao.shouldShow() { ConCaoHint().frame(maxWidth: 520) }
            default:
                Text(vm.junkSelected > 0 ? t("\(fmt(vm.junkSelected)) safe to clean", "\(fmt(vm.junkSelected)) an toàn để dọn") : t("Already tidy", "Máy đang gọn rồi"))
                    .font(.system(size: fs(40), weight: .bold)).foregroundColor(Theme.text)
                Text(vm.junkSelected > 0
                     ? t("Apps rebuild all of this on their own. Everything goes to the Trash first.", "Toàn bộ phần này app tự tạo lại được. Mọi thứ vào Thùng rác trước.")
                     : t("Nothing safe to clean right now. Try Clean by App or Large Files for things only you can decide on.", "Không có gì an toàn để dọn lúc này. Thử Dọn theo ứng dụng hoặc File lớn, là phần chỉ bạn quyết được."))
                    .foregroundColor(Theme.sub).multilineTextAlignment(.center).frame(maxWidth: 520)
                // What will be cleaned, one card per group: the decision is informed without opening the full list.
                // Cleaning itself stays on the single button below (preview first, then Clean).
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190 * uiScale, maximum: 260 * uiScale), spacing: 12)], spacing: 12) {
                    ForEach(vm.cats) { c in
                        JunkCard(cat: c) {
                            if let i = vm.cats.firstIndex(where: { $0.id == c.id }) { for j in vm.cats.indices { vm.cats[j].expanded = j == i } }
                            vm.page = .cleanup; vm.phase = .review
                        }
                    }
                }.frame(maxWidth: 820).padding(.horizontal, 24)
                HStack(spacing: 14) {
                    GhostButton(title: t("Review every item", "Xem từng mục")) { vm.page = .cleanup; vm.phase = .review }
                    PrimaryButton(title: t("Clean (\(fmt(vm.junkSelected)))", "Dọn (\(fmt(vm.junkSelected)))"), action: { vm.cleanJunk() }, disabled: vm.junkSelected == 0)
                }
                if vm.junkSelected > 0 {
                    Text(t("Not selected: \(fmt(vm.junkTotal - vm.junkSelected)) that only you can decide on. Tick it under Review every item.", "Chưa tick: \(fmt(vm.junkTotal - vm.junkSelected)) là phần bạn tự quyết. Muốn dọn thì tick ở Xem từng mục."))
                        .font(.system(size: fs(11))).foregroundColor(Theme.sub)
                }
                TextLink(t("Disk still full of \"System Data\"? See what is in it", "Ổ vẫn đầy vì \"System Data\"? Xem nó gồm những gì"), size: fs(12), weight: .semibold) {
                    vm.page = .lens; vm.openSys()
                }.padding(.top, 2)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { vm.refreshTrash() }
    }
}

/// Small navigation card on the home page: what it is, where it goes, who decides.
struct HomeCard: View {
    let title: String, value: String, sub: String
    let action: () -> Void
    @StateObject private var hover = Flag()
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).foregroundColor(Theme.sub).font(.system(size: fs(11))).lineLimit(1)
                Text(value).foregroundColor(Theme.text).font(.system(size: fs(16), weight: .semibold))
                Text(sub).foregroundColor(Theme.sub).font(.system(size: fs(11)))
            }
            .padding(14).frame(width: 190 * uiScale, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(hover.v ? Theme.cardHi : Theme.card))
        }.buttonStyle(.plain).onHover { hover.v = $0 }
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
            ScanSteps(title: t("Looking for junk...", "Đang tìm rác..."), steps: VM.junkSteps, current: vm.scanStep, detail: vm.scanDetail).frame(maxWidth: .infinity, maxHeight: .infinity)
        case .summary:
            VStack(spacing: 24) {
                Text(fmt(vm.junkTotal)).font(.system(size: fs(54), weight: .bold)).foregroundColor(Theme.text)
                Text(t("can be cleaned. \(fmt(vm.junkSelected)) is rebuilt by apps on their own and is pre-selected.", "có thể dọn. \(fmt(vm.junkSelected)) là phần app tự tạo lại được, đã chọn sẵn.")).foregroundColor(Theme.sub)
                HStack(spacing: 14) {
                    GhostButton(title: t("Review Details", "Xem chi tiết")) { vm.phase = .review }
                    PrimaryButton(title: t("Clean", "Dọn"), action: { vm.cleanJunk() }, disabled: vm.junkSelected == 0)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .review:
            ReviewView(vm: vm)
        case .done:
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: fs(64))).foregroundColor(Theme.green)
                Text(vm.lastFreed > 0 ? t("\(fmt(vm.lastFreed)) tidier", "Gọn thêm \(fmt(vm.lastFreed))") : t("All done!", "Xong rồi!")).font(.system(size: fs(40), weight: .bold)).foregroundColor(Theme.text)
                Text(vm.lastResult).foregroundColor(Theme.sub).multilineTextAlignment(.center)
                Text(t("Last step: review the Trash, then empty it.", "Bước cuối: xem lại Thùng rác rồi đổ.")).foregroundColor(Theme.sub)
                HStack(spacing: 14) {
                    if vm.undoable != nil { GhostButton(title: t("Undo", "Hoàn tác")) { vm.undoLast() } }
                    GhostButton(title: t("Scan Again", "Quét lại")) { vm.scanJunk() }
                    PrimaryButton(title: t("Open Trash", "Xem Thùng rác"), action: { vm.page = .trash })
                }
                if Invite.shouldShow() { InviteCard(source: "after-clean").frame(maxWidth: 520).padding(.top, 8) }
                if ConCao.shouldShow() { ConCaoHint().frame(maxWidth: 520) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ReviewView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { vm.phase = .summary } label: { Label(t("Back", "Quay lại"), systemImage: "chevron.left").padding(.horizontal, 6).padding(.vertical, 3).hoverTile() }.buttonStyle(.plain).foregroundColor(Theme.text)
                Spacer()
                Text(t("Cleanup Details", "Dọn rác chi tiết")).font(.system(size: fs(17), weight: .semibold)).foregroundColor(Theme.text)
                Spacer()
                Menu(t("Select", "Chọn")) {
                    Button(t("Select All", "Chọn tất cả")) { vm.setAll(true) }
                    Button(t("Deselect All", "Bỏ chọn tất cả")) { vm.setAll(false) }
                    Button(t("Smart Selection", "Chọn thông minh")) { vm.scanJunk(thenReview: true) }
                }.menuStyle(.borderlessButton).frame(width: 70).foregroundColor(Theme.text).padding(.vertical, 3).hoverTile()
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 14)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach($vm.cats) { $cat in
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Button { vm.toggleCat(cat.id) } label: { CheckBox(state: cat.state) }.buttonStyle(.plain)
                                Image(systemName: cat.icon).font(.system(size: fs(18))).foregroundStyle(Theme.accent).frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.title).foregroundColor(Theme.text).font(.system(size: fs(14), weight: .semibold))
                                    Text(cat.desc).foregroundColor(Theme.sub).font(.system(size: fs(11)))
                                }
                                Spacer()
                                SafetyBadge(level: cat.safety, why: cat.why)
                                Text(t("\(cat.items.count) items", "\(cat.items.count) mục")).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                                Text(fmt(cat.selectedSize) + " / " + fmt(cat.total)).foregroundColor(Theme.text)
                                    .font(.system(size: fs(13), weight: .medium).monospacedDigit()).frame(width: 150, alignment: .trailing)
                                Image(systemName: "chevron.down").rotationEffect(.degrees(cat.expanded ? 0 : -90)).foregroundColor(Theme.sub)
                            }
                            .padding(14).hoverBG(14, Theme.ink.opacity(0.06)).contentShape(Rectangle())
                            .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { cat.expanded.toggle() } }

                            if cat.expanded {
                                Divider().background(Theme.ink.opacity(0.1))
                                ForEach($cat.items) { $it in ItemRow(item: $it, vm: vm) }.padding(.leading, 26)
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                    }
                }.padding(.horizontal, 24).padding(.bottom, 16)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selLabel(vm.cats.reduce(0) { $0 + $1.items.filter(\.selected).count }, vm.junkSelected)).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                    Text(t("Moved to the Trash, not deleted yet. Right-click an item for more.", "Chỉ chuyển vào Thùng rác, chưa xoá hẳn. Chuột phải vào một mục để xem thêm.")).foregroundColor(Theme.sub).font(.system(size: fs(11)))
                }
                Spacer()
                PrimaryButton(title: t("Clean", "Dọn"), action: { vm.cleanJunk() }, disabled: vm.junkSelected == 0)
            }.padding(.horizontal, 24).padding(.vertical, 14).background(Theme.shade.opacity(0.25))
        }
    }
}

struct ByAppView: View {
    @ObservedObject var vm: VM
    var body: some View {
        if vm.appBusy {
            Scanning(text: t("Measuring app data...", "Đang đo dữ liệu từng app...")).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !vm.appScanned {
            VStack(spacing: 28) {
                Header(title: t("Clean by App", "Dọn theo ứng dụng"),
                       sub: t("Zalo, Chrome, Edge, Cốc Cốc, CapCut: see what each app keeps on your Mac and clean it by type.\nMessages and logins are never touched.",
                              "Zalo, Chrome, Edge, Cốc Cốc, CapCut: xem từng app đang giữ gì trên máy và dọn theo loại.\nTin nhắn và đăng nhập không bao giờ bị đụng."))
                BigScanButton(label: t("Scan", "Quét")) { vm.scanByApp() }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let id = vm.appSel, let r = vm.appReports.first(where: { $0.id == id }) {
            AppDetail(vm: vm, report: r)
        } else {
            AppList(vm: vm)
        }
    }
}

func appIcon(_ bundleIDs: [String]) -> NSImage {
    for b in bundleIDs { if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: b) { return NSWorkspace.shared.icon(forFile: u.path) } }
    return NSWorkspace.shared.icon(for: .applicationBundle)
}

struct AppList: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("Clean by App", "Dọn theo ứng dụng")).font(.system(size: fs(22), weight: .bold)).foregroundColor(Theme.text)
                    Text(t("\(vm.appReports.count) apps, \(fmt(vm.appReports.reduce(0) { $0 + $1.cleanable })) can be cleaned.", "\(vm.appReports.count) app, có thể dọn \(fmt(vm.appReports.reduce(0) { $0 + $1.cleanable }))."))
                        .font(.system(size: fs(12))).foregroundColor(Theme.sub)
                }
                Spacer()
                GhostButton(title: t("Scan Again", "Quét lại")) { vm.scanByApp() }
            }.padding(.horizontal, 24).padding(.top, 30).padding(.bottom, 14)
            DoneBanner(vm: vm, page: .byapp)
            if !vm.appMsg.isEmpty { Text(vm.appMsg).font(.system(size: fs(12))).foregroundColor(Theme.green).padding(.horizontal, 24).padding(.bottom, 8) }
            if vm.appReports.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "app.dashed").font(.system(size: fs(40))).foregroundColor(Theme.sub)
                    Text(t("None of the supported apps keeps data on this Mac.", "Không thấy dữ liệu của các app được hỗ trợ trên máy này.")).foregroundColor(Theme.sub)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.appReports) { r in
                            HStack(spacing: 14) {
                                Image(nsImage: appIcon(r.rule.bundleIDs)).resizable().frame(width: 40, height: 40)
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 8) {
                                        Text(r.rule.name).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                                        if r.running {
                                            Text(t("Open", "Đang mở")).font(.system(size: fs(10), weight: .semibold)).foregroundColor(Theme.warn)
                                                .padding(.horizontal, 6).padding(.vertical, 1).background(Capsule().fill(Theme.warn.opacity(0.15)))
                                        }
                                    }
                                    Text(r.groups.map { "\($0.section.title) \(fmt($0.total))" }.joined(separator: " · ")).font(.system(size: fs(11))).foregroundColor(Theme.sub).lineLimit(1)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(fmt(r.total)).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold).monospacedDigit())
                                    Text(t("\(fmt(r.cleanable)) cleanable", "dọn được \(fmt(r.cleanable))")).font(.system(size: fs(11))).foregroundColor(Theme.sub)
                                }
                                Image(systemName: "chevron.right").foregroundColor(Theme.sub)
                            }
                            .padding(16).background(RoundedRectangle(cornerRadius: 14).fill(Theme.card)).hoverBG(14, Theme.ink.opacity(0.06))
                            .contentShape(Rectangle()).onTapGesture { vm.appSel = r.id; vm.appAge = 0 }
                        }
                    }.padding(.horizontal, 24).padding(.bottom, 16)
                }
            }
        }
        .onAppear { vm.refreshAppRunning() }
    }
}

struct AppDetail: View {
    @ObservedObject var vm: VM
    let report: AppReport
    var hasAge: Bool { report.groups.contains { $0.section.byAge } }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { vm.appSel = nil } label: { Label(t("Back", "Quay lại"), systemImage: "chevron.left").padding(.horizontal, 6).padding(.vertical, 3).hoverTile() }.buttonStyle(.plain).foregroundColor(Theme.text)
                Spacer()
                HStack(spacing: 8) {
                    Image(nsImage: appIcon(report.rule.bundleIDs)).resizable().frame(width: 22, height: 22)
                    Text(report.rule.name).font(.system(size: fs(17), weight: .semibold)).foregroundColor(Theme.text)
                    Text(fmt(report.total)).font(.system(size: fs(13))).foregroundColor(Theme.sub)
                }
                Spacer()
                if hasAge {
                    Picker("", selection: Binding(get: { vm.appAge }, set: { vm.selectOlder(report.id, months: $0) })) {
                        Text(t("Pick by hand", "Tự tick")).tag(0)
                        Text(t("Older than 3 months", "Cũ hơn 3 tháng")).tag(3)
                        Text(t("Older than 6 months", "Cũ hơn 6 tháng")).tag(6)
                        Text(t("Older than 1 year", "Cũ hơn 1 năm")).tag(12)
                    }.pickerStyle(.menu).frame(width: 170)
                } else { Color.clear.frame(width: 170, height: 1) }
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 14)

            if report.running {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.warn)
                    Text(t("\(report.rule.name) is open. Quit it before cleaning so it does not write to these files.", "\(report.rule.name) đang mở. Tắt app trước khi dọn để app không ghi vào các file này."))
                        .font(.system(size: fs(12))).foregroundColor(Theme.text)
                    Spacer()
                    GhostButton(title: t("Quit \(report.rule.name)", "Tắt \(report.rule.name)")) { vm.quitApp(report.id) }
                }.padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Theme.warn.opacity(0.12))).padding(.horizontal, 24).padding(.bottom, 10)
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(report.groups) { g in
                        let locked = g.section.safety == .locked
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                if locked { Image(systemName: "lock.fill").foregroundColor(Theme.danger).frame(width: 18) }
                                else { Button { vm.toggleAppGroup(report.id, g.id) } label: { CheckBox(state: g.state) }.buttonStyle(.plain) }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(g.section.title).foregroundColor(Theme.text).font(.system(size: fs(14), weight: .semibold))
                                    Text(g.section.why).foregroundColor(Theme.sub).font(.system(size: fs(11))).lineLimit(2)
                                }
                                Spacer()
                                SafetyBadge(level: g.section.safety, why: g.section.why)
                                Text(locked ? fmt(g.total) : fmt(g.selected) + " / " + fmt(g.total)).foregroundColor(Theme.text)
                                    .font(.system(size: fs(13), weight: .medium).monospacedDigit()).frame(width: 150, alignment: .trailing)
                                Image(systemName: "chevron.down").rotationEffect(.degrees(g.expanded ? 0 : -90)).foregroundColor(Theme.sub).opacity(locked ? 0 : 1)
                            }
                            .padding(14).hoverBG(14, Theme.ink.opacity(0.06)).contentShape(Rectangle())
                            .onTapGesture { if !locked { vm.toggleAppExpand(report.id, g.id) } }
                            if g.expanded && !locked {
                                Divider().background(Theme.ink.opacity(0.1))
                                ForEach(g.rows) { row in
                                    HStack(spacing: 12) {
                                        Button { vm.toggleAppRow(report.id, g.id, row.id) } label: { CheckBox(state: row.selected ? 2 : 0) }.buttonStyle(.plain)
                                        if let u = row.urls.first, row.month == nil {
                                            Image(nsImage: NSWorkspace.shared.icon(forFile: u.path)).resizable().frame(width: 22, height: 22)
                                        } else { Image(systemName: "calendar").foregroundColor(Theme.sub).frame(width: 22) }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(row.title).foregroundColor(Theme.text).font(.system(size: fs(13))).lineLimit(1)
                                            Text(row.sub).foregroundColor(Theme.sub).font(.system(size: fs(11))).lineLimit(1).truncationMode(.middle)
                                        }
                                        Spacer()
                                        Text(fmt(row.size)).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .medium).monospacedDigit()).frame(width: 80, alignment: .trailing)
                                    }
                                    .padding(.vertical, 6).padding(.horizontal, 12).hoverBG(8, Theme.ink.opacity(0.07)).contentShape(Rectangle())
                                    .contextMenu { Button(t("Reveal in Finder", "Mở trong Finder")) { if let u = row.urls.first { vm.reveal(u) } } }
                                }.padding(.leading, 26)
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                    }
                }.padding(.horizontal, 24).padding(.bottom, 16)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selLabel(report.groups.filter { $0.section.safety != .locked }.reduce(0) { $0 + $1.rows.filter(\.selected).count }, report.selected)).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                    Text(t("Everything goes to the Trash first. Undo is on the Trash page.", "Mọi thứ vào Thùng rác trước. Hoàn tác ở trang Thùng rác.")).foregroundColor(Theme.sub).font(.system(size: fs(11)))
                }
                Spacer()
                PrimaryButton(title: t("Move to Trash", "Chuyển vào Thùng rác"), action: { vm.cleanApp(report.id) }, disabled: report.selected == 0)
            }.padding(.horizontal, 24).padding(.vertical, 14).background(Theme.shade.opacity(0.25))
        }
        .onAppear { vm.refreshAppRunning() }
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
                    Text(t("Large Files (\(vm.large.count))", "File lớn (\(vm.large.count))")).font(.system(size: fs(17), weight: .semibold)).foregroundColor(Theme.text)
                    Spacer()
                    Picker("", selection: $sortByDate.v) { Text(t("By Size", "Theo dung lượng")).tag(false); Text(t("Oldest Opened", "Lâu không mở")).tag(true) }
                        .pickerStyle(.segmented).frame(width: 240)
                    Button { vm.scanLarge() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.icon).tip(t("Scan again", "Quét lại"), trailing: true).foregroundColor(Theme.text).padding(.leading, 8)
                }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 14)
                DoneBanner(vm: vm, page: .large)
                if vm.large.isEmpty {
                    Text(t("No files over 100 MB.", "Không có file nào trên 100 MB.")).foregroundColor(Theme.sub).frame(maxHeight: .infinity)
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
                    Text(selLabel(vm.large.filter(\.selected).count, vm.largeSelected)).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                    Spacer()
                    PrimaryButton(title: t("Move to Trash", "Chuyển vào Thùng rác"), action: { vm.cleanLarge() }, disabled: vm.largeSelected == 0)
                }.padding(.horizontal, 24).padding(.vertical, 14).background(Theme.shade.opacity(0.25))
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
        if vm.sysOpen {
            SysDataView(vm: vm)
        } else if vm.lensPath.isEmpty {
            VStack(spacing: 28) {
                Header(title: t("Space Lens", "Bản đồ ổ đĩa"), sub: t("See what takes up space, folder by folder.\nClick a bubble to look inside.", "Xem thư mục nào chiếm chỗ.\nBấm vào bong bóng để xem bên trong."))
                BigScanButton(label: t("Scan", "Quét")) { vm.openLens(Scanner.home) }
                HStack(spacing: 12) {
                    GhostButton(title: "Library") { vm.openLens(Scanner.lib) }
                    GhostButton(title: "Documents") { vm.openLens(Scanner.home.appendingPathComponent("Documents")) }
                }
                TextLink(t("Disk full of \"System Data\"? See what is in it", "Ổ đầy vì \"System Data\"? Xem nó gồm những gì"), size: fs(13), weight: .semibold) { vm.openSys() }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                // breadcrumb
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Button { vm.lensBack() } label: { Image(systemName: "chevron.left") }.buttonStyle(.icon)
                            .foregroundColor(vm.lensPath.count > 1 ? Theme.text : Theme.sub.opacity(0.4)).disabled(vm.lensPath.count <= 1).tip(t("Back", "Lùi"))
                        Button { vm.lensForward() } label: { Image(systemName: "chevron.right") }.buttonStyle(.icon)
                            .foregroundColor(vm.lensFwd.isEmpty ? Theme.sub.opacity(0.4) : Theme.text).disabled(vm.lensFwd.isEmpty).tip(t("Forward", "Tiến"))
                            .padding(.trailing, 8)
                        Button { vm.stopLens(); vm.lensPath = []; vm.lensNodes = []; vm.lensSel = []; vm.lensFwd = [] } label: { Image(systemName: "house") }.buttonStyle(.icon).tip(t("Go to your home folder", "Về thư mục người dùng")).foregroundColor(Theme.text)
                        ForEach(Array(vm.lensPath.enumerated()), id: \.offset) { i, u in
                            Image(systemName: "chevron.right").font(.system(size: fs(10))).foregroundColor(Theme.sub)
                            Button { vm.lensUp(to: i) } label: {
                                Text(i == 0 && u.path == NSHomeDirectory() ? t("Home", "Nhà") : u.lastPathComponent).padding(.horizontal, 4).padding(.vertical, 2).hoverTile()
                            }.buttonStyle(.plain).foregroundColor(i == vm.lensPath.count - 1 ? Theme.text : Theme.sub)
                        }
                    }
                }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 10)
                DoneBanner(vm: vm, page: .lens)

                if vm.lensBusy {
                    HStack(spacing: 10) {
                        ProgressView(value: Double(vm.lensDone), total: Double(max(vm.lensTotal, 1))).tint(Theme.accentSolid).frame(width: 160)
                        Text(t("Measured \(vm.lensDone)/\(vm.lensTotal)", "Đã đo \(vm.lensDone)/\(vm.lensTotal)") + (vm.lensCurrent.isEmpty ? "" : t(" · now: ", " · đang đo: ") + vm.lensCurrent))
                            .font(.system(size: fs(11))).foregroundColor(Theme.sub).lineLimit(1)
                        Spacer()
                        TextLink(t("Stop", "Dừng"), size: 11, weight: .semibold, color: Theme.text) { vm.stopLens() }
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
                                        let blocked = Scanner.blocked(n.url.path)
                                        Button { if vm.lensSel.contains(n.url) { vm.lensSel.remove(n.url) } else { vm.lensSel.insert(n.url) } } label: {
                                            CheckBox(state: vm.lensSel.contains(n.url) ? 2 : 0).opacity(blocked ? 0.25 : 1)
                                        }.buttonStyle(.plain).disabled(blocked).tip(blocked ? t("Protected", "Được bảo vệ") : "")
                                        FileThumb(url: n.url, side: 22 * uiScale)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(n.name).foregroundColor(Theme.text).font(.system(size: fs(13))).lineLimit(1)
                                            if n.otherCount == 0, let info = folderInfo(n.url) {
                                                Text(info).foregroundColor(Theme.sub).font(.system(size: fs(10))).lineLimit(1)
                                            }
                                        }.tip(n.otherCount == 0 ? (folderInfo(n.url) ?? "") : "")
                                        Spacer()
                                        Text(fmt(n.size)).foregroundColor(Theme.sub).font(.system(size: fs(12)).monospacedDigit())
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(vm.hoverNode == n.id || vm.lensSel.contains(n.url) ? Theme.cardHi : Color.clear))
                                    .contentShape(Rectangle())
                                    .onTapGesture { if n.isDir { vm.openLens(n.url) } }
                                    .onHover { h in vm.hoverNode = h ? n.id : nil }
                                    .contextMenu { nodeMenu(n) }
                                }
                            }.padding(.horizontal, 12)
                        }.frame(width: 300 * uiScale).background(Theme.shade.opacity(0.15))
                        // bubbles
                        GeometryReader { g in
                            let total = max(vm.lensNodes.reduce(0) { $0 + $1.size }, 1)
                            let bs = pack(lensBubbles(vm.lensNodes, folder: vm.lensPath.last), in: g.size)
                            ZStack {
                                ForEach(bs, id: \.node.id) { b in
                                    ZStack {
                                        Sphere(color: b.color, r: b.r, hot: vm.hoverNode == b.node.id || vm.lensSel.contains(b.node.url))
                                        if vm.lensSel.contains(b.node.url) && b.node.otherCount == 0 {
                                            Circle().strokeBorder(Theme.accent, lineWidth: 2.5)
                                        }
                                        let pct = Double(b.node.size) / Double(total) * 100
                                        let pctText = pct < 1 ? "<1%" : String(format: "%.0f%%", pct)
                                        if b.r > 34 {
                                            VStack(spacing: 2) {
                                                Text(b.node.name).font(.system(size: max(9, min(14, b.r / 5)), weight: .semibold)).lineLimit(1)
                                                Text(fmt(b.node.size) + " · " + pctText).font(.system(size: max(8, min(12, b.r / 6))))
                                            }.foregroundColor(.white).frame(width: b.r * 1.6).shadow(color: .black.opacity(Theme.p.light ? 0.7 : 0.5), radius: Theme.p.light ? 3 : 2, y: 1)
                                        } else if b.r > 14 {
                                            Text(pctText).font(.system(size: fs(9), weight: .semibold)).foregroundColor(Theme.text)
                                        }
                                    }
                                    .frame(width: b.r * 2, height: b.r * 2)
                                    .scaleEffect(vm.hoverNode == b.node.id ? 1.03 : 1)
                                    .animation(.easeOut(duration: 0.18), value: vm.hoverNode == b.node.id)
                                    .position(x: b.x, y: b.y)
                                    .onTapGesture { if b.node.isDir && b.node.otherCount == 0 { vm.openLens(b.node.url) } }
                                    .onHover { h in vm.hoverNode = h ? b.node.id : nil }
                                    .contextMenu { if b.node.otherCount == 0 { nodeMenu(b.node) } }
                                    .tip(b.node.otherCount > 0
                                          ? t("\(b.node.otherCount) small items (under 1% each), \(fmt(b.node.size)). See the list on the left.",
                                              "\(b.node.otherCount) mục nhỏ (mỗi mục dưới 1%), \(fmt(b.node.size)). Xem ở danh sách bên trái.")
                                          : "\(b.node.name): \(fmt(b.node.size))" + (folderInfo(b.node.url).map { "\n" + $0 } ?? ""))
                                }
                            }
                        }.padding(12)
                    }
                }
                HStack {
                    if vm.lensSel.isEmpty {
                        Text(t("Total: ", "Tổng: ") + fmt(vm.lensNodes.reduce(0) { $0 + $1.size })).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                        Spacer()
                        Text(t("Click a folder to open it. Tick items to move them to the Trash.", "Bấm vào thư mục để mở. Tick mục muốn chuyển vào Thùng rác.")).foregroundColor(Theme.sub).font(.system(size: fs(11)))
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selLabel(vm.lensSel.count, vm.lensSelSize)).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                            Text(t("Moved to the Trash, not deleted yet.", "Chỉ chuyển vào Thùng rác, chưa xoá hẳn.")).foregroundColor(Theme.sub).font(.system(size: fs(11)))
                        }
                        Spacer()
                        GhostButton(title: t("Deselect", "Bỏ chọn")) { vm.lensSel = [] }.padding(.trailing, 8)
                        PrimaryButton(title: t("Move to Trash", "Chuyển vào Thùng rác"), action: { vm.trashLensSelection() })
                    }
                }.padding(.horizontal, 24).padding(.vertical, 12).background(Theme.shade.opacity(0.25))
            }
        }
    }
    @ViewBuilder func nodeMenu(_ n: Node) -> some View {
        Button(t("Reveal in Finder", "Mở trong Finder")) { vm.reveal(n.url) }
        if n.isDir { Button(t("Open", "Mở")) { vm.openLens(n.url) } }
        Divider()
        if Scanner.blocked(n.url.path) {
            Text(t("Protected: cannot be removed here", "Được bảo vệ: không xoá từ đây được"))
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
            Image(systemName: vm.trashCount == 0 ? "trash" : "trash.fill").font(.system(size: fs(70))).foregroundStyle(Theme.accent)
            Text(fmt(vm.trashSize)).font(.system(size: fs(46), weight: .bold)).foregroundColor(Theme.text)
            Text(vm.trashCount == 0 ? t("The Trash is empty.", "Thùng rác trống.") : t("\(vm.trashCount) items in the Trash", "\(vm.trashCount) mục trong Thùng rác")).foregroundColor(Theme.sub)
            HStack(spacing: 14) {
                GhostButton(title: t("Show in Finder", "Mở trong Finder")) { NSWorkspace.shared.open(Scanner.trashURL) }
                PrimaryButton(title: t("Empty Trash", "Đổ Thùng rác"), action: { vm.emptyTrash() }, disabled: vm.trashCount == 0)
            }
            Text(t("Emptying cannot be undone. Take a quick look first.", "Dọn sạch rồi thì không lấy lại được. Liếc qua một lượt trước đã.")).font(.system(size: fs(12))).foregroundColor(Theme.sub)
            if let s = vm.undoable {
                VStack(spacing: 8) {
                    Text(t("Last clean: \(s.entries.count) items, \(fmt(s.size)), \(ago(s.date))", "Lần dọn vừa rồi: \(s.entries.count) mục, \(fmt(s.size)), \(ago(s.date))"))
                        .font(.system(size: fs(12))).foregroundColor(Theme.sub)
                    GhostButton(title: t("Undo last clean", "Hoàn tác lần dọn vừa rồi")) { vm.undoLast() }
                }.padding(.top, 10)
            }
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
                Text(t("Ignore List", "Danh sách bỏ qua")).font(.system(size: fs(22), weight: .bold)).foregroundColor(Theme.text)
                Text(t("Items here are never shown in scans. Right-click any item in Cleanup, Large Files or Space Lens to add it.", "Mục ở đây không bao giờ hiện trong kết quả quét. Chuột phải vào một mục ở Dọn rác chi tiết, File lớn hoặc Bản đồ ổ đĩa để thêm."))
                    .foregroundColor(Theme.sub).font(.system(size: fs(12)))
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 16)
            if vm.ignored.isEmpty {
                Text(t("Nothing ignored yet.", "Chưa bỏ qua mục nào.")).foregroundColor(Theme.sub).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(vm.ignored, id: \.self) { p in
                            HStack(spacing: 10) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: p)).resizable().frame(width: 20, height: 20)
                                Text(p.replacingOccurrences(of: NSHomeDirectory(), with: "~")).foregroundColor(Theme.text).font(.system(size: fs(12)))
                                    .lineLimit(1).truncationMode(.middle)
                                Spacer()
                                TextLink(t("Remove", "Gỡ"), size: 13) { vm.unignore(p) }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                            .hoverBG(10, Theme.ink.opacity(0.06))
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
        Text(text).font(.system(size: fs(10), weight: .semibold)).tracking(0.8)
            .foregroundColor(Theme.sub.opacity(0.8))
            .padding(.horizontal, 12).padding(.top, 14).padding(.bottom, 4)
    }
}

/// Sidebar Trash icon drawn as lines (same weight as the system symbols next to it), in two states:
/// lid flat when empty; lid resting askew on a crumpled ball when there is something inside.
struct TrashShape: Shape {
    var full: Bool
    func path(in r: CGRect) -> Path {
        let u = r.width / 20
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * u, y: r.minY + y * u) }
        var p = Path()
        // body: slight taper, rounded bottom corners
        p.move(to: pt(5.0, 6.8)); p.addLine(to: pt(5.9, 16.2))
        p.addQuadCurve(to: pt(7.7, 17.8), control: pt(6.1, 17.8))
        p.addLine(to: pt(12.3, 17.8))
        p.addQuadCurve(to: pt(14.1, 16.2), control: pt(13.9, 17.8))
        p.addLine(to: pt(15.0, 6.8))
        // ribs and rim
        p.move(to: pt(8.5, 9.4)); p.addLine(to: pt(8.7, 15.2))
        p.move(to: pt(11.5, 9.4)); p.addLine(to: pt(11.3, 15.2))
        p.move(to: pt(4.0, 6.8)); p.addLine(to: pt(16.0, 6.8))
        if !full {
            p.move(to: pt(3.6, 4.7)); p.addLine(to: pt(16.4, 4.7))
            p.move(to: pt(8.4, 4.7)); p.addLine(to: pt(8.4, 3.1)); p.addLine(to: pt(11.6, 3.1)); p.addLine(to: pt(11.6, 4.7))
        } else {
            // lid resting askew from (5.2, 2.6) to (16.6, 5.2); handle follows the same angle; crumpled ball underneath
            let a = CGPoint(x: 5.2, y: 2.6), b = CGPoint(x: 16.6, y: 5.2)
            let dx = b.x - a.x, dy = b.y - a.y, len = (dx * dx + dy * dy).squareRoot()
            let ux = dx / len, uy = dy / len, nx = uy, ny = -ux
            func on(_ t: CGFloat, _ h: CGFloat) -> CGPoint { pt(a.x + ux * t + nx * h, a.y + uy * t + ny * h) }
            p.move(to: pt(a.x, a.y)); p.addLine(to: pt(b.x, b.y))
            p.move(to: on(5.0, 0)); p.addLine(to: on(5.0, 1.6)); p.addLine(to: on(8.2, 1.6)); p.addLine(to: on(8.2, 0))
            p.addEllipse(in: CGRect(x: r.minX + 6.1 * u, y: r.minY + 3.5 * u, width: 3.4 * u, height: 3.3 * u))
        }
        return p
    }
}

struct NavItem: View {
    let p: Page
    @ObservedObject var vm: VM
    var body: some View {
        // Cleanup details has no menu row of its own (reached from Clean Now), so Clean Now stays highlighted there.
        let selected = vm.page == p || (p == .smart && vm.page == .cleanup)
        Button { vm.page = p } label: {
            HStack(spacing: 10) {
                // The Trash row has its own two-state line icon (see TrashShape).
                if p == .trash {
                    TrashShape(full: vm.trashSize > 0)
                        .stroke(selected ? Color.white : Theme.ink.opacity(0.8), style: StrokeStyle(lineWidth: 1.15, lineCap: .round, lineJoin: .round))
                        .frame(width: 18, height: 18).frame(width: 20)
                } else {
                    Image(systemName: p.icon).frame(width: 20)
                }
                Text(p.label).lineLimit(1)
                Spacer()
                NavBadge(p: p, vm: vm)
            }
            .font(.system(size: fs(13), weight: selected ? .semibold : .regular))
            .foregroundColor(selected ? .white : Theme.ink.opacity(0.8))
            .padding(.horizontal, 12).padding(.vertical, 8)
            // Selected item uses the theme colour; Smart Scan always keeps a light theme tint as the main entry point.
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? AnyShapeStyle(Theme.accentSolid.opacity(0.8))
                : (p == .smart ? AnyShapeStyle(Theme.accentSolid.opacity(Theme.p.light ? 0.12 : 0.22)) : AnyShapeStyle(Color.clear))))
            .hoverBG(8, Theme.ink.opacity(0.07))
            .contentShape(Rectangle())
        }.buttonStyle(.plain).id(p)
    }
}

/// Right edge of a sidebar row: spinner while that page scans, a small dot when a result is waiting to be seen,
/// a number on Settings only (count of pending things). Colours follow the theme.
struct NavBadge: View {
    let p: Page
    @ObservedObject var vm: VM
    var body: some View {
        let selected = vm.page == p
        if vm.isBusy(p) {
            ProgressView().controlSize(.mini).tint(selected ? .white : Theme.accentSolid)
        } else if p == .settings {
            // A number only where it counts several pending things.
            if vm.settingsPending > 0 {
                Text("\(vm.settingsPending)").font(.system(size: fs(10), weight: .bold))
                    .foregroundColor(selected ? Theme.accentSolid : .white)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(Capsule().fill(selected ? Color.white : Theme.accentSolid))
            }
        } else if vm.fresh.contains(p) {
            // A new result not seen yet: a small dot. Startup Items with something worth a look: warning colour.
            let warn = p == .startup && vm.launchAttention > 0
            Circle().fill(selected ? Color.white : (warn ? Theme.warn : Theme.accentSolid)).frame(width: 8, height: 8)
                .tip(warn ? t("\(vm.launchAttention) items worth a look", "\(vm.launchAttention) mục đáng để ý") : t("New results", "Có kết quả mới"))
        }
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
                        .font(.system(size: fs(10), weight: .semibold))
                        .foregroundColor(Theme.ink.opacity(vm.lang == l ? 1 : 0.55))
                        .frame(width: 22, height: 16)
                        .background(RoundedRectangle(cornerRadius: 4).fill(vm.lang == l ? Theme.ink.opacity(0.22) : .clear))
                        .hoverTile(vm.lang != l)
                }.buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 6).stroke(Theme.ink.opacity(0.2), lineWidth: 1))
        .tip(vm.lang == "vi" ? "Ngôn ngữ" : "Language")
    }
}

// MARK: - Root

/// Tracks whether the sidebar menu has more items above or below the visible area.
final class ScrollEdges: ObservableObject {
    @Published var view: CGRect = .zero      // visible scroll area (global coordinates)
    @Published var content: CGRect = .zero   // menu content (global coordinates)
    var moreBelow: Bool { view.height > 0 && content.maxY - 6 > view.maxY + 4 }   // 6 = bottom padding under the last item
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
                (Text("Tidy").foregroundColor(Theme.text) + Text("mint").foregroundColor(Theme.brandMint)).font(.system(size: fs(15), weight: .bold))
            }.padding(.top, 44).padding(.bottom, 12)
            // The menu scrolls when the window is short, so nothing overlaps.
            // A fade and a "More" chevron show that items are hidden below (and a fade at the top when scrolled).
            ScrollViewReader { proxy in
            VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 2) {
            NavItem(p: .smart, vm: vm)
            NavItem(p: .byapp, vm: vm)
            NavItem(p: .apps, vm: vm)
            NavItem(p: .trash, vm: vm)
            // Advanced pages fold away so the first screen stays simple. The fold opens itself when one of them is active.
            Button { withAnimation(.easeOut(duration: 0.2)) { vm.setAdvanced(!vm.advancedOpen) } } label: {
                HStack {
                    SectionTitle(text: t("ADVANCED", "NÂNG CAO"))
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: fs(9), weight: .bold)).foregroundColor(Theme.sub)
                        .rotationEffect(.degrees(vm.advancedOpen ? 90 : 0)).padding(.trailing, 10)
                }.padding(.vertical, 2).hoverTile()
            }.buttonStyle(.plain)
            if vm.advancedOpen {
                NavItem(p: .lens, vm: vm)
                NavItem(p: .large, vm: vm)
                NavItem(p: .dupes, vm: vm)
                NavItem(p: .cloud, vm: vm)
                NavItem(p: .startup, vm: vm)
                NavItem(p: .stats, vm: vm)
                NavItem(p: .ignore, vm: vm)
            }
            // Not cleaning: tools that organize files get their own group, always open.
            if featureOrganize {
            HStack(alignment: .top, spacing: 1) {
                SectionTitle(text: t("ORGANIZE (NEW)", "SẮP XẾP (MỚI)")).padding(.trailing, -12)
                Image(systemName: "sparkle").font(.system(size: fs(8), weight: .bold)).foregroundColor(Theme.accentSolid)
                    .padding(.top, 9)
            }
            NavItem(p: .organize, vm: vm)
            }
            SectionTitle(text: "")
            NavItem(p: .settings, vm: vm)
            NavItem(p: .contact, vm: vm)
            }.padding(.bottom, 6)
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
                    LinearGradient(colors: [Theme.shade.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 22).allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottom) {
                if edges.moreBelow {
                    LinearGradient(colors: [.clear, Theme.shade.opacity(0.45)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 28).allowsHitTesting(false)
                }
            }
            // The "More" chip sits in its own row under the list, so it can never cover a menu item.
            if edges.moreBelow {
                Button { withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(Page.contact, anchor: .bottom) } } label: {
                    HStack(spacing: 4) {
                        Text(t("More", "Xem thêm")).font(.system(size: fs(10), weight: .semibold))
                        Image(systemName: "chevron.down").font(.system(size: fs(9), weight: .bold))
                    }
                    .foregroundColor(Theme.ink.opacity(0.85))
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.ink.opacity(0.14)))
                }.buttonStyle(.plain).hoverLift().padding(.vertical, 4).frame(maxWidth: .infinity)
            }
            }
            }
            Divider().overlay(Theme.ink.opacity(0.08)).padding(.bottom, 10)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Macintosh HD").font(.system(size: fs(11))).foregroundColor(Theme.sub)
                    Spacer()
                    LangSwitch(vm: vm)
                }
                (Text(String(format: t("%.0f GB free", "Trống %.0f GB"), vm.freeGB)).font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                 + Text(String(format: " / %.0f GB", vm.totalGB)).font(.system(size: fs(12))).foregroundColor(Theme.sub))
                DiskBar(free: vm.freeGB, total: vm.totalGB, low: vm.freeGB > 0 && vm.freeGB < vm.lowSpaceGB,
                        usedColor: Theme.ink.opacity(0.28))
                Text(String(format: t("%.0f GB used", "Đã dùng %.0f GB"), max(0, vm.totalGB - vm.freeGB)))
                    .font(.system(size: fs(10))).foregroundColor(Theme.sub)
            }.padding(.bottom, 16)
        }
        .padding(.horizontal, 14).frame(width: 120 + 140 * uiScale).background(Theme.sidebar)  // fixed parts (padding, icon, badge) do not scale, only the label does
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
                case .byapp: ByAppView(vm: vm)
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
                case .organize: OrganizeView(vm: vm)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.bg)
        .frame(minWidth: 980 * uiScale, minHeight: 600)
        .id(vm.theme + vm.textSize)
        .preferredColorScheme(Theme.p.light ? .light : .dark)
        .ignoresSafeArea()
        .onAppear { vm.checkUpdates() }
    }
}

/// Update check: one request a day to GitHub's public releases endpoint. Nothing about the Mac is sent;
/// the app only reads the latest version number and shows a line if it is newer. No auto-install.
enum Updates {
    static let api = URL(string: "https://api.github.com/repos/HaiTrung-Workspace/tidymint/releases/latest")!
    static let page = URL(string: "https://github.com/HaiTrung-Workspace/tidymint/releases/latest")!
    static var current: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }
    static func parts(_ v: String) -> [Int] { v.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").map { Int($0) ?? 0 } }
    static func newer(_ a: String, than b: String) -> Bool {
        let x = parts(a), y = parts(b)
        for i in 0..<max(x.count, y.count) { let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0; if p != q { return p > q } }
        return false
    }
    /// Calls back with the newer version string, or nil. Skips the network when the last check was under a day ago.
    static func check(force: Bool = false, _ done: @escaping (String?) -> Void) {
        let ud = UserDefaults.standard
        let last = ud.object(forKey: "upd-last") as? Date ?? .distantPast
        if !force, Date().timeIntervalSince(last) < 86400 {
            let cached = ud.string(forKey: "upd-latest") ?? ""
            done(newer(cached, than: current) ? cached : nil); return
        }
        // The website copy is tried first: it is a plain text file on the same host as the docs and reachable
        // on networks where api.github.com is slow or blocked. GitHub's API is the fallback.
        var req = URLRequest(url: site); req.timeoutInterval = 6; req.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200, let d = data, let v = String(data: d, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !parts(v).isEmpty {
                DispatchQueue.main.async { record(v, done) }; return
            }
            var r2 = URLRequest(url: api); r2.timeoutInterval = 8
            r2.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            URLSession.shared.dataTask(with: r2) { data, _, _ in
                var tag: String? = nil
                if let d = data, let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let tg = j["tag_name"] as? String { tag = tg }
                DispatchQueue.main.async { if let tg = tag { record(tg, done) } else { done(nil) } }
            }.resume()
        }.resume()
    }
    static let site = URL(string: "https://tidymint.app/version.txt")!
    private static func record(_ v: String, _ done: (String?) -> Void) {
        let ud = UserDefaults.standard
        ud.set(Date(), forKey: "upd-last"); ud.set(v, forKey: "upd-latest")
        done(newer(v, than: current) ? v : nil)
    }
}

// MARK: - Uninstaller page

struct AppsView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(t("Uninstaller", "Gỡ app")).font(.system(size: fs(22), weight: .bold)).foregroundColor(Theme.text)
                Spacer()
                Picker("", selection: $vm.appsTab) {
                    Text(t("Apps", "App") + " (\(vm.apps.count))").tag(0)
                    Text(t("Leftovers", "File sót") + " (\(vm.leftovers.count))").tag(1)
                    Text(t("Installers", "File cài đặt") + " (\(vm.installers.count))").tag(2)
                }.pickerStyle(.segmented).frame(width: 360)
                if vm.appsBusy { ProgressView().controlSize(.small).tint(Theme.text).padding(.leading, 6) }
                Button { vm.scanApps() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.icon).tip(t("Scan again", "Quét lại"), trailing: true).foregroundColor(Theme.text).padding(.leading, 6)
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 10)
            DoneBanner(vm: vm, page: .apps)
            if !vm.appsMsg.isEmpty {
                Text(vm.appsMsg).font(.system(size: fs(12))).foregroundColor(Theme.green).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.bottom, 6)
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
            HStack(spacing: 8) {
                Menu {
                    ForEach(0..<5, id: \.self) { f in
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
                                if let d = a.lastUsed {
                                    Text(t("Last opened ", "Mở lần cuối ") + shortDate(d)).foregroundColor(Theme.sub).font(.system(size: fs(10)))
                                } else {
                                    Text(t("Never opened", "Chưa mở lần nào")).foregroundColor(Theme.sub).font(.system(size: fs(10)))
                                }
                            }
                            Spacer()
                            Text(fmt(a.size)).foregroundColor(Theme.sub).font(.system(size: fs(12)).monospacedDigit())
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(vm.selApp == a.id ? Theme.cardHi : Color.clear))
                        .hoverBG(8, Theme.ink.opacity(0.07))
                        .contentShape(Rectangle())
                        .onTapGesture { vm.loadRelated(a.id) }
                    }
                }.padding(.horizontal, 12)
            }
            }.frame(width: 320 * uiScale).background(Theme.shade.opacity(0.15))

            if let i = vm.apps.firstIndex(where: { $0.id == vm.selApp }) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: vm.apps[i].url.path)).resizable().frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vm.apps[i].name).font(.system(size: fs(18), weight: .bold)).foregroundColor(Theme.text)
                            Text(vm.apps[i].bundleID).font(.system(size: fs(11))).foregroundColor(Theme.sub)
                        }
                    }.padding(20)
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
                            if vm.apps[i].related.isEmpty {
                                Text(t("No related files found in Library.", "Không thấy file liên quan trong Library."))
                                    .font(.system(size: fs(12))).foregroundColor(Theme.sub).padding(12)
                            }
                        }.padding(.horizontal, 12)
                    }
                    HStack {
                        let tot = vm.apps[i].size + vm.apps[i].related.filter(\.selected).reduce(0) { $0 + $1.size }
                        Text(selLabel(1 + vm.apps[i].related.filter(\.selected).count, tot)).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                        Spacer()
                        PrimaryButton(title: t("Uninstall", "Gỡ app"), action: { vm.uninstall(vm.apps[i].id) })
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
         t("From the App Store", "Từ App Store"), t("Other sources", "Nguồn khác")][f]
    }

    func listTab(_ which: Int) -> some View {
        let items = which == 1 ? $vm.leftovers : $vm.installers
        let sel = (which == 1 ? vm.leftovers : vm.installers).filter(\.selected).reduce(0) { $0 + $1.size }
        return VStack(spacing: 0) {
            Text(which == 1
                 ? t("Files left behind by apps that are no longer installed.", "File do các app đã gỡ để lại.")
                 : t("Installer files (.dmg, .pkg) in Downloads, Desktop and Documents. Safe to remove once the app is installed.",
                     "File cài đặt (.dmg, .pkg) trong Downloads, Desktop, Documents. Cài xong app rồi thì xoá được."))
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

// MARK: - Duplicates page

struct DupesView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Duplicates", "File trùng")).font(.system(size: fs(22), weight: .bold)).foregroundColor(Theme.text)
                    Text(t("Identical files (same content, any name) over 1 MB in Documents, Downloads, Desktop, Pictures, Movies, Music.",
                           "File giống hệt nhau về nội dung (dù khác tên), trên 1 MB, trong Documents, Downloads, Desktop, Pictures, Movies, Music."))
                        .font(.system(size: fs(12))).foregroundColor(Theme.sub)
                }
                Spacer()
                Menu(t("Select", "Chọn")) {
                    Button(t("Select all duplicates (keep one)", "Chọn mọi bản trùng (giữ 1 bản)")) { vm.dupAutoSelect(all: true) }
                    Button(t("Deselect all", "Bỏ chọn tất cả")) { vm.dupAutoSelect(all: false) }
                }.menuStyle(.borderlessButton).frame(width: 70).foregroundColor(Theme.text).padding(.vertical, 3).hoverTile()
                Button { vm.scanDupes() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.icon).tip(t("Scan again", "Quét lại"), trailing: true).foregroundColor(Theme.text).padding(.leading, 6)
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 10)
            DoneBanner(vm: vm, page: .dupes)
            if !vm.dupMsg.isEmpty {
                Text(vm.dupMsg).font(.system(size: fs(12))).foregroundColor(Theme.green).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.bottom, 6)
            }
            if vm.dupBusy {
                Scanning(text: t("Comparing files... \(vm.dupCount) checked", "Đang so file... đã xem \(vm.dupCount)")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.dupes.isEmpty {
                VStack(spacing: 24) {
                    BigScanButton(label: t("Scan", "Quét")) { vm.scanDupes() }
                    Text(t("Files inside your project folders are never pre-selected.", "File trong thư mục dự án không bao giờ được tick sẵn.")).font(.system(size: fs(12))).foregroundColor(Theme.sub)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text(t("\(vm.dupes.count) groups, \(fmt(vm.dupWasted)) taken by extra copies. The first file of each group is the one suggested to keep.",
                       "\(vm.dupes.count) nhóm, \(fmt(vm.dupWasted)) bị chiếm bởi các bản thừa. File đầu tiên mỗi nhóm là bản đề xuất giữ lại."))
                    .font(.system(size: fs(12))).foregroundColor(Theme.sub).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.bottom, 8)
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach($vm.dupes) { $g in
                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    Button { vm.dupToggleGroup(g.id) } label: { CheckBox(state: vm.dupGroupState(g)) }.buttonStyle(.plain)
                                    FileThumb(url: g.items[0].url, side: 30 * uiScale)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(g.items[0].name).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .semibold)).lineLimit(1)
                                        Text(t("\(g.items.count) copies × \(fmt(g.size))", "\(g.items.count) bản × \(fmt(g.size))")).foregroundColor(Theme.sub).font(.system(size: fs(11)))
                                    }
                                    Spacer()
                                    Text(t("extra ", "thừa ") + fmt(g.wasted)).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .medium).monospacedDigit())
                                    Image(systemName: "chevron.down").rotationEffect(.degrees(g.expanded ? 0 : -90)).foregroundColor(Theme.sub)
                                }
                                .padding(12).hoverBG(14, Theme.ink.opacity(0.06)).contentShape(Rectangle())
                                .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { g.expanded.toggle() } }
                                if g.expanded {
                                    Divider().background(Theme.ink.opacity(0.1))
                                    ForEach(Array($g.items.enumerated()), id: \.element.id) { idx, $it in
                                        HStack(spacing: 0) {
                                            ItemRow(item: $it, vm: vm, showDate: true)
                                            if idx == 0 {
                                                Text(t("Keep", "Giữ")).font(.system(size: fs(10), weight: .semibold)).foregroundColor(Theme.green)
                                                    .padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(Theme.green.opacity(0.15))).padding(.trailing, 10)
                                            }
                                        }
                                    }.padding(.leading, 14)
                                }
                            }.background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                        }
                    }.padding(.horizontal, 24).padding(.bottom, 16)
                }
                if vm.refsBusy {
                    // The link check greps every project folder, which can take minutes. Say so where the eye is.
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small).tint(Theme.warn)
                        Text(t("Checking links in your project folders, this can take a few minutes. Feel free to use other pages meanwhile.",
                               "Đang kiểm tra liên kết trong thư mục dự án, có thể mất vài phút. Bạn cứ dùng trang khác trong lúc chờ."))
                            .font(.system(size: fs(12))).foregroundColor(Theme.text).fixedSize(horizontal: false, vertical: true)
                    }.padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Theme.warn.opacity(0.12))).padding(.horizontal, 24).padding(.bottom, 8)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selLabel(vm.dupes.reduce(0) { $0 + $1.items.filter(\.selected).count }, vm.dupSelected)).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                        Text(t("At least one copy of every file is always kept.", "Mỗi file luôn giữ lại ít nhất một bản.")).foregroundColor(Theme.sub).font(.system(size: fs(11)))
                    }
                    Spacer()
                    GhostButton(title: vm.dupAllExtrasSelected ? t("Deselect all", "Bỏ chọn tất cả") : t("Select all extra copies", "Chọn mọi bản thừa")) {
                        vm.dupAutoSelect(all: !vm.dupAllExtrasSelected)
                    }.padding(.trailing, 8).disabled(vm.refsBusy)
                    PrimaryButton(title: t("Move to Trash", "Chuyển vào Thùng rác"), action: { vm.cleanDupes() }, disabled: vm.dupSelected == 0 || vm.refsBusy)
                }.padding(.horizontal, 24).padding(.vertical, 14).background(Theme.shade.opacity(0.25))
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
                    Text(t("Cloud Cleanup", "Dữ liệu đám mây")).font(.system(size: fs(22), weight: .bold)).foregroundColor(Theme.text)
                    Text(t("How much of Google Drive, iCloud and other cloud folders is stored on this Mac. Files that live only in the cloud count as 0.",
                           "Google Drive, iCloud và các thư mục mây đang chiếm bao nhiêu trên máy. File chỉ nằm trên mây tính là 0."))
                        .foregroundColor(Theme.sub).font(.system(size: fs(12)))
                }
                Spacer()
                if vm.cloudBusy { ProgressView().controlSize(.small).tint(Theme.text) }
                Button { vm.scanCloud() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.icon).tip(t("Scan again", "Quét lại"), trailing: true).foregroundColor(Theme.text)
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 12)
            if !vm.cloudMsg.isEmpty {
                Text(vm.cloudMsg).font(.system(size: fs(12))).foregroundColor(Theme.green).padding(.horizontal, 24).padding(.bottom, 8)
            }
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach($vm.clouds) { $p in
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Image(systemName: p.isICloud ? "icloud.fill" : "externaldrive.connected.to.line.below")
                                    .font(.system(size: fs(18))).foregroundStyle(Theme.accent).frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).foregroundColor(Theme.text).font(.system(size: fs(14), weight: .semibold))
                                    if !p.account.isEmpty { Text(p.account).foregroundColor(Theme.sub).font(.system(size: fs(11))) }
                                }
                                Spacer()
                                Text(t("on this Mac: ", "trên máy: ")).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                                Text(fmt(p.local)).foregroundColor(Theme.text).font(.system(size: fs(14), weight: .semibold).monospacedDigit())
                                Image(systemName: "chevron.down").rotationEffect(.degrees(p.expanded ? 0 : -90)).foregroundColor(Theme.sub)
                            }
                            .padding(14).hoverBG(14, Theme.ink.opacity(0.06)).contentShape(Rectangle())
                            .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { p.expanded.toggle() } }
                            if p.expanded {
                                Divider().background(Theme.ink.opacity(0.1))
                                if !p.isICloud {
                                    Text(t("macOS only lets the Drive app remove downloads. Click Show in Finder, then right-click > Remove Download.",
                                           "macOS chỉ cho app Drive gỡ bản tải xuống. Bấm Mở trong Finder, rồi chuột phải > Remove Download (Xoá bản tải xuống)."))
                                        .font(.system(size: fs(11))).foregroundColor(Theme.warn).padding(.horizontal, 14).padding(.top, 8)
                                }
                                if p.items.isEmpty {
                                    Text(t("Nothing stored locally.", "Không có gì lưu trên máy.")).font(.system(size: fs(12))).foregroundColor(Theme.sub).padding(14)
                                }
                                ForEach(p.items) { n in
                                    HStack(spacing: 10) {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: n.url.path)).resizable().frame(width: 20, height: 20)
                                        Text(n.url.lastPathComponent).foregroundColor(Theme.text).font(.system(size: fs(12))).lineLimit(1)
                                        Spacer()
                                        Text(fmt(n.size)).foregroundColor(Theme.sub).font(.system(size: fs(12)).monospacedDigit())
                                        if p.isICloud {
                                            TextLink(t("Remove Download", "Xoá bản trên máy"), size: 11, weight: .semibold) { vm.evictICloud(n.url) }
                                        }
                                        TextLink(t("Show in Finder", "Mở trong Finder"), size: 11, weight: .regular, color: Theme.ink.opacity(0.8)) { vm.reveal(n.url) }
                                    }.padding(.horizontal, 14).padding(.vertical, 6).hoverBG(8, Theme.ink.opacity(0.07))
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
            Text(t("Settings", "Cài đặt")).font(.system(size: fs(22), weight: .bold)).foregroundColor(Theme.text).padding(.top, 34)
            settingRow(t("Theme", "Giao diện màu"), "") {
                HStack(spacing: 10) {
                    ForEach(palettes, id: \.id) { pl in
                        Button { vm.setTheme(pl.id) } label: {
                            VStack(spacing: 4) {
                                Circle().fill(LinearGradient(colors: pl.bg.map { Color(hex: $0) } + pl.accent.suffix(1).map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 30, height: 30)
                                    .overlay(Circle().stroke(Theme.ink.opacity(vm.theme == pl.id ? 0.95 : 0.25), lineWidth: vm.theme == pl.id ? 2 : 1))
                                Text(appLang == "vi" ? pl.nameVI.components(separatedBy: " (").first ?? pl.nameVI : pl.nameEN)
                                    .font(.system(size: fs(10))).foregroundColor(vm.theme == pl.id ? Theme.text : Theme.sub)
                            }
                        }.buttonStyle(.plain).hoverLift().tip(appLang == "vi" ? pl.nameVI : pl.nameEN)
                    }
                }
            }
            settingRow(t("Text size", "Cỡ chữ"), "") {
                Picker("", selection: Binding(get: { vm.textSize }, set: { vm.setTextSize($0) })) {
                    Text(t("Small", "Nhỏ")).tag("small")
                    Text(t("Default", "Mặc định")).tag("default")
                    Text(t("Large", "Lớn")).tag("large")
                }.pickerStyle(.segmented).labelsHidden().frame(width: 240 * uiScale)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("Project folders", "Thư mục dự án")).foregroundColor(Theme.text).font(.system(size: fs(14), weight: .semibold))
                        Text(t("Where you keep code or AI workspaces. Drafts (_tmp, _to_delete) are found here, duplicates here are never pre-selected, and links are checked here before deleting.",
                               "Nơi chứa code hoặc thư mục làm việc với AI. App tìm nháp (_tmp, _to_delete) ở đây, không tick sẵn file trùng ở đây, và kiểm tra liên kết ở đây trước khi xoá."))
                            .foregroundColor(Theme.sub).font(.system(size: fs(11))).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    GhostButton(title: t("Add folder", "Thêm thư mục"), action: { vm.addProjectFolder() }, width: Pill.rowWidth)
                }
                ForEach(vm.projects, id: \.self) { p in
                    HStack(spacing: 8) {
                        Image(systemName: "folder").foregroundColor(Theme.link)
                        Text(p.replacingOccurrences(of: NSHomeDirectory(), with: "~")).foregroundColor(Theme.text).font(.system(size: fs(12))).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        TextLink(t("Remove", "Gỡ")) { vm.removeProjectFolder(p) }
                    }.padding(.horizontal, 10).padding(.vertical, 5).hoverBG(8, Theme.ink.opacity(0.06))
                }
            }.padding(14).background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            settingRow(t("Full Disk Access", "Truy cập toàn bộ ổ đĩa"),
                       vm.fullDiskAccess ? t("On. Mail, Safari and Messages are measured too.", "Đã bật. Mail, Safari, Tin nhắn cũng được đo.")
                                         : t("Off, so Mail, Safari and Messages stay hidden from scans. Turn on Tidymint in System Settings, then come back.",
                                             "Chưa bật, nên Mail, Safari, Tin nhắn bị ẩn khỏi lượt quét. Bật Tidymint trong Cài đặt hệ thống rồi quay lại.")) {
                if vm.fullDiskAccess {
                    Label(t("On", "Đã bật"), systemImage: "checkmark.circle.fill").font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.green)
                } else {
                    PrimaryButton(title: t("Open Settings", "Mở Cài đặt"), action: { NSWorkspace.shared.open(VM.fdaSettings) }, width: Pill.rowWidth)
                }
            }
            settingRow(t("Version \(Updates.current)", "Phiên bản \(Updates.current)"),
                       vm.newVersion != nil ? t("Version \(vm.newVersion!) is available on GitHub. Download it and drag it over the old one.", "Đã có bản \(vm.newVersion!) trên GitHub. Tải về rồi kéo đè lên bản cũ.")
                                            : t("Checks GitHub once a day for a new version; nothing about your Mac is sent.\n\nTidymint is free and will stay free. Sponsorships go toward the Apple Developer account ($99/year): with it, Apple verifies the app, new users just open it and it runs, no trip to Settings > Security, and each update reaches you faster.",
                                                "Kiểm tra bản mới mỗi ngày một lần trên GitHub, không gửi thông tin gì về máy.\n\nTidymint miễn phí và sẽ luôn miễn phí. Mỗi khoản ủng hộ góp vào tài khoản Apple Developer (99 USD/năm): có nó, app được Apple xác nhận, người mới cài chỉ cần mở là chạy, không phải qua bước Cài đặt > Bảo mật, và mỗi bản cập nhật tới tay bạn nhanh hơn.")) {
                VStack(alignment: .trailing, spacing: 10) {
                    HStack(spacing: 10) {
                        if vm.updChecking { ProgressView().controlSize(.small).tint(Theme.text) }
                        if vm.newVersion != nil { PrimaryButton(title: t("Download", "Tải về"), action: { NSWorkspace.shared.open(Updates.page) }, width: Pill.rowWidth) }
                        else { GhostButton(title: t("Check now", "Kiểm tra ngay"), action: { vm.checkUpdates(force: true) }, width: Pill.rowWidth) }
                    }
                    PrimaryButton(title: t("Support the project", "Ủng hộ dự án"), action: { NSWorkspace.shared.open(sponsorURL("button")) }, width: Pill.rowWidth)
                }
            }
            settingRow(t("Open at login", "Mở cùng máy"),
                       t("Keeps the menu bar monitor running after restart.", "Giữ biểu tượng theo dõi trên thanh menu sau khi khởi động lại máy.")) {
                Toggle("", isOn: Binding(get: { vm.openAtLogin }, set: { vm.setOpenAtLogin($0) })).toggleStyle(.switch).labelsHidden()
            }
            settingRow(t("Low disk space alert", "Cảnh báo ổ sắp đầy"),
                       vm.lowSpaceGB > 0
                       ? String(format: t("Notify when free space drops below %.0f GB (at most every 6 hours). Enter 0 to turn off.", "Báo khi dung lượng trống dưới %.0f GB (tối đa 6 giờ báo một lần). Nhập 0 để tắt."), vm.lowSpaceGB)
                       : t("Off. Enter a number of GB to be notified when free space drops below it.", "Đang tắt. Nhập số GB để được báo khi dung lượng trống xuống dưới mức đó.")) {
                HStack(spacing: 6) {
                    TextField("0", text: Binding(get: { vm.lowSpaceGB > 0 ? String(Int(vm.lowSpaceGB)) : "" },
                                                 set: { vm.setLowSpace(min(10_000, max(0, Double($0.filter(\.isNumber)) ?? 0))) }))
                        .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 64)
                    Text("GB").foregroundColor(Theme.sub).font(.system(size: fs(12)))
                }
            }
            settingRow(t("High memory alert", "Cảnh báo RAM cao"),
                       t("Notify when more than 90% of RAM is in use (at most once an hour).", "Báo khi RAM dùng trên 90% (tối đa 1 giờ báo một lần).")) {
                Toggle("", isOn: Binding(get: { vm.ramAlert }, set: { vm.setRamAlert($0) })).toggleStyle(.switch).labelsHidden()
            }
            if appLang == "vi" {
                settingRow("Cùng tác giả: Cồn Cào", "Kiến thức đồ uống: whisky, sake, cocktail.") {
                    TextLink("concao.org", url: ConCao.url("settings"))
                }
            }
        }.padding(.horizontal, 24).padding(.bottom, 24).frame(maxWidth: .infinity, alignment: .leading) }
    }
    func settingRow<C: View>(_ title: String, _ sub: String, @ViewBuilder _ control: () -> C) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).foregroundColor(Theme.text).font(.system(size: fs(14), weight: .semibold))
                if !sub.isEmpty { Text(sub).foregroundColor(Theme.sub).font(.system(size: fs(11))).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 16)
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
            HStack { Text(label).foregroundColor(.secondary); Spacer(); Text(value).fontWeight(.semibold) }.font(.system(size: fs(12)))
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
                (Text("Tidy") + Text("mint").foregroundColor(Theme.brandMint)).font(.system(size: fs(13), weight: .bold))
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text(t("Disk", "Ổ đĩa")).foregroundColor(.secondary); Spacer()
                    Text(String(format: t("%.0f GB free / %.0f GB", "Trống %.0f / %.0f GB"), vm.freeGB, vm.totalGB)).fontWeight(.semibold) }
                    .font(.system(size: fs(12)))
                DiskBar(free: vm.freeGB, total: vm.totalGB, low: vm.freeGB > 0 && vm.freeGB < vm.lowSpaceGB)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text("RAM").foregroundColor(.secondary); Spacer()
                    Text(String(format: t("%.1f GB free / %.0f GB", "Trống %.1f / %.0f GB"), max(0, vm.ramTotal - vm.ramUsed), vm.ramTotal)).fontWeight(.semibold) }
                    .font(.system(size: fs(12)))
                DiskBar(free: max(0, vm.ramTotal - vm.ramUsed), total: vm.ramTotal, low: vm.ramTotal > 0 && vm.ramUsed / vm.ramTotal > 0.9)
            }
            HStack { Text(t("Trash", "Thùng rác")).foregroundColor(.secondary); Spacer(); Text(fmt(vm.trashSize)).fontWeight(.semibold) }.font(.system(size: fs(12)))
            Divider()
            VStack(spacing: 1) {
                MenuRow(title: t("Open Tidymint", "Mở Tidymint")) { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
                MenuRow(title: t("Clean Now", "Dọn ngay")) { vm.page = .smart; openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true); vm.smartScan() }
                MenuRow(title: t("Empty Trash...", "Đổ Thùng rác..."), disabled: vm.trashCount == 0) { NSApp.activate(ignoringOtherApps: true); vm.emptyTrash() }
            }.padding(.horizontal, -8)
            Divider()
            VStack(spacing: 1) {
                MenuRow(title: t("Support the project", "Ủng hộ dự án")) { NSWorkspace.shared.open(sponsorURL("menubar")) }
                MenuRow(title: t("Quit", "Thoát")) { NSApp.terminate(nil) }
            }.padding(.horizontal, -8)
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
    func applicationDidBecomeActive(_ n: Notification) {
        if !CommandLine.arguments.contains("--demo") { sharedVM.checkFullDiskAccess() }
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        // Developer helper: `Tidymint --export-icon <theme> <out.png>` writes the 1024px icon and quits.
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "--export-icon"), i + 2 < a.count,
           let pal = palettes.first(where: { $0.id == a[i + 1] }),
           let tiff = makeAppIcon(pal).tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: a[i + 2])); exit(0)
        }
        // Developer helper: `Tidymint --export-menubar <freeGB> <out.png>` writes the menu bar icon at 8x and quits.
        if let i = a.firstIndex(of: "--export-menubar"), i + 2 < a.count, let f = Double(a[i + 1]) {
            let im = menuBarImage(free: f, total: 245, low: false)
            let px = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(im.size.width * 8), pixelsHigh: Int(im.size.height * 8),
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            px.size = im.size
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: px)
            im.draw(in: NSRect(origin: .zero, size: im.size)); NSGraphicsContext.restoreGraphicsState()
            try? px.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: a[i + 2])); exit(0)
        }
        // Single instance: a second copy (typically an older build still running after an update) is asked to quit,
        // so the menu bar never shows two Tidymint icons. Screenshot/demo runs are exempt so tooling can run beside a live app.
        if !a.contains("--demo"), let bid = Bundle.main.bundleIdentifier {
            let me = ProcessInfo.processInfo.processIdentifier
            for other in NSRunningApplication.runningApplications(withBundleIdentifier: bid) where other.processIdentifier != me {
                other.terminate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { if !other.isTerminated { other.forceTerminate() } }
            }
        }
        NSApp.applicationIconImage = makeAppIcon(Theme.p)
        if !a.contains("--demo") { sharedVM.checkFullDiskAccess() }
        // Developer helper for README screenshots: `--demo` fills every page with sample data (no real files),
        // `--page <name> --window <W>x<H>` opens a page at a fixed size.
        if let i = a.firstIndex(of: "--export-icon"), i + 1 < a.count {
            // Writes the 1024px app icon for Resources/AppIcon.png, then quits. Used by build tooling.
            let img = makeAppIcon(Theme.p)
            if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: a[i + 1]))
            }
            exit(0)
        }
        if a.contains("--demo") { Demo.load(sharedVM) }
        // `--watch-folder <dir>` watches a test folder instead of Downloads.
        if let j = a.firstIndex(of: "--watch-folder"), j + 1 < a.count { OrgVM.watchDir = URL(fileURLWithPath: a[j + 1]) }
        OrgNotifier.shared.install()
        if featureOrganize && sharedOrg.watchDownloads { sharedOrg.vm = sharedVM; sharedOrg.startWatch(catchUp: true) }
        if let i = a.firstIndex(of: "--page"), i + 1 < a.count,
           let pg = Page.allCases.first(where: { "\($0)" == a[i + 1] }) {
            sharedVM.page = pg
            if pg == .cleanup && a.contains("--demo") { sharedVM.phase = a.contains("--done") ? .done : .review }
            if pg == .byapp && a.contains("--demo") { Demo.apps(sharedVM, detail: a.contains("--detail")) }
            if pg == .organize && a.contains("--demo") { Demo.organize(sharedOrg) }
            if pg == .lens && a.contains("--sysdata") { sharedVM.openSys() }
            // `--organize <folder>` plans a real folder right away (used to test the organizer on sample files).
            if pg == .organize, let j = a.firstIndex(of: "--organize"), j + 1 < a.count { sharedOrg.folder = URL(fileURLWithPath: a[j + 1]); sharedOrg.vm = sharedVM
                if a.contains("--organize-undo") { sharedOrg.undo() }
                else {
                    sharedOrg.plan()
                    // `--organize-apply`: apply the plan as soon as it is ready (test helper).
                    if a.contains("--organize-rule") {
                        Task { @MainActor in
                            while sharedOrg.phase != .review { try? await Task.sleep(nanoseconds: 300_000_000) }
                            try? await Task.sleep(nanoseconds: 800_000_000); sharedOrg.showRule = true
                        }
                    }
                    // `--organize-tree`: open the plan as folder trees; `--organize-reveal-check`: jump from the tree to the first file to check.
                    if a.contains("--organize-tree") || a.contains("--organize-reveal-check") {
                        let reveal = a.contains("--organize-reveal-check")
                        Task { @MainActor in
                            while sharedOrg.phase != .review { try? await Task.sleep(nanoseconds: 300_000_000) }
                            sharedOrg.treeView = true
                            if reveal, let f = sharedOrg.files.last(where: { $0.include && $0.warn != nil }) {
                                try? await Task.sleep(nanoseconds: 1_000_000_000); sharedOrg.reveal(f.id)
                            }
                        }
                    }
                    // `--organize-show check|rename`: open the plan filtered (test helper).
                    if let k = a.firstIndex(of: "--organize-show"), k + 1 < a.count {
                        let v: OrgVM.Show = a[k + 1] == "check" ? .check : .rename
                        Task { @MainActor in
                            while sharedOrg.phase != .review { try? await Task.sleep(nanoseconds: 300_000_000) }
                            sharedOrg.show = v
                        }
                    }
                    if a.contains("--organize-apply") {
                        // `--organize-apply-after <s>`: wait a few seconds after planning (a test removes a file meanwhile).
                        let wait = a.firstIndex(of: "--organize-apply-after").flatMap { k in k + 1 < a.count ? Double(a[k + 1]) : nil } ?? 0
                        Task { @MainActor in
                            while sharedOrg.phase != .review { try? await Task.sleep(nanoseconds: 300_000_000) }
                            if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1e9)) }
                            sharedOrg.apply()
                        }
                    }
                }
            }
            if pg == .smart && a.contains("--demo") { sharedVM.phase = a.contains("--done") ? .done : .summary; sharedVM.lastFreed = sharedVM.junkSelected; sharedVM.lastCount = 38 }
            if a.contains("--done") { sharedVM.lastResult = t("Moved 128 items (6.2 GB) to the Trash.", "Đã chuyển 128 mục (6,2 GB) vào Thùng rác.") }
        }
        if let i = a.firstIndex(of: "--window"), i + 1 < a.count {
            let wh = a[i + 1].split(separator: "x").compactMap { Double($0) }
            if wh.count == 2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    for w in NSApp.windows where w.title == "Tidymint" || w.identifier?.rawValue.contains("main") == true {
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

/// Organize (folder sorting) ships in 0.4.0. Until then it is hidden for everyone except Macs that opt in for testing:
/// `defaults write com.haitrung.diskcleanup dev-organize -bool true` (turn off with `defaults delete com.haitrung.diskcleanup dev-organize`).
var featureOrganize: Bool { UserDefaults.standard.bool(forKey: "dev-organize") }

func makeAppIcon(_ p: Palette) -> NSImage {
    let img = NSImage(size: NSSize(width: 1024, height: 1024), flipped: true) { _ in
        // "dark" tints ports, veins and shadows; on a light palette it is a graphite grey, not the pale background.
        let dark = p.light ? NSColor(hex: 0x2b3431) : NSColor(hex: p.bg[0])
        // Mac mini body: white on dark palettes, Apple-style silver on light ones so it stands out from the pale tile.
        let shell = p.light ? NSColor(hex: 0xc9ccd0) : NSColor.white.withAlphaComponent(0.92)
        let body = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 190, yRadius: 190)
        // No drop shadow around the tile: macOS adds its own in the Dock, and in-app the halo shows on light backgrounds.
        (p.light ? NSColor(hex: p.icon[0]) : dark).setFill(); body.fill()
        let sh = NSShadow(); sh.shadowOffset = NSSize(width: 0, height: -16); sh.shadowBlurRadius = 40
        let cols = p.icon.map { NSColor(hex: $0) }
        let locs = (0..<cols.count).map { CGFloat($0) / CGFloat(max(cols.count - 1, 1)) }
        NSGradient(colors: cols, atLocations: locs, colorSpace: .sRGB)?.draw(in: body, angle: p.id == "pride" ? 90 : -45)
        NSGradient(colors: [NSColor.white.withAlphaComponent(0.14), NSColor.white.withAlphaComponent(0)],
                   atLocations: [0, 0.45], colorSpace: .sRGB)?.draw(in: body, angle: 90)
        // recessed foot
        dark.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: NSRect(x: 262, y: 688, width: 500, height: 22), xRadius: 10, yRadius: 10).fill()
        // body (2.54:1)
        let mini = NSBezierPath(roundedRect: NSRect(x: 222, y: 460, width: 580, height: 228), xRadius: 40, yRadius: 40)
        NSGraphicsContext.saveGraphicsState(); sh.shadowColor = NSColor.black.withAlphaComponent(0.35); sh.set()
        shell.setFill(); mini.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(colors: [NSColor.white.withAlphaComponent(p.light ? 0.45 : 0.0), dark.withAlphaComponent(p.light ? 0.22 : 0.18)], atLocations: [0, 1], colorSpace: .sRGB)?
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
        // Mint leaf above the Mac mini (Creative Fabrica leaf approved 28/10, same outline as docs/logo.svg):
        // the open vein is part of the outline, so the leaf takes the palette colour with no extra strokes.
        let lp: [CGFloat] = [
            708.0,168.0, 705.5,168.5, 701.7,169.6, 696.6,171.9, 691.9,174.8, 686.9,178.9, 682.4,183.6, 678.3,189.0, 674.5,195.0, 671.6,201.1,
            671.1,201.1, 670.6,200.8, 669.4,199.5, 668.8,198.4, 667.4,195.2, 666.3,191.6, 662.5,193.4, 657.8,196.8, 655.5,198.8, 652.6,202.0,
            649.8,205.5, 647.6,209.0, 643.7,216.6, 642.1,220.7, 640.9,224.9, 640.7,224.8, 636.0,213.7, 629.8,218.8, 625.3,223.2, 621.7,227.4,
            616.7,234.4, 614.0,239.2, 611.5,244.5, 609.5,250.1, 608.1,255.1, 607.4,258.7, 607.2,261.3, 606.9,261.3, 601.4,248.4, 601.1,248.6,
            599.5,251.0, 597.2,254.8, 595.2,258.9, 592.7,265.0, 590.9,270.8, 589.5,276.5, 588.4,283.4, 587.7,291.8, 587.7,298.1, 587.9,300.1,
            587.5,300.1, 575.6,291.7, 575.4,291.9, 575.1,305.3, 575.2,309.8, 575.9,318.6, 576.6,324.5, 578.2,334.5, 580.0,343.1, 581.1,347.2,
            579.0,347.3, 576.5,346.9, 574.2,346.2, 570.8,344.6, 570.6,344.7, 572.3,353.1, 574.6,361.4, 576.2,366.1, 578.6,372.5, 581.6,378.8,
            586.6,387.7, 592.0,395.5, 597.7,402.3, 604.3,408.9, 611.1,414.5, 619.3,420.2, 619.7,426.6, 620.4,433.1, 620.6,433.7, 621.3,439.0,
            622.6,445.6, 625.6,455.7, 627.2,460.0, 629.4,465.1, 629.5,464.9, 629.3,464.3, 628.6,459.1, 628.2,452.1, 628.2,446.0, 628.6,438.6,
            630.2,427.2, 631.6,420.7, 633.8,412.0, 636.3,404.2, 638.8,397.4, 642.0,389.7, 646.8,379.4, 654.7,364.0, 668.8,338.8, 676.5,324.4,
            683.5,309.9, 688.7,297.2, 691.0,290.8, 693.7,281.6, 695.3,274.9, 696.6,267.4, 697.6,259.9, 697.9,252.6, 697.8,244.7, 697.3,239.6,
            697.1,239.0, 697.2,237.8, 697.4,238.1, 698.3,243.8, 699.0,251.7, 699.0,261.7, 698.8,263.0, 698.8,265.4, 698.1,271.9, 696.5,281.5,
            695.2,287.7, 692.7,296.9, 688.4,309.7, 682.7,323.6, 676.4,337.6, 665.7,359.3, 659.4,372.8, 655.3,382.1, 651.2,392.3, 648.0,401.5,
            645.5,410.0, 643.0,421.0, 641.7,430.3, 646.5,431.5, 653.2,432.4, 664.0,432.4, 668.5,432.0, 674.1,431.1, 679.3,430.0, 685.0,428.4,
            690.4,426.6, 695.6,424.5, 705.6,419.8, 705.6,419.4, 704.6,419.2, 701.5,417.4, 698.8,415.0, 699.0,414.6, 701.9,414.5, 706.1,413.9,
            712.3,412.0, 716.1,410.5, 720.2,408.4, 727.4,403.9, 733.8,398.7, 737.9,394.7, 738.8,393.6, 736.9,394.7, 734.4,395.6, 731.7,396.1,
            728.9,396.1, 724.5,395.2, 721.6,394.0, 720.9,393.5, 726.9,390.5, 732.0,386.9, 737.8,381.3, 742.4,375.5, 746.5,369.3, 751.1,360.8,
            754.5,352.9, 757.2,344.6, 756.9,344.6, 755.2,345.7, 752.2,347.1, 750.1,347.5, 749.0,347.5, 747.2,346.9, 746.3,346.0, 745.7,344.5,
            748.3,342.0, 751.1,338.1, 752.9,334.7, 755.1,329.4, 757.4,322.6, 759.7,314.0, 762.0,301.4, 761.9,301.3, 760.9,302.0, 759.2,302.4,
            754.9,302.4, 749.2,301.4, 748.7,301.1, 750.8,298.5, 753.1,294.0, 754.9,288.0, 756.0,281.4, 756.5,276.4, 756.6,265.4, 756.3,257.8,
            755.4,249.4, 753.4,251.4, 750.8,253.0, 747.7,253.9, 746.0,254.0, 745.7,253.8, 746.0,250.4, 745.8,245.0, 744.7,235.6, 742.0,221.8,
            738.1,207.1, 737.8,207.1, 735.5,210.2, 732.4,213.3, 729.9,215.3, 729.3,215.3, 729.3,213.7, 728.8,210.8, 727.7,206.7, 725.7,201.0,
            723.4,195.8, 716.8,182.8, 711.6,173.8
        ]
        let leaf = NSBezierPath()
        leaf.move(to: NSPoint(x: lp[0], y: lp[1]))
        for i in stride(from: 2, to: lp.count, by: 2) { leaf.line(to: NSPoint(x: lp[i], y: lp[i + 1])) }
        leaf.close()
        NSColor(hex: p.leaf).setFill(); leaf.fill()
        return true
    }
    return img
}

extension NSBezierPath {
    /// Quadratic curve expressed as a cubic (NSBezierPath has no quadratic segment).
    func quad(to p: NSPoint, control q: NSPoint) {
        let p0 = currentPoint
        let c1 = NSPoint(x: p0.x + 2 / 3 * (q.x - p0.x), y: p0.y + 2 / 3 * (q.y - p0.y))
        let c2 = NSPoint(x: p.x + 2 / 3 * (q.x - p.x), y: p.y + 2 / 3 * (q.y - p.y))
        curve(to: p, controlPoint1: c1, controlPoint2: c2)
    }
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
        Window("Tidymint", id: "main") { RootView(vm: vm) }
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
                Text(t("Startup Items", "Khởi động cùng máy")).font(.system(size: fs(22), weight: .bold)).foregroundColor(Theme.text)
                Text(t("Background helpers that start with your Mac, each with who signed it. This is not antivirus: Tidymint states facts, you decide. For a second opinion use KnockKnock (free, open source) or Malwarebytes.",
                       "Các tiến trình chạy ngầm khi bật máy, kèm ai đã ký chúng. Đây không phải diệt virus: Tidymint chỉ nêu sự thật, bạn tự quyết. Muốn kiểm thêm, dùng KnockKnock (miễn phí, mã mở) hoặc Malwarebytes."))
                    .foregroundColor(Theme.sub).font(.system(size: fs(12)))
                HStack(spacing: 8) {
                    if vm.launchBusy { ProgressView().controlSize(.small).tint(Theme.text); Text(t("Checking signatures...", "Đang kiểm chữ ký...")).foregroundColor(Theme.sub).font(.system(size: fs(12))) }
                    else if vm.launchAttention > 0 {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.warn)
                        Text(t("\(vm.launchAttention) items worth a look. Hover a badge to see why.", "\(vm.launchAttention) mục đáng để ý. Rê chuột lên nhãn để xem lý do.")).foregroundColor(Theme.text).font(.system(size: fs(12)))
                    } else if !vm.launch.isEmpty {
                        Image(systemName: "checkmark.shield").foregroundColor(Theme.green)
                        Text(t("Nothing unusual in \(vm.launch.count) items.", "Không có gì bất thường trong \(vm.launch.count) mục.")).foregroundColor(Theme.text).font(.system(size: fs(12)))
                    }
                }.padding(.top, 4)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 12)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach([0, 1, 2], id: \.self) { sc in
                        let rows = vm.launch.indices.filter { vm.launch[$0].scope == sc }
                        if !rows.isEmpty {
                            Text(sc == 0 ? t("YOUR ACCOUNT (can remove here)", "CỦA TÀI KHOẢN CHÚ (gỡ được ở đây)")
                                 : sc == 1 ? t("ALL USERS · AGENTS (needs admin, remove via the app or Settings)", "CẢ MÁY · AGENT (cần quyền admin, gỡ bằng app gốc hoặc Cài đặt)")
                                 : t("ALL USERS · SYSTEM SERVICES (needs admin)", "CẢ MÁY · DỊCH VỤ HỆ THỐNG (cần quyền admin)"))
                                .font(.system(size: fs(10), weight: .semibold)).tracking(0.6).foregroundColor(Theme.sub).padding(.top, 10).padding(.leading, 4)
                            ForEach(rows, id: \.self) { i in LaunchRow(e: $vm.launch[i], vm: vm) }
                        }
                    }
                }.padding(.horizontal, 24).padding(.bottom, 12)
            }
            HStack(spacing: 12) {
                Text(vm.launchMsg.isEmpty ? t("\(vm.launch.count) items", "\(vm.launch.count) mục") : vm.launchMsg)
                    .foregroundColor(Theme.text).font(.system(size: fs(13))).lineLimit(2)
                Spacer()
                GhostButton(title: t("Open Login Items settings", "Mở cài đặt Mục đăng nhập")) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
                }
                PrimaryButton(title: t("Remove selected", "Gỡ mục đã chọn"), action: { vm.removeLaunch() },
                              disabled: !vm.launch.contains { $0.selected && $0.scope == 0 })
            }.padding(.horizontal, 24).padding(.vertical, 12).background(Theme.shade.opacity(0.25))
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
                Image(systemName: "lock.fill").font(.system(size: fs(12))).foregroundColor(Theme.sub).frame(width: 17)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(e.owner).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .medium)).lineLimit(1)
                    if e.orphan { badge(t("App removed", "App đã gỡ"), Theme.danger) }
                    if e.running == true { badge(t("Running", "Đang chạy"), Theme.green) }
                    if case .apple = e.sign {} else if !e.sign.label.isEmpty { badge(e.sign.label, e.sign.color).tip(e.sign.help) }
                    ForEach(e.flags, id: \.self) { f in badge(f.label, Theme.warn).tip(f.help) }
                }
                Text(e.label).foregroundColor(Theme.sub).font(.system(size: fs(11))).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            TextLink(t("Reveal", "Xem file")) { vm.reveal(e.url) }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
        .hoverBG(10, Theme.ink.opacity(0.06))
        .tip(e.program)
    }
    func badge(_ s: String, _ c: Color) -> some View {
        Text(s).font(.system(size: fs(10), weight: .semibold)).foregroundColor(c)
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
        let df: DateFormatter = { let f = DateFormatter(); f.dateFormat = "dd/MM HH:mm"; return f }()
        VStack(alignment: .leading, spacing: 16) {
            Text(t("Statistics", "Thống kê")).font(.system(size: fs(22), weight: .bold)).foregroundColor(Theme.text).padding(.top, 34)
            HStack(spacing: 12) {
                statCard(t("Freed in total", "Tổng đã giải phóng"), fmt(freed))
                statCard(t("Cleanups", "Số lần dọn"), "\(runs)")
                statCard(t("Free now", "Đang trống"), String(format: "%.0f GB", vm.freeGB))
                statCard(t("Trash now", "Thùng rác"), fmt(vm.trashSize))
            }
            FreeSpaceChart(vm: vm, log: log)
            HStack {
                Text(t("Recent activity", "Hoạt động gần đây")).font(.system(size: fs(12), weight: .semibold)).foregroundColor(Theme.sub)
                Spacer()
                TextLink(t("Open log file", "Mở file nhật ký"), url: URL(fileURLWithPath: Stats.path))
            }
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(log.reversed().prefix(60)) { e in
                        HStack(alignment: .top, spacing: 10) {
                            Text(df.string(from: e.date)).font(.system(size: fs(11)).monospacedDigit()).foregroundColor(Theme.sub).frame(width: 78, alignment: .leading)
                            Text(e.text).font(.system(size: fs(12))).foregroundColor(e.text.hasPrefix("ERROR") ? Theme.danger : Theme.text).lineLimit(2)
                            Spacer()
                            if e.freed > 0 { Text("+" + fmt(e.freed)).font(.system(size: fs(11), weight: .semibold)).foregroundColor(Theme.green) }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .hoverBG(8, Theme.ink.opacity(0.06))
                    }
                }
            }
        }
        .padding(.horizontal, 24).padding(.bottom, 16)
        .onAppear { vm.refreshTrash(); vm.refreshDisk(); tick.v.toggle() }
    }
    func statCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: fs(11))).foregroundColor(Theme.sub)
            Text(value).font(.system(size: fs(22), weight: .bold)).foregroundColor(Theme.text)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .hoverBG(12, Theme.ink.opacity(0.05))
    }
}


// MARK: - Feedback & newsletter

/// Where feedback and newsletter sign-ups go. `endpoint` is a Google Apps Script web app that appends
/// one row per submission to a Google Sheet (see backend/Code.gs). No email address is published on purpose.
enum Backend {
    static let endpoint = "https://script.google.com/macros/s/AKfycbz07aYQ8kI0u0OV842dt-LxeN5TedqfOzNvhmuVAPmgXdcIGtpzI-GNwLE_kiUMiGDKag/exec"
    /// Public privacy policy (PRIVACY.md on GitHub). The link is hidden while empty.
    static let privacyURL = "https://github.com/HaiTrung-Workspace/tidymint/blob/main/PRIVACY.md"
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

/// A gentle pointer to the author's Vietnamese drinks site, shown only in Vietnamese,
/// at most once a day on the "done" screen, and never again after "Don't show again".
/// Nothing is sent anywhere: the link only opens when the user clicks it.
enum ConCao {
    static let lastKey = "concaoHintLast", offKey = "concaoHintOff"
    static func url(_ place: String) -> URL {
        URL(string: "https://concao.org/?utm_source=tidymint&utm_medium=app&utm_campaign=\(place)")!
    }
    static func shouldShow() -> Bool {
        guard appLang == "vi", !UserDefaults.standard.bool(forKey: offKey) else { return false }
        if let d = UserDefaults.standard.object(forKey: lastKey) as? Date, Calendar.current.isDateInToday(d) {
            return shownThisSession
        }
        return true
    }
    static var shownThisSession = false
    static func markShown() {
        if !shownThisSession { shownThisSession = true; UserDefaults.standard.set(Date(), forKey: lastKey) }
    }
}

final class HintState: ObservableObject { @Published var hidden = false }

struct ConCaoHint: View {
    @StateObject private var h = HintState()
    var body: some View {
        if !h.hidden {
            HStack(spacing: 10) {
                Image(systemName: "wineglass").foregroundColor(Theme.link)
                Text("Dọn xong rồi, thưởng mình một ly?").foregroundColor(Theme.sub)
                TextLink("Gợi ý ở Cồn Cào →", url: ConCao.url("done"), size: 13)
                Spacer()
                Button { UserDefaults.standard.set(true, forKey: ConCao.offKey); h.hidden = true } label: {
                    Text("Đừng hiện nữa").padding(.horizontal, 6).padding(.vertical, 3).hoverTile()
                }.buttonStyle(.plain).foregroundColor(Theme.sub)
            }
            .font(.system(size: fs(12)))
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .onAppear { ConCao.markShown() }
        }
    }
}

struct FieldBox<C: View>: View {
    let title: String
    @ViewBuilder let content: () -> C
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: fs(12), weight: .semibold)).foregroundColor(Theme.sub)
            content()
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.shade.opacity(0.25)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.ink.opacity(0.15), lineWidth: 1))
        }
    }
}

struct ContactView: View {
    static let social: [(String, String)] = [("Facebook", "https://www.facebook.com/tidymintapp"), ("Instagram", "https://www.instagram.com/tidymint.app/"),
                                             ("X", "https://x.com/tidymintapp"), ("LinkedIn", "https://www.linkedin.com/company/tidymint/"),
                                             ("GitHub", "https://github.com/HaiTrung-Workspace/tidymint")]
    @ObservedObject var vm: VM
    @StateObject private var f = FormState()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Contact the developer", "Liên hệ nhà phát triển")).font(.system(size: fs(22), weight: .bold)).foregroundColor(Theme.text)
                    Text(t("Feedback, bug reports and questions go straight to the developer. An email address is needed so you can get a reply.",
                           "Góp ý, báo lỗi, câu hỏi đều tới thẳng nhà phát triển. Cần email để có thể trả lời bạn."))
                        .foregroundColor(Theme.sub).font(.system(size: fs(12)))
                    HStack(spacing: 4) {
                        Text(t("Or email", "Hoặc gửi email tới")).foregroundColor(Theme.sub)
                        TextLink("hello@tidymint.app", url: URL(string: "mailto:hello@tidymint.app")!)
                    }.font(.system(size: fs(12)))
                    // Brand accounts and public bug reports. Plain links: nothing is loaded until the person clicks.
                    HStack(spacing: 4) {
                        Text(t("Follow Tidymint:", "Theo dõi Tidymint:")).foregroundColor(Theme.sub)
                        ForEach(Array(ContactView.social.enumerated()), id: \.offset) { i, s in
                            if i > 0 { Text("·").foregroundColor(Theme.sub.opacity(0.6)) }
                            TextLink(s.0, url: URL(string: s.1)!)
                        }
                    }.font(.system(size: fs(12)))
                    TextLink(t("Report a bug on GitHub", "Báo lỗi trên GitHub"), url: URL(string: "https://github.com/HaiTrung-Workspace/tidymint/issues")!)
                }.padding(.top, 34)
                HStack(spacing: 8) {
                    ForEach([("feedback", t("Feedback", "Góp ý")), ("bug", t("Bug report", "Báo lỗi")), ("question", t("Question", "Câu hỏi"))], id: \.0) { k, label in
                        Button { f.kind = k } label: {
                            Text(label).font(.system(size: fs(12), weight: .medium)).foregroundColor(f.kind == k ? .white : Theme.text)
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(Capsule().fill(f.kind == k ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.card)))
                        }.buttonStyle(.plain).hoverLift()
                    }
                }
                FieldBox(title: t("Your email (required)", "Email của bạn (bắt buộc)")) {
                    TextField("name@example.com", text: $f.email).textFieldStyle(.plain).foregroundColor(Theme.text)
                        .onSubmit { submit(newsletter: true) }
                }
                FieldBox(title: t("Message", "Nội dung")) {
                    TextEditor(text: $f.message).font(.system(size: fs(13))).foregroundColor(Theme.text)
                        .scrollContentBackground(.hidden).frame(minHeight: 140)
                }
                Toggle(isOn: $f.includeInfo) {
                    Text(t("Attach app version, macOS version and Mac model", "Kèm phiên bản app, phiên bản macOS và đời máy"))
                        .font(.system(size: fs(12))).foregroundColor(Theme.sub)
                }.toggleStyle(.checkbox)
                if !f.result.isEmpty {
                    Text(f.result).font(.system(size: fs(13), weight: .medium)).foregroundColor(f.ok ? Theme.green : Theme.warn)
                }
                HStack(spacing: 10) {
                    if f.sending { ProgressView().controlSize(.small).tint(Theme.text) }
                    Spacer()
                    // Return (outside the message box) = the main button.
                    Button { submit(newsletter: true) } label: {
                        Text(t("Send & get the newsletter", "Gửi và nhận bản tin")).font(.system(size: fs(15), weight: .semibold)).foregroundColor(.white)
                            .padding(.horizontal, 28).padding(.vertical, 11)
                            .background(Capsule().fill(Theme.accent)).shadow(color: Theme.accentSolid.opacity(0.4), radius: 12, y: 4)
                    }.buttonStyle(.plain).hoverLift().disabled(f.sending).keyboardShortcut(.defaultAction)
                    Button { submit(newsletter: false) } label: {
                        Text(t("Send only", "Chỉ gửi")).font(.system(size: fs(12))).foregroundColor(Theme.sub)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().stroke(Theme.ink.opacity(0.25), lineWidth: 1))
                    }.buttonStyle(.plain).hoverBG(14, Theme.ink.opacity(0.08)).disabled(f.sending)
                }
                HStack(spacing: 6) {
                    Spacer()
                    Text(Backend.newsletterText).font(.system(size: fs(11))).foregroundColor(Theme.sub)
                    if let u = URL(string: Backend.privacyURL), !Backend.privacyURL.isEmpty {
                        TextLink(t("Privacy", "Quyền riêng tư"), url: u, size: 11)
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
                Text(t("Want monthly tips to keep your Mac lean?", "Nhận mẹo giữ máy gọn mỗi tháng?")).font(.system(size: fs(15), weight: .semibold)).foregroundColor(Theme.text)
                Text(Backend.newsletterText).font(.system(size: fs(11))).foregroundColor(Theme.sub).fixedSize(horizontal: false, vertical: true)
                if f.ok {
                    Text(t("Thanks! You're on the list.", "Cảm ơn bạn! Đã đăng ký.")).foregroundColor(Theme.green).font(.system(size: fs(13), weight: .medium))
                } else {
                    HStack(spacing: 8) {
                        TextField("name@example.com", text: $f.email).textFieldStyle(.plain).foregroundColor(Theme.text)
                            .onSubmit { join() }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.shade.opacity(0.25)))
                        if f.sending { ProgressView().controlSize(.small).tint(Theme.text) }
                        Button { join() } label: {
                            Text(t("Subscribe", "Nhận bản tin")).font(.system(size: fs(13), weight: .semibold)).foregroundColor(.white)
                                .padding(.horizontal, 16).padding(.vertical, 7).background(Capsule().fill(Theme.accent))
                        }.buttonStyle(.plain).hoverLift()
                    }
                    if !f.result.isEmpty { Text(f.result).font(.system(size: fs(11))).foregroundColor(Theme.warn) }
                    HStack(spacing: 14) {
                        TextLink(t("Later", "Để sau"), size: 11, weight: .regular, color: Theme.sub) { Invite.later(); f.hidden = true }
                        TextLink(t("Don't ask again", "Không hỏi lại"), size: 11, weight: .regular, color: Theme.sub) { Invite.never(); f.hidden = true }
                    }
                }
            }
            .padding(16).background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.ink.opacity(0.12), lineWidth: 1))
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


// MARK: - Sample data for screenshots (--demo). Nothing here touches real files.

@MainActor enum Demo {
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
        func row(_ p: String, _ size: Double, _ sel: Bool) -> AppRow { AppRow(id: p, title: (p as NSString).lastPathComponent, sub: "~/" + p, size: mb(size), count: 1, urls: [u(p)], month: nil, selected: sel) }
        let zalo = AppRules.all[0], chrome = AppRules.all[1], capcut = AppRules.all[4]
        let z = "Library/Application Support/ZaloData/"
        let zaloReport = AppReport(rule: zalo, groups: [
                AppGroup(id: "cache", section: zalo.sections[0], rows: [row(z + "media/update", 312, true), row(z + "Cache", 210, true), row(z + "media/1234567890123456789/ZaloDownloads/fileThumb", 101, true), row(z + "resp_cache", 1.4, true)], expanded: true),
                AppGroup(id: "picture", section: zalo.sections[1], rows: ageRows("p", [(0, 180, 412), (1, 260, 590), (2, 310, 702), (4, 420, 1210), (7, 390, 980), (13, 530, 1430)]), expanded: true),
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
                AppGroup(id: "cache", section: capcut.sections[0], rows: [row(c + "Cache/frameThumbnail", 860, true), row(c + "Cache/recognize", 410, true), row(c + "Cache/audioWave", 95, true)]),
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
    }
    static func load(_ vm: VM) {
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
                     safety: .review, items: [item("Projects/ai-video/_tmp", mb(2860), true), item("Projects/landing-page/_to_delete", mb(418), true)]),
            Category(id: "downloads", titleEN: "Old Downloads (14+ days)", titleVI: "Downloads cũ hơn 14 ngày", icon: "arrow.down.circle",
                     descEN: "Not selected by default. Review before removing", descVI: "Mặc định không tick, xem rồi chọn",
                     safety: .review, items: [item("Downloads/Figma-125.4.dmg", mb(412), false, days: 41), item("Downloads/Zoom.pkg", mb(98), false, days: 63),
                             item("Downloads/dataset-v2.zip", gb(2.4), false, days: 28)]),
        ]
        vm.phase = .summary
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

// MARK: - Organize (sort a folder, suggest tags, keep notes)
//
// Everything runs on this Mac. "Quick" sorts by file type and name; "Read content" adds Apple's built-in Vision
// (text recognition + image classification) and PDFKit text, no model download. Nothing moves until the person
// reviews the plan and clicks Apply; every apply can be undone. Only files directly inside the chosen folder are
// touched, never subfolders, and nothing is ever deleted or overwritten.

/// Where one group goes when sorting: a new folder name inside the chosen folder, or a folder picked elsewhere.
struct OrgDest: Codable, Equatable { var name: String? = nil; var path: String? = nil }

enum OrgGroup: String, CaseIterable, Codable {
    case screens, receipts, cv, images, video, audio, docs, sheets, slides, archives, installers, code, other
    var label: String { let n = names; return t(n.0, n.1) }
    /// English and Vietnamese names, to find a group folder made in the other language.
    var names: (String, String) {
        switch self {
        case .screens: return ("Screenshots", "Ảnh màn hình")
        case .receipts: return ("Receipts and invoices", "Hoá đơn và biên lai")
        case .cv: return ("CVs", "CV")
        case .images: return ("Images", "Ảnh")
        case .video: return ("Videos", "Video")
        case .audio: return ("Audio", "Âm thanh")
        case .docs: return ("Documents", "Tài liệu")
        case .sheets: return ("Spreadsheets", "Bảng tính")
        case .slides: return ("Presentations", "Trình chiếu")
        case .archives: return ("Archives", "File nén")
        case .installers: return ("Installers", "Bộ cài app")
        case .code: return ("Code", "Code")
        case .other: return ("Other", "Khác")
        }
    }
    var icon: String {
        switch self {
        case .screens: return "camera.viewfinder"
        case .receipts: return "doc.text.magnifyingglass"
        case .cv: return "person.text.rectangle"
        case .images: return "photo"
        case .video: return "film"
        case .audio: return "waveform"
        case .docs: return "doc.text"
        case .sheets: return "tablecells"
        case .slides: return "rectangle.on.rectangle"
        case .archives: return "archivebox"
        case .installers: return "shippingbox"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .other: return "questionmark.folder"
        }
    }
}

enum NameToken: String, CaseIterable, Codable {
    case date, time, parent, kind, desc, seq, old, text
    var label: String {
        switch self {
        case .date: return t("Date", "Ngày")
        case .time: return t("Time", "Giờ")
        case .parent: return t("Parent folder", "Thư mục mẹ")
        case .kind: return t("Type", "Loại")
        case .desc: return t("Description", "Mô tả")
        case .seq: return t("Number", "Số thứ tự")
        case .old: return t("Old name", "Tên cũ")
        case .text: return t("Your text", "Chữ tự gõ")
        }
    }
}
/// One part of a name rule. `text` holds what the person typed for a .text part (a prefix, suffix or tag like "ACME").
struct NamePart: Codable, Equatable, Identifiable {
    var id = UUID()
    var kind: NameToken
    var text = ""
}
/// How new names are built: the parts in order, the separator, and two switches for web-safe names.
struct NameRule: Codable, Equatable {
    var parts: [NamePart]
    var sep: String
    var noAccents: Bool
    var lower: Bool
}
enum NamePreset: String, CaseIterable {
    case dateDesc, dateTime, parentSeq, web, custom
    var label: String {
        switch self {
        case .dateDesc: return t("Date + description", "Ngày + mô tả")
        case .dateTime: return t("Date and time taken", "Ngày giờ chụp")
        case .parentSeq: return t("Folder + date + number", "Thư mục mẹ + ngày + số")
        case .web: return t("Web style (no accents, lower case)", "Kiểu web (không dấu, viết thường)")
        case .custom: return t("Custom", "Tuỳ chỉnh")
        }
    }
    var rule: NameRule? {
        switch self {
        case .dateDesc: return NameRule(parts: [.init(kind: .date), .init(kind: .desc)], sep: " ", noAccents: false, lower: false)
        case .dateTime: return NameRule(parts: [.init(kind: .date), .init(kind: .time)], sep: " ", noAccents: false, lower: false)
        case .parentSeq: return NameRule(parts: [.init(kind: .parent), .init(kind: .date), .init(kind: .seq)], sep: "_", noAccents: false, lower: false)
        case .web: return NameRule(parts: [.init(kind: .date), .init(kind: .desc)], sep: "_", noAccents: true, lower: true)
        case .custom: return nil
        }
    }
}

struct OrgFile: Identifiable {
    let id = UUID()
    let url: URL
    var size: Int64
    var date: Date?
    var group: OrgGroup
    var why: String = ""
    var tags: [String] = []          // suggested tags
    var tagOn: Set<String> = []      // tags the person keeps
    var newName: String? = nil       // suggested clearer name (editable)
    var renameOn = false             // apply the new name
    var title: String? = nil         // title read from the content (PDF title or first line of text)
    var desc: String? = nil          // what the file is, for the [Description] part of a name
    var needsName = false            // current name says nothing (IMG_, scan, Untitled...) or it is a receipt/CV
    var nameEdited = false           // the person typed a name: rules no longer overwrite it
    var note: String = ""
    var include = true
    var pairOf: UUID? = nil          // this file travels with another one (Live Photo video, RAW, subtitle, sidecar)
    var warn: String? = nil          // what will happen differently from the plan (name clash, too long, duplicate)
    var fate: String? = nil          // the name it will really get (" 2" added), or "" when it goes to the Trash
    var name: String { url.lastPathComponent }
}

/// One line on the result screen: a file that did not go as planned, and why.
struct OrgNote: Identifiable { enum Kind { case skipped, kept, numbered, trashed }; let id = UUID(); let kind: Kind; let name: String; let detail: String }

struct OrgMove: Codable { let from: String; let to: String; let addedTags: [String]; var trashed: Bool? = nil }
struct OrgSession: Codable { let folder: String; var date: Date; var moves: [OrgMove]; var madeDirs: [String]; var auto: Bool? = nil; var id: String? = nil }

enum OrgEngine {
    static let fm = FileManager.default
    static let ext: [OrgGroup: Set<String>] = [
        .images: ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "tif", "bmp", "svg", "raw", "dng", "cr2", "nef", "arw", "psd", "avif"],
        .video: ["mov", "mp4", "m4v", "avi", "mkv", "webm"],
        .audio: ["mp3", "m4a", "wav", "aac", "flac", "ogg", "aiff", "aif"],
        .docs: ["pdf", "doc", "docx", "pages", "txt", "rtf", "md", "odt", "epub"],
        .sheets: ["xls", "xlsx", "numbers", "csv", "ods"],
        .slides: ["ppt", "pptx", "key", "odp"],
        .archives: ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz"],
        .installers: ["dmg", "pkg", "mpkg", "iso"],
        .code: ["py", "js", "ts", "swift", "json", "html", "css", "sh", "ipynb", "java", "c", "cpp", "h", "go", "rs", "yml", "yaml", "sql", "rb", "php"],
    ]
    static let screenPrefixes = ["screenshot", "screen shot", "ảnh màn hình", "ảnh chụp màn hình", "screen recording", "bản ghi màn hình", "cleanshot"]
    static let cameraPrefixes = ["img_", "img-", "dsc_", "dsc0", "pxl_", "dji_", "gopr", "photo_", "image_", "mvimg_"]

    /// A folder is allowed if it sits inside the home folder, is not the home folder itself and not inside ~/Library.
    static func allowed(_ u: URL) -> Bool {
        let p = u.standardizedFileURL.path, h = NSHomeDirectory()
        return p.hasPrefix(h + "/") && !p.hasPrefix(h + "/Library") && !p.hasPrefix(h + "/.")
    }

    /// Folders never entered when sub-folders are included: app bundles and libraries (packages), code projects, dependency folders.
    static let skipDirs: Set<String> = ["node_modules", ".git", "Library", "venv", ".venv", "build", "DerivedData", "Pods"]
    static func isProject(_ d: URL) -> Bool {
        ["\(d.path)/.git", "\(d.path)/package.json", "\(d.path)/Package.swift", "\(d.path)/.xcodeproj"].contains { fm.fileExists(atPath: $0) }
    }
    /// Files in the folder and its sub-folders (up to 6 levels, at most 5,000 files), skipping packages and code projects.
    static func filesDeep(in folder: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey, .isPackageKey, .isDirectoryKey]
        guard let en = fm.enumerator(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, _ in true }) else { return [] }
        var out: [URL] = []
        let base = folder.pathComponents.count
        for case let u as URL in en {
            guard let v = try? u.resourceValues(forKeys: Set(keys)) else { continue }
            if v.isDirectory == true {
                if v.isPackage == true || skipDirs.contains(u.lastPathComponent) || u.pathComponents.count - base >= 6 || isProject(u) { en.skipDescendants() }
                continue
            }
            if v.isRegularFile == true && v.isSymbolicLink != true { out.append(u) }
            if out.count >= 5000 { break }
        }
        return out.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }
    static func files(in folder: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey, .isPackageKey]
        let kids = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        return kids.filter {
            guard let v = try? $0.resourceValues(forKeys: Set(keys)) else { return false }
            return v.isRegularFile == true && v.isSymbolicLink != true && v.isPackage != true
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    static func quick(_ u: URL) -> OrgFile {
        let v = try? u.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .creationDateKey, .contentModificationDateKey])
        let e = u.pathExtension.lowercased(), n = u.lastPathComponent.lowercased()
        var g = OrgGroup.other
        for (k, s) in ext where s.contains(e) { g = k }
        var why = ""
        if (g == .images || g == .video), screenPrefixes.contains(where: { n.hasPrefix($0) }) { g = .screens; why = t("Name says it is a screen capture", "Tên file cho thấy là ảnh chụp màn hình") }
        // When it was taken, not when it was copied here: camera date first, else the earlier of created and modified
        // (a copy gets a new creation date but keeps its modification date).
        let fileDate = [v?.creationDate, v?.contentModificationDate].compactMap { $0 }.min()
        let media = g == .images || g == .video || g == .screens
        var taken = media ? takenDate(u, video: g == .video) : nil
        // Spotlight falls back to the file's own date for videos without a recording date: keep the earliest.
        if g == .video, let d = taken, let fd = fileDate { taken = min(d, fd) }
        var f = OrgFile(url: u, size: Int64(v?.totalFileAllocatedSize ?? 0), date: taken ?? fileDate, group: g, why: why)
        f.desc = describe(f, label: nil); f.needsName = meaningless(u)
        return f
    }

    static let exifFmt: DateFormatter = { let d = DateFormatter(); d.locale = Locale(identifier: "en_US_POSIX"); d.dateFormat = "yyyy:MM:dd HH:mm:ss"; return d }()
    static let exifFmtZ: DateFormatter = { let d = DateFormatter(); d.locale = Locale(identifier: "en_US_POSIX"); d.dateFormat = "yyyy:MM:dd HH:mm:ssxxx"; return d }()
    /// The capture date stored inside the file: EXIF for photos (read from the header only), the recording date for videos.
    static func takenDate(_ u: URL, video: Bool) -> Date? {
        if video {
            guard let item = MDItemCreateWithURL(nil, u as CFURL), let d = MDItemCopyAttribute(item, kMDItemContentCreationDate) as? Date else { return nil }
            return d
        }
        guard let src = CGImageSourceCreateWithURL(u as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let s = (exif[kCGImagePropertyExifDateTimeOriginal] ?? exif[kCGImagePropertyExifDateTimeDigitized]) as? String else { return nil }
        if let off = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String, let d = exifFmtZ.date(from: s + off) { return d }
        return exifFmt.date(from: s)
    }

    /// Files that belong together and must keep the same name and folder: a Live Photo (photo + video),
    /// RAW + JPG, a video and its subtitles, any file and its .xmp / .aae edit sidecar.
    static let pairMain: Set<String> = ["heic", "heif", "jpg", "jpeg", "png"]
    static let rawExt: Set<String> = ["dng", "cr2", "cr3", "nef", "arw", "raf", "orf", "rw2", "raw"]
    static let subExt: Set<String> = ["srt", "vtt", "ass", "ssa"]
    static let sideExt: Set<String> = ["xmp", "aae"]
    static func linkPairs(_ files: inout [OrgFile]) {
        var byStem: [String: [Int]] = [:]
        for i in files.indices {
            let k = files[i].url.deletingPathExtension().path.lowercased()
            byStem[k, default: []].append(i)
        }
        for (_, ix) in byStem where ix.count > 1 {
            func e(_ i: Int) -> String { files[i].url.pathExtension.lowercased() }
            let videoExt = ext[.video]!
            // The leader carries the name: the photo, else the RAW, else the video, else the first non-sidecar file.
            guard let lead = ix.first(where: { pairMain.contains(e($0)) }) ?? ix.first(where: { rawExt.contains(e($0)) })
                    ?? ix.first(where: { videoExt.contains(e($0)) }) ?? ix.first(where: { !sideExt.contains(e($0)) }) else { continue }
            let le = e(lead)
            for i in ix where i != lead {
                let x = e(i)
                var why: String? = nil
                if sideExt.contains(x) { why = t("edit sidecar", "file chỉnh sửa đi kèm") }
                else if videoExt.contains(x) && pairMain.contains(le) { why = "Live Photo" }
                else if rawExt.contains(x) && pairMain.contains(le) { why = "RAW + JPG" }
                else if subExt.contains(x) && videoExt.contains(le) { why = t("subtitles", "phụ đề") }
                guard let w = why else { continue }
                files[i].pairOf = files[lead].id
                files[i].why = t("Goes with \(files[lead].name) (\(w))", "Đi cùng \(files[lead].name) (\(w))")
            }
        }
    }

    /// Finder accepts up to 255 bytes per name. Drop characters it refuses or hides the file with, keep room for " 2".
    static func safeStem(_ s: String, ext: String) -> String {
        var x = String(String.UnicodeScalarView(s.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }))
        x = x.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        x = x.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        while x.hasPrefix(".") { x.removeFirst() }
        let room = 255 - (ext.isEmpty ? 0 : ext.utf8.count + 1) - 6
        while x.utf8.count > room { x.removeLast() }
        return x.trimmingCharacters(in: .whitespaces)
    }

    /// Same file on disk (also when the paths differ only in upper/lower case on a case-insensitive disk).
    static func sameFile(_ a: URL, _ b: URL) -> Bool {
        guard let x = try? a.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject,
              let y = try? b.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject else { return false }
        return x.isEqual(y)
    }
    /// Move or rename. A change of case only (IMG.JPG to IMG.jpg) goes through a temporary name, because the disk sees one file.
    /// Another process has this file open (a torrent client still writing, an installer reading). Checked before moving a new download.
    static func isOpen(_ u: URL) -> Bool {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof"); p.arguments = ["-t", "--", u.path]
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }
    static func move(_ from: URL, _ to: URL) throws {
        if from.path != to.path, from.path.lowercased() == to.path.lowercased() || sameFile(from, to) {
            let tmp = to.deletingLastPathComponent().appendingPathComponent(".tidymint-\(UUID().uuidString)")
            try fm.moveItem(at: from, to: tmp)
            do { try fm.moveItem(at: tmp, to: to) } catch { try? fm.moveItem(at: tmp, to: from); throw error }
        } else { try fm.moveItem(at: from, to: to) }
    }
    /// Byte-for-byte identical (files over 500 MB are never treated as duplicates, to keep this fast).
    static func identical(_ a: URL, _ b: URL) -> Bool {
        guard let sa = (try? fm.attributesOfItem(atPath: a.path))?[.size] as? Int64,
              let sb = (try? fm.attributesOfItem(atPath: b.path))?[.size] as? Int64, sa == sb, sa <= 500_000_000,
              let ha = try? FileHandle(forReadingFrom: a), let hb = try? FileHandle(forReadingFrom: b) else { return false }
        defer { try? ha.close(); try? hb.close() }
        while true {
            let x = ha.readData(ofLength: 1 << 20), y = hb.readData(ofLength: 1 << 20)
            if x != y { return false }
            if x.isEmpty { return true }
        }
    }

    static let df: DateFormatter = { let d = DateFormatter(); d.dateFormat = "yyyy-MM-dd"; return d }()
    /// Names that say nothing about the file: camera dumps, scans, "Untitled", "download (3)", long random strings.
    static func meaningless(_ url: URL) -> Bool {
        let n = url.deletingPathExtension().lastPathComponent.lowercased()
        if cameraPrefixes.contains(where: { n.hasPrefix($0) }) || screenPrefixes.contains(where: { n.hasPrefix($0) }) { return true }
        let generic = ["scan", "untitled", "document", "download", "image", "file", "photo", "img", "new document", "tài liệu", "không có tiêu đề", "unnamed"]
        let core = n.replacingOccurrences(of: #"[\s_\-\(\)\d]+$"#, with: "", options: .regularExpression)
        if generic.contains(core) || core.isEmpty { return true }
        // Random strings: hex/UUID-like, or one long run of letters and digits with several digits and no separators.
        if n.range(of: #"^[a-f0-9\-]{16,}$"#, options: .regularExpression) != nil { return true }
        if n.range(of: #"^[a-z0-9]{16,}$"#, options: .regularExpression) != nil && n.filter(\.isNumber).count >= 4 { return true }
        return false
    }
    /// Keep a name safe for Finder: no slashes or colons, single spaces, at most 60 characters.
    static func clean(_ s: String) -> String {
        // Keep letters, digits and a few safe signs only; text read from images can contain stray control characters.
        let ok = CharacterSet.letters.union(.decimalDigits).union(CharacterSet(charactersIn: " -_.,()&'+#"))
        var x = String(String.UnicodeScalarView(s.unicodeScalars.map { ok.contains($0) ? $0 : " " }))
        // ALL-CAPS text read from a scan becomes Title Case so the name stays readable.
        if x == x.uppercased(), x.rangeOfCharacter(from: .lowercaseLetters) == nil, x.count > 4 { x = x.capitalized(with: Locale(identifier: "vi")) }
        x = x.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return String(x.prefix(60)).trimmingCharacters(in: .whitespaces)
    }
    /// What the file is, in a few words: used for the [Description] part of a name.
    static func describe(_ f: OrgFile, label: String?) -> String {
        // A name the person chose is kept as the description (dates and copy marks stripped); content only names files whose name says nothing.
        if !meaningless(f.url), let old = oldDesc(f.url) { return old }
        let title = f.title.map(clean).flatMap { $0.isEmpty ? nil : $0 }
        switch f.group {
        case .screens: return t("Screenshot", "Ảnh màn hình")
        case .receipts: return t("Receipt", "Hoá đơn") + (title.map { " " + $0 } ?? "")
        case .cv: return "CV" + (title.map { " " + $0 } ?? "")
        default: return clean(title ?? label ?? f.group.label)
        }
    }
    static let datePatterns: [(String, String)] = [
        (#"(19|20)\d{2}[-_.](0[1-9]|1[0-2])[-_.](0[1-9]|[12]\d|3[01])"#, "yyyy-MM-dd"),
        (#"(0[1-9]|[12]\d|3[01])[-_.](0[1-9]|1[0-2])[-_.](19|20)\d{2}"#, "dd-MM-yyyy"),
        (#"(?<!\d)(19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])(?!\d)"#, "yyyyMMdd"),
    ]
    /// A date already written in the name (2025-03-14, 14.03.2025, 20250314): kept instead of the file's own date.
    static func nameDate(_ url: URL) -> Date? {
        let n = url.deletingPathExtension().lastPathComponent
        for (p, fmt) in datePatterns {
            guard let r = n.range(of: p, options: .regularExpression) else { continue }
            let raw = n[r].replacingOccurrences(of: "_", with: "-").replacingOccurrences(of: ".", with: "-")
            let d = DateFormatter(); d.dateFormat = fmt; d.isLenient = false
            if let v = d.date(from: raw) { return v }
        }
        return nil
    }
    /// The words of the current name without dates, "copy", "(2)" or "final final": what the person called the file.
    static func oldDesc(_ url: URL) -> String? {
        var n = url.deletingPathExtension().lastPathComponent
        for (p, _) in datePatterns { n = n.replacingOccurrences(of: p, with: " ", options: .regularExpression) }
        n = n.replacingOccurrences(of: #"[_\-]+"#, with: " ", options: .regularExpression)
        n = n.replacingOccurrences(of: #"(?i)\b(copy|bản sao)\b|\(\d+\)|\s\d{1,2}$"#, with: " ", options: .regularExpression)
        let c = clean(n)
        return c.isEmpty ? nil : c
    }
    static let tf: DateFormatter = { let d = DateFormatter(); d.dateFormat = "HH.mm.ss"; return d }()
    /// Extensions in lower case, and .jpeg shortened to .jpg, so the same kind of file always ends the same way.
    static func normExt(_ e: String) -> String { let x = e.lowercased(); return x == "jpeg" ? "jpg" : x }
    static func stripAccents(_ s: String) -> String {
        s.replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "D").folding(options: .diacriticInsensitive, locale: Locale(identifier: "vi"))
    }
    /// Build a name from a rule. seq is the file's number within its folder (001, 002...).
    static func makeName(_ f: OrgFile, _ r: NameRule, seq: Int, parent: String) -> String {
        var parts: [String] = []
        for part in r.parts {
            var p: String
            switch part.kind {
            case .date: p = df.string(from: nameDate(f.url) ?? f.date ?? Date())
            case .time: p = tf.string(from: f.date ?? Date())
            case .parent: p = clean(parent)
            case .kind: p = f.group.label
            case .desc: p = f.desc ?? f.group.label
            case .seq: p = String(format: "%03d", seq)
            case .old: p = clean(f.url.deletingPathExtension().lastPathComponent)
            // Typed text is kept as typed, only characters Finder refuses are dropped.
            case .text: p = part.text.replacingOccurrences(of: #"[/:\\\n\r\t]"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            }
            if r.noAccents { p = stripAccents(p) }
            if r.lower { p = p.lowercased() }
            if r.noAccents && r.lower { p = p.replacingOccurrences(of: " ", with: "-") }
            if !p.isEmpty { parts.append(p) }
        }
        let e = normExt(f.url.pathExtension)
        let stem = safeStem(parts.joined(separator: r.sep), ext: e)
        return stem + (e.isEmpty ? "" : "." + e)
    }
    /// The first line of text that reads like a title: 3 to 60 characters, mostly letters, not a known heading word.
    static func titleLine(_ text: String) -> String? {
        let skip = Set(["curriculum vitae", "resume", "résumé", "hóa đơn", "hoá đơn", "hóa đơn bán hàng", "hoá đơn bán hàng", "invoice", "receipt", "biên lai", "cv"].map(fold))
        for l in text.split(whereSeparator: \.isNewline).prefix(8) {
            let s = l.trimmingCharacters(in: .whitespaces)
            let letters = s.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
            guard s.count >= 3, s.count <= 60, letters * 10 >= s.count * 6, !skip.contains(fold(s)) else { continue }
            return s
        }
        return nil
    }

    // MARK: content (Vision + PDFKit)
    static let receiptWords = ["hóa đơn", "hoá đơn", "biên lai", "invoice", "receipt", "tổng cộng", "subtotal", "total", "vat", "thanh toán", "payment", "order #", "mã đơn", "tax"]
    static let cvWords = ["curriculum vitae", "resume", "résumé", "kinh nghiệm làm việc", "work experience", "education", "học vấn", "kỹ năng", "skills", "mục tiêu nghề nghiệp"]
    static let vi: [String: String] = [
        "food": "Đồ ăn", "meal": "Đồ ăn", "dessert": "Đồ ngọt", "drink": "Đồ uống", "beverage": "Đồ uống", "wine": "Rượu vang", "cocktail": "Cocktail",
        "coffee": "Cà phê", "bottle": "Chai", "dog": "Chó", "cat": "Mèo", "animal": "Động vật", "bird": "Chim", "people": "Người", "adult": "Người",
        "child": "Trẻ em", "baby": "Em bé", "beach": "Biển", "sea": "Biển", "ocean": "Biển", "sky": "Bầu trời", "mountain": "Núi", "plant": "Cây",
        "tree": "Cây", "flower": "Hoa", "car": "Ô tô", "vehicle": "Xe", "building": "Toà nhà", "city": "Thành phố", "interior_room": "Trong nhà",
        "sunset_sunrise": "Hoàng hôn", "night_sky": "Trời đêm", "document": "Giấy tờ", "receipt": "Hoá đơn", "book": "Sách", "art": "Nghệ thuật",
        "illustrations": "Minh hoạ", "computer": "Máy tính", "screenshot": "Ảnh màn hình", "text": "Có chữ", "clothing": "Quần áo", "shoes": "Giày",
        "furniture": "Đồ nội thất", "outdoor": "Ngoài trời", "blue_sky": "Trời xanh", "indoor": "Trong nhà", "portrait": "Chân dung", "selfie": "Ảnh tự chụp", "kitchen": "Bếp", "landscape": "Phong cảnh", "water": "Nước", "snow": "Tuyết", "party": "Tiệc",
    ]
    static let generic: Set<String> = ["printed_page", "structure", "material", "liquid", "container", "wood_processed", "textile", "paper", "consumer_electronics", "machine"]

    static func readText(_ u: URL) -> String {
        let e = u.pathExtension.lowercased()
        if e == "pdf", let d = PDFDocument(url: u) {
            var s = ""
            if let tt = d.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String, tt.count > 2,
               !["untitled", "microsoft word"].contains(where: { tt.lowercased().hasPrefix($0) }) { s = tt + "\n" }
            for i in 0..<min(2, d.pageCount) { s += d.page(at: i)?.string ?? "" }
            return s
        }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .fast
        if let langs = try? req.supportedRecognitionLanguages() { req.recognitionLanguages = ["vi-VT", "en-US"].filter { langs.contains($0) } }
        try? VNImageRequestHandler(url: u).perform([req])
        return (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }

    /// Words that make a screenshot a real document (bill, contract, ticket, statement, ID), not just a screen full of text.
    static let docWords = ["hợp đồng", "contract", "agreement", "vé", "ticket", "boarding pass", "booking", "đặt chỗ", "sao kê", "statement",
                           "số tài khoản", "account number", "căn cước", "passport", "hộ chiếu", "giấy phép", "license", "certificate", "chứng nhận"]
    /// Labels for an image. Measured on real files (29/10/2026): Apple returns "document" with exactly the same confidence as
    /// "screenshot" for every screen capture (it is the parent label), and guesses on tiny images sit around 0.5. So: skip tiny
    /// images, keep labels from 0.6 up, and drop "document" when it only comes along with "screenshot".
    static func labels(_ u: URL) -> [String] {
        let bytes = (try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        var side = 0
        if let src = CGImageSourceCreateWithURL(u as CFURL, nil), let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] {
            side = max(p[kCGImagePropertyPixelWidth] as? Int ?? 0, p[kCGImagePropertyPixelHeight] as? Int ?? 0)
        }
        if bytes < 20_000 || (side > 0 && side < 300) { return [] }
        let req = VNClassifyImageRequest()
        try? VNImageRequestHandler(url: u).perform([req])
        var obs = (req.results ?? []).filter { $0.confidence >= 0.6 && !generic.contains($0.identifier) }
        if obs.contains(where: { $0.identifier == "screenshot" }) { obs.removeAll { $0.identifier == "document" } }
        var out: [String] = []
        for o in obs.sorted(by: { $0.confidence > $1.confidence }) {
            let name = vi[o.identifier].map { appLang == "vi" ? $0 : o.identifier.replacingOccurrences(of: "_", with: " ").capitalized }
                ?? o.identifier.replacingOccurrences(of: "_", with: " ").capitalized
            if !out.contains(name) { out.append(name) }
            if out.count == 3 { break }
        }
        return out
    }

    /// Lowercase without accents ("Hóa đơn" -> "hoa don"), so text read without diacritics still matches.
    static func fold(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "đ", with: "d").folding(options: .diacriticInsensitive, locale: Locale(identifier: "vi"))
    }

    static func deep(_ f: inout OrgFile) {
        let e = f.url.pathExtension.lowercased()
        let image = ext[.images]!.contains(e) && e != "svg" && e != "psd"
        guard image || e == "pdf" else { return }
        let raw = readText(f.url)
        let text = fold(raw)
        let r = receiptWords.map(fold).filter { text.contains($0) }.count
        let c = cvWords.map(fold).filter { text.contains($0) }.count
        if r >= 2 { f.group = .receipts; f.why = t("Text in the file looks like a receipt or invoice", "Chữ trong file giống hoá đơn, biên lai") }
        else if c >= 2 { f.group = .cv; f.why = t("Text in the file looks like a CV", "Chữ trong file giống CV") }
        if image {
            f.tags = labels(f.url)
            // A screenshot of a bill, contract or ticket is still a document: add it back when the text says so.
            let doc = t("Document", "Giấy tờ")
            if f.tags.contains(t("Screenshot", "Ảnh màn hình")), !f.tags.contains(doc),
               r >= 2 || c >= 2 || docWords.map(fold).contains(where: { text.contains($0) }) {
                f.tags.insert(doc, at: min(1, f.tags.count))
            }
            if raw.count > 40, !f.tags.contains(t("Has text", "Có chữ")) { f.tags.append(t("Has text", "Có chữ")) }
        }
        f.tagOn = Set(f.tags)
        f.title = titleLine(raw)
        f.desc = describe(f, label: f.tags.first); f.needsName = meaningless(f.url)
    }
}

/// Notes are kept by Tidymint (a small JSON file), keyed by the file's path after organizing.
enum OrgNotes {
    static let path = Stats.dir + "/notes.json"
    static func load() -> [String: String] {
        guard let d = FileManager.default.contents(atPath: path), let m = try? JSONDecoder().decode([String: String].self, from: d) else { return [:] }
        return m
    }
    static func save(_ m: [String: String]) {
        try? FileManager.default.createDirectory(atPath: Stats.dir, withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(m) { try? d.write(to: URL(fileURLWithPath: path)) }
    }
}

@MainActor final class OrgVM: ObservableObject {
    @Published var folder: URL = Scanner.home.appendingPathComponent("Downloads") { didSet { dests = Self.loadDests(for: folder) } }
    @Published var readContent = true
    /// Sort into folders (one per group, inside the chosen folder unless the person picked another) or rename only.
    @Published var moveIntoFolders = UserDefaults.standard.object(forKey: "org-move") as? Bool ?? true {
        didSet { UserDefaults.standard.set(moveIntoFolders, forKey: "org-move"); recomputeNames() }
    }
    /// Include files in sub-folders. Those are renamed and tagged where they are; only loose files are sorted into folders.
    @Published var includeSub = UserDefaults.standard.bool(forKey: "org-sub") {
        didSet { UserDefaults.standard.set(includeSub, forKey: "org-sub") }
    }
    /// Where each group goes when sorting, remembered per chosen folder (key: group raw value).
    @Published var dests: [String: OrgDest] = OrgVM.loadDests(for: Scanner.home.appendingPathComponent("Downloads"))
    @Published var editingGroup: OrgGroup? = nil
    @Published var groupDraft = ""
    @Published var phase: Phase = .idle
    @Published var files: [OrgFile] = []
    @Published var progress = 0
    @Published var total = 0
    @Published var current = ""
    @Published var collapsed = Set<OrgGroup>()
    @Published var preset: NamePreset = NamePreset(rawValue: UserDefaults.standard.string(forKey: "org-preset") ?? "") ?? .dateDesc {
        didSet { UserDefaults.standard.set(preset.rawValue, forKey: "org-preset"); recomputeNames() }
    }
    @Published var custom: NameRule = (UserDefaults.standard.data(forKey: "org-custom")).flatMap { try? JSONDecoder().decode(NameRule.self, from: $0) }
        ?? NameRule(parts: [.init(kind: .date), .init(kind: .desc)], sep: " ", noAccents: false, lower: false) {
        didSet { if let d = try? JSONEncoder().encode(custom) { UserDefaults.standard.set(d, forKey: "org-custom") }; recomputeNames() }
    }
    @Published var renameAll = UserDefaults.standard.bool(forKey: "org-rename-all") {
        didSet { UserDefaults.standard.set(renameAll, forKey: "org-rename-all"); recomputeNames() }
    }
    @Published var showRule = false
    /// When a new name is taken by a byte-for-byte identical file, send the extra copy to the Trash instead of adding " 2".
    @Published var dedupe = UserDefaults.standard.object(forKey: "org-dedupe") as? Bool ?? true {
        didSet { UserDefaults.standard.set(dedupe, forKey: "org-dedupe"); validate() }
    }
    /// Keep Downloads tidy: new downloads go into their type folder on their own.
    @Published var watchDownloads = UserDefaults.standard.bool(forKey: "org-watch") {
        didSet { UserDefaults.standard.set(watchDownloads, forKey: "org-watch"); if watchDownloads { startWatch() } else { stopWatch() } }
    }
    var rule: NameRule { preset.rule ?? custom }
    @Published var editing: UUID? = nil
    @Published var result = ""
    @Published var canUndo = OrgVM.lastSession() != nil
    weak var vm: VM?
    static let sessionPath = Stats.dir + "/organize-last.json"

    var included: [OrgFile] { files.filter(\.include) }
    /// What the list shows: everything, only files that get a new name, or only files with a warning.
    enum Show: Int { case all, rename, check }
    @Published var show: Show = .all
    /// Show the plan as two folder trees (now / after Apply) instead of the grouped list.
    @Published var treeView = UserDefaults.standard.bool(forKey: "org-tree") { didSet { UserDefaults.standard.set(treeView, forKey: "org-tree") } }
    /// A file picked in the tree: the list scrolls to it and marks it.
    @Published var focus: UUID? = nil
    func reveal(_ id: UUID) {
        if let f = file(id) { collapsed.remove(f.group); if !shown(f) { show = .all } }
        focus = id; treeView = false
    }

    /// The two trees: where planned files are now, and where they will be after Apply (filtered like the list).
    func trees() -> (now: [OrgTreeRow], after: [OrgTreeRow]) {
        let inc = files.filter { $0.include && shown($0) }
        let by = Dictionary(uniqueKeysWithValues: files.filter(\.include).map { ($0.id, $0) })
        let c = ctx, base = folder.standardizedFileURL.path
        func rel(_ u: URL) -> [String] {
            let p = u.standardizedFileURL.path
            if p.hasPrefix(base + "/") { return String(p.dropFirst(base.count + 1)).split(separator: "/").map(String.init) }
            // A folder outside the chosen one shows as one "~/..." line.
            return [u.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"), u.lastPathComponent]
        }
        var now: [(path: [String], f: OrgFile, state: Int)] = [], after: [(path: [String], f: OrgFile, state: Int)] = []
        for f in inc {
            let to = Self.target(f, by, c)
            let changed = to.path != f.url.path
            now.append((rel(f.url), f, changed ? 3 : 0))
            // Show what will really happen: the numbered name, or a line saying it goes to the Trash.
            var p = rel(to)
            if let fa = f.fate { if fa.isEmpty { p[p.count - 1] += t("  → Trash", "  → Thùng rác") } else { p[p.count - 1] = fa } }
            after.append((p, f, f.warn != nil ? 2 : (changed ? 1 : 0)))
        }
        return (OrgTreeRow.build(now, root: folder, markNew: false), OrgTreeRow.build(after, root: folder, markNew: true))
    }
    func shown(_ f: OrgFile) -> Bool {
        switch show {
        case .all: return true
        case .rename: return f.include && f.renameOn && f.newName != nil
        case .check: return f.include && f.warn != nil
        }
    }
    var groups: [OrgGroup] { OrgGroup.allCases.filter { g in files.contains { $0.group == g && shown($0) } } }
    func idx(_ g: OrgGroup) -> [Int] { files.indices.filter { files[$0].group == g && shown(files[$0]) } }
    /// Files that did not go as planned in the last Apply, for the result screen.
    @Published var report: [OrgNote] = []

    func choose() {
        let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false; p.allowsMultipleSelection = false
        p.directoryURL = folder; p.prompt = t("Choose", "Chọn")
        guard p.runModal() == .OK, let u = p.url else { return }
        if OrgEngine.allowed(u) { folder = u; phase = .idle; files = [] }
        else {
            let a = NSAlert(); a.messageText = t("Pick a folder inside your home folder", "Chọn một thư mục bên trong thư mục người dùng")
            a.informativeText = t("Tidymint does not organize your whole home folder, Library or system folders.", "Tidymint không sắp xếp cả thư mục người dùng, thư mục Library hay thư mục hệ thống.")
            a.runModal()
        }
    }

    func plan() {
        guard OrgEngine.allowed(folder) else { return }
        phase = .scanning; progress = 0; result = ""
        let f = folder, deep = readContent, sub = includeSub
        Task.detached {
            let urls = sub ? OrgEngine.filesDeep(in: f) : OrgEngine.files(in: f)
            await MainActor.run { self.total = urls.count }
            var out: [OrgFile] = []
            for (i, u) in urls.enumerated() {
                var o = OrgEngine.quick(u)
                if deep { OrgEngine.deep(&o) }
                out.append(o)
                if i % 3 == 0 || i == urls.count - 1 {
                    let n = i + 1, name = u.lastPathComponent
                    await MainActor.run { self.progress = n; self.current = name }
                }
            }
            OrgEngine.linkPairs(&out)
            // A file that goes with another one is listed right under it.
            let lone = out.filter { $0.pairOf == nil }
            out = lone.flatMap { l in [l] + out.filter { $0.pairOf == l.id } }
            let notes = OrgNotes.load()
            for i in out.indices { out[i].note = notes[out[i].url.path] ?? "" }
            await MainActor.run { self.files = out; self.sameCache = [:]; self.show = .all; self.focus = nil; self.recomputeNames(); self.phase = .review; self.vm?.markDone(.organize) }
        }
    }

    /// Access by id, not by index: the list can change (apply, plan again) while a row is still on screen.
    func file(_ id: UUID) -> OrgFile? { files.first { $0.id == id } }
    func edit(_ id: UUID, check: Bool = true, _ change: (inout OrgFile) -> Void) {
        if let i = files.firstIndex(where: { $0.id == id }) { change(&files[i]); if check { validate() } }
    }
    func setGroup(_ id: UUID, _ g: OrgGroup) {
        guard let i = files.firstIndex(where: { $0.id == id }) else { return }
        files[i].group = g; files[i].desc = OrgEngine.describe(files[i], label: files[i].tags.first); recomputeNames()
    }

    /// Re-run the naming rule on every file (numbers restart in each destination folder, oldest first).
    /// Names the person typed are kept; a rename they switched off stays off. Files that go with another one take its name later.
    func recomputeNames() {
        let r = rule
        var counters: [String: Int] = [:]
        let order = files.indices.sorted { (files[$0].date ?? .distantPast, files[$0].name) < (files[$1].date ?? .distantPast, files[$1].name) }
        for i in order where files[i].pairOf == nil {
            if files[i].nameEdited { continue }
            guard renameAll || files[i].needsName else { files[i].newName = nil; files[i].renameOn = false; continue }
            // Numbers restart per destination folder: the type folder when moving, otherwise the folder the file sits in.
            let own = files[i].url.deletingLastPathComponent()
            let mv = moves(files[i])
            let key = mv ? destURL(files[i].group).standardizedFileURL.path : own.standardizedFileURL.path
            let parent = mv ? folder.lastPathComponent : own.lastPathComponent
            counters[key, default: 0] += 1
            let n = OrgEngine.makeName(files[i], r, seq: counters[key]!, parent: parent)
            let had = files[i].newName != nil
            files[i].newName = n == files[i].name ? nil : n
            if !had { files[i].renameOn = files[i].newName != nil }
            if files[i].newName == nil { files[i].renameOn = false }
        }
        validate()
    }
    var renameCount: Int { files.filter { $0.include && $0.renameOn && $0.newName != nil }.count }
    var warnCount: Int { files.filter { $0.include && $0.warn != nil }.count }
    var namedCount: Int { files.filter { $0.needsName }.count }
    /// Example of the current rule on the first file it applies to, for the rule editor.
    var example: String {
        let f = files.first { $0.pairOf == nil && (renameAll || $0.needsName) } ?? files.first
        guard let f else { return "" }
        return OrgEngine.makeName(f, rule, seq: 1, parent: moves(f) ? folder.lastPathComponent : f.url.deletingLastPathComponent().lastPathComponent)
    }

    // MARK: destination folders

    nonisolated static let destKey = "org-dest"
    nonisolated static func allDests() -> [String: [String: OrgDest]] {
        UserDefaults.standard.data(forKey: destKey).flatMap { try? JSONDecoder().decode([String: [String: OrgDest]].self, from: $0) } ?? [:]
    }
    nonisolated static func loadDests(for f: URL) -> [String: OrgDest] { allDests()[f.standardizedFileURL.path] ?? [:] }
    func saveDests() {
        var all = Self.allDests(); all[folder.standardizedFileURL.path] = dests.isEmpty ? nil : dests
        if let d = try? JSONEncoder().encode(all) { UserDefaults.standard.set(d, forKey: Self.destKey) }
    }
    /// A folder the person picked, or a folder named after the group (or their name for it) inside the chosen folder.
    static func destURL(_ g: OrgGroup, _ folder: URL, _ d: [String: OrgDest]) -> URL {
        if let p = d[g.rawValue]?.path { return URL(fileURLWithPath: p, isDirectory: true) }
        if let n = d[g.rawValue]?.name { return folder.appendingPathComponent(n, isDirectory: true) }
        // A folder made earlier keeps being used when the app language changes ("Images" stays, no second "Ảnh").
        for n in [g.label, g.names.0, g.names.1] where isDir(folder.appendingPathComponent(n)) { return folder.appendingPathComponent(n, isDirectory: true) }
        return folder.appendingPathComponent(g.label, isDirectory: true)
    }
    nonisolated static func isDir(_ u: URL) -> Bool { var d: ObjCBool = false; return FileManager.default.fileExists(atPath: u.path, isDirectory: &d) && d.boolValue }
    /// Keep Downloads tidy only uses folders inside the watched folder: a group set to go elsewhere uses its default folder there.
    nonisolated static func autoDests(for dir: URL) -> [String: OrgDest] {
        let base = dir.standardizedFileURL.path + "/"
        return loadDests(for: dir).filter { $0.value.path.map { URL(fileURLWithPath: $0).standardizedFileURL.path.hasPrefix(base) } ?? true }
    }
    func destURL(_ g: OrgGroup) -> URL { Self.destURL(g, folder, dests) }
    func isInside(_ u: URL) -> Bool { u.standardizedFileURL.path.hasPrefix(folder.standardizedFileURL.path + "/") }
    /// Short path for the screen: "Downloads/Images" inside the chosen folder, "~/Documents/Work" elsewhere.
    func destLabel(_ g: OrgGroup) -> String {
        let u = destURL(g).standardizedFileURL, base = folder.standardizedFileURL.path
        if isInside(u) { return folder.lastPathComponent + String(u.path.dropFirst(base.count)) }
        return u.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
    func destExists(_ g: OrgGroup) -> Bool { var d: ObjCBool = false; return FileManager.default.fileExists(atPath: destURL(g).path, isDirectory: &d) && d.boolValue }
    /// A file sorts into its group folder only when it sits loose in the chosen folder.
    func moves(_ f: OrgFile) -> Bool { moveIntoFolders && f.url.deletingLastPathComponent().standardizedFileURL.path == folder.standardizedFileURL.path }
    func groupMoves(_ g: OrgGroup) -> Bool { files.contains { $0.group == g && $0.include && $0.pairOf == nil && moves($0) } }
    var movingGroups: [OrgGroup] { OrgGroup.allCases.filter { groupMoves($0) } }
    var newDirCount: Int { Set(movingGroups.filter { !destExists($0) }.map { destURL($0).standardizedFileURL.path }).count }
    var outsideGroups: [OrgGroup] { movingGroups.filter { !isInside(destURL($0)) && destURL($0).standardizedFileURL.path != folder.standardizedFileURL.path } }
    func setDest(_ g: OrgGroup, _ d: OrgDest?) { dests[g.rawValue] = d; saveDests(); recomputeNames() }
    func renameDest(_ g: OrgGroup, _ typed: String) {
        let n = typed.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        let clean = n.hasPrefix(".") ? String(n.drop { $0 == "." }) : n
        setDest(g, clean.isEmpty || clean == g.label ? nil : OrgDest(name: clean))
        editingGroup = nil
    }
    func chooseDest(_ g: OrgGroup) {
        let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false; p.allowsMultipleSelection = false; p.canCreateDirectories = true
        p.directoryURL = destExists(g) ? destURL(g) : folder; p.prompt = t("Use this folder", "Dùng thư mục này")
        p.message = t("Files in \(g.label) will go into the folder you pick. You can make a new folder here.",
                      "File nhóm \(g.label) sẽ vào thư mục bạn chọn. Có thể tạo thư mục mới ngay tại đây.")
        guard p.runModal() == .OK, let u = p.url else { return }
        guard OrgEngine.allowed(u) else {
            let a = NSAlert(); a.messageText = t("Pick a folder inside your home folder", "Chọn một thư mục bên trong thư mục người dùng")
            a.informativeText = t("Tidymint does not move files into Library or system folders.", "Tidymint không chuyển file vào Library hay thư mục hệ thống.")
            a.runModal(); return
        }
        setDest(g, OrgDest(path: u.standardizedFileURL.path))
    }

    // MARK: where each file ends up

    struct Ctx { let folder: URL; let moving: Bool; var dests: [String: OrgDest] = [:] }
    var ctx: Ctx { Ctx(folder: folder, moving: moveIntoFolders, dests: dests) }

    /// The name a file will have after Apply. A typed name is cleaned the same way Apply cleans it;
    /// a file that goes with another one takes that file's new name with its own extension.
    static func finalName(_ f: OrgFile, _ by: [UUID: OrgFile]) -> String {
        let ext = OrgEngine.normExt(f.url.pathExtension)
        if let l = f.pairOf.flatMap({ by[$0] }) {
            let ln = finalName(l, by)
            let stem = (ln as NSString).deletingPathExtension
            guard stem != l.url.deletingPathExtension().lastPathComponent else { return f.name }
            return stem + (ext.isEmpty ? "" : "." + ext)
        }
        guard f.renameOn, let typed = f.newName else { return f.name }
        let nn = OrgEngine.safeStem(stripExt(typed, f), ext: ext)
        return nn.isEmpty ? f.name : nn + (ext.isEmpty ? "" : "." + ext)
    }
    /// A typed name may or may not include the extension.
    static func stripExt(_ typed: String, _ f: OrgFile) -> String {
        var nn = typed.trimmingCharacters(in: .whitespaces)
        for e in [f.url.pathExtension, OrgEngine.normExt(f.url.pathExtension)] where !e.isEmpty && nn.lowercased().hasSuffix("." + e.lowercased()) { nn = String(nn.dropLast(e.count + 1)) }
        return nn.trimmingCharacters(in: .whitespaces)
    }
    static func target(_ f: OrgFile, _ by: [UUID: OrgFile], _ c: Ctx) -> URL {
        let dir: URL
        if let l = f.pairOf.flatMap({ by[$0] }) { dir = target(l, by, c).deletingLastPathComponent() }
        else {
            let own = f.url.deletingLastPathComponent()
            // Only loose files are sorted; files already in a sub-folder stay there.
            dir = c.moving && own.standardizedFileURL.path == c.folder.standardizedFileURL.path ? Self.destURL(f.group, c.folder, c.dests) : own
        }
        return dir.appendingPathComponent(finalName(f, by))
    }

    var sameCache: [String: Bool] = [:]
    func same(_ a: URL, _ b: URL) -> Bool {
        let k = a.path + "|" + b.path
        if let v = sameCache[k] { return v }
        let v = OrgEngine.identical(a, b); sameCache[k] = v; return v
    }

    /// Check the plan before anything moves: two files given the same name, a name already taken, an identical copy
    /// already there, a typed name that had to be fixed. Each row shows what will happen instead.
    func validate() {
        // Files that go with another one follow its checkbox, rename switch and group.
        let lead = Dictionary(uniqueKeysWithValues: files.filter { $0.pairOf == nil }.map { ($0.id, $0) })
        for i in files.indices { if let l = files[i].pairOf.flatMap({ lead[$0] }) { files[i].include = l.include; files[i].renameOn = l.renameOn; files[i].group = l.group } }
        let inc = files.filter(\.include)
        let by = Dictionary(uniqueKeysWithValues: inc.map { ($0.id, $0) })
        let c = ctx, fm = FileManager.default
        var tg: [UUID: URL] = [:]
        for f in inc { tg[f.id] = Self.target(f, by, c) }
        func stays(_ f: OrgFile) -> Bool { tg[f.id]!.path.lowercased() == f.url.path.lowercased() }
        // Paths freed during Apply because their file moves away.
        let leaving = Set(inc.filter { !stays($0) }.map { $0.url.path.lowercased() })
        // Files that keep their place claim their name first.
        var claimed: [String: OrgFile] = [:]
        for f in inc where stays(f) { claimed[f.url.path.lowercased()] = f }
        var warn: [UUID: String] = [:], fate: [UUID: String] = [:]
        // The name a clash will really get: the first free "name 2", "name 3"... among files and names already handed out.
        var given = Set<String>()
        func numbered(_ to: URL) -> String {
            let base = to.deletingPathExtension().lastPathComponent, e = to.pathExtension
            var n = 2
            while true {
                let c = to.deletingLastPathComponent().appendingPathComponent("\(base) \(n)" + (e.isEmpty ? "" : ".\(e)"))
                if !given.contains(c.path.lowercased()) && !fm.fileExists(atPath: c.path) { given.insert(c.path.lowercased()); return c.lastPathComponent }
                n += 1
            }
        }
        for f in inc where !stays(f) {
            let to = tg[f.id]!, k = to.path.lowercased()
            if let first = claimed[k] {
                let dup = dedupe && same(f.url, first.url)
                warn[f.id] = dup
                    ? t("Identical to \(first.name): this copy goes to the Trash", "Giống hệt \(first.name): bản này vào Thùng rác")
                    : t("Same new name as \(first.name): gets \" 2\"", "Trùng tên mới với \(first.name): thêm \" 2\"")
                fate[f.id] = dup ? "" : numbered(to)
            } else if fm.fileExists(atPath: to.path), !leaving.contains(k) {
                let dup = dedupe && same(f.url, to)
                warn[f.id] = dup
                    ? t("An identical \(to.lastPathComponent) is already there: this copy goes to the Trash", "Đã có \(to.lastPathComponent) giống hệt: bản này vào Thùng rác")
                    : t("\(to.lastPathComponent) already exists: gets \" 2\"", "Đã có file \(to.lastPathComponent): thêm \" 2\"")
                fate[f.id] = dup ? "" : numbered(to)
            } else { claimed[k] = f; given.insert(k) }
        }
        for f in inc where f.pairOf == nil && f.renameOn {
            guard let typed = f.newName else { continue }
            let raw = Self.stripExt(typed, f), safe = OrgEngine.safeStem(raw, ext: OrgEngine.normExt(f.url.pathExtension))
            var w: String? = nil
            if safe.isEmpty { w = t("Empty name: keeps the old name", "Tên trống: giữ tên cũ") }
            else if safe != raw { w = t("Name fixed to be valid: \(safe)", "Tên được sửa cho hợp lệ: \(safe)") }
            if let w { warn[f.id] = warn[f.id].map { $0 + " · " + w } ?? w }
        }
        for i in files.indices {
            files[i].warn = warn[files[i].id]
            files[i].fate = fate[files[i].id]
            if files[i].pairOf != nil {
                let n = Self.finalName(files[i], by)
                files[i].newName = n == files[i].name ? nil : n
            }
        }
    }

    // MARK: carrying out a plan

    struct Outcome { var moves: [OrgMove] = []; var made: [String] = []; var moved = 0, tagged = 0, fail = 0, trashed = 0; var notes: [OrgNote] = [] }
    /// Plain reason for a refused move, instead of the system's English message.
    static func reason(_ e: Error) -> String {
        switch (e as? CocoaError)?.code {
        case .fileWriteNoPermission?, .fileReadNoPermission?: return t("No permission to change it", "Không có quyền đổi file này")
        case .fileNoSuchFile?, .fileReadNoSuchFile?: return t("The file is no longer there", "File không còn ở đó")
        case .fileWriteVolumeReadOnly?: return t("The disk is read-only", "Ổ đĩa chỉ cho đọc")
        case .fileWriteFileExists?: return t("That name is already taken", "Tên này đã có file khác")
        case .fileLocking?: return t("The file is locked or in use", "File đang bị khoá hoặc đang mở")
        default: return (e as NSError).localizedDescription
        }
    }

    /// Never overwrite: "name 2.ext", "name 3.ext"... The file itself does not count as taken (a change of case only).
    static func free(_ u: URL, keeping src: URL) -> URL {
        let fm = FileManager.default
        if !fm.fileExists(atPath: u.path) || OrgEngine.sameFile(u, src) { return u }
        let base = u.deletingPathExtension().lastPathComponent, e = u.pathExtension, dir = u.deletingLastPathComponent()
        var n = 2
        while true {
            let c = dir.appendingPathComponent("\(base) \(n)" + (e.isEmpty ? "" : ".\(e)"))
            if !fm.fileExists(atPath: c.path) || OrgEngine.sameFile(c, src) { return c }
            n += 1
        }
    }

    /// Carry out a plan. A file whose new name is still held by another planned file waits until that file has moved;
    /// a real clash gets " 2", or goes to the Trash when it is a byte-for-byte copy (if that switch is on).
    /// Files that go with another one follow it last, so they get its final name even if that got " 2".
    static func execute(_ list: [OrgFile], _ c: Ctx, dedupe: Bool) -> Outcome {
        let fm = FileManager.default
        var o = Outcome(), notes = OrgNotes.load()
        let by = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
        var dest: [UUID: URL] = [:], order: [UUID] = []
        func ensureDir(_ d: URL) -> Bool {
            if fm.fileExists(atPath: d.path) { return true }
            do { try fm.createDirectory(at: d, withIntermediateDirectories: false); o.made.append(d.path); return true } catch { return false }
        }
        func place(_ f: OrgFile, _ want: URL, mayTrash: Bool) {
            var to = want
            defer { if dest[f.id] != nil { order.append(f.id) } }
            // Moved or deleted since the plan was made: nothing to do, say so.
            guard fm.fileExists(atPath: f.url.path) else {
                o.fail += 1
                o.notes.append(OrgNote(kind: .skipped, name: f.name, detail: t("The file is no longer there (moved or deleted after planning)", "File không còn ở đó (đã bị chuyển hoặc xoá sau khi lập kế hoạch)")))
                return
            }
            if to.path == f.url.path { dest[f.id] = f.url; return }
            guard ensureDir(to.deletingLastPathComponent()) else {
                o.fail += 1; dest[f.id] = f.url
                o.notes.append(OrgNote(kind: .skipped, name: f.name, detail: t("Could not create the folder \(to.deletingLastPathComponent().lastPathComponent)", "Không tạo được thư mục \(to.deletingLastPathComponent().lastPathComponent)")))
                return
            }
            if fm.fileExists(atPath: to.path) && !OrgEngine.sameFile(to, f.url) {
                if mayTrash && dedupe && OrgEngine.identical(f.url, to) {
                    var res: NSURL?
                    if (try? fm.trashItem(at: f.url, resultingItemURL: &res)) != nil {
                        o.trashed += 1
                        o.moves.append(OrgMove(from: f.url.path, to: (res as URL?)?.path ?? "", addedTags: [], trashed: true))
                        notes.removeValue(forKey: f.url.path)
                        o.notes.append(OrgNote(kind: .trashed, name: f.name, detail: t("Identical to \(to.lastPathComponent), this copy is in the Trash", "Giống hệt \(to.lastPathComponent), bản này đã vào Thùng rác")))
                        return
                    }
                }
                let taken = to.lastPathComponent
                to = free(to, keeping: f.url)
                if to.lastPathComponent != taken {
                    o.notes.append(OrgNote(kind: .numbered, name: f.name, detail: t("\(taken) was taken, named \(to.lastPathComponent)", "Đã có \(taken), nên đặt là \(to.lastPathComponent)")))
                }
            }
            do { try OrgEngine.move(f.url, to) }
            catch {
                // The new name was refused: keep the original name rather than skip the file.
                let why = reason(error)
                to = free(to.deletingLastPathComponent().appendingPathComponent(f.name), keeping: f.url)
                if to.path != f.url.path {
                    do { try OrgEngine.move(f.url, to) } catch {
                        o.fail += 1; dest[f.id] = f.url
                        o.notes.append(OrgNote(kind: .skipped, name: f.name, detail: reason(error)))
                        return
                    }
                }
                o.notes.append(OrgNote(kind: to.path == f.url.path ? .skipped : .kept, name: f.name, detail: t("Could not use the new name (\(why)), kept the old one", "Không đặt được tên mới (\(why)), giữ tên cũ")))
            }
            dest[f.id] = to
            if to.path != f.url.path { o.moved += 1 }
        }
        var pending = list.filter { $0.pairOf.flatMap { by[$0] } == nil }
        let followers = list.filter { $0.pairOf.flatMap { by[$0] } != nil }
        while !pending.isEmpty {
            // Who still sits on a path it is about to leave.
            var owner: [String: UUID] = [:]
            for f in pending where target(f, by, c).path.lowercased() != f.url.path.lowercased() { owner[f.url.path.lowercased()] = f.id }
            var later: [OrgFile] = []
            for f in pending {
                let want = target(f, by, c), k = want.path.lowercased()
                if k != f.url.path.lowercased(), let w = owner[k], w != f.id, dest[w] == nil { later.append(f); continue }
                place(f, want, mayTrash: true)
            }
            // A loop (A wants B's name and B wants A's): " 2" breaks it.
            if later.count == pending.count { for f in later { place(f, target(f, by, c), mayTrash: true) }; break }
            pending = later
        }
        for f in followers {
            guard let l = by[f.pairOf!], let ld = dest[l.id] else { continue }   // its file went to the Trash or failed: leave it
            let ext = OrgEngine.normExt(f.url.pathExtension), stem = ld.deletingPathExtension().lastPathComponent
            let name = stem == l.url.deletingPathExtension().lastPathComponent ? f.name : stem + (ext.isEmpty ? "" : "." + ext)
            place(f, ld.deletingLastPathComponent().appendingPathComponent(name), mayTrash: false)
        }
        for id in order {
            guard let f = by[id], let d = dest[id] else { continue }
            let old = (try? d.resourceValues(forKeys: [.tagNamesKey]).tagNames) ?? []
            let add = f.tags.filter { f.tagOn.contains($0) && !old.contains($0) }
            if !add.isEmpty {
                do { try (d as NSURL).setResourceValue(old + add, forKey: .tagNamesKey); o.tagged += 1 } catch { }
            }
            notes.removeValue(forKey: f.url.path)
            if !f.note.trimmingCharacters(in: .whitespaces).isEmpty { notes[d.path] = f.note }
            o.moves.append(OrgMove(from: f.url.path, to: d.path, addedTags: add))
        }
        OrgNotes.save(notes)
        return o
    }

    /// Apply the reviewed plan: optional move into a subfolder per group, optional rename, tags and notes.
    func apply() {
        validate()
        let away = outsideGroups.map { "\(destURL($0).lastPathComponent) → \(destLabel($0))" }
        let o = Self.execute(included, ctx, dedupe: dedupe)
        report = o.notes
        let s = OrgSession(folder: folder.path, date: Date(), moves: o.moves, madeDirs: o.made)
        if let d = try? JSONEncoder().encode(s) { try? d.write(to: URL(fileURLWithPath: OrgVM.sessionPath)) }
        canUndo = true
        let dup = o.trashed > 0 ? t(" \(o.trashed) identical copies went to the Trash.", " \(o.trashed) bản trùng y hệt đã vào Thùng rác.") : ""
        result = t("Organized \(o.moved) files, tagged \(o.tagged).", "Đã sắp xếp \(o.moved) file, gắn tag \(o.tagged) file.") + dup + (o.fail > 0 ? t(" \(o.fail) skipped.", " Bỏ qua \(o.fail) file.") : "")
            + (away.isEmpty ? "" : t(" Moved out of \(folder.lastPathComponent): ", " Chuyển ra ngoài \(folder.lastPathComponent): ") + away.joined(separator: ", ") + ".")
        vm?.log(t("Organized \(folder.lastPathComponent): moved or renamed \(o.moved) files, tagged \(o.tagged)", "Sắp xếp \(folder.lastPathComponent): chuyển hoặc đổi tên \(o.moved) file, gắn tag \(o.tagged) file")
                + (o.trashed > 0 ? t(", \(o.trashed) identical copies to the Trash", ", \(o.trashed) bản trùng vào Thùng rác") : "")
                + (o.fail > 0 ? t(", skipped \(o.fail)", ", bỏ qua \(o.fail)") : ""))
        phase = .done; files = []
    }

    static func load(_ p: String) -> OrgSession? {
        guard let d = FileManager.default.contents(atPath: p) else { return nil }
        return try? JSONDecoder().decode(OrgSession.self, from: d)
    }
    /// The newest thing to undo: the last manual organize or the newest automatic batch.
    static func latest() -> (String, OrgSession)? {
        let manual = load(sessionPath).map { (sessionPath, $0) }
        let auto = history().first.map { ("auto:" + ($0.id ?? ""), $0) }
        return [manual, auto].compactMap { $0 }.max { $0.1.date < $1.1.date }
    }
    static let historyPath = Stats.dir + "/organize-auto-history.json"
    /// Automatic batches from the last 7 days, newest first. Each one can be undone on its own.
    static func history() -> [OrgSession] {
        var h = FileManager.default.contents(atPath: historyPath).flatMap { try? JSONDecoder().decode([OrgSession].self, from: $0) } ?? []
        // Older builds kept one automatic session per day in a single file.
        if var old = load(autoPath) {
            old.id = old.id ?? UUID().uuidString; h.append(old); h.sort { $0.date > $1.date }
            try? FileManager.default.removeItem(atPath: autoPath); saveHistory(h)
        }
        let cut = Date().addingTimeInterval(-7 * 86400)
        return h.filter { $0.date > cut }
    }
    static func saveHistory(_ h: [OrgSession]) {
        let cut = Date().addingTimeInterval(-7 * 86400)
        let keep = Array(h.filter { $0.date > cut }.sorted { $0.date > $1.date }.prefix(300))
        try? FileManager.default.createDirectory(atPath: Stats.dir, withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(keep) { try? d.write(to: URL(fileURLWithPath: historyPath)) }
    }
    /// Undo one automatic batch (from the list or the notification).
    func undoBatch(_ id: String) {
        guard let s = Self.history().first(where: { $0.id == id }) else { return }
        // From a notification while a plan is open: undo, but keep the plan on screen.
        let keep = phase == .review || phase == .scanning ? phase : nil, msg = result
        revert(s, key: "auto:" + id)
        if let keep { phase = keep; result = msg }
    }
    @Published var historyOpen = false
    @Published var historyTick = 0
    static func lastSession() -> OrgSession? { latest()?.1 }

    /// Put every file back where it was (also copies sent to the Trash), remove the tags this session added,
    /// remove folders it created if now empty.
    func undo() {
        guard let (path, s) = OrgVM.latest() else { return }
        revert(s, key: path)
    }
    func revert(_ s: OrgSession, key path: String) {
        let fm = FileManager.default
        var back = 0, fail = 0, notes = OrgNotes.load()
        for m in s.moves.reversed() {
            let to = URL(fileURLWithPath: m.to), from = URL(fileURLWithPath: m.from)
            if !m.addedTags.isEmpty, let cur = try? to.resourceValues(forKeys: [.tagNamesKey]).tagNames {
                try? (to as NSURL).setResourceValue(cur.filter { !m.addedTags.contains($0) }, forKey: .tagNamesKey)
            }
            if let n = notes.removeValue(forKey: m.to) { notes[m.from] = n }
            if m.to != m.from {
                guard !m.to.isEmpty, fm.fileExists(atPath: m.to), !fm.fileExists(atPath: m.from) || OrgEngine.sameFile(to, from) else { fail += 1; continue }
                do { try OrgEngine.move(to, from); back += 1 } catch { fail += 1 }
            }
        }
        for d in s.madeDirs.reversed() where ((try? fm.contentsOfDirectory(atPath: d))?.filter { $0 != ".DS_Store" }.isEmpty ?? false) {
            try? fm.removeItem(atPath: d + "/.DS_Store"); try? fm.removeItem(atPath: d)
        }
        OrgNotes.save(notes)
        if path.hasPrefix("auto:") { Self.saveHistory(Self.history().filter { $0.id != s.id }) } else { try? fm.removeItem(atPath: path) }
        historyTick += 1
        report = []
        canUndo = OrgVM.lastSession() != nil
        result = t("Put back \(back) files.", "Đã đưa \(back) file về chỗ cũ.") + (fail > 0 ? t(" \(fail) could not be moved back.", " \(fail) file không đưa về được.") : "")
        vm?.log(t("Undid organizing \((s.folder as NSString).lastPathComponent): \(back) files back", "Hoàn tác sắp xếp \((s.folder as NSString).lastPathComponent): đưa \(back) file về chỗ cũ") + (fail > 0 ? t(", \(fail) could not be moved back", ", \(fail) file không đưa về được") : ""))
        phase = .done
    }

    // MARK: keep Downloads tidy

    static let autoPath = Stats.dir + "/organize-auto.json"
    /// The watched folder: Downloads, or a test folder given with `--watch-folder`.
    static var watchDir = Scanner.home.appendingPathComponent("Downloads")
    static let partialExt: Set<String> = ["crdownload", "download", "part", "partial", "tmp", "opdownload", "aria2"]
    private var watchTimer: Timer?
    private var watchSeen = Set<String>()
    private var watchSize: [String: Int64] = [:]
    private var watchBusy = false
    static let lastRunKey = "org-watch-last"

    /// Files Tidymint sorted, by file number (it survives renames and moves): one the person brings back to Downloads is left alone.
    nonisolated static let movedPath = Stats.dir + "/organize-auto-moved.json"
    private var movedIDs: [String: Date] = OrgVM.loadMoved()
    nonisolated static func loadMoved() -> [String: Date] {
        let m = FileManager.default.contents(atPath: movedPath).flatMap { try? JSONDecoder().decode([String: Date].self, from: $0) } ?? [:]
        let cut = Date().addingTimeInterval(-90 * 86400)
        return m.filter { $0.value > cut }
    }
    func saveMoved() { if let d = try? JSONEncoder().encode(movedIDs) { try? d.write(to: URL(fileURLWithPath: Self.movedPath)) } }
    nonisolated static func fileNumber(_ u: URL) -> String? {
        ((try? FileManager.default.attributesOfItem(atPath: u.path))?[.systemFileNumber] as? NSNumber).map { $0.stringValue }
    }

    /// Never touched by Keep Downloads tidy: ".torrent" is an extension, anything else is part of the name. Comma separated.
    @Published var exclude = UserDefaults.standard.string(forKey: "org-exclude") ?? "" {
        didSet { UserDefaults.standard.set(exclude, forKey: "org-exclude") }
    }
    nonisolated static func excluded(_ u: URL, _ pats: String) -> Bool {
        let n = u.lastPathComponent.lowercased(), e = u.pathExtension.lowercased()
        for raw in pats.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" }) {
            let p = raw.trimmingCharacters(in: .whitespaces).lowercased()
            if p.isEmpty { continue }
            if p.hasPrefix("."), !p.dropFirst().contains(".") { if e == String(p.dropFirst()) { return true } }
            else if n.contains(p) { return true }
        }
        return false
    }

    /// Watch Downloads while Tidymint runs (window or menu bar). Turning the switch on leaves files already there alone;
    /// when the app starts (catchUp), files that landed while it was closed are sorted too.
    /// A new file is moved once it has stopped changing for 2 minutes and no other app has it open.
    func startWatch(catchUp: Bool = false) {
        stopWatch()
        let since = catchUp ? (UserDefaults.standard.object(forKey: Self.lastRunKey) as? Date)?.addingTimeInterval(-300) : nil
        watchSeen = Set(OrgEngine.files(in: Self.watchDir).filter { u in
            guard let s = since, let added = (try? u.resourceValues(forKeys: [.addedToDirectoryDateKey]))?.addedToDirectoryDate else { return true }
            return added <= s
        }.map(\.path))
        UserDefaults.standard.set(Date(), forKey: Self.lastRunKey)
        watchTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { _ in Task { @MainActor in sharedOrg.watchTick() } }
    }
    func stopWatch() { watchTimer?.invalidate(); watchTimer = nil; watchSize = [:] }

    func watchTick() {
        UserDefaults.standard.set(Date(), forKey: Self.lastRunKey)
        // Not while the person is planning that same folder by hand.
        let busyHere = (phase == .scanning || phase == .review) && folder.standardizedFileURL.path == Self.watchDir.standardizedFileURL.path
        guard !watchBusy, !busyHere else { return }
        var ready: [URL] = []
        let now = Date(), pats = exclude
        for u in OrgEngine.files(in: Self.watchDir) where !watchSeen.contains(u.path) {
            if Self.partialExt.contains(u.pathExtension.lowercased()) { continue }
            // Brought back by the person after Tidymint sorted it, or on the do-not-touch list: leave it where it is.
            if let id = Self.fileNumber(u), movedIDs[id] != nil { watchSeen.insert(u.path); continue }
            if Self.excluded(u, pats) { watchSeen.insert(u.path); continue }
            let v = try? u.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(v?.fileSize ?? -1)
            // Same size as last check and untouched for 2 minutes: the download has finished.
            if watchSize[u.path] == size, let m = v?.contentModificationDate, now.timeIntervalSince(m) > 120 { ready.append(u) }
            else { watchSize[u.path] = size }
        }
        guard !ready.isEmpty else { return }
        watchBusy = true
        let deep = readContent, r = rule, all = renameAll, dd = dedupe
        Task.detached {
            // A file still open in another app waits for the next check.
            let free = ready.filter { !OrgEngine.isOpen($0) }
            var list: [OrgFile] = free.map { var o = OrgEngine.quick($0); if deep { OrgEngine.deep(&o) }; return o }
            OrgEngine.linkPairs(&list)
            let done = list
            await MainActor.run { sharedOrg.autoApply(done, rule: r, renameAll: all, dedupe: dd) }
        }
    }

    func autoApply(_ input: [OrgFile], rule r: NameRule, renameAll all: Bool, dedupe dd: Bool) {
        defer { watchBusy = false }
        for f in input { watchSeen.insert(f.url.path); watchSize.removeValue(forKey: f.url.path) }
        var list = input
        let dir = Self.watchDir, dd2 = Self.autoDests(for: dir)
        let lead = Dictionary(uniqueKeysWithValues: list.filter { $0.pairOf == nil }.map { ($0.id, $0) })
        for i in list.indices { if let l = list[i].pairOf.flatMap({ lead[$0] }) { list[i].group = l.group } }
        // Names follow the current rule: only names that say nothing, unless "rename all" is on. Numbers continue the folder's count.
        var counters: [String: Int] = [:]
        for i in list.indices where list[i].pairOf == nil && (all || list[i].needsName) {
            let g = list[i].group.label
            if counters[g] == nil { counters[g] = OrgEngine.files(in: Self.destURL(list[i].group, dir, dd2)).count }
            counters[g]! += 1
            let n = OrgEngine.makeName(list[i], r, seq: counters[g]!, parent: dir.lastPathComponent)
            if n != list[i].name { list[i].newName = n; list[i].renameOn = true }
        }
        let o = Self.execute(list, Ctx(folder: dir, moving: true, dests: dd2), dedupe: dd)
        guard !o.moves.isEmpty else { return }
        // Each batch is kept for 7 days and can be undone on its own.
        let s = OrgSession(folder: dir.path, date: Date(), moves: o.moves, madeDirs: o.made, auto: true, id: UUID().uuidString)
        Self.saveHistory([s] + Self.history())
        for m in o.moves where m.trashed != true { if let n = Self.fileNumber(URL(fileURLWithPath: m.to)) { movedIDs[n] = Date() } }
        saveMoved()
        canUndo = true; historyTick += 1
        vm?.log(t("Kept \(dir.lastPathComponent) tidy: moved \(o.moved) new files", "Tự xếp \(dir.lastPathComponent): chuyển \(o.moved) file mới")
                + (o.trashed > 0 ? t(", \(o.trashed) identical copies to the Trash", ", \(o.trashed) bản trùng vào Thùng rác") : ""))
        notifyAuto(s, moved: o.moved, trashed: o.trashed)
    }

    /// "Sorted 3 new downloads · Screenshots: 2 · Documents: 1", with Show in Finder and Undo.
    func notifyAuto(_ s: OrgSession, moved: Int, trashed: Int) {
        let kept = s.moves.filter { $0.trashed != true }
        let by = Dictionary(grouping: kept) { URL(fileURLWithPath: $0.to).deletingLastPathComponent().lastPathComponent }
        let c = UNMutableNotificationContent()
        c.title = t("Sorted \(moved) new downloads", "Đã xếp \(moved) file vừa tải về")
        c.body = by.keys.sorted().map { "\($0): \(by[$0]!.count)" }.joined(separator: " · ")
            + (trashed > 0 ? t(" · \(trashed) identical copies to the Trash", " · \(trashed) bản trùng vào Thùng rác") : "")
        c.categoryIdentifier = "org-auto"
        let dirs = Set(kept.map { URL(fileURLWithPath: $0.to).deletingLastPathComponent().path })
        let reveal = kept.count == 1 ? kept[0].to : (dirs.count == 1 ? dirs.first! : s.folder)
        c.userInfo = ["batch": s.id ?? "", "reveal": reveal]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: s.id ?? UUID().uuidString, content: c, trigger: nil))
    }
}

/// Notifications: shown while Tidymint is in front too; Show in Finder and Undo on a Keep Downloads tidy batch.
final class OrgNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = OrgNotifier()
    func install() {
        let open = UNNotificationAction(identifier: "open", title: t("Show in Finder", "Mở thư mục"), options: [.foreground])
        let undo = UNNotificationAction(identifier: "undo", title: t("Undo", "Hoàn tác"), options: [])
        let c = UNUserNotificationCenter.current()
        c.setNotificationCategories([UNNotificationCategory(identifier: "org-auto", actions: [open, undo], intentIdentifiers: [], options: [])])
        c.delegate = self
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) { done([.banner, .sound]) }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler done: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let batch = info["batch"] as? String ?? "", reveal = info["reveal"] as? String ?? "", act = response.actionIdentifier
        let isAuto = response.notification.request.content.categoryIdentifier == "org-auto"
        Task { @MainActor in
            if act == "undo" { sharedOrg.undoBatch(batch) }
            else if isAuto && !reveal.isEmpty {
                let u = URL(fileURLWithPath: reveal)
                if OrgVM.isDir(u) { NSWorkspace.shared.open(u) } else if FileManager.default.fileExists(atPath: reveal) { NSWorkspace.shared.activateFileViewerSelecting([u]) }
            }
        }
        done()
    }
}

let sharedOrg = MainActor.assumeIsolated { OrgVM() }

struct OrganizeView: View {
    @ObservedObject var vm: VM
    @ObservedObject var org = sharedOrg
    var body: some View {
        VStack(spacing: 0) {
            switch org.phase {
            case .idle: OrgStart(org: org)
            case .scanning:
                VStack(spacing: 18) {
                    ProgressView(value: Double(org.progress), total: Double(max(org.total, 1))).tint(Theme.accentSolid).frame(width: 320)
                    Text(t("Reading \(org.progress) of \(org.total)", "Đang đọc \(org.progress)/\(org.total)")).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                    Text(org.current).foregroundColor(Theme.sub).font(.system(size: fs(12))).lineLimit(1).truncationMode(.middle).frame(maxWidth: 420)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            case .done:
                VStack(spacing: 18) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: fs(40))).foregroundColor(Theme.green)
                    Text(org.result).font(.system(size: fs(17), weight: .semibold)).foregroundColor(Theme.text).multilineTextAlignment(.center)
                    if !org.report.isEmpty { OrgReport(lines: org.report).frame(width: 560) }
                    HStack(spacing: 12) {
                        GhostButton(title: t("Show in Finder", "Mở trong Finder")) { NSWorkspace.shared.open(org.folder) }
                        if org.canUndo { GhostButton(title: t("Undo", "Hoàn tác")) { org.undo() } }
                        PrimaryButton(title: t("Done", "Xong"), action: { org.phase = .idle })
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            default: OrgPlan(org: org)
            }
        }.onAppear { org.vm = vm }
    }
}

struct OrgStart: View {
    @ObservedObject var org: OrgVM
    var body: some View {
        VStack(spacing: 24) {
            Header(title: t("Organize a Folder", "Sắp xếp thư mục"),
                   sub: t("Tidymint proposes subfolders, clearer names and tags. You review everything before it moves.\nRuns on this Mac, nothing is uploaded. Nothing is deleted.",
                          "Tidymint đề xuất thư mục con, tên dễ đọc và tag. Bạn xem hết rồi mới chuyển.\nChạy ngay trên máy, không gửi gì đi. Không xoá file nào."))
            HStack(spacing: 12) {
                Image(systemName: "folder").font(.system(size: fs(18))).foregroundColor(Theme.accentSolid)
                Text(org.folder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")).foregroundColor(Theme.text).font(.system(size: fs(14))).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 12)
                GhostButton(title: t("Choose folder", "Chọn thư mục")) { org.choose() }
            }.padding(14).frame(width: 520).background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            VStack(spacing: 4) {
                OrgSwitchRow(title: t("Read content of images and PDFs", "Đọc nội dung ảnh và PDF"),
                             sub: t("Finds receipts and CVs, suggests tags like Food or Beach. Uses macOS's built-in recognition, slower.",
                                    "Nhận ra hoá đơn, CV, gợi ý tag như Đồ ăn, Biển. Dùng nhận diện có sẵn của macOS, chậm hơn."), on: $org.readContent)
                OrgSwitchRow(title: t("Include sub-folders", "Gồm cả thư mục con"),
                             sub: t("Files in sub-folders are renamed and tagged where they are. Only loose files are sorted into folders. App bundles and code projects are skipped.",
                                    "File trong thư mục con được đổi tên và gắn tag tại chỗ. Chỉ file nằm rời mới được xếp vào thư mục. Bỏ qua gói app và thư mục dự án code."), on: $org.includeSub)
                OrgSwitchRow(title: t("Put identical copies in the Trash", "Bỏ bản trùng y hệt vào Thùng rác"),
                             sub: t("When a new name is taken by a file with exactly the same content, the extra copy goes to the Trash instead of getting \" 2\". Undo brings it back.",
                                    "Khi tên mới trùng một file có nội dung giống hệt, bản thừa vào Thùng rác thay vì thêm \" 2\". Hoàn tác sẽ lấy lại."), on: $org.dedupe)
                OrgSwitchRow(title: t("Keep Downloads tidy", "Tự xếp thư mục Tải về"),
                             sub: t("New downloads go into their type folder inside Downloads about 2 minutes after they finish, named by your rule. A file still open in another app waits, and a file you drag back to Downloads stays there. Works while Tidymint is open, even only in the menu bar; downloads that came while it was closed are sorted when it opens. Files already there when you turn this on are left alone.",
                                    "File mới tải về được chuyển vào thư mục theo loại ngay trong Tải về, khoảng 2 phút sau khi tải xong, đặt tên theo quy tắc của bạn. File đang mở trong app khác sẽ chờ; file bạn kéo ra lại Tải về được để yên. Chạy khi Tidymint đang mở, kể cả chỉ ở thanh menu; file tải lúc app tắt được xếp khi mở lại. File có sẵn lúc bật không bị động tới."), on: $org.watchDownloads)
                if org.watchDownloads {
                    HStack(spacing: 8) {
                        Text(t("Never touch:", "Không động tới:")).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                        TextField(t(".torrent, invoice", ".torrent, hoá đơn"), text: $org.exclude).textFieldStyle(.roundedBorder).font(.system(size: fs(12)))
                            .tip(t("Comma separated. \".mkv\" skips that extension, any other word skips files whose name contains it.",
                                    "Cách nhau bằng dấu phẩy. \".mkv\" bỏ qua đuôi đó, chữ khác thì bỏ qua file có tên chứa chữ đó."))
                    }.padding(.horizontal, 14).padding(.bottom, 4)
                }
                OrgHistory(org: org)
            }.frame(width: 520)
            BigScanButton(label: t("Plan", "Lập kế hoạch")) { org.plan() }
            if org.canUndo { TextLink(t("Undo the last organize", "Hoàn tác lần sắp xếp gần nhất"), size: fs(12)) { org.undo() } }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct OrgPlan: View {
    @ObservedObject var org: OrgVM
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(t("Plan for \(org.folder.lastPathComponent) (\(org.files.count) files)", "Kế hoạch cho \(org.folder.lastPathComponent) (\(org.files.count) file)"))
                    .font(.system(size: fs(17), weight: .semibold)).foregroundColor(Theme.text)
                Spacer()
                PillSwitch(options: [(false, t("Rename only", "Chỉ đổi tên"), t("Keep files where they are, only rename them", "Giữ file ở chỗ cũ, chỉ đổi tên"), nil),
                                     (true, t("Sort into folders", "Sắp xếp vào thư mục"), t("Make a folder per type and move files into it", "Tạo thư mục theo loại và chuyển file vào"), nil)],
                           value: $org.moveIntoFolders)
                Button { org.plan() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.icon).foregroundColor(Theme.text).tip(t("Plan again", "Lập lại kế hoạch"), trailing: true)
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 8)
            if org.moveIntoFolders && !org.files.isEmpty {
                let n = org.newDirCount
                let made = n > 0 ? t("Creates \(n) new folders in \(org.folder.lastPathComponent).", "Tạo \(n) thư mục mới trong \(org.folder.lastPathComponent).") : ""
                let stay = org.includeSub ? t(" Files already in sub-folders stay where they are, only renamed.", " File đã nằm trong thư mục con cũ giữ nguyên chỗ, chỉ đổi tên.") : ""
                if !(made + stay).isEmpty {
                    Text((made + stay).trimmingCharacters(in: .whitespaces)).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.bottom, 6)
                }
            }
            OrgNameBar(org: org).padding(.horizontal, 24).padding(.bottom, 10)
            OrgShowBar(org: org).padding(.horizontal, 24).padding(.bottom, 10)
            if org.files.isEmpty {
                Text(org.includeSub ? t("No files in this folder.", "Không có file nào trong thư mục này.") : t("No files directly in this folder. Turn on \"Include sub-folders\" to look inside.", "Không có file nào nằm trực tiếp trong thư mục này. Bật \"Gồm cả thư mục con\" để xem bên trong.")).foregroundColor(Theme.sub).frame(maxHeight: .infinity)
            } else if org.groups.isEmpty {
                VStack(spacing: 10) {
                    Text(org.show == .check ? t("Nothing to check: every file goes as planned.", "Không còn file nào cần xem: mọi file đều đúng kế hoạch.")
                                            : t("No file gets a new name.", "Không có file nào đổi tên."))
                        .foregroundColor(Theme.sub).font(.system(size: fs(14)))
                    TextLink(t("Show all files", "Xem tất cả file"), size: fs(13)) { org.show = .all }
                }.frame(maxHeight: .infinity)
            } else if org.treeView {
                OrgTreeView(org: org)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(org.groups, id: \.self) { g in OrgGroupBlock(org: org, g: g).id(g) }
                        }.padding(.horizontal, 24).padding(.bottom, 12)
                    }
                    // Rows sit inside lazily built groups: bring the group in first, then the row.
                    .onAppear {
                        guard let id = org.focus, let f = org.file(id) else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { proxy.scrollTo(f.group, anchor: .top) }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                    }
                }
            }
            HStack {
                let inc = org.included
                Text(selLabel(inc.count, inc.reduce(0) { $0 + $1.size })).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                Text(t("· \(inc.reduce(0) { $0 + $1.tagOn.count }) tags", "· \(inc.reduce(0) { $0 + $1.tagOn.count }) tag")).foregroundColor(Theme.sub).font(.system(size: fs(13)))
                Spacer()
                if org.moveIntoFolders && !org.outsideGroups.isEmpty {
                    let n = org.outsideGroups.count
                    let auto = org.watchDownloads && org.folder.standardizedFileURL.path == OrgVM.watchDir.standardizedFileURL.path
                    Text(t("\(n) group(s) go outside \(org.folder.lastPathComponent). Undo puts everything back.", "Có \(n) nhóm chuyển ra ngoài \(org.folder.lastPathComponent). Hoàn tác trả lại tất cả.")
                         + (auto ? t(" New downloads still stay inside Downloads.", " File mới tải về vẫn xếp trong Tải về.") : ""))
                        .foregroundColor(Theme.sub).font(.system(size: fs(12))).lineLimit(2).padding(.trailing, 6)
                }
                GhostButton(title: t("Cancel", "Huỷ")) { org.phase = .idle; org.files = [] }
                PrimaryButton(title: t("Apply", "Áp dụng"), action: { org.apply() }, disabled: inc.isEmpty)
            }.padding(.horizontal, 24).padding(.vertical, 14).background(Theme.shade.opacity(0.25))
        }
    }
}

struct OrgGroupBlock: View {
    @ObservedObject var org: OrgVM
    let g: OrgGroup
    var body: some View {
        let ids = org.idx(g)
        let on = ids.filter { org.files[$0].include }.count
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    let v = on < ids.count
                    for i in ids where i < org.files.count { org.files[i].include = v }
                    org.validate()
                } label: { CheckBox(state: on == 0 ? 0 : (on == ids.count ? 2 : 1)) }.buttonStyle(.plain)
                Image(systemName: g.icon).font(.system(size: fs(18))).foregroundColor(Theme.accentSolid).frame(width: 24)
                let mv = org.groupMoves(g)
                VStack(alignment: .leading, spacing: 2) {
                    if org.editingGroup == g {
                        TextField(g.label, text: $org.groupDraft).textFieldStyle(.plain).foregroundColor(Theme.text)
                            .font(.system(size: fs(15), weight: .semibold)).frame(width: 220 * uiScale)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accentSolid, lineWidth: 1))
                            .onSubmit { org.renameDest(g, org.groupDraft) }
                            .onExitCommand { org.editingGroup = nil }
                    } else {
                        Text(mv ? org.destURL(g).lastPathComponent + "/" : g.label).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                    }
                    HStack(spacing: 6) {
                        Text(t("\(ids.count) files · \(fmt(ids.reduce(0) { $0 + org.files[$1].size }))", "\(ids.count) file · \(fmt(ids.reduce(0) { $0 + org.files[$1].size }))"))
                        if mv {
                            Text("→ " + org.destLabel(g)).lineLimit(1).truncationMode(.middle)
                            let fresh = !org.destExists(g)
                            Text(fresh ? t("NEW", "MỚI") : t("EXISTING", "CÓ SẴN")).font(.system(size: fs(9), weight: .semibold))
                                .foregroundColor(fresh ? Theme.accentSolid : Theme.text).padding(.horizontal, 6).padding(.vertical, 1)
                                .background(Capsule().fill(fresh ? Theme.accentSolid.opacity(0.18) : Theme.sub.opacity(0.18)))
                                .tip(fresh ? t("This folder is created when you Apply", "Thư mục sẽ được tạo khi áp dụng") : t("This folder already exists, files are added to it", "Thư mục đã có, file được thêm vào"))
                        }
                    }.foregroundColor(Theme.sub).font(.system(size: fs(11)))
                }
                Spacer()
                if mv {
                    Menu {
                        Button(t("Rename folder…", "Đổi tên thư mục…")) { org.groupDraft = org.destURL(g).lastPathComponent; org.editingGroup = g }
                        Button(t("Choose an existing folder…", "Chọn thư mục có sẵn…")) { org.chooseDest(g) }
                        Divider()
                        Button(t("Back to default (in \(org.folder.lastPathComponent))", "Về mặc định (trong \(org.folder.lastPathComponent))")) { org.setDest(g, nil) }
                            .disabled(org.dests[g.rawValue] == nil)
                    } label: { Text(t("Change", "Đổi")).font(.system(size: fs(12))) }
                        .menuStyle(.borderlessButton).fixedSize().foregroundColor(Theme.text)
                        .padding(.horizontal, 8).padding(.vertical, 3).hoverTile()
                        .tip(t("Rename this folder or pick another one", "Đổi tên thư mục này hoặc chọn thư mục khác"), trailing: true)
                }
                Button { if org.collapsed.contains(g) { org.collapsed.remove(g) } else { org.collapsed.insert(g) } } label: {
                    Image(systemName: "chevron.down").rotationEffect(.degrees(org.collapsed.contains(g) ? -90 : 0))
                }.buttonStyle(.icon).foregroundColor(Theme.sub)
                    .tip(org.collapsed.contains(g) ? t("Expand group", "Mở nhóm") : t("Collapse group", "Thu gọn nhóm"), trailing: true)
            }.padding(.horizontal, 14).padding(.vertical, 12)
            if !org.collapsed.contains(g) {
                ForEach(ids, id: \.self) { i in OrgRow(org: org, i: i) }
            }
        }.background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
    }
}

struct OrgRow: View {
    @ObservedObject var org: OrgVM
    let i: Int
    var body: some View {
        if i < org.files.count {
            let f = org.files[i]
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    // A file that goes with another one follows that file's checkbox.
                    if f.pairOf != nil { CheckBox(state: f.include ? 2 : 0).opacity(0.4) }
                    else { Button { org.edit(f.id) { $0.include.toggle() } } label: { CheckBox(state: f.include ? 2 : 0) }.buttonStyle(.plain) }
                    FileThumb(url: f.url, side: 34 * uiScale)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.name).foregroundColor(Theme.text).font(.system(size: fs(14))).lineLimit(1).truncationMode(.middle)
                        HStack(spacing: 6) {
                            let rel = f.url.deletingLastPathComponent().path.replacingOccurrences(of: org.folder.path, with: "")
                            if !rel.isEmpty {
                                Image(systemName: "folder").font(.system(size: fs(10))).foregroundColor(Theme.sub)
                                Text(String(rel.dropFirst())).foregroundColor(Theme.sub).font(.system(size: fs(11))).lineLimit(1).truncationMode(.head)
                            }
                            if !f.why.isEmpty {
                                Text(f.why).foregroundColor(Theme.sub).font(.system(size: fs(11))).lineLimit(1)
                            } else {
                                Text(fmt(f.size)).foregroundColor(Theme.sub).font(.system(size: fs(11)))
                            }
                        }
                    }
                    Spacer(minLength: 8)
                    ForEach(f.tags, id: \.self) { tg in OrgTag(text: tg, on: f.tagOn.contains(tg)) {
                        org.edit(f.id, check: false) { if $0.tagOn.contains(tg) { $0.tagOn.remove(tg) } else { $0.tagOn.insert(tg) } }
                    } }
                    if f.pairOf == nil {
                        Menu {
                            ForEach(OrgGroup.allCases, id: \.self) { g in Button(g.label) { org.setGroup(f.id, g) } }
                        } label: { Image(systemName: "folder") }.menuStyle(.borderlessButton).fixedSize().padding(.horizontal, 5).padding(.vertical, 3).hoverTile().tip(t("Move to another group", "Chuyển sang nhóm khác"), trailing: true)
                    }
                    Button { org.editing = org.editing == f.id ? nil : f.id } label: {
                        Image(systemName: f.note.isEmpty ? "square.and.pencil" : "note.text").foregroundColor(f.note.isEmpty ? Theme.sub : Theme.accentSolid)
                    }.buttonStyle(.icon).tip(t("Add a note (kept in Tidymint only, not written into the file)", "Thêm ghi chú (chỉ lưu trong Tidymint, không ghi vào file)"), trailing: true)
                }
                if f.pairOf != nil, let n = f.newName {
                    // Its name comes from the file it goes with.
                    HStack(spacing: 8) {
                        Image(systemName: "link").font(.system(size: fs(12))).foregroundColor(Theme.sub)
                        Text(t("Rename to", "Đổi tên thành")).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                        Text(n).foregroundColor(Theme.text).font(.system(size: fs(12))).lineLimit(1).truncationMode(.middle)
                    }.padding(.leading, 76 * uiScale).opacity(f.renameOn ? 1 : 0.6)
                } else if f.newName != nil {
                    HStack(spacing: 8) {
                        Button { org.edit(f.id) { $0.renameOn.toggle() } } label: {
                            Image(systemName: f.renameOn ? "checkmark.square.fill" : "square").font(.system(size: fs(13)))
                                .foregroundStyle(f.renameOn ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.ink.opacity(0.5)))
                                .contentShape(Rectangle()).onHover { ($0 ? NSCursor.pointingHand : NSCursor.arrow).set() }
                        }.buttonStyle(.plain)
                        Text(t("Rename to", "Đổi tên thành")).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                        TextField("", text: Binding(get: { org.file(f.id)?.newName ?? "" }, set: { v in org.edit(f.id) { $0.newName = v; $0.renameOn = true; $0.nameEdited = true } }))
                            .textFieldStyle(.roundedBorder).font(.system(size: fs(12))).frame(maxWidth: 420)
                    }.padding(.leading, 76 * uiScale).opacity(f.renameOn ? 1 : 0.6)
                }
                if let w = f.warn, f.include {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: fs(11)))
                        Text(w).font(.system(size: fs(12))).lineLimit(2)
                    }.foregroundColor(Theme.warn).padding(.leading, 76 * uiScale)
                }
                if org.editing == f.id || !f.note.isEmpty {
                    TextField(t("Add a note for this file", "Thêm ghi chú cho file này"), text: Binding(get: { org.file(f.id)?.note ?? "" }, set: { v in org.edit(f.id, check: false) { $0.note = v } }))
                        .textFieldStyle(.roundedBorder).font(.system(size: fs(12))).padding(.leading, 76 * uiScale)
                }
            }.padding(.horizontal, 14).padding(.vertical, 8).opacity(f.include ? 1 : 0.55)
            .background(RoundedRectangle(cornerRadius: 8).stroke(Theme.accentSolid, lineWidth: org.focus == f.id ? 2 : 0))
            .id(f.id)
        }
    }
}

/// After Apply: each file that did not go exactly as planned, with the reason. Skipped files first.
struct OrgReport: View {
    let lines: [OrgNote]
    func icon(_ k: OrgNote.Kind) -> (String, Color) {
        switch k {
        case .skipped: return ("xmark.circle.fill", Theme.danger)
        case .kept: return ("exclamationmark.triangle.fill", Theme.warn)
        case .numbered: return ("number.circle.fill", Theme.sub)
        case .trashed: return ("trash.fill", Theme.sub)
        }
    }
    var body: some View {
        let order: [OrgNote.Kind] = [.skipped, .kept, .numbered, .trashed]
        let sorted = lines.sorted { order.firstIndex(of: $0.kind)! < order.firstIndex(of: $1.kind)! }
        VStack(alignment: .leading, spacing: 8) {
            Text(t("\(lines.count) files did not go exactly as planned", "\(lines.count) file không đúng như kế hoạch"))
                .font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
            let list = VStack(alignment: .leading, spacing: 8) {
                    ForEach(sorted) { l in
                        let ic = icon(l.kind)
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: ic.0).font(.system(size: fs(12))).foregroundColor(ic.1)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.name).font(.system(size: fs(13))).foregroundColor(Theme.text).lineLimit(1).truncationMode(.middle)
                                Text(l.detail).font(.system(size: fs(12))).foregroundColor(Theme.sub).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            // A short list sits at its own height; a long one scrolls inside a fixed box.
            if sorted.count <= 5 { list } else { ScrollView { list }.frame(height: 220) }
        }.padding(14).background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
    }
}

/// One line of a folder tree. state: 0 unchanged, 1 renamed or moved (after), 2 needs a look, 3 will leave this place (now).
struct OrgTreeRow: Identifiable {
    let id = UUID()
    let depth: Int; let name: String; let isDir: Bool
    var isNew = false; var existing = false; var count = 0
    var file: UUID? = nil; var state = 0; var pair: String? = nil

    final class Node { var dirs: [String: Node] = [:]; var files: [(String, OrgFile, Int)] = [] }
    static func build(_ items: [(path: [String], f: OrgFile, state: Int)], root: URL, markNew: Bool) -> [OrgTreeRow] {
        let top = Node()
        for it in items {
            var n = top
            for d in it.path.dropLast() { if n.dirs[d] == nil { n.dirs[d] = Node() }; n = n.dirs[d]! }
            n.files.append((it.path.last ?? it.f.name, it.f, it.state))
        }
        var out = [OrgTreeRow(depth: 0, name: root.lastPathComponent, isDir: true, count: items.count)]
        func walk(_ n: Node, _ depth: Int, _ at: URL) {
            for d in n.dirs.keys.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending }) {
                let u = d.hasPrefix("~/") ? URL(fileURLWithPath: NSHomeDirectory() + d.dropFirst()) : at.appendingPathComponent(d), k = n.dirs[d]!
                var r = OrgTreeRow(depth: depth, name: d, isDir: true, count: k.files.count)
                r.isNew = markNew && !FileManager.default.fileExists(atPath: u.path)
                r.existing = markNew && !r.isNew
                out.append(r)
                walk(k, depth + 1, u)
            }
            for (name, f, st) in n.files.sorted(by: { $0.0.localizedStandardCompare($1.0) == .orderedAscending }) {
                var r = OrgTreeRow(depth: depth, name: name, isDir: false, file: f.id, state: st)
                if f.pairOf != nil, let w = f.why.range(of: "(") { r.pair = String(f.why[w.lowerBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "()")) }
                out.append(r)
            }
        }
        walk(top, 1, root)
        return out
    }
}

/// Plan as two trees side by side: where the files are now, and where they will be after Apply.
/// Green: renamed or moved. Yellow: needs a look. Folders that will be created carry a NEW badge.
/// Clicking a file opens the list at that file.
struct OrgTreeView: View {
    @ObservedObject var org: OrgVM
    var body: some View {
        let tr = org.trees()
        HStack(alignment: .top, spacing: 12) {
            column(t("Now", "Bây giờ"), tr.now, after: false)
            column(t("After Apply", "Sau khi áp dụng"), tr.after, after: true)
        }.padding(.horizontal, 24).padding(.bottom, 12)
    }
    func column(_ title: String, _ rows: [OrgTreeRow], after: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.system(size: fs(11), weight: .semibold)).tracking(1).foregroundColor(Theme.sub)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { r in line(r, after: after) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
    }
    @ViewBuilder func line(_ r: OrgTreeRow, after: Bool) -> some View {
        let color: Color = r.isDir ? Theme.text : (r.state == 1 ? Theme.green : (r.state == 2 ? Theme.warn : (r.state == 3 ? Theme.sub : Theme.text)))
        HStack(spacing: 6) {
            if r.isDir {
                Image(systemName: r.depth == 0 ? "folder.fill" : "folder").font(.system(size: fs(13))).foregroundColor(Theme.accentSolid)
                Text(r.name).font(.system(size: fs(14), weight: .semibold)).foregroundColor(Theme.text).lineLimit(1)
                if r.isNew {
                    Text(t("NEW", "MỚI")).font(.system(size: fs(10), weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 1).background(Capsule().fill(Theme.accentSolid))
                }
                if r.depth > 0 {
                    Text((r.existing ? t("already there · ", "đã có · ") : "") + t("\(r.count) files", "\(r.count) file")).font(.system(size: fs(11))).foregroundColor(Theme.sub)
                }
            } else {
                if r.state == 2 { Image(systemName: "exclamationmark.triangle.fill").font(.system(size: fs(11))).foregroundColor(Theme.warn) }
                Text(r.name).font(.system(size: fs(14))).foregroundColor(color).lineLimit(1).truncationMode(.middle)
                if after, let p = r.pair {
                    Image(systemName: "link").font(.system(size: fs(10))).foregroundColor(Theme.sub)
                    Text(p).font(.system(size: fs(11))).foregroundColor(Theme.sub).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(r.depth) * 20 * uiScale).padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { if let id = r.file { org.reveal(id) } }
        .tip(r.file != nil ? t("Show this file in the list", "Xem file này trong danh sách") : "")
    }
}

/// Above the list: show everything, only renames, or only files to check (like f2's status column).
struct OrgShowBar: View {
    @ObservedObject var org: OrgVM
    var body: some View {
        let inc = org.files.filter(\.include)
        HStack {
            Picker("", selection: $org.show) {
                Text(t("All (\(org.files.count))", "Tất cả (\(org.files.count))")).tag(OrgVM.Show.all)
                Text(t("Renamed (\(org.renameCount))", "Sẽ đổi tên (\(org.renameCount))")).tag(OrgVM.Show.rename)
                Text(t("To check (\(inc.filter { $0.warn != nil }.count))", "Cần xem (\(inc.filter { $0.warn != nil }.count))")).tag(OrgVM.Show.check)
            }.pickerStyle(.segmented).labelsHidden().fixedSize()
            Spacer()
            // Named by what each side is for: the list is where files are changed, the tree only shows the result.
            PillSwitch(options: [(false, t("Edit", "Chỉnh sửa"), t("Rename, tag and regroup each file", "Đổi tên, tag, nhóm cho từng file"), "square.and.pencil"),
                                 (true, t("Preview", "Xem trước"), t("See the folders before and after Apply", "Xem thư mục trước và sau khi áp dụng"), "eye")],
                       value: $org.treeView)
        }
    }
}

struct OrgTag: View {
    let text: String; let on: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: on ? "tag.fill" : "tag").font(.system(size: fs(9)))
                Text(text).font(.system(size: fs(11), weight: .medium))
            }
            .foregroundColor(on ? Theme.text : Theme.sub)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(on ? Theme.accentSolid.opacity(0.25) : Color.clear))
            .overlay(Capsule().stroke(on ? Theme.accentSolid.opacity(0.6) : Theme.ink.opacity(0.25), lineWidth: 1))
        }.buttonStyle(.plain).tip(on ? t("Click to drop this tag", "Bấm để bỏ tag này") : t("Click to keep this tag", "Bấm để giữ tag này"), trailing: true)
    }
}

extension Demo {
    static func organize(_ o: OrgVM) {
        func f(_ n: String, _ g: OrgGroup, _ mb: Double, _ tags: [String] = [], why: String = "", new: String? = nil, note: String = "", days: Double = 3) -> OrgFile {
            var x = OrgFile(url: u("Downloads/" + n), size: Int64(mb * 1_000_000), date: Date().addingTimeInterval(-days * 86400), group: g, why: why, tags: tags, tagOn: Set(tags), newName: new, renameOn: new != nil, desc: new.map { ($0 as NSString).deletingPathExtension.components(separatedBy: " ").dropFirst().joined(separator: " ") }, needsName: new != nil, note: note)
            x.include = true; return x
        }
        o.folder = u("Downloads")
        o.files = [
            f("Screenshot 2026-10-21 at 09.14.22.png", .screens, 1.2, [t("Has text", "Có chữ")], why: t("Name says it is a screen capture", "Tên file cho thấy là ảnh chụp màn hình"), new: "2026-10-21 " + t("Screenshot", "Ảnh màn hình") + ".png"),
            f("Screenshot 2026-10-25 at 18.02.10.png", .screens, 0.9, [], why: t("Name says it is a screen capture", "Tên file cho thấy là ảnh chụp màn hình"), new: "2026-10-25 " + t("Screenshot", "Ảnh màn hình") + ".png"),
            f("IMG_4821.HEIC", .receipts, 2.4, [t("Document", "Giấy tờ"), t("Has text", "Có chữ")], why: t("Text in the file looks like a receipt or invoice", "Chữ trong file giống hoá đơn, biên lai"), new: "2026-10-19 " + t("Receipt", "Hoá đơn") + ".HEIC", note: t("Office chair, keep for warranty", "Ghế văn phòng, giữ để bảo hành")),
            f("invoice_88213.pdf", .receipts, 0.2, [], why: t("Text in the file looks like a receipt or invoice", "Chữ trong file giống hoá đơn, biên lai")),
            f("IMG_4790.JPG", .images, 3.1, [t("Food", "Đồ ăn"), t("Drink", "Đồ uống")], new: "2026-10-12 " + t("Food", "Đồ ăn") + ".JPG"),
            f("IMG_4802.JPG", .images, 2.8, [t("Beach", "Biển"), t("Sky", "Bầu trời")], new: "2026-10-14 " + t("Beach", "Biển") + ".JPG"),
            f("PXL_20261002_0815.jpg", .images, 3.6, [t("Dog", "Chó")], new: "2026-10-02 " + t("Dog", "Chó") + ".jpg"),
            f("hero-banner-v3.png", .images, 4.2, [t("Illustrations", "Minh hoạ")]),
            f("interview-raw.mp4", .video, 410, []),
            f("Bao-cao-Q3.docx", .docs, 0.4, []),
            f("ngan-sach-2026.xlsx", .sheets, 0.1, []),
            f("Tidymint.zip", .archives, 3.5, []),
            f("ubuntu-24.04-desktop-arm64.iso", .installers, 3200, []),
        ]
        o.phase = .review
    }
}

/// Naming rule bar above the plan: preset menu, example, edit button, "keep all old names".
struct OrgNameBar: View {
    @ObservedObject var org: OrgVM
    var body: some View {
        let named = org.files.indices.filter { org.files[$0].newName != nil }
        HStack(spacing: 10) {
            Image(systemName: "character.cursor.ibeam").foregroundColor(Theme.accentSolid).font(.system(size: fs(14)))
            Text(t("Names:", "Đặt tên:")).foregroundColor(Theme.sub).font(.system(size: fs(12)))
            Menu {
                ForEach(NamePreset.allCases, id: \.self) { p in Button(p.label) { org.preset = p } }
            } label: { Text(org.preset.label).font(.system(size: fs(12), weight: .semibold)) }.menuStyle(.borderlessButton).fixedSize()
                .padding(.horizontal, 6).padding(.vertical, 3).hoverTile().tip(t("Pick a ready-made naming style", "Chọn kiểu đặt tên có sẵn"))
            // The whole pill takes the click (a bare icon only reacts on its thin strokes), and a click always opens the editor.
            Button { org.showRule = true } label: {
                Label(t("Customize", "Tuỳ chỉnh"), systemImage: "slider.horizontal.3").font(.system(size: fs(12)))
            }.buttonStyle(.icon).foregroundColor(Theme.text)
                .tip(t("Edit the rule", "Sửa quy tắc"))
                .popover(isPresented: $org.showRule, arrowEdge: .bottom) { OrgRuleEditor(org: org).frame(width: 380).padding(16) }
            Text(t("e.g. ", "ví dụ: ") + org.example).foregroundColor(Theme.sub).font(.system(size: fs(12))).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 8)
            if org.warnCount > 0 {
                Button { org.show = .check } label: {
                    Label(t("\(org.warnCount) to check", "\(org.warnCount) file cần xem"), systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.warn).font(.system(size: fs(12), weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 3).hoverTile()
                }.buttonStyle(.plain)
                    .tip(t("Show only these files", "Chỉ hiện các file này"))
            }
            if org.renameCount == 0 && !org.renameAll && named.isEmpty && !org.files.isEmpty {
                // Say why nothing is renamed: every name is already readable, so the rule leaves them alone.
                Text(t("Names already clear, kept", "Tên đã rõ ràng, giữ nguyên")).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                    .tip(t("Only names that say nothing (IMG_, Screenshot, scan, random strings) are renamed by default.",
                            "Mặc định chỉ đổi tên file có tên vô nghĩa (IMG_, Screenshot, scan, chuỗi ngẫu nhiên)."))
                TextLink(t("Rename these too", "Đổi cả các file này"), size: fs(12)) { org.renameAll = true }
            } else {
                Text(t("\(org.renameCount) to rename", "\(org.renameCount) file sẽ đổi tên")).foregroundColor(Theme.text).font(.system(size: fs(12), weight: .semibold))
            }
            if !named.isEmpty {
                let allOn = named.allSatisfy { org.files[$0].renameOn }
                TextLink(allOn ? t("Keep all old names", "Giữ tên cũ tất cả") : t("Rename all", "Đổi tên tất cả"), size: fs(12)) {
                    for i in named where i < org.files.count { org.files[i].renameOn = !allOn }
                    org.validate()
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8).background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
    }
}

/// Custom rule editor: the parts in use (drag to reorder, or use the arrows), parts to add (including your own text),
/// separator and web-safe switches. Any change switches the preset to Custom and is remembered.
struct OrgRuleEditor: View {
    @ObservedObject var org: OrgVM
    func set(_ change: (inout NameRule) -> Void) { var r = org.rule; change(&r); org.custom = r; if org.preset != .custom { org.preset = .custom } }
    func move(_ i: Int, _ d: Int) { set { r in let j = i + d; guard r.parts.indices.contains(i), r.parts.indices.contains(j) else { return }; r.parts.swapAt(i, j) } }
    var body: some View {
        let r = org.rule
        VStack(alignment: .leading, spacing: 10) {
            Text(t("Naming rule", "Quy tắc đặt tên")).font(.system(size: fs(14), weight: .semibold))
            Text(t("Drag the parts to reorder them, or use the arrows.", "Kéo thả để đổi thứ tự các phần, hoặc bấm mũi tên.")).font(.system(size: fs(11))).foregroundColor(.secondary)
            List {
                ForEach(r.parts) { p in
                    let i = r.parts.firstIndex(of: p) ?? 0
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal").foregroundColor(.secondary).tip(t("Drag to reorder", "Kéo để đổi chỗ"))
                        if p.kind == .text {
                            TextField(t("Your text, e.g. ACME", "Chữ tự gõ, ví dụ ACME"), text: Binding(
                                get: { org.rule.parts.first { $0.id == p.id }?.text ?? "" },
                                set: { v in set { r in if let k = r.parts.firstIndex(where: { $0.id == p.id }) { r.parts[k].text = v } } }))
                                .textFieldStyle(.roundedBorder).font(.system(size: fs(12)))
                        } else {
                            Text(p.kind.label).font(.system(size: fs(12)))
                            Spacer()
                        }
                        Button { move(i, -1) } label: { Image(systemName: "chevron.up") }.buttonStyle(.icon).disabled(i == 0)
                        Button { move(i, 1) } label: { Image(systemName: "chevron.down") }.buttonStyle(.icon).disabled(i == r.parts.count - 1)
                        Button { set { r in r.parts.removeAll { $0.id == p.id } } } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
                            .buttonStyle(.icon).tip(t("Remove", "Bỏ phần này"))
                    }.padding(.vertical, 2)
                }
                .onMove { from, to in set { r in r.parts.move(fromOffsets: from, toOffset: to) } }
            }
            .frame(height: CGFloat(max(r.parts.count, 1)) * 34 + 12)
            Text(t("Add a part", "Thêm phần")).font(.system(size: fs(11))).foregroundColor(.secondary)
            let unused = NameToken.allCases.filter { k in k != .text && !r.parts.contains { $0.kind == k } }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(unused + [.text], id: \.self) { k in
                    Button { set { r in r.parts.append(NamePart(kind: k)) } } label: {
                        Label(k.label, systemImage: k == .text ? "character.cursor.ibeam" : "plus").font(.system(size: fs(11)))
                            .padding(.horizontal, 8).padding(.vertical, 4).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Capsule().stroke(Color.secondary.opacity(0.4))).hoverTile()
                    }.buttonStyle(.plain)
                }
            }
            Divider()
            HStack {
                Text(t("Separator", "Dấu nối")).font(.system(size: fs(12)))
                Picker("", selection: Binding(get: { org.rule.sep }, set: { v in set { $0.sep = v } })) {
                    Text(t("Space", "Khoảng trắng")).tag(" "); Text("_").tag("_"); Text("-").tag("-")
                }.pickerStyle(.segmented).frame(width: 200)
            }
            Toggle(t("Remove Vietnamese accents", "Bỏ dấu tiếng Việt"), isOn: Binding(get: { org.rule.noAccents }, set: { v in set { $0.noAccents = v } })).font(.system(size: fs(12)))
            Toggle(t("Lower case", "Viết thường"), isOn: Binding(get: { org.rule.lower }, set: { v in set { $0.lower = v } })).font(.system(size: fs(12)))
            Toggle(t("Also rename files that already have a clear name", "Đổi cả file đã có tên rõ ràng"), isOn: $org.renameAll).font(.system(size: fs(12)))
            Divider()
            Text(t("Example", "Ví dụ")).font(.system(size: fs(11))).foregroundColor(.secondary)
            Text(org.example).font(.system(size: fs(13), weight: .medium)).textSelection(.enabled)
            Text(t("Extensions are always lower case (.JPG becomes .jpg). Nothing is overwritten: a clash gets \" 2\". Dates come from the camera when the photo or video has one. A Live Photo, RAW + JPG or a video and its subtitles keep the same name.",
                   "Đuôi file luôn viết thường (.JPG thành .jpg). Không ghi đè: trùng tên thì thêm \" 2\". Ngày lấy theo ngày chụp nếu ảnh hoặc video có ghi. Live Photo, RAW + JPG, video và phụ đề luôn giữ chung một tên."))
                .font(.system(size: fs(11))).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            // Say plainly what the rule will do to this list, and why nothing changes when every name is already clear.
            if org.renameCount == 0 && !org.renameAll {
                Text(t("All \(org.files.count) files already have clear names, so they keep them. Turn on \"Also rename files that already have a clear name\" to apply the rule to them.",
                       "Cả \(org.files.count) file đã có tên rõ ràng nên được giữ nguyên. Bật \"Đổi cả file đã có tên rõ ràng\" để áp quy tắc cho chúng."))
                    .font(.system(size: fs(12))).foregroundColor(Theme.warn).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Text(t("\(org.renameCount) files will be renamed when you click Apply.", "\(org.renameCount) file sẽ được đổi tên khi bấm Áp dụng."))
                    .font(.system(size: fs(12), weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                Spacer()
                PrimaryButton(title: t("Use this rule", "Dùng quy tắc này"), action: { org.recomputeNames(); org.showRule = false })
            }
        }
    }
}

/// A settings-style row: title and explanation on the left, the switch pinned to the right edge,
/// so every switch lines up with the others and with the button in the folder card above.
/// Keep Downloads tidy batches from the last 7 days, each with its own Undo.
struct OrgHistory: View {
    @ObservedObject var org: OrgVM
    var body: some View {
        let _ = org.historyTick
        let h = OrgVM.history()
        if !h.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                TextLink(org.historyOpen ? t("Hide automatic batches", "Ẩn các đợt tự xếp") : t("Automatic batches, last 7 days (\(h.count))", "Các đợt tự xếp 7 ngày qua (\(h.count))"), size: fs(12)) {
                    org.historyOpen.toggle()
                }
                if org.historyOpen {
                    let df: DateFormatter = { let f = DateFormatter(); f.dateFormat = "dd/MM HH:mm"; return f }()
                    ForEach(h.prefix(30), id: \.date) { b in
                        let kept = b.moves.filter { $0.trashed != true }
                        let dirs = Array(Set(kept.map { URL(fileURLWithPath: $0.to).deletingLastPathComponent().lastPathComponent })).sorted()
                        HStack(spacing: 8) {
                            Text(df.string(from: b.date)).foregroundColor(Theme.sub).monospacedDigit()
                            Text(t("\(kept.count) files", "\(kept.count) file") + (dirs.isEmpty ? "" : " · " + dirs.joined(separator: ", ")))
                                .foregroundColor(Theme.text).lineLimit(1).truncationMode(.tail)
                            Spacer(minLength: 8)
                            TextLink(t("Undo", "Hoàn tác"), size: fs(12)) { if let id = b.id { org.undoBatch(id) } }
                        }.font(.system(size: fs(12)))
                    }
                }
            }.padding(.horizontal, 14).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Two-option switch made of buttons, so each option has its own tooltip and hover tile (a segmented picker has neither).
struct PillSwitch: View {
    let options: [(Bool, String, String, String?)]   // value, label, tooltip, SF symbol
    @Binding var value: Bool
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { v, label, tip, icon in
                Button { value = v } label: {
                    HStack(spacing: 5) {
                        if let icon { Image(systemName: icon) }
                        Text(label)
                    }.font(.system(size: fs(12), weight: .medium)).foregroundColor(value == v ? .white : Theme.sub)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(value == v ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.clear)))
                        .hoverTile(value != v)
                }.buttonStyle(.plain).tip(tip)
            }
        }.padding(3).background(Capsule().fill(Theme.card))
    }
}

struct OrgSwitchRow: View {
    let title: String; let sub: String
    @Binding var on: Bool
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundColor(Theme.text).font(.system(size: fs(14), weight: .medium))
                Text(sub).foregroundColor(Theme.sub).font(.system(size: fs(12))).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: $on).labelsHidden().toggleStyle(.switch).tint(Theme.accentSolid)
        }.padding(.horizontal, 14).padding(.vertical, 8)
    }
}

/// Free space per day: a line with a soft fill, a green dot on days with a cleanup, 7/30/90-day ranges, hover for the day's numbers.
struct FreeSpaceChart: View {
    @ObservedObject var vm: VM
    let log: [LogEntry]
    @StateObject private var pick = RangePick()
    var body: some View {
        let data = DiskHistory.series(days: pick.days, log: log)
        let dm: DateFormatter = { let f = DateFormatter(); f.dateFormat = "dd/MM"; return f }()
        let top = max(vm.totalGB, (data.map(\.free).max() ?? 1) * 1.1)
        let sel = pick.sel.flatMap { s in data.min { abs($0.date.timeIntervalSince(s)) < abs($1.date.timeIntervalSince(s)) } }
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t("Free space per day (GB)", "Dung lượng trống mỗi ngày (GB)")).font(.system(size: fs(12), weight: .semibold)).foregroundColor(Theme.sub)
                Spacer()
                if let d = sel {
                    Text(dm.string(from: d.date) + ": " + t("free ", "trống ") + String(format: "%.0f GB", d.free)
                         + (d.freed > 0 ? t(", cleaned ", ", đã dọn ") + fmt(d.freed) : ""))
                        .font(.system(size: fs(11), weight: .semibold)).foregroundColor(Theme.text)
                }
                Picker("", selection: $pick.days) {
                    Text(t("7 days", "7 ngày")).tag(7); Text(t("30 days", "30 ngày")).tag(30); Text(t("90 days", "90 ngày")).tag(90)
                }.pickerStyle(.segmented).frame(width: 220)
            }
            if data.count < 2 {
                Text(t("Not enough days yet. Tidymint notes the free space once a day while it is open.",
                       "Chưa đủ số ngày. Tidymint ghi dung lượng trống mỗi ngày một lần khi app đang mở."))
                    .font(.system(size: fs(12))).foregroundColor(Theme.sub).frame(height: 140)
            } else {
                Chart {
                    ForEach(data) { d in
                        AreaMark(x: .value("Day", d.date, unit: .day), y: .value("GB", d.free))
                            .foregroundStyle(LinearGradient(colors: [Theme.accentSolid.opacity(0.35), Theme.accentSolid.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Day", d.date, unit: .day), y: .value("GB", d.free))
                            .foregroundStyle(Theme.accentSolid).lineStyle(StrokeStyle(lineWidth: 2))
                        if d.freed > 0 {
                            PointMark(x: .value("Day", d.date, unit: .day), y: .value("GB", d.free)).foregroundStyle(Theme.green).symbolSize(40)
                        }
                    }
                    if let d = sel {
                        RuleMark(x: .value("Day", d.date, unit: .day)).foregroundStyle(Theme.ink.opacity(0.3))
                    }
                }
                .chartYScale(domain: 0...top)
                // The axis always spans the whole range, so the line sits on the right dates even when early days are missing.
                .chartXScale(domain: (Calendar.current.date(byAdding: .day, value: -(pick.days - 1), to: Calendar.current.startOfDay(for: Date())) ?? Date())...Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: pick.days <= 7 ? 1 : (pick.days <= 30 ? 7 : 14))) { v in
                        AxisGridLine().foregroundStyle(Theme.ink.opacity(0.08))
                        AxisValueLabel { if let d = v.as(Date.self) { Text(dm.string(from: d)).font(.system(size: fs(10))).foregroundColor(Theme.sub) } }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { v in
                        AxisGridLine().foregroundStyle(Theme.ink.opacity(0.08))
                        AxisValueLabel { if let g = v.as(Double.self) { Text(String(format: "%.0f", g)).font(.system(size: fs(10))).foregroundColor(Theme.sub) } }
                    }
                }
                .chartXSelection(value: $pick.sel)
                .frame(height: 150)
            }
        }.padding(14).background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
    }
}
