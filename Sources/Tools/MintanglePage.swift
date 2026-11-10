// Mintangle: sidebar page, shortcut grid and the Settings switch (core in Mintangle.swift).
import AppKit
import Carbon
import SwiftUI

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
