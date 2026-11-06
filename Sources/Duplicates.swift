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

// MARK: - Duplicates

struct DupGroup: Identifiable {
    let id = UUID()
    let size: Int64
    var items: [CleanItem]
    var expanded = false
    /// What trashing every copy but one frees: per-copy bytes that are not shared (APFS clones share theirs).
    var wasted: Int64 { let s = items.map(\.size); return max(0, s.reduce(0, +) - (s.max() ?? 0)) }
    var selectedSize: Int64 { items.filter(\.selected).reduce(0) { $0 + $1.size } }
    /// Copies both on the Mac and on an external drive.
    var isCross: Bool { items.contains { $0.cross == 1 } && items.contains { $0.cross == 2 } }
}

enum Dupes {
    static let roots = ["Documents", "Downloads", "Desktop", "Pictures", "Movies", "Music"].map { Scanner.home.appendingPathComponent($0) }
    static let skipDirs: Set<String> = [".git", "node_modules", "__pycache__", ".venv", "venv", "build", "DerivedData", "Backups.backupdb"]

    static func hash(_ u: URL, limit: Int? = nil) -> String? {
        guard let h = try? FileHandle(forReadingFrom: u) else { return nil }
        defer { try? h.close() }
        var hasher = SHA256(); var read = 0
        while true {
            let want = limit.map { min(1 << 20, $0 - read) } ?? (1 << 20)
            if want <= 0 { break }
            // Each 1 MB chunk is released right away; without the pool a large video piled up in memory until the end (1.5 GB peak seen).
            let n: Int = autoreleasepool {
                guard let d = try? h.read(upToCount: want), !d.isEmpty else { return 0 }
                hasher.update(data: d); return d.count
            }
            if n == 0 { break }
            read += n
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Which copy to keep: not in Downloads/Desktop/_tmp, then shorter path.
    static func keepScore(_ u: URL) -> (Int, Int) {
        let p = u.path
        let temp = ["/Downloads/", "/Desktop/", "/_tmp", "/_to_delete", "/_to-delete"].contains { p.contains($0) } ? 1 : 0
        return (temp, p.count)
    }
    /// Order a group (kept copy first) and set what is pre-selected.
    /// A group with copies both on the Mac and on an external drive follows `rule` (Prefs.crossKeep):
    /// "external" keeps the external copy, "mac" keeps the Mac copy, "ask" pre-selects nothing.
    /// Copies inside project folders are never pre-selected.
    /// The protections every automatic pick respects: project folders, cross-drive groups set to "ask", files scripts use.
    static func autoPick(_ i: CleanItem, ask: Bool) -> Bool { !Prefs.inProject(i.url.path) && !ask && i.refStrong.isEmpty && i.size > 0 }   // a clone frees nothing
    static func arrange(_ items: [CleanItem], rule: String) -> [CleanItem] {
        let onExt = { (i: CleanItem) in Prefs.onOtherDrive(i.url.path) }
        let isCross = items.contains(where: onExt) && items.contains { !onExt($0) }
        var out = items.sorted { keepScore($0.url) < keepScore($1.url) }
        if isCross && rule != "ask" {
            let keepExt = rule == "external"
            out = out.filter { onExt($0) == keepExt } + out.filter { onExt($0) != keepExt }
        }
        // APFS clones share their data: in the final order, the first copy of each clone id keeps the size, later ones count 0
        // and are never picked. Done after ordering so the kept copy is never a 0-byte clone (re-run safely by dupApplyCross).
        let full = items.map(\.size).max() ?? 0
        var seenClone = Set<UInt64>()
        for i in out.indices {
            if let c = cloneID(out[i].url.path), !seenClone.insert(c).inserted {
                out[i].size = 0; out[i].clone = true
                out[i].reason = t("APFS clone of another copy: shares its data, frees nothing", "Bản sao APFS của bản khác: dùng chung dữ liệu, xoá không giải phóng chỗ")
            } else if out[i].clone {
                out[i].size = full; out[i].clone = false; out[i].reason = ""
            }
        }
        for i in out.indices {
            out[i].cross = isCross ? (onExt(out[i]) ? 2 : 1) : 0
            out[i].selected = i > 0 && autoPick(out[i], ask: isCross && rule == "ask")
        }
        return out
    }

    /// APFS clone id (getattrlist(2) ATTR_CMNEXT_CLONEID): files with the same id share their data blocks, so trashing
    /// all but one of them frees nothing. Measured on a real Mac (macOS 26): `cp -c` copies share the id, `cp`/`cat` copies do not.
    /// (ATTR_CMNEXT_PRIVATESIZE was tried first and read 0 for every file, clone or not, so it is not used.)
    static func cloneID(_ path: String) -> UInt64? {
        var al = attrlist(bitmapcount: u_short(ATTR_BIT_MAP_COUNT), reserved: 0, commonattr: 0, volattr: 0, dirattr: 0, fileattr: 0,
                          forkattr: attrgroup_t(ATTR_CMNEXT_CLONEID))
        var buf = [UInt8](repeating: 0, count: 32)
        guard getattrlist(path, &al, &buf, buf.count, UInt32(FSOPT_ATTR_CMN_EXTENDED)) == 0 else { return nil }
        guard buf.withUnsafeBytes({ $0.loadUnaligned(fromByteOffset: 0, as: UInt32.self) }) >= 12 else { return nil }
        let v = buf.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt64.self) }
        return v == 0 ? nil : v
    }

    static func scan(minBytes: Int64 = 1_000_000, progress: @escaping (Int) -> Void) -> [DupGroup] {
        var bySize: [Int64: [URL]] = [:]
        var count = 0
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey, .isDirectoryKey, .fileResourceIdentifierKey]
        var seenFiles = Set<NSObject>()   // hard links share one file: count it once, trashing a link frees nothing
        for r in Scanner.scanRoots(roots) {
            guard let en = FileManager.default.enumerator(at: r, includingPropertiesForKeys: Array(keys),
                                                          options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, _ in true }) else { continue }
            for case let f as URL in en {
                if skipDirs.contains(f.lastPathComponent) || Scanner.skip(f.path) { en.skipDescendants(); continue }
                guard let v = try? f.resourceValues(forKeys: keys), v.isRegularFile == true, let sz = v.fileSize, Int64(sz) >= minBytes else { continue }
                if let fid = v.fileResourceIdentifier as? NSObject, !seenFiles.insert(fid).inserted { continue }
                bySize[Int64(sz), default: []].append(f)
                count += 1; if count % 500 == 0 { progress(count) }
            }
        }
        var groups: [DupGroup] = []
        for (sz, urls) in bySize where urls.count > 1 {
            var byHead: [String: [URL]] = [:]
            for u in urls { if let h = hash(u, limit: 65536) { byHead[h, default: []].append(u) } }
            for (_, us) in byHead where us.count > 1 {
                var byFull: [String: [URL]] = [:]
                for u in us { if let h = hash(u) { byFull[h, default: []].append(u) } }
                for (_, same) in byFull where same.count > 1 {
                    let items = arrange(same.map { u in
                        CleanItem(url: u, size: sz, selected: false, date: (try? u.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate)
                    }, rule: Prefs.crossKeep)
                    groups.append(DupGroup(size: sz, items: items))
                }
            }
        }
        return groups.sorted { $0.wasted > $1.wasted }
    }
}

// MARK: - Duplicates page

struct DupesView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Duplicates", "File trùng")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text)
                    Text(t("Identical files (same content, any name) over 1 MB in Documents, Downloads, Desktop, Pictures, Movies, Music, plus drives and folders added in Settings. Skips .git, node_modules, build, DerivedData and similar developer folders.",
                           "File giống hệt nhau về nội dung (dù khác tên), trên 1 MB, trong Documents, Downloads, Desktop, Pictures, Movies, Music, cùng ổ và thư mục thêm ở Cài đặt. Bỏ qua .git, node_modules, build, DerivedData và các thư mục lập trình tương tự."))
                        .font(.system(size: fs(12))).foregroundColor(Theme.sub)
                }
                Spacer()
                Menu(t("Select", "Chọn")) {
                    Button(t("Select all duplicates (keep one)", "Chọn mọi bản trùng (giữ 1 bản)")) { vm.dupAutoSelect(all: true) }
                    Button(t("Deselect all", "Bỏ chọn tất cả")) { vm.dupAutoSelect(all: false) }
                    if vm.dupes.contains(where: \.isCross) {
                        Divider()
                        Button(t("Copies on the Mac and a drive: keep the drive copy", "Bản trùng giữa máy và ổ ngoài: giữ bản trên ổ ngoài")) { vm.dupApplyCross("external") }
                        Button(t("Copies on the Mac and a drive: keep the Mac copy", "Bản trùng giữa máy và ổ ngoài: giữ bản trên máy")) { vm.dupApplyCross("mac") }
                    }
                }.menuStyle(.borderlessButton).frame(width: 70).foregroundColor(Theme.text).padding(.vertical, 3).hoverTile()
                Button { vm.scanDupes() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.icon).tip(t("Scan again", "Quét lại"), trailing: true).foregroundColor(Theme.text).padding(.leading, 6)
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 10)
            DoneBanner(vm: vm, page: .dupes)
            if !vm.dupMsg.isEmpty {
                Text(vm.dupMsg).font(.system(size: fs(12))).foregroundColor(Theme.green).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.bottom, 6)
            }
            if vm.dupBusy {
                Scanning(text: t("Comparing files... \(vm.dupCount) checked", "Đang so file... đã xem \(vm.dupCount)")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.dupes.isEmpty {
                VStack(spacing: 24) {
                    BigScanButton(label: t("Scan", "Quét")) { vm.scanDupes() }
                    Text(t("Files inside your project folders are never pre-selected.", "File trong thư mục dự án không bao giờ được tick sẵn.")).font(.system(size: fs(12))).foregroundColor(Theme.sub)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text(t("\(vm.dupes.count) groups, \(fmt(vm.dupWasted)) taken by extra copies. The first file of each group is the one suggested to keep.",
                       "\(vm.dupes.count) nhóm, \(fmt(vm.dupWasted)) bị chiếm bởi các bản thừa. File đầu tiên mỗi nhóm là bản đề xuất giữ lại."))
                    .font(.system(size: fs(12))).foregroundColor(Theme.sub).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.bottom, 8)
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach($vm.dupes) { $g in
                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    Button { vm.dupToggleGroup(g.id) } label: { CheckBox(state: vm.dupGroupState(g)) }.buttonStyle(.plain)
                                    FileThumb(url: g.items[0].url, side: 30 * uiScale)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(g.items[0].name).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .semibold)).lineLimit(1)
                                        Text(t("\(g.items.count) copies × \(fmt(g.size))", "\(g.items.count) bản × \(fmt(g.size))") + (g.isCross ? t(" · on this Mac and an external drive", " · trên máy và ổ cứng rời") : ""))
                                            .foregroundColor(Theme.sub).font(.system(size: fs(11)))
                                    }
                                    Spacer()
                                    Text(t("extra ", "thừa ") + fmt(g.wasted)).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .medium).monospacedDigit())
                                    Image(systemName: "chevron.down").rotationEffect(.degrees(g.expanded ? 0 : -90)).foregroundColor(Theme.sub)
                                }
                                .padding(12).hoverBG(14, Theme.ink.opacity(0.06)).contentShape(Rectangle())
                                .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { g.expanded.toggle() } }
                                if g.expanded {
                                    Divider().background(Theme.ink.opacity(0.1))
                                    ForEach(Array($g.items.enumerated()), id: \.element.id) { idx, $it in
                                        ItemRow(item: $it, vm: vm, showDate: true, keep: idx == 0, keepColumn: true)
                                    }.padding(.leading, 14)
                                }
                            }.background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                        }
                    }.padding(.horizontal, 24).padding(.bottom, 16)
                }
                if vm.refsBusy {
                    // The link check greps every project folder, which can take minutes. Say so where the eye is.
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small).tint(Theme.warn)
                        Text(t("Checking links in your project folders, this can take a few minutes. Feel free to use other pages meanwhile.",
                               "Đang kiểm tra liên kết trong thư mục dự án, có thể mất vài phút. Bạn cứ dùng trang khác trong lúc chờ."))
                            .font(.system(size: fs(12))).foregroundColor(Theme.text).fixedSize(horizontal: false, vertical: true)
                    }.padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Theme.warn.opacity(0.12))).padding(.horizontal, 24).padding(.bottom, 8)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selLabel(vm.dupes.reduce(0) { $0 + $1.items.filter(\.selected).count }, vm.dupSelected)).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                        Text(t("At least one copy of every file is always kept.", "Mỗi file luôn giữ lại ít nhất một bản.")).foregroundColor(Theme.sub).font(.system(size: fs(11)))
                    }
                    Spacer()
                    GhostButton(title: vm.dupAllExtrasSelected ? t("Deselect all", "Bỏ chọn tất cả") : t("Select all extra copies", "Chọn mọi bản thừa")) {
                        vm.dupAutoSelect(all: !vm.dupAllExtrasSelected)
                    }.padding(.trailing, 8).disabled(vm.refsBusy)
                    PrimaryButton(title: t("Move to Trash", "Chuyển vào Thùng rác"), action: { vm.cleanDupes() }, disabled: vm.dupSelected == 0 || vm.refsBusy)
                }.padding(.horizontal, 24).padding(.vertical, 14).background(Theme.shade.opacity(0.25))
            }
        }
    }
}
