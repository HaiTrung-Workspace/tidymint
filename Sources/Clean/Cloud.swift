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

// MARK: - Cloud

struct CloudProvider: Identifiable {
    let id = UUID()
    let name: String        // Google Drive, iCloud Drive, Dropbox...
    let account: String
    let root: URL
    let isICloud: Bool
    var local: Int64 = 0
    var items: [Node] = []
    var expanded = false
}

enum Cloud {
    static func providers() -> [CloudProvider] {
        var out: [CloudProvider] = []
        let cs = Scanner.lib.appendingPathComponent("CloudStorage")
        for d in Scanner.children(cs) {
            let n = d.lastPathComponent
            var name = n, acc = ""
            if let r = n.range(of: "-") { name = String(n[..<r.lowerBound]); acc = String(n[r.upperBound...]) }
            name = name.replacingOccurrences(of: "GoogleDrive", with: "Google Drive").replacingOccurrences(of: "OneDrive", with: "OneDrive")
            out.append(CloudProvider(name: name, account: acc, root: d, isICloud: false))
        }
        let ic = Scanner.lib.appendingPathComponent("Mobile Documents/com~apple~CloudDocs")
        if FileManager.default.fileExists(atPath: ic.path) {
            out.append(CloudProvider(name: "iCloud Drive", account: "", root: ic, isICloud: true))
        }
        return out
    }
    /// Size actually stored on this Mac (cloud-only files count as 0 and are not downloaded).
    static func localSize(_ path: String) -> Int64 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        p.arguments = ["-skx", path]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return 0 }
        let d = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        let str = String(data: d, encoding: .utf8) ?? ""
        return (Int64(str.split(whereSeparator: { $0 == "\t" || $0 == " " }).first ?? "0") ?? 0) * 1024
    }
    /// First-level folders (for Google Drive, also open "My Drive").
    static func topItems(_ root: URL) -> [URL] {
        var out: [URL] = []
        for c in Scanner.children(root) {
            let n = c.lastPathComponent
            if ["My Drive", "Drive của tôi"].contains(n) { out += Scanner.children(c) } else { out.append(c) }
        }
        return out
    }
    /// iCloud only: remove the local download, keep the file in the cloud.
    static func evict(_ url: URL) -> (Int, Int) {
        var ok = 0, fail = 0
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        let files: [URL]
        if isDir.boolValue {
            var f: [URL] = []
            if let en = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                for case let u as URL in en where (try? u.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true { f.append(u) }
            }
            files = f
        } else { files = [url] }
        for f in files { do { try FileManager.default.evictUbiquitousItem(at: f); ok += 1 } catch { fail += 1 } }
        return (ok, fail)
    }
}

func ramInfo() -> (used: Double, total: Double) {
    var stats = vm_statistics64()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
    let r = withUnsafeMutablePointer(to: &stats) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
    }
    let total = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
    guard r == KERN_SUCCESS else { return (0, total) }
    let ps = Double(getpagesize())
    let pages = Double(stats.internal_page_count) - Double(stats.purgeable_count) + Double(stats.wire_count) + Double(stats.compressor_page_count)
    return (max(0, pages * ps / 1_073_741_824), total)
}

// MARK: - Cloud page

struct CloudView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Cloud Cleanup", "Dữ liệu đám mây")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text)
                    Text(t("How much of Google Drive, iCloud and other cloud folders is stored on this Mac. Files that live only in the cloud count as 0.",
                           "Google Drive, iCloud và các thư mục mây đang chiếm bao nhiêu trên máy. File chỉ nằm trên mây tính là 0."))
                        .foregroundColor(Theme.sub).font(.system(size: fs(12)))
                }
                Spacer()
                if vm.cloudBusy { ProgressView().controlSize(.small).tint(Theme.text) }
                Button { vm.scanCloud() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.icon).tip(t("Scan again", "Quét lại"), trailing: true).foregroundColor(Theme.text)
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 12)
            if !vm.cloudMsg.isEmpty {
                Text(vm.cloudMsg).font(.system(size: fs(12))).foregroundColor(Theme.green).padding(.horizontal, 24).padding(.bottom, 8)
            }
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach($vm.clouds) { $p in
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Image(systemName: p.isICloud ? "icloud.fill" : "externaldrive.connected.to.line.below")
                                    .font(.system(size: fs(15))).foregroundStyle(Theme.accent).frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).foregroundColor(Theme.text).font(.system(size: fs(13)))
                                    if !p.account.isEmpty { Text(p.account).foregroundColor(Theme.sub).font(.system(size: fs(11))) }
                                }
                                Spacer()
                                Text(t("on this Mac: ", "trên máy: ")).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                                Text(fmt(p.local)).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .medium).monospacedDigit())
                                Image(systemName: "chevron.down").rotationEffect(.degrees(p.expanded ? 0 : -90)).foregroundColor(Theme.sub)
                            }
                            .padding(14).hoverBG(14, Theme.ink.opacity(0.06)).contentShape(Rectangle())
                            .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { p.expanded.toggle() } }
                            if p.expanded {
                                Divider().background(Theme.ink.opacity(0.1))
                                if !p.isICloud {
                                    Text(t("macOS only lets the Drive app remove downloads. Click Show in Finder, then right-click > Remove Download.",
                                           "macOS chỉ cho app Drive gỡ bản tải xuống. Bấm Mở trong Finder, rồi chuột phải > Remove Download (Xoá bản tải xuống)."))
                                        .font(.system(size: fs(11))).foregroundColor(Theme.warn).padding(.horizontal, 14).padding(.top, 8)
                                }
                                if p.items.isEmpty {
                                    Text(t("Nothing stored locally.", "Không có gì lưu trên máy.")).font(.system(size: fs(12))).foregroundColor(Theme.sub).padding(14)
                                }
                                ForEach(p.items) { n in
                                    HStack(spacing: 10) {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: n.url.path)).resizable().frame(width: 20, height: 20)
                                        Text(n.url.lastPathComponent).foregroundColor(Theme.text).font(.system(size: fs(12))).lineLimit(1)
                                        Spacer()
                                        Text(fmt(n.size)).foregroundColor(Theme.sub).font(.system(size: fs(12)).monospacedDigit())
                                        if p.isICloud {
                                            TextLink(t("Remove Download", "Xoá bản trên máy"), size: 11, weight: .semibold) { vm.evictICloud(n.url) }
                                        }
                                        TextLink(t("Show in Finder", "Mở trong Finder"), size: 11, weight: .regular, color: Theme.ink.opacity(0.8)) { vm.reveal(n.url) }
                                    }.padding(.horizontal, 14).padding(.vertical, 6).hoverBG(8, Theme.ink.opacity(0.07))
                                }
                            }
                        }.background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                    }
                }.padding(.horizontal, 24).padding(.bottom, 16)
            }
        }
        .onAppear { if vm.clouds.isEmpty { vm.scanCloud() } }
    }
}
