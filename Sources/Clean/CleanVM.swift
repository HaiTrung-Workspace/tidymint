// View model actions for Clean Now, Large Files and Cloud (state lives in App/ViewModel.swift).
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
        guard !cloudBusy else { return }
        cloudBusy = true   // a folder with many files took seconds on the main thread
        Task.detached {
            let (ok, fail) = Cloud.evict(u)
            await MainActor.run { [weak self] in self?.cloudBusy = false; self?.evictDone(u, ok: ok, fail: fail) }
        }
    }
    private func evictDone(_ u: URL, ok: Int, fail: Int) {
        cloudMsg = t("Removed local copies of \(ok) files (still in iCloud).", "Đã xoá bản trên máy của \(ok) file (vẫn còn trên iCloud).") + (fail > 0 ? t(" \(fail) failed.", " \(fail) file lỗi.") : "")
        log(t("Cloud: removed local copy of \(u.path), ok \(ok), failed \(fail)", "Đám mây: gỡ bản tải về của \(u.path), được \(ok), lỗi \(fail)"))
        scanCloud(); refreshDisk()
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

    func toggleCat(_ id: String) {
        guard let i = cats.firstIndex(where: { $0.id == id }) else { return }
        // Tick when something tickable is still unticked; otherwise clear. Items of an open app are never ticked here,
        // so "all ticked" is judged without them (or the box could never be cleared).
        let on = cats[i].items.contains { !$0.selected && !$0.running }
        for j in cats[i].items.indices where !(on && cats[i].items[j].running) { cats[i].items[j].selected = on }
    }

    func setAll(_ on: Bool) {
        for i in cats.indices { for j in cats[i].items.indices where !(on && cats[i].items[j].running) { cats[i].items[j].selected = on } }
    }

    func okSize(_ items: [CleanItem]) -> Int64 { items.filter { lastOK.contains($0.url) }.reduce(0) { $0 + $1.size } }

    func cleanJunk() {
        // Dependency folders and Git working copies are checked again right now: a project may have come back to life
        // since the scan. One lsof run serves both groups.
        var skippedNow = 0
        let recheck = cats.contains { ["devdeps", "worktrees"].contains($0.id) && $0.items.contains(where: \.selected) }
        let cwds = recheck ? DevDeps.workingDirs() : nil
        if let i = cats.firstIndex(where: { $0.id == "devdeps" }) {
            for j in cats[i].items.indices where cats[i].items[j].selected {
                if cwds == nil || DevDeps.verdict(cats[i].items[j].url, cwds: cwds ?? []) == nil {
                    cats[i].items[j].selected = false; skippedNow += 1
                    cats[i].items[j].reason = t("Skipped: the project changed or is in use now", "Đã bỏ qua: dự án vừa thay đổi hoặc đang được dùng")
                }
            }
        }
        if let i = cats.firstIndex(where: { $0.id == "worktrees" }) {
            for j in cats[i].items.indices where cats[i].items[j].selected {
                if cwds == nil || !DevDeps.orphaned(cats[i].items[j].url, cwds: cwds ?? []) {
                    cats[i].items[j].selected = false; skippedNow += 1
                    cats[i].items[j].reason = t("Skipped: git tracks it again or it is in use now", "Đã bỏ qua: git đã theo dõi lại hoặc đang được dùng")
                }
            }
        }
        let sel = cats.flatMap { $0.items.filter(\.selected) }
        let size = sel.reduce(0) { $0 + $1.size }
        let (ok, fail) = trash(sel.map(\.url), label: "cleanup", sizes: Dictionary(sel.map { ($0.url, $0.size) }, uniquingKeysWith: { a, _ in a })); _ = size
        lastFreed = okSize(sel); lastCount = ok
        lastResult = t("Moved \(ok) items (\(fmt(okSize(sel)))) to the Trash.", "Đã chuyển \(ok) mục (\(fmt(okSize(sel)))) vào Thùng rác.") + (fail > 0 ? t(" Skipped \(fail) items.", " Bỏ qua \(fail) mục.") + failNote : "")
            + (skippedNow > 0 ? t(" \(skippedNow) project items were left alone: the project changed or is in use since the scan.", " \(skippedNow) mục của dự án được để yên: dự án vừa thay đổi hoặc đang được dùng sau lần quét.") : "")
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
}
