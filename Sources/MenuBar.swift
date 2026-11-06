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

// MARK: - Menu bar

/// Capacity bar like macOS Storage (used for disk and RAM): used part in neutral grey on the left,
/// free part highlighted in the theme colour on the right (red when nearly full).
struct DiskBar: View {
    let free: Double, total: Double, low: Bool
    var usedColor: Color = Color.primary.opacity(0.28)
    var body: some View {
        GeometryReader { g in
            let f = total > 0 ? max(0.02, min(1, free / total)) : 0
            let fw = g.size.width * CGFloat(f)
            HStack(spacing: 2) {
                Capsule().fill(usedColor)
                Capsule().fill(low ? AnyShapeStyle(Color.red) : AnyShapeStyle(Theme.accent)).frame(width: fw)
            }
        }.frame(height: 6)
    }
}

struct Meter: View {
    let label: String, value: String, frac: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(label).foregroundColor(.secondary); Spacer(); Text(value).fontWeight(.semibold) }.font(.system(size: fs(12)))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12))
                    Capsule().fill(frac > 0.9 ? AnyShapeStyle(Color.red) : AnyShapeStyle(Theme.accent)).frame(width: g.size.width * CGFloat(max(0, min(1, frac))))
                }
            }.frame(height: 6)
        }
    }
}

struct MenuView: View {
    @ObservedObject var vm: VM
    @Environment(\.openWindow) var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(nsImage: cachedIcon(Theme.p)).resizable().frame(width: 22, height: 22)
                (Text("Tidy") + Text("mint").foregroundColor(Theme.brandMint)).font(.system(size: fs(13), weight: .bold))
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text(t("Disk", "Ổ đĩa")).foregroundColor(.secondary); Spacer()
                    Text(String(format: t("%.0f GB free / %.0f GB", "Trống %.0f / %.0f GB"), vm.freeGB, vm.totalGB)).fontWeight(.semibold) }
                    .font(.system(size: fs(12)))
                DiskBar(free: vm.freeGB, total: vm.totalGB, low: vm.freeGB > 0 && vm.freeGB < vm.lowSpaceGB)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text("RAM").foregroundColor(.secondary); Spacer()
                    Text(String(format: t("%.1f GB free / %.0f GB", "Trống %.1f / %.0f GB"), max(0, vm.ramTotal - vm.ramUsed), vm.ramTotal)).fontWeight(.semibold) }
                    .font(.system(size: fs(12)))
                DiskBar(free: max(0, vm.ramTotal - vm.ramUsed), total: vm.ramTotal, low: vm.ramTotal > 0 && vm.ramUsed / vm.ramTotal > 0.9)
            }
            HStack { Text(t("Trash", "Thùng rác")).foregroundColor(.secondary); Spacer(); Text(fmt(vm.trashSize)).fontWeight(.semibold) }.font(.system(size: fs(12)))
            Divider()
            VStack(spacing: 1) {
                MenuRow(title: t("Open Tidymint", "Mở Tidymint")) { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
                MenuRow(title: t("Clean Now", "Dọn ngay")) { vm.page = .smart; openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true); vm.smartScan() }
                MenuRow(title: t("Empty Trash...", "Đổ Thùng rác..."), disabled: vm.trashCount == 0) { NSApp.activate(ignoringOtherApps: true); vm.emptyTrash() }
            }.padding(.horizontal, -8)
            Divider()
            VStack(spacing: 1) {
                MenuRow(title: t("Support the project", "Ủng hộ dự án")) { NSWorkspace.shared.open(sponsorURL("menubar")) }
                MenuRow(title: t("Quit", "Thoát")) { NSApp.terminate(nil) }
            }.padding(.horizontal, -8)
        }
        .padding(14).frame(width: 280)
        .onAppear { vm.refreshRAM(); vm.refreshDisk(); vm.refreshTrash() }
    }
}

/// Menu bar icon: a hard drive with the free space (e.g. "75GB") inside the upper part,
/// a divider line and an activity light at the bottom. The shaded part shows free space
/// like a battery level; red when the disk is nearly full.
/// The mint leaf outline (Creative Fabrica leaf approved 28/10, same as docs/logo.svg), in app-icon coordinates
/// (y down, x 570.6...762, y 168...465.1). Used by the app icon and the menu bar icon.
let leafOutline: [CGFloat] = [
            708.0,168.0, 705.5,168.5, 701.7,169.6, 696.6,171.9, 691.9,174.8, 686.9,178.9, 682.4,183.6, 678.3,189.0, 674.5,195.0, 671.6,201.1,
            671.1,201.1, 670.6,200.8, 669.4,199.5, 668.8,198.4, 667.4,195.2, 666.3,191.6, 662.5,193.4, 657.8,196.8, 655.5,198.8, 652.6,202.0,
            649.8,205.5, 647.6,209.0, 643.7,216.6, 642.1,220.7, 640.9,224.9, 640.7,224.8, 636.0,213.7, 629.8,218.8, 625.3,223.2, 621.7,227.4,
            616.7,234.4, 614.0,239.2, 611.5,244.5, 609.5,250.1, 608.1,255.1, 607.4,258.7, 607.2,261.3, 606.9,261.3, 601.4,248.4, 601.1,248.6,
            599.5,251.0, 597.2,254.8, 595.2,258.9, 592.7,265.0, 590.9,270.8, 589.5,276.5, 588.4,283.4, 587.7,291.8, 587.7,298.1, 587.9,300.1,
            587.5,300.1, 575.6,291.7, 575.4,291.9, 575.1,305.3, 575.2,309.8, 575.9,318.6, 576.6,324.5, 578.2,334.5, 580.0,343.1, 581.1,347.2,
            579.0,347.3, 576.5,346.9, 574.2,346.2, 570.8,344.6, 570.6,344.7, 572.3,353.1, 574.6,361.4, 576.2,366.1, 578.6,372.5, 581.6,378.8,
            586.6,387.7, 592.0,395.5, 597.7,402.3, 604.3,408.9, 611.1,414.5, 619.3,420.2, 619.7,426.6, 620.4,433.1, 620.6,433.7, 621.3,439.0,
            622.6,445.6, 625.6,455.7, 627.2,460.0, 629.4,465.1, 629.5,464.9, 629.3,464.3, 628.6,459.1, 628.2,452.1, 628.2,446.0, 628.6,438.6,
            630.2,427.2, 631.6,420.7, 633.8,412.0, 636.3,404.2, 638.8,397.4, 642.0,389.7, 646.8,379.4, 654.7,364.0, 668.8,338.8, 676.5,324.4,
            683.5,309.9, 688.7,297.2, 691.0,290.8, 693.7,281.6, 695.3,274.9, 696.6,267.4, 697.6,259.9, 697.9,252.6, 697.8,244.7, 697.3,239.6,
            697.1,239.0, 697.2,237.8, 697.4,238.1, 698.3,243.8, 699.0,251.7, 699.0,261.7, 698.8,263.0, 698.8,265.4, 698.1,271.9, 696.5,281.5,
            695.2,287.7, 692.7,296.9, 688.4,309.7, 682.7,323.6, 676.4,337.6, 665.7,359.3, 659.4,372.8, 655.3,382.1, 651.2,392.3, 648.0,401.5,
            645.5,410.0, 643.0,421.0, 641.7,430.3, 646.5,431.5, 653.2,432.4, 664.0,432.4, 668.5,432.0, 674.1,431.1, 679.3,430.0, 685.0,428.4,
            690.4,426.6, 695.6,424.5, 705.6,419.8, 705.6,419.4, 704.6,419.2, 701.5,417.4, 698.8,415.0, 699.0,414.6, 701.9,414.5, 706.1,413.9,
            712.3,412.0, 716.1,410.5, 720.2,408.4, 727.4,403.9, 733.8,398.7, 737.9,394.7, 738.8,393.6, 736.9,394.7, 734.4,395.6, 731.7,396.1,
            728.9,396.1, 724.5,395.2, 721.6,394.0, 720.9,393.5, 726.9,390.5, 732.0,386.9, 737.8,381.3, 742.4,375.5, 746.5,369.3, 751.1,360.8,
            754.5,352.9, 757.2,344.6, 756.9,344.6, 755.2,345.7, 752.2,347.1, 750.1,347.5, 749.0,347.5, 747.2,346.9, 746.3,346.0, 745.7,344.5,
            748.3,342.0, 751.1,338.1, 752.9,334.7, 755.1,329.4, 757.4,322.6, 759.7,314.0, 762.0,301.4, 761.9,301.3, 760.9,302.0, 759.2,302.4,
            754.9,302.4, 749.2,301.4, 748.7,301.1, 750.8,298.5, 753.1,294.0, 754.9,288.0, 756.0,281.4, 756.5,276.4, 756.6,265.4, 756.3,257.8,
            755.4,249.4, 753.4,251.4, 750.8,253.0, 747.7,253.9, 746.0,254.0, 745.7,253.8, 746.0,250.4, 745.8,245.0, 744.7,235.6, 742.0,221.8,
            738.1,207.1, 737.8,207.1, 735.5,210.2, 732.4,213.3, 729.9,215.3, 729.3,215.3, 729.3,213.7, 728.8,210.8, 727.7,206.7, 725.7,201.0,
            723.4,195.8, 716.8,182.8, 711.6,173.8
]

/// The leaf scaled to height `h`, y-up, left edge at x0, bottom (stem) at y0.
func leafPath(x0: CGFloat, y0: CGFloat, h: CGFloat) -> NSBezierPath {
    let minX: CGFloat = 570.6, minY: CGFloat = 168.0, maxY: CGFloat = 465.1
    let k = h / (maxY - minY), p = NSBezierPath()
    for i in stride(from: 0, to: leafOutline.count, by: 2) {
        let pt = NSPoint(x: x0 + (leafOutline[i] - minX) * k, y: y0 + (maxY - leafOutline[i + 1]) * k)
        if i == 0 { p.move(to: pt) } else { p.line(to: pt) }
    }
    p.close(); return p
}

/// Share of the leaf's area below each height (0...1, 200 steps from the stem up), measured once by drawing it.
/// Filling by area, not height, keeps 70% and 90% visibly different (the tip is narrow).
let leafAreaBelow: [CGFloat] = {
    let n = 200
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: n, pixelsHigh: n, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return [] }
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.black.setFill(); leafPath(x0: 0, y0: 0, h: CGFloat(n)).fill()
    NSGraphicsContext.restoreGraphicsState()
    var rows = [CGFloat](repeating: 0, count: n)          // rows[0] = bottom row
    for y in 0..<n { for x in 0..<n where (rep.colorAt(x: x, y: n - 1 - y)?.alphaComponent ?? 0) > 0.5 { rows[y] += 1 } }
    let total = max(1, rows.reduce(0, +)); var acc: CGFloat = 0
    return rows.map { acc += $0; return acc / total }
}()
/// Height (0...1) to fill so the filled part covers `area` of the leaf.
func leafFillHeight(_ area: CGFloat) -> CGFloat {
    guard area > 0 else { return 0 }
    guard let i = leafAreaBelow.firstIndex(where: { $0 >= area }) else { return 1 }
    return CGFloat(i + 1) / CGFloat(max(1, leafAreaBelow.count))
}

func menuBarImage(free: Double, total: Double, level: Int) -> NSImage {
    // The mint leaf, filled (by area) as far as the disk is used, then the free space.
    // 75GB, 123GB, then 1.2TB from 1000 GB up, so the label never grows past 3 digits.
    let text = free >= 999.5 ? String(format: "%.1fTB", free / 1000) : String(format: "%.0fGB", free)
    // level 0 normal (template, follows the menu bar), 1 getting low (Theme.warn), 2 low (Theme.danger).
    // Same hex values as the app palette, picked by the system appearance (the menu bar is not the app's theme).
    let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    func hex(_ v: Int) -> NSColor { NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1) }
    let ink: NSColor = level >= 2 ? hex(dark ? 0xff6b6b : 0xb91c1c) : (level == 1 ? hex(dark ? 0xffc56b : 0xa15c00) : .black)
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium), .foregroundColor: ink]
    let ts = (text as NSString).size(withAttributes: attrs)
    let gw: CGFloat = 12.5, gap: CGFloat = 3, H: CGFloat = 18
    let W = ceil(gw + gap + ts.width) + 1
    let used = total > 0 ? CGFloat(max(0, min(1, 1 - free / total))) : 0
    let img = NSImage(size: NSSize(width: W, height: H), flipped: false) { _ in
        // Mint leaf: faint whole leaf, solid part = share of the disk in use (by area).
        let leaf = leafPath(x0: 1, y0: 0.5, h: 17)
        NSGraphicsContext.saveGraphicsState(); leaf.addClip()
        ink.withAlphaComponent(0.3).setFill(); NSRect(x: 0, y: 0, width: gw, height: H).fill()
        ink.setFill(); NSRect(x: 0, y: 0.5, width: gw, height: 17 * leafFillHeight(used)).fill()
        NSGraphicsContext.restoreGraphicsState()
        (text as NSString).draw(at: NSPoint(x: gw + gap, y: (H - ts.height) / 2), withAttributes: attrs)
        return true
    }
    img.isTemplate = level == 0   // normal: follows the menu bar's colour like Apple's icons
    return img
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationDidBecomeActive(_ n: Notification) {
        if !CommandLine.arguments.contains("--demo") { sharedVM.checkFullDiskAccess() }
        if !CommandLine.arguments.contains("--demo") && Mintangle.shared.enabled { Mintangle.shared.apply() }
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        // Developer helper: `Tidymint --export-icon <theme> <out.png>` writes the 1024px icon and quits.
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "--export-icon"), i + 2 < a.count,
           let pal = palettes.first(where: { $0.id == a[i + 1] }),
           let tiff = makeAppIcon(pal).tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: a[i + 2])); exit(0)
        }
        // Developer helper: `Tidymint --export-menubar <freeGB> <out.png>` writes the menu bar icon at 8x and quits.
        if let i = a.firstIndex(of: "--export-menubar"), i + 2 < a.count, let f = Double(a[i + 1]) {
            let im = menuBarImage(free: f, total: 245, level: a.count > i + 3 ? Int(a[i + 3]) ?? 0 : 0)
            let px = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(im.size.width * 8), pixelsHigh: Int(im.size.height * 8),
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            px.size = im.size
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: px)
            im.draw(in: NSRect(origin: .zero, size: im.size)); NSGraphicsContext.restoreGraphicsState()
            try? px.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: a[i + 2])); exit(0)
        }
        // Single instance: a second copy (typically an older build still running after an update) is asked to quit,
        // so the menu bar never shows two Tidymint icons. Screenshot/demo runs are exempt so tooling can run beside a live app.
        if !a.contains("--demo"), let bid = Bundle.main.bundleIdentifier {
            let me = ProcessInfo.processInfo.processIdentifier
            for other in NSRunningApplication.runningApplications(withBundleIdentifier: bid) where other.processIdentifier != me {
                other.terminate()
                // Grace period long enough for a move to the Trash in progress to finish and write its Undo record.
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) { if !other.isTerminated { other.forceTerminate() } }
            }
        }
        NSApp.applicationIconImage = dockIcon(Theme.p)
        if !a.contains("--demo") { sharedVM.checkFullDiskAccess() }
        if !a.contains("--demo") { Mintangle.shared.apply() }   // shortcuts only when the user turned Mintangle on
        if !a.contains("--demo") && featureShelf { Shelf.shared.apply() }   // shelf only when the user turned it on
        // Dev helper for screenshots: `--shelf-open path1 path2…` opens the shelf with those files.
        if isDevBuild, let i = a.firstIndex(of: "--shelf-open") {
            let paths = a[(i + 1)...].prefix { !$0.hasPrefix("--") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { Shelf.shared.add(paths.map { URL(fileURLWithPath: $0) }); Shelf.shared.show(atPointer: false) }
        }
        PreviewLinks.clear()   // leftovers from a run that quit with the month viewer open
        if !a.contains("--demo") { _ = CheckIn.shared.firstOpen }   // saved once, on the first launch
        // Developer helper for README screenshots: `--demo` fills every page with sample data (no real files),
        // `--page <name> --window <W>x<H>` opens a page at a fixed size.
        if let i = a.firstIndex(of: "--export-icon"), i + 1 < a.count, a[i + 1].lowercased().hasSuffix(".png") {
            // Writes the 1024px app icon for Resources/AppIcon.png, then quits. Used by build tooling.
            let img = makeAppIcon(Theme.p)
            if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: a[i + 1]))
            }
            exit(0)
        }
        if a.contains("--demo") { Demo.load(sharedVM) }
        if let i = a.firstIndex(of: "--page"), i + 1 < a.count,
           let pg = Page.allCases.first(where: { "\($0)" == a[i + 1] }) {
            sharedVM.page = pg
            if pg == .cleanup && a.contains("--demo") { sharedVM.phase = (a.contains("--done") || a.contains("--demo-done")) ? .done : .review }
            if pg == .byapp && a.contains("--demo") { Demo.apps(sharedVM, detail: a.contains("--detail")) }
            if pg == .lens && a.contains("--sysdata") { sharedVM.openSys() }
            // `--scan` starts the scan of Duplicates or Large & Old Files right away (test helper).
            if pg == .dupes && a.contains("--scan") {
                sharedVM.scanDupes()
                // `--detail` opens the first group once the scan is done (test helper).
                if a.contains("--detail") {
                    Task { @MainActor in
                        while sharedVM.dupBusy { try? await Task.sleep(nanoseconds: 300_000_000) }
                        if !sharedVM.dupes.isEmpty { sharedVM.dupes[0].expanded = true }
                    }
                }
            }
            if pg == .large && a.contains("--scan") { sharedVM.scanLarge() }
            if pg == .smart && a.contains("--demo") { sharedVM.phase = a.contains("--done") ? .done : .summary; sharedVM.lastFreed = sharedVM.junkSelected; sharedVM.lastCount = 38 }
            if a.contains("--done") { sharedVM.lastResult = t("Moved 128 items (6.2 GB) to the Trash.", "Đã chuyển 128 mục (6,2 GB) vào Thùng rác.") }
        }
        if let i = a.firstIndex(of: "--window"), i + 1 < a.count {
            let wh = a[i + 1].split(separator: "x").compactMap { Double($0) }
            if wh.count == 2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    for w in NSApp.windows where w.title == "Tidymint" || w.identifier?.rawValue.contains("main") == true {
                        w.setContentSize(NSSize(width: wh[0], height: wh[1])); w.center()
                    }
                }
            }
        }
    }
}
