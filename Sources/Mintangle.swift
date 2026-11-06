// Mintangle: arrange windows with keyboard shortcuts (0.5.0, hidden behind featureMintangle until release).
// Off by default. Turning it on asks for Accessibility permission, which macOS requires for moving and resizing
// the windows of other apps. Nothing is read from window contents; only the frontmost window's position and size.
// Calculations follow Rectangle (MIT, Copyright (c) 2019-2026 Ryan Hanson) in spirit; the code here is written for Tidymint.
import AppKit
import Carbon
import SwiftUI

var featureMintangle: Bool { true }   // released in 0.5.0 (was a dev-mintangle flag); stays off until the user turns it on

enum MTAction: Int, CaseIterable, Identifiable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case firstThird, centerThird, lastThird, firstTwoThirds, lastTwoThirds
    case maximize, almostMaximize, maximizeHeight, center, larger, smaller, restore
    case nextDisplay, previousDisplay
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .leftHalf: return t("Left half", "Nửa trái")
        case .rightHalf: return t("Right half", "Nửa phải")
        case .topHalf: return t("Top half", "Nửa trên")
        case .bottomHalf: return t("Bottom half", "Nửa dưới")
        case .topLeft: return t("Top left", "Góc trên bên trái")
        case .topRight: return t("Top right", "Góc trên bên phải")
        case .bottomLeft: return t("Bottom left", "Góc dưới bên trái")
        case .bottomRight: return t("Bottom right", "Góc dưới bên phải")
        case .firstThird: return t("First third", "1/3 bên trái")
        case .centerThird: return t("Center third", "1/3 ở giữa")
        case .lastThird: return t("Last third", "1/3 bên phải")
        case .firstTwoThirds: return t("First two thirds", "2/3 bên trái")
        case .lastTwoThirds: return t("Last two thirds", "2/3 bên phải")
        case .maximize: return t("Maximize", "Phóng to hết")
        case .almostMaximize: return t("Almost maximize", "Gần kín màn hình")
        case .maximizeHeight: return t("Maximize height", "Cao hết màn hình")
        case .center: return t("Center", "Căn giữa")
        case .larger: return t("Larger", "To thêm")
        case .smaller: return t("Smaller", "Nhỏ lại")
        case .restore: return t("Restore", "Trả về cỡ cũ")
        case .nextDisplay: return t("Next display", "Sang màn hình kế tiếp")
        case .previousDisplay: return t("Previous display", "Về màn hình trước")
        }
    }

    /// Same defaults as Rectangle, so people who switch keep their muscle memory. (keyCode, Carbon modifiers)
    var shortcut: (UInt32, UInt32) {
        let co = UInt32(controlKey | optionKey)
        switch self {
        case .leftHalf: return (UInt32(kVK_LeftArrow), co)
        case .rightHalf: return (UInt32(kVK_RightArrow), co)
        case .topHalf: return (UInt32(kVK_UpArrow), co)
        case .bottomHalf: return (UInt32(kVK_DownArrow), co)
        case .topLeft: return (UInt32(kVK_ANSI_U), co)
        case .topRight: return (UInt32(kVK_ANSI_I), co)
        case .bottomLeft: return (UInt32(kVK_ANSI_J), co)
        case .bottomRight: return (UInt32(kVK_ANSI_K), co)
        case .firstThird: return (UInt32(kVK_ANSI_D), co)
        case .centerThird: return (UInt32(kVK_ANSI_F), co)
        case .lastThird: return (UInt32(kVK_ANSI_G), co)
        case .firstTwoThirds: return (UInt32(kVK_ANSI_E), co)
        case .lastTwoThirds: return (UInt32(kVK_ANSI_T), co)
        case .maximize: return (UInt32(kVK_Return), co)
        case .almostMaximize: return (UInt32(kVK_Return), co | UInt32(shiftKey))
        case .maximizeHeight: return (UInt32(kVK_UpArrow), co | UInt32(shiftKey))
        case .center: return (UInt32(kVK_ANSI_C), co)
        case .larger: return (UInt32(kVK_ANSI_Equal), co)
        case .smaller: return (UInt32(kVK_ANSI_Minus), co)
        case .restore: return (UInt32(kVK_Delete), co)
        case .nextDisplay: return (UInt32(kVK_RightArrow), co | UInt32(cmdKey))
        case .previousDisplay: return (UInt32(kVK_LeftArrow), co | UInt32(cmdKey))
        }
    }

    var defaultKey: MTKey { let (k, m) = shortcut; return MTKey(code: k, mods: m, char: MTKey.defaultChar(k)) }

    /// Groups for the Settings list.
    static let groups: [[MTAction]] = [
        [.leftHalf, .rightHalf, .topHalf, .bottomHalf],
        [.topLeft, .topRight, .bottomLeft, .bottomRight],
        [.firstThird, .centerThird, .lastThird, .firstTwoThirds, .lastTwoThirds],
        [.maximize, .almostMaximize, .maximizeHeight, .center, .larger, .smaller, .restore],
        [.nextDisplay, .previousDisplay]]
}

/// One keyboard shortcut: key code and Carbon modifiers, plus the character shown for keys without a symbol.
struct MTKey: Equatable {
    var code: UInt32
    var mods: UInt32
    var char: String

    static let special: [UInt32: (sym: String, en: String, vi: String)] = [
        UInt32(kVK_LeftArrow): ("←", "Left Arrow", "Mũi tên trái"), UInt32(kVK_RightArrow): ("→", "Right Arrow", "Mũi tên phải"),
        UInt32(kVK_UpArrow): ("↑", "Up Arrow", "Mũi tên lên"), UInt32(kVK_DownArrow): ("↓", "Down Arrow", "Mũi tên xuống"),
        UInt32(kVK_Return): ("↩", "Return", "Return"), UInt32(kVK_Delete): ("⌫", "Delete", "Delete"),
        UInt32(kVK_ForwardDelete): ("⌦", "Forward Delete", "Xoá tới"), UInt32(kVK_Space): ("Space", "Space", "Phím cách"),
        UInt32(kVK_Tab): ("⇥", "Tab", "Tab"), UInt32(kVK_Home): ("↖", "Home", "Home"), UInt32(kVK_End): ("↘", "End", "End"),
        UInt32(kVK_PageUp): ("⇞", "Page Up", "Page Up"), UInt32(kVK_PageDown): ("⇟", "Page Down", "Page Down")]
    static let letters: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C", UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E",
        UInt32(kVK_ANSI_F): "F", UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I", UInt32(kVK_ANSI_J): "J",
        UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L", UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R", UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T",
        UInt32(kVK_ANSI_U): "U", UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X", UInt32(kVK_ANSI_Y): "Y",
        UInt32(kVK_ANSI_Z): "Z", UInt32(kVK_ANSI_Equal): "=", UInt32(kVK_ANSI_Minus): "-"]
    static func defaultChar(_ code: UInt32) -> String { letters[code] ?? special[code]?.sym ?? "?" }

    var keyName: String { Self.special[code]?.sym ?? char }
    var label: String {
        var s = ""
        if mods & UInt32(controlKey) != 0 { s += "⌃" }
        if mods & UInt32(optionKey) != 0 { s += "⌥" }
        if mods & UInt32(shiftKey) != 0 { s += "⇧" }
        if mods & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + keyName
    }
    /// Spelled out for the hover tip: "Control + Option + ←" (arrows stay as symbols).
    var spoken: String {
        var p: [String] = []
        if mods & UInt32(controlKey) != 0 { p.append("Control") }
        if mods & UInt32(optionKey) != 0 { p.append("Option") }
        if mods & UInt32(shiftKey) != 0 { p.append("Shift") }
        if mods & UInt32(cmdKey) != 0 { p.append("Command") }
        let arrows: Set<UInt32> = [UInt32(kVK_LeftArrow), UInt32(kVK_RightArrow), UInt32(kVK_UpArrow), UInt32(kVK_DownArrow)]
        p.append(arrows.contains(code) ? keyName : (Self.special[code].map { t($0.en, $0.vi) } ?? char))
        return p.joined(separator: " + ")
    }
    /// Cocoa modifier flags (NSEvent, symbolic hotkeys) to Carbon modifiers.
    static func carbon(_ f: UInt) -> UInt32 {
        var m: UInt32 = 0
        if f & NSEvent.ModifierFlags.control.rawValue != 0 { m |= UInt32(controlKey) }
        if f & NSEvent.ModifierFlags.option.rawValue != 0 { m |= UInt32(optionKey) }
        if f & NSEvent.ModifierFlags.shift.rawValue != 0 { m |= UInt32(shiftKey) }
        if f & NSEvent.ModifierFlags.command.rawValue != 0 { m |= UInt32(cmdKey) }
        return m
    }
    var stored: String { "\(code),\(mods),\(char)" }
    init(code: UInt32, mods: UInt32, char: String) { self.code = code; self.mods = mods; self.char = char }
    init?(stored: String) {
        let p = stored.split(separator: ",", maxSplits: 2, omittingEmptySubsequences: false)
        guard p.count == 3, let c = UInt32(p[0]), let m = UInt32(p[1]) else { return nil }
        code = c; mods = m; char = String(p[2])
    }
}

/// Shortcuts of macOS itself (System Settings › Keyboard › Keyboard Shortcuts) that use the same keys.
enum MTSystemShortcuts {
    /// Names of the common ones, by symbolic hotkey id, with the section they live in.
    static let names: [Int: (en: String, vi: String, secEN: String, secVI: String)] = [
        32: ("Mission Control", "Mission Control", "Mission Control", "Mission Control"),
        33: ("Application windows", "Cửa sổ ứng dụng", "Mission Control", "Mission Control"),
        36: ("Show Desktop", "Hiển thị màn hình nền", "Mission Control", "Mission Control"),
        79: ("Move left a space", "Sang trái một không gian", "Mission Control", "Mission Control"),
        80: ("Move left a space", "Sang trái một không gian", "Mission Control", "Mission Control"),
        81: ("Move right a space", "Sang phải một không gian", "Mission Control", "Mission Control"),
        82: ("Move right a space", "Sang phải một không gian", "Mission Control", "Mission Control"),
        60: ("Select the previous input source", "Chọn nguồn đầu vào trước", "Input Sources", "Nguồn đầu vào"),
        61: ("Select next source in Input menu", "Chọn nguồn kế tiếp", "Input Sources", "Nguồn đầu vào"),
        64: ("Show Spotlight search", "Hiện tìm kiếm Spotlight", "Spotlight", "Spotlight"),
        65: ("Show Finder search window", "Hiện cửa sổ tìm kiếm Finder", "Spotlight", "Spotlight"),
        28: ("Save picture of screen", "Lưu ảnh màn hình", "Screenshots", "Ảnh màn hình"),
        29: ("Copy picture of screen", "Sao chép ảnh màn hình", "Screenshots", "Ảnh màn hình"),
        30: ("Save picture of selected area", "Lưu ảnh vùng được chọn", "Screenshots", "Ảnh màn hình"),
        31: ("Copy picture of selected area", "Sao chép ảnh vùng được chọn", "Screenshots", "Ảnh màn hình"),
        184: ("Screenshot and recording options", "Tuỳ chọn chụp và ghi màn hình", "Screenshots", "Ảnh màn hình")]

    /// Enabled system shortcuts as (id, key).
    static func enabled() -> [(Int, MTKey)] {
        guard let d = UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys") else { return [] }
        var out: [(Int, MTKey)] = []
        for (k, v) in d {
            guard let id = Int(k), let e = v as? [String: Any], (e["enabled"] as? Bool) ?? (e["enabled"] as? Int == 1),
                  let val = e["value"] as? [String: Any], let p = val["parameters"] as? [Int], p.count >= 3, p[1] != 65535 else { continue }
            out.append((id, MTKey(code: UInt32(p[1]), mods: MTKey.carbon(UInt(p[2])), char: "")))
        }
        return out
    }
    static func title(_ id: Int) -> String {
        if let n = names[id] { return t(n.en, n.vi) }
        if (118...133).contains(id) { return t("Switch to Desktop \(id - 117)", "Chuyển sang màn hình nền \(id - 117)") }
        return t("System shortcut #\(id)", "Phím tắt hệ thống số \(id)")
    }
    static func section(_ id: Int) -> String {
        if let n = names[id] { return t(n.secEN, n.secVI) }
        if (118...133).contains(id) { return "Mission Control" }
        return t("Keyboard Shortcuts", "Phím tắt bàn phím")
    }
    /// System Settings › Keyboard (the Keyboard Shortcuts… button is on that pane).
    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!
}

/// Records a new shortcut for one action: the next key press with Control, Option or Command.
/// Esc cancels, Delete alone clears the shortcut. Mintangle's own hotkeys are paused meanwhile, or they would fire.
final class MTRecorder: ObservableObject {
    static let shared = MTRecorder()
    @Published var action: MTAction?
    @Published var hint: String?
    /// Row under the pointer (for the spelled-out hint under each cluster).
    @Published var hover: MTAction?
    func start(_ a: MTAction) {
        if action != nil { stop() }
        action = a; hint = nil
        Mintangle.shared.pause(true)
    }
    /// One key press while recording. Returns true when the event was used.
    func handle(_ e: NSEvent) -> Bool {
        guard let a = action, e.type == .keyDown else { return false }
        let f = e.modifierFlags.intersection([.control, .option, .shift, .command])
        if e.keyCode == 53 { stop(); return true }
        if (e.keyCode == 51 || e.keyCode == 117) && f.isEmpty { Mintangle.shared.setKey(a, nil); stop(); return true }
        // macOS 15+ refuses a global shortcut whose only modifiers are Shift and Option (RegisterEventHotKey error -9868,
        // Apple Developer Forums thread 763878), so require Control or Command on every macOS we support.
        guard !f.intersection([.control, .command]).isEmpty else {
            hint = t("Hold Control or Command (Option and Shift can be added), then press a key. Esc cancels.", "Giữ Control hoặc Command (thêm Option, Shift tuỳ ý) rồi bấm một phím. Esc để huỷ."); return true
        }
        let ch = (e.charactersIgnoringModifiers ?? "").uppercased()
        let k = MTKey(code: UInt32(e.keyCode), mods: MTKey.carbon(f.rawValue), char: MTKey.letters[UInt32(e.keyCode)] ?? (ch.isEmpty ? "?" : ch))
        Mintangle.shared.setKey(a, k)
        stop()
        return true
    }
    func stop() {
        hint = nil
        if action != nil { action = nil; Mintangle.shared.pause(false) }
    }
}

/// AppKit layer over one shortcut row: native tooltip, pointer tracking, and the key recorder.
/// A real first-responder view (like Rectangle's MASShortcutView) gets every key press, including ones with Command
/// that SwiftUI would hand to the menu bar.
final class MTRowNSView: NSView {
    var action: MTAction = .leftHalf
    var editable = true
    /// Keys spelled out, shown in the app's own tooltip bubble right under the keycap.
    var tip = ""
    private var area: NSTrackingArea?
    private var pending: DispatchWorkItem?
    private func showTip() {
        pending?.cancel()
        guard !tip.isEmpty, MTRecorder.shared.action != action, let w = window else { return }
        let i = DispatchWorkItem { [weak self] in
            guard let self, let w = self.window else { return }
            let r = w.convertToScreen(self.convert(self.bounds, to: nil))
            // The keycap sits at the right end of the row.
            TipPanel.shared.show(self.tip, owner: ObjectIdentifier(self), below: NSRect(x: r.maxX - 110, y: r.minY, width: 110, height: r.height))
        }
        _ = w; pending = i
        DispatchQueue.main.asyncAfter(deadline: .now() + TipPanel.shared.delay, execute: i)
    }
    private func hideTip() { pending?.cancel(); pending = nil; TipPanel.shared.hide(owner: ObjectIdentifier(self)) }
    override var acceptsFirstResponder: Bool { editable }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area { removeTrackingArea(area) }
        let a = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(a); area = a
    }
    override func mouseEntered(with event: NSEvent) { MTRecorder.shared.hover = action; showTip() }
    override func mouseExited(with event: NSEvent) { if MTRecorder.shared.hover == action { MTRecorder.shared.hover = nil }; hideTip() }
    override func mouseDown(with event: NSEvent) {
        hideTip()
        guard editable else { return }
        // Clicking the row being recorded keeps recording (a second click must not cancel it); Esc or a click elsewhere cancels.
        if MTRecorder.shared.action != action { MTRecorder.shared.start(action) }
        window?.makeFirstResponder(self)
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard MTRecorder.shared.action == action else { return false }
        let used = MTRecorder.shared.handle(event)
        if MTRecorder.shared.action == nil { window?.makeFirstResponder(nil) }
        return used
    }
    override func keyDown(with event: NSEvent) {
        guard MTRecorder.shared.action == action else { super.keyDown(with: event); return }
        _ = MTRecorder.shared.handle(event)
        if MTRecorder.shared.action == nil { window?.makeFirstResponder(nil) }
    }
    override func resignFirstResponder() -> Bool {
        if MTRecorder.shared.action == action { MTRecorder.shared.stop() }
        return true
    }
}

struct MTRowCatcher: NSViewRepresentable {
    let action: MTAction
    let tip: String
    let editable: Bool
    func makeNSView(context: Context) -> MTRowNSView { let v = MTRowNSView(); updateNSView(v, context: context); return v }
    func updateNSView(_ v: MTRowNSView, context: Context) { v.action = action; v.editable = editable; v.tip = tip }
}

/// What pressing the same half/corner shortcut again does.
enum MTRepeat: String, CaseIterable { case resize, display, none }

final class Mintangle: ObservableObject {
    static let shared = Mintangle()
    private let d = UserDefaults.standard

    /// The user's choice. Shortcuts only work while this is on AND Accessibility is granted.
    @Published var enabled: Bool { didSet { d.set(enabled, forKey: "mt.enabled"); apply() } }
    @Published var gap: Double { didSet { d.set(gap, forKey: "mt.gap") } }
    @Published var repeatMode: MTRepeat { didSet { d.set(repeatMode.rawValue, forKey: "mt.repeat") } }
    @Published var ignored: [String] { didSet { d.set(ignored, forKey: "mt.ignore") } }
    /// Drag a window to a screen edge or corner to snap it (needs the same Accessibility permission).
    @Published var snapDrag: Bool { didSet { d.set(snapDrag, forKey: "mt.snapDrag"); apply() } }
    /// Dragging a snapped window away gives it back the size it had before.
    @Published var unsnapRestore: Bool { didSet { d.set(unsnapRestore, forKey: "mt.unsnapRestore") } }
    /// macOS 15+ has its own drag-to-edge tiling; both reacting to one drag fights, so the page warns.
    @Published private(set) var macTiling = false
    @Published private(set) var trusted = AXIsProcessTrusted()
    var trustedNow: Bool { AXIsProcessTrusted() }
    /// Shortcuts macOS refused (another app holds them), shown in Settings.
    @Published private(set) var failed: [MTAction] = []
    /// Other window managers running now (names) and their bundle ids.
    @Published private(set) var rivals: [String] = []
    @Published private(set) var rivalIDsRunning: [String] = []
    /// Shortcuts the user changed (action raw value -> key) and the ones turned off.
    @Published private(set) var custom: [Int: MTKey] = [:]
    @Published private(set) var off: Set<Int> = []
    /// Mintangle shortcuts that macOS itself also uses: action -> system shortcut id.
    @Published private(set) var systemClash: [MTAction: Int] = [:]
    private var paused = false

    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var poll: Timer?
    /// Frame before the first arrange, per window, for Restore and for "unsnap".
    var original: [Int: CGRect] = [:]
    /// Frame Mintangle last gave each window, to tell "still snapped" from "moved by hand".
    var snapped: [Int: CGRect] = [:]
    let snapper = MTSnapper()
    private var last: (action: MTAction, window: Int, frame: CGRect, step: Int, time: Date)?

    static let rivalIDs: [String: String] = [
        "com.knollsoft.Rectangle": "Rectangle", "com.knollsoft.Hookshot": "Hookshot",
        "com.crowdcafe.windowmagnet": "Magnet", "com.divisiblebyzero.Spectacle": "Spectacle",
        "com.manytricks.Moom": "Moom"]

    private init() {
        enabled = d.bool(forKey: "mt.enabled")
        gap = d.object(forKey: "mt.gap") as? Double ?? 0
        repeatMode = MTRepeat(rawValue: d.string(forKey: "mt.repeat") ?? "") ?? .resize
        ignored = d.stringArray(forKey: "mt.ignore") ?? []
        snapDrag = d.object(forKey: "mt.snapDrag") as? Bool ?? true
        unsnapRestore = d.object(forKey: "mt.unsnapRestore") as? Bool ?? true
        for (k, v) in (d.dictionary(forKey: "mt.keys") as? [String: String]) ?? [:] { if let i = Int(k), let key = MTKey(stored: v) { custom[i] = key } }
        off = Set((d.array(forKey: "mt.off") as? [Int]) ?? [])
    }

    // MARK: Lifecycle

    /// Called at launch and whenever the switch or the permission changes.
    func apply() {
        guard featureMintangle else { unregister(); return }
        trusted = AXIsProcessTrusted()
        refreshRivals()
        if #available(macOS 15, *) {
            macTiling = (UserDefaults(suiteName: "com.apple.WindowManager")?.object(forKey: "EnableTilingByEdgeDrag") as? Bool) ?? true
        } else { macTiling = false }
        refreshSystemClash()
        if enabled && trusted && !paused { register() } else { unregister() }
        if enabled && trusted && snapDrag { snapper.start() } else { snapper.stop() }
        if enabled && !trusted { waitForPermission() }
    }

    /// Turning the switch on asks macOS for Accessibility (the system prompt opens System Settings).
    func setEnabled(_ on: Bool) {
        if on && !AXIsProcessTrusted() {
            let opt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opt)
        }
        enabled = on
    }

    static let desktopSettings = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension")!
    static let accessibilitySettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    /// After asking, check every 1.5 s for up to 3 minutes; the app is also re-checked when it becomes active.
    private func waitForPermission() {
        poll?.invalidate()
        var n = 0
        poll = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] tm in
            n += 1
            guard let self else { tm.invalidate(); return }
            if AXIsProcessTrusted() { tm.invalidate(); self.apply() }
            else if n > 120 || !self.enabled { tm.invalidate() }
        }
    }

    func refreshRivals() {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let found = Self.rivalIDs.filter { running.contains($0.key) }
        rivals = found.map(\.value).sorted()
        rivalIDsRunning = found.map(\.key)
    }

    /// Quits another window manager (the user pressed its button on the page).
    func quitRival(_ id: String) {
        NSRunningApplication.runningApplications(withBundleIdentifier: id).forEach { $0.terminate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.refreshRivals(); self.apply() }
    }

    func key(for a: MTAction) -> MTKey? { off.contains(a.rawValue) ? nil : (custom[a.rawValue] ?? a.defaultKey) }

    /// New key for one action (nil = no shortcut). The same keys are taken away from any other action.
    func setKey(_ a: MTAction, _ k: MTKey?) {
        if let k {
            for b in MTAction.allCases where b != a { if let kb = key(for: b), kb.code == k.code, kb.mods == k.mods { off.insert(b.rawValue); custom[b.rawValue] = nil } }
            off.remove(a.rawValue)
            custom[a.rawValue] = k == a.defaultKey ? nil : k
        } else { off.insert(a.rawValue); custom[a.rawValue] = nil }
        save(); apply()
    }
    func resetKeys() { custom = [:]; off = []; save(); apply() }
    private func save() {
        d.set(Dictionary(uniqueKeysWithValues: custom.map { (String($0.key), $0.value.stored) }), forKey: "mt.keys")
        d.set(Array(off), forKey: "mt.off")
    }
    func refreshSystemClash() {
        let sys = MTSystemShortcuts.enabled()
        var c: [MTAction: Int] = [:]
        for a in MTAction.allCases { if let k = key(for: a), let hit = sys.first(where: { $0.1.code == k.code && $0.1.mods == k.mods }) { c[a] = hit.0 } }
        systemClash = c
    }
    /// While a new shortcut is being recorded, Mintangle's own hotkeys must not fire.
    func pause(_ on: Bool) { paused = on; if on { unregister() } else { apply() } }

    private func register() {
        unregister()
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, ev, _ in
                var hk = EventHotKeyID()
                let st = GetEventParameter(ev, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
                // Other features (Shelf) register their own hotkeys: let their handler take those.
                guard st == noErr, hk.signature == OSType(0x4D4E_5447) else { return OSStatus(eventNotHandledErr) }
                if let a = MTAction(rawValue: Int(hk.id)) { DispatchQueue.main.async { Mintangle.shared.run(a) } }
                return noErr
            }, 1, &spec, nil, &handler)
        }
        var bad: [MTAction] = []
        for a in MTAction.allCases {
            var ref: EventHotKeyRef?
            guard let key = key(for: a) else { continue }
            let st = RegisterEventHotKey(key.code, key.mods, EventHotKeyID(signature: OSType(0x4D4E_5447), id: UInt32(a.rawValue)),
                                         GetApplicationEventTarget(), 0, &ref)
            if st == noErr, let ref { refs.append(ref) } else { bad.append(a) }
        }
        failed = bad
    }

    private func unregister() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs = []; failed = []
    }

    // MARK: Ignore list

    func ignoreFrontmostCandidates() -> [(id: String, name: String)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { a in a.bundleIdentifier.map { ($0, a.localizedName ?? $0) } }
            .filter { !ignored.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    func appName(_ id: String) -> String {
        if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) { return FileManager.default.displayName(atPath: u.path).replacingOccurrences(of: ".app", with: "") }
        return id
    }

    // MARK: Arranging

    func run(_ a: MTAction) {
        guard enabled, AXIsProcessTrusted() else { return }
        guard let app = NSWorkspace.shared.frontmostApplication, let bid = app.bundleIdentifier,
              !ignored.contains(bid) else { return }
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        guard let win = Self.focusedWindow(appEl), let cur = Self.frame(of: win) else { return }
        let key = Int(CFHash(win))
        let screens = NSScreen.screens
        guard let screen = Self.screen(for: cur, in: screens) else { return }

        var action = a
        var step = 0
        var target = screen
        // The same shortcut again on the same, untouched window: cycle size or move to the next display.
        if let l = last, l.action == a, l.window == key, Self.close(l.frame, cur), Date().timeIntervalSince(l.time) < 30, a.repeats {
            switch repeatMode {
            case .resize: step = (l.step + 1) % 3
            case .display:
                let side: CGFloat = (a == .leftHalf || a == .topLeft || a == .bottomLeft || a == .firstThird || a == .firstTwoThirds) ? -1 : 1
                if a == .leftHalf || a == .rightHalf || a.isCorner, let s = Self.neighbour(of: screen, side: side, in: screens) {
                    target = s; action = a.mirrored
                }
            case .none: break
            }
        }

        var r: CGRect
        switch action {
        case .restore:
            guard let o = original[key] else { return }
            Self.set(win, app: appEl, o); original[key] = nil; snapped[key] = nil; last = nil; return
        case .nextDisplay, .previousDisplay:
            guard screens.count > 1, let i = screens.firstIndex(of: screen) else { return }
            let dest = screens[(i + (action == .nextDisplay ? 1 : screens.count - 1)) % screens.count]
            let from = screen.visibleFrame, to = dest.visibleFrame
            if let l = last, l.window == key, Self.close(l.frame, cur), l.action.hasLayout {
                r = l.action.rect(in: to, step: l.step, gap: gap, current: cur); action = l.action; step = l.step
            } else {
                let w = min(cur.width, to.width), h = min(cur.height, to.height)
                let fx = from.width > cur.width ? (cur.minX - from.minX) / (from.width - cur.width) : 0
                let fy = from.height > cur.height ? (cur.minY - from.minY) / (from.height - cur.height) : 0
                r = CGRect(x: to.minX + max(0, min(1, fx)) * (to.width - w), y: to.minY + max(0, min(1, fy)) * (to.height - h), width: w, height: h)
            }
        default:
            r = action.rect(in: target.visibleFrame, step: step, gap: gap, current: cur)
        }
        if original[key] == nil { original[key] = cur }
        Self.set(win, app: appEl, r)
        snapped[key] = Self.frame(of: win) ?? r
        // Remember the pressed shortcut (or, after a display move, the layout re-applied there) for the next press.
        let remembered = (a == .nextDisplay || a == .previousDisplay) ? action : a
        last = (remembered, key, Self.frame(of: win) ?? r, step, Date())
    }

    // MARK: Accessibility helpers (Cocoa coordinates: origin bottom-left of the main screen)

    static func focusedWindow(_ app: AXUIElement) -> AXUIElement? {
        var v: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &v) == .success, let v { return (v as! AXUIElement) }
        if AXUIElementCopyAttributeValue(app, kAXMainWindowAttribute as CFString, &v) == .success, let v { return (v as! AXUIElement) }
        return nil
    }

    private static var mainHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    static func frame(of w: AXUIElement) -> CGRect? {
        var p: CFTypeRef?, s: CFTypeRef?
        guard AXUIElementCopyAttributeValue(w, kAXPositionAttribute as CFString, &p) == .success,
              AXUIElementCopyAttributeValue(w, kAXSizeAttribute as CFString, &s) == .success, let p, let s else { return nil }
        var pt = CGPoint.zero, sz = CGSize.zero
        AXValueGetValue(p as! AXValue, .cgPoint, &pt); AXValueGetValue(s as! AXValue, .cgSize, &sz)
        return CGRect(x: pt.x, y: mainHeight - pt.y - sz.height, width: sz.width, height: sz.height)
    }

    /// Position, size, position again: some apps clamp the size to the screen they are on before moving.
    /// Apps with AXEnhancedUserInterface on (Chrome, Electron with VoiceOver hooks) animate and jump while it is on,
    /// so it is switched off for the move and back on after (the fix Rectangle uses).
    static func set(_ w: AXUIElement, app: AXUIElement, _ r: CGRect) {
        let eui = "AXEnhancedUserInterface" as CFString
        var cur: CFTypeRef?
        let had = AXUIElementCopyAttributeValue(app, eui, &cur) == .success && (cur as? Bool) == true
        if had { AXUIElementSetAttributeValue(app, eui, kCFBooleanFalse) }
        var pt = CGPoint(x: r.minX, y: mainHeight - r.maxY), sz = r.size
        if let pv = AXValueCreate(.cgPoint, &pt) { AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, pv) }
        if let sv = AXValueCreate(.cgSize, &sz) { AXUIElementSetAttributeValue(w, kAXSizeAttribute as CFString, sv) }
        if let pv = AXValueCreate(.cgPoint, &pt) { AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, pv) }
        if had { AXUIElementSetAttributeValue(app, eui, kCFBooleanTrue) }
    }

    static func screen(for r: CGRect, in screens: [NSScreen]) -> NSScreen? {
        screens.max { a, b in
            let ia = a.frame.intersection(r), ib = b.frame.intersection(r)
            return (ia.isNull ? 0 : ia.width * ia.height) < (ib.isNull ? 0 : ib.width * ib.height)
        }
    }

    static func neighbour(of s: NSScreen, side: CGFloat, in screens: [NSScreen]) -> NSScreen? {
        let others = screens.filter { $0 != s && (side < 0 ? $0.frame.midX < s.frame.midX : $0.frame.midX > s.frame.midX) }
        return others.min { abs($0.frame.midX - s.frame.midX) < abs($1.frame.midX - s.frame.midX) }
    }

    static func close(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 3 && abs(a.minY - b.minY) < 3 && abs(a.width - b.width) < 3 && abs(a.height - b.height) < 3
    }
}

// MARK: Drag to snap

/// Watches mouse drags while Mintangle is on. When a window is being moved (its size stays the same) and the pointer
/// touches a screen edge or corner, a translucent footprint shows where it will land; letting go there snaps it.
/// Same zones as Rectangle: left/right edge = half, top = maximize, corners = quarter, bottom edge = third under the pointer.
final class MTSnapper {
    private var monitor: Any?
    private var win: AXUIElement?
    private var app: AXUIElement?
    private var startFrame: CGRect = .zero
    private var moving = false
    private var zone: MTAction?
    private var zoneScreen: NSScreen?
    private var lastRead = Date.distantPast
    private let footprint = MTFootprint()

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] e in
            switch e.type {
            case .leftMouseDown: self?.down()
            case .leftMouseDragged: self?.drag()
            case .leftMouseUp: self?.up()
            default: break
            }
        }
    }
    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil; reset()
    }
    private func reset() { win = nil; app = nil; moving = false; zone = nil; footprint.hide() }

    /// The window under the pointer, if it belongs to an app that is not on the ignore list.
    private func down() {
        reset()
        let p = NSEvent.mouseLocation
        let sys = AXUIElementCreateSystemWide()
        var el: AXUIElement?
        let h = NSScreen.screens.first?.frame.height ?? 0
        guard AXUIElementCopyElementAtPosition(sys, Float(p.x), Float(h - p.y), &el) == .success, let el else { return }
        var pid: pid_t = 0
        AXUIElementGetPid(el, &pid)
        guard pid != ProcessInfo.processInfo.processIdentifier,
              let bid = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier,
              !Mintangle.shared.ignored.contains(bid) else { return }
        var w: CFTypeRef?
        var target: AXUIElement?
        if AXUIElementCopyAttributeValue(el, kAXWindowAttribute as CFString, &w) == .success, let w { target = (w as! AXUIElement) }
        else {
            var role: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &role) == .success, (role as? String) == kAXWindowRole { target = el }
        }
        guard let target, let f = Mintangle.frame(of: target) else { return }
        win = target; app = AXUIElementCreateApplication(pid); startFrame = f
    }

    private func drag() {
        guard let win else { return }
        if !moving {
            // Only start once the window really moves without changing size (a move, not a resize or a text drag).
            guard Date().timeIntervalSince(lastRead) > 0.03 else { return }
            lastRead = Date()
            guard let f = Mintangle.frame(of: win) else { return }
            guard abs(f.width - startFrame.width) < 2, abs(f.height - startFrame.height) < 2,
                  abs(f.minX - startFrame.minX) > 2 || abs(f.minY - startFrame.minY) > 2 else { return }
            moving = true
            unsnapIfNeeded(win, current: f)
        }
        let p = NSEvent.mouseLocation
        if let (a, s) = Self.zone(at: p) {
            if a != zone || s != zoneScreen {
                zone = a; zoneScreen = s
                footprint.show(a.rect(in: s.visibleFrame, step: 0, gap: Mintangle.shared.gap, current: startFrame))
            }
        } else if zone != nil { zone = nil; footprint.hide() }
    }

    private func up() {
        defer { reset() }
        guard moving, let win, let app, let zone, let s = zoneScreen else { return }
        let m = Mintangle.shared
        let key = Int(CFHash(win))
        let cur = Mintangle.frame(of: win) ?? startFrame
        if m.original[key] == nil { m.original[key] = startFrame.size == cur.size ? startFrame : cur }
        let r = zone.rect(in: s.visibleFrame, step: 0, gap: m.gap, current: cur)
        Mintangle.set(win, app: app, r)
        m.snapped[key] = Mintangle.frame(of: win) ?? r
    }

    /// A window Mintangle had snapped and that is dragged away gets its earlier size back, under the pointer.
    private func unsnapIfNeeded(_ w: AXUIElement, current f: CGRect) {
        let m = Mintangle.shared
        let key = Int(CFHash(w))
        guard m.unsnapRestore, let snap = m.snapped[key], let o = m.original[key],
              abs(snap.width - f.width) < 3, abs(snap.height - f.height) < 3, let app else { return }
        let p = NSEvent.mouseLocation
        let rx = f.width > 0 ? (p.x - f.minX) / f.width : 0.5
        let r = CGRect(x: p.x - rx * o.width, y: f.maxY - o.height, width: o.width, height: o.height)
        Mintangle.set(w, app: app, r)
        startFrame = Mintangle.frame(of: w) ?? r
        m.snapped[key] = nil; m.original[key] = nil
    }

    /// Edge zones, 5 px from the screen frame; corners take 30 px along each edge.
    static func zone(at p: CGPoint) -> (MTAction, NSScreen)? {
        guard let s = NSScreen.screens.first(where: { NSMouseInRect(p, $0.frame, false) }) else { return nil }
        let f = s.frame, m: CGFloat = 5, c: CGFloat = 30
        let left = p.x <= f.minX + m, right = p.x >= f.maxX - m - 1
        let top = p.y >= f.maxY - m - 1, bottom = p.y <= f.minY + m
        let nearTop = p.y >= f.maxY - c, nearBottom = p.y <= f.minY + c
        let nearLeft = p.x <= f.minX + c, nearRight = p.x >= f.maxX - c
        if (left && nearTop) || (top && nearLeft) { return (.topLeft, s) }
        if (right && nearTop) || (top && nearRight) { return (.topRight, s) }
        if (left && nearBottom) || (bottom && nearLeft) { return (.bottomLeft, s) }
        if (right && nearBottom) || (bottom && nearRight) { return (.bottomRight, s) }
        if left { return (.leftHalf, s) }
        if right { return (.rightHalf, s) }
        if top { return (.maximize, s) }
        if bottom {
            let fx = (p.x - f.minX) / f.width
            return (fx < 1.0 / 3 ? .firstThird : (fx < 2.0 / 3 ? .centerThird : .lastThird), s)
        }
        return nil
    }
}

/// The translucent preview of where a dragged window will land.
final class MTFootprint {
    private lazy var window: NSWindow = {
        let w = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        w.isOpaque = false; w.backgroundColor = .clear; w.hasShadow = false; w.ignoresMouseEvents = true
        w.level = .floating; w.isReleasedWhenClosed = false
        w.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
        let v = NSView(); v.wantsLayer = true
        v.layer?.cornerRadius = 12
        v.layer?.backgroundColor = NSColor(calibratedRed: 0.37, green: 0.94, blue: 0.75, alpha: 0.22).cgColor
        v.layer?.borderColor = NSColor(calibratedRed: 0.37, green: 0.94, blue: 0.75, alpha: 0.85).cgColor
        v.layer?.borderWidth = 2
        w.contentView = v
        return w
    }()
    func show(_ r: CGRect) {
        if window.isVisible {
            NSAnimationContext.runAnimationGroup { ctx in ctx.duration = 0.12; window.animator().setFrame(r, display: true) }
        } else {
            window.setFrame(r, display: true); window.alphaValue = 0; window.orderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in ctx.duration = 0.12; window.animator().alphaValue = 1 }
        }
    }
    func hide() { if window.isVisible { window.orderOut(nil) } }
}

extension MTAction {
    var isCorner: Bool { [.topLeft, .topRight, .bottomLeft, .bottomRight].contains(self) }
    /// Halves and corners react to a second press (cycle sizes or move to the neighbouring display).
    var repeats: Bool { [.leftHalf, .rightHalf, .topHalf, .bottomHalf].contains(self) || isCorner }
    /// Actions that describe a place on the screen, so moving to another display can re-apply them there.
    var hasLayout: Bool { ![.center, .larger, .smaller, .restore, .nextDisplay, .previousDisplay].contains(self) }
    /// Left side becomes right side when the window jumps to the display on the left, and the other way round.
    var mirrored: MTAction {
        switch self {
        case .leftHalf: return .rightHalf
        case .rightHalf: return .leftHalf
        case .topLeft: return .topRight
        case .topRight: return .topLeft
        case .bottomLeft: return .bottomRight
        case .bottomRight: return .bottomLeft
        default: return self
        }
    }

    /// Target frame inside the visible area of a screen (Cocoa coordinates). `step` 0/1/2 = 1/2, 2/3, 1/3 for halves and corners.
    func rect(in v: CGRect, step: Int, gap g: Double, current c: CGRect) -> CGRect {
        let frac: CGFloat = [0.5, 2.0 / 3.0, 1.0 / 3.0][min(max(step, 0), 2)]
        let w = v.width, h = v.height
        var r: CGRect
        switch self {
        case .leftHalf: r = CGRect(x: v.minX, y: v.minY, width: w * frac, height: h)
        case .rightHalf: r = CGRect(x: v.maxX - w * frac, y: v.minY, width: w * frac, height: h)
        case .topHalf: r = CGRect(x: v.minX, y: v.maxY - h * frac, width: w, height: h * frac)
        case .bottomHalf: r = CGRect(x: v.minX, y: v.minY, width: w, height: h * frac)
        case .topLeft: r = CGRect(x: v.minX, y: v.midY, width: w * frac, height: h / 2)
        case .topRight: r = CGRect(x: v.maxX - w * frac, y: v.midY, width: w * frac, height: h / 2)
        case .bottomLeft: r = CGRect(x: v.minX, y: v.minY, width: w * frac, height: h / 2)
        case .bottomRight: r = CGRect(x: v.maxX - w * frac, y: v.minY, width: w * frac, height: h / 2)
        case .firstThird: r = CGRect(x: v.minX, y: v.minY, width: w / 3, height: h)
        case .centerThird: r = CGRect(x: v.minX + w / 3, y: v.minY, width: w / 3, height: h)
        case .lastThird: r = CGRect(x: v.minX + 2 * w / 3, y: v.minY, width: w / 3, height: h)
        case .firstTwoThirds: r = CGRect(x: v.minX, y: v.minY, width: 2 * w / 3, height: h)
        case .lastTwoThirds: r = CGRect(x: v.minX + w / 3, y: v.minY, width: 2 * w / 3, height: h)
        case .maximize: r = v
        case .almostMaximize: r = v.insetBy(dx: w * 0.05, dy: h * 0.05)
        case .maximizeHeight: return CGRect(x: c.minX, y: v.minY, width: c.width, height: h)
        case .center:
            let cw = min(c.width, w), ch = min(c.height, h)
            return CGRect(x: v.midX - cw / 2, y: v.midY - ch / 2, width: cw, height: ch)
        case .larger, .smaller:
            let d: CGFloat = self == .larger ? 30 : -30
            var n = c.insetBy(dx: -d, dy: -d)
            n.size.width = max(200, min(n.width, w)); n.size.height = max(150, min(n.height, h))
            n.origin.x = max(v.minX, min(n.minX, v.maxX - n.width)); n.origin.y = max(v.minY, min(n.minY, v.maxY - n.height))
            return n
        case .restore, .nextDisplay, .previousDisplay: return c
        }
        return Self.withGap(r, in: v, gap: CGFloat(g))
    }

    /// Gap: full gap at screen edges, half a gap on inner edges, so two neighbours are `gap` apart.
    static func withGap(_ r: CGRect, in v: CGRect, gap g: CGFloat) -> CGRect {
        guard g > 0 else { return r }
        let l = abs(r.minX - v.minX) < 1 ? g : g / 2, rt = abs(r.maxX - v.maxX) < 1 ? g : g / 2
        let b = abs(r.minY - v.minY) < 1 ? g : g / 2, tp = abs(r.maxY - v.maxY) < 1 ? g : g / 2
        return CGRect(x: r.minX + l, y: r.minY + b, width: r.width - l - rt, height: r.height - b - tp)
    }
}

// MARK: Sidebar page (Mintangle)

/// Right edge of the Mintangle row in the sidebar: "Off" while turned off, a warning while waiting for permission.
struct MintangleNavState: View {
    let selected: Bool
    @ObservedObject private var m = Mintangle.shared
    var body: some View {
        if !m.enabled {
            Text(t("Off", "Tắt")).font(.system(size: fs(10), weight: .semibold))
                .foregroundColor(selected ? .white : Theme.sub)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Capsule().stroke(selected ? Color.white.opacity(0.7) : Theme.ink.opacity(0.3), lineWidth: 1))
        } else if !m.trusted {
            Circle().fill(Theme.warn).frame(width: 7, height: 7)
        }
    }
}

struct MintangleView: View {
    @ObservedObject private var m = Mintangle.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Mintangle: arrange windows", "Mintangle: xếp cửa sổ")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text)
                    Text(t("Snap windows to halves, corners and thirds.",
                           "Xếp cửa sổ vào nửa, góc, 1/3 màn hình."))
                        .foregroundColor(Theme.sub).font(.system(size: fs(12)))
                }
                Spacer(minLength: 16)
                if m.enabled { GhostButton(title: t("Turn off", "Tắt Mintangle"), action: { m.setEnabled(false) }, compact: true) }
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !m.enabled {
                        offCard
                        section(t("What you get", "Bật lên bạn sẽ có"))
                        MTShortcutGrid(editable: false).opacity(0.75)
                        MTSnapDiagram().opacity(0.75)
                    }
                    else if !m.trusted { permissionCard }
                    else { onContent }
                    TextLink(t("Full guide: shortcuts, dragging, what the permission is for →", "Hướng dẫn đầy đủ: phím tắt, kéo thả, quyền Trợ năng dùng để làm gì →"),
                             url: URL(string: appLang == "vi" ? "https://tidymint.app/vi/mintangle-xep-cua-so-mac/" : "https://tidymint.app/mintangle-window-tiling-mac/")!)
                }.frame(maxWidth: 760 * uiScale, alignment: .leading)
                .padding(.horizontal, 24).padding(.bottom, 24).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear { m.apply() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in m.apply() }
    }

    var offCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.lefthalf.inset.filled").font(.system(size: fs(20))).foregroundColor(Theme.brandMint)
                Text(t("Mintangle is off", "Mintangle đang tắt")).font(.system(size: fs(14), weight: .semibold)).foregroundColor(Theme.text)
            }
            Text(t("Needs Accessibility permission. Only window position and size are read, never content.",
                   "Cần quyền Trợ năng. Chỉ đọc vị trí và cỡ cửa sổ, không đọc nội dung."))
                .foregroundColor(Theme.sub).font(.system(size: fs(12))).fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: t("Turn on and grant permission", "Bật và cấp quyền"), action: { m.setEnabled(true) }, compact: true)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
    }

    var permissionCard: some View {
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Tidymint"
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(Theme.warn).frame(width: 8, height: 8)
                Text(t("Waiting for Accessibility permission", "Đang chờ quyền Trợ năng")).font(.system(size: fs(14), weight: .semibold)).foregroundColor(Theme.text)
            }
            Text(t("System Settings › Privacy & Security › Accessibility: turn on \(name).",
                   "Cài đặt hệ thống › Quyền riêng tư & Bảo mật › Trợ năng: bật \(name)."))
                .foregroundColor(Theme.sub).font(.system(size: fs(12))).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                PrimaryButton(title: t("Open System Settings", "Mở Cài đặt hệ thống"), action: { NSWorkspace.shared.open(Mintangle.accessibilitySettings) }, compact: true)
                TextLink(t("Cancel", "Huỷ")) { m.setEnabled(false) }
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.warn.opacity(0.08)))
    }

    func section(_ title: String) -> some View {
        Text(title).font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text).padding(.top, 6)
    }

    @ViewBuilder var onContent: some View {
        ForEach(m.rivalIDsRunning, id: \.self) { id in
            let name = Mintangle.rivalIDs[id] ?? id
            note(t("\(name) is running", "\(name) đang chạy"),
                 t("Same shortcuts. Quit \(name) to avoid conflicts.",
                   "Trùng phím tắt. Thoát \(name) để tránh xung đột.")) {
                PrimaryButton(title: t("Quit \(name)", "Thoát \(name)"), action: { m.quitRival(id) }, compact: true)
            }
        }
        if !m.failed.isEmpty {
            note(t("Some shortcuts are taken by another app", "Một số phím tắt đang bị app khác giữ"),
                 m.failed.compactMap { a in m.key(for: a).map { "\($0.label) \(a.title)" } }.joined(separator: " · ")
                 + t(". Click the key to pick another one.", ". Bấm vào dòng đó để chọn phím khác.")) { EmptyView() }
        }
        if !m.systemClash.isEmpty {
            let ids = Set(m.systemClash.values)
            let secs = Array(Set(ids.map { MTSystemShortcuts.section($0) })).sorted().joined(separator: ", ")
            note(t("Same keys as macOS shortcuts", "Trùng phím tắt của macOS"),
                 m.systemClash.sorted { $0.key.rawValue < $1.key.rawValue }.compactMap { a, id in
                     m.key(for: a).map { "\($0.label) \(a.title) ↔ \(MTSystemShortcuts.title(id))" } }.joined(separator: "\n")
                 + t("\nChange it in Keyboard Shortcuts… › \(secs), or pick another key here.",
                     "\nĐổi ở Phím tắt bàn phím… › \(secs), hoặc chọn phím khác ở đây.")) {
                GhostButton(title: t("Open Keyboard settings", "Mở cài đặt Bàn phím"), action: { NSWorkspace.shared.open(MTSystemShortcuts.settingsURL) }, compact: true)
            }
        }
        section(t("Keyboard shortcuts", "Phím tắt"))
        MTShortcutGrid(editable: true)
        HStack(spacing: 6) {
            SettingNote(t("Click a row, press new keys. Delete: remove. Esc: cancel.",
                          "Bấm vào dòng, gõ phím mới. Delete: bỏ. Esc: huỷ."))
            if !m.custom.isEmpty || !m.off.isEmpty { TextLink(t("Restore defaults", "Khôi phục mặc định"), size: 11) { m.resetKeys() } }
        }

        section(t("Drag to screen edges", "Kéo vào mép màn hình"))
        SettingsBox {
            rowFlat(t("Snap windows by dragging", "Kéo cửa sổ vào mép để xếp")) {
                Toggle("", isOn: $m.snapDrag).toggleStyle(.switch).labelsHidden().controlSize(.mini)
            }
            rowFlat(t("Restore size when dragged away", "Kéo ra khỏi mép thì trả về cỡ cũ")) {
                Toggle("", isOn: $m.unsnapRestore).toggleStyle(.switch).labelsHidden().controlSize(.mini)
            }
        }
        if m.snapDrag {
            MTSnapDiagram()
            if m.macTiling {
                VStack(alignment: .leading, spacing: 6) {
                    SettingsBox {
                        rowFlat(t("macOS window tiling is also on", "Xếp cửa sổ của macOS cũng đang bật"), attention: true) {
                            GhostButton(title: t("Open Settings", "Mở Cài đặt"), action: { NSWorkspace.shared.open(Mintangle.desktopSettings) }, compact: true)
                        }
                    }
                    SettingNote(t("macOS also tiles on drag. Turn it off in Desktop & Dock › Windows.",
                                  "macOS cũng xếp khi kéo. Tắt ở Màn hình nền & Dock › Cửa sổ."))
                }
            }
        }

        section(t("Behavior", "Cách hoạt động"))
        let k = m.key(for: .leftHalf)?.label ?? "⌃⌥←"
        VStack(alignment: .leading, spacing: 6) {
            SettingsBox {
                rowFlat(t("Pressing the same shortcut again", "Bấm một phím tắt nhiều lần liền")) {
                    Picker("", selection: $m.repeatMode) {
                        Text(t("Change width: 1/2 › 2/3 › 1/3", "Đổi độ rộng: 1/2 › 2/3 › 1/3")).tag(MTRepeat.resize)
                        Text(t("Jump to the next display", "Nhảy sang màn hình bên cạnh")).tag(MTRepeat.display)
                        Text(t("Nothing", "Không làm gì")).tag(MTRepeat.none)
                    }.labelsHidden().controlSize(.small).fixedSize()
                }
            }
            SettingNote(m.repeatMode == .display
                ? t("Example: \(k) twice moves the window to the display on the left.",
                    "Ví dụ: bấm \(k) hai lần, cửa sổ sang màn hình bên trái.")
                : m.repeatMode == .resize
                ? t("Example: press \(k) repeatedly: 1/2 › 2/3 › 1/3.",
                    "Ví dụ: bấm \(k) liên tiếp: 1/2 › 2/3 › 1/3.")
                : t("Window stays put.", "Cửa sổ giữ nguyên."))
        }
        SettingsBox {
            rowFlat(t("Gap between windows", "Khoảng cách giữa các cửa sổ")) {
                HStack(spacing: 8) {
                    Slider(value: $m.gap, in: 0...20, step: 1).frame(width: 120 * uiScale).controlSize(.small)
                    Text("\(Int(m.gap)) px").foregroundColor(Theme.sub).font(.system(size: fs(12))).frame(width: 40, alignment: .trailing)
                }
            }
        }
        VStack(alignment: .leading, spacing: 6) {
            SettingsBox {
                HStack {
                    Text(t("Apps to leave alone", "App không áp dụng")).foregroundColor(Theme.text).font(.system(size: fs(13)))
                    Spacer()
                    Menu(t("Add…", "Thêm…")) {
                        ForEach(m.ignoreFrontmostCandidates(), id: \.id) { a in Button(a.name) { m.ignored.append(a.id) } }
                    }.menuStyle(.borderlessButton).fixedSize().controlSize(.small)
                }.settingFlat()
                ForEach(m.ignored, id: \.self) { id in
                    HStack {
                        Text(m.appName(id)).foregroundColor(Theme.text).font(.system(size: fs(12)))
                        Spacer()
                        TextLink(t("Remove", "Gỡ")) { m.ignored.removeAll { $0 == id } }
                    }.settingFlat()
                }
            }
            SettingNote(t("Shortcuts and dragging do nothing while one of these apps is in front.", "Mintangle bỏ qua cửa sổ của các app trong danh sách này."))
        }
    }

    func note<C: View>(_ title: String, _ sub: String, @ViewBuilder _ control: () -> C) -> some View {
        let r = rowFlat(title, attention: true, control)
        return VStack(alignment: .leading, spacing: 6) {
            SettingsBox { r }
            SettingNote(sub)
        }
    }
    func rowFlat<C: View>(_ title: String, attention: Bool = false, @ViewBuilder _ control: () -> C) -> some View {
        HStack {
            HStack(spacing: 6) {
                if attention { Circle().fill(Theme.warn).frame(width: 7, height: 7) }
                Text(title).foregroundColor(Theme.text).font(.system(size: fs(13)))
            }
            Spacer(minLength: 16)
            control()
        }.settingFlat(attention: attention)
    }
}

/// Small screen drawing with the area an action fills (like the icons in Rectangle's list).
struct MTIcon: View {
    let action: MTAction
    var size = CGSize(width: 26, height: 17)
    var body: some View {
        let symbol: String? = {
            switch action {
            case .larger: return "plus"
            case .smaller: return "minus"
            case .restore: return "arrow.uturn.backward"
            case .nextDisplay: return "chevron.right.2"
            case .previousDisplay: return "chevron.left.2"
            default: return nil
            }
        }()
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3).stroke(Theme.sub, lineWidth: 1)
            if let symbol {
                Image(systemName: symbol).font(.system(size: 8, weight: .bold)).foregroundColor(Theme.brandMint)
                    .frame(width: size.width, height: size.height)
            } else {
                let u = action.rect(in: CGRect(x: 0, y: 0, width: 1, height: 1), step: 0, gap: 0,
                                    current: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4))
                RoundedRectangle(cornerRadius: 1.5).fill(Theme.brandMint)
                    .frame(width: max(2, u.width * (size.width - 4)), height: max(2, u.height * (size.height - 4)))
                    .offset(x: 2 + u.minX * (size.width - 4), y: 2 + (1 - u.maxY) * (size.height - 4))
            }
        }.frame(width: size.width, height: size.height)
    }
}

struct MTKeycap: View {
    let text: String
    var warn = false
    var recording = false
    var body: some View {
        Text(text).font(.system(size: fs(12), weight: .medium, design: .rounded))
            .foregroundColor(recording ? Theme.brandMint : (warn ? Theme.warn : Theme.text))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(recording ? Theme.brandMint.opacity(0.12) : Theme.ink.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(recording ? Theme.brandMint : (warn ? Theme.warn.opacity(0.7) : Theme.ink.opacity(0.12)), lineWidth: 1))
    }
}

/// All shortcuts in clusters (halves, corners, thirds, size, displays): each cluster has a small heading and its own card.
/// Hovering a row spells the keys out; clicking the key records a new one (when editable).
struct MTShortcutGrid: View {
    let editable: Bool
    @ObservedObject private var m = Mintangle.shared
    @ObservedObject private var rec = MTRecorder.shared
    static let headings: [(String, String)] = [("Halves", "Nửa màn hình"), ("Corners", "Góc"), ("Thirds", "Chia ba"),
                                               ("Size and position", "Kích thước và vị trí"), ("Displays", "Nhiều màn hình")]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(MTAction.groups.enumerated()), id: \.offset) { i, g in
                VStack(alignment: .leading, spacing: 6) {
                    Text(t(Self.headings[i].0, Self.headings[i].1).uppercased())
                        .font(.system(size: fs(10), weight: .semibold)).tracking(0.6).foregroundColor(Theme.sub).padding(.leading, 4)
                    VStack(alignment: .leading, spacing: 4) {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)], spacing: 2) {
                            ForEach(g) { a in row(a) }
                        }
                        caption(g)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                }
            }
        }
        .onDisappear { rec.stop() }
    }

    /// The line under each cluster: spells out the keys of the row under the pointer, or what to press while recording.
    @ViewBuilder func caption(_ g: [MTAction]) -> some View {
        if let a = rec.action, g.contains(a) {
            Text(rec.hint ?? t("\(a.title): press the new keys now (Esc cancels, Delete removes the shortcut).",
                               "\(a.title): bấm tổ hợp phím mới ngay bây giờ (Esc để huỷ, Delete để bỏ phím tắt)."))
                .foregroundColor(rec.hint == nil ? Theme.brandMint : Theme.warn).font(.system(size: fs(11))).padding(.bottom, 4)
            if !m.rivals.isEmpty {
                Text(t("\(m.rivals.joined(separator: ", ")) is still running and may catch the keys before Mintangle sees them.",
                       "\(m.rivals.joined(separator: ", ")) vẫn đang chạy nên có thể chặn mất phím trước khi Mintangle nhận được."))
                    .foregroundColor(Theme.warn).font(.system(size: fs(11))).padding(.bottom, 4)
            }
        }
    }

    func row(_ a: MTAction) -> some View {
        let k = m.key(for: a)
        let recording = rec.action == a
        let clash = m.failed.contains(a) || m.systemClash[a] != nil
        let label = recording ? t("Press keys…", "Bấm phím mới…") : (k?.label ?? t("Not set", "Chưa đặt"))
        let tip = k?.spoken ?? ""
        return HStack(spacing: 10) {
            MTIcon(action: a)
            Text(a.title).foregroundColor(Theme.text).font(.system(size: fs(12))).lineLimit(1)
            Spacer(minLength: 6)
            MTKeycap(text: label, warn: editable && (clash || k == nil), recording: recording)
        }
        .padding(.vertical, 6).padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(rec.hover == a || recording ? Theme.ink.opacity(0.06) : Color.clear))
        .overlay(MTRowCatcher(action: a, tip: tip, editable: editable))
    }
}

/// Pointer state for the snap diagram (@State needs the SwiftUI macro plugin, which plain swiftc builds lack).
final class MTHover: ObservableObject { @Published var action: MTAction? }

/// Where each edge and corner sends a dragged window. Pointing at a label lights up its area on the little screen.
struct MTSnapDiagram: View {
    @StateObject private var hover = MTHover()
    struct Zone { let a: MTAction; let en: String; let vi: String; let align: Alignment }
    static let zones: [Zone] = [
        Zone(a: .topLeft, en: "Top left", vi: "Góc trên bên trái", align: .topLeading),
        Zone(a: .maximize, en: "Top edge: maximize", vi: "Mép trên: phóng to hết", align: .top),
        Zone(a: .topRight, en: "Top right", vi: "Góc trên bên phải", align: .topTrailing),
        Zone(a: .leftHalf, en: "Left edge: left half", vi: "Mép trái: nửa trái", align: .leading),
        Zone(a: .rightHalf, en: "Right edge: right half", vi: "Mép phải: nửa phải", align: .trailing),
        Zone(a: .bottomLeft, en: "Bottom left", vi: "Góc dưới bên trái", align: .bottomLeading),
        Zone(a: .centerThird, en: "Bottom edge: thirds", vi: "Mép dưới: chia ba", align: .bottom),
        Zone(a: .bottomRight, en: "Bottom right", vi: "Góc dưới bên phải", align: .bottomTrailing)]
    var body: some View {
        let sh: CGFloat = 144 * uiScale
        ZStack {
            MTMiniScreen(hover: hover)
            ForEach(Self.zones, id: \.a) { z in MTZoneLabel(zone: z, hover: hover) }
        }
        .frame(height: sh + 70).padding(14).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
    }
}

struct MTZoneLabel: View {
    let zone: MTSnapDiagram.Zone
    @ObservedObject var hover: MTHover
    var body: some View {
        let on = hover.action == zone.a
        let bg: Color = on ? Theme.brandMint.opacity(0.22) : Theme.ink.opacity(0.08)
        Text(t(zone.en, zone.vi)).font(.system(size: fs(11), weight: .medium))
            .foregroundColor(on ? Theme.text : Theme.sub)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(bg))
            .onHover { inside in
                if inside { hover.action = zone.a } else if hover.action == zone.a { hover.action = nil }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: zone.align)
    }
}

struct MTMiniScreen: View {
    @ObservedObject var hover: MTHover
    var body: some View {
        let sw: CGFloat = 230 * uiScale, sh: CGFloat = 144 * uiScale
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8).fill(Theme.ink.opacity(0.06))
            Rectangle().fill(Theme.ink.opacity(0.12)).frame(height: 7)
            ForEach(Array(rects().enumerated()), id: \.offset) { _, u in area(u, sw: sw, sh: sh) }
        }
        .frame(width: sw, height: sh)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))   // the title bar must follow the rounded corners
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.ink.opacity(0.35), lineWidth: 1))
        .animation(.easeOut(duration: 0.12), value: hover.action)
    }
    func area(_ u: CGRect, sw: CGFloat, sh: CGFloat) -> some View {
        let w = u.width * (sw - 8), h = u.height * (sh - 15)
        let x = 4 + u.minX * (sw - 8), y = 11 + (1 - u.maxY) * (sh - 15)
        return RoundedRectangle(cornerRadius: 4).fill(Theme.brandMint.opacity(0.3))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.brandMint, lineWidth: 1.5))
            .frame(width: w, height: h).offset(x: x, y: y)
    }
    func rects() -> [CGRect] {
        guard let h = hover.action else { return [] }
        let u = CGRect(x: 0, y: 0, width: 1, height: 1)
        if h == .centerThird {
            return [MTAction.firstThird, .centerThird, .lastThird].map { $0.rect(in: u, step: 0, gap: 0, current: u).insetBy(dx: 0.01, dy: 0) }
        }
        return [h.rect(in: u, step: 0, gap: 0, current: u)]
    }
}

// MARK: Settings: only the switch (everything else lives on the Mintangle page)

struct MintangleSettings: View {
    @ObservedObject var groups: OpenGroups
    let open: () -> Void
    @ObservedObject private var m = Mintangle.shared
    var body: some View {
        SettingsGroup(id: "mintangle", icon: "rectangle.lefthalf.inset.filled",
                      title: t("Mintangle: arrange windows", "Mintangle: xếp cửa sổ"),
                      summary: m.enabled ? (m.trusted ? t("On", "Đang bật") : t("Waiting for Accessibility", "Chờ cấp quyền Trợ năng")) : t("Off", "Đang tắt"),
                      badge: m.enabled && !m.trusted ? t("Needs permission", "Cần cấp quyền") : nil, groups: groups) {
            VStack(alignment: .leading, spacing: 6) {
                SettingsBox {
                    HStack {
                        Text(t("Arrange windows with shortcuts", "Xếp cửa sổ bằng phím tắt và kéo thả")).foregroundColor(Theme.text).font(.system(size: fs(13)))
                        Spacer(minLength: 16)
                        Toggle("", isOn: Binding(get: { m.enabled }, set: { m.setEnabled($0) })).toggleStyle(.switch).labelsHidden().controlSize(.mini)
                    }.settingFlat()
                }
                HStack(spacing: 4) {
                    SettingNote(t("Off by default. Turning it on asks for Accessibility permission.", "Mặc định tắt. Bật lên sẽ hỏi quyền Trợ năng."))
                    TextLink(t("Shortcuts and options", "Phím tắt và tuỳ chọn"), size: 11) { open() }
                }
            }
        }
        .onAppear { m.apply() }
    }
}
