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
    /// Dark core of the Scan button: the brand "tile" green on dark themes, a soft white on light ones.
    static var tile: Color { p.light ? Color(hex: 0xf3faf6) : Color(hex: 0x0d2b24) }
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
/// "Last opened Oct 29, 2026" / "Mở lần cuối 29/10/2026": the date column of file rows (fixed width, so kept short).
// Formatters are costly to create and rows redraw often: one per format and language, made once.
private let viDayFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"; return f }()
private let shortFmts: [String: DateFormatter] = Dictionary(uniqueKeysWithValues: ["vi", "en"].map { l in
    let f = DateFormatter(); f.locale = Locale(identifier: l == "vi" ? "vi_VN" : "en_US"); f.dateStyle = .medium; f.timeStyle = .none; return (l, f)
})
func openedLabel(_ d: Date) -> String {
    if appLang == "vi" { return "Mở lần cuối " + viDayFmt.string(from: d) }
    return "Last opened " + shortDate(d)
}
func shortDate(_ d: Date) -> String { (shortFmts[appLang == "vi" ? "vi" : "en"] ?? shortFmts["en"]!).string(from: d) }

/// Replacement for @State.
final class Flag: ObservableObject { @Published var v = false }
/// Which Settings groups are unfolded (a class, not @State: see the note at the top of the file).
final class OpenGroups: ObservableObject { @Published var ids: Set<String> = []; static let shared = OpenGroups() }

/// Tooltip drawn by the app itself. macOS help tags often never appear on SwiftUI views that also track the mouse
/// (hover tiles, cursors), so every tooltip in Tidymint uses this: a small bubble near the pointer after half a second.
/// The bubble lives in its own borderless panel above the window, so it is never clipped by the window edge,
/// a scroll view or a neighbouring control, and it is kept inside the visible screen.
final class TipPanel {
    static let shared = TipPanel()
    private var panel: NSPanel?
    private var owner: ObjectIdentifier?
    private var monitor: Any?
    private let maxW: CGFloat = 280
    private var lastShown = Date.distantPast
    /// True while a bubble is up or was up a moment ago: moving to the next control then shows its tip at once,
    /// instead of waiting the half second again.
    var warm: Bool { panel?.isVisible == true || Date().timeIntervalSince(lastShown) < 0.35 }
    var delay: Double { warm ? 0 : 0.5 }

    /// `below`: a screen rect to hang the bubble under (left-aligned to it) instead of following the pointer.
    func show(_ text: String, owner o: ObjectIdentifier, below: NSRect? = nil) {
        guard !text.isEmpty else { return }
        let font = NSFont.systemFont(ofSize: fs(11))
        let line = (text as NSString).size(withAttributes: [.font: font]).width
        let w = min(ceil(line) + 2, maxW)
        let host = NSHostingView(rootView: TipBubble(text: text, width: w))
        let size = host.fittingSize
        let p = panel ?? make()
        p.contentView = host
        let mouse = NSEvent.mouseLocation
        var origin = below.map { NSPoint(x: $0.minX - 8, y: $0.minY - size.height + 4) } ?? NSPoint(x: mouse.x - 14, y: mouse.y - size.height - 14)
        if let scr = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main {
            let vf = scr.visibleFrame
            origin.x = min(max(origin.x, vf.minX + 4), vf.maxX - size.width - 4)
            if origin.y < vf.minY + 4 { origin.y = mouse.y + 18 }
        }
        p.setFrame(NSRect(origin: origin, size: size), display: true)
        p.orderFrontRegardless()
        owner = o
    }
    /// `cold`: a click, scroll or key press closed it, so the next tip waits again.
    func hide(owner o: ObjectIdentifier? = nil, cold: Bool = false) {
        if let o, o != owner { return }
        lastShown = cold ? .distantPast : (panel?.isVisible == true ? Date() : lastShown)
        panel?.orderOut(nil); owner = nil
    }
    private func make() -> NSPanel {
        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = false
        p.level = .popUpMenu; p.ignoresMouseEvents = true; p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel = p
        // Like system tooltips: any click, scroll or key press dismisses the bubble.
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .scrollWheel, .keyDown]) { [weak self] e in
            self?.hide(cold: true); return e
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.hide() }
        return p
    }
}
struct TipBubble: View {
    let text: String; let width: CGFloat
    var body: some View {
        Text(text).font(.system(size: fs(11))).foregroundColor(Color(nsColor: .labelColor))
            .multilineTextAlignment(.leading).frame(width: width, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .windowBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
            .padding(8)   // room for the shadow inside the panel
    }
}
final class TipState: ObservableObject {
    private var item: DispatchWorkItem?
    var text = ""
    func hover(_ inside: Bool) {
        item?.cancel(); item = nil
        let me = ObjectIdentifier(self)
        guard inside, !text.isEmpty else { TipPanel.shared.hide(owner: me); return }
        let i = DispatchWorkItem { [weak self] in
            guard let self else { return }
            TipPanel.shared.show(self.text, owner: ObjectIdentifier(self))
        }
        item = i; DispatchQueue.main.asyncAfter(deadline: .now() + TipPanel.shared.delay, execute: i)
    }
}
struct Tip: ViewModifier {
    let text: String
    var trailing = false   // kept for call sites; the floating bubble places itself inside the screen
    @StateObject private var st = TipState()
    func body(content: Content) -> some View {
        content
            .onHover { inside in st.text = text; st.hover(inside) }
            .onDisappear { st.hover(false) }
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
