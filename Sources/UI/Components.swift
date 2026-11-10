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

// MARK: - Components

struct SafetyBadge: View {
    let level: Safety; var why = ""
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: level.icon).font(.system(size: fs(9), weight: .bold))
            Text(level.label).font(.system(size: fs(10), weight: .semibold))
        }
        .foregroundColor(level.color).padding(.horizontal, 7).padding(.vertical, 2)
        .background(Capsule().fill(level.color.opacity(0.15)))
        .tip(why)
    }
}

struct CheckBox: View {
    let state: Int
    var body: some View {
        Image(systemName: state == 2 ? "checkmark.square.fill" : (state == 1 ? "minus.square.fill" : "square"))
            .font(.system(size: fs(15), weight: .medium))
            .foregroundStyle(state == 0 ? AnyShapeStyle(Theme.ink.opacity(0.5)) : AnyShapeStyle(Theme.accent))
            // The whole square takes the click, not only the outline; hand cursor, no hover colour (lists stay calm).
            .contentShape(Rectangle())
            .onHover { ($0 ? NSCursor.pointingHand : NSCursor.arrow).set() }
    }
}

// Pill buttons share one size (14 pt text, 22/10 padding) so primary and ghost line up side by side.
// `width` fixes the pill width for places where several buttons sit in a column (Settings rows).
enum Pill { static var font: Font { Font.system(size: fs(14), weight: .semibold) }; static let padH: CGFloat = 22; static let padV: CGFloat = 10; static var rowWidth: CGFloat { 150 * max(uiScale, 1) + (uiScale > 1 ? 12 : 0) } }   // never narrower than at default size, so labels fit at Small

struct PrimaryButton: View {
    let title: String; let action: () -> Void
    var disabled = false
    var width: CGFloat? = nil
    /// Small macOS-size button for list rows (Settings): 12 pt text, tight padding, width from the label.
    var compact = false
    var body: some View {
        Button(action: action) {
            Text(title).font(compact ? .system(size: fs(13), weight: .medium) : Pill.font).foregroundColor(.white).lineLimit(1)
                .frame(width: compact ? nil : width.map { $0 - 2 * Pill.padH })
                .padding(.horizontal, compact ? 11 : Pill.padH).padding(.vertical, compact ? 4 : Pill.padV)
                .background(compact ? AnyView(RoundedRectangle(cornerRadius: 6).fill(Theme.accentSolid)) : AnyView(Capsule().fill(Theme.accent))).opacity(disabled ? 0.4 : 1)
                .shadow(color: Theme.accentSolid.opacity(compact ? 0 : 0.4), radius: 12, y: 4)
        }.buttonStyle(.plain).disabled(disabled).hoverLift()
    }
}

struct GhostButton: View {
    let title: String; let action: () -> Void
    var width: CGFloat? = nil
    /// Small macOS-size button for list rows (Settings): 12 pt text, tight padding, width from the label.
    var compact = false
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: fs(13 + (compact ? 0 : 1)), weight: compact ? .regular : .medium)).foregroundColor(Theme.text).lineLimit(1)
                .frame(width: compact ? nil : width.map { $0 - 2 * Pill.padH })
                .padding(.horizontal, compact ? 11 : Pill.padH).padding(.vertical, compact ? 4 : Pill.padV)
                .background(compact ? AnyView(RoundedRectangle(cornerRadius: 6).fill(Theme.ink.opacity(0.13))) : AnyView(Capsule().stroke(Theme.ink.opacity(0.35), lineWidth: 1)))
                .hoverBG(compact ? 6 : 20, Theme.ink.opacity(0.1))
        }.buttonStyle(.plain).hoverLift()
    }
}

/// The mint leaf from the brand kit (assets/brand/src/leaf-path.txt), as a polygon in a 0...1000 box, width:height = 845:1311.
struct LeafShape: Shape {
    static let pts: [CGFloat] = [717,0,704,2,685,5,658,13,633,23,607,37,583,53,562,71,543,91,527,111,525,111,522,110,516,106,512,102,505,92,499,79,480,85,455,97,443,104,428,114,414,126,402,138,382,164,373,177,367,192,366,191,341,154,309,171,286,186,267,200,241,224,227,240,214,257,203,276,196,293,192,305,191,314,189,314,161,270,159,271,151,279,139,292,128,306,115,326,106,346,99,365,93,388,89,416,89,438,90,444,88,444,26,416,25,417,24,462,24,477,28,507,31,527,40,560,49,589,55,603,44,603,31,602,19,600,1,594,0,595,9,623,21,651,29,667,42,688,57,709,83,739,112,765,141,788,176,810,211,830,254,849,256,870,260,892,261,894,264,912,272,934,287,968,295,982,307,1000,308,999,306,997,303,979,301,956,301,936,303,910,311,872,318,850,330,821,343,795,356,772,373,746,398,711,439,659,512,575,553,526,589,478,617,435,628,413,643,382,651,360,658,334,663,309,664,284,664,258,662,241,660,239,661,235,662,236,667,255,670,282,670,315,669,320,669,328,666,350,657,382,650,403,637,434,615,477,585,524,552,571,496,644,463,689,442,720,421,755,404,786,391,814,378,851,371,882,396,887,431,890,488,890,511,888,540,885,568,881,597,876,625,870,653,863,705,847,705,846,699,845,683,839,669,831,670,830,685,830,707,827,740,821,760,816,781,809,818,794,852,776,873,763,878,759,868,763,855,766,841,767,827,767,804,764,788,760,785,759,816,749,843,736,873,718,897,698,918,677,942,649,960,622,974,594,973,594,964,598,948,603,937,604,931,604,922,602,917,599,914,594,928,585,942,572,952,561,963,543,975,520,987,491,999,449,999,448,994,451,985,452,962,452,932,449,930,448,941,439,953,424,962,404,968,381,970,365,971,328,969,302,964,274,954,281,941,286,924,289,915,290,914,289,915,277,915,259,909,227,895,181,875,132,873,132,861,142,844,153,831,159,828,159,828,154,826,144,820,130,810,111,798,93,763,50,736,20]
    func path(in r: CGRect) -> Path {
        var p = Path()
        let aspect: CGFloat = 845.0 / 1311.0
        var w = r.width, h = r.height
        if w / h > aspect { w = h * aspect } else { h = w / aspect }
        let ox = r.midX - w / 2, oy = r.midY - h / 2
        let xs = stride(from: 0, to: Self.pts.count, by: 2).map { CGPoint(x: ox + Self.pts[$0] / 1000 * w, y: oy + Self.pts[$0 + 1] / 1000 * h) }
        guard let f = xs.first else { return p }
        p.move(to: f); for q in xs.dropFirst() { p.addLine(to: q) }; p.closeSubpath()
        return p
    }
}

/// The big Scan button: a dark core with the mint leaf inside a thin ring. Hover fades the leaf and shows the word.
struct BigScanButton: View {
    let label: String; let action: () -> Void
    @StateObject private var pulse = Flag()   // hover
    @StateObject private var breath = Flag()  // slow idle breathing, off when Reduce Motion is on
    var body: some View {
        let still = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let hot = pulse.v
        Button(action: action) {
            ZStack {
                Circle().fill(Theme.accentSolid.opacity(breath.v || hot ? 0.20 : 0.12)).frame(width: 190, height: 190)
                    .scaleEffect(still ? 1 : (hot ? 1.08 : (breath.v ? 1.05 : 0.97)))
                Circle().fill(Theme.tile).frame(width: 150, height: 150)
                    .overlay(Circle().stroke(Theme.accentSolid.opacity(hot ? 1 : 0.6), lineWidth: 2))
                    .shadow(color: Theme.accentSolid.opacity(breath.v || hot ? 0.6 : 0.35), radius: breath.v || hot ? 30 : 20)
                LeafShape().fill(Theme.accent).frame(width: 88, height: 88)
                    .opacity(hot ? 0.18 : 1).scaleEffect(hot && !still ? 1.06 : 1)
                Text(label).font(.system(size: fs(24), weight: .bold)).foregroundColor(Theme.text)
                    .opacity(hot ? 1 : 0)
            }
        }.buttonStyle(.plain)
        .accessibilityLabel(label)
        .onHover { h in withAnimation(.easeOut(duration: 0.25)) { pulse.v = h } }
        // Breathe three times after the page appears, then rest. A forever animation kept the CPU at ~10% even with the
        // window closed, so the cue is finite: finished animations cost nothing.
        .task {
            guard !still else { return }
            for _ in 0..<3 {
                withAnimation(.easeInOut(duration: 2.4)) { breath.v = true }
                try? await Task.sleep(nanoseconds: 2_400_000_000)
                withAnimation(.easeInOut(duration: 2.4)) { breath.v = false }
                try? await Task.sleep(nanoseconds: 2_400_000_000)
            }
        }
    }
}

struct Header: View {
    let title: String; let sub: String
    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: fs(28), weight: .bold)).foregroundColor(Theme.text)
            // Narrow column so lines break evenly instead of running edge to edge with one orphan word.
            Text(sub).font(.system(size: fs(14))).foregroundColor(Theme.sub).multilineTextAlignment(.center)
                .frame(maxWidth: 560 * uiScale).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct Scanning: View {
    let text: String
    var body: some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large).tint(Theme.text)
            Text(text).foregroundColor(Theme.sub)
        }
    }
}

/// What a file really is, read from its first bytes when the name has no useful extension
/// (Zalo, Messenger and others save photos and videos without one).
enum FileKind {
    case image, video, pdf, other
    static let imageExt: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "tif", "bmp", "raw", "dng", "cr2", "nef", "arw", "psd", "jxl", "avif"]
    static let videoExt: Set<String> = ["mov", "mp4", "m4v", "avi", "mkv", "webm", "3gp"]
    private static var memo: [String: FileKind] = [:]
    private static let lock = NSLock()
    static func clearMemo() { lock.lock(); memo = [:]; lock.unlock() }
    static func of(_ url: URL) -> FileKind {
        let e = url.pathExtension.lowercased()
        if imageExt.contains(e) { return .image }
        if videoExt.contains(e) { return .video }
        if e == "pdf" { return .pdf }
        if ["txt", "json", "plist", "db", "sqlite", "log", "ttf", "otf", "zip", "dmg", "pkg", "app", "html", "js", "css", "meta", "rescache"].contains(e) { return .other }
        // Anything else (no extension, or WhatsApp's .thumb / .mmsthumb / .videothumb) is read to see what it really is.
        lock.lock(); if let k = memo[url.path] { lock.unlock(); return k }; lock.unlock()
        let k = sniff(url)
        lock.lock(); memo[url.path] = k; lock.unlock()
        return k
    }
    static func sniff(_ url: URL) -> FileKind {
        guard let h = try? FileHandle(forReadingFrom: url) else { return .other }
        defer { try? h.close() }
        guard let d = try? h.read(upToCount: 16), d.count >= 4 else { return .other }
        let b = [UInt8](d)
        func ascii(_ r: Range<Int>) -> String { r.upperBound <= b.count ? String(bytes: b[r], encoding: .ascii) ?? "" : "" }
        if b[0] == 0xFF && b[1] == 0xD8 { return .image }                                   // JPEG
        if b[0] == 0x89 && ascii(1..<4) == "PNG" { return .image }
        if ascii(0..<4) == "GIF8" || ascii(0..<4) == "8BPS" { return .image }               // GIF, PSD
        if ascii(0..<4) == "RIFF" && ascii(8..<12) == "WEBP" { return .image }
        if ascii(0..<4) == "RIFF" && ascii(8..<12) == "AVI " { return .video }
        if (b[0] == 0x49 && b[1] == 0x49) || (b[0] == 0x4D && b[1] == 0x4D) { return .image }  // TIFF
        if b[0] == 0xFF && b[1] == 0x0A { return .image }                                   // JPEG XL codestream
        if ascii(4..<8) == "JXL " { return .image }                                         // JPEG XL container
        if ascii(0..<4) == "%PDF" { return .pdf }
        if b[0] == 0x1A && b[1] == 0x45 && b[2] == 0xDF && b[3] == 0xA3 { return .video }   // Matroska / WebM
        if ascii(4..<8) == "ftyp" {
            let brand = ascii(8..<12)
            if ["heic", "heix", "heim", "heis", "mif1", "msf1", "avif", "avis"].contains(brand) { return .image }
            return .video                                                                   // mp4, m4v, mov (qt), 3gp
        }
        return .other
    }
}

/// Real thumbnail for photos and videos, the Finder icon for everything else. Cached per path and size.
/// Photos go through ImageIO, which reads the content, so files without an extension still get a picture.
final class ThumbStore: ObservableObject {
    @Published var image: NSImage?
    @Published var real = false   // true once a real thumbnail replaced the Finder icon
    // Bounded so a long scroll through thousands of photos cannot pile up decoded thumbnails.
    static let cache: NSCache<NSString, NSImage> = { let c = NSCache<NSString, NSImage>(); c.countLimit = 300; c.totalCostLimit = 24 << 20; return c }()
    static func cost(_ img: NSImage) -> Int {
        let px = img.representations.map { $0.pixelsWide * $0.pixelsHigh }.max() ?? 0
        return max(1, px) * 4
    }
    static let work: OperationQueue = { let q = OperationQueue(); q.maxConcurrentOperationCount = 4; q.qualityOfService = .userInitiated; return q }()
    static var media: Set<String> { FileKind.imageExt.union(FileKind.videoExt).union(["pdf"]) }
    func load(_ url: URL, side: CGFloat) {
        let key = "\(url.path)|\(Int(side))" as NSString
        if let c = ThumbStore.cache.object(forKey: key) { image = c; real = true; return }
        image = NSWorkspace.shared.icon(forFile: url.path)
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        ThumbStore.work.addOperation { [weak self] in
            let kind = FileKind.of(url)
            guard kind != .other, FileManager.default.fileExists(atPath: url.path) else { return }
            if kind == .image, let img = ThumbStore.imageThumb(url, px: side * scale) {
                ThumbStore.cache.setObject(img, forKey: key, cost: ThumbStore.cost(img))
                DispatchQueue.main.async { self?.image = img; self?.real = true }
                return
            }
            if kind == .video && url.pathExtension.isEmpty, let img = ThumbStore.videoThumb(url, px: side * scale) {
                ThumbStore.cache.setObject(img, forKey: key, cost: ThumbStore.cost(img))
                DispatchQueue.main.async { self?.image = img; self?.real = true }
                return
            }
            let req = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: side, height: side), scale: scale, representationTypes: .thumbnail)
            QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { rep, _ in
                guard let img = rep?.nsImage else { return }
                ThumbStore.cache.setObject(img, forKey: key, cost: ThumbStore.cost(img))
                DispatchQueue.main.async { self?.image = img; self?.real = true }
            }
        }
    }
    static func imageThumb(_ url: URL, px: CGFloat) -> NSImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                                     kCGImageSourceThumbnailMaxPixelSize: Int(px), kCGImageSourceShouldCacheImmediately: true]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width) / 2, height: CGFloat(cg.height) / 2))
    }
    /// A video saved without an extension: AVFoundation goes by the extension, so read it through a short-lived hard link
    /// named .mp4 in Tidymint's temporary folder (a second name for the same file, removed right after; the video is untouched).
    static func videoThumb(_ url: URL, px: CGFloat) -> NSImage? {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tidymint-thumb", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let link = dir.appendingPathComponent(UUID().uuidString + ".mp4")
        guard (try? FileManager.default.linkItem(at: url, to: link)) != nil else { return nil }
        defer { try? FileManager.default.removeItem(at: link) }
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: link))
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: px, height: px)
        guard let cg = try? gen.copyCGImage(at: CMTime(seconds: 0.5, preferredTimescale: 600), actualTime: nil) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width) / 2, height: CGFloat(cg.height) / 2))
    }
}

struct FileThumb: View {
    let url: URL; var side: CGFloat = 22
    @StateObject private var store = ThumbStore()
    var body: some View {
        Group {
            if let img = store.image {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
            } else { Color.clear }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .onAppear { store.load(url, side: side) }
    }
}

/// "38 small items under 512 KB · 4 MB": one row with its own checkbox; click to list them.
struct SmallItemsRow: View {
    @Binding var cat: Category
    let vm: VM
    var body: some View {
        let small = cat.items.filter { $0.size < Category.smallLimit }
        if !small.isEmpty {
            let on = small.filter(\.selected).count
            let state = on == 0 ? 0 : (on == small.count ? 2 : 1)
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button {
                        let v = small.contains { !$0.selected && !$0.running }
                        for i in cat.items.indices where cat.items[i].size < Category.smallLimit && !(v && cat.items[i].running) { cat.items[i].selected = v }
                    } label: { CheckBox(state: state) }.buttonStyle(.plain)
                    Image(systemName: "square.stack.3d.down.right").font(.system(size: fs(14))).foregroundColor(Theme.sub).frame(width: 26 * uiScale)
                    Text(t("\(small.count) small items (under 500 KB)", "\(small.count) mục nhỏ (dưới 500 KB)")).foregroundColor(Theme.text).font(.system(size: fs(13)))
                    Spacer(minLength: 12)
                    Image(systemName: "chevron.down").rotationEffect(.degrees(cat.smallExpanded ? 0 : -90)).foregroundColor(Theme.sub)
                    Text(fmt(small.reduce(0) { $0 + $1.size })).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .medium).monospacedDigit()).frame(width: 80 * uiScale, alignment: .trailing)
                }
                .padding(.vertical, 9).padding(.horizontal, 12)
                .hoverBG(8, Theme.ink.opacity(0.07))
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { cat.smallExpanded.toggle() } }
                if cat.smallExpanded {
                    ForEach($cat.items) { $it in if it.size < Category.smallLimit { ItemRow(item: $it, vm: vm) } }.padding(.leading, 26)
                }
            }
        }
    }
}

struct ItemRow: View {
    @Binding var item: CleanItem
    let vm: VM
    var showDate = false
    /// Duplicates: the copy suggested to keep shows a "Keep" tag. `keepColumn` reserves that column on every row of the
    /// group, so the date and size columns stay in line whether or not a row has the tag.
    var keep = false
    var keepColumn = false
    var body: some View {
        // Closures below (hover, taps, menu) can run after the row's item was removed from its list (it was just
        // cleaned): they must use this copy, not the binding, or reading the binding crashes (index out of range).
        let url = item.url
        return HStack(spacing: 12) {
            Button { item.selected.toggle() } label: { CheckBox(state: item.selected ? 2 : 0) }.buttonStyle(.plain)
            FileThumb(url: item.url, side: 26 * uiScale)
            // Name, path, and (when there is one) the warning on its own line: all start at the same left edge,
            // so nothing pokes out between rows and the name never gets squeezed (style guide 1f).
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).foregroundColor(Theme.text).font(.system(size: fs(13))).lineLimit(1)
                Text(item.shortPath).foregroundColor(Theme.sub).font(.system(size: fs(11))).lineLimit(1).truncationMode(.middle)
                if !item.rowNote.isEmpty {
                    Label(item.rowNote, systemImage: "exclamationmark.triangle.fill").font(.system(size: fs(11), weight: .medium))
                        .foregroundColor(item.noteColor).lineLimit(1).tip(item.refHelp)
                }
            }
            Spacer(minLength: 12)
            if keepColumn {
                Group { if keep { StatusTag(t("Keep", "Giữ"), Theme.green) } }.frame(width: 50 * uiScale, alignment: .center)
            }
            if showDate {
                Text(item.date.map(openedLabel) ?? "")
                    .foregroundColor(Theme.sub).font(.system(size: fs(11)).monospacedDigit())
                    .lineLimit(1).frame(width: 165 * uiScale, alignment: .trailing)
            }
            Text(fmt(item.size)).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .medium).monospacedDigit()).frame(width: 80 * uiScale, alignment: .trailing)
        }
        .padding(.vertical, 9).padding(.horizontal, 12)
        .hoverBG(8, Theme.ink.opacity(0.07))
        .contentShape(Rectangle())
        // Like Finder: double-click opens in the default app, click shows a preview, Space over the row too.
        .onTapGesture(count: 2) { vm.fileQL = nil; vm.openFile(url) }
        .onTapGesture { vm.fileQL = url }
        .onHover { inside in
            if inside { vm.hoverFile = url } else if vm.hoverFile == url { vm.hoverFile = nil }
        }
        .contextMenu { FileMenu(url: url, vm: vm)
            Button(item.selected ? t("Deselect", "Bỏ chọn") : t("Select", "Chọn")) { item.selected.toggle() }
            Divider()
            Button(t("Ignore (don't show again)", "Bỏ qua (không hiện lại)")) { DispatchQueue.main.async { vm.ignore(url) } }
        }
    }
}

/// Right-click items for a file, Finder style: Open, Open With, Quick Look, Show in Finder, Copy Path.
/// Nothing here deletes; cleaning stays with the tick boxes and Move to Trash.
struct FileMenu: View {
    let url: URL
    let vm: VM
    var openWith = true
    var quickLook = true
    var body: some View {
        Button(t("Open", "Mở")) { vm.openFile(url) }
        if openWith { Menu(t("Open With", "Mở bằng")) {
            let def = NSWorkspace.shared.urlForApplication(toOpen: url)
            let apps = NSWorkspace.shared.urlsForApplications(toOpen: url)
            if let d = def {
                Button(FileManager.default.displayName(atPath: d.path) + t(" (default)", " (mặc định)")) { vm.openFile(url, with: d) }
                if apps.count > 1 { Divider() }
            }
            ForEach(apps.filter { $0 != def }.prefix(20), id: \.self) { a in
                Button(FileManager.default.displayName(atPath: a.path)) { vm.openFile(url, with: a) }
            }
            if def == nil && apps.isEmpty { Text(t("No app can open this file", "Chưa có app mở được file này")) }
        } }
        if quickLook { Button(t("Quick Look", "Xem nhanh")) { vm.fileQL = url } }
        Divider()
        Button(t("Show in Finder", "Hiện trong Finder")) { vm.reveal(url) }
        Button(t("Copy Path", "Chép đường dẫn")) {
            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(url.path, forType: .string)
        }
        Divider()
    }
}

/// Shown at the top of a list page right after a clean: how much got tidier, Undo, and the way to the Trash.
struct DoneBanner: View {
    @ObservedObject var vm: VM
    let page: Page
    var body: some View {
        if vm.doneInfo?.page != page, let n = vm.undoNote, n.page == page {
            UndoNote(vm: vm, text: n.text)
        } else if let d = vm.doneInfo, d.page == page {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: fs(22))).foregroundColor(Theme.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text(d.size > 0 ? t("\(fmt(d.size)) tidier", "Gọn thêm \(fmt(d.size))") : t("Done", "Xong"))
                        .font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                    Text(t("\(d.count) items moved to the Trash. Empty the Trash to free the space for real.",
                           "\(d.count) mục đã vào Thùng rác. Đổ Thùng rác thì ổ mới trống thật.") + (d.fail > 0 ? t(" \(d.fail) skipped.", " Bỏ qua \(d.fail) mục.") : ""))
                        .font(.system(size: fs(12))).foregroundColor(Theme.sub).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if vm.bannerCanUndo { GhostButton(title: t("Undo", "Hoàn tác"), action: { vm.undoFromBanner() }, compact: true) }
                GhostButton(title: t("Open Trash", "Xem Thùng rác"), action: { vm.page = .trash }, compact: true)
                Button { vm.doneInfo = nil } label: { Image(systemName: "xmark").font(.system(size: fs(12), weight: .semibold)) }
                    .buttonStyle(.icon).foregroundColor(Theme.sub).tip(t("Close", "Đóng"), trailing: true)
            }
            .padding(14).background(RoundedRectangle(cornerRadius: 10).fill(Theme.green.opacity(0.12)))
            .padding(.horizontal, 24).padding(.bottom, 10)
        }
    }
}

/// One line after an Undo: what came back. Closed by hand or by the next clean.
struct UndoNote: View {
    @ObservedObject var vm: VM
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.uturn.backward.circle.fill").foregroundColor(Theme.green)
            Text(text).font(.system(size: fs(12))).foregroundColor(Theme.text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button { vm.undoNote = nil } label: { Image(systemName: "xmark").font(.system(size: fs(12), weight: .semibold)) }
                .buttonStyle(.icon).foregroundColor(Theme.sub).tip(t("Close", "Đóng"), trailing: true)
        }
        .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Theme.green.opacity(0.10)))
        .padding(.horizontal, 24).padding(.bottom, 10)
    }
}

/// Scan progress: the steps of the scan, ticked one by one, plus what is being read right now.
struct ScanSteps: View {
    let title: String, steps: [String], current: Int
    var detail = ""
    var body: some View {
        VStack(spacing: 18) {
            Text(title).font(.system(size: fs(24), weight: .bold)).foregroundColor(Theme.text)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                    HStack(spacing: 10) {
                        Group {
                            if i < current { Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.green) }
                            else if i == current { ProgressView().controlSize(.small).tint(Theme.text) }
                            else { Image(systemName: "circle").foregroundColor(Theme.sub.opacity(0.6)) }
                        }.frame(width: 18)
                        Text(s).font(.system(size: fs(14), weight: i == current ? .semibold : .regular))
                            .foregroundColor(i <= current ? Theme.text : Theme.sub)
                    }
                }
            }.padding(20).frame(width: 340 * uiScale, alignment: .leading).background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
            Text(detail).font(.system(size: fs(11))).foregroundColor(Theme.sub).lineLimit(1).truncationMode(.middle).frame(maxWidth: 420)
        }
    }
}

/// One group of the Clean Now result: big size, what it is, who decides. Tapping opens the full list at that group.
struct JunkCard: View {
    let cat: Category; let action: () -> Void
    @StateObject private var hover = Flag()
    var body: some View {
        let picked = cat.selectedSize > 0
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: cat.icon).font(.system(size: fs(17))).foregroundStyle(Theme.accent)
                        .frame(width: 34, height: 34).background(Circle().fill(Theme.accent.opacity(0.14)))
                    Spacer()
                    SafetyBadge(level: cat.safety, why: cat.why)
                }
                Text(fmt(picked ? cat.selectedSize : cat.total)).font(.system(size: fs(24), weight: .bold).monospacedDigit()).foregroundColor(Theme.text)
                Text(cat.title).font(.system(size: fs(13))).foregroundColor(Theme.text).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text(cat.desc).font(.system(size: fs(12))).foregroundColor(Theme.sub).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text(picked ? t("Selected · Review", "Đã chọn · Xem") : t("Not selected · Review", "Chưa chọn · Xem"))
                    .font(.system(size: fs(12), weight: .semibold)).foregroundColor(picked ? Theme.text : Theme.sub)
            }
            .padding(16).frame(maxWidth: .infinity, minHeight: 168 * uiScale, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 16).fill(hover.v ? Theme.cardHi : Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.accentSolid.opacity(picked ? 0.35 : 0), lineWidth: 1))
        }.buttonStyle(.plain).onHover { hover.v = $0 }
    }
}
