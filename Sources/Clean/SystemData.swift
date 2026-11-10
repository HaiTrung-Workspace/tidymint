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

// MARK: - System Data explainer (inside Space Lens)

/// One piece of what macOS lumps into "System Data", with what can be done about it.
struct SysPart: Identifiable {
    enum Kind { case clean, elsewhere, system }
    enum Action { case none, url(URL), page(Page) }
    let id: String
    let icon: String
    let title: String
    let note: String
    var size: Int64              // -1 = macOS does not report it
    var kind: Kind
    var items: [CleanItem] = []
    var detail = ""
    var actionTitle = ""
    var action: Action = .none
    var selectedSize: Int64 { items.filter(\.selected).reduce(0) { $0 + $1.size } }
    var state: Int { let n = items.filter(\.selected).count; return n == 0 ? 0 : (n == items.count ? 2 : 1) }
}

enum SysData {
    static let fm = FileManager.default
    static var lib: URL { Scanner.lib }
    static func dir(_ rel: String) -> URL { lib.appendingPathComponent(rel) }
    static func sz(_ u: URL) -> Int64 { fm.fileExists(atPath: u.path) ? Scanner.size(u) : 0 }
    static func modDate(_ u: URL) -> Date? { try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }

    static func item(_ u: URL, on: Bool, label: String? = nil, minSize: Int64 = 1) -> CleanItem? {
        guard !Scanner.skip(u.path) else { return nil }
        let s = Scanner.size(u)
        guard s >= minSize else { return nil }
        var it = CleanItem(url: u, size: s, selected: on)
        it.label = label
        return it
    }

    /// Time Machine snapshots kept on the startup disk ("com.apple.TimeMachine.2026-10-28-101500.local").
    static func snapshots() -> [String] {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil"); p.arguments = ["listlocalsnapshots", "/"]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return [] }
        let d = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        return String(decoding: d, as: UTF8.self).split(separator: "\n").map(String.init).filter { $0.contains("com.apple.TimeMachine.") }
    }
    static func snapshotDate(_ s: String) -> Date? {
        guard let r = s.range(of: #"\d{4}-\d{2}-\d{2}-\d{6}"#, options: .regularExpression) else { return nil }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd-HHmmss"
        return f.date(from: String(s[r]))
    }

    /// Chromium code-sign clones in the user's boot-cleaned temp folder (sibling "X" of the "T" temp folder).
    static func browserClones() -> (count: Int, size: Int64) {
        var buf = [CChar](repeating: 0, count: 1024)
        guard confstr(_CS_DARWIN_USER_TEMP_DIR, &buf, buf.count) > 0 else { return (0, 0) }
        let x = URL(fileURLWithPath: String(cString: buf)).deletingLastPathComponent().appendingPathComponent("X")
        var n = 0; var total: Int64 = 0
        for d in Scanner.children(x, hidden: true) where d.lastPathComponent.hasSuffix(".code_sign_clone") {
            let kids = Scanner.children(d, hidden: true)
            n += kids.count
            total += Scanner.size(d)
        }
        return (n, total)
    }

    /// Space macOS counts as free for big jobs (updates, installs) but is still held by purgeable data such as snapshots.
    static func purgeable() -> Int64 {
        let v = try? Scanner.home.resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        let important = Int64(v?.volumeAvailableCapacityForImportantUsage ?? 0), plain = Int64(v?.volumeAvailableCapacity ?? 0)
        return max(0, important - plain)
    }

    static func scan() -> ([SysPart], Int64) {
        var clean: [SysPart] = [], other: [SysPart] = []

        // iPhone / iPad backups made through Finder
        let bk = dir("Application Support/MobileSync/Backup")
        let backups: [CleanItem] = Scanner.children(bk).compactMap { d in
            let info = NSDictionary(contentsOf: d.appendingPathComponent("Info.plist"))
            let name = (info?["Device Name"] as? String) ?? (info?["Display Name"] as? String) ?? d.lastPathComponent
            let date = (info?["Last Backup Date"] as? Date) ?? modDate(d)
            return item(d, on: false, label: name + (date.map { " · " + shortDate($0) } ?? ""))
        }.sorted { $0.size > $1.size }
        if !backups.isEmpty {
            clean.append(SysPart(id: "backups", icon: "iphone", title: t("iPhone and iPad backups", "Bản sao lưu iPhone, iPad"),
                                 note: t("Made by Finder when the phone was plugged in. Keep the newest one of each device you still use. Remove an old device's backup only if you are sure you no longer need what is in it: it may be the only copy. Apple's way: Finder > select the device > Manage Backups.",
                                         "Finder tạo khi cắm điện thoại vào máy. Giữ bản mới nhất của máy còn dùng. Bản của máy cũ chỉ bỏ khi chắc không cần dữ liệu trong đó: có thể đó là bản duy nhất. Cách của Apple: Finder > chọn máy > Quản lý bản sao lưu."),
                                 size: backups.reduce(0) { $0 + $1.size }, kind: .clean, items: backups))
        }

        // iOS update files (downloaded again when needed)
        let ipsw: [CleanItem] = ["iTunes/iPhone Software Updates", "iTunes/iPad Software Updates", "iTunes/iPod Software Updates"].flatMap { r in
            Scanner.children(dir(r)).filter { $0.pathExtension.lowercased() == "ipsw" }.compactMap { item($0, on: true) }
        }
        if !ipsw.isEmpty {
            clean.append(SysPart(id: "ipsw", icon: "arrow.down.circle", title: t("iOS update files", "File cập nhật iOS"),
                                 note: t("Firmware downloaded to update or restore a device. Downloaded again when needed.", "Bản cài iOS tải về để cập nhật hay khôi phục máy. Cần thì tải lại."),
                                 size: ipsw.reduce(0) { $0 + $1.size }, kind: .clean, items: ipsw))
        }

        // Xcode leftovers
        var xc: [CleanItem] = []
        if let i = item(dir("Developer/Xcode/DerivedData"), on: false, label: t("Build files (DerivedData)", "File build (DerivedData)")) { xc.append(i) }
        if let i = item(dir("Developer/CoreSimulator/Caches"), on: false, label: t("Simulator caches", "Bộ nhớ đệm máy ảo")) { xc.append(i) }
        for r in ["iOS DeviceSupport", "watchOS DeviceSupport", "tvOS DeviceSupport", "visionOS DeviceSupport"] {
            xc += Scanner.children(dir("Developer/Xcode/" + r)).compactMap { item($0, on: false, label: r.replacingOccurrences(of: "DeviceSupport", with: "") + $0.lastPathComponent) }
        }
        if !xc.isEmpty {
            clean.append(SysPart(id: "xcode", icon: "hammer", title: t("Xcode leftovers", "Rác của Xcode"),
                                 note: t("Build files rebuild on their own, the next build is slower; quit Xcode first. Device support files are copied again only from a device still on that system version.",
                                         "File build tự tạo lại, lần build sau lâu hơn; đóng Xcode trước. File hỗ trợ thiết bị chỉ được chép lại từ máy còn chạy đúng bản hệ điều hành đó."),
                                 size: xc.reduce(0) { $0 + $1.size }, kind: .clean, items: xc.sorted { $0.size > $1.size }))
        }

        // Archives: never offered here. Apple asks developers to keep the archive of every release (crash reports, re-distribution).
        // Source: research/nguon-chinh-thuc/xcode.md
        let archives = sz(dir("Developer/Xcode/Archives"))
        if archives >= 50_000_000 {
            other.append(SysPart(id: "archives", icon: "archivebox", title: t("Xcode archives", "Bản archive của Xcode"),
                                 note: t("Builds you archived in Xcode. Keep the archive of every version you released: it is needed to read crash reports and to distribute that build again. Remove old ones in Xcode's Organizer.",
                                         "Các bản build đã archive trong Xcode. Giữ archive của mọi bản đã phát hành: cần để đọc báo cáo lỗi và phát hành lại bản đó. Xoá bản cũ trong cửa sổ Organizer của Xcode."),
                                 size: archives, kind: .elsewhere))
        }

        // Things that are cleaned elsewhere
        let cache = sz(dir("Caches")) + sz(dir("Logs"))
        if cache >= 50_000_000 {
            other.append(SysPart(id: "caches", icon: "internaldrive", title: t("Caches and logs", "Bộ nhớ đệm và nhật ký"),
                                 note: t("Part of System Data too. Clean them on the Clean Now page, where each item says what happens after.",
                                         "Cũng nằm trong System Data. Dọn ở trang Dọn ngay, mỗi mục ghi rõ dọn xong thì sao."),
                                 size: cache, kind: .elsewhere, actionTitle: Page.smart.label, action: .page(.smart)))
        }
        let sims = sz(dir("Developer/CoreSimulator/Devices"))
        if sims >= 50_000_000 {
            other.append(SysPart(id: "sims", icon: "ipad.and.iphone", title: t("iPhone simulators", "Máy ảo iPhone"),
                                 note: t("Delete old ones in Xcode, or run xcrun simctl delete unavailable, so Xcode keeps track of them. Don't delete the folder by hand.",
                                         "Xoá máy ảo cũ trong Xcode, hoặc chạy lệnh xcrun simctl delete unavailable, để Xcode không bị lẫn. Đừng xoá tay thư mục."),
                                 size: sims, kind: .elsewhere))
        }
        let docker = sz(dir("Containers/com.docker.docker/Data/vms"))
        if docker >= 50_000_000 {
            other.append(SysPart(id: "docker", icon: "shippingbox", title: t("Docker disk", "Ổ ảo của Docker"),
                                 note: t("One big file holding every image and container. Shrink it from Docker Desktop (Troubleshoot > Clean up data, which removes every container and image) or with docker system prune.",
                                         "Một file lớn chứa mọi image, container. Thu nhỏ trong Docker Desktop (Troubleshoot > Clean up data, xoá hết container và image) hoặc lệnh docker system prune."),
                                 size: docker, kind: .elsewhere))
        }
        let msg = sz(dir("Messages/Attachments"))
        if msg >= 50_000_000 {
            other.append(SysPart(id: "messages", icon: "message", title: t("Messages attachments", "Ảnh, file trong Tin nhắn"),
                                 note: t("Photos and files from iMessage chats. Remove them in Messages or in System Settings > General > Storage > Messages, not by deleting the folder. Note: changing Keep messages deletes whole older conversations, not only the files.",
                                         "Ảnh, file trong các cuộc trò chuyện iMessage. Xoá trong app Tin nhắn hoặc Cài đặt hệ thống > Cài đặt chung > Dung lượng > Tin nhắn, đừng xoá tay thư mục. Lưu ý: đổi mục Giữ tin nhắn sẽ xoá cả các cuộc trò chuyện cũ, không chỉ file."),
                                 size: msg, kind: .elsewhere))
        }

        // Things macOS manages itself
        // Chromium browsers clone their app into the per-user folder macOS empties at boot (/private/var/folders/.../X),
        // one clone per launch; clones left by a browser that did not quit cleanly stay until restart.
        // Source: research/nguon-chinh-thuc/chrome-va-web-app.md (Chromium code_sign_clone_manager.mm). Never offered for removal.
        let clones = browserClones()
        if clones.size >= 500_000_000 {
            other.append(SysPart(id: "browserclones", icon: "globe", title: t("Browser temporary copies", "Bản sao tạm của trình duyệt"),
                                 note: t("Chrome, and browsers built on it such as Edge and Brave, put a copy of themselves here when they open, so the browser can check its signature while an update waits to install. A copy can be left behind, for example when the browser is closed abruptly. macOS empties this folder when the Mac restarts. Tidymint leaves it alone: the open browser is still using one copy. The size is an upper limit: the copies share data, so they may take less.",
                                         "Chrome và các trình duyệt cùng lõi như Edge, Brave đặt một bản sao của chính nó ở đây khi mở, để kiểm chữ ký khi có bản cập nhật chờ cài. Bản sao có thể bị sót lại, ví dụ khi trình duyệt bị tắt ngang. macOS tự xoá thư mục này khi khởi động lại máy. Tidymint không đụng tới: trình duyệt đang mở vẫn dùng một bản. Con số là mức tối đa: các bản sao dùng chung dữ liệu nên có thể chiếm ít hơn."),
                                 size: clones.size, kind: .system, detail: t("\(clones.count) copies", "\(clones.count) bản")))
        }
        let snaps = snapshots()
        let tmURL = URL(string: "x-apple.systempreferences:com.apple.Time-Machine-Settings.extension")!
        let last = snaps.compactMap(snapshotDate).max()
        other.append(SysPart(id: "snapshots", icon: "clock.arrow.circlepath", title: t("Time Machine snapshots on this Mac", "Bản sao lưu Time Machine nằm trên máy"),
                             note: snaps.isEmpty
                                ? t("None right now. When automatic Time Machine backups are on, macOS keeps hourly snapshots on this Mac and removes them by itself.",
                                    "Hiện không có. Khi bật sao lưu Time Machine tự động, macOS giữ bản chụp theo giờ trên máy và tự xoá.")
                                : t("Time Machine takes these every hour while automatic backups are on. Hourly ones are kept for 24 hours, a few for longer, and macOS removes them sooner when it needs space. Tidymint leaves them alone: deleting one is permanent and cannot go to the Trash.",
                                    "Time Machine chụp mỗi giờ khi bật sao lưu tự động. Bản theo giờ giữ 24 giờ, vài bản giữ lâu hơn, và macOS xoá sớm hơn khi cần chỗ. Tidymint không xoá phần này: xoá là mất hẳn, không vào Thùng rác được."),
                             size: -1, kind: snaps.isEmpty ? .system : .elsewhere,
                             detail: snaps.isEmpty ? "" : t("\(snaps.count) snapshots", "\(snaps.count) bản") + (last.map { t(", newest ", ", mới nhất ") + shortDate($0) } ?? ""),
                             actionTitle: t("Time Machine Settings", "Mở cài đặt Time Machine"), action: .url(tmURL)))

        var vm: Int64 = 0
        for u in Scanner.children(URL(fileURLWithPath: "/private/var/vm"), hidden: true) {
            vm += Int64((try? u.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize) ?? 0)
        }
        if vm > 0 {
            other.append(SysPart(id: "vm", icon: "memorychip", title: t("Swap and sleep files", "Bộ nhớ ảo và file ngủ"),
                                 note: t("Used when memory runs short and when the Mac sleeps. macOS creates and removes them. Do not delete.",
                                         "Dùng khi thiếu RAM và khi máy ngủ. macOS tự tạo, tự xoá. Không nên xoá."),
                                 size: vm, kind: .system))
        }
        return (clean.sorted { $0.size > $1.size } + other, purgeable())
    }
}

final class OpenSet: ObservableObject { @Published var v = Set<String>() }

struct SysPartCard: View {
    @Binding var part: SysPart
    @ObservedObject var vm: VM
    @ObservedObject var open: OpenSet
    var badge: (String, Color) {
        switch part.kind {
        case .clean: return (t("Can clean here", "Dọn được ở đây"), Theme.green)
        case .elsewhere: return (t("Handled elsewhere", "Dọn ở chỗ khác"), Theme.warn)
        case .system: return (t("Leave to macOS", "Để macOS lo"), Theme.sub)
        }
    }
    var body: some View {
        let isOpen = open.v.contains(part.id)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                if part.kind == .clean {
                    Button { let on = part.state != 2; for i in part.items.indices { part.items[i].selected = on } } label: { CheckBox(state: part.state) }
                        .buttonStyle(.plain).padding(.top, 8)
                }
                Image(systemName: part.icon).font(.system(size: fs(15))).foregroundStyle(Theme.accent)
                    .frame(width: 32, height: 32).background(Circle().fill(Theme.accent.opacity(0.14)))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(part.title).font(.system(size: fs(13))).foregroundColor(Theme.text)
                        Spacer(minLength: 8)
                        StatusTag(badge.0, badge.1)
                    }
                    Text(part.note).font(.system(size: fs(12))).foregroundColor(Theme.sub).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 14) {
                        if part.kind == .clean {
                            TextLink(isOpen ? t("Hide items", "Ẩn danh sách") : t("Show \(part.items.count) items", "Xem \(part.items.count) mục"), size: fs(12), weight: .semibold) {
                                if isOpen { open.v.remove(part.id) } else { open.v.insert(part.id) }
                            }
                        }
                        if !part.actionTitle.isEmpty {
                            TextLink(part.actionTitle, size: fs(12), weight: .semibold) {
                                switch part.action {
                                case .url(let u): NSWorkspace.shared.open(u)
                                case .page(let p): vm.page = p
                                case .none: break
                                }
                            }
                        }
                    }.padding(.top, 2)
                }
                Spacer(minLength: 8)
                if part.size >= 0 || !part.detail.isEmpty { VStack(alignment: .trailing, spacing: 2) {
                    Text(part.size < 0 ? part.detail : fmt(part.size))
                        .font(.system(size: fs(part.size < 0 ? 13 : 17), weight: .bold).monospacedDigit()).foregroundColor(Theme.text)
                    if part.size < 0 && !part.detail.isEmpty {
                        Text(t("size not measured", "chưa đo được dung lượng")).font(.system(size: fs(10))).foregroundColor(Theme.sub)
                    }
                } }
            }.padding(14)
            if isOpen && part.kind == .clean {
                VStack(spacing: 2) {
                    ForEach($part.items) { $it in ItemRow(item: $it, vm: vm) }
                }.padding(.horizontal, 8).padding(.bottom, 8)
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
    }
}

struct SysDataView: View {
    @ObservedObject var vm: VM
    @StateObject private var open = OpenSet()
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { vm.sysOpen = false } label: { Image(systemName: "chevron.left") }.buttonStyle(.icon).foregroundColor(Theme.text).tip(t("Back", "Lùi"))
                Text(t("What is in System Data", "System Data gồm những gì")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text)
                Spacer()
                if !vm.sysBusy { TextLink(t("Scan again", "Quét lại"), size: fs(12), weight: .semibold, color: Theme.text) { vm.scanSys() } }
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 6)
            Text(t("System Data is what macOS cannot file under another category: mostly logs, caches and temporary files. Below are the things that most often fill a Mac, including a few macOS lists under other categories (iOS Files, Messages, Developer). The ones with a checkbox can be cleaned here, the rest say where to handle them or to leave them alone. Notes that point to another page appear from 50 MB, and this page does not list everything macOS counts as System Data, so the total is lower than macOS shows.",
                   "Dữ liệu hệ thống là phần macOS không xếp được vào nhóm nào khác: chủ yếu nhật ký, bộ nhớ đệm, file tạm. Dưới đây là những thứ hay làm đầy ổ mà Tidymint đo được, kể cả vài thứ macOS xếp ở nhóm khác (File iOS, Tin nhắn, Nhà phát triển). Phần có ô chọn thì dọn được ở đây, phần còn lại ghi rõ dọn ở đâu hoặc nên để yên. Thẻ \"Dọn ở chỗ khác\" chỉ hiện khi từ 50 MB, và trang này không liệt kê hết những gì macOS tính vào Dữ liệu hệ thống, nên tổng thấp hơn con số macOS hiện."))
                .font(.system(size: fs(12))).foregroundColor(Theme.sub).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.bottom, 12)
            DoneBanner(vm: vm, page: .lens)
            if vm.sysBusy && vm.sysParts.isEmpty {
                Scanning(text: t("Looking inside System Data...", "Đang xem System Data gồm những gì...")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        if vm.sysPurgeable >= 1_000_000_000 {
                            HStack(spacing: 10) {
                                Image(systemName: "info.circle").foregroundColor(Theme.link)
                                Text(t("About \(fmt(vm.sysPurgeable)) is held by data macOS can free on its own, such as caches. It is released when an update or a big file needs the room.",
                                       "Khoảng \(fmt(vm.sysPurgeable)) đang bị giữ bởi dữ liệu macOS tự giải phóng được, ví dụ bộ nhớ đệm. Khi cài bản cập nhật hay chép file lớn cần chỗ, macOS sẽ tự nhả ra."))
                                    .font(.system(size: fs(12))).foregroundColor(Theme.text).fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }.padding(14).background(RoundedRectangle(cornerRadius: 14).fill(Theme.link.opacity(0.10)))
                        }
                        ForEach($vm.sysParts) { $p in SysPartCard(part: $p, vm: vm, open: open) }
                        Text(t("The rest is data macOS manages itself: logs, caches and temporary files of the system. Tidymint does not touch it.",
                               "Phần còn lại là dữ liệu macOS tự quản: nhật ký, bộ nhớ đệm, file tạm của hệ thống. Tidymint không đụng tới."))
                            .font(.system(size: fs(11))).foregroundColor(Theme.sub).fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                    }.padding(.horizontal, 24).padding(.bottom, 16)
                }
            }
            HStack {
                let sel = vm.sysParts.flatMap { $0.items.filter(\.selected) }
                if sel.isEmpty {
                    Text(t("Tick items to move them to the Trash.", "Tick mục muốn chuyển vào Thùng rác.")).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                    Spacer()
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selLabel(sel.count, sel.reduce(0) { $0 + $1.size })).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                        Text(t("Moved to the Trash, not deleted yet.", "Chỉ chuyển vào Thùng rác, chưa xoá hẳn.")).foregroundColor(Theme.sub).font(.system(size: fs(11)))
                    }
                    Spacer()
                    PrimaryButton(title: t("Move to Trash", "Chuyển vào Thùng rác"), action: { vm.trashSys() })
                }
            }.padding(.horizontal, 24).padding(.vertical, 12).background(Theme.shade.opacity(0.25))
        }
    }
}
