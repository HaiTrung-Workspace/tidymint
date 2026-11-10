// View model actions for the Uninstaller, leftovers, the Trash hint and Startup items (state lives in App/ViewModel.swift).
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
    func scanApps() {
        CheckIn.shared.used()
        appsBusy = true; appsMsg = ""; appsMsgErr = false
        Task.detached {
            let a = Apps.list(); let l = Apps.leftovers(); let i = Apps.installers()
            await MainActor.run { self.apps = a; self.leftovers = l; self.installers = i; self.appsBusy = false; self.markDone(.apps) }
        }
    }
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
    /// Close the detail pane first, then drop the app from the list on the next turn of the run loop. Removing it in the
    /// same update crashed (index out of range): the detail pane still held bindings to the old array position.
    func dropApp(_ id: UUID) {
        selApp = nil
        DispatchQueue.main.async { self.apps.removeAll { $0.id == id } }
    }
    /// The result line counts only what really went to the Trash (up to 0.4.0 it reported the planned total).
    func reportUninstall(_ a: AppEntry, extra: [CleanItem], ok: Int, fail: Int) {
        let moved = a.size + extra.filter { lastOK.contains($0.url) }.reduce(0) { $0 + $1.size }
        finished(.apps, ok + 1, moved, fail)
        appsMsgErr = fail > 0
        appsMsg = (ok == 0 ? t("Uninstalled \(a.name) (\(fmt(moved))).", "Đã gỡ \(a.name) (\(fmt(moved))).")
            : t("Uninstalled \(a.name) and \(ok) related items (\(fmt(moved))).", "Đã gỡ \(a.name) và \(ok) mục liên quan (\(fmt(moved)))."))
            + (fail > 0 ? t(" \(fail) could not be moved: \(lastErr).", " \(fail) mục không chuyển được: \(lastErr).") : "")
    }

    func uninstall(_ id: UUID) {
        guard let i = apps.firstIndex(where: { $0.id == id }) else { return }
        let a = apps[i]
        guard a.lock == nil else { return }
        if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == a.bundleID }) {
            _ = confirm(t("Quit \(a.name) first", "Tắt \(a.name) trước"), t("The app is running. Quit it, then try again.", "App đang mở. Tắt app rồi bấm lại."), "OK"); return
        }
        let extra = a.related.filter(\.selected)
        let total = a.size + extra.reduce(0) { $0 + $1.size }
        guard confirm(t("Uninstall \(a.name)?", "Gỡ \(a.name)?"),
                      (extra.isEmpty ? t("The app (\(fmt(total))) will be moved to the Trash.", "App (\(fmt(total))) sẽ được chuyển vào Thùng rác.") : t("The app and \(extra.count) related items (\(fmt(total))) will be moved to the Trash.", "App và \(extra.count) mục liên quan (\(fmt(total))) sẽ được chuyển vào Thùng rác."))
                        + (a.needsAdmin ? t(" macOS will ask for an administrator password in its own window; Tidymint never sees it.", " macOS sẽ hỏi mật khẩu quản trị trong hộp thoại của macOS; Tidymint không thấy mật khẩu.") : ""),
                      t("Uninstall", "Gỡ")) else { return }
        TrashHint.uninstalling(a.bundleID)   // the Trash hint stays quiet about an app removed here
        if a.needsAdmin { uninstallWithFinder(a, extra: extra, total: total); return }
        NSWorkspace.shared.recycle([a.url]) { newURLs, err in
            Task { @MainActor in
                guard err == nil else {
                    // The app itself could not go to the Trash: leave its related files where they are.
                    self.log(t("Uninstall \(a.name) failed: ", "Gỡ \(a.name) thất bại: ") + err!.localizedDescription)
                    self.appsMsgErr = true
                    self.appsMsg = t("Could not move \(a.name) to the Trash: macOS did not allow it. Nothing was moved. You can drag the app to the Trash in Finder.",
                                     "Không chuyển được \(a.name) vào Thùng rác: macOS không cho phép. Chưa có gì bị chuyển đi. Bạn có thể kéo app vào Thùng rác trong Finder.")
                    return
                }
                // Record the app in the Undo journal together with its related files, so Undo puts all of it back.
                let appEntry = newURLs[a.url].map { [Journal.Entry(from: a.url.path, to: $0.path, size: a.size)] } ?? []
                let (ok, fail) = self.trash(extra.map(\.url), label: a.name, alsoUndo: appEntry)
                self.dropApp(id)
                self.reportUninstall(a, extra: extra, ok: ok, fail: fail)
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
                    let (ok, fail) = self.trash(extra.map(\.url), label: a.name, alsoUndo: appEntry)
                    self.dropApp(a.id)
                    self.reportUninstall(a, extra: extra, ok: ok, fail: fail)
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
                if case .failed(let e) = r { self.log(t("Uninstall \(a.name) through Finder failed: \(e)", "Gỡ \(a.name) qua Finder thất bại: \(e)")) }
                self.log(self.appsMsg); self.refreshTrash(); self.refreshDisk()
            }
        }
    }
    func setTrashHint(_ v: Bool) { trashHintOn = v; UserDefaults.standard.set(v, forKey: "trashHint"); TrashHint.apply(); if !v { TrashHint.forgetAll(); trashHints = []; trashHintNote = "" } }
    func showTrashHint(_ h: TrashHintInfo, notify: Bool = true) {
        trashHintNote = ""
        trashHints.removeAll { $0.id == h.id }
        trashHints.insert(h, at: 0)
        while trashHints.count > 3 { TrashHint.forget(trashHints.removeLast().id) }
        guard notify else { return }
        let size = h.items.reduce(0) { $0 + $1.size }
        let c = UNMutableNotificationContent()
        c.title = t("\(h.name) left \(h.items.count) items behind", "\(h.name) còn để lại \(h.items.count) mục")
        c.body = t("\(fmt(size)) in Library. Nothing was removed. Open Tidymint to pick what goes.", "\(fmt(size)) trong Library. Chưa có gì bị xoá. Mở Tidymint để chọn mục cần dọn.")
        c.userInfo = ["page": "trashhint", "id": h.id]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "trashhint-" + h.id, content: c, trigger: nil))
    }
    func cleanTrashHint(_ id: String) {
        guard let h = trashHints.first(where: { $0.id == id }) else { return }
        // Checked again right before moving: never while the app is back (Put Back, reinstall) or running.
        // The same check as when the card was made, plus: the app must still be in the Trash.
        if TrashHint.stillInstalled(h.bundleID) != nil || !TrashHint.inTrash(h.bundleID) || !NSRunningApplication.runningApplications(withBundleIdentifier: h.bundleID).isEmpty {
            appsMsg = t("\(h.name) is installed again or no longer in the Trash, nothing was moved.", "\(h.name) đã được cài lại hoặc không còn trong Thùng rác, chưa chuyển gì."); appsMsgErr = true
            trashHints.removeAll { $0.id == id }; TrashHint.forget(id); return
        }
        let sel = h.items.filter { $0.selected && FileManager.default.fileExists(atPath: $0.url.path) }
        guard !sel.isEmpty else { return }
        let (ok, fail) = trash(sel.map(\.url), label: h.name, sizes: Dictionary(sel.map { ($0.url, $0.size) }, uniquingKeysWith: { a, _ in a }))
        appsMsgErr = false
        appsMsg = t("Moved \(ok) items (\(fmt(okSize(sel)))) to the Trash.", "Đã chuyển \(ok) mục (\(fmt(okSize(sel)))) vào Thùng rác.") + (fail > 0 ? t(" \(fail) failed.", " \(fail) mục lỗi.") + failNote : "")
        log(appsMsg)
        finished(.apps, ok, okSize(sel), fail); appsMsg = ""
        if let a = trashHints.firstIndex(where: { $0.id == id }) {
            trashHints[a].items.removeAll { lastOK.contains($0.url) }
            if trashHints[a].items.isEmpty { trashHints.remove(at: a); TrashHint.forget(id) }
        }
        refreshTrash(); refreshDisk()
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
        case 1: return apps.filter { $0.lastUsed.map { $0 < old } ?? false }
        case 5: return apps.filter { $0.lastUsed == nil }
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
}
