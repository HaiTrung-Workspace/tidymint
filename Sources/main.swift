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
func openedLabel(_ d: Date) -> String {
    if appLang == "vi" { let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"; return "Mở lần cuối " + f.string(from: d) }
    return "Last opened " + shortDate(d)
}
func shortDate(_ d: Date) -> String {
    let f = DateFormatter(); f.locale = Locale(identifier: appLang == "vi" ? "vi_VN" : "en_US"); f.dateStyle = .medium; f.timeStyle = .none
    return f.string(from: d)
}

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

    func show(_ text: String, owner o: ObjectIdentifier) {
        guard !text.isEmpty else { return }
        let font = NSFont.systemFont(ofSize: fs(11))
        let line = (text as NSString).size(withAttributes: [.font: font]).width
        let w = min(ceil(line) + 2, maxW)
        let host = NSHostingView(rootView: TipBubble(text: text, width: w))
        let size = host.fittingSize
        let p = panel ?? make()
        p.contentView = host
        let mouse = NSEvent.mouseLocation
        var origin = NSPoint(x: mouse.x - 14, y: mouse.y - size.height - 14)
        if let scr = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main {
            let vf = scr.visibleFrame
            origin.x = min(max(origin.x, vf.minX + 4), vf.maxX - size.width - 4)
            if origin.y < vf.minY + 4 { origin.y = mouse.y + 18 }
        }
        p.setFrame(NSRect(origin: origin, size: size), display: true)
        p.orderFrontRegardless()
        owner = o
    }
    func hide(owner o: ObjectIdentifier? = nil) {
        if let o, o != owner { return }
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
            self?.hide(); return e
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
        item = i; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: i)
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

// MARK: - Ignore list

/// User settings stored in UserDefaults.
enum Prefs {
    /// Folders where the user keeps projects (code, AI workspaces). Used to look for drafts,
    /// to never pre-select duplicates inside them, and to check links before deleting.
    /// Extra path keywords that must never be touched (e.g. a browser-profile folder name).
    static var protectedKeywords: [String] { UserDefaults.standard.stringArray(forKey: "protectedKeywords") ?? [] }
    private static var projectCache: [String]? = nil
    private static let projectLock = NSLock()
    static var projectFolders: [String] {
        get { projectLock.lock(); defer { projectLock.unlock() }
              if let c = projectCache { return c }
              let v = UserDefaults.standard.stringArray(forKey: "projectFolders") ?? []; projectCache = v; return v }
        set { projectLock.lock(); projectCache = newValue; projectLock.unlock(); UserDefaults.standard.set(newValue, forKey: "projectFolders") }
    }
    static func inProject(_ p: String) -> Bool { let q = canonical(p); return projectFolders.contains { q == $0 || q.hasPrefix($0 + "/") } }
    /// Drive name as it was when a path on it was saved (project folder, extra folder, ignore list), by volume UUID.
    /// A renamed drive ("SSD" became "SSD 1") then still matches those saved paths.
    private static var volCache: [String: String]? = nil
    static var volumeNames: [String: String] {
        get { projectLock.lock(); defer { projectLock.unlock() }
              if let c = volCache { return c }
              let v = UserDefaults.standard.dictionary(forKey: "volumeNames") as? [String: String] ?? [:]; volCache = v; return v }
        set { projectLock.lock(); volCache = newValue; projectLock.unlock(); UserDefaults.standard.set(newValue, forKey: "volumeNames") }
    }
    static func rememberVolume(of path: String) {
        guard onOtherDrive(path), let root = volumeRoot(path),
              let id = (try? URL(fileURLWithPath: root).resourceValues(forKeys: [.volumeUUIDStringKey]))?.volumeUUIDString else { return }
        if volumeNames[id] == nil { volumeNames[id] = root }
    }
    static func volumeRoot(_ p: String) -> String? {
        let parts = p.split(separator: "/", omittingEmptySubsequences: true)
        return parts.count >= 2 && parts[0] == "Volumes" ? "/" + parts.prefix(2).joined(separator: "/") : nil
    }
    /// The path with the drive name it was saved under (see volumeNames); unchanged for anything else.
    static func canonical(_ p: String) -> String {
        guard let root = volumeRoot(p) else { return p }
        driveLock.lock(); let known = uuidCache[root]; driveLock.unlock()
        let id: String?
        if let known { id = known }
        else {
            id = (try? URL(fileURLWithPath: root).resourceValues(forKeys: [.volumeUUIDStringKey]))?.volumeUUIDString
            if let id { driveLock.lock(); uuidCache[root] = id; driveLock.unlock() }
        }
        guard let id, let saved = volumeNames[id], saved != root else { return p }
        return saved + p.dropFirst(root.count)
    }
    private static var uuidCache: [String: String] = [:]
    /// Extra places scanned by Duplicates and Large & Old Files: external drives, or folders in the home folder
    /// outside the usual six (Documents, Downloads...). Added by the user in Settings. Several drives are fine.
    static var extraFolders: [String] {
        get { UserDefaults.standard.stringArray(forKey: "extraScanFolders") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "extraScanFolders") }
    }
    /// Volume UUID of each extra folder on an external drive, so the folder is found again when the drive comes back
    /// under another name ("SSD 1" when two drives share a name, or after a rename).
    static var extraVolumeIDs: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: "extraScanVolumeIDs") as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "extraScanVolumeIDs") }
    }
    /// Where an extra folder is right now, or nil when its drive is not plugged in.
    static func resolveExtra(_ path: String) -> String? {
        let fm = FileManager.default
        guard onOtherDrive(path) else { return fm.fileExists(atPath: path) ? path : nil }
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)   // ["Volumes", name, rest...]
        guard parts.count >= 2 else { return nil }
        let root = "/" + parts.prefix(2).joined(separator: "/")
        let rest = parts.dropFirst(2).joined(separator: "/")
        let want = extraVolumeIDs[path]
        func uuid(_ u: URL) -> String? { (try? u.resourceValues(forKeys: [.volumeUUIDStringKey]))?.volumeUUIDString }
        if fm.fileExists(atPath: path) {
            // Same name, but a different drive is mounted there: not our folder.
            if let w = want, let now = uuid(URL(fileURLWithPath: root)), now != w { return nil }
            return path
        }
        guard let w = want else { return nil }
        let vols = fm.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeUUIDStringKey], options: [.skipHiddenVolumes]) ?? []
        guard let v = vols.first(where: { uuid($0) == w }) else { return nil }
        let p = rest.isEmpty ? v.path : v.appendingPathComponent(rest).path
        return fm.fileExists(atPath: p) ? p : nil
    }
    /// Extra folders present right now: a drive that is not plugged in is skipped, not reported as an error.
    static var extraRoots: [URL] { extraFolders.compactMap(resolveExtra).map { URL(fileURLWithPath: $0) } }
    enum ExtraCheck { case ok, outside, network, readOnly, timeMachine }
    /// Allowed: a folder on another local, writable drive (/Volumes/<name>), or a folder inside the home folder that is not Library.
    /// The startup disk seen through /Volumes resolves to "/" and is refused. Network drives are refused: macOS has no Trash
    /// there, so a "move to Trash" would fail. Time Machine backups are refused: macOS manages them.
    static func extraCheck(_ u: URL) -> ExtraCheck {
        let real = u.resolvingSymlinksInPath().path
        let home = FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().path
        if real.hasPrefix("/Volumes/") {
            let v = try? u.resourceValues(forKeys: [.volumeIsLocalKey, .volumeIsReadOnlyKey, .volumeURLKey])
            if v?.volumeIsLocal == false { return .network }
            if v?.volumeIsReadOnly == true { return .readOnly }
            let rootKids = (try? FileManager.default.contentsOfDirectory(atPath: v?.volume?.path ?? real)) ?? []
            // HFS+ backups keep Backups.backupdb; APFS backups are folders named like 2026-11-04-101500.backup.
            if rootKids.contains(where: { $0 == "Backups.backupdb" || $0.range(of: #"^\d{4}-\d{2}-\d{2}-\d{6}\.(backup|previous|inprogress|interrupted)$"#, options: .regularExpression) != nil }) { return .timeMachine }
            return .ok
        }
        guard real.hasPrefix(home + "/") else { return .outside }
        return (real == home + "/Library" || real.hasPrefix(home + "/Library/")) ? .outside : .ok
    }
    /// True when the path is on a drive other than the startup disk.
    /// A second volume on the internal disk is not "another drive": the space stays on the same SSD.
    /// Cached per volume, called from scans on background threads.
    static func onOtherDrive(_ p: String) -> Bool {
        guard p.hasPrefix("/Volumes/") else { return false }
        let parts = p.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return false }
        let root = "/" + parts.prefix(2).joined(separator: "/")
        driveLock.lock(); defer { driveLock.unlock() }
        if let v = driveCache[root] { return v }
        guard let r = try? URL(fileURLWithPath: root).resourceValues(forKeys: [.volumeIsEjectableKey, .volumeIsRemovableKey, .volumeIsInternalKey]) else {
            return true   // not mounted right now: nothing to cache, and a /Volumes path that is not there is not the startup disk
        }
        let other = r.volumeIsEjectable == true || r.volumeIsRemovable == true || r.volumeIsInternal == false
        driveCache[root] = other
        return other
    }
    private static var driveCache: [String: Bool] = [:]
    static let driveLock = NSLock()
    /// Which copy to keep when the same file is on the Mac and on an external drive:
    /// "ask" (nothing pre-selected, the user picks), "external" (free space on the Mac), "mac" (keep the Mac copy).
    static var crossKeep: String {
        get { UserDefaults.standard.string(forKey: "crossDriveKeep") ?? "ask" }
        set { UserDefaults.standard.set(newValue, forKey: "crossDriveKeep") }
    }
}

enum IgnoreList {
    static let key = "ignoredPaths"
    /// Kept in memory: `contains` runs for every file a scan walks.
    private static var cached: [String]? = nil
    private static let lock = NSLock()
    static var paths: [String] {
        get { lock.lock(); defer { lock.unlock() }
              if let c = cached { return c }
              let v = UserDefaults.standard.stringArray(forKey: key) ?? []; cached = v; return v }
        set { lock.lock(); cached = newValue; lock.unlock(); UserDefaults.standard.set(newValue, forKey: key) }
    }
    static func add(_ p: String) { Prefs.rememberVolume(of: p); let q = Prefs.canonical(p); if !paths.contains(q) { paths.append(q) } }
    static func remove(_ p: String) { paths.removeAll { $0 == p } }
    static func contains(_ p: String) -> Bool { let q = Prefs.canonical(p); return paths.contains { q == $0 || q.hasPrefix($0 + "/") } }
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
    var cross = 0                  // duplicate group spans the Mac and an external drive: 1 = this copy is on the Mac, 2 = on an external drive
    var note: String {
        if running { return t("App is open, quit it first", "App đang mở, tắt app rồi dọn") }
        if hasDB { return t("Has a database inside, may be your data", "Có database bên trong, có thể là dữ liệu của bạn") }
        if nameMatch { return t("Matched by name only, check first", "Khớp theo tên app, kiểm tra trước") }
        if !refStrong.isEmpty { return t("Used by \(refStrong.count) script/skill", "Script/skill đang dùng (\(refStrong.count))") }
        if !refWeak.isEmpty { return t("Mentioned in \(refWeak.count) notes", "Được nhắc trong \(refWeak.count) ghi chú") }
        if cross == 1 { return t("Same file is on an external drive", "Có bản giống hệt trên ổ ngoài") }
        if cross == 2 { return t("Same file is on this Mac", "Có bản giống hệt trên máy") }
        return ""
    }
    /// Warning shown on the row itself. Where a copy sits (Mac / external drive) is said once in the duplicate group header instead.
    var rowNote: String { cross != 0 && !running && !hasDB && !nameMatch && refStrong.isEmpty && refWeak.isEmpty ? "" : note }
    var noteColor: Color { !refStrong.isEmpty || hasDB ? Theme.danger : (running || nameMatch || !refWeak.isEmpty ? Theme.warn : Theme.sub) }
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

    static func blocked(_ p: String) -> Bool { never.contains { p.contains($0) } }
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
                             items: make(findDirs(projects, names: ["_to_delete", "_to-delete", "_tmp"], depth: 5), running: run, defaultOn: false, minSize: 1)))

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
            // Pre-selected only what is shown to be rebuilt (thumbnails, waveforms, analysis caches, logs).
            // recognize (auto captions), ttsTemp (text-to-speech audio) and tmp are not verified: a project may point to them,
            // so they are offered but not pre-selected. Source: research/nguon-chinh-thuc/capcut.md
            AppSection(id: "cache", titleEN: "Scratch files", titleVI: "File tạm khi dựng video",
                       paths: ["frameThumbnail", "audioWave", "AlgorithmCache", "ILASDKDB"].map { "Movies/CapCut/User Data/Cache/\($0)" }
                              + ["Movies/CapCut/User Data/Log"],
                       safety: .safe,
                       whyEN: "Thumbnails, waveforms, analysis caches and logs. CapCut rebuilds them when you open a project.",
                       whyVI: "Ảnh thu nhỏ, sóng âm, dữ liệu phân tích, nhật ký. CapCut tự tạo lại khi mở dự án."),
            AppSection(id: "speech", titleEN: "Captions and voice-over scratch", titleVI: "File tạm phụ đề và giọng đọc",
                       paths: ["recognize", "ttsTemp", "tmp"].map { "Movies/CapCut/User Data/Cache/\($0)" },
                       safety: .review,
                       whyEN: "Working files for auto captions and text-to-speech. A project you are still editing may use them, so check before removing.",
                       whyVI: "File làm việc của phụ đề tự động và giọng đọc. Dự án đang dựng có thể còn dùng, nên xem kỹ trước khi bỏ."),
            AppSection(id: "render", titleEN: "Rendering cache and proxies", titleVI: "Bản dựng sẵn và proxy",
                       paths: ["prerender", "agencycache", "RemuxCache"].map { "Movies/CapCut/User Data/Cache/\($0)" },
                       safety: .review,
                       whyEN: "Preview renders, low-res proxies and converted copies of your clips. CapCut makes them again; previews may lag for a while. CapCut also clears them in Settings > Performance.",
                       whyVI: "Bản dựng sẵn, proxy và bản chuyển định dạng của video. CapCut tạo lại, xem trước có thể giật một lúc. Trong CapCut cũng xoá được ở Cài đặt › Performance."),
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
    /// Month rows: the files picked one by one in the month viewer (nil = the whole row, companion files included).
    var picked: Set<String>? = nil
    var pickedSize: Int64 = 0
    var pickedCount = 0          // photos picked (a photo may have several copies on disk)
    var selSize: Int64 { !selected ? 0 : (picked == nil ? size : pickedSize) }
    var checkState: Int { !selected ? 0 : (picked == nil ? 2 : 1) }
    var selURLs: [URL] { !selected ? [] : (picked.map { p in urls.filter { p.contains($0.path) } } ?? urls) }
    /// Under the title in the list: "84 files", plus what was picked one by one in the month viewer.
    var subLine: String {
        guard checkState == 1 else { return sub }
        let n = pickedCount, z = fmt(pickedSize)
        return sub + t(" · \(n) picked (\(z))", " · đã chọn \(n) (\(z))")
    }
}
struct AppGroup: Identifiable {
    let id: String
    let section: AppSection
    var rows: [AppRow]
    var expanded = false
    var total: Int64 { rows.reduce(0) { $0 + $1.size } }
    var selected: Int64 { rows.reduce(0) { $0 + $1.selSize } }
    var state: Int {
        if rows.allSatisfy({ $0.checkState == 2 }) { return 2 }
        return rows.contains(where: { $0.checkState > 0 }) ? 1 : 0
    }
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
        var bucket: [Date: (size: Int64, urls: [URL], index: Int)] = [:]   // index = app index files (Zalo .rescache), not counted as files
        var copies: [Date: Set<String>] = [:]   // Zalo photo keys seen per month: copies of one photo count once
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey, .contentModificationDateKey]
        for tpl in s.paths {
            for folder in expand(tpl) where !Scanner.skip(folder.path) {
                if s.dbGuard && Scanner.holdsDatabase(folder) { continue }
                guard let en = Scanner.fm.enumerator(at: folder, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, _ in true }) else { continue }
                for case let f as URL in en {
                    guard let v = try? f.resourceValues(forKeys: keys), v.isRegularFile == true, !Scanner.isDatabase(f) else { continue }
                    let m = monthStart(v.contentModificationDate ?? Date())
                    bucket[m, default: (0, [], 0)].size += Int64(v.totalFileAllocatedSize ?? 0)
                    bucket[m, default: (0, [], 0)].urls.append(f)
                    if MonthItem.isCompanion(f) { bucket[m, default: (0, [], 0)].index += 1 }
                    else if let k = MonthItem.variantKey(f) {
                        if copies[m, default: []].contains(k) { bucket[m, default: (0, [], 0)].index += 1 } else { copies[m, default: []].insert(k) }
                    }
                }
            }
        }
        return bucket.keys.sorted(by: >).map { m in
            let b = bucket[m]!
            let n = b.urls.count - b.index
            let sub = n > 0 ? t("\(n) files", "\(n) file")
                            : t("only \(b.index) index files of the app", "chỉ còn \(b.index) tệp chỉ mục của app")
            return AppRow(id: s.id + "|" + ISO8601DateFormatter().string(from: m), title: monthLabel(m),
                          sub: sub, size: b.size, count: n, urls: b.urls, month: m, selected: false)
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

/// Same nodes and size give the same layout: hovering a bubble redraws the view, packing again would be wasted.
@MainActor private var packCache: (key: String, value: [Bubble])? = nil
@MainActor func pack(_ nodes: [Node], in size: CGSize) -> [Bubble] {
    let key = "\(Int(size.width))x\(Int(size.height))|" + nodes.map { "\($0.url.path)=\($0.size)" }.joined(separator: "|")
    if let c = packCache, c.key == key { return c.value }
    let v = packLayout(nodes, in: size)
    packCache = (key, v)
    return v
}
func packLayout(_ nodes: [Node], in size: CGSize) -> [Bubble] {
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
        // The user's own cache and temp folders under /private/var/folders (confstr(3): cache is never cleaned by the
        // system, temp files unused for 3 days may be). Only the folder named exactly like this app's bundle id.
        for key in [_CS_DARWIN_USER_CACHE_DIR, _CS_DARWIN_USER_TEMP_DIR] {
            var buf = [CChar](repeating: 0, count: 1024)
            if confstr(key, &buf, buf.count) > 0, !id.isEmpty { byID.append(URL(fileURLWithPath: String(cString: buf)).appendingPathComponent(id)) }
        }
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
    /// Copies both on the Mac and on an external drive.
    var isCross: Bool { items.contains { $0.cross == 1 } && items.contains { $0.cross == 2 } }
}

enum Dupes {
    static let roots = ["Documents", "Downloads", "Desktop", "Pictures", "Movies", "Music"].map { Scanner.home.appendingPathComponent($0) }
    static let skipDirs: Set<String> = [".git", "node_modules", "__pycache__", ".venv", "venv", "build", "DerivedData", "Backups.backupdb"]

    static func hash(_ u: URL, limit: Int? = nil) -> String? {
        guard let h = try? FileHandle(forReadingFrom: u) else { return nil }
        defer { try? h.close() }
        var hasher = SHA256(); var read = 0
        while true {
            let want = limit.map { min(1 << 20, $0 - read) } ?? (1 << 20)
            if want <= 0 { break }
            // Each 1 MB chunk is released right away; without the pool a large video piled up in memory until the end (1.5 GB peak seen).
            let n: Int = autoreleasepool {
                guard let d = try? h.read(upToCount: want), !d.isEmpty else { return 0 }
                hasher.update(data: d); return d.count
            }
            if n == 0 { break }
            read += n
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Which copy to keep: not in Downloads/Desktop/_tmp, then shorter path.
    static func keepScore(_ u: URL) -> (Int, Int) {
        let p = u.path
        let temp = ["/Downloads/", "/Desktop/", "/_tmp", "/_to_delete", "/_to-delete"].contains { p.contains($0) } ? 1 : 0
        return (temp, p.count)
    }
    /// Order a group (kept copy first) and set what is pre-selected.
    /// A group with copies both on the Mac and on an external drive follows `rule` (Prefs.crossKeep):
    /// "external" keeps the external copy, "mac" keeps the Mac copy, "ask" pre-selects nothing.
    /// Copies inside project folders are never pre-selected.
    static func arrange(_ items: [CleanItem], rule: String) -> [CleanItem] {
        let onExt = { (i: CleanItem) in Prefs.onOtherDrive(i.url.path) }
        let isCross = items.contains(where: onExt) && items.contains { !onExt($0) }
        var out = items.sorted { keepScore($0.url) < keepScore($1.url) }
        if isCross && rule != "ask" {
            let keepExt = rule == "external"
            out = out.filter { onExt($0) == keepExt } + out.filter { onExt($0) != keepExt }
        }
        for i in out.indices {
            out[i].cross = isCross ? (onExt(out[i]) ? 2 : 1) : 0
            out[i].selected = i > 0 && !Prefs.inProject(out[i].url.path) && !(isCross && rule == "ask") && out[i].refStrong.isEmpty
        }
        return out
    }

    static func scan(minBytes: Int64 = 1 << 20, progress: @escaping (Int) -> Void) -> [DupGroup] {
        var bySize: [Int64: [URL]] = [:]
        var count = 0
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey, .isDirectoryKey, .fileResourceIdentifierKey]
        var seenFiles = Set<NSObject>()   // hard links share one file: count it once, trashing a link frees nothing
        for r in Scanner.scanRoots(roots) {
            guard let en = FileManager.default.enumerator(at: r, includingPropertiesForKeys: Array(keys),
                                                          options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, _ in true }) else { continue }
            for case let f as URL in en {
                if skipDirs.contains(f.lastPathComponent) || Scanner.skip(f.path) { en.skipDescendants(); continue }
                guard let v = try? f.resourceValues(forKeys: keys), v.isRegularFile == true, let sz = v.fileSize, Int64(sz) >= minBytes else { continue }
                if let fid = v.fileResourceIdentifier as? NSObject, !seenFiles.insert(fid).inserted { continue }
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
                    let items = arrange(same.map { u in
                        CleanItem(url: u, size: sz, selected: false, date: (try? u.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate)
                    }, rule: Prefs.crossKeep)
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
    case smart = "Smart Scan", cleanup = "Cleanup", byapp = "Clean by App", large = "Large & Old Files", lens = "Space Lens", trash = "Trash", ignore = "Ignore List", cloud = "Cloud Cleanup", settings = "Settings", apps = "Uninstaller", dupes = "Duplicates", startup = "Startup", stats = "Stats", contact = "Contact"
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
    func uninstall(_ id: UUID) {
        guard let i = apps.firstIndex(where: { $0.id == id }) else { return }
        let a = apps[i]
        if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == a.bundleID }) {
            _ = confirm(t("Quit \(a.name) first", "Tắt \(a.name) trước"), t("The app is running. Quit it, then try again.", "App đang mở. Tắt app rồi bấm lại."), "OK"); return
        }
        let extra = a.related.filter(\.selected)
        let total = a.size + extra.reduce(0) { $0 + $1.size }
        guard confirm(t("Uninstall \(a.name)?", "Gỡ \(a.name)?"),
                      t("The app and \(extra.count) related items (\(fmt(total))) will be moved to the Trash.", "App và \(extra.count) mục liên quan (\(fmt(total))) sẽ được chuyển vào Thùng rác.")
                        + (a.needsAdmin ? t(" macOS will ask for an administrator password in its own window; Tidymint never sees it.", " macOS sẽ hỏi mật khẩu quản trị trong hộp thoại của macOS; Tidymint không thấy mật khẩu.") : ""),
                      t("Uninstall", "Gỡ")) else { return }
        if a.needsAdmin { uninstallWithFinder(a, extra: extra, total: total); return }
        NSWorkspace.shared.recycle([a.url]) { newURLs, err in
            Task { @MainActor in
                guard err == nil else {
                    // The app itself could not go to the Trash: leave its related files where they are.
                    self.log("Uninstall \(a.name) failed: \(err!.localizedDescription)")
                    self.appsMsgErr = true
                    self.appsMsg = t("Could not move \(a.name) to the Trash: macOS did not allow it. Nothing was moved. You can drag the app to the Trash in Finder.",
                                     "Không chuyển được \(a.name) vào Thùng rác: macOS không cho phép. Chưa có gì bị chuyển đi. Bạn có thể kéo app vào Thùng rác trong Finder.")
                    return
                }
                // Record the app in the Undo journal together with its related files, so Undo puts all of it back.
                let appEntry = newURLs[a.url].map { [Journal.Entry(from: a.url.path, to: $0.path, size: a.size)] } ?? []
                let (ok, _) = self.trash(extra.map(\.url), label: a.name, alsoUndo: appEntry)
                self.apps.removeAll { $0.id == id }; self.selApp = nil
                self.finished(.apps, ok + 1, total, 0)
                self.appsMsgErr = false
                self.appsMsg = t("Uninstalled \(a.name) and \(ok) related items (\(fmt(total))).", "Đã gỡ \(a.name) và \(ok) mục liên quan (\(fmt(total))).")
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
                    let (ok, _) = self.trash(extra.map(\.url), label: a.name, alsoUndo: appEntry)
                    self.apps.removeAll { $0.id == a.id }; self.selApp = nil
                    self.finished(.apps, ok + 1, total, 0)
                    self.appsMsgErr = false
                    self.appsMsg = t("Uninstalled \(a.name) and \(ok) related items (\(fmt(total))).", "Đã gỡ \(a.name) và \(ok) mục liên quan (\(fmt(total))).")
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
                if case .failed(let e) = r { self.log("Uninstall \(a.name) through Finder failed: \(e)") }
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
    /// Re-apply a keep rule to the groups that span the Mac and an external drive (menu on the Duplicates page).
    func dupApplyCross(_ rule: String) {
        for i in dupes.indices where dupes[i].isCross { dupes[i].items = Dupes.arrange(dupes[i].items, rule: rule) }
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
        let f = Double(v?.volumeAvailableCapacityForImportantUsage ?? 0) / 1_000_000_000
        let tot = Double(v?.volumeTotalCapacity ?? 0) / 1_000_000_000
        if abs(f - freeGB) >= 0.05 { freeGB = f }
        if abs(tot - totalGB) >= 0.05 { totalGB = tot }
        if freeGB > 0 { DiskHistory.record(freeGB) }
    }

    func refreshTrash() {
        let t = Scanner.trashURL
        Task.detached {
            // Finder's Empty Trash also empties the Trash on each mounted drive (.Trashes/<uid>), so count those too.
            let vols = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeIsLocalKey], options: [.skipHiddenVolumes]) ?? []
            let uid = getuid()
            let trashes = [t] + vols.filter { $0.path.hasPrefix("/Volumes/") && (try? $0.resourceValues(forKeys: [.volumeIsLocalKey]))?.volumeIsLocal == true }
                .map { $0.appendingPathComponent(".Trashes/\(uid)") }
                // Only a Trash macOS itself made: ".Trashes" owned by root. A ".Trashes" folder made by a script or copy
                // is not shown or emptied by Finder (seen 04/11/2026), so counting it made the number look stuck.
                .filter { u in
                    FileManager.default.fileExists(atPath: u.path) &&
                    ((try? FileManager.default.attributesOfItem(atPath: u.deletingLastPathComponent().path))?[.ownerAccountID] as? NSNumber)?.intValue == 0
                }
            let s = trashes.reduce(Int64(0)) { $0 + Scanner.size($1) }
            let c = trashes.reduce(0) { $0 + Scanner.children($1, hidden: false).count }
            let drives: [(String, Int, Int64)] = trashes.dropFirst().compactMap { u in
                let n = Scanner.children(u, hidden: false).count
                return n == 0 ? nil : (u.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent, n, Scanner.size(u))
            }
            await MainActor.run { self.trashSize = s; self.trashCount = c; self.trashOnDrives = drives }
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
        case 1: return apps.filter { ($0.lastUsed ?? .distantPast) < old }
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
    func trash(_ urls: [URL], label: String = "", strict: Bool = true, alsoUndo: [Journal.Entry] = [], sizes: [URL: Int64] = [:]) -> (Int, Int) {
        var ok = 0, fail = 0
        lastOK = []; lastErr = ""
        if Demo.active { lastErr = t("demo mode, nothing is moved", "chế độ demo, không chuyển gì"); return (0, urls.count) }
        var moved: [Journal.Entry] = alsoUndo
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
        let needsPassword = s.entries.contains { ((try? FileManager.default.attributesOfItem(atPath: $0.to)[.ownerAccountID] as? NSNumber)?.intValue) == 0 }
        guard confirm(t("Undo the last clean\(sessionName(s))?", "Hoàn tác lần dọn vừa rồi\(sessionName(s))?"),
                      t("\(s.entries.count) items (\(fmt(s.size))) go back to where they were.", "\(s.entries.count) mục (\(fmt(s.size))) sẽ trở về chỗ cũ.")
                        + (needsPassword ? t(" An app installed for every user goes back through Finder: macOS asks for an administrator password in its own window.", " App cài cho mọi tài khoản được Finder trả về: macOS hỏi mật khẩu quản trị trong hộp thoại của macOS.") : ""),
                      t("Put Back", "Trả về chỗ cũ")) else { return }
        let r = Journal.restore(s)
        lastResult = t("Put back \(r.ok) items\(sessionName(s)).", "Đã trả về \(r.ok) mục\(sessionName(s)).") + (r.skipped > 0 ? t(" \(r.skipped) were already gone or replaced.", " \(r.skipped) mục đã mất hoặc đã có file mới ở chỗ cũ.") : "")
        undoNote = (page == .trash ? .trash : (doneInfo?.page ?? page), lastResult)
        log("Undo: put back \(r.ok) items, skipped \(r.skipped)")
        undoable = nil; Journal.clear()
        refreshTrash(); refreshDisk()
    }
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

    func emptyTrash() {
        guard confirm(t("Empty Trash?", "Đổ Thùng rác?"), t("\(trashCount) items, \(fmt(trashSize)). This cannot be undone.", "\(trashCount) mục, \(fmt(trashSize)). Đổ rồi không lấy lại được."), t("Empty Trash", "Đổ Thùng rác")) else { return }
        var err: NSDictionary?
        NSAppleScript(source: "tell application \"Finder\" to empty trash")?.executeAndReturnError(&err)
        if let e = err, (e[NSAppleScript.errorNumber] as? Int) == -128 {
            // The person cancelled Finder's own confirmation: nothing happened, nothing to report.
        } else if let e = err {
            let msg = (e[NSAppleScript.errorMessage] as? String) ?? "\(e)"
            log("ERROR empty Trash: \(msg)")
            _ = confirm(t("Could not empty the Trash", "Chưa đổ được Thùng rác"),
                        t("Finder did not empty it (\(msg)). Allow Tidymint to control Finder in System Settings > Privacy & Security > Automation, then try again.",
                          "Finder chưa đổ (\(msg)). Cho phép Tidymint điều khiển Finder trong Cài đặt hệ thống > Quyền riêng tư & Bảo mật > Tự động hoá, rồi thử lại."), "OK")
        } else {
            log("Emptied Trash: \(fmt(trashSize))")
            undoable = nil; Journal.clear()   // the items are gone, Undo can no longer put them back
        }
        refreshTrash(); refreshDisk()
        // Finder can leave items behind (seen 04/11/2026: a folder in an external drive's Trash stayed after Empty Trash).
        // Check again once Finder is done and say what is left, instead of showing an unchanged number with no reason.
        trashLeftNote = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            self.refreshTrash()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                guard self.trashCount > 0 else { return }
                self.trashLeftNote = t("Finder did not empty everything: \(self.trashCount) items are still there. Open the Trash in Finder to see them, then empty it again.",
                                       "Finder chưa đổ hết: còn \(self.trashCount) mục. Mở Thùng rác trong Finder để xem, rồi đổ lại.")
            }
        }
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
        if ok > 0 { lensNodes.removeAll { $0.id == n.id }; lensSel.remove(n.url); sizeCache.removeValue(forKey: n.url.path); log("Space Lens: moved \(n.url.path) (\(fmt(n.size))) to Trash") }
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

/// Move a file into ~/.Trash directly (used when the standard Trash refuses, e.g. iCloud Drive files).
/// True for a file inside ~/Library/Mobile Documents (iCloud Drive) that sits on the same volume as the home folder.
func isICloudDriveOnHomeVolume(_ u: URL) -> Bool {
    let home = URL(fileURLWithPath: NSHomeDirectory())
    let icloud = home.appendingPathComponent("Library/Mobile Documents").resolvingSymlinksInPath().path + "/"
    guard u.resolvingSymlinksInPath().path.hasPrefix(icloud) else { return false }
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
        "Developer": ("Xcode data, simulators, build files and archives. Build files can go; keep the archives of apps you released.", "Dữ liệu Xcode, máy ảo, file build và bản archive. File build xoá được; giữ archive của bản đã phát hành."),
        "DerivedData": ("Xcode build files. Xcode makes them again; the next build is slower. Quit Xcode first.", "File build của Xcode. Xcode tự tạo lại, lần build sau lâu hơn. Đóng Xcode trước."),
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
        "iOS DeviceSupport": ("System symbols copied from each iPhone you plugged in, used to read crash reports. Old versions can go; Xcode copies them again only from a device still on that version.", "Ký hiệu hệ thống chép từ từng iPhone từng cắm, dùng để đọc báo cáo lỗi. Bản cũ xoá được; Xcode chỉ chép lại từ máy còn chạy đúng bản đó."),
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
        // First "(number unit)" group: an app name can carry its own parentheses ("Foo (Beta)").
        let units: [String: Double] = ["bytes": 1, "KB": 1e3, "MB": 1e6, "GB": 1e9, "TB": 1e12]
        var rest = m[...]
        while let open = rest.firstIndex(of: "("), let close = rest[open...].firstIndex(of: ")") {
            let bits = rest[rest.index(after: open)..<close].replacingOccurrences(of: ",", with: ".").split(separator: " ")
            if bits.count == 2, let v = Double(bits[0]), let mult = units[String(bits[1])] { return Int64(v * mult) }
            rest = rest[rest.index(after: close)...]
        }
        return 0
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
    private static var lastWritten: (day: String, gb: Double)? = nil
    static func record(_ gb: Double) {
        let day = key.string(from: Date()), v = (gb * 10).rounded() / 10
        if let w = lastWritten, w.day == day, w.gb == v { return }   // unchanged: skip the read and rewrite of the file
        lastWritten = (day, v)
        var m = load()
        m[day] = v
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
            .font(.system(size: fs(15), weight: .medium))
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
    /// Small macOS-size button for list rows (Settings): 12 pt text, tight padding, width from the label.
    var compact = false
    var body: some View {
        Button(action: action) {
            Text(title).font(compact ? .system(size: fs(13), weight: .medium) : Pill.font).foregroundColor(.white).lineLimit(1)
                .frame(width: compact ? nil : width.map { $0 - 2 * Pill.padH })
                .padding(.horizontal, compact ? 11 : Pill.padH).padding(.vertical, compact ? 4 : Pill.padV)
                .background(compact ? AnyView(RoundedRectangle(cornerRadius: 6).fill(Theme.accentSolid)) : AnyView(Capsule().fill(Theme.accent))).opacity(disabled ? 0.4 : 1)
                .shadow(color: Theme.accentSolid.opacity(compact ? 0 : 0.4), radius: 12, y: 4)
        }.buttonStyle(.plain).disabled(disabled).hoverLift()
    }
}

struct GhostButton: View {
    let title: String; let action: () -> Void
    var width: CGFloat? = nil
    /// Small macOS-size button for list rows (Settings): 12 pt text, tight padding, width from the label.
    var compact = false
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: fs(13 + (compact ? 0 : 1)), weight: compact ? .regular : .medium)).foregroundColor(Theme.text).lineLimit(1)
                .frame(width: compact ? nil : width.map { $0 - 2 * Pill.padH })
                .padding(.horizontal, compact ? 11 : Pill.padH).padding(.vertical, compact ? 4 : Pill.padV)
                .background(compact ? AnyView(RoundedRectangle(cornerRadius: 6).fill(Theme.ink.opacity(0.13))) : AnyView(Capsule().stroke(Theme.ink.opacity(0.35), lineWidth: 1)))
                .hoverBG(compact ? 6 : 20, Theme.ink.opacity(0.1))
        }.buttonStyle(.plain).hoverLift()
    }
}

/// The mint leaf from the brand kit (assets/brand/src/leaf-path.txt), as a polygon in a 0...1000 box, width:height = 845:1311.
struct LeafShape: Shape {
    static let pts: [CGFloat] = [717,0,704,2,685,5,658,13,633,23,607,37,583,53,562,71,543,91,527,111,525,111,522,110,516,106,512,102,505,92,499,79,480,85,455,97,443,104,428,114,414,126,402,138,382,164,373,177,367,192,366,191,341,154,309,171,286,186,267,200,241,224,227,240,214,257,203,276,196,293,192,305,191,314,189,314,161,270,159,271,151,279,139,292,128,306,115,326,106,346,99,365,93,388,89,416,89,438,90,444,88,444,26,416,25,417,24,462,24,477,28,507,31,527,40,560,49,589,55,603,44,603,31,602,19,600,1,594,0,595,9,623,21,651,29,667,42,688,57,709,83,739,112,765,141,788,176,810,211,830,254,849,256,870,260,892,261,894,264,912,272,934,287,968,295,982,307,1000,308,999,306,997,303,979,301,956,301,936,303,910,311,872,318,850,330,821,343,795,356,772,373,746,398,711,439,659,512,575,553,526,589,478,617,435,628,413,643,382,651,360,658,334,663,309,664,284,664,258,662,241,660,239,661,235,662,236,667,255,670,282,670,315,669,320,669,328,666,350,657,382,650,403,637,434,615,477,585,524,552,571,496,644,463,689,442,720,421,755,404,786,391,814,378,851,371,882,396,887,431,890,488,890,511,888,540,885,568,881,597,876,625,870,653,863,705,847,705,846,699,845,683,839,669,831,670,830,685,830,707,827,740,821,760,816,781,809,818,794,852,776,873,763,878,759,868,763,855,766,841,767,827,767,804,764,788,760,785,759,816,749,843,736,873,718,897,698,918,677,942,649,960,622,974,594,973,594,964,598,948,603,937,604,931,604,922,602,917,599,914,594,928,585,942,572,952,561,963,543,975,520,987,491,999,449,999,448,994,451,985,452,962,452,932,449,930,448,941,439,953,424,962,404,968,381,970,365,971,328,969,302,964,274,954,281,941,286,924,289,915,290,914,289,915,277,915,259,909,227,895,181,875,132,873,132,861,142,844,153,831,159,828,159,828,154,826,144,820,130,810,111,798,93,763,50,736,20]
    func path(in r: CGRect) -> Path {
        var p = Path()
        let aspect: CGFloat = 845.0 / 1311.0
        var w = r.width, h = r.height
        if w / h > aspect { w = h * aspect } else { h = w / aspect }
        let ox = r.midX - w / 2, oy = r.midY - h / 2
        let xs = stride(from: 0, to: Self.pts.count, by: 2).map { CGPoint(x: ox + Self.pts[$0] / 1000 * w, y: oy + Self.pts[$0 + 1] / 1000 * h) }
        guard let f = xs.first else { return p }
        p.move(to: f); for q in xs.dropFirst() { p.addLine(to: q) }; p.closeSubpath()
        return p
    }
}

/// The big Scan button: a dark core with the mint leaf inside a thin ring. Hover fades the leaf and shows the word.
struct BigScanButton: View {
    let label: String; let action: () -> Void
    @StateObject private var pulse = Flag()   // hover
    @StateObject private var breath = Flag()  // slow idle breathing, off when Reduce Motion is on
    var body: some View {
        let still = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let hot = pulse.v
        Button(action: action) {
            ZStack {
                Circle().fill(Theme.accentSolid.opacity(breath.v || hot ? 0.20 : 0.12)).frame(width: 190, height: 190)
                    .scaleEffect(still ? 1 : (hot ? 1.08 : (breath.v ? 1.05 : 0.97)))
                Circle().fill(Theme.tile).frame(width: 150, height: 150)
                    .overlay(Circle().stroke(Theme.accentSolid.opacity(hot ? 1 : 0.6), lineWidth: 2))
                    .shadow(color: Theme.accentSolid.opacity(breath.v || hot ? 0.6 : 0.35), radius: breath.v || hot ? 30 : 20)
                LeafShape().fill(Theme.accent).frame(width: 88, height: 88)
                    .opacity(hot ? 0.18 : 1).scaleEffect(hot && !still ? 1.06 : 1)
                Text(label).font(.system(size: fs(24), weight: .bold)).foregroundColor(Theme.text)
                    .opacity(hot ? 1 : 0)
            }
        }.buttonStyle(.plain)
        .accessibilityLabel(label)
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
            // Narrow column so lines break evenly instead of running edge to edge with one orphan word.
            Text(sub).font(.system(size: fs(14))).foregroundColor(Theme.sub).multilineTextAlignment(.center)
                .frame(maxWidth: 560 * uiScale).fixedSize(horizontal: false, vertical: true)
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

/// What a file really is, read from its first bytes when the name has no useful extension
/// (Zalo, Messenger and others save photos and videos without one).
enum FileKind {
    case image, video, pdf, other
    static let imageExt: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "tif", "bmp", "raw", "dng", "cr2", "nef", "arw", "psd", "jxl", "avif"]
    static let videoExt: Set<String> = ["mov", "mp4", "m4v", "avi", "mkv", "webm", "3gp"]
    private static var memo: [String: FileKind] = [:]
    private static let lock = NSLock()
    static func clearMemo() { lock.lock(); memo = [:]; lock.unlock() }
    static func of(_ url: URL) -> FileKind {
        let e = url.pathExtension.lowercased()
        if imageExt.contains(e) { return .image }
        if videoExt.contains(e) { return .video }
        if e == "pdf" { return .pdf }
        if ["txt", "json", "plist", "db", "sqlite", "log", "ttf", "otf", "zip", "dmg", "pkg", "app", "html", "js", "css", "meta", "rescache"].contains(e) { return .other }
        // Anything else (no extension, or WhatsApp's .thumb / .mmsthumb / .videothumb) is read to see what it really is.
        lock.lock(); if let k = memo[url.path] { lock.unlock(); return k }; lock.unlock()
        let k = sniff(url)
        lock.lock(); memo[url.path] = k; lock.unlock()
        return k
    }
    static func sniff(_ url: URL) -> FileKind {
        guard let h = try? FileHandle(forReadingFrom: url) else { return .other }
        defer { try? h.close() }
        guard let d = try? h.read(upToCount: 16), d.count >= 4 else { return .other }
        let b = [UInt8](d)
        func ascii(_ r: Range<Int>) -> String { r.upperBound <= b.count ? String(bytes: b[r], encoding: .ascii) ?? "" : "" }
        if b[0] == 0xFF && b[1] == 0xD8 { return .image }                                   // JPEG
        if b[0] == 0x89 && ascii(1..<4) == "PNG" { return .image }
        if ascii(0..<4) == "GIF8" || ascii(0..<4) == "8BPS" { return .image }               // GIF, PSD
        if ascii(0..<4) == "RIFF" && ascii(8..<12) == "WEBP" { return .image }
        if ascii(0..<4) == "RIFF" && ascii(8..<12) == "AVI " { return .video }
        if (b[0] == 0x49 && b[1] == 0x49) || (b[0] == 0x4D && b[1] == 0x4D) { return .image }  // TIFF
        if b[0] == 0xFF && b[1] == 0x0A { return .image }                                   // JPEG XL codestream
        if ascii(4..<8) == "JXL " { return .image }                                         // JPEG XL container
        if ascii(0..<4) == "%PDF" { return .pdf }
        if b[0] == 0x1A && b[1] == 0x45 && b[2] == 0xDF && b[3] == 0xA3 { return .video }   // Matroska / WebM
        if ascii(4..<8) == "ftyp" {
            let brand = ascii(8..<12)
            if ["heic", "heix", "heim", "heis", "mif1", "msf1", "avif", "avis"].contains(brand) { return .image }
            return .video                                                                   // mp4, m4v, mov (qt), 3gp
        }
        return .other
    }
}

/// Real thumbnail for photos and videos, the Finder icon for everything else. Cached per path and size.
/// Photos go through ImageIO, which reads the content, so files without an extension still get a picture.
final class ThumbStore: ObservableObject {
    @Published var image: NSImage?
    @Published var real = false   // true once a real thumbnail replaced the Finder icon
    // Bounded so a long scroll through thousands of photos cannot pile up decoded thumbnails.
    static let cache: NSCache<NSString, NSImage> = { let c = NSCache<NSString, NSImage>(); c.countLimit = 300; c.totalCostLimit = 24 << 20; return c }()
    static func cost(_ img: NSImage) -> Int {
        let px = img.representations.map { $0.pixelsWide * $0.pixelsHigh }.max() ?? 0
        return max(1, px) * 4
    }
    static let work: OperationQueue = { let q = OperationQueue(); q.maxConcurrentOperationCount = 4; q.qualityOfService = .userInitiated; return q }()
    static var media: Set<String> { FileKind.imageExt.union(FileKind.videoExt).union(["pdf"]) }
    func load(_ url: URL, side: CGFloat) {
        let key = "\(url.path)|\(Int(side))" as NSString
        if let c = ThumbStore.cache.object(forKey: key) { image = c; real = true; return }
        image = NSWorkspace.shared.icon(forFile: url.path)
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        ThumbStore.work.addOperation { [weak self] in
            let kind = FileKind.of(url)
            guard kind != .other, FileManager.default.fileExists(atPath: url.path) else { return }
            if kind == .image, let img = ThumbStore.imageThumb(url, px: side * scale) {
                ThumbStore.cache.setObject(img, forKey: key, cost: ThumbStore.cost(img))
                DispatchQueue.main.async { self?.image = img; self?.real = true }
                return
            }
            if kind == .video && url.pathExtension.isEmpty, let img = ThumbStore.videoThumb(url, px: side * scale) {
                ThumbStore.cache.setObject(img, forKey: key, cost: ThumbStore.cost(img))
                DispatchQueue.main.async { self?.image = img; self?.real = true }
                return
            }
            let req = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: side, height: side), scale: scale, representationTypes: .thumbnail)
            QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { rep, _ in
                guard let img = rep?.nsImage else { return }
                ThumbStore.cache.setObject(img, forKey: key, cost: ThumbStore.cost(img))
                DispatchQueue.main.async { self?.image = img; self?.real = true }
            }
        }
    }
    static func imageThumb(_ url: URL, px: CGFloat) -> NSImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                                     kCGImageSourceThumbnailMaxPixelSize: Int(px), kCGImageSourceShouldCacheImmediately: true]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width) / 2, height: CGFloat(cg.height) / 2))
    }
    /// A video saved without an extension: AVFoundation goes by the extension, so read it through a short-lived hard link
    /// named .mp4 in Tidymint's temporary folder (a second name for the same file, removed right after; the video is untouched).
    static func videoThumb(_ url: URL, px: CGFloat) -> NSImage? {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tidymint-thumb", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let link = dir.appendingPathComponent(UUID().uuidString + ".mp4")
        guard (try? FileManager.default.linkItem(at: url, to: link)) != nil else { return nil }
        defer { try? FileManager.default.removeItem(at: link) }
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: link))
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: px, height: px)
        guard let cg = try? gen.copyCGImage(at: CMTime(seconds: 0.5, preferredTimescale: 600), actualTime: nil) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width) / 2, height: CGFloat(cg.height) / 2))
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
    /// Duplicates: the copy suggested to keep shows a "Keep" tag. `keepColumn` reserves that column on every row of the
    /// group, so the date and size columns stay in line whether or not a row has the tag.
    var keep = false
    var keepColumn = false
    var body: some View {
        HStack(spacing: 12) {
            Button { item.selected.toggle() } label: { CheckBox(state: item.selected ? 2 : 0) }.buttonStyle(.plain)
            FileThumb(url: item.url, side: 26 * uiScale)
            // Name, path, and (when there is one) the warning on its own line: all start at the same left edge,
            // so nothing pokes out between rows and the name never gets squeezed (style guide 1f).
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).foregroundColor(Theme.text).font(.system(size: fs(13))).lineLimit(1)
                Text(item.shortPath).foregroundColor(Theme.sub).font(.system(size: fs(11))).lineLimit(1).truncationMode(.middle)
                if !item.rowNote.isEmpty {
                    Label(item.rowNote, systemImage: "exclamationmark.triangle.fill").font(.system(size: fs(11), weight: .medium))
                        .foregroundColor(item.noteColor).lineLimit(1).tip(item.refHelp)
                }
            }
            Spacer(minLength: 12)
            if keepColumn {
                Group { if keep { StatusTag(t("Keep", "Giữ"), Theme.green) } }.frame(width: 50 * uiScale, alignment: .center)
            }
            if showDate {
                Text(item.date.map(openedLabel) ?? "")
                    .foregroundColor(Theme.sub).font(.system(size: fs(11)).monospacedDigit())
                    .lineLimit(1).frame(width: 165 * uiScale, alignment: .trailing)
            }
            Text(fmt(item.size)).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .medium).monospacedDigit()).frame(width: 80 * uiScale, alignment: .trailing)
        }
        .padding(.vertical, 9).padding(.horizontal, 12)
        .hoverBG(8, Theme.ink.opacity(0.07))
        .contentShape(Rectangle())
        // Like Finder: double-click opens in the default app, click shows a preview, Space over the row too.
        .onTapGesture(count: 2) { vm.fileQL = nil; vm.openFile(item.url) }
        .onTapGesture { vm.fileQL = item.url }
        .onHover { inside in
            if inside { vm.hoverFile = item.url } else if vm.hoverFile == item.url { vm.hoverFile = nil }
        }
        .contextMenu { FileMenu(url: item.url, vm: vm)
            Button(item.selected ? t("Deselect", "Bỏ chọn") : t("Select", "Chọn")) { item.selected.toggle() }
            Divider()
            Button(t("Ignore (don't show again)", "Bỏ qua (không hiện lại)")) { let u = item.url; DispatchQueue.main.async { vm.ignore(u) } }
        }
    }
}

/// Right-click items for a file, Finder style: Open, Open With, Quick Look, Show in Finder, Copy Path.
/// Nothing here deletes; cleaning stays with the tick boxes and Move to Trash.
struct FileMenu: View {
    let url: URL
    let vm: VM
    var openWith = true
    var quickLook = true
    var body: some View {
        Button(t("Open", "Mở")) { vm.openFile(url) }
        if openWith { Menu(t("Open With", "Mở bằng")) {
            let def = NSWorkspace.shared.urlForApplication(toOpen: url)
            let apps = NSWorkspace.shared.urlsForApplications(toOpen: url)
            if let d = def {
                Button(FileManager.default.displayName(atPath: d.path) + t(" (default)", " (mặc định)")) { vm.openFile(url, with: d) }
                if apps.count > 1 { Divider() }
            }
            ForEach(apps.filter { $0 != def }.prefix(20), id: \.self) { a in
                Button(FileManager.default.displayName(atPath: a.path)) { vm.openFile(url, with: a) }
            }
            if def == nil && apps.isEmpty { Text(t("No app can open this file", "Chưa có app mở được file này")) }
        } }
        if quickLook { Button(t("Quick Look", "Xem nhanh")) { vm.fileQL = url } }
        Divider()
        Button(t("Show in Finder", "Hiện trong Finder")) { vm.reveal(url) }
        Button(t("Copy Path", "Chép đường dẫn")) {
            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(url.path, forType: .string)
        }
        Divider()
    }
}

/// Shown at the top of a list page right after a clean: how much got tidier, Undo, and the way to the Trash.
struct DoneBanner: View {
    @ObservedObject var vm: VM
    let page: Page
    var body: some View {
        if vm.doneInfo?.page != page, let n = vm.undoNote, n.page == page {
            UndoNote(vm: vm, text: n.text)
        } else if let d = vm.doneInfo, d.page == page {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: fs(22))).foregroundColor(Theme.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text(d.size > 0 ? t("\(fmt(d.size)) tidier", "Gọn thêm \(fmt(d.size))") : t("Done", "Xong"))
                        .font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                    Text(t("\(d.count) items moved to the Trash. Empty the Trash to free the space for real.",
                           "\(d.count) mục đã vào Thùng rác. Đổ Thùng rác thì ổ mới trống thật.") + (d.fail > 0 ? t(" \(d.fail) skipped.", " Bỏ qua \(d.fail) mục.") : ""))
                        .font(.system(size: fs(12))).foregroundColor(Theme.sub).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if vm.bannerCanUndo { GhostButton(title: t("Undo", "Hoàn tác"), action: { vm.undoFromBanner() }, compact: true) }
                GhostButton(title: t("Open Trash", "Xem Thùng rác"), action: { vm.page = .trash }, compact: true)
                Button { vm.doneInfo = nil } label: { Image(systemName: "xmark").font(.system(size: fs(12), weight: .semibold)) }
                    .buttonStyle(.icon).foregroundColor(Theme.sub).tip(t("Close", "Đóng"), trailing: true)
            }
            .padding(14).background(RoundedRectangle(cornerRadius: 10).fill(Theme.green.opacity(0.12)))
            .padding(.horizontal, 24).padding(.bottom, 10)
        }
    }
}

/// One line after an Undo: what came back. Closed by hand or by the next clean.
struct UndoNote: View {
    @ObservedObject var vm: VM
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.uturn.backward.circle.fill").foregroundColor(Theme.green)
            Text(text).font(.system(size: fs(12))).foregroundColor(Theme.text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button { vm.undoNote = nil } label: { Image(systemName: "xmark").font(.system(size: fs(12), weight: .semibold)) }
                .buttonStyle(.icon).foregroundColor(Theme.sub).tip(t("Close", "Đóng"), trailing: true)
        }
        .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Theme.green.opacity(0.10)))
        .padding(.horizontal, 24).padding(.bottom, 10)
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
                Text(cat.title).font(.system(size: fs(13))).foregroundColor(Theme.text).lineLimit(2).fixedSize(horizontal: false, vertical: true)
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

    /// Chromium code-sign clones in the user's boot-cleaned temp folder (sibling "X" of the "T" temp folder).
    static func browserClones() -> (count: Int, size: Int64) {
        var buf = [CChar](repeating: 0, count: 1024)
        guard confstr(_CS_DARWIN_USER_TEMP_DIR, &buf, buf.count) > 0 else { return (0, 0) }
        let x = URL(fileURLWithPath: String(cString: buf)).deletingLastPathComponent().appendingPathComponent("X")
        var n = 0; var total: Int64 = 0
        for d in Scanner.children(x, hidden: true) where d.lastPathComponent.hasSuffix(".code_sign_clone") {
            let kids = Scanner.children(d, hidden: true)
            n += kids.count
            total += Scanner.size(d)
        }
        return (n, total)
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
                                 note: t("Made by Finder when the phone was plugged in. Keep the newest one of each device you still use. Remove an old device's backup only if you are sure you no longer need what is in it: it may be the only copy. Apple's way: Finder > select the device > Manage Backups.",
                                         "Finder tạo khi cắm điện thoại vào máy. Giữ bản mới nhất của máy còn dùng. Bản của máy cũ chỉ bỏ khi chắc không cần dữ liệu trong đó: có thể đó là bản duy nhất. Cách của Apple: Finder > chọn máy > Quản lý bản sao lưu."),
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
        if let i = item(dir("Developer/CoreSimulator/Caches"), on: false, label: t("Simulator caches", "Bộ nhớ đệm máy ảo")) { xc.append(i) }
        for r in ["iOS DeviceSupport", "watchOS DeviceSupport", "tvOS DeviceSupport", "visionOS DeviceSupport"] {
            xc += Scanner.children(dir("Developer/Xcode/" + r)).compactMap { item($0, on: false, label: r.replacingOccurrences(of: "DeviceSupport", with: "") + $0.lastPathComponent) }
        }
        if !xc.isEmpty {
            clean.append(SysPart(id: "xcode", icon: "hammer", title: t("Xcode leftovers", "Rác của Xcode"),
                                 note: t("Build files rebuild on their own, the next build is slower; quit Xcode first. Device support files are copied again only from a device still on that system version.",
                                         "File build tự tạo lại, lần build sau lâu hơn; đóng Xcode trước. File hỗ trợ thiết bị chỉ được chép lại từ máy còn chạy đúng bản hệ điều hành đó."),
                                 size: xc.reduce(0) { $0 + $1.size }, kind: .clean, items: xc.sorted { $0.size > $1.size }))
        }

        // Archives: never offered here. Apple asks developers to keep the archive of every release (crash reports, re-distribution).
        // Source: research/nguon-chinh-thuc/xcode.md
        let archives = sz(dir("Developer/Xcode/Archives"))
        if archives >= 50_000_000 {
            other.append(SysPart(id: "archives", icon: "archivebox", title: t("Xcode archives", "Bản archive của Xcode"),
                                 note: t("Builds you archived in Xcode. Keep the archive of every version you released: it is needed to read crash reports and to distribute that build again. Remove old ones in Xcode's Organizer.",
                                         "Các bản build đã archive trong Xcode. Giữ archive của mọi bản đã phát hành: cần để đọc báo cáo lỗi và phát hành lại bản đó. Xoá bản cũ trong cửa sổ Organizer của Xcode."),
                                 size: archives, kind: .elsewhere))
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
                                 note: t("Delete old ones in Xcode, or run xcrun simctl delete unavailable, so Xcode keeps track of them. Don't delete the folder by hand.",
                                         "Xoá máy ảo cũ trong Xcode, hoặc chạy lệnh xcrun simctl delete unavailable, để Xcode không bị lẫn. Đừng xoá tay thư mục."),
                                 size: sims, kind: .elsewhere))
        }
        let docker = sz(dir("Containers/com.docker.docker/Data/vms"))
        if docker >= 50_000_000 {
            other.append(SysPart(id: "docker", icon: "shippingbox", title: t("Docker disk", "Ổ ảo của Docker"),
                                 note: t("One big file holding every image and container. Shrink it from Docker Desktop (Troubleshoot > Clean up data, which removes every container and image) or with docker system prune.",
                                         "Một file lớn chứa mọi image, container. Thu nhỏ trong Docker Desktop (Troubleshoot > Clean up data, xoá hết container và image) hoặc lệnh docker system prune."),
                                 size: docker, kind: .elsewhere))
        }
        let msg = sz(dir("Messages/Attachments"))
        if msg >= 50_000_000 {
            other.append(SysPart(id: "messages", icon: "message", title: t("Messages attachments", "Ảnh, file trong Tin nhắn"),
                                 note: t("Photos and files from iMessage chats. Remove them in Messages or in System Settings > General > Storage > Messages, not by deleting the folder. Note: changing Keep messages deletes whole older conversations, not only the files.",
                                         "Ảnh, file trong các cuộc trò chuyện iMessage. Xoá trong app Tin nhắn hoặc Cài đặt hệ thống > Cài đặt chung > Dung lượng > Tin nhắn, đừng xoá tay thư mục. Lưu ý: đổi mục Giữ tin nhắn sẽ xoá cả các cuộc trò chuyện cũ, không chỉ file."),
                                 size: msg, kind: .elsewhere))
        }

        // Things macOS manages itself
        // Chromium browsers clone their app into the per-user folder macOS empties at boot (/private/var/folders/.../X),
        // one clone per launch; clones left by a browser that did not quit cleanly stay until restart.
        // Source: research/nguon-chinh-thuc/chrome-va-web-app.md (Chromium code_sign_clone_manager.mm). Never offered for removal.
        let clones = browserClones()
        if clones.size >= 500_000_000 {
            other.append(SysPart(id: "browserclones", icon: "globe", title: t("Browser temporary copies", "Bản sao tạm của trình duyệt"),
                                 note: t("Chrome, and browsers built on it such as Edge and Brave, put a copy of themselves here when they open, so the browser can check its signature while an update waits to install. A copy can be left behind, for example when the browser is closed abruptly. macOS empties this folder when the Mac restarts. Tidymint leaves it alone: the open browser is still using one copy. The size is an upper limit: the copies share data, so they may take less.",
                                         "Chrome và các trình duyệt cùng lõi như Edge, Brave đặt một bản sao của chính nó ở đây khi mở, để kiểm chữ ký khi có bản cập nhật chờ cài. Bản sao có thể bị sót lại, ví dụ khi trình duyệt bị tắt ngang. macOS tự xoá thư mục này khi khởi động lại máy. Tidymint không đụng tới: trình duyệt đang mở vẫn dùng một bản. Con số là mức tối đa: các bản sao dùng chung dữ liệu nên có thể chiếm ít hơn."),
                                 size: clones.size, kind: .system, detail: t("\(clones.count) copies", "\(clones.count) bản")))
        }
        let snaps = snapshots()
        let tmURL = URL(string: "x-apple.systempreferences:com.apple.Time-Machine-Settings.extension")!
        let last = snaps.compactMap(snapshotDate).max()
        other.append(SysPart(id: "snapshots", icon: "clock.arrow.circlepath", title: t("Time Machine snapshots on this Mac", "Bản sao lưu Time Machine nằm trên máy"),
                             note: snaps.isEmpty
                                ? t("None right now. When automatic Time Machine backups are on, macOS keeps hourly snapshots on this Mac and removes them by itself.",
                                    "Hiện không có. Khi bật sao lưu Time Machine tự động, macOS giữ bản chụp theo giờ trên máy và tự xoá.")
                                : t("Time Machine takes these every hour while automatic backups are on. Hourly ones are kept for 24 hours, a few for longer, and macOS removes them sooner when it needs space. Tidymint leaves them alone: deleting one is permanent and cannot go to the Trash.",
                                    "Time Machine chụp mỗi giờ khi bật sao lưu tự động. Bản theo giờ giữ 24 giờ, vài bản giữ lâu hơn, và macOS xoá sớm hơn khi cần chỗ. Tidymint không xoá phần này: xoá là mất hẳn, không vào Thùng rác được."),
                             size: -1, kind: snaps.isEmpty ? .system : .elsewhere,
                             detail: snaps.isEmpty ? "" : t("\(snaps.count) snapshots", "\(snaps.count) bản") + (last.map { t(", newest ", ", mới nhất ") + shortDate($0) } ?? ""),
                             actionTitle: t("Time Machine Settings", "Mở cài đặt Time Machine"), action: .url(tmURL)))

        var vm: Int64 = 0
        for u in Scanner.children(URL(fileURLWithPath: "/private/var/vm"), hidden: true) {
            vm += Int64((try? u.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize) ?? 0)
        }
        if vm > 0 {
            other.append(SysPart(id: "vm", icon: "memorychip", title: t("Swap and sleep files", "Bộ nhớ ảo và file ngủ"),
                                 note: t("Used when memory runs short and when the Mac sleeps. macOS creates and removes them. Do not delete.",
                                         "Dùng khi thiếu RAM và khi máy ngủ. macOS tự tạo, tự xoá. Không nên xoá."),
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
                        Text(part.title).font(.system(size: fs(13))).foregroundColor(Theme.text)
                        Spacer(minLength: 8)
                        StatusTag(badge.0, badge.1)
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
                        Text(t("size not measured", "chưa đo được dung lượng")).font(.system(size: fs(10))).foregroundColor(Theme.sub)
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
                Text(t("What is in System Data", "System Data gồm những gì")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text)
                Spacer()
                if !vm.sysBusy { TextLink(t("Scan again", "Quét lại"), size: fs(12), weight: .semibold, color: Theme.text) { vm.scanSys() } }
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 6)
            Text(t("System Data is what macOS cannot file under another category: mostly logs, caches and temporary files. Below are the things that most often fill a Mac, including a few macOS lists under other categories (iOS Files, Messages, Developer). The ones with a checkbox can be cleaned here, the rest say where to handle them or to leave them alone.",
                   "Dữ liệu hệ thống là phần macOS không xếp được vào nhóm nào khác: chủ yếu nhật ký, bộ nhớ đệm, file tạm. Dưới đây là những thứ hay làm đầy ổ mà Tidymint đo được, kể cả vài thứ macOS xếp ở nhóm khác (File iOS, Tin nhắn, Nhà phát triển). Phần có ô chọn thì dọn được ở đây, phần còn lại ghi rõ dọn ở đâu hoặc nên để yên."))
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
                                Text(t("About \(fmt(vm.sysPurgeable)) is held by data macOS can free on its own, such as caches. It is released when an update or a big file needs the room.",
                                       "Khoảng \(fmt(vm.sysPurgeable)) đang bị giữ bởi dữ liệu macOS tự giải phóng được, ví dụ bộ nhớ đệm. Khi cài bản cập nhật hay chép file lớn cần chỗ, macOS sẽ tự nhả ra."))
                                    .font(.system(size: fs(12))).foregroundColor(Theme.text).fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }.padding(14).background(RoundedRectangle(cornerRadius: 14).fill(Theme.link.opacity(0.10)))
                        }
                        ForEach($vm.sysParts) { $p in SysPartCard(part: $p, vm: vm, open: open) }
                        Text(t("The rest is data macOS manages itself: logs, caches and temporary files of the system. Tidymint does not touch it.",
                               "Phần còn lại là dữ liệu macOS tự quản: nhật ký, bộ nhớ đệm, file tạm của hệ thống. Tidymint không đụng tới."))
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
                CheckInCard()
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
                    .onAppear { CheckIn.shared.refresh() }   // the card itself is empty while hidden, so it cannot carry onAppear
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
                    if vm.undoable != nil { GhostButton(title: t("Undo", "Hoàn tác")) { vm.undoLast(); if vm.undoable == nil { vm.phase = .idle } } }
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
                    GhostButton(title: t("Scan Again", "Quét lại"), action: { vm.scanJunk() }, compact: true)
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
                Text(t("Cleanup Details", "Dọn rác chi tiết")).font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
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
                                Image(systemName: cat.icon).font(.system(size: fs(15))).foregroundStyle(Theme.accent).frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.title).foregroundColor(Theme.text).font(.system(size: fs(13)))
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
func appInstalled(_ bundleIDs: [String]) -> Bool { bundleIDs.contains { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil } }

/// App icon for a Clean by App rule. The app may be gone while its data stays (e.g. CapCut removed, Movies/CapCut left):
/// then a neutral tile with the app's initial instead of macOS's blank "application" icon, which looks broken.
struct RuleIcon: View {
    let name: String; let bundleIDs: [String]; let side: CGFloat
    var body: some View {
        if appInstalled(bundleIDs) {
            Image(nsImage: appIcon(bundleIDs)).resizable().frame(width: side, height: side)
        } else {
            RoundedRectangle(cornerRadius: side * 0.22).fill(Theme.ink.opacity(0.12))
                .overlay(Text(String(name.prefix(1))).font(.system(size: side * 0.48, weight: .semibold)).foregroundColor(Theme.sub))
                .frame(width: side * 0.86, height: side * 0.86).frame(width: side, height: side)
        }
    }
}

struct AppList: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("Clean by App", "Dọn theo ứng dụng")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text)
                    Text(t("\(vm.appReports.count) apps, \(fmt(vm.appReports.reduce(0) { $0 + $1.cleanable })) can be cleaned.", "\(vm.appReports.count) app, có thể dọn \(fmt(vm.appReports.reduce(0) { $0 + $1.cleanable }))."))
                        .font(.system(size: fs(12))).foregroundColor(Theme.sub)
                }
                Spacer()
                GhostButton(title: t("Scan Again", "Quét lại"), action: { vm.scanByApp() }, compact: true)
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
                                RuleIcon(name: r.rule.name, bundleIDs: r.rule.bundleIDs, side: 40)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(r.rule.name).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .semibold))
                                    Text(r.groups.map { "\($0.section.title) \(fmt($0.total))" }.joined(separator: " · ")).font(.system(size: fs(11))).foregroundColor(Theme.sub).lineLimit(1)
                                }
                                Spacer(minLength: 12)
                                if r.running { StatusTag(t("Open", "Đang mở"), Theme.warn) }
                                else if !appInstalled(r.rule.bundleIDs) { StatusTag(t("App removed", "App đã gỡ"), Theme.sub).tip(t("The app is gone but its data is still here.", "App đã gỡ nhưng dữ liệu vẫn còn.")) }
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(fmt(r.total)).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .semibold).monospacedDigit())
                                    Text(t("\(fmt(r.cleanable)) cleanable", "dọn được \(fmt(r.cleanable))")).font(.system(size: fs(11))).foregroundColor(Theme.sub)
                                }.frame(minWidth: 110 * uiScale, alignment: .trailing)
                                Image(systemName: "chevron.right").foregroundColor(Theme.sub)
                            }
                            .padding(14).background(RoundedRectangle(cornerRadius: 10).fill(Theme.card)).hoverBG(10, Theme.ink.opacity(0.06))
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
        if let ref = vm.monthRef, ref.app == report.id { MonthViewer(vm: vm, report: report, ref: ref) } else { list }
    }
    var list: some View {
        VStack(spacing: 0) {
            HStack {
                Button { vm.closeMonth(); vm.appSel = nil } label: { Label(t("Back", "Quay lại"), systemImage: "chevron.left").padding(.horizontal, 6).padding(.vertical, 3).hoverTile() }.buttonStyle(.plain).foregroundColor(Theme.text)
                Spacer()
                HStack(spacing: 8) {
                    RuleIcon(name: report.rule.name, bundleIDs: report.rule.bundleIDs, side: 22)
                    Text(report.rule.name).font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
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
                                    Text(g.section.title).foregroundColor(Theme.text).font(.system(size: fs(13)))
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
                                        Button { vm.toggleAppRow(report.id, g.id, row.id) } label: { CheckBox(state: row.checkState) }.buttonStyle(.plain)
                                        if let u = row.urls.first, row.month == nil {
                                            Image(nsImage: NSWorkspace.shared.icon(forFile: u.path)).resizable().frame(width: 22, height: 22)
                                        } else { Image(systemName: "calendar").foregroundColor(Theme.sub).frame(width: 22) }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(row.title).foregroundColor(Theme.text).font(.system(size: fs(13))).lineLimit(1)
                                            RowSubLine(row: row)
                                        }
                                        Spacer()
                                        Text(fmt(row.size)).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .medium).monospacedDigit()).frame(width: 80, alignment: .trailing)
                                        if row.month != nil { Image(systemName: "chevron.right").foregroundColor(Theme.sub).font(.system(size: fs(12))) }
                                    }
                                    .padding(.vertical, 6).padding(.horizontal, 12).hoverBG(8, Theme.ink.opacity(0.07)).contentShape(Rectangle())
                                    // A month opens the month viewer; a single file or folder: click = Quick Look,
                                    // double-click = open in its default app, Space over it = Quick Look (like Finder).
                                    .onTapGesture(count: 2) { if row.month == nil, let u = row.urls.first { vm.fileQL = nil; vm.openFile(u) } }
                                    .onTapGesture { if row.month != nil { vm.openMonth(report.id, g.id, row.id) } else if let u = row.urls.first { vm.fileQL = u } }
                                    .onHover { inside in
                                        guard row.month == nil, let u = row.urls.first else { return }
                                        if inside { vm.hoverFile = u } else if vm.hoverFile == u { vm.hoverFile = nil }
                                    }
                                    .contextMenu {
                                        if row.month != nil {
                                            Button(t("View files", "Xem các file")) { vm.openMonth(report.id, g.id, row.id) }
                                            if let u = row.urls.first { Button(t("Show in Finder", "Hiện trong Finder")) { vm.reveal(u) } }
                                        } else if let u = row.urls.first { FileMenu(url: u, vm: vm) }
                                    }
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


// MARK: - Month viewer (Clean by app)

struct MonthRef: Equatable { let app: String, group: String, row: String }
/// One file inside a by-month row.
struct MonthItem: Identifiable {
    let url: URL; let size: Int64; let date: Date; let kind: FileKind
    /// Other copies of the same photo (Zalo keeps _t thumbnail, _n, _h and a .jxl of each); ticked and cleaned together.
    var variants: [URL] = []
    /// Telegram keeps animated stickers as gzip files named telegram-cloud-document-…, set once when the month opens.
    var tgSticker = false
    var id: String { url.path }
    var allPaths: [String] { [url.path] + variants.map(\.path) }
    var count: Int { 1 + variants.count }
    /// Zalo photo names: <13-digit time>_<id>_<g or not><id>_ then n, h, t, or a 32-hex hash with .jxl.
    /// Only this exact shape is grouped, so ordinary names like IMG_2024_01_05.jpg are never merged.
    static let zaloVariant = try! NSRegularExpression(pattern: "^(\\d{13}_\\d+_g?\\d+)_(n|h|t|[0-9a-f]{32}\\.jxl)$")
    /// Telegram: a file, its "_partial" twin while it downloads, and "_partial.meta" are one item.
    static let telegramVariant = try! NSRegularExpression(pattern: "^(telegram-.+?)(_partial(\\.meta)?)?$")
    static func isTelegramSticker(_ u: URL) -> Bool {
        guard u.lastPathComponent.hasPrefix("telegram-cloud-document"), FileKind.of(u) == .other,
              let h = try? FileHandle(forReadingFrom: u) else { return false }
        defer { try? h.close() }
        guard let d = try? h.read(upToCount: 2), d.count == 2 else { return false }
        return d[d.startIndex] == 0x1F && d[d.startIndex + 1] == 0x8B   // gzip = Lottie sticker (.tgs)
    }
    static func variantKey(_ u: URL) -> String? {
        let n = u.lastPathComponent
        if n.hasPrefix("telegram-"), let m = telegramVariant.firstMatch(in: n, range: NSRange(n.startIndex..., in: n)),
           let r = Range(m.range(at: 1), in: n) { return String(n[r]) }
        guard let m = zaloVariant.firstMatch(in: n, range: NSRange(n.startIndex..., in: n)), let r = Range(m.range(at: 1), in: n) else { return nil }
        return String(n[r])   // copies sit in different folders (Cache/ and picture/), the name alone is unique
    }
    /// Extensions that mark an app's own index files (Zalo's .rescache), never shown as photos.
    static let companionExt: Set<String> = ["rescache", "ds_store"]
    /// Zalo names them just ".rescache" (a hidden file with no extension), one per chat folder.
    static func isCompanion(_ u: URL) -> Bool {
        let n = u.lastPathComponent.lowercased()
        if n.hasPrefix("telegram-") && n.hasSuffix(".meta") { return true }   // Telegram's download bookkeeping
        return companionExt.contains { n == "." + $0 || n.hasSuffix("." + $0) }
    }
    var isVideo: Bool { kind == .video }
    var isMedia: Bool { kind != .other }
    var showsInGrid: Bool { isMedia || badge != nil }
    /// Files with no picture to show get a plain label instead of a blank page icon.
    var badge: (en: String, vi: String, icon: String)? {
        let n = url.lastPathComponent
        if tgSticker || n.contains("animated-sticker") || n.hasSuffix(".tgs") { return ("Animated sticker", "Sticker động", "face.smiling") }
        if !isMedia && n.contains(":sticker") { return ("Sticker", "Sticker", "face.smiling") }
        if !isMedia && n.hasSuffix("_partial") { return ("Partial download", "Tải dở", "arrow.down.circle") }
        return nil
    }
    /// Days 1-7 are week 0, 8-14 week 1, and so on (29-31 is week 4).
    var week: Int { (Calendar.current.component(.day, from: date) - 1) / 7 }
    /// Quick Look picks the viewer from the extension, so a photo or video saved without one is shown through a link that has one.
    var previewURL: URL { url.pathExtension.isEmpty && isMedia ? PreviewLinks.link(url, ext: kind == .video ? "mp4" : (kind == .pdf ? "pdf" : "jpg")) : url }
}

/// Drag-to-select in the month viewer: the box being drawn, whether it ticks or unticks, the ticks before it started,
/// and where each visible file sits (not published, it changes on every scroll).
final class SelectBox: ObservableObject {
    @Published var band: CGRect? = nil
    var on = true
    var base = Set<String>()
    var frames: [String: CGRect] = [:]
}

/// Frames of the month viewer's visible cells, for drag-to-select.
struct CellFrames: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) { value.merge(nextValue()) { $1 } }
}

/// Quick Look ignores symbolic links, so an extensionless photo is shown through a hard link with a proper extension,
/// in Tidymint's own temporary folder. A hard link is a second name for the same file: removing it never removes the photo,
/// and it takes no extra space. The links go when the month viewer closes (and at launch, in case the app quit early),
/// so a photo moved to the Trash afterwards really frees its space when the Trash is emptied.
enum PreviewLinks {
    static let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tidymint-preview", isDirectory: true)
    static var made: [String: URL] = [:]
    static var failed = Set<String>()   // not retried on every redraw
    static func link(_ u: URL, ext: String) -> URL {
        if let l = made[u.path] { return l }
        if failed.contains(u.path) { return u }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let l = dir.appendingPathComponent("\(made.count + 1)-\(u.lastPathComponent).\(ext)")
        guard (try? FileManager.default.linkItem(at: u, to: l)) != nil else { failed.insert(u.path); return u }
        made[u.path] = l; return l
    }
    /// Removes only names inside Tidymint's own preview folder.
    static func clear() {
        for l in made.values where l.deletingLastPathComponent().standardizedFileURL == dir.standardizedFileURL { try? FileManager.default.removeItem(at: l) }
        made = [:]; failed = []
        if let left = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for l in left { try? FileManager.default.removeItem(at: l) }
        }
    }
}

/// The grey line under a Clean by App row; mint when files were picked one by one in the month viewer.
struct RowSubLine: View {
    let row: AppRow
    var body: some View {
        let c: Color = row.checkState == 1 ? Theme.accentSolid : Theme.sub
        return Text(row.subLine).foregroundColor(c).font(.system(size: fs(11))).lineLimit(1).truncationMode(.middle)
    }
}

/// Key presses for one page (Space = Quick Look, Esc = back). Local monitor, removed when the page goes away.
final class KeyTap: ObservableObject {
    private var mon: Any?
    func start(_ handle: @escaping (NSEvent) -> Bool) {
        stop(); mon = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { handle($0) ? nil : $0 }
    }
    func stop() { if let m = mon { NSEvent.removeMonitor(m) }; mon = nil }
    deinit { stop() }
}

/// The files of one month, split by week, as a grid of thumbnails. Click ticks a file, a week header ticks the week;
/// double-click or Space shows the file large (Quick Look). Ticks go back to the month row in the list.
struct MonthViewer: View {
    @ObservedObject var vm: VM
    let report: AppReport
    let ref: MonthRef
    @StateObject private var keys = KeyTap()
    @StateObject private var box = SelectBox()
    var group: AppGroup? { report.groups.first { $0.id == ref.group } }
    var row: AppRow? { group?.rows.first { $0.id == ref.row } }
    /// Photos, videos and labelled items go in the week grid; files with nothing to show go in a separate list at the end.
    var weeks: [(Int, [MonthItem])] { Dictionary(grouping: vm.monthItems.filter(\.showsInGrid), by: \.week).sorted { $0.key > $1.key } }
    var others: [MonthItem] { vm.monthItems.filter { !$0.showsInGrid } }
    func weekLabel(_ w: Int) -> String {
        guard let m = row?.month else { return "" }
        let c = Calendar.current
        let last = c.range(of: .day, in: .month, for: m)?.count ?? 30
        let from = w * 7 + 1, to = min(w * 7 + 7, last), mo = c.component(.month, from: m)
        if appLang == "vi" { return "Tuần \(w + 1) · \(from)–\(to)/\(mo)" }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "MMM"
        return "Week \(w + 1) · \(f.string(from: m)) \(from)–\(to)"
    }
    func state(_ ids: [String]) -> Int {
        let n = ids.filter { vm.monthPick.contains($0) }.count
        return n == 0 ? 0 : (n == ids.count ? 2 : 1)
    }
    var pickSize: Int64 { vm.monthItems.filter { vm.monthPick.contains($0.id) }.reduce(0) { $0 + $1.size } }
    var body: some View {
        let all = vm.monthItems.map(\.id)
        VStack(spacing: 0) {
            HStack {
                Button { vm.closeMonth() } label: { Label(t("Back", "Quay lại"), systemImage: "chevron.left").padding(.horizontal, 6).padding(.vertical, 3).hoverTile() }.buttonStyle(.plain).foregroundColor(Theme.text)
                Spacer()
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        RuleIcon(name: report.rule.name, bundleIDs: report.rule.bundleIDs, side: 20)
                        Text("\(report.rule.name) · \(group?.section.title ?? "") · \(row?.title ?? "")").font(.system(size: fs(15), weight: .semibold)).foregroundColor(Theme.text).lineLimit(1)
                    }
                    Text(t("\(vm.monthItems.count) files · \(fmt(vm.monthItems.reduce(0) { $0 + $1.size }))", "\(vm.monthItems.count) file · \(fmt(vm.monthItems.reduce(0) { $0 + $1.size }))"))
                        .font(.system(size: fs(12)).monospacedDigit()).foregroundColor(Theme.sub)
                }
                Spacer()
                Button { vm.setMonthPick(all, on: state(all) != 2) } label: {
                    HStack(spacing: 6) { CheckBox(state: state(all)); Text(t("Select all", "Chọn tất cả")).foregroundColor(Theme.text).font(.system(size: fs(13))) }
                        .padding(.horizontal, 6).padding(.vertical, 3).hoverTile()
                }.buttonStyle(.plain).disabled(all.isEmpty)
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 6)
            Text(t("Click to tick, drag a box to tick many, Shift-click for a range. Double-click or Space to see a file large.", "Bấm để tick, kéo chuột quét vùng để tick nhiều, giữ Shift để chọn một dải. Bấm đúp hoặc phím cách để xem to."))
                .font(.system(size: fs(11))).foregroundColor(Theme.sub).padding(.bottom, 10)
            if vm.monthLoading {
                Scanning(text: t("Reading files...", "Đang đọc file...")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(weeks, id: \.0) { w, items in
                            let ids = items.map(\.id)
                            let folded = vm.monthCollapsed.contains(w)
                            HStack(spacing: 10) {
                                Button { vm.setMonthPick(ids, on: state(ids) != 2) } label: { CheckBox(state: state(ids)) }.buttonStyle(.plain)
                                Button {
                                    withAnimation(.easeOut(duration: 0.15)) { if folded { vm.monthCollapsed.remove(w) } else { vm.monthCollapsed.insert(w) } }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "chevron.down").rotationEffect(.degrees(folded ? -90 : 0)).foregroundColor(Theme.sub).font(.system(size: fs(11), weight: .semibold))
                                        Text(weekLabel(w)).font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain).tip(folded ? t("Show this week", "Mở tuần này") : t("Fold this week", "Thu gọn tuần này"))
                                Spacer()
                                Text(t("\(items.count) files · \(fmt(items.reduce(0) { $0 + $1.size }))", "\(items.count) file · \(fmt(items.reduce(0) { $0 + $1.size }))"))
                                    .font(.system(size: fs(12)).monospacedDigit()).foregroundColor(Theme.sub)
                            }.padding(.top, 4)
                            if !folded {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120 * max(uiScale, 1), maximum: 170 * max(uiScale, 1)), spacing: 10)], spacing: 12) {
                                ForEach(items) { it in
                                    MonthCell(item: it, focused: vm.monthFocus == it.id, picked: vm.monthPick.contains(it.id))
                                        .background(GeometryReader { g in Color.clear.preference(key: CellFrames.self, value: [it.id: g.frame(in: .named("monthgrid"))]) })
                                        .onTapGesture(count: 2) { vm.previewMonth(it.id) }
                                        .onTapGesture { vm.clickMonth(it.id, shift: NSEvent.modifierFlags.contains(.shift)) }
                                        .contextMenu {
                                            Button(t("Show large", "Xem to")) { vm.previewMonth(it.id) }
                                            FileMenu(url: it.url, vm: vm, quickLook: false)
                                        }
                                }
                            }
                            }
                        }
                        if !others.isEmpty {
                            let ids = others.map(\.id)
                            let open = vm.monthCollapsed.contains(99)   // folded until asked: these have no picture to judge by
                            HStack(spacing: 10) {
                                Button { vm.setMonthPick(ids, on: state(ids) != 2) } label: { CheckBox(state: state(ids)) }.buttonStyle(.plain)
                                Button {
                                    withAnimation(.easeOut(duration: 0.15)) { if open { vm.monthCollapsed.remove(99) } else { vm.monthCollapsed.insert(99) } }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "chevron.down").rotationEffect(.degrees(open ? 0 : -90)).foregroundColor(Theme.sub).font(.system(size: fs(11), weight: .semibold))
                                        Text(t("Other files, no preview", "File khác, không xem trước được")).font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                Spacer()
                                Text(t("\(others.count) files · \(fmt(others.reduce(0) { $0 + $1.size }))", "\(others.count) file · \(fmt(others.reduce(0) { $0 + $1.size }))"))
                                    .font(.system(size: fs(12)).monospacedDigit()).foregroundColor(Theme.sub)
                            }.padding(.top, 8)
                            if open {
                                ForEach(others) { it in
                                    HStack(spacing: 10) {
                                        CheckBox(state: vm.monthPick.contains(it.id) ? 2 : 0)
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: it.url.path)).resizable().frame(width: 20, height: 20)
                                        Text(it.url.lastPathComponent).font(.system(size: fs(12))).foregroundColor(Theme.text).lineLimit(1).truncationMode(.middle)
                                        Spacer()
                                        Text("\(MonthCell.df.string(from: it.date)) · \(fmt(it.size))").font(.system(size: fs(11)).monospacedDigit()).foregroundColor(Theme.sub)
                                    }
                                    .padding(.vertical, 4).padding(.horizontal, 8).hoverBG(6, Theme.ink.opacity(0.06)).contentShape(Rectangle())
                                    .onTapGesture { vm.clickMonth(it.id, shift: NSEvent.modifierFlags.contains(.shift)) }
                                    .contextMenu {
                                        Button(t("Show large", "Xem to")) { vm.previewMonth(it.id) }
                                        FileMenu(url: it.url, vm: vm, quickLook: false)
                                    }
                                }
                            }
                        }
                        if !vm.monthExtras.isEmpty {
                            Text(t("Also in this month: \(vm.monthExtras.count) index files of \(report.rule.name) (\(fmt(vm.monthExtrasSize))), not photos or videos. They go only when the whole month is ticked.",
                                   "Trong tháng còn \(vm.monthExtras.count) tệp chỉ mục của \(report.rule.name) (\(fmt(vm.monthExtrasSize))), không phải ảnh hay video. Chỉ dọn khi tick cả tháng."))
                                .font(.system(size: fs(11))).foregroundColor(Theme.sub).padding(.top, 6)
                        }
                    }.padding(.horizontal, 24).padding(.bottom, 16)
                    .coordinateSpace(name: "monthgrid")
                    .onPreferenceChange(CellFrames.self) { box.frames = $0 }
                    .overlay(alignment: .topLeading) {
                        if let r = box.band {
                            Rectangle().fill(Theme.accentSolid.opacity(0.12))
                                .overlay(Rectangle().stroke(Theme.accentSolid.opacity(0.8), lineWidth: 1))
                                .frame(width: r.width, height: r.height).offset(x: r.minX, y: r.minY).allowsHitTesting(false)
                        }
                    }
                    .gesture(DragGesture(minimumDistance: 8, coordinateSpace: .named("monthgrid"))
                        .onChanged { d in
                            if box.band == nil {
                                // Starting on a ticked file unticks what the box covers; anywhere else ticks it.
                                let start = box.frames.first { $0.value.contains(d.startLocation) }?.key
                                box.on = !(start.map { vm.monthPick.contains($0) } ?? false)
                                box.base = vm.monthPick
                            }
                            let r = CGRect(x: min(d.startLocation.x, d.location.x), y: min(d.startLocation.y, d.location.y),
                                           width: abs(d.location.x - d.startLocation.x), height: abs(d.location.y - d.startLocation.y))
                            box.band = r
                            let hit = Set(box.frames.filter { $0.value.intersects(r) }.map(\.key))
                            let target = box.on ? box.base.union(hit) : box.base.subtracting(hit)
                            let add = target.subtracting(vm.monthPick), drop = vm.monthPick.subtracting(target)
                            if !add.isEmpty { vm.setMonthPick(Array(add), on: true) }
                            if !drop.isEmpty { vm.setMonthPick(Array(drop), on: false) }
                        }
                        .onEnded { _ in box.band = nil })
                }
            }
            HStack {
                Text(vm.monthPick.isEmpty ? t("Nothing ticked", "Chưa tick gì")
                     : t("\(vm.monthPick.count) ticked · \(fmt(pickSize))", "Đã tick \(vm.monthPick.count) · \(fmt(pickSize))"))
                    .foregroundColor(Theme.text).font(.system(size: fs(13), weight: .medium).monospacedDigit())
                Spacer()
                Text(t("Ticked files are cleaned with the rest when you press Move to Trash.", "File đã tick được dọn cùng khi bấm Chuyển vào Thùng rác."))
                    .foregroundColor(Theme.sub).font(.system(size: fs(11)))
                GhostButton(title: t("Done", "Xong"), action: { vm.closeMonth() })
            }.padding(.horizontal, 24).padding(.vertical, 14).background(Theme.ink.opacity(0.03))
        }
        .quickLookPreview(Binding(get: { vm.qlURL }, set: { vm.qlURL = $0 }), in: vm.qlURL == nil ? [] : vm.monthItems.map(\.previewURL))
        .onAppear {
            keys.start { e in
                MainActor.assumeIsolated {
                    guard vm.monthRef != nil, vm.qlURL == nil else { return false }
                    switch e.keyCode {
                    case 49: vm.previewMonth(); return true      // Space
                    case 53: vm.closeMonth(); return true        // Esc
                    default: return false
                    }
                }
            }
        }
        .onDisappear {
            keys.stop()
            // Window closed or page left with a month open: drop the preview links, or they keep the space of
            // trashed photos allocated until the next launch.
            if vm.monthRef != nil { vm.closeMonth() }
        }
    }
}

struct MonthCell: View {
    let item: MonthItem; let focused: Bool; let picked: Bool
    static let df: DateFormatter = { let f = DateFormatter(); f.dateFormat = "dd/MM HH:mm"; return f }()
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8).fill(Theme.ink.opacity(0.06))
                if let b = item.badge {
                    VStack(spacing: 6) {
                        Image(systemName: b.icon).font(.system(size: 30)).foregroundColor(Theme.sub)
                        Text(t(b.en, b.vi)).font(.system(size: fs(12), weight: .medium)).foregroundColor(Theme.sub)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    GridThumb(url: item.url, side: 170)
                }
                if item.isVideo {
                    Image(systemName: "play.circle.fill").font(.system(size: 28)).foregroundStyle(.white, .black.opacity(0.45))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Image(systemName: picked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(picked ? AnyShapeStyle(Theme.accentSolid) : AnyShapeStyle(Color.white.opacity(0.9)))
                    .background(Circle().fill(Color.black.opacity(picked ? 0 : 0.35)).padding(2))
                    .padding(6)
            }
            .frame(height: 120 * max(uiScale, 1)).clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(picked ? Theme.accentSolid : Theme.sub.opacity(0.6), lineWidth: picked ? 2.5 : (focused ? 1.5 : 0)))
            Text(item.isMedia || item.badge != nil ? "\(MonthCell.df.string(from: item.date)) · \(fmt(item.size))" : item.url.lastPathComponent)
                .font(.system(size: fs(11)).monospacedDigit())
                .foregroundColor(Theme.sub).lineLimit(1).truncationMode(.middle)
        }.contentShape(Rectangle())
    }
}

/// A thumbnail that fills its cell; falls back to the centred Finder icon until (or unless) Quick Look has one.
struct GridThumb: View {
    let url: URL; let side: CGFloat
    @StateObject private var store = ThumbStore()
    var body: some View {
        GeometryReader { g in
            if let img = store.image {
                if store.real {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill).frame(width: g.size.width, height: g.size.height).clipped()
                } else {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fit).frame(width: 56, height: 56).position(x: g.size.width / 2, y: g.size.height / 2)
                }
            }
        }
        .onAppear { store.load(url, side: side) }
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
                    Header(title: t("Large & Old Files", "File lớn và cũ"), sub: t("Files over 100 MB in your folders and the drives added in Settings.\nNothing is ticked; you choose.", "File trên 100 MB trong các thư mục của bạn và ổ đã thêm ở Cài đặt.\nKhông tick sẵn, bạn tự chọn."))
                    BigScanButton(label: t("Scan", "Quét")) { vm.scanLarge() }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            case .scanning:
                Scanning(text: t("Looking for large files...", "Đang tìm file lớn...")).frame(maxWidth: .infinity, maxHeight: .infinity)
            default:
                HStack {
                    Text(t("Large Files (\(vm.large.count))", "File lớn (\(vm.large.count))")).font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                    Spacer()
                    Picker("", selection: $sortByDate.v) { Text(t("By Size", "Theo dung lượng")).tag(false); Text(t("Oldest Opened", "Lâu không mở")).tag(true) }
                        .pickerStyle(.segmented).controlSize(.small).fixedSize()
                    Button { vm.scanLarge() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.icon).tip(t("Scan again", "Quét lại"), trailing: true).foregroundColor(Theme.text).padding(.leading, 8)
                }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 14)
                DoneBanner(vm: vm, page: .large)
                if vm.large.isEmpty {
                    Text(t("No files over 100 MB.", "Không có file nào trên 100 MB.")).foregroundColor(Theme.sub).frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            let index = Dictionary(uniqueKeysWithValues: vm.large.enumerated().map { ($1.id, $0) })
                            ForEach(sortedIDs(), id: \.self) { id in
                                if let i = index[id] {
                                    ItemRow(item: $vm.large[i], vm: vm, showDate: true)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                                }
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
    /// Rows keyed by item id, so a row never shows another file's thumbnail after items are removed.
    func sortedIDs() -> [UUID] {
        let l = vm.large
        if sortByDate.v { return l.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }.map(\.id) }
        return l.sorted { $0.size > $1.size }.map(\.id)
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
                                    // Folder: click goes into it. File: click = Quick Look, double-click = open. Space = Quick Look.
                                    .onTapGesture(count: 2) { if !n.isDir && n.otherCount == 0 { vm.fileQL = nil; vm.openFile(n.url) } }
                                    .onTapGesture { if n.isDir { vm.openLens(n.url) } else if n.otherCount == 0 { vm.fileQL = n.url } }
                                    .onHover { h in
                                        vm.hoverNode = h ? n.id : nil
                                        if n.otherCount == 0 { if h { vm.hoverFile = n.url } else if vm.hoverFile == n.url { vm.hoverFile = nil } }
                                    }
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
        if n.isDir {
            Button(t("Open in Space Lens", "Xem trong Bản đồ ổ đĩa")) { vm.openLens(n.url) }
            FileMenu(url: n.url, vm: vm, openWith: false)
        } else {
            FileMenu(url: n.url, vm: vm)
        }
        if Scanner.blocked(n.url.path) {
            Text(t("Protected: cannot be removed here", "Được bảo vệ: không xoá từ đây được"))
        } else {
            Button(t("Move to Trash...", "Chuyển vào Thùng rác...")) { DispatchQueue.main.async { vm.trashNode(n) } }
        }
        Button(t("Ignore", "Bỏ qua")) { let u = n.url; DispatchQueue.main.async { vm.ignore(u) } }
    }
}

/// " (CapCut)" for an uninstall, " (Clean Now)" and so on for the other pages; empty when unknown.
func sessionName(_ s: Journal.Session) -> String {
    let names = ["cleanup": Page.smart.label, "large": Page.large.label, "lens": Page.lens.label, "sysdata": "System Data", "startup": Page.startup.label]
    var n = names[s.label] ?? s.label
    if s.label.hasPrefix("app:") {   // Clean by App: "app:zalo" reads "Zalo"
        let id = String(s.label.dropFirst(4))
        n = AppRules.all.first { $0.id == id }?.name ?? id
    }
    return n.isEmpty ? "" : " (\(n))"
}

struct TrashView: View {
    @ObservedObject var vm: VM
    var body: some View {
        // Same layout language as Settings (style guide 1f): page title, rounded blocks, notes under each block.
        ScrollView { VStack(alignment: .leading, spacing: 14) {
            Text(t("Trash", "Thùng rác")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text).padding(.top, 34)
            VStack(alignment: .leading, spacing: 6) {
                SettingsBox {
                    HStack(spacing: 14) {
                        Image(systemName: vm.trashCount == 0 ? "trash" : "trash.fill").font(.system(size: fs(26))).foregroundStyle(Theme.accent).frame(width: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fmt(vm.trashSize)).font(.system(size: fs(20), weight: .bold).monospacedDigit()).foregroundColor(Theme.text)
                            Text(vm.trashCount == 0 ? t("The Trash is empty.", "Thùng rác trống.") : t("\(vm.trashCount) items in the Trash", "\(vm.trashCount) mục trong Thùng rác"))
                                .font(.system(size: fs(11))).foregroundColor(Theme.sub)
                            ForEach(vm.trashOnDrives, id: \.0) { d in
                                Label(t("\(d.1) items, \(fmt(d.2)) on \(d.0)", "\(d.1) mục, \(fmt(d.2)) trên ổ \(d.0)"), systemImage: "externaldrive")
                                    .font(.system(size: fs(11))).foregroundColor(Theme.sub)
                            }
                        }
                        Spacer(minLength: 12)
                        GhostButton(title: t("Show in Finder", "Mở trong Finder"), action: { NSWorkspace.shared.open(Scanner.trashURL) }, compact: true)
                        PrimaryButton(title: t("Empty Trash", "Đổ Thùng rác"), action: { vm.emptyTrash() }, disabled: vm.trashCount == 0, compact: true)
                    }.settingFlat()
                }
                if let n = vm.trashLeftNote, vm.trashCount > 0 {
                    Label(n, systemImage: "exclamationmark.triangle.fill").font(.system(size: fs(11), weight: .medium)).foregroundColor(Theme.warn)
                        .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 14)
                }
                SettingNote(t("Emptying cannot be undone. Take a quick look first.", "Đổ rồi thì không lấy lại được. Liếc qua một lượt trước đã."))
            }
            if let n = vm.undoNote {
                Label(n.text, systemImage: "arrow.uturn.backward.circle.fill").font(.system(size: fs(12))).foregroundColor(Theme.green).padding(.horizontal, 14)
            }
            if let s = vm.undoable {
                Text(t("Last clean", "Lần dọn vừa rồi")).font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text).padding(.top, 6).padding(.leading, 4)
                VStack(alignment: .leading, spacing: 6) {
                    SettingsBox {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t("\(s.entries.count) items, \(fmt(s.size))", "\(s.entries.count) mục, \(fmt(s.size))") + sessionName(s))
                                    .font(.system(size: fs(13))).foregroundColor(Theme.text)
                                Text(ago(s.date)).font(.system(size: fs(11))).foregroundColor(Theme.sub)
                            }
                            Spacer(minLength: 12)
                            GhostButton(title: t("Undo", "Hoàn tác"), action: { vm.undoLast() }, compact: true)
                        }.settingFlat()
                    }
                    SettingNote(t("Undo puts back only these items. The Trash total above also counts what was there before.", "Hoàn tác chỉ trả về đúng các mục này. Con số Thùng rác ở trên tính cả những thứ đã có từ trước."))
                }
            }
        }.frame(maxWidth: 760 * uiScale, alignment: .leading).padding(.horizontal, 24).padding(.bottom, 24).frame(maxWidth: .infinity) }
        .onAppear { vm.refreshTrash() }
    }
}

struct IgnoreView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Ignore List", "Danh sách bỏ qua")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text)
                    Text(t("Items here never show up in scans. Add files or folders here, or right-click an item in a scan list.", "Mục ở đây không bao giờ hiện trong kết quả quét. Thêm file, thư mục ở đây, hoặc chuột phải vào một mục trong danh sách quét."))
                        .foregroundColor(Theme.sub).font(.system(size: fs(12)))
                }
                Spacer(minLength: 16)
                GhostButton(title: t("Add…", "Thêm…"), action: { vm.addIgnoredByPicker() }, compact: true)
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

/// Gives the VM the NSWindow that hosts the main view, so window limits can be set on it directly.
struct WindowGrabber: NSViewRepresentable {
    let vm: VM
    final class V: NSView {
        var onWindow: ((NSWindow) -> Void)?
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); if let w = window { onWindow?(w) } }
    }
    func makeNSView(context: Context) -> V {
        let v = V(); v.onWindow = { w in MainActor.assumeIsolated { vm.mainWindow = w; vm.applyWindowLimits() } }; return v
    }
    func updateNSView(_ v: V, context: Context) {}
}

struct RootView: View {
    @ObservedObject var vm: VM
    @StateObject private var keys = KeyTap()
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
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.bg)
        .frame(minWidth: 980 * uiScale, minHeight: 600)
        .background(WindowGrabber(vm: vm))
        .id(vm.theme + vm.textSize)
        .preferredColorScheme(Theme.p.light ? .light : .dark)
        .ignoresSafeArea()
        .quickLookPreview(Binding(get: { vm.fileQL }, set: { vm.fileQL = $0 }))
        .onAppear {
            vm.checkUpdates(); vm.windowShown()
            // Space over a file row shows it (Quick Look), Space again closes it, like Finder.
            // Not while typing in a field, and not in the month viewer (it has its own Space).
            keys.start { e in
                MainActor.assumeIsolated {
                    guard e.keyCode == 49, e.modifierFlags.intersection([.command, .option, .control]).isEmpty,
                          vm.monthRef == nil, !(NSApp.keyWindow?.firstResponder is NSTextView) else { return false }
                    if vm.fileQL != nil { vm.fileQL = nil; return true }
                    if let h = vm.hoverFile { vm.fileQL = h; return true }
                    return false
                }
            }
        }
        .onDisappear { vm.windowGone(); keys.stop() }
    }
}

/// Update check: when the window opens, at most once a day, asks update.tidymint.app (backup: tidymint.app, then GitHub)
/// for the latest version number and shows a line if it is newer. No auto-install. Off in Settings: no automatic check.
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
        // Plain text first: update.tidymint.app (counts the check per day, app version and macOS from the standard
        // User-Agent, nothing else is sent and no IP is kept; code in app/dev/worker-update), then the copy on the website,
        // then GitHub's API. Each is tried only if the one before gave no version.
        func plain(_ urls: [URL], _ fallback: @escaping () -> Void) {
            guard let u = urls.first else { fallback(); return }
            var req = URLRequest(url: u); req.timeoutInterval = 6; req.cachePolicy = .reloadIgnoringLocalCacheData
            URLSession.shared.dataTask(with: req) { data, resp, _ in
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if code == 200, let d = data, let v = String(data: d, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   v.range(of: #"^v?\d+(\.\d+){1,3}$"#, options: .regularExpression) != nil {   // a Wi-Fi login page also answers 200
                    DispatchQueue.main.async { record(v, done) }; return
                }
                plain(Array(urls.dropFirst()), fallback)
            }.resume()
        }
        let isDev = Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true   // the Dev build is not counted
        plain(isDev ? [site] : [counter, site]) {
            var r2 = URLRequest(url: api); r2.timeoutInterval = 8
            r2.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            URLSession.shared.dataTask(with: r2) { data, _, _ in
                var tag: String? = nil
                if let d = data, let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let tg = j["tag_name"] as? String { tag = tg }
                DispatchQueue.main.async { if let tg = tag { record(tg, done) } else { done(nil) } }
            }.resume()
        }
    }
    static let counter = URL(string: "https://update.tidymint.app/version")!
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
                                HStack(spacing: 6) {
                                    if let d = a.lastUsed {
                                        Text(t("Last opened ", "Mở lần cuối ") + shortDate(d)).foregroundColor(Theme.sub).font(.system(size: fs(10))).lineLimit(1)
                                    } else {
                                        Text(t("Never opened", "Chưa mở lần nào")).foregroundColor(Theme.sub).font(.system(size: fs(10))).lineLimit(1)
                                    }
                                }
                            }
                            Spacer(minLength: 8)
                            if let b = a.webAppBrowser { WebAppTag(browser: b) }
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
                        PrimaryButton(title: t("Uninstall", "Gỡ app"), action: { vm.uninstall(vm.apps[i].id) }).disabled(vm.appsBusy || vm.relatedLoading == vm.apps[i].id)
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
                    Text(t("Duplicates", "File trùng")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text)
                    Text(t("Identical files (same content, any name) over 1 MB in Documents, Downloads, Desktop, Pictures, Movies, Music, plus drives and folders added in Settings.",
                           "File giống hệt nhau về nội dung (dù khác tên), trên 1 MB, trong Documents, Downloads, Desktop, Pictures, Movies, Music, cùng ổ và thư mục thêm ở Cài đặt."))
                        .font(.system(size: fs(12))).foregroundColor(Theme.sub)
                }
                Spacer()
                Menu(t("Select", "Chọn")) {
                    Button(t("Select all duplicates (keep one)", "Chọn mọi bản trùng (giữ 1 bản)")) { vm.dupAutoSelect(all: true) }
                    Button(t("Deselect all", "Bỏ chọn tất cả")) { vm.dupAutoSelect(all: false) }
                    if vm.dupes.contains(where: \.isCross) {
                        Divider()
                        Button(t("Copies on the Mac and a drive: keep the drive copy", "Bản trùng giữa máy và ổ ngoài: giữ bản trên ổ ngoài")) { vm.dupApplyCross("external") }
                        Button(t("Copies on the Mac and a drive: keep the Mac copy", "Bản trùng giữa máy và ổ ngoài: giữ bản trên máy")) { vm.dupApplyCross("mac") }
                    }
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
                                        Text(t("\(g.items.count) copies × \(fmt(g.size))", "\(g.items.count) bản × \(fmt(g.size))") + (g.isCross ? t(" · on this Mac and an external drive", " · trên máy và ổ cứng rời") : ""))
                                            .foregroundColor(Theme.sub).font(.system(size: fs(11)))
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
                                        ItemRow(item: $it, vm: vm, showDate: true, keep: idx == 0, keepColumn: true)
                                    }.padding(.leading, 14)
                                }
                            }.background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
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
                    Text(t("Cloud Cleanup", "Dữ liệu đám mây")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text)
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
                                    .font(.system(size: fs(15))).foregroundStyle(Theme.accent).frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).foregroundColor(Theme.text).font(.system(size: fs(13)))
                                    if !p.account.isEmpty { Text(p.account).foregroundColor(Theme.sub).font(.system(size: fs(11))) }
                                }
                                Spacer()
                                Text(t("on this Mac: ", "trên máy: ")).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                                Text(fmt(p.local)).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .medium).monospacedDigit())
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
/// A Settings group: a header card (title, one-line summary of what is inside, optional badge, chevron) that folds its rows.
/// Thin line between rows of the Settings list (System Settings style: one card, rows split by a hairline).
struct RowLine: View { var body: some View { Rectangle().fill(Theme.ink.opacity(0.08)).frame(height: 1) } }

/// One foldable group of the Settings list: icon, title, one-line summary, optional attention badge, chevron.
/// Rows inside are indented under the title and share the same card (chốt kiểu A, 04/11/2026).
struct SettingsGroup<Content: View>: View {
    let id: String
    let icon: String
    let title: String
    let summary: String
    let badge: String?
    var first = false
    @ObservedObject var groups: OpenGroups
    @ViewBuilder let content: () -> Content
    var isOpen: Bool { groups.ids.contains(id) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) { if isOpen { groups.ids.remove(id) } else { groups.ids.insert(id) } }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon).font(.system(size: fs(15))).foregroundColor(Theme.brandMint).frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .semibold))
                        if !isOpen { Text(summary).foregroundColor(Theme.sub).font(.system(size: fs(11))).lineLimit(1) }
                    }
                    Spacer(minLength: 12)
                    if let b = badge {
                        Text(b).font(.system(size: fs(11), weight: .semibold)).foregroundColor(Theme.warn)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Capsule().fill(Theme.warn.opacity(0.14)))
                    }
                    Image(systemName: "chevron.right").font(.system(size: fs(11), weight: .semibold)).foregroundColor(Theme.sub)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                }
                .padding(.horizontal, 12).padding(.vertical, 8).contentShape(Rectangle())
            }.buttonStyle(.plain).hoverBG(8, Theme.ink.opacity(0.05))
            if isOpen { VStack(alignment: .leading, spacing: 14) { content() } }
        }
    }
}

/// Theme colour dot in Settings: the name shows under the selected one only; others show it on hover (like macOS Appearance).
/// Which theme dot the pointer is on (shared by the row, so only one name shows at a time).
final class HoveredTheme: ObservableObject { @Published var id: String? = nil; @Published var inRow = false }

struct ThemeSwatch: View {
    let pl: Palette
    @ObservedObject var vm: VM
    @ObservedObject var hover: HoveredTheme
    var body: some View {
        let on = vm.theme == pl.id
        // While the pointer is anywhere on the row the selected name stays hidden, so it does not blink between dots.
        let showName = hover.id == pl.id || (on && !hover.inRow)
        Button { vm.setTheme(pl.id) } label: {
            Circle().fill(LinearGradient(colors: pl.bg.map { Color(hex: $0) } + pl.accent.suffix(1).map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(Theme.ink.opacity(on ? 0.95 : 0.25), lineWidth: on ? 2 : 1))
                .overlay(alignment: .top) {
                    Text(appLang == "vi" ? pl.nameVI.components(separatedBy: " (").first ?? pl.nameVI : pl.nameEN)
                        .font(.system(size: fs(10))).foregroundColor(on ? Theme.text : Theme.sub)
                        .fixedSize().offset(y: 27).opacity(showName ? 1 : 0)
                }
        }.buttonStyle(.plain).onHover { inside in
            if inside { hover.id = pl.id } else if hover.id == pl.id { hover.id = nil }
        }.padding(.bottom, 16)
    }
}

/// Explanation under a Settings block, outside it (System Settings style).
struct SettingNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).foregroundColor(Theme.sub).font(.system(size: fs(11))).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 14)
    }
}

/// One rounded block of Settings rows (System Settings style). Rows are split by a hairline; the first row's line is clipped off.
struct SettingsBox<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content() }.padding(.top, -1)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }
}

extension View {
    /// A row inside a SettingsBox: hairline on top (clipped off for the first row).
    /// `attention`: something here needs the user (new version, permission off): a soft warning tint.
    func settingFlat(attention: Bool = false) -> some View {
        self.padding(.horizontal, 14).padding(.vertical, 11)
            .background(attention ? Theme.warn.opacity(0.07) : Color.clear)
            .overlay(alignment: .top) { RowLine().padding(.horizontal, 14) }
    }
}


struct SettingsView: View {
    @ObservedObject var vm: VM
    /// Groups start folded (chốt 04/11/2026); a group shows a badge in its header when something inside needs attention.
    // Shared, not per view: changing text size or theme rebuilds every view, and the open group must stay open.
    @ObservedObject private var groups = OpenGroups.shared
    /// The disk/RAM icon in the menu bar (same key as the MenuBarExtra in the App). Off: no icon; the app stays reachable
    /// from the Dock and Applications, and the low disk / RAM alerts still arrive as notifications.
    @AppStorage("showMenuBar") private var showMenuBar = true
    @StateObject private var themeHover = HoveredTheme()
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            Text(t("Settings", "Cài đặt")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text).padding(.top, 34)
            VStack(alignment: .leading, spacing: 14) {
            SettingsGroup(id: "scan", icon: "magnifyingglass", title: t("Scanning and cleaning", "Quét và dọn"),
                          summary: t("Full Disk Access, project folders, external drives", "Truy cập toàn bộ ổ đĩa, thư mục dự án, ổ cứng rời"),
                          badge: vm.fullDiskAccess ? nil : t("Needs Full Disk Access", "Cần bật quyền"), first: true, groups: groups) {
                settingRow(t("Full Disk Access", "Truy cập toàn bộ ổ đĩa"),
                           vm.fullDiskAccess ? t("On. Mail, Safari and Messages are measured too.", "Đã bật. Mail, Safari, Tin nhắn cũng được đo.")
                                             : t("Off: Mail, Safari and Messages are left out of scans. Turn it on in System Settings, then come back.",
                                                 "Đang tắt: Mail, Safari, Tin nhắn bị bỏ qua khi quét. Bật trong Cài đặt hệ thống rồi quay lại."), attention: !vm.fullDiskAccess) {
                    // The app cannot grant or revoke this itself: the switch shows the real state and opens the
                    // Privacy pane in System Settings; it flips when the user comes back (checked on activation).
                    Toggle("", isOn: Binding(get: { vm.fullDiskAccess }, set: { _ in NSWorkspace.shared.open(VM.fdaSettings) }))
                        .toggleStyle(.switch).labelsHidden().controlSize(.mini)
                }
                VStack(alignment: .leading, spacing: 6) {
                SettingsBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(t("Project folders", "Thư mục dự án")).foregroundColor(Theme.text).font(.system(size: fs(13)))
                        }
                        Spacer()
                        GhostButton(title: t("Add…", "Thêm…"), action: { vm.addProjectFolder() }, compact: true)
                    }
                    ForEach(vm.projects, id: \.self) { p in
                        HStack(spacing: 8) {
                            Image(systemName: "folder").foregroundColor(Theme.link)
                            Text(p.replacingOccurrences(of: NSHomeDirectory(), with: "~")).foregroundColor(Theme.text).font(.system(size: fs(12))).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            TextLink(t("Remove", "Gỡ")) { vm.removeProjectFolder(p) }
                        }.padding(.horizontal, 10).padding(.vertical, 5).hoverBG(8, Theme.ink.opacity(0.06))
                    }
                }.settingFlat()
                }
                SettingNote(t("Code or AI work folders. Tidymint finds drafts (_tmp, _to_delete) here, never pre-selects duplicates here, and checks links before deleting.",
                                   "Thư mục code hoặc làm việc với AI. Tidymint tìm nháp (_tmp, _to_delete) ở đây, không tick sẵn file trùng ở đây và kiểm tra liên kết trước khi xoá."))
                }
                VStack(alignment: .leading, spacing: 6) {
                SettingsBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(t("External drives and extra folders", "Ổ cứng rời và thư mục quét thêm")).foregroundColor(Theme.text).font(.system(size: fs(13)))
                        }
                        Spacer()
                        GhostButton(title: t("Add…", "Thêm…"), action: { vm.addExtraFolder() }, compact: true)
                    }.onAppear { vm.refreshExtras() }
                    ForEach(vm.extras, id: \.self) { p in
                        HStack(spacing: 8) {
                            Image(systemName: Prefs.onOtherDrive(p) ? "externaldrive" : "folder").foregroundColor(Theme.link)
                            Text(p.replacingOccurrences(of: NSHomeDirectory(), with: "~")).foregroundColor(Theme.text).font(.system(size: fs(12))).lineLimit(1).truncationMode(.middle)
                            if vm.extrasMissing.contains(p) {
                                Text(t("Not connected", "Chưa cắm")).font(.system(size: fs(10), weight: .semibold)).foregroundColor(Theme.warn)
                            }
                            Spacer()
                            TextLink(t("Remove", "Gỡ")) { vm.removeExtraFolder(p) }
                        }.padding(.horizontal, 10).padding(.vertical, 5).hoverBG(8, Theme.ink.opacity(0.06))
                    }
                    HStack(spacing: 10) {
                        Text(t("When a file is both on this Mac and on a drive", "Khi một file có cả trên máy lẫn trên ổ cứng rời"))
                            .foregroundColor(Theme.text).font(.system(size: fs(12)))
                        Spacer()
                        // A pop-up sized to the chosen option, so its text sits at the right edge like the other controls.
                        let opts: [(String, String)] = [("ask", t("Let me choose each time", "Để tôi tự chọn mỗi lần")),
                                                        ("external", t("Keep the drive copy (frees space on the Mac)", "Giữ bản trên ổ cứng rời (lấy lại chỗ trên máy)")),
                                                        ("mac", t("Keep the Mac copy", "Giữ bản trên máy"))]
                        Menu {
                            ForEach(opts, id: \.0) { o in
                                Button { vm.setCrossKeep(o.0) } label: { if vm.crossKeep == o.0 { Label(o.1, systemImage: "checkmark") } else { Text(o.1) } }
                            }
                        } label: {
                            Text(opts.first { $0.0 == vm.crossKeep }?.1 ?? opts[0].1)
                        }.menuStyle(.button).controlSize(.small).fixedSize()
                    }.padding(.top, 4)
                }.settingFlat()
                }
                SettingNote(t("Duplicates and Large & Old Files also scan here. Unplugged drives are skipped; network drives and Time Machine backups are not supported.",
                                   "File trùng và File lớn và cũ quét thêm ở đây. Ổ chưa cắm thì bỏ qua; chưa hỗ trợ ổ mạng và ổ sao lưu Time Machine."))
                }
            }
            SettingsGroup(id: "menubar", icon: "bell", title: t("Menu bar and alerts", "Thanh menu và cảnh báo"),
                          summary: t("Menu bar icon, open at login, low disk space, high memory", "Biểu tượng thanh menu, mở cùng máy, ổ sắp đầy, RAM cao"), badge: nil, groups: groups) {
                settingRow(t("Show in menu bar", "Hiện trên thanh menu"),
                           t("Free disk space and RAM at a glance. Off: alerts still arrive as notifications; open Tidymint from the Dock or Applications.",
                             "Xem nhanh dung lượng trống và RAM. Tắt: cảnh báo vẫn hiện thành thông báo; mở Tidymint từ Dock hoặc Applications.")) {
                    Toggle("", isOn: $showMenuBar).toggleStyle(.switch).labelsHidden().controlSize(.mini)
                }
                settingRow(t("Open at login", "Mở cùng máy"),
                           t("Keeps the menu bar icon running after a restart.", "Giữ biểu tượng trên thanh menu sau khi khởi động lại máy.")) {
                    Toggle("", isOn: Binding(get: { vm.openAtLogin }, set: { vm.setOpenAtLogin($0) })).toggleStyle(.switch).labelsHidden().controlSize(.mini)
                }
                settingRow(t("Low disk space alert", "Cảnh báo ổ sắp đầy"),
                           vm.lowSpaceGB > 0
                           ? String(format: t("Alerts when free space drops below %.0f GB, at most every 6 hours. Enter 0 to turn off.", "Báo khi chỗ trống dưới %.0f GB, tối đa 6 giờ một lần. Nhập 0 để tắt."), vm.lowSpaceGB)
                           : t("Off. Enter a number of GB to turn it on.", "Đang tắt. Nhập số GB để bật.")) {
                    HStack(spacing: 6) {
                        TextField("0", text: Binding(get: { vm.lowSpaceGB > 0 ? String(Int(vm.lowSpaceGB)) : "" },
                                                     set: { vm.setLowSpace(min(10_000, max(0, Double($0.filter(\.isNumber)) ?? 0))) }))
                            .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).controlSize(.small).frame(width: 56)
                        Text("GB").foregroundColor(Theme.sub).font(.system(size: fs(12)))
                    }
                }
                settingRow(t("High memory alert", "Cảnh báo RAM cao"),
                           t("Alerts when over 90% of RAM is in use, at most once an hour.", "Báo khi RAM dùng trên 90%, tối đa 1 giờ một lần.")) {
                    Toggle("", isOn: Binding(get: { vm.ramAlert }, set: { vm.setRamAlert($0) })).toggleStyle(.switch).labelsHidden().controlSize(.mini)
                }
            }
            SettingsGroup(id: "look", icon: "paintpalette", title: t("Appearance", "Giao diện"),
                          summary: t("Theme, text size", "Màu giao diện, cỡ chữ"), badge: nil, groups: groups) {
                SettingsBox {
                settingRow(t("Theme", "Giao diện màu"), "") {
                    HStack(spacing: 12) {
                        ForEach(palettes, id: \.id) { pl in ThemeSwatch(pl: pl, vm: vm, hover: themeHover) }
                    }.contentShape(Rectangle()).onHover { themeHover.inRow = $0; if !$0 { themeHover.id = nil } }
                }
                settingRow(t("Text size", "Cỡ chữ"), "") {
                    Picker("", selection: Binding(get: { vm.textSize }, set: { vm.setTextSize($0) })) {
                        Text(t("Small", "Nhỏ")).tag("small")
                        Text(t("Default", "Mặc định")).tag("default")
                        Text(t("Large", "Lớn")).tag("large")
                    }.pickerStyle(.segmented).labelsHidden().controlSize(.small).fixedSize()
                }
                }
            }
            SettingsGroup(id: "about", icon: "info.circle", title: t("Updates and about", "Cập nhật và thông tin"),
                          summary: t("Version \(Updates.current), update check, privacy, support", "Phiên bản \(Updates.current), kiểm bản mới, quyền riêng tư, ủng hộ"),
                          badge: vm.newVersion != nil ? t("New version", "Có bản mới") : nil, groups: groups) {
                settingRow(t("Version \(Updates.current)", "Phiên bản \(Updates.current)"),
                           vm.newVersion != nil ? t("Version \(vm.newVersion!) is available on GitHub. Download it and drag it over the old one.", "Đã có bản \(vm.newVersion!) trên GitHub. Tải về rồi kéo đè lên bản cũ.")
                                                : (vm.autoUpdateCheck ? t("Checks once a day. Only the app and macOS version are counted; nothing else about your Mac is sent.", "Kiểm mỗi ngày một lần. Chỉ đếm theo phiên bản app và macOS, không gửi gì khác về máy.")
                                                                      : t("Automatic check is off.", "Đã tắt tự kiểm tra.")), attention: vm.newVersion != nil) {
                    HStack(spacing: 10) {
                        if vm.updChecking { ProgressView().controlSize(.small).tint(Theme.text) }
                        if vm.newVersion != nil { PrimaryButton(title: t("Download", "Tải về"), action: { NSWorkspace.shared.open(Updates.page) }, compact: true) }
                        else { GhostButton(title: t("Check Now", "Kiểm tra"), action: { vm.checkUpdates(force: true) }, compact: true) }
                    }
                }
                settingRow(t("Check for new versions automatically", "Tự kiểm tra bản mới"),
                           t("At most once a day, when the window opens, Tidymint asks update.tidymint.app for the latest version number.\nBackup: tidymint.app, GitHub.",
                             "Mỗi ngày tối đa một lần, khi mở cửa sổ, Tidymint hỏi update.tidymint.app số phiên bản mới nhất.\nDự phòng: tidymint.app, GitHub.")) {
                    Toggle("", isOn: Binding(get: { vm.autoUpdateCheck }, set: { vm.setAutoUpdateCheck($0) })).toggleStyle(.switch).labelsHidden().controlSize(.mini)
                }
                settingRow(t("Support the project", "Ủng hộ dự án"),
                           t("Free forever. Sponsorships pay for the Apple Developer account ($99/year), so Apple can verify the app and new users just open it, no trip to Settings > Security.",
                             "Miễn phí trọn đời. Tiền ủng hộ trả phí tài khoản Apple Developer (99 USD/năm) để Apple xác nhận app, người mới cài mở là chạy, không phải qua Cài đặt > Bảo mật.")) {
                    PrimaryButton(title: t("Sponsor", "Ủng hộ"), action: { NSWorkspace.shared.open(sponsorURL("button")) }, compact: true)
                }
                settingRow(t("Privacy", "Quyền riêng tư"),
                           t("What Tidymint sends, and what it never sends.", "Tidymint gửi gì đi, và không bao giờ gửi gì.")) {
                    TextLink(t("View", "Xem"), url: URL(string: Backend.privacyURL)!)
                }
                if appLang == "vi" {
                    settingRow("Cùng tác giả: Cồn Cào", "Kiến thức đồ uống: whisky, sake, cocktail.") {
                        TextLink("concao.org", url: ConCao.url("settings"))
                    }
                }
            }
            }
            .frame(maxWidth: 760 * uiScale)
        }.padding(.horizontal, 24).padding(.bottom, 24).frame(maxWidth: .infinity) }
        // A group with something waiting (permission off, new version) opens by itself; the rest stay folded.
        .onAppear { openAttention() }
        .onReceive(vm.$newVersion) { _ in openAttention() }
    }
    func openAttention() {
        if !vm.fullDiskAccess { groups.ids.insert("scan") }
        if vm.newVersion != nil { groups.ids.insert("about") }
    }
    /// One setting. With a description: its own rounded block, the description as a note under it (System Settings style).
    /// Without: a bare row, to be grouped with others inside a SettingsBox.
    func settingRow<C: View>(_ title: String, _ sub: String, attention: Bool = false, @ViewBuilder _ control: () -> C) -> some View {
        let row = HStack {
            HStack(spacing: 6) {
                if attention { Circle().fill(Theme.warn).frame(width: 7, height: 7) }
                Text(title).foregroundColor(Theme.text).font(.system(size: fs(13)))
            }
            Spacer(minLength: 16)
            control()
        }.settingFlat(attention: attention)
        return Group {
            if sub.isEmpty { row }
            else { VStack(alignment: .leading, spacing: 6) { SettingsBox { row }; SettingNote(sub) } }
        }
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
                Image(nsImage: cachedIcon(Theme.p)).resizable().frame(width: 22, height: 22)
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
/// The mint leaf outline (Creative Fabrica leaf approved 28/10, same as docs/logo.svg), in app-icon coordinates
/// (y down, x 570.6...762, y 168...465.1). Used by the app icon and the menu bar icon.
let leafOutline: [CGFloat] = [
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

/// The leaf scaled to height `h`, y-up, left edge at x0, bottom (stem) at y0.
func leafPath(x0: CGFloat, y0: CGFloat, h: CGFloat) -> NSBezierPath {
    let minX: CGFloat = 570.6, minY: CGFloat = 168.0, maxY: CGFloat = 465.1
    let k = h / (maxY - minY), p = NSBezierPath()
    for i in stride(from: 0, to: leafOutline.count, by: 2) {
        let pt = NSPoint(x: x0 + (leafOutline[i] - minX) * k, y: y0 + (maxY - leafOutline[i + 1]) * k)
        if i == 0 { p.move(to: pt) } else { p.line(to: pt) }
    }
    p.close(); return p
}

/// Share of the leaf's area below each height (0...1, 200 steps from the stem up), measured once by drawing it.
/// Filling by area, not height, keeps 70% and 90% visibly different (the tip is narrow).
let leafAreaBelow: [CGFloat] = {
    let n = 200
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: n, pixelsHigh: n, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return [] }
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.black.setFill(); leafPath(x0: 0, y0: 0, h: CGFloat(n)).fill()
    NSGraphicsContext.restoreGraphicsState()
    var rows = [CGFloat](repeating: 0, count: n)          // rows[0] = bottom row
    for y in 0..<n { for x in 0..<n where (rep.colorAt(x: x, y: n - 1 - y)?.alphaComponent ?? 0) > 0.5 { rows[y] += 1 } }
    let total = max(1, rows.reduce(0, +)); var acc: CGFloat = 0
    return rows.map { acc += $0; return acc / total }
}()
/// Height (0...1) to fill so the filled part covers `area` of the leaf.
func leafFillHeight(_ area: CGFloat) -> CGFloat {
    guard area > 0 else { return 0 }
    guard let i = leafAreaBelow.firstIndex(where: { $0 >= area }) else { return 1 }
    return CGFloat(i + 1) / CGFloat(max(1, leafAreaBelow.count))
}

func menuBarImage(free: Double, total: Double, level: Int) -> NSImage {
    // The mint leaf, filled (by area) as far as the disk is used, then the free space.
    // 75GB, 123GB, then 1.2TB from 1000 GB up, so the label never grows past 3 digits.
    let text = free >= 999.5 ? String(format: "%.1fTB", free / 1000) : String(format: "%.0fGB", free)
    // level 0 normal (template, follows the menu bar), 1 getting low (Theme.warn), 2 low (Theme.danger).
    // Same hex values as the app palette, picked by the system appearance (the menu bar is not the app's theme).
    let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    func hex(_ v: Int) -> NSColor { NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1) }
    let ink: NSColor = level >= 2 ? hex(dark ? 0xff6b6b : 0xb91c1c) : (level == 1 ? hex(dark ? 0xffc56b : 0xa15c00) : .black)
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium), .foregroundColor: ink]
    let ts = (text as NSString).size(withAttributes: attrs)
    let gw: CGFloat = 12.5, gap: CGFloat = 3, H: CGFloat = 18
    let W = ceil(gw + gap + ts.width) + 1
    let used = total > 0 ? CGFloat(max(0, min(1, 1 - free / total))) : 0
    let img = NSImage(size: NSSize(width: W, height: H), flipped: false) { _ in
        // Mint leaf: faint whole leaf, solid part = share of the disk in use (by area).
        let leaf = leafPath(x0: 1, y0: 0.5, h: 17)
        NSGraphicsContext.saveGraphicsState(); leaf.addClip()
        ink.withAlphaComponent(0.3).setFill(); NSRect(x: 0, y: 0, width: gw, height: H).fill()
        ink.setFill(); NSRect(x: 0, y: 0.5, width: gw, height: 17 * leafFillHeight(used)).fill()
        NSGraphicsContext.restoreGraphicsState()
        (text as NSString).draw(at: NSPoint(x: gw + gap, y: (H - ts.height) / 2), withAttributes: attrs)
        return true
    }
    img.isTemplate = level == 0   // normal: follows the menu bar's colour like Apple's icons
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
            let im = menuBarImage(free: f, total: 245, level: a.count > i + 3 ? Int(a[i + 3]) ?? 0 : 0)
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
                // Grace period long enough for a move to the Trash in progress to finish and write its Undo record.
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) { if !other.isTerminated { other.forceTerminate() } }
            }
        }
        NSApp.applicationIconImage = dockIcon(Theme.p)
        if !a.contains("--demo") { sharedVM.checkFullDiskAccess() }
        PreviewLinks.clear()   // leftovers from a run that quit with the month viewer open
        if !a.contains("--demo") { _ = CheckIn.shared.firstOpen }   // saved once, on the first launch
        // Developer helper for README screenshots: `--demo` fills every page with sample data (no real files),
        // `--page <name> --window <W>x<H>` opens a page at a fixed size.
        if let i = a.firstIndex(of: "--export-icon"), i + 1 < a.count, a[i + 1].lowercased().hasSuffix(".png") {
            // Writes the 1024px app icon for Resources/AppIcon.png, then quits. Used by build tooling.
            let img = makeAppIcon(Theme.p)
            if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: a[i + 1]))
            }
            exit(0)
        }
        if a.contains("--demo") { Demo.load(sharedVM) }
        if let i = a.firstIndex(of: "--page"), i + 1 < a.count,
           let pg = Page.allCases.first(where: { "\($0)" == a[i + 1] }) {
            sharedVM.page = pg
            if pg == .cleanup && a.contains("--demo") { sharedVM.phase = a.contains("--done") ? .done : .review }
            if pg == .byapp && a.contains("--demo") { Demo.apps(sharedVM, detail: a.contains("--detail")) }
            if pg == .lens && a.contains("--sysdata") { sharedVM.openSys() }
            // `--scan` starts the scan of Duplicates or Large & Old Files right away (test helper).
            if pg == .dupes && a.contains("--scan") {
                sharedVM.scanDupes()
                // `--detail` opens the first group once the scan is done (test helper).
                if a.contains("--detail") {
                    Task { @MainActor in
                        while sharedVM.dupBusy { try? await Task.sleep(nanoseconds: 300_000_000) }
                        if !sharedVM.dupes.isEmpty { sharedVM.dupes[0].expanded = true }
                    }
                }
            }
            if pg == .large && a.contains("--scan") { sharedVM.scanLarge() }
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
/// Small icon for the sidebar and menu (bitmap, 64 px). The drawn icon is 1024 pt, and showing it directly kept
/// a 2048 px bitmap (16 MB) alive for each place it appears.
func cachedIcon(_ p: Palette) -> NSImage {
    if let i = iconCache[p.id] { return i }
    let i = rasterIcon(makeAppIcon(p), px: 64); iconCache[p.id] = i; return i
}
/// Draws `img` once into a px x px bitmap; the result is px/2 points (Retina).
func rasterIcon(_ img: NSImage, px: Int) -> NSImage {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return img }
    let pt = CGFloat(px) / 2
    rep.size = NSSize(width: pt, height: pt)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: pt, height: pt)); NSGraphicsContext.restoreGraphicsState()
    let out = NSImage(size: rep.size); out.addRepresentation(rep); return out
}
/// Dock icon: a 512 px bitmap (1 MB) instead of the 1024 pt drawing.
func dockIcon(_ p: Palette) -> NSImage { rasterIcon(makeAppIcon(p), px: 512) }


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
        let lp = leafOutline
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
    @AppStorage("showMenuBar") var showMenuBar = true
    var body: some Scene {
        Window("Tidymint", id: "main") { RootView(vm: vm) }
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width: 1080, height: 700)
        MenuBarExtra(isInserted: $showMenuBar) {
            MenuView(vm: vm).id(vm.theme)
        } label: {
            Image(nsImage: menuBarImage(free: vm.freeGB, total: vm.totalGB, level: vm.diskLevel))
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
                Text(t("Startup Items", "Khởi động cùng máy")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text)
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
                            // Section title 13 semibold + a short note in the secondary colour (style guide 1f).
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(sc == 0 ? t("Your account", "Tài khoản của bạn") : sc == 1 ? t("All users · agents", "Cả máy · agent") : t("All users · system services", "Cả máy · dịch vụ hệ thống"))
                                    .font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                                Text(sc == 0 ? t("can remove here", "gỡ được ở đây") : sc == 1 ? t("needs admin, remove via the app or Settings", "cần quyền admin, gỡ bằng app gốc hoặc Cài đặt") : t("needs admin", "cần quyền admin"))
                                    .font(.system(size: fs(11))).foregroundColor(Theme.sub)
                            }.padding(.top, 12).padding(.bottom, 2).padding(.leading, 4)
                            ForEach(rows, id: \.self) { i in LaunchRow(e: $vm.launch[i], vm: vm) }
                        }
                    }
                }.padding(.horizontal, 24).padding(.bottom, 12)
            }
            HStack(spacing: 12) {
                Text(vm.launchMsg.isEmpty ? t("\(vm.launch.count) items", "\(vm.launch.count) mục") : vm.launchMsg)
                    .foregroundColor(Theme.text).font(.system(size: fs(13))).lineLimit(2)
                Spacer()
                GhostButton(title: t("Login Items…", "Mục đăng nhập…")) {
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
                Text(e.owner).foregroundColor(Theme.text).font(.system(size: fs(13))).lineLimit(1)
                Text(e.label).foregroundColor(Theme.sub).font(.system(size: fs(11))).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 12)
            HStack(spacing: 6) {
                if e.orphan { StatusTag(t("App removed", "App đã gỡ"), Theme.danger) }
                if e.running == true { StatusTag(t("Running", "Đang chạy"), Theme.green) }
                if case .apple = e.sign {} else if !e.sign.label.isEmpty { StatusTag(e.sign.label, e.sign.color).tip(e.sign.help) }
                ForEach(e.flags, id: \.self) { f in StatusTag(f.label, Theme.warn).tip(f.help) }
            }
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
            Text(t("Statistics", "Thống kê")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text).padding(.top, 34)
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
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
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

// MARK: - Check-in ("Is Tidymint helping you?")

/// A one-line card at the top of Clean Now, asked once: 14 days after the first launch and 2 uses of a main feature
/// (or 60 days and 1 use). X on the question = later (14 more days, once), then never again.
/// The answer goes to the same form endpoint as Contact: no email, no machine id. The Dev build never asks.
@MainActor final class CheckIn: ObservableObject {
    static let shared = CheckIn()
    enum Step { case hidden, ask, why, thanks, sent }
    @Published var step: Step = .hidden
    @Published var reasons = Set<String>()
    @Published var note = ""
    var answer = ""
    let d = UserDefaults.standard

    /// First launch, saved once. Updating the app keeps UserDefaults (same bundle id), so a release never restarts the clock.
    /// Someone upgrading from 0.3.7 has no key yet: the oldest trace of earlier use is taken (activity log, data folder).
    var firstOpen: Date {
        if let v = d.object(forKey: "firstOpenDate") as? Date { return v }
        var cands = [Date()]
        if let e = Stats.load().first?.date { cands.append(e) }
        if let c = (try? FileManager.default.attributesOfItem(atPath: Stats.dir))?[.creationDate] as? Date { cands.append(c) }
        let v = cands.min()!
        d.set(v, forKey: "firstOpenDate")
        return v
    }
    /// Uses of a main feature (scan, clean by app, uninstaller, space lens, large files, duplicates).
    /// Started from the activity log for people upgrading, so their earlier cleanups count.
    var uses: Int {
        if d.object(forKey: "featureUses") == nil { d.set(Stats.load().count, forKey: "featureUses") }
        return d.integer(forKey: "featureUses")
    }
    func used() { d.set(uses + 1, forKey: "featureUses") }

    var isDev: Bool { Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true }
    func shouldAsk(now: Date = Date()) -> Bool {
        guard !isDev, !Demo.active else { return false }
        let state = d.string(forKey: "checkinState") ?? ""
        if state == "done" { return false }
        if let next = d.object(forKey: "checkinNext") as? Date, now < next { return false }
        let days = now.timeIntervalSince(firstOpen) / 86400, n = uses
        return (days >= 14 && n >= 2) || (days >= 60 && n >= 1)
    }
    /// Called when the Clean Now page shows.
    func refresh() { if step == .hidden && shouldAsk() { step = .ask }; flushPending() }

    func later() {
        if (d.string(forKey: "checkinState") ?? "") == "" {
            d.set("later", forKey: "checkinState"); d.set(Date().addingTimeInterval(14 * 86400), forKey: "checkinNext")
        } else { d.set("done", forKey: "checkinState") }
        step = .hidden
    }
    func choose(_ a: String) {
        answer = a
        d.set("done", forKey: "checkinState")
        send(["answer": a])
        step = a == "helpful" ? .thanks : .why
    }
    func sendWhy() {
        send(["answer": answer, "reasons": reasons.sorted().joined(separator: ", "), "message": note.trimmingCharacters(in: .whitespacesAndNewlines)])
        step = .sent
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { if self.step == .sent { self.step = .hidden } }
    }
    func close() { d.set("done", forKey: "checkinState"); step = .hidden }

    private func send(_ extra: [String: String]) {
        var f = ["source": "checkin", "type": "checkin", "email": "", "newsletter": "no", "message": "",
                 "app": Backend.systemInfo["app"] ?? "?", "lang": appLang]
        f.merge(extra) { _, b in b }
        Backend.send(f) { ok in if !ok { self.queue(f) } }
    }
    /// No network: kept and sent at the next launch.
    private func queue(_ f: [String: String]) {
        var f = f
        let n = (Int(f["tries"] ?? "0") ?? 0) + 1
        guard n <= 5 else { return }   // given up after 5 tries: no endless requests on every page visit
        f["tries"] = String(n)
        var q = d.array(forKey: "checkinPending") as? [[String: String]] ?? []
        q.append(f); d.set(Array(q.suffix(5)), forKey: "checkinPending")
    }
    private func flushPending() {
        guard let q = d.array(forKey: "checkinPending") as? [[String: String]], !q.isEmpty else { return }
        d.removeObject(forKey: "checkinPending")
        for f in q { Backend.send(f) { ok in if !ok { self.queue(f) } } }
    }
    static func freeHelpURL() -> URL {
        URL(string: t("https://tidymint.app/sponsor/", "https://tidymint.app/vi/ung-ho/") + "?utm_source=tidymint&utm_medium=app&utm_campaign=checkin#free")!
    }
}

struct CheckInCard: View {
    @ObservedObject var c = CheckIn.shared
    static let reasons: [(String, String, String)] = [
        ("little", "Frees too little", "Dọn được ít"), ("hard", "Hard to follow", "Khó hiểu"),
        ("apps", "Missing my apps", "Thiếu app hay dùng"), ("rare", "Rarely need it", "Ít khi cần dọn"), ("other", "Something else", "Lý do khác")]
    func pill(_ title: String, _ icon: String, _ a: String) -> some View {
        Button { c.choose(a) } label: {
            Label(title, systemImage: icon).font(.system(size: fs(12), weight: .medium)).foregroundColor(Theme.text)
                .padding(.horizontal, 10).padding(.vertical, 5).background(Capsule().stroke(Theme.ink.opacity(0.3), lineWidth: 1))
        }.buttonStyle(.plain).hoverLift()
    }
    func xButton(_ act: @escaping () -> Void, tip: String) -> some View {
        Button(action: act) { Image(systemName: "xmark").font(.system(size: fs(11), weight: .semibold)).foregroundColor(Theme.sub) }
            .buttonStyle(.plain).tip(tip)
    }
    var body: some View {
        Group {
            switch c.step {
            case .hidden: EmptyView()
            case .ask:
                HStack(spacing: 8) {
                    Text(t("Is Tidymint helping you?", "Tidymint có giúp ích cho bạn không?")).font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                    Spacer(minLength: 6)
                    pill(t("Helpful", "Hữu ích"), "hand.thumbsup", "helpful")
                    pill(t("It's okay", "Bình thường"), "face.smiling", "okay")
                    pill(t("Not yet", "Chưa hữu ích"), "hand.thumbsdown", "not")
                    xButton({ c.later() }, tip: t("Later", "Để sau"))
                }.onExitCommand { c.later() }
            case .why:
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(t("What is Tidymint missing?", "Tidymint còn thiếu gì?")).font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                        Spacer()
                        xButton({ c.close() }, tip: t("Skip", "Bỏ qua"))
                    }
                    HStack(spacing: 6) {
                        ForEach(Self.reasons, id: \.0) { r in
                            let on = c.reasons.contains(r.0)
                            Button { if on { c.reasons.remove(r.0) } else { c.reasons.insert(r.0) } } label: {
                                HStack(spacing: 4) {
                                    if on { Image(systemName: "checkmark").font(.system(size: fs(10), weight: .bold)) }
                                    Text(t(r.1, r.2))
                                }.font(.system(size: fs(12), weight: .medium)).foregroundColor(on ? Theme.text : Theme.sub)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Capsule().fill(on ? Theme.accentSolid.opacity(0.25) : Color.clear))
                                    .overlay(Capsule().stroke(on ? Theme.accentSolid : Theme.ink.opacity(0.3), lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                    HStack(spacing: 8) {
                        TextField(t("Add a line (optional)", "Thêm một dòng (không bắt buộc)"), text: $c.note)
                            .textFieldStyle(.roundedBorder).font(.system(size: fs(12)))
                        PrimaryButton(title: t("Send", "Gửi"), action: { c.sendWhy() },
                                      disabled: c.reasons.isEmpty && c.note.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }.onExitCommand { c.close() }
            case .thanks:
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "leaf").foregroundColor(Theme.accentSolid)
                        Text(t("Thank you. Tidymint stays free thanks to Mint keepers like you.", "Cảm ơn bạn. Tidymint miễn phí nhờ những Mint keepers như bạn."))
                            .font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                        Spacer()
                        xButton({ c.close() }, tip: t("Close", "Đóng"))
                    }
                    HStack(spacing: 12) {
                        PrimaryButton(title: t("3 free ways to help", "3 cách giúp miễn phí"), action: { NSWorkspace.shared.open(CheckIn.freeHelpURL()); c.close() })
                        TextLink(t("Support the project", "Ủng hộ dự án"), url: sponsorURL("checkin"))
                    }
                }.onExitCommand { c.close() }
            case .sent:
                HStack(spacing: 8) {
                    Image(systemName: "checkmark").foregroundColor(Theme.green)
                    Text(t("Sent. Thank you, we read every reply.", "Đã gửi. Cảm ơn bạn, chúng tôi sẽ đọc từng góp ý.")).font(.system(size: fs(13))).foregroundColor(Theme.text)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, c.step == .hidden ? 0 : 14).padding(.vertical, c.step == .hidden ? 0 : 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(c.step == .hidden ? Color.clear : Theme.card))
        .frame(maxWidth: 680)
        .animation(.easeOut(duration: 0.2), value: c.step)
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
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
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

/// Brand logos for the Contact footer: Simple Icons (CC0) / Lucide (LinkedIn), the same shapes as the website footer,
/// as 64 px template PNGs so they take the theme colour. Brand logos are the one exception to SF Symbols (style guide 1e).
enum BrandIcon {
    static let png: [String: String] = [
        "facebook": "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAEqklEQVR4nOSbaahNXRjH/7je9/XKEG4hwzVe81AocxK+yRSSKRER8oFuQr4gpYxdUcoUGTOVWRkzRzJPtwjJkMwyPf+7zqnd7pxz99p7re2s61f/2z17r3vuXs9ew7Oe9awcxEN3UQtRc1FTUW1RdVGNxP1XoteiZ6K7otuim6KzsEwZ2KGNaKCoN1Tlw/JFdF50XLRV9BCGMWmAXNFE0RhRY9jhhmiTaK3oHQxgwgBNRAWicYiPz6L1ooWip4hAOYSnrGiWaJuoI+KlfOJ/ThC9EV1BSMK2AL71zaJOyA44RowSPYcmZaHPJNE1ZE/lCQdbzhoDoIluC9ghGoLsplA0JWjhoAaoJjog6gw3OCgaBDWNZiSIASpDzcXN4RanRD1LKlQuwP1Dog5wj/qiBqI9mQqVZIBlomFwl3ZQ0+TFdAUydQE6NusQD/ehuhnFGeZtQi88ZWpCvdV8UTOoWah3sK8vLnci1Y10BqCTwYVIedjjh2inaAGUi6sLDXEnYFm2AraGJ/4b6fyAXbBb+ctQq8LhCFd58lOjLGexLalupDLAfFFd2IOLma6iR4iGrhPXTTTUf9HfBepA9cf/YAeOKeNhBrrj96AHu0A97wW/FefBXuVPQi2XTRHGjWfLnuq94G0BtAwDDjkwz6/E90dauvrQGQS9cMGUJ/rGD14rzoSdypP9MFt58gvhqAW1cizGa4CRsMdKmCesAciY5C/JN95fVBX2OIbw0OGhS8s3533G6ggP45Qc8J8mDTAC9rgEff6HcsP5XBVhB/ogS9gFOBD2gz10w1V8Ji5nGe6yVXnSlz/YAtrDbvO/BT34ZnrAPnSMig3QC3b5AD3iii5XEHWlAVrBLroG6Ib4aEkDNIVd3muU5ebKv4iPxjRAPuzyXaNsBcRLPg1QCdlDGP8+CrVpgCi7Q66TSwPEbfVsIpeV1+mj6WAEqUwa6bjBRRm+x68ziE4ODfAJbtIe0XlPA3yEezC2YMJNfkcDaO+oZgFtYYYXNEAR3KMNzPCAs4DxvJsYaA0zFBvgKtzDVAu4SgNchlv8AzPuOzdWTnIMYBdwaSDk6tWE88YX/yH5RfvgDqaa/17+SO4LMDx0GHbog+DeYJ7oMeKhIf9XsgUcgZv+QFguIGFob1+KKxcgGyhM/uI1wGr8HTAxe2Pyg9cAzNRejtLPUu8H/3TC3FvdIKZL8CUv9F7wG+ClaA5KLwX+C6kcCnaD6yh9MNFzk/9iOo+K6bCuBkpSwWyz0alupDPAA8Sb/28b5ga9TXUjk0/NcwCL4D5MnD6d7mZJi4rZUAFPV+EWe2GmAkFWVdyjPwf3YOVnlFQoiAGYTMT8AZcCJ4sRoPIk6LqazlEX0RpkP0yDKwhaWCew8BXquAyzx3V2fOOCBy8Hi1bp/FGYyMp2UUtkGFn/AFzccJt/NzQJG1piyilPY0zDn91Y4TFb5h0z7e0NQhAltsY8Peb/MUa3AvEuovgCJkOdG4g0Q5kILhaJpkMdaOBD3YY9WNmxUFtjRuIXJrfG2RX4UDwlzjwfnu810Sq4CzxX1AiquW+AQWydHvdSBcEPOudBRagZRD0KdfLL6hjzGwAA///8mGIKAAAABklEQVQDABV6wtD33EZdAAAAAElFTkSuQmCC",
        "instagram": "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAHNElEQVR4nNybCdCVUxjH/9XXV6JQtjZRqcZeqmkaW5ZMhjA1NIRhJMYWkaWQtcUyw2AGgw9ZsozxYYhowthSYwkp9WnfQ1rVJ8/fufeb6+15zrve3Ntv5t9895xzb/d93vOe8zzPeW4FktFE1EvUQdQ2p1aiRqL2udfFYI3oe9EG0WLRwpzmiD5FAurFGLun6FzRGaKTUXqsF30oekX0umhTlDdFMcAeoutF14h2Q3mwSjRedF/YwDADXCR6EM4I5QgfkwvhZoZKA8+bnxKNFjVG+dJMdAHcmjVZG2DNgJdF5yAZv8EtVNtQHA4W7Y34fCLqB7dW1KEZYILoPPhZCrfqfgN3sQtE80W/Y8ewl2h/UUdRZ1F3Ue9cu48PRH0LG4IGGCJ6AjZfiW4XvYfShLN2tKiLZwwX84fzLwoNwGk1V9TUeOMduQ8vB64TPWD0rYPzVVbyReEiOFZ0jPGmyzwfWIp8LtosOknpqxQ1FE3ii/wMOEBUY3zYKNE9KE8eEV2htG8UtRGtqZ9ruNz4gFko3YunK879nU7PWrhV/oTAmJtz/UF2gfNx6mbAElFLZeAg0USUHoxBfjH6eoi+LnjNm/uYMm66qDsNwBXzJ2UALZdkv90RcBW/yuh7CS5mKYQLnrZFtuAj0As6b6B06RKzb5IxtmeF/HOQ0TkFxaEr3KLbAu6u0GPkbFstmif6LsJn/O3p05w7rg+ac9eRBugAnenIjm6iwaKBCM8V0KPkuvOc6AdjDOP/U4y+H5W2mcbYDrTWR6I+SmecXIEF3dQxorOQjBdFI0W/BtqtRZBxCN3ieYF2Gn2BMn4iL5L+/BGBDu6TTZAOXvhNyAZ+zrhAG+MAzqpD4Zybb+EWx5XGZ2jB2RQagO5v+0DHCtG+SAZDUEaT/ZAtz8OFtklhFBi8qTO4C2hZnnVIxq5wUWLWF0/Oh3tck6KlyBpzEdSm+nokg3fpsJAxP8N5cPQy+azSK+uaEx/FVp73cq3iNL8a8dEM0IgG0GbABsSHbqdvsePMYJQ2Tel7reDv/qIquCSsBh2gL0UvIB6aASrrxxjso53oXk8/+xhpTkM41XCz6GPPGM6C3RGPWqWtgWWAvxCPsZ4+zoyRiAeTmcfBDsGbi25BPLRdwDSAz9MKwm1okNFHh8ZnnDCYjq82+kaI9kF0NAPUswywFdEZYLTzLl6M9HDrW2H0nYl0bLMMUIno9DfaOe2TLKZB/oCdihuIdNSnI6RNjami4xEOp+BypZ1fOuvDlD+h71jcRqMs2tx2OwfaVlgzwHdgUkgno30Ssmey0d4O0dB2gYq0i6CVh5+B7LGiU5/jVIi2szWsMAZbhglircLLkT3WZ0Y9it+itFWmNUCc3SIttUZ71O8aywBRz/UWG+3FyCXuZ7QvRDRUP6AC6VhqtHdD9nSL+R0ikdYAc432U5E9fY32GqTAen6ipsMYNmsxOpMig5EdzAVoZ5bvwmWvoqBda61lgDhn+28Z7aOQHVYwVY3oaNfaIOoK6uNNo51e1/1Iz3hs78GF/d8a2rVuTPsIED6DVk3BcNGdSA5rEW4w+h5CvAVQ825r07rCefhFrcDnVtE7iLc10sPkozXa6GdccBfioQV4W2gAbRGJa4Bloms9/dwVmP9jcqSpZxz7mALn7nKaZxwPPFcjHo2Utk2c6qzrCaaXWPdzOOJzN8KzP4zcmANkuU3+AINp+Z5w4W1YVRozQWMQn0Wi1oG2GhqAyYbg9JwNe+EJ43HRpSgOLHwcgWTw1CgYos/kI6BVdoVVW/kYKhoG23dPAmMOZpeSXjwx/QBtJW2OdHCF5uHlfKSHU5cJ0meQjmZK21YawDpLa4108PCDR+9Xws7p+eBdH5f7jM+QDis7tYoGWGZ0ZlHyzhD0UbhzRlaZ8y6u9Yzn4/i26EbRIXA7QtwzCg3rWpYyGJpndLLS4gtkR3VOfJYPhFtk8ym1WTktQHGwFvS5NMAco5OlM1UoDjU57aiK06ON9tncBq3MLpMdbbBzYFXBteUawAVKq8vhIpj24KEU4MGKdvGc+Yvye+ME4823obzhmYEVM7zKf/IGeNoYxDP7cjZCFVxZvQZ/EFIX9DAg4lbVQxnIogQmSKaivGAYPczoYyzybwhfGPcz6+qLr/mGoSgPmIgZ7unntsh45z/+MR2iIZ43McBhvd0AlC50tlj15rt4Olez8y+0zM+Tokvgh5WdTFg8C1fMuAr/D/Tvj4SrT+CO1TJkfBVyVeJ5rNQXn/djkQ4WYCeJATS4VrGAqimSw6LL7cplLQOw3I13uA92DvjDCbW63Ep9MYjh9KbFe6N84W+NOeXNX5CG5f7ehwtg6BV2QvnAQk+m089GyFF93B9Pnw6XtzsR6WuJiwELM3jD+LxH+g1jmopw1v0xWUFPi0ETCxXyRuHMOgrOFc0K+u5Lcn9vzv3Nk2GG0MwiM3SPekxWxz8AAAD//+uR6vkAAAAGSURBVAMA9RFWB2i7K80AAAAASUVORK5CYII=",
        "x": "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAIuklEQVR4nMybeawlRRXGvzcjKEFB4gbGEXCJEBR1UNlEnyKoQRkMLqhRZ0SNElHjviSamLgRRSMucWEx4hIMUcedEXgo+xb2NcBj33lhGdZhOb+p7qTuuVV1u/t2z8yXfH/c07d6qa5zzlenqhdJ2sJ4k/HxHvgXbTiYMf5N4/d4lnGT+k+LjAvG96kfLDN+UBsGDjG+zdluML7V+EBtmIkO/tz4cU2Pe4zbGW/W+sMK4xHOxn3tYrw0NsYd8BTjRcYXanrMGd+g9YO9jP8yLo5sjxr3NJ7k/zzjfu9sPN3ZfmH8o/J4uvHPCfunjT/WusWOxlOMT3V2RsRRqQYzCdu3jV+Jfq82bm+8Xnl8xvhDZ3vQ+FLjVVo32FIhwD3P2Xmer+UapTrgScZzFHqzBqNid+NjymPO+Hpn4zyvmdCuD2xqPFWj9wyONb6z1HBxwsbNzhk/Fh2nV9cY/5c/lf5j/KjxyZHtudX5TtJwIJP93bibs59m3FfB/7NYnLHfYXxYIaDUeJ3xH8pH9/sUhvu7nH0P41+Nt2oY/NT4Hme7UiEI3zep8cyEYydrtGevNu6g4N85HG18v7NdZny5Qqf2iVTsQdcsNc6rARYVjqGa3qsQBGu8wPgjlXGQxgMmuuC76heInB8420PGfdTw4cHiCcfvNt5ufHtke5WCf+Wi+0PV8QM1OsIQIatUziZNwT3807ixsx9gPE4tsKjBf36lEOBiMMyfVWhD1vBvh874g0LEngYEZITOJs5OqjtWLTHT8H887OUKE6ca9PSbC214O2cbX+bsRxo/rG7YTKFzt+/rnJNcoMb9CoHsgMiGZL5N4SFTIP2coNF0Cl6p8BBtBRLn+LfC8I9BiiXXP64OaNoBgBHwYo2KDfQ1w3oh0+ZOhc7zI4Xfv1Y5m3gcbtzP2S6t7qHNeUbQ1AVqMAQZCVtFtnMV5hBrCtc4UeMqEW2wn5rhy8bvONstxlcrTHE7o80IAER45O3yyEZnIJ9PKLRLqURS4zXG81XG/goTsvhlMZ+fVRA8U6FtB4B54zMVNH4N5gkExdzbyKlEhu9vlFdsuxpXKnRwDaQ1nfJ/9YC2LlAjVTsgvzP7u6fQ7vcK4irGnNK1g20U3GsLZ+91mt1EB6RA0EF/x7O8JcafTGhHxcnPJWaNn3I2Hvo4jT88VateawxdXKAGD7KRwiSpBnr/koopEENImx/S6OhjBFB0WajOuao6VwxmfNQbO6W7HLq6QI1U7aBJTfD7xs85G+chx/9O40XaCxSk9APqGdN2AECV+TdORthzQjtiyA7Ohs8vdbbrFNLsLRoA07hADWoH92pU7Gxb2U4rtCOKH+juYSv3H0bTrFrM7tqijw4ASFuKJ0siG36N2Lkt0wY7wXTvzHGkNDX8nNTuBX24QI3nK7hCPNtDPhMfHi5cn1reLoljTG6O1MDomgZTwFcPdraXGL9XaENEf7fS2uEmrQP0OQJqMGPzk59ZlQujKMRjnI1CDB24oAExRAekagekRCJ+6WFStcQ2E6ZO6NMFavDmVjgb0f3wCe2oJV7rbCy29rVwm8QQI6DGUQqKL8ZyhclPDgRDgmJ8X4Mutg7ZAU8zXqzR1EiFGVe4ttDOL80BpPHeGgBDuEANhJDfK0CKPHpCu68bL3Q2NEYfS/dj6EsI5TCvEAzjPI9eIMWdm2nDDBMp/RGN1gHeZPytQqm+NwzpAjWeoSCXY+AKpLgbC+0+aTzM2YgPu6tHDD0CcDH2DflNF5TMd1Jmzb7CmQrLcnFb4gkzwlPUE4YeAT8zfqJw/LMaX9uLQfokkMaaAllNreAy9YAhOyC1cOnBwzBXuLzwH5blVjob9QFG0BpNiaFcgJtO5XsKIbu5688qlLpyuMK4tcKCSo3nKLjXiZoSQ3QAb5Qy+EbO/k3jVxXWFnaN7M+ubKVFzf8aP2DcPLK9VuX9Co3QtwuwcMk+nS2dnWpwrfMJgKwFbBcdZ1ZI/aA0YSKVEvxi7UKpnUp055WhPoUQIoe36B+eqtDy6Dd+T0U59t965Xgz5UHRxe8xIEMcoinQlwtwHral7uzs9VaV1c7OdhkEzxsjG9L5RcY/KQ/2KL1DIQbU4JqMnHl1QF8uwK5MPwNE/LB2N59pw+gj1+/k7Ph6SS4joM5TWJypQRzApUqLMtmbmBbkcv/w1P+p580X2jECcAXvv2x6WlJoR8r8vLOhFzotmEzrAuzToW4XjyQCGvsIjm/QfqHiPpGNBVSyxBGFdgRarxJfoQ77DqZxgR2rC/qtKl9S+8BEPp91NqbEpY1VqcpT6zJa1w7IpbuuW1UYwkjbOAuQJVgkubDQLqUSW5XRurgA6Y5FjW2dnaIFPt1l7Y7lcYok+0c24hNZgp0kOcmLSmR6HavEpvsO1qLtCKDD2KG1l7OzVYWIv1rTgZnjMmdjxfngQptNq+vHgbNxGa1tB6TSXS9bVSrgz8z+/BIZZfaSVE6pxDk1+GahjQuQer7obKuri0y9VaUCKdFvwQFvUXlTFZ3vl+q3UdikdaYKaDoCSHcr3f8fq25slfpH6vMdlOa+hTaUz87Q6OryxG8WmnQAa/ZIUJ/uDlJ5GjsNcp/vsJpc0gfsZb5Yoyqx+M3CJBcg3RHxN3f2Q43f0nAg6uPTFEbjl0RhtN5JkgL2uzQqrPhmgQlYclNVqQPIyUwytnZ2tqqs0PAggqMK94hsG1e/iQe5dMtyuleJ7FFMfrOQcwE65niNb27k5ASa3reqZJDaggO+oVBgySGlEpPfLOQmQ+wQ9w8/L/fR4ToAroC48vsL6IClhXZIYr8shy4Y67SUC3xB4+kOYcHQ6yPXtwXTar+ThJGLGPulyiqRGBZ3FGsKuPDN8YlipNLdI9XFSuWqoZH6fKcrRsposQuQ7o7ReKcs1/p9eJD6fKcrCI6H1j/iz+JS6Q6fOUwbBlgTRHYv0/RAuq8to/G2c19hxJXcDQmpLThdsLaM9gQAAAD////R8KYAAAAGSURBVAMAPG3dodnXXCgAAAAASUVORK5CYII=",
        "linkedin": "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAACdUlEQVR4nOyaS0gWURiGX82CDLoH3SkoCqJoUxEVtO2yKIhqE0S1rhZdFkGbaNMmWqQbcSGCC0HFlbhVBG/gwoUiiO68gW5UULy8H+NCZM7MOf6/Z/7xOw88CHO+Ec7LzJzbXwHlVEA5IQAoR30AeyxqrtD39Au9Q1fpKHYJZSlt0unfdO+Wthb6js4i5yQF8Jn+TWjvpA/pCnKM6RU4R5voPvOtOE+naC9yTLnh+hN6AOm8Qc4xjQI3YcdV5BxTAHOwYwI5xxTAAOywrStZTKNAJe2h18y3Ypnepf3IMaaP4AJ9tfHXxDfkvPNC0kxwmlbTE/QgoqdiEtGw95I2YxdQBuWE1SCUEwKAcko5gOv0KT1Lj9OjdJ7OIBqNOmgbCqTUAthPP9IP9JJFvUzZG+gfOoZtUCrDoEzI3tJf9DTcWaL/N+532qQxBdBIX6Cw/2HLYdpKH6BwZPL2CA4z1HJki6w1ZEFVjM4LMmvtgsM+RZbfgAuIPmRHUFxkF6uOrtH6tOKsngBZW7Sj+J3fTC29l1aUVQD/6GXsLLKTLd+yyqSiLAK4geiL74NT9EdSQRYB1MAvXxHtYMfiO4D79Bb8Iq/CJ1Oj7wCewZ0q+pgeorfpd0TjvQvPTQ2+J0JypnjRoVbOJ4Zi2uTMQl6l17BH1haDWy/6fAJkyLPtvIzh0rkhQ7ssiuRschz2xL56PgM46VArh69pR26L9CfsiV1j+JwJnnGo7bOs64Y9mQfgMusbsawbhj3H4i76DCDrpXfs6x62xKCcEACUEwKAckIAUE4IAMoJAUA5IQAoJwQA5agPIPxOEMoJAUA5IQAoJwQA5awDAAD//48o/vsAAAAGSURBVAMAe85Nuv8OnGMAAAAASUVORK5CYII=",
        "github": "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAGOElEQVR4nNSbaYwURRTH/yoqRrmCgC5RRHFdPOItRIhuPONNBIlG8YxAxOOLGI2JWaPRaPygon4wMcZzjfE+UIgYFTxwN0iCwiJ4gBKCqCiurgoB3n+qC3qb7ul61d0zPb/kv9nuqZqZelNd/eq9131QHwaKBov2DY5/Ff0m+gM1pg+Kp1U0XnSEaLSoWbRXQtse0XLRMtHXogWiT1AguyB/hoouF10kOhX5ME/0uqhd9DtyJE8DcMA3iU5Hsbwjekw0BzmQhwGuFN0lOgS1hZfJHaI3kYEsBmgSPSM6A/XlJdEMeF4au8KPKaKlqP/gyaUws+FceKA1QH/Rq6JnRQNQHrjwviuaJdpT01FzCfAan4PaX+taOmFmw3qXxq4GOEE0WzQEjcEqmLvRd2kNXQxA56VDtDcai7Wio5EyE9LWgEGiuWi8wZP9YXyGqmvCbqgOB38UGpfhooNFryU1qGaA50QXoPHhD9gt+jzuxaRLYLroClRnI8ymhutIi+g20fconq9gHJ8RwWcf6NDnISS46HGLID28lUjesVleQLyRJsC4qCchX14RPSz6NOa1hQ6fxzvDQdGTcdvhB5E+eLIg4fwbgSaLHhUNE/0tWixaJFoDs++nGAfYAyY+YHWA6DiYFbyvaIXoGsQP3PIF0g3AGcMf5v7wyegMGBO8mQt0g+eltOGA6KV9Cz8YQ+C9/N+UdjeLHkE6jDeMFK2zJ6JrwD1wZ4NDG/7KvoMn3yB98ORPuMGZPTN8ImyAsaIz4U4tokmu9FW05QJqQ3G9DDATOoajPIxQtKWxptsDawB6fBdDxzEoD8dCx9X2H2uAydAzBuVhpLI9d7TH8x9rgEugg07QDJSHKdAziX9oAK6M2kDmDXDYatYQ7lbvhI7T+Id+AFf+uYqOjNu3oHxwx0pvb7Bj+y2iAZwBJ0PHfSgn9DYfV7Tn2Mfxz+GKTluRMQxdMLOV7VtogMMUHejPu3pd9YCbom5F+2YaQBPkXIPys0rRdhQNoAkjO0Va68xaRdth9Oc1uYFNKD//KdoOoQHS4oJhNJuOeuESy7A0aXd0/VF+Bina9nD6a6oyNLuueqHZF/yjNcChKDfMXA1UtN9AA/ys6LCP6EiUl/HK9qtpgJ+gwysNXSPOh46KAZbp+uwIJpQMrv6TdF2wlAZYpOtTSZa2onxMg/4u1cHtMBeOX6DjS5QrIsRiDUafh+q6oR9nAN3bhbp+lSSENgBRJMxjagf/gajbusFvQc+9outQf56CXxKX2avtmSGmkH1DXG2iu1F7eL/n4LXRbAtnzHo7A5jV7YAfbUHfWobJGcTtgv/g30ewsw1vhGiMuPsoq6+4ws6HSWYyHrh7pA0zykw2nCXaDFOztxH5wjz/VJgKtethnDJfbkdw+48mR3k3iBZCLRGdgh0uM1d/Vlw0oTpclZlC7wzeQ+twTYQZNL/PZdBtcqrBbHOzPYgagEUOD8R04vpAJ2NxcMz6G6arXTcenEUaL40RXl5Wo5E/V8HMogpxBRK00KiY85zSnOL2lslZ8THSYbSWYbd10HEijL+RJ/zReu0X4qJBUxM608tqDx2zjv9WpPME9IMnnAG5VISHmBY9ERcN+hEmUhxXHcbrkIvc/OCYhUecruOQTBv8a4f6ic5DPvDSbo+eTCqU3A8mAxTnW3MxZGHSX6FznK50iviAhM0acYa8B1O50QM/+H4fITs/wFSb7PQ9qlWKMneWVAJzC0z9T9FwJnYhG8xjjE16n2oR4Q9hVsw4+IBE2m0wDzQR3iR490k0YlpInLeLG2POMwHJ2VF08XTWJ1rORnI1WwWXnAATjnHlM7zWP0OxD01kMQB/+dSst+YDOBNmJbzGKcYFL+z+sv6P1/BE+EN/ZIWuS6WqjINPK+GroLXwhaIXoaseZ+rtf/hBl3W5ov1qmMEvce2gfWSGcQM+PKGp/fMdPNH8QCyNZ3Wp8+CJz0NTXcEHPYnicf1+vC0zKKJ+9Nb3qTFeZ3QrWV6zEsWR9v3ehrlMvH0SXwNYGFdjtoj7hywlsUkkZaO5u2yFWZO0i2Qv8n52+BwYY0wIjp8WXYtscMfJnScXw5dFzyNHYxfx8DRhGS1jBp3IByZlNZUfzmwDAAD//5M94tAAAAAGSURBVAMA4fEEQpAZsWwAAAAASUVORK5CYII=",
    ]
    static func image(_ k: String) -> NSImage? {
        guard let s = png[k], let d = Data(base64Encoded: s), let i = NSImage(data: d) else { return nil }
        i.isTemplate = true; i.size = NSSize(width: 16, height: 16); return i
    }
}

/// Round icon link in a footer (email, social): icon only, name as tooltip.
struct FooterIcon: View {
    let tip: String; let url: URL; var brand: String? = nil; var symbol: String? = nil
    @StateObject private var h = Flag()
    var body: some View {
        Button { NSWorkspace.shared.open(url) } label: {
            Group {
                if let b = brand, let img = BrandIcon.image(b) { Image(nsImage: img).renderingMode(.template).resizable().frame(width: 15, height: 15) }
                else { Image(systemName: symbol ?? "link").font(.system(size: fs(13))) }
            }
            .foregroundColor(h.v ? Theme.brandMint : Theme.sub)
            .frame(width: 30, height: 30).background(Circle().fill(Theme.ink.opacity(h.v ? 0.12 : 0.07)))
        }.buttonStyle(.plain).onHover { h.v = $0 }.tip(tip)
    }
}

struct ContactView: View {
    static let social: [(String, String, String)] = [("Facebook", "facebook", "https://www.facebook.com/tidymintapp"), ("Instagram", "instagram", "https://www.instagram.com/tidymint.app/"),
                                             ("X", "x", "https://x.com/tidymintapp"), ("LinkedIn", "linkedin", "https://www.linkedin.com/company/tidymint/"),
                                             ("GitHub", "github", "https://github.com/HaiTrung-Workspace/tidymint")]
    @ObservedObject var vm: VM
    @StateObject private var f = FormState()
    var body: some View {
      VStack(spacing: 0) {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Contact the developer", "Liên hệ nhà phát triển")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text)
                    Text(t("Feedback, bug reports and questions go straight to the developer. An email address is needed so you can get a reply.",
                           "Góp ý, báo lỗi, câu hỏi đều tới thẳng nhà phát triển. Cần email để có thể trả lời bạn."))
                        .foregroundColor(Theme.sub).font(.system(size: fs(12)))
                }.padding(.top, 34)
                Picker("", selection: $f.kind) {
                    Text(t("Feedback", "Góp ý")).tag("feedback")
                    Text(t("Bug report", "Báo lỗi")).tag("bug")
                    Text(t("Question", "Câu hỏi")).tag("question")
                }.pickerStyle(.segmented).labelsHidden().controlSize(.small).fixedSize()
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
                    TextLink(t("Report a bug on GitHub", "Báo lỗi trên GitHub"), url: URL(string: "https://github.com/HaiTrung-Workspace/tidymint/issues")!)
                    if f.sending { ProgressView().controlSize(.small).tint(Theme.text) }
                    Spacer()
                    // Return (outside the message box) = the main button.
                    GhostButton(title: t("Send Only", "Chỉ gửi"), action: { submit(newsletter: false) }).disabled(f.sending)
                    PrimaryButton(title: t("Send & Subscribe", "Gửi và nhận bản tin"), action: { submit(newsletter: true) }, disabled: f.sending)
                        .keyboardShortcut(.defaultAction)
                }
                // The newsletter consent stays right under the button it belongs to.
                HStack(spacing: 6) {
                    Spacer()
                    Text(Backend.newsletterText).font(.system(size: fs(11))).foregroundColor(Theme.sub)
                    if let u = URL(string: Backend.privacyURL), !Backend.privacyURL.isEmpty {
                        TextLink(t("Privacy", "Quyền riêng tư"), url: u, size: 11)
                    }
                }
            }.padding(.horizontal, 24).padding(.bottom, 24)
        }
        // Footer: email and brand accounts as icons (plain links: nothing loads until clicked).
        RowLine()
        HStack(spacing: 8) {
            Spacer()
            FooterIcon(tip: "hello@tidymint.app", url: URL(string: "mailto:hello@tidymint.app")!, symbol: "envelope")
            ForEach(ContactView.social, id: \.1) { s in FooterIcon(tip: s.0, url: URL(string: s.2)!, brand: s.1) }
        }.padding(.horizontal, 24).padding(.vertical, 12)
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

// MARK: - Free space chart (Stats page)

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
        // Built step by step: one long + chain is too slow for some Swift versions to type-check.
        let selText: String? = sel.map { d in
            var s = dm.string(from: d.date) + ": " + t("free ", "trống ")
            s += String(format: "%.0f GB", d.free)
            if d.freed > 0 { s += t(", cleaned ", ", đã dọn ") + fmt(d.freed) }
            return s
        }
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t("Free space per day (GB)", "Dung lượng trống mỗi ngày (GB)")).font(.system(size: fs(12), weight: .semibold)).foregroundColor(Theme.sub)
                Spacer()
                if let s = selText {
                    Text(s).font(.system(size: fs(11), weight: .semibold)).foregroundColor(Theme.text)
                }
                Picker("", selection: $pick.days) {
                    Text(t("7 days", "7 ngày")).tag(7); Text(t("30 days", "30 ngày")).tag(30); Text(t("90 days", "90 ngày")).tag(90)
                }.pickerStyle(.segmented).controlSize(.small).fixedSize()
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
        }.padding(14).background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
    }
}
