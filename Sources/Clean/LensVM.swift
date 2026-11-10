// View model actions for Space Lens and System Data (state lives in App/ViewModel.swift).
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
    func openSys() { sysOpen = true; if sysParts.isEmpty { scanSys() } }
    func scanSys() {
        sysBusy = true
        Task.detached {
            let (parts, purge) = SysData.scan()
            await MainActor.run { self.sysParts = parts; self.sysPurgeable = purge; self.sysBusy = false }
        }
    }
    func trashSys() {
        let picked = sysParts.flatMap { $0.items.filter(\.selected) }.filter { !Scanner.blocked($0.url.path) }
        guard !picked.isEmpty else { return }
        guard confirm(t("Move \(picked.count) items to the Trash?", "Chuyển \(picked.count) mục vào Thùng rác?"),
                      picked.prefix(8).map { "• \($0.name), \(fmt($0.size))" }.joined(separator: "\n") + (picked.count > 8 ? "\n…" : ""),
                      t("Move to Trash", "Chuyển vào Thùng rác")) else { return }
        let (ok, fail) = trash(picked.map(\.url), label: "sysdata", sizes: Dictionary(picked.map { ($0.url, $0.size) }, uniquingKeysWith: { a, _ in a }))
        let freed = okSize(picked)
        log(t("System Data: moved \(ok) items (\(fmt(freed))) to the Trash.", "Dữ liệu hệ thống: đã chuyển \(ok) mục (\(fmt(freed))) vào Thùng rác."))
        finished(.lens, ok, freed, fail)
        scanSys(); refreshTrash(); refreshDisk()
    }
    func lensBack() { guard lensPath.count > 1 else { return }; lensFwd.append(lensPath.removeLast()); lensSel = []; loadLens() }
    func lensForward() { guard let u = lensFwd.popLast() else { return }; lensPath.append(u); lensSel = []; loadLens() }
    func trashLensSelection() {
        let picked = lensNodes.filter { lensSel.contains($0.url) && !Scanner.blocked($0.url.path) }
        guard !picked.isEmpty else { return }
        let size = picked.reduce(0) { $0 + $1.size }
        guard confirm(t("Move \(picked.count) items to the Trash?", "Chuyển \(picked.count) mục vào Thùng rác?"),
                      picked.prefix(8).map { "• \($0.name), \(fmt($0.size))" }.joined(separator: "\n") + (picked.count > 8 ? "\n…" : ""),
                      t("Move to Trash", "Chuyển vào Thùng rác")) else { return }
        let (ok, fail) = trash(picked.map(\.url), label: "lens", strict: false)
        let gone = lastOK
        let freed = picked.filter { gone.contains($0.url) }.reduce(0) { $0 + $1.size }
        lensNodes.removeAll { gone.contains($0.url) }
        for u in gone { sizeCache.removeValue(forKey: u.path) }
        lensSel = []
        log(t("Space Lens: moved \(ok) items (\(fmt(freed))) to the Trash.", "Bản đồ ổ đĩa: đã chuyển \(ok) mục (\(fmt(freed))) vào Thùng rác.")); _ = size
        finished(.lens, ok, freed, fail)
        refreshTrash(); refreshDisk()
    }

    // Space Lens
    func openLens(_ u: URL) {
        if lensPath.isEmpty { CheckIn.shared.used() }
        lensPath.append(u); lensFwd = []; lensSel = []; loadLens()
    }
    func lensUp(to i: Int) { lensPath = Array(lensPath.prefix(i + 1)); lensFwd = []; lensSel = []; loadLens() }

    nonisolated static func du(_ path: String) -> Int64 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        p.arguments = ["-skx", "-I", "CloudStorage", "-I", "Mobile Documents", path]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return 0 }
        let d = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let str = String(data: d, encoding: .utf8) ?? ""
        return (Int64(str.split(whereSeparator: { $0 == "\t" || $0 == " " }).first ?? "0") ?? 0) * 1024
    }

    func loadLens() {
        guard let u = lensPath.last else { return }
        let token = UUID(); lensToken = token
        let kids = Scanner.children(u, hidden: true).filter { !IgnoreList.contains($0.path) }
        lensNodes = []; lensDone = 0; lensTotal = kids.count; lensBusy = !kids.isEmpty; lensCurrent = ""
        let cloud = ["CloudStorage", "Mobile Documents"]
        var todo: [URL] = []
        for k in kids {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: k.path, isDirectory: &isDir)
            let dir = isDir.boolValue && k.pathExtension.lowercased() != "app"
            if cloud.contains(k.lastPathComponent) { lensDone += 1; continue }          // cloud files, not counted
            if let c = sizeCache[k.path] {
                if c > 0 { lensNodes.append(Node(url: k, size: c, isDir: dir)) }
                lensDone += 1
            } else { todo.append(k) }
        }
        lensNodes.sort { $0.size > $1.size }
        if todo.isEmpty { lensBusy = false; return }
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.concurrentPerform(iterations: todo.count) { i in
                let k = todo[i]
                DispatchQueue.main.async { if self.lensToken == token { self.lensCurrent = k.lastPathComponent } }
                let sz = VM.du(k.path)
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: k.path, isDirectory: &isDir)
                let node = Node(url: k, size: sz, isDir: isDir.boolValue && k.pathExtension.lowercased() != "app")
                DispatchQueue.main.async {
                    guard self.lensToken == token else { return }
                    self.sizeCache[k.path] = sz
                    if sz > 0 { self.lensNodes.append(node); self.lensNodes.sort { $0.size > $1.size } }
                    self.lensDone += 1
                    if self.lensDone >= self.lensTotal { self.lensBusy = false; self.lensCurrent = ""; self.markDone(.lens) }
                }
            }
        }
    }
    func stopLens() { lensToken = UUID(); lensBusy = false; lensCurrent = "" }
    func rescanLens() { if let u = lensPath.last { sizeCache = sizeCache.filter { !$0.key.hasPrefix(u.path) } }; loadLens() }
    func trashNode(_ n: Node) {
        guard confirm(t("Move to Trash?", "Chuyển vào Thùng rác?"), "\(n.name), \(fmt(n.size))", t("Move to Trash", "Chuyển vào Thùng rác")) else { return }
        let (ok, fail) = trash([n.url], label: "lens", strict: false)
        if ok > 0 { lensNodes.removeAll { $0.id == n.id }; lensSel.remove(n.url); sizeCache.removeValue(forKey: n.url.path); log(t("Space Lens: moved \(n.url.path) (\(fmt(n.size))) to the Trash.", "Bản đồ ổ đĩa: đã chuyển \(n.url.path) (\(fmt(n.size))) vào Thùng rác.")) }
        finished(.lens, ok, ok > 0 ? n.size : 0, fail)
        refreshTrash(); refreshDisk()
    }
}
