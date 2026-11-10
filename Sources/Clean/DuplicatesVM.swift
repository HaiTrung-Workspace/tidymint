// View model actions for Duplicates (state lives in App/ViewModel.swift).
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

extension VM {
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
    /// True when every copy the automatic pick may take is ticked. Copies it never takes (APFS clones, project files,
    /// files scripts use, cross-drive groups set to "ask") do not count, otherwise the button could never switch to Deselect.
    var dupAllExtrasSelected: Bool {
        var any = false
        for g in dupes {
            let ask = g.isCross && Prefs.crossKeep == "ask"
            for it in g.items.dropFirst() where Dupes.autoPick(it, ask: ask) { if !it.selected { return false }; any = true }
        }
        return any
    }
    func dupGroupState(_ g: DupGroup) -> Int {
        let n = g.items.dropFirst().filter(\.selected).count
        return n == 0 ? 0 : (n == g.items.count - 1 ? 2 : 1)
    }
    func dupToggleGroup(_ id: UUID) {
        guard let i = dupes.firstIndex(where: { $0.id == id }) else { return }
        let ask = dupes[i].isCross && Prefs.crossKeep == "ask"
        let on = dupes[i].items.indices.contains { j in j > 0 && !dupes[i].items[j].selected && Dupes.autoPick(dupes[i].items[j], ask: ask) }
        for j in dupes[i].items.indices { dupes[i].items[j].selected = on && j > 0 && Dupes.autoPick(dupes[i].items[j], ask: ask) }
    }
    /// Re-apply a keep rule to the groups that span the Mac and an external drive (menu on the Duplicates page).
    func dupApplyCross(_ rule: String) {
        for i in dupes.indices where dupes[i].isCross { dupes[i].items = Dupes.arrange(dupes[i].items, rule: rule) }
    }
    func dupAutoSelect(all: Bool) {
        for i in dupes.indices {
            let ask = dupes[i].isCross && Prefs.crossKeep == "ask"
            for j in dupes[i].items.indices { dupes[i].items[j].selected = all && j > 0 && Dupes.autoPick(dupes[i].items[j], ask: ask) }
        }
        // Nothing could be picked (every extra copy sits in a project folder, is used by a script, shares its data, or
        // spans two drives): say so, a button that does nothing reads as broken (seen 08/11/2026).
        if all && !dupes.isEmpty && !dupes.contains(where: { $0.items.contains(where: \.selected) }) {
            dupMsg = t("No copy was selected automatically: every extra copy is inside a project folder, used by a script, on another drive, or shares its data with the copy kept (frees nothing). You can still tick copies one by one.",
                       "Không có bản nào được chọn tự động: mọi bản thừa đều nằm trong thư mục dự án, đang được script dùng, nằm ở ổ khác, hoặc dùng chung dữ liệu với bản giữ lại (xoá không giải phóng chỗ). Bạn vẫn tick tay từng bản được.")
        } else if dupMsg.hasPrefix(t("No copy was selected", "Không có bản nào được chọn")) { dupMsg = "" }
    }

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
}
