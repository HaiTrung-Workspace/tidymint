// Tidymint: a free, open-source disk cleaner for macOS, built for people who work with AI tools.
// "Keep your Mac in mint condition."
// Author: Tidymint contributors. License: MIT (see LICENSE). Provided "as is", without warranty.
// Safety rules: items are only moved to the Trash (the "Empty Trash" button asks first);
// cloud libraries, Photos, Mail, keychains, browser profiles and Apple system caches are never touched.
// Note: no @State anywhere (the @State macro needs an Xcode-only plugin); use Flag/ObservableObject instead.
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


// MARK: - App icon (drawn in code so it follows the theme)

/// Front view of a Mac mini (2024): two USB-C ports on the left; on the right,
/// the white status light sits just left of the headphone jack. 1024 x 1024 canvas, macOS icon grid (824 px rounded square).
private var iconCache: [String: NSImage] = [:]
/// Small icon for the sidebar and menu (bitmap, 64 px). The drawn icon is 1024 pt, and showing it directly kept
/// a 2048 px bitmap (16 MB) alive for each place it appears.
func cachedIcon(_ p: Palette) -> NSImage {
    if let i = iconCache[p.id] { return i }
    let i = rasterIcon(makeAppIcon(p), px: 64); iconCache[p.id] = i; return i
}
/// Draws `img` once into a px x px bitmap; the result is px/2 points (Retina).
func rasterIcon(_ img: NSImage, px: Int) -> NSImage {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return img }
    let pt = CGFloat(px) / 2
    rep.size = NSSize(width: pt, height: pt)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: pt, height: pt)); NSGraphicsContext.restoreGraphicsState()
    let out = NSImage(size: rep.size); out.addRepresentation(rep); return out
}
/// Dock icon: a 512 px bitmap (1 MB) instead of the 1024 pt drawing.
func dockIcon(_ p: Palette) -> NSImage { rasterIcon(makeAppIcon(p), px: 512) }

/// Dev build (built with `./build.sh --dev`, bundle id ending in ".dev"): runs beside the official app with its own
/// settings, data folder and a "DEV" badge on the icon, and has the self-tests and the developer's switches.
/// Decided when the app is compiled: without `-D TIDYMINT_DEV` this is the constant false, so renaming the bundle
/// id of a release (and signing it again) changes nothing (22/11/2026: a release tested its bundle id at run time).
#if TIDYMINT_DEV
let isDevBuild = Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true
#else
let isDevBuild = false
#endif

/// Forget the small icons, after something drawn on the icon changed.
func resetIconCache() { iconCache = [:] }

func makeAppIcon(_ p: Palette) -> NSImage {
    let base = makeLeafIcon(p)
    return isDevBuild ? devBadged(base) : base
}

/// The icon with "DEV" written at the bottom right: amber letters only, no pill (17/11/2026: a pill covered the leaf's
/// tail). Wholly inside the tile (the 824 px rounded square, corners included) and below the leaf: anything reaching
/// past the tile makes macOS 26 and later treat the icon as off-grid and show it small on a grey plate in Finder.
func devBadged(_ base: NSImage) -> NSImage {
    NSImage(size: base.size, flipped: false) { r in
        base.draw(in: r)
        let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.45); shadow.shadowBlurRadius = 10; shadow.shadowOffset = NSSize(width: 0, height: -3)
        let t = NSAttributedString(string: "DEV", attributes: [.font: NSFont.systemFont(ofSize: 104, weight: .heavy), .foregroundColor: NSColor(hex: 0xffb02e),
                                                              .kern: 2, .shadow: shadow])
        let sz = t.size(); t.draw(at: NSPoint(x: 730 - sz.width / 2, y: 188 - sz.height / 2))
        return true
    }
}

/// The app icon from 0.6.0 (chosen 15/11/2026): the mint leaf alone on a dark tile, like the favicon, following the theme.
/// The tile runs from the palette's first icon colour (top right) down to a darker shade of it (bottom left); on the Mint
/// theme that is the brand tile #0D2B24 to #05110E with the leaf #5FF0C0. A light palette keeps its pale tile, Pride its
/// rainbow. 1024 x 1024 canvas, macOS icon grid (824 px rounded square); the leaf is 560 tall, centred.
func makeLeafIcon(_ p: Palette) -> NSImage {
    NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { _ in
        let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 190, yRadius: 190)
        if p.id == "pride" {
            let cols = p.icon.map { NSColor(hex: $0) }
            let locs = (0..<cols.count).map { CGFloat($0) / CGFloat(max(cols.count - 1, 1)) }
            NSGradient(colors: cols, atLocations: locs, colorSpace: .sRGB)?.draw(in: tile, angle: -90)
        } else {
            let hi = p.icon[0]
            // 40% of each channel: the same hue, deep enough to sit on a dark Dock and still part from a white one.
            let dim = (((hi >> 16) & 255) * 2 / 5) << 16 | (((hi >> 8) & 255) * 2 / 5) << 8 | ((hi & 255) * 2 / 5)
            let lo = p.light ? p.icon[p.icon.count - 1] : dim
            NSGradient(colors: [NSColor(hex: lo), NSColor(hex: hi)], atLocations: [0, 1], colorSpace: .sRGB)?.draw(in: tile, angle: 45)
        }
        NSColor(hex: p.leaf).setFill(); leafPath(x0: 331.6, y0: 232, h: 560).fill()
        return true
    }
}

extension NSBezierPath {
    /// Quadratic curve expressed as a cubic (NSBezierPath has no quadratic segment).
    func quad(to p: NSPoint, control q: NSPoint) {
        let p0 = currentPoint
        let c1 = NSPoint(x: p0.x + 2 / 3 * (q.x - p0.x), y: p0.y + 2 / 3 * (q.y - p0.y))
        let c2 = NSPoint(x: p.x + 2 / 3 * (q.x - p.x), y: p.y + 2 / 3 * (q.y - p.y))
        curve(to: p, controlPoint1: c1, controlPoint2: c2)
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1)
    }
}

let sharedVM = MainActor.assumeIsolated { TrashHint.earlyProbe(); return VM() }

@main
struct DiskCleanupApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @ObservedObject var vm = sharedVM
    @AppStorage("showMenuBar") var showMenuBar = true
    var body: some Scene {
        Window("Tidymint", id: "main") { RootView(vm: vm) }
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width: 1080, height: 700)
        MenuBarExtra(isInserted: $showMenuBar) {
            MenuView(vm: vm).id(vm.theme)
        } label: {
            Image(nsImage: menuBarImage(free: vm.freeGB, total: vm.totalGB, level: vm.diskLevel))
        }
        .menuBarExtraStyle(.window)
    }
}
