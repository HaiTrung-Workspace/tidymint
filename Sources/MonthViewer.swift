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

// MARK: - Month viewer (Clean by app)

struct MonthRef: Equatable { let app: String, group: String, row: String }
/// One file inside a by-month row.
struct MonthItem: Identifiable {
    let url: URL; let size: Int64; let date: Date; let kind: FileKind
    /// Other copies of the same photo (Zalo keeps _t thumbnail, _n, _h and a .jxl of each); ticked and cleaned together.
    var variants: [URL] = []
    /// Telegram keeps animated stickers as gzip files named telegram-cloud-document-…, set once when the month opens.
    var tgSticker = false
    var id: String { url.path }
    var allPaths: [String] { [url.path] + variants.map(\.path) }
    var count: Int { 1 + variants.count }
    /// Zalo photo names: <13-digit time>_<id>_<g or not><id>_ then n, h, t, or a 32-hex hash with .jxl.
    /// Only this exact shape is grouped, so ordinary names like IMG_2024_01_05.jpg are never merged.
    static let zaloVariant = try! NSRegularExpression(pattern: "^(\\d{13}_\\d+_g?\\d+)_(n|h|t|[0-9a-f]{32}\\.jxl)$")
    /// Telegram: a file, its "_partial" twin while it downloads, and "_partial.meta" are one item.
    static let telegramVariant = try! NSRegularExpression(pattern: "^(telegram-.+?)(_partial(\\.meta)?)?$")
    static func isTelegramSticker(_ u: URL) -> Bool {
        guard u.lastPathComponent.hasPrefix("telegram-cloud-document"), FileKind.of(u) == .other,
              let h = try? FileHandle(forReadingFrom: u) else { return false }
        defer { try? h.close() }
        guard let d = try? h.read(upToCount: 2), d.count == 2 else { return false }
        return d[d.startIndex] == 0x1F && d[d.startIndex + 1] == 0x8B   // gzip = Lottie sticker (.tgs)
    }
    static func variantKey(_ u: URL) -> String? {
        let n = u.lastPathComponent
        if n.hasPrefix("telegram-"), let m = telegramVariant.firstMatch(in: n, range: NSRange(n.startIndex..., in: n)),
           let r = Range(m.range(at: 1), in: n) { return String(n[r]) }
        guard let m = zaloVariant.firstMatch(in: n, range: NSRange(n.startIndex..., in: n)), let r = Range(m.range(at: 1), in: n) else { return nil }
        return String(n[r])   // copies sit in different folders (Cache/ and picture/), the name alone is unique
    }
    /// Extensions that mark an app's own index files (Zalo's .rescache), never shown as photos.
    static let companionExt: Set<String> = ["rescache", "ds_store"]
    /// Zalo names them just ".rescache" (a hidden file with no extension), one per chat folder.
    static func isCompanion(_ u: URL) -> Bool {
        let n = u.lastPathComponent.lowercased()
        if n.hasPrefix("telegram-") && n.hasSuffix(".meta") { return true }   // Telegram's download bookkeeping
        return companionExt.contains { n == "." + $0 || n.hasSuffix("." + $0) }
    }
    var isVideo: Bool { kind == .video }
    var isMedia: Bool { kind != .other }
    var showsInGrid: Bool { isMedia || badge != nil }
    /// Files with no picture to show get a plain label instead of a blank page icon.
    var badge: (en: String, vi: String, icon: String)? {
        let n = url.lastPathComponent
        if tgSticker || n.contains("animated-sticker") || n.hasSuffix(".tgs") { return ("Animated sticker", "Sticker động", "face.smiling") }
        if !isMedia && n.contains(":sticker") { return ("Sticker", "Sticker", "face.smiling") }
        if !isMedia && n.hasSuffix("_partial") { return ("Partial download", "Tải dở", "arrow.down.circle") }
        return nil
    }
    /// Days 1-7 are week 0, 8-14 week 1, and so on (29-31 is week 4).
    var week: Int { (Calendar.current.component(.day, from: date) - 1) / 7 }
    /// Quick Look picks the viewer from the extension, so a photo or video saved without one is shown through a link that has one.
    var previewURL: URL { url.pathExtension.isEmpty && isMedia ? PreviewLinks.link(url, ext: kind == .video ? "mp4" : (kind == .pdf ? "pdf" : "jpg")) : url }
}

/// Drag-to-select in the month viewer: the box being drawn, whether it ticks or unticks, the ticks before it started,
/// and where each visible file sits (not published, it changes on every scroll).
final class SelectBox: ObservableObject {
    @Published var band: CGRect? = nil
    var on = true
    var base = Set<String>()
    var frames: [String: CGRect] = [:]
}

/// Frames of the month viewer's visible cells, for drag-to-select.
struct CellFrames: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) { value.merge(nextValue()) { $1 } }
}

/// Quick Look ignores symbolic links, so an extensionless photo is shown through a hard link with a proper extension,
/// in Tidymint's own temporary folder. A hard link is a second name for the same file: removing it never removes the photo,
/// and it takes no extra space. The links go when the month viewer closes (and at launch, in case the app quit early),
/// so a photo moved to the Trash afterwards really frees its space when the Trash is emptied.
enum PreviewLinks {
    static let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tidymint-preview", isDirectory: true)
    static var made: [String: URL] = [:]
    static var failed = Set<String>()   // not retried on every redraw
    static func link(_ u: URL, ext: String) -> URL {
        if let l = made[u.path] { return l }
        if failed.contains(u.path) { return u }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let l = dir.appendingPathComponent("\(made.count + 1)-\(u.lastPathComponent).\(ext)")
        guard (try? FileManager.default.linkItem(at: u, to: l)) != nil else { failed.insert(u.path); return u }
        made[u.path] = l; return l
    }
    /// Removes only names inside Tidymint's own preview folder.
    static func clear() {
        for l in made.values where l.deletingLastPathComponent().standardizedFileURL == dir.standardizedFileURL { try? FileManager.default.removeItem(at: l) }
        made = [:]; failed = []
        if let left = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for l in left { try? FileManager.default.removeItem(at: l) }
        }
    }
}

/// The grey line under a Clean by App row; mint when files were picked one by one in the month viewer.
struct RowSubLine: View {
    let row: AppRow
    var body: some View {
        let c: Color = row.checkState == 1 ? Theme.accentSolid : Theme.sub
        return Text(row.subLine).foregroundColor(c).font(.system(size: fs(11))).lineLimit(1).truncationMode(.middle)
    }
}

/// Key presses for one page (Space = Quick Look, Esc = back). Local monitor, removed when the page goes away.
final class KeyTap: ObservableObject {
    private var mon: Any?
    func start(_ handle: @escaping (NSEvent) -> Bool) {
        stop(); mon = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { handle($0) ? nil : $0 }
    }
    func stop() { if let m = mon { NSEvent.removeMonitor(m) }; mon = nil }
    deinit { stop() }
}

/// The files of one month, split by week, as a grid of thumbnails. Click ticks a file, a week header ticks the week;
/// double-click or Space shows the file large (Quick Look). Ticks go back to the month row in the list.
struct MonthViewer: View {
    @ObservedObject var vm: VM
    let report: AppReport
    let ref: MonthRef
    @StateObject private var keys = KeyTap()
    @StateObject private var box = SelectBox()
    var group: AppGroup? { report.groups.first { $0.id == ref.group } }
    var row: AppRow? { group?.rows.first { $0.id == ref.row } }
    /// Photos, videos and labelled items go in the week grid; files with nothing to show go in a separate list at the end.
    var weeks: [(Int, [MonthItem])] { Dictionary(grouping: vm.monthItems.filter(\.showsInGrid), by: \.week).sorted { $0.key > $1.key } }
    var others: [MonthItem] { vm.monthItems.filter { !$0.showsInGrid } }
    func weekLabel(_ w: Int) -> String {
        guard let m = row?.month else { return "" }
        let c = Calendar.current
        let last = c.range(of: .day, in: .month, for: m)?.count ?? 30
        let from = w * 7 + 1, to = min(w * 7 + 7, last), mo = c.component(.month, from: m)
        if appLang == "vi" { return "Tuần \(w + 1) · \(from)–\(to)/\(mo)" }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "MMM"
        return "Week \(w + 1) · \(f.string(from: m)) \(from)–\(to)"
    }
    func state(_ ids: [String]) -> Int {
        let n = ids.filter { vm.monthPick.contains($0) }.count
        return n == 0 ? 0 : (n == ids.count ? 2 : 1)
    }
    var pickSize: Int64 { vm.monthItems.filter { vm.monthPick.contains($0.id) }.reduce(0) { $0 + $1.size } }
    var body: some View {
        let all = vm.monthItems.map(\.id)
        VStack(spacing: 0) {
            HStack {
                Button { vm.closeMonth() } label: { Label(t("Back", "Quay lại"), systemImage: "chevron.left").padding(.horizontal, 6).padding(.vertical, 3).hoverTile() }.buttonStyle(.plain).foregroundColor(Theme.text)
                Spacer()
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        RuleIcon(name: report.rule.name, bundleIDs: report.rule.bundleIDs, side: 20)
                        Text("\(report.rule.name) · \(group?.section.title ?? "") · \(row?.title ?? "")").font(.system(size: fs(15), weight: .semibold)).foregroundColor(Theme.text).lineLimit(1)
                    }
                    Text(t("\(vm.monthItems.count) files · \(fmt(vm.monthItems.reduce(0) { $0 + $1.size }))", "\(vm.monthItems.count) file · \(fmt(vm.monthItems.reduce(0) { $0 + $1.size }))"))
                        .font(.system(size: fs(12)).monospacedDigit()).foregroundColor(Theme.sub)
                }
                Spacer()
                Button { vm.setMonthPick(all, on: state(all) != 2) } label: {
                    HStack(spacing: 6) { CheckBox(state: state(all)); Text(t("Select all", "Chọn tất cả")).foregroundColor(Theme.text).font(.system(size: fs(13))) }
                        .padding(.horizontal, 6).padding(.vertical, 3).hoverTile()
                }.buttonStyle(.plain).disabled(all.isEmpty)
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 6)
            Text(t("Click to tick, drag a box to tick many, Shift-click for a range. Double-click or Space to see a file large.", "Bấm để tick, kéo chuột quét vùng để tick nhiều, giữ Shift để chọn một dải. Bấm đúp hoặc phím cách để xem to."))
                .font(.system(size: fs(11))).foregroundColor(Theme.sub).padding(.bottom, 10)
            if vm.monthLoading {
                Scanning(text: t("Reading files...", "Đang đọc file...")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(weeks, id: \.0) { w, items in
                            let ids = items.map(\.id)
                            let folded = vm.monthCollapsed.contains(w)
                            HStack(spacing: 10) {
                                Button { vm.setMonthPick(ids, on: state(ids) != 2) } label: { CheckBox(state: state(ids)) }.buttonStyle(.plain)
                                Button {
                                    withAnimation(.easeOut(duration: 0.15)) { if folded { vm.monthCollapsed.remove(w) } else { vm.monthCollapsed.insert(w) } }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "chevron.down").rotationEffect(.degrees(folded ? -90 : 0)).foregroundColor(Theme.sub).font(.system(size: fs(11), weight: .semibold))
                                        Text(weekLabel(w)).font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain).tip(folded ? t("Show this week", "Mở tuần này") : t("Fold this week", "Thu gọn tuần này"))
                                Spacer()
                                Text(t("\(items.count) files · \(fmt(items.reduce(0) { $0 + $1.size }))", "\(items.count) file · \(fmt(items.reduce(0) { $0 + $1.size }))"))
                                    .font(.system(size: fs(12)).monospacedDigit()).foregroundColor(Theme.sub)
                            }.padding(.top, 4)
                            if !folded {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120 * max(uiScale, 1), maximum: 170 * max(uiScale, 1)), spacing: 10)], spacing: 12) {
                                ForEach(items) { it in
                                    MonthCell(item: it, focused: vm.monthFocus == it.id, picked: vm.monthPick.contains(it.id))
                                        .background(GeometryReader { g in Color.clear.preference(key: CellFrames.self, value: [it.id: g.frame(in: .named("monthgrid"))]) })
                                        .onTapGesture(count: 2) { vm.previewMonth(it.id) }
                                        .onTapGesture { vm.clickMonth(it.id, shift: NSEvent.modifierFlags.contains(.shift)) }
                                        .contextMenu {
                                            Button(t("Show large", "Xem to")) { vm.previewMonth(it.id) }
                                            FileMenu(url: it.url, vm: vm, quickLook: false)
                                        }
                                }
                            }
                            }
                        }
                        if !others.isEmpty {
                            let ids = others.map(\.id)
                            let open = vm.monthCollapsed.contains(99)   // folded until asked: these have no picture to judge by
                            HStack(spacing: 10) {
                                Button { vm.setMonthPick(ids, on: state(ids) != 2) } label: { CheckBox(state: state(ids)) }.buttonStyle(.plain)
                                Button {
                                    withAnimation(.easeOut(duration: 0.15)) { if open { vm.monthCollapsed.remove(99) } else { vm.monthCollapsed.insert(99) } }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "chevron.down").rotationEffect(.degrees(open ? 0 : -90)).foregroundColor(Theme.sub).font(.system(size: fs(11), weight: .semibold))
                                        Text(t("Other files, no preview", "File khác, không xem trước được")).font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                Spacer()
                                Text(t("\(others.count) files · \(fmt(others.reduce(0) { $0 + $1.size }))", "\(others.count) file · \(fmt(others.reduce(0) { $0 + $1.size }))"))
                                    .font(.system(size: fs(12)).monospacedDigit()).foregroundColor(Theme.sub)
                            }.padding(.top, 8)
                            if open {
                                ForEach(others) { it in
                                    HStack(spacing: 10) {
                                        CheckBox(state: vm.monthPick.contains(it.id) ? 2 : 0)
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: it.url.path)).resizable().frame(width: 20, height: 20)
                                        Text(it.url.lastPathComponent).font(.system(size: fs(12))).foregroundColor(Theme.text).lineLimit(1).truncationMode(.middle)
                                        Spacer()
                                        Text("\(MonthCell.df.string(from: it.date)) · \(fmt(it.size))").font(.system(size: fs(11)).monospacedDigit()).foregroundColor(Theme.sub)
                                    }
                                    .padding(.vertical, 4).padding(.horizontal, 8).hoverBG(6, Theme.ink.opacity(0.06)).contentShape(Rectangle())
                                    .onTapGesture { vm.clickMonth(it.id, shift: NSEvent.modifierFlags.contains(.shift)) }
                                    .contextMenu {
                                        Button(t("Show large", "Xem to")) { vm.previewMonth(it.id) }
                                        FileMenu(url: it.url, vm: vm, quickLook: false)
                                    }
                                }
                            }
                        }
                        if !vm.monthExtras.isEmpty {
                            Text(t("Also in this month: \(vm.monthExtras.count) index files of \(report.rule.name) (\(fmt(vm.monthExtrasSize))), not photos or videos. They go only when the whole month is ticked.",
                                   "Trong tháng còn \(vm.monthExtras.count) tệp chỉ mục của \(report.rule.name) (\(fmt(vm.monthExtrasSize))), không phải ảnh hay video. Chỉ dọn khi tick cả tháng."))
                                .font(.system(size: fs(11))).foregroundColor(Theme.sub).padding(.top, 6)
                        }
                    }.padding(.horizontal, 24).padding(.bottom, 16)
                    .coordinateSpace(name: "monthgrid")
                    .onPreferenceChange(CellFrames.self) { box.frames = $0 }
                    .overlay(alignment: .topLeading) {
                        if let r = box.band {
                            Rectangle().fill(Theme.accentSolid.opacity(0.12))
                                .overlay(Rectangle().stroke(Theme.accentSolid.opacity(0.8), lineWidth: 1))
                                .frame(width: r.width, height: r.height).offset(x: r.minX, y: r.minY).allowsHitTesting(false)
                        }
                    }
                    .gesture(DragGesture(minimumDistance: 8, coordinateSpace: .named("monthgrid"))
                        .onChanged { d in
                            if box.band == nil {
                                // Starting on a ticked file unticks what the box covers; anywhere else ticks it.
                                let start = box.frames.first { $0.value.contains(d.startLocation) }?.key
                                box.on = !(start.map { vm.monthPick.contains($0) } ?? false)
                                box.base = vm.monthPick
                            }
                            let r = CGRect(x: min(d.startLocation.x, d.location.x), y: min(d.startLocation.y, d.location.y),
                                           width: abs(d.location.x - d.startLocation.x), height: abs(d.location.y - d.startLocation.y))
                            box.band = r
                            let hit = Set(box.frames.filter { $0.value.intersects(r) }.map(\.key))
                            let target = box.on ? box.base.union(hit) : box.base.subtracting(hit)
                            let add = target.subtracting(vm.monthPick), drop = vm.monthPick.subtracting(target)
                            if !add.isEmpty { vm.setMonthPick(Array(add), on: true) }
                            if !drop.isEmpty { vm.setMonthPick(Array(drop), on: false) }
                        }
                        .onEnded { _ in box.band = nil })
                }
            }
            HStack {
                Text(vm.monthPick.isEmpty ? t("Nothing ticked", "Chưa tick gì")
                     : t("\(vm.monthPick.count) ticked · \(fmt(pickSize))", "Đã tick \(vm.monthPick.count) · \(fmt(pickSize))"))
                    .foregroundColor(Theme.text).font(.system(size: fs(13), weight: .medium).monospacedDigit())
                Spacer()
                Text(t("Ticked files are cleaned with the rest when you press Move to Trash.", "File đã tick được dọn cùng khi bấm Chuyển vào Thùng rác."))
                    .foregroundColor(Theme.sub).font(.system(size: fs(11)))
                GhostButton(title: t("Done", "Xong"), action: { vm.closeMonth() })
            }.padding(.horizontal, 24).padding(.vertical, 14).background(Theme.ink.opacity(0.03))
        }
        .quickLookPreview(Binding(get: { vm.qlURL }, set: { vm.qlURL = $0 }), in: vm.qlURL == nil ? [] : vm.monthItems.map(\.previewURL))
        .onAppear {
            keys.start { e in
                MainActor.assumeIsolated {
                    guard vm.monthRef != nil, vm.qlURL == nil else { return false }
                    switch e.keyCode {
                    case 49: vm.previewMonth(); return true      // Space
                    case 53: vm.closeMonth(); return true        // Esc
                    default: return false
                    }
                }
            }
        }
        .onDisappear {
            keys.stop()
            // Window closed or page left with a month open: drop the preview links, or they keep the space of
            // trashed photos allocated until the next launch.
            if vm.monthRef != nil { vm.closeMonth() }
        }
    }
}

struct MonthCell: View {
    let item: MonthItem; let focused: Bool; let picked: Bool
    static let df: DateFormatter = { let f = DateFormatter(); f.dateFormat = "dd/MM HH:mm"; return f }()
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8).fill(Theme.ink.opacity(0.06))
                if let b = item.badge {
                    VStack(spacing: 6) {
                        Image(systemName: b.icon).font(.system(size: 30)).foregroundColor(Theme.sub)
                        Text(t(b.en, b.vi)).font(.system(size: fs(12), weight: .medium)).foregroundColor(Theme.sub)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    GridThumb(url: item.url, side: 170)
                }
                if item.isVideo {
                    Image(systemName: "play.circle.fill").font(.system(size: 28)).foregroundStyle(.white, .black.opacity(0.45))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Image(systemName: picked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(picked ? AnyShapeStyle(Theme.accentSolid) : AnyShapeStyle(Color.white.opacity(0.9)))
                    .background(Circle().fill(Color.black.opacity(picked ? 0 : 0.35)).padding(2))
                    .padding(6)
            }
            .frame(height: 120 * max(uiScale, 1)).clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(picked ? Theme.accentSolid : Theme.sub.opacity(0.6), lineWidth: picked ? 2.5 : (focused ? 1.5 : 0)))
            Text(item.isMedia || item.badge != nil ? "\(MonthCell.df.string(from: item.date)) · \(fmt(item.size))" : item.url.lastPathComponent)
                .font(.system(size: fs(11)).monospacedDigit())
                .foregroundColor(Theme.sub).lineLimit(1).truncationMode(.middle)
        }.contentShape(Rectangle())
    }
}

/// A thumbnail that fills its cell; falls back to the centred Finder icon until (or unless) Quick Look has one.
struct GridThumb: View {
    let url: URL; let side: CGFloat
    @StateObject private var store = ThumbStore()
    var body: some View {
        GeometryReader { g in
            if let img = store.image {
                if store.real {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill).frame(width: g.size.width, height: g.size.height).clipped()
                } else {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fit).frame(width: 56, height: 56).position(x: g.size.width / 2, y: g.size.height / 2)
                }
            }
        }
        .onAppear { store.load(url, side: side) }
    }
}
