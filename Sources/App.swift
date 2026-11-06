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

/// Organize (folder sorting) ships in 0.4.0. Until then it is hidden for everyone except Macs that opt in for testing:
/// `defaults write com.haitrung.diskcleanup dev-organize -bool true` (turn off with `defaults delete com.haitrung.diskcleanup dev-organize`).
var featureOrganize: Bool { isDevBuild || UserDefaults.standard.bool(forKey: "dev-organize") }

/// Dev build (bundle id ending in ".dev", built with `./build.sh --dev`): runs beside the official app with its own
/// settings, data folder and a "DEV" badge on the icon, and shows every feature still hidden in releases.
let isDevBuild = Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true

func makeAppIcon(_ p: Palette) -> NSImage {
    let base = makeBaseIcon(p)
    guard isDevBuild else { return base }
    return NSImage(size: base.size, flipped: false) { r in
        base.draw(in: r)
        let pill = NSBezierPath(roundedRect: NSRect(x: 520, y: 70, width: 430, height: 190), xRadius: 95, yRadius: 95)
        NSColor(hex: 0xa15c00).setFill(); pill.fill()
        NSColor.white.setStroke(); pill.lineWidth = 14; pill.stroke()
        let t = NSAttributedString(string: "DEV", attributes: [.font: NSFont.systemFont(ofSize: 132, weight: .heavy), .foregroundColor: NSColor.white])
        let sz = t.size(); t.draw(at: NSPoint(x: 735 - sz.width / 2, y: 165 - sz.height / 2))
        return true
    }
}

func makeBaseIcon(_ p: Palette) -> NSImage {
    let img = NSImage(size: NSSize(width: 1024, height: 1024), flipped: true) { _ in
        // "dark" tints ports, veins and shadows; on a light palette it is a graphite grey, not the pale background.
        let dark = p.light ? NSColor(hex: 0x2b3431) : NSColor(hex: p.bg[0])
        // Mac mini body: white on dark palettes, Apple-style silver on light ones so it stands out from the pale tile.
        let shell = p.light ? NSColor(hex: 0xc9ccd0) : NSColor.white.withAlphaComponent(0.92)
        let body = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 190, yRadius: 190)
        // No drop shadow around the tile: macOS adds its own in the Dock, and in-app the halo shows on light backgrounds.
        (p.light ? NSColor(hex: p.icon[0]) : dark).setFill(); body.fill()
        let sh = NSShadow(); sh.shadowOffset = NSSize(width: 0, height: -16); sh.shadowBlurRadius = 40
        let cols = p.icon.map { NSColor(hex: $0) }
        let locs = (0..<cols.count).map { CGFloat($0) / CGFloat(max(cols.count - 1, 1)) }
        NSGradient(colors: cols, atLocations: locs, colorSpace: .sRGB)?.draw(in: body, angle: p.id == "pride" ? 90 : -45)
        NSGradient(colors: [NSColor.white.withAlphaComponent(0.14), NSColor.white.withAlphaComponent(0)],
                   atLocations: [0, 0.45], colorSpace: .sRGB)?.draw(in: body, angle: 90)
        // recessed foot
        dark.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: NSRect(x: 262, y: 688, width: 500, height: 22), xRadius: 10, yRadius: 10).fill()
        // body (2.54:1)
        let mini = NSBezierPath(roundedRect: NSRect(x: 222, y: 460, width: 580, height: 228), xRadius: 40, yRadius: 40)
        NSGraphicsContext.saveGraphicsState(); sh.shadowColor = NSColor.black.withAlphaComponent(0.35); sh.set()
        shell.setFill(); mini.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(colors: [NSColor.white.withAlphaComponent(p.light ? 0.45 : 0.0), dark.withAlphaComponent(p.light ? 0.22 : 0.18)], atLocations: [0, 1], colorSpace: .sRGB)?
            .draw(in: mini, angle: -45)
        NSColor.white.withAlphaComponent(0.8).setFill()
        NSBezierPath(roundedRect: NSRect(x: 262, y: 466, width: 500, height: 6), xRadius: 3, yRadius: 3).fill()
        // two USB-C ports (vertical), left
        dark.withAlphaComponent(0.85).setFill()
        NSBezierPath(roundedRect: NSRect(x: 304, y: 547, width: 18, height: 56), xRadius: 9, yRadius: 9).fill()
        NSBezierPath(roundedRect: NSRect(x: 348, y: 547, width: 18, height: 56), xRadius: 9, yRadius: 9).fill()
        // white status light, just left of the headphone jack
        dark.withAlphaComponent(0.55).setFill()
        NSBezierPath(ovalIn: NSRect(x: 656, y: 565, width: 20, height: 20)).fill()
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow(); glow.shadowBlurRadius = 10; glow.shadowOffset = .zero; glow.shadowColor = NSColor.white; glow.set()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: 660, y: 569, width: 12, height: 12)).fill()
        NSGraphicsContext.restoreGraphicsState()
        // headphone jack, right
        dark.withAlphaComponent(0.85).setFill()
        NSBezierPath(ovalIn: NSRect(x: 707, y: 560, width: 30, height: 30)).fill()
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: 715, y: 568, width: 14, height: 14)).fill()
        // Mint leaf above the Mac mini (Creative Fabrica leaf approved 28/10, same outline as docs/logo.svg):
        // the open vein is part of the outline, so the leaf takes the palette colour with no extra strokes.
        let lp = leafOutline
        let leaf = NSBezierPath()
        leaf.move(to: NSPoint(x: lp[0], y: lp[1]))
        for i in stride(from: 2, to: lp.count, by: 2) { leaf.line(to: NSPoint(x: lp[i], y: lp[i + 1])) }
        leaf.close()
        NSColor(hex: p.leaf).setFill(); leaf.fill()
        return true
    }
    return img
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

let sharedVM = MainActor.assumeIsolated { VM() }

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
