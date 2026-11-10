// View model actions for Clean by App and its month viewer (state lives in App/ViewModel.swift).
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
    func refreshAppRunning() { for i in appReports.indices { appReports[i].running = AppRules.isRunning(appReports[i].rule) } }
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
    /// Rows built by code, read again and compared with the scan. Every row counts, ticked or not, and so does a row
    /// that is new: a model pulled after the scan may share a file with the ticked ones, and that file must then stay
    /// (found in review 11/2026). Size too: a folder row keeps its path while files are added to it.
    func customRowsChanged(_ r: AppReport) -> Bool {
        for g in r.groups where g.section.safety != .locked {
            guard let build = g.section.custom else { continue }
            let fresh = Dictionary(build().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            if Set(fresh.keys) != Set(g.rows.map(\.id)) { return true }
            if g.rows.contains(where: { row in
                guard let f = fresh[row.id] else { return true }
                return Set(f.urls) != Set(row.urls) || Set(f.shared.keys) != Set(row.shared.keys) || (row.selected && f.size != row.size)
            }) { return true }
        }
        return false
    }
    func cleanApp(_ id: String) {
        guard let i = appReports.firstIndex(where: { $0.id == id }) else { return }
        let r = appReports[i]
        refreshAppRunning()
        if appReports[i].running {
            _ = confirm(t("Quit \(r.rule.name) first", "Tắt \(r.rule.name) trước"), t("The app is open and may be writing these files. Quit it, then clean.", "App đang mở, có thể đang ghi vào các file này. Tắt app rồi dọn."), "OK"); return
        }
        // Rows built by code (AI models, LM Studio engines) are read again right now: a tool may have changed its files
        // since the scan (a model pulled, another engine version chosen). Any ticked row that is gone or differs: stop.
        if customRowsChanged(r) {
            let a = NSAlert()   // one button: there is nothing to choose
            a.messageText = t("\(r.rule.name) changed since the scan", "\(r.rule.name) vừa thay đổi sau lần quét")
            a.informativeText = t("Nothing was moved. The list will refresh; pick again.", "Chưa chuyển gì cả. Danh sách sẽ được quét lại, bạn chọn lại nhé.")
            a.addButton(withTitle: t("OK", "OK")); a.runModal()
            scanByApp(); return
        }
        let rows = r.groups.filter { $0.section.safety != .locked }.flatMap { $0.rows.filter(\.selected) }
        // Parts shared between rows (Ollama blobs) go too once every row that shares them is ticked.
        let freed = r.groups.filter { $0.section.safety != .locked }.flatMap { $0.sharedParts(freed: true) }
        let urls = rows.flatMap(\.selURLs) + freed.flatMap(\.urls)
        let size = rows.reduce(0) { $0 + $1.selSize } + freed.reduce(0) { $0 + $1.size }
        let risky = r.groups.contains { $0.section.safety == .review && $0.rows.contains(where: \.selected) }
        let body = risky
            ? t("\(urls.count) items (\(fmt(size))) go to the Trash. What you ticked is removed from this Mac; put it back from the Trash if you change your mind.",
                "\(urls.count) mục (\(fmt(size))) sẽ vào Thùng rác. Những gì đã tick sẽ mất trên máy này; đổi ý thì trả về từ Thùng rác.")
            : t("\(urls.count) items (\(fmt(size))) go to the Trash.", "\(urls.count) mục (\(fmt(size))) sẽ vào Thùng rác.")
        guard confirm(t("Clean \(r.rule.name)?", "Dọn \(r.rule.name)?"), body, t("Move to Trash", "Chuyển vào Thùng rác")) else { return }
        let (ok, fail) = trash(urls, label: "app:" + id)
        // Report what really moved: when something was refused, its share of the size is left out (a row with several
        // files counts by the part of its files that went).
        var done: Int64 = 0
        for row in rows { let u = row.selURLs; if !u.isEmpty { done += row.selSize * Int64(u.filter { lastOK.contains($0) }.count) / Int64(u.count) } }
        for part in freed where !part.urls.isEmpty { done += part.size * Int64(part.urls.filter { lastOK.contains($0) }.count) / Int64(part.urls.count) }
        if fail == 0 { done = size }
        appMsg = t("\(r.rule.name): moved \(ok) items (\(fmt(done))) to the Trash.", "\(r.rule.name): đã chuyển \(ok) mục (\(fmt(done))) vào Thùng rác.") + (fail > 0 ? t(" Skipped \(fail).", " Bỏ qua \(fail).") + failNote : "")
        log(appMsg)
        finished(.byapp, ok, done, fail); appMsg = ""
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
    static let fdaSettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
}
