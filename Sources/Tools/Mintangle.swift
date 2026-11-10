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
