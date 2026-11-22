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
/// One tool in Settings › Tools: its name and what it does, its switch, then a note and a link to its page.
struct ToolSettingRow: View {
    let name: String, what: String, note: String, link: String
    var attention = false
    let on: Binding<Bool>
    let open: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsBox {
                HStack {
                    if attention { Circle().fill(Theme.warn).frame(width: 7, height: 7) }
                    Text(name).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .medium))
                    Text(what).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                    Spacer(minLength: 16)
                    Toggle("", isOn: on).toggleStyle(.switch).labelsHidden().controlSize(.mini)
                }.settingFlat(attention: attention)
            }
            HStack(spacing: 4) {
                if !note.isEmpty { SettingNote(note) }
                TextLink(link, size: 11) { open() }
            }.padding(.leading, note.isEmpty ? 14 : 0)
        }
    }
}

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
            // As System Settings draws its groups: a flat patch a little lighter than the page, softly rounded, no outline
            // (Apple keeps glass out of the content layer; rows are told apart by hairlines only).
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
    @AppStorage(SettingsBackup.permCheckKey) private var permCheck = false
    #if TIDYMINT_PRIVATE
    @ObservedObject private var mintbar = Mintbar.shared
    #endif
    /// The Mintbar groups holding Tidymint's icon: it is in the menu bar then, inside their fans, though "showMenuBar"
    /// is off (Mintbar turns the leaf's own item off while it sits in a group; 20/11/2026: the switch read Off, and
    /// switching it on put a second leaf in the bar).
    private var ownGroups: [String] {
        #if TIDYMINT_PRIVATE
        return mintbar.ownGroupNames
        #else
        return []
        #endif
    }
    @StateObject private var themeHover = HoveredTheme()
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            Text(t("Settings", "Cài đặt")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text).padding(.top, 34)
            VStack(alignment: .leading, spacing: 14) {
            if permCheck { permissionsAfterImport }
            SettingsGroup(id: "general", icon: "gearshape", title: t("General", "Chung"),
                          summary: t("Open at login, Tidymint icon, theme", "Mở cùng máy, icon Tidymint, màu giao diện"), badge: nil, first: true, groups: groups) {
                SettingsBox {
                settingRow(t("Open at login", "Mở cùng máy"), "") {
                    Toggle("", isOn: Binding(get: { vm.openAtLogin }, set: { vm.setOpenAtLogin($0) })).toggleStyle(.switch).labelsHidden().controlSize(.mini)
                }
                }
                settingRow(t("Tidymint icon in the menu bar", "Icon Tidymint trên thanh menu"),
                           ownGroups.isEmpty
                           ? t("Free disk space and memory at a glance. It can go into a Mintbar group. Off: alerts still arrive as notifications; open Tidymint from the Dock or Applications.",
                               "Xem nhanh dung lượng trống và bộ nhớ. Cho vào một nhóm của Mintbar được. Tắt: cảnh báo vẫn hiện thành thông báo; mở Tidymint từ Dock hoặc Applications.")
                           : String(format: t("In the Mintbar group %@.", "Đang nằm trong nhóm %@ của Mintbar."),
                                    ownGroups.joined(separator: ", "))) {
                    Toggle("", isOn: Binding(get: { showMenuBar || !ownGroups.isEmpty }, set: { on in
                        #if TIDYMINT_PRIVATE
                        if !on && !ownGroups.isEmpty { mintbar.takeOwnOut() }
                        if on && mintbar.putOwnBack() { return }   // back in the group it left, not loose in the bar
                        #endif
                        showMenuBar = on
                    })).toggleStyle(.switch).labelsHidden().controlSize(.mini)
                }
                SettingsBox {
                settingRow(t("Theme", "Giao diện màu"), "") {
                    HStack(spacing: 12) {
                        ForEach(palettes, id: \.id) { pl in ThemeSwatch(pl: pl, vm: vm, hover: themeHover) }
                    }.contentShape(Rectangle()).onHover { themeHover.inRow = $0; if !$0 { themeHover.id = nil } }
                }
                }
            }
            SettingsGroup(id: "scan", icon: "magnifyingglass", title: t("Scanning and cleaning", "Quét và dọn"),
                          summary: t("Full Disk Access, project folders, external drives, Trash hint", "Truy cập toàn bộ ổ đĩa, thư mục dự án, ổ cứng rời, gợi ý Thùng rác"),
                          badge: vm.fullDiskAccess ? nil : t("Needs Full Disk Access", "Cần bật quyền"), groups: groups) {
                settingRow(t("Full Disk Access", "Truy cập toàn bộ ổ đĩa"),
                           vm.fullDiskAccess ? "" : t("Off: Mail, Safari and Messages are left out of scans.", "Đang tắt: Mail, Safari, Tin nhắn bị bỏ qua khi quét."),
                           attention: !vm.fullDiskAccess, boxed: true) {
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
                            Text(t("Project folders (code, AI)", "Thư mục dự án (code, AI)")).foregroundColor(Theme.text).font(.system(size: fs(13)))
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
                SettingNote(t("Network drives and Time Machine backups are not supported.", "Chưa hỗ trợ ổ mạng và ổ Time Machine."))
                }
                settingRow(t("Hint when an app goes to the Trash", "Gợi ý khi bỏ app vào Thùng rác"),
                           !vm.fullDiskAccess && vm.trashHintOn
                           ? t("Needs Full Disk Access to see the Trash.", "Cần quyền Truy cập toàn bộ ổ đĩa để thấy Thùng rác.") : "", boxed: true) {
                    Toggle("", isOn: Binding(get: { vm.trashHintOn }, set: { vm.setTrashHint($0) })).toggleStyle(.switch).labelsHidden().controlSize(.mini)
                }
            }
            SettingsGroup(id: "alerts", icon: "bell", title: t("Alerts", "Cảnh báo"),
                          summary: t("Low disk space, memory", "Ổ sắp đầy, bộ nhớ"), badge: nil, groups: groups) {
                settingRow(t("Low disk space alert", "Cảnh báo ổ sắp đầy"),
                           vm.lowSpaceGB > 0
                           ? String(format: t("Below %.0f GB. Enter 0 to turn off.", "Dưới %.0f GB. Nhập 0 để tắt."), vm.lowSpaceGB)
                           : t("Off. Enter a number of GB to turn it on.", "Đang tắt. Nhập số GB để bật.")) {
                    HStack(spacing: 6) {
                        TextField("0", text: Binding(get: { vm.lowSpaceGB > 0 ? String(Int(vm.lowSpaceGB)) : "" },
                                                     set: { vm.setLowSpace(min(10_000, max(0, Double($0.filter(\.isNumber)) ?? 0))) }))
                            .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).controlSize(.small).frame(width: 56)
                        Text("GB").foregroundColor(Theme.sub).font(.system(size: fs(12)))
                    }
                }
                settingRow(t("Memory alert", "Cảnh báo bộ nhớ"), "", boxed: true) {
                    Toggle("", isOn: Binding(get: { vm.ramAlert }, set: { vm.setRamAlert($0) })).toggleStyle(.switch).labelsHidden().controlSize(.mini)
                }
            }
            #if TIDYMINT_PRIVATE
            // The tools, one row each in one group (each had a group of its own holding one switch).
            SettingsGroup(id: "tools", icon: "wrench.and.screwdriver", title: t("Tools", "Công cụ"),
                          summary: ([featureMintangle ? "Mintangle" : nil, featureShelf ? "Mintdrop" : nil, "Mintbar"] as [String?]).compactMap { $0 }.joined(separator: ", "),
                          badge: featureMintangle && Mintangle.shared.enabled && !Mintangle.shared.trusted ? t("Needs permission", "Cần cấp quyền") : nil, groups: groups) {
                if featureMintangle { MintangleSettings(open: { vm.page = .windows }) }
                if featureShelf { ShelfSettings(open: { vm.page = .shelf }) }
                MintbarSettings(open: { vm.page = .menubar })
            }
            #endif
            if SettingsBackup.released || isDevBuild {
            SettingsGroup(id: "backup", icon: "externaldrive.badge.timemachine", title: t("Back up", "Sao lưu"),
                          summary: t("Settings, history and statistics in one file", "Cài đặt, lịch sử và thống kê trong một file"), badge: nil, groups: groups) {
                SettingsBox {
                    settingRow(t("Backup file", "File sao lưu"), "") {
                        HStack(spacing: 8) {
                            GhostButton(title: t("Export…", "Xuất…"), action: { SettingsBackup.export() }, compact: true)
                            GhostButton(title: t("Import…", "Nhập…"), action: { SettingsBackup.importFile() }, compact: true)
                        }
                    }
                }
            }
            }
            SettingsGroup(id: "about", icon: "info.circle", title: t("Updates and about", "Cập nhật và thông tin"),
                          summary: t("Version \(Updates.current), privacy, support", "Phiên bản \(Updates.current), quyền riêng tư, ủng hộ"),
                          badge: vm.newVersion != nil ? t("New version", "Có bản mới") : nil, groups: groups) {
                settingRow(t("Version \(Updates.current)", "Phiên bản \(Updates.current)") + privateVersionNote,
                           vm.newVersion != nil ? t("Version \(vm.newVersion!) is available on GitHub. Download it and drag it over the old one.", "Đã có bản \(vm.newVersion!) trên GitHub. Tải về rồi kéo đè lên bản cũ.")
                                                : vm.updResult ?? "", attention: vm.newVersion != nil, boxed: true) {
                    HStack(spacing: 10) {
                        if vm.updChecking { ProgressView().controlSize(.small).tint(Theme.text) }
                        if vm.newVersion != nil { PrimaryButton(title: t("Download", "Tải về"), action: { NSWorkspace.shared.open(Updates.download) }, compact: true) }
                        else { GhostButton(title: t("Check Now", "Kiểm tra"), action: { vm.checkUpdates(force: true) }, compact: true) }
                    }
                }
                settingRow(t("Privacy", "Quyền riêng tư"), "", boxed: true) {
                    TextLink(t("View", "Xem"), url: URL(string: Backend.privacyURL)!)
                }
                settingRow(t("Support the project", "Ủng hộ dự án"), "", boxed: true) {
                    PrimaryButton(title: t("Sponsor", "Ủng hộ"), action: { NSWorkspace.shared.open(sponsorURL("button")) }, compact: true)
                }
                if appLang == "vi" {
                    settingRow("Cùng tác giả: Cồn Cào", "", boxed: true) {
                        TextLink("concao.org", url: ConCao.url("settings"))
                    }
                }
            }
            }
            .frame(maxWidth: 760 * uiScale)
        }.padding(.horizontal, 24).padding(.bottom, 24).frame(maxWidth: .infinity) }
        // A group with something waiting (permission off, new version) opens by itself; the rest stay folded.
        .onAppear { openAttention() }
        .onReceive(vm.$newVersion) { v in if v != nil { groups.ids.insert("about") } }   // @Published sends before the value is set
    }
    /// After loading a backup: the macOS permissions this Mac still lacks (no app can carry them over), each with a
    /// button to its pane. Gone once all are granted or the person closes it.
    var missingPermissions: [(name: String, pane: String)] {
        var out: [(String, String)] = []
        if !vm.fullDiskAccess { out.append((t("Full Disk Access", "Truy cập toàn bộ ổ đĩa"), "Privacy_AllFiles")) }
        #if TIDYMINT_PRIVATE
        let ax = (featureMintangle && Mintangle.shared.enabled) || Mintbar.shared.enabled
        if ax && !AXIsProcessTrusted() { out.append((t("Accessibility", "Trợ năng"), "Privacy_Accessibility")) }
        if Mintbar.shared.enabled && !CGPreflightScreenCaptureAccess() { out.append((t("Screen Recording", "Ghi màn hình"), "Privacy_ScreenCapture")) }
        #endif
        return out
    }
    @ViewBuilder var permissionsAfterImport: some View {
        let missing = missingPermissions
        VStack(alignment: .leading, spacing: 6) {
            SettingsBox {
                HStack {
                    Text(missing.isEmpty ? t("All permissions are back", "Đã đủ quyền") : t("Permissions to grant again", "Quyền cần cấp lại"))
                        .foregroundColor(Theme.text).font(.system(size: fs(13), weight: .semibold))
                    Spacer()
                    TextLink(t("Done", "Xong")) { permCheck = false }
                }.settingFlat(attention: !missing.isEmpty)
                ForEach(missing, id: \.name) { p in
                    HStack {
                        Text(p.name).foregroundColor(Theme.text).font(.system(size: fs(13)))
                        Spacer()
                        GhostButton(title: t("Open", "Mở"), action: {
                            if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(p.pane)") { NSWorkspace.shared.open(u) }
                        }, compact: true)
                    }.settingFlat()
                }
            }
            if !missing.isEmpty { SettingNote(t("macOS does not let any app carry these over.", "macOS không cho app nào mang các quyền này theo.")) }
        }
    }

    func openAttention() {
        if !vm.fullDiskAccess { groups.ids.insert("scan") }
        if vm.newVersion != nil { groups.ids.insert("about") }
        #if TIDYMINT_PRIVATE
        if featureMintangle && Mintangle.shared.enabled && !Mintangle.shared.trustedNow { groups.ids.insert("tools") }
        #endif
    }
    /// One setting. With a description: its own rounded block, the description as a note under it (System Settings style).
    /// Without: a bare row, to be grouped with others inside a SettingsBox.
    /// `boxed`: with no description, the row still gets its own rounded block (a row that stands alone).
    func settingRow<C: View>(_ title: String, _ sub: String, attention: Bool = false, boxed: Bool = false, @ViewBuilder _ control: () -> C) -> some View {
        let row = HStack {
            HStack(spacing: 6) {
                if attention { Circle().fill(Theme.warn).frame(width: 7, height: 7) }
                Text(title).foregroundColor(Theme.text).font(.system(size: fs(13)))
            }
            Spacer(minLength: 16)
            control()
        }.settingFlat(attention: attention)
        return Group {
            if sub.isEmpty { if boxed { SettingsBox { row } } else { row } }
            else { VStack(alignment: .leading, spacing: 6) { SettingsBox { row }; SettingNote(sub) } }
        }
    }
}
