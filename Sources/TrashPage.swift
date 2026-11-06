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
