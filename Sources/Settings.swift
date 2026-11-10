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
                settingRow(t("Hint when an app goes to the Trash", "Gợi ý khi bỏ app vào Thùng rác"),
                           !vm.fullDiskAccess && vm.trashHintOn
                           ? t("Needs Full Disk Access to see the Trash.", "Cần quyền Truy cập toàn bộ ổ đĩa để thấy Thùng rác.")
                           : t("While Tidymint is running, drag an app to the Trash and Tidymint lists what it left in Library. Nothing is ticked or removed for you.",
                               "Khi Tidymint đang chạy, bạn kéo một app vào Thùng rác thì Tidymint liệt kê những gì app đó để lại trong Library. Không tick sẵn, không tự xoá.")) {
                    Toggle("", isOn: Binding(get: { vm.trashHintOn }, set: { vm.setTrashHint($0) })).toggleStyle(.switch).labelsHidden().controlSize(.mini)
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
            if featureMintangle { MintangleSettings(groups: groups, open: { vm.page = .windows }) }
            if featureShelf { ShelfSettings(groups: groups, open: { vm.page = .shelf }) }
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
                                                : vm.updResult ?? (vm.autoUpdateCheck ? t("Checks once a day. Only the app and macOS version are counted; nothing else about your Mac is sent.", "Kiểm mỗi ngày một lần. Chỉ đếm theo phiên bản app và macOS, không gửi gì khác về máy.")
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
        .onReceive(vm.$newVersion) { v in if v != nil { groups.ids.insert("about") } }   // @Published sends before the value is set
    }
    func openAttention() {
        if !vm.fullDiskAccess { groups.ids.insert("scan") }
        if vm.newVersion != nil { groups.ids.insert("about") }
        if featureMintangle && Mintangle.shared.enabled && !Mintangle.shared.trustedNow { groups.ids.insert("mintangle") }
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
