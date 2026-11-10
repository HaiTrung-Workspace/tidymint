// Mintangle: drag to snap, the footprint shown while dragging, and where each action puts a window (core in Mintangle.swift).
import AppKit
import Carbon
import SwiftUI

// MARK: Drag to snap

/// Watches mouse drags while Mintangle is on. When a window is being moved (its size stays the same) and the pointer
/// touches a screen edge or corner, a translucent footprint shows where it will land; letting go there snaps it.
/// Same zones as Rectangle: left/right edge = half, top = maximize, corners = quarter, bottom edge = third under the pointer.
final class MTSnapper {
    private var monitor: Any?
    private var win: AXUIElement?
    private var app: AXUIElement?
    private var startFrame: CGRect = .zero
    private var moving = false
    private var zone: MTAction?
    private var zoneScreen: NSScreen?
    private var lastRead = Date.distantPast
    private let footprint = MTFootprint()

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] e in
            switch e.type {
            case .leftMouseDown: self?.down()
            case .leftMouseDragged: self?.drag()
            case .leftMouseUp: self?.up()
            default: break
            }
        }
    }
    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil; reset()
    }
    private func reset() { win = nil; app = nil; moving = false; zone = nil; footprint.hide() }

    /// The window under the pointer, if it belongs to an app that is not on the ignore list.
    private func down() {
        reset()
        let p = NSEvent.mouseLocation
        let sys = AXUIElementCreateSystemWide()
        var el: AXUIElement?
        let h = NSScreen.screens.first?.frame.height ?? 0
        guard AXUIElementCopyElementAtPosition(sys, Float(p.x), Float(h - p.y), &el) == .success, let el else { return }
        var pid: pid_t = 0
        AXUIElementGetPid(el, &pid)
        guard pid != ProcessInfo.processInfo.processIdentifier,
              let bid = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier,
              !Mintangle.shared.ignored.contains(bid) else { return }
        var w: CFTypeRef?
        var target: AXUIElement?
        if AXUIElementCopyAttributeValue(el, kAXWindowAttribute as CFString, &w) == .success, let w { target = (w as! AXUIElement) }
        else {
            var role: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &role) == .success, (role as? String) == kAXWindowRole { target = el }
        }
        guard let target, let f = Mintangle.frame(of: target) else { return }
        win = target; app = AXUIElementCreateApplication(pid); startFrame = f
    }

    private func drag() {
        guard let win else { return }
        if !moving {
            // Only start once the window really moves without changing size (a move, not a resize or a text drag).
            guard Date().timeIntervalSince(lastRead) > 0.03 else { return }
            lastRead = Date()
            guard let f = Mintangle.frame(of: win) else { return }
            guard abs(f.width - startFrame.width) < 2, abs(f.height - startFrame.height) < 2,
                  abs(f.minX - startFrame.minX) > 2 || abs(f.minY - startFrame.minY) > 2 else { return }
            moving = true
            unsnapIfNeeded(win, current: f)
        }
        let p = NSEvent.mouseLocation
        if let (a, s) = Self.zone(at: p) {
            if a != zone || s != zoneScreen {
                zone = a; zoneScreen = s
                footprint.show(a.rect(in: s.visibleFrame, step: 0, gap: Mintangle.shared.gap, current: startFrame))
            }
        } else if zone != nil { zone = nil; footprint.hide() }
    }

    private func up() {
        defer { reset() }
        guard moving, let win, let app, let zone, let s = zoneScreen else { return }
        let m = Mintangle.shared
        let key = Int(CFHash(win))
        let cur = Mintangle.frame(of: win) ?? startFrame
        if m.original[key] == nil { m.original[key] = startFrame.size == cur.size ? startFrame : cur }
        let r = zone.rect(in: s.visibleFrame, step: 0, gap: m.gap, current: cur)
        Mintangle.set(win, app: app, r)
        m.snapped[key] = Mintangle.frame(of: win) ?? r
    }

    /// A window Mintangle had snapped and that is dragged away gets its earlier size back, under the pointer.
    private func unsnapIfNeeded(_ w: AXUIElement, current f: CGRect) {
        let m = Mintangle.shared
        let key = Int(CFHash(w))
        guard m.unsnapRestore, let snap = m.snapped[key], let o = m.original[key],
              abs(snap.width - f.width) < 3, abs(snap.height - f.height) < 3, let app else { return }
        let p = NSEvent.mouseLocation
        let rx = f.width > 0 ? (p.x - f.minX) / f.width : 0.5
        let r = CGRect(x: p.x - rx * o.width, y: f.maxY - o.height, width: o.width, height: o.height)
        Mintangle.set(w, app: app, r)
        startFrame = Mintangle.frame(of: w) ?? r
        m.snapped[key] = nil; m.original[key] = nil
    }

    /// Edge zones, 5 px from the screen frame; corners take 30 px along each edge.
    static func zone(at p: CGPoint) -> (MTAction, NSScreen)? {
        guard let s = NSScreen.screens.first(where: { NSMouseInRect(p, $0.frame, false) }) else { return nil }
        let f = s.frame, m: CGFloat = 5, c: CGFloat = 30
        let left = p.x <= f.minX + m, right = p.x >= f.maxX - m - 1
        let top = p.y >= f.maxY - m - 1, bottom = p.y <= f.minY + m
        let nearTop = p.y >= f.maxY - c, nearBottom = p.y <= f.minY + c
        let nearLeft = p.x <= f.minX + c, nearRight = p.x >= f.maxX - c
        if (left && nearTop) || (top && nearLeft) { return (.topLeft, s) }
        if (right && nearTop) || (top && nearRight) { return (.topRight, s) }
        if (left && nearBottom) || (bottom && nearLeft) { return (.bottomLeft, s) }
        if (right && nearBottom) || (bottom && nearRight) { return (.bottomRight, s) }
        if left { return (.leftHalf, s) }
        if right { return (.rightHalf, s) }
        if top { return (.maximize, s) }
        if bottom {
            let fx = (p.x - f.minX) / f.width
            return (fx < 1.0 / 3 ? .firstThird : (fx < 2.0 / 3 ? .centerThird : .lastThird), s)
        }
        return nil
    }
}

/// The translucent preview of where a dragged window will land.
final class MTFootprint {
    private lazy var window: NSWindow = {
        let w = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        w.isOpaque = false; w.backgroundColor = .clear; w.hasShadow = false; w.ignoresMouseEvents = true
        w.level = .floating; w.isReleasedWhenClosed = false
        w.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
        let v = NSView(); v.wantsLayer = true
        v.layer?.cornerRadius = 12
        v.layer?.backgroundColor = NSColor(calibratedRed: 0.37, green: 0.94, blue: 0.75, alpha: 0.22).cgColor
        v.layer?.borderColor = NSColor(calibratedRed: 0.37, green: 0.94, blue: 0.75, alpha: 0.85).cgColor
        v.layer?.borderWidth = 2
        w.contentView = v
        return w
    }()
    func show(_ r: CGRect) {
        if window.isVisible {
            NSAnimationContext.runAnimationGroup { ctx in ctx.duration = 0.12; window.animator().setFrame(r, display: true) }
        } else {
            window.setFrame(r, display: true); window.alphaValue = 0; window.orderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in ctx.duration = 0.12; window.animator().alphaValue = 1 }
        }
    }
    func hide() { if window.isVisible { window.orderOut(nil) } }
}

extension MTAction {
    var isCorner: Bool { [.topLeft, .topRight, .bottomLeft, .bottomRight].contains(self) }
    /// Halves and corners react to a second press (cycle sizes or move to the neighbouring display).
    var repeats: Bool { [.leftHalf, .rightHalf, .topHalf, .bottomHalf].contains(self) || isCorner }
    /// Actions that describe a place on the screen, so moving to another display can re-apply them there.
    var hasLayout: Bool { ![.center, .larger, .smaller, .restore, .nextDisplay, .previousDisplay].contains(self) }
    /// Left side becomes right side when the window jumps to the display on the left, and the other way round.
    var mirrored: MTAction {
        switch self {
        case .leftHalf: return .rightHalf
        case .rightHalf: return .leftHalf
        case .topLeft: return .topRight
        case .topRight: return .topLeft
        case .bottomLeft: return .bottomRight
        case .bottomRight: return .bottomLeft
        default: return self
        }
    }

    /// Target frame inside the visible area of a screen (Cocoa coordinates). `step` 0/1/2 = 1/2, 2/3, 1/3 for halves and corners.
    func rect(in v: CGRect, step: Int, gap g: Double, current c: CGRect) -> CGRect {
        let frac: CGFloat = [0.5, 2.0 / 3.0, 1.0 / 3.0][min(max(step, 0), 2)]
        let w = v.width, h = v.height
        var r: CGRect
        switch self {
        case .leftHalf: r = CGRect(x: v.minX, y: v.minY, width: w * frac, height: h)
        case .rightHalf: r = CGRect(x: v.maxX - w * frac, y: v.minY, width: w * frac, height: h)
        case .topHalf: r = CGRect(x: v.minX, y: v.maxY - h * frac, width: w, height: h * frac)
        case .bottomHalf: r = CGRect(x: v.minX, y: v.minY, width: w, height: h * frac)
        case .topLeft: r = CGRect(x: v.minX, y: v.midY, width: w * frac, height: h / 2)
        case .topRight: r = CGRect(x: v.maxX - w * frac, y: v.midY, width: w * frac, height: h / 2)
        case .bottomLeft: r = CGRect(x: v.minX, y: v.minY, width: w * frac, height: h / 2)
        case .bottomRight: r = CGRect(x: v.maxX - w * frac, y: v.minY, width: w * frac, height: h / 2)
        case .firstThird: r = CGRect(x: v.minX, y: v.minY, width: w / 3, height: h)
        case .centerThird: r = CGRect(x: v.minX + w / 3, y: v.minY, width: w / 3, height: h)
        case .lastThird: r = CGRect(x: v.minX + 2 * w / 3, y: v.minY, width: w / 3, height: h)
        case .firstTwoThirds: r = CGRect(x: v.minX, y: v.minY, width: 2 * w / 3, height: h)
        case .lastTwoThirds: r = CGRect(x: v.minX + w / 3, y: v.minY, width: 2 * w / 3, height: h)
        case .maximize: r = v
        case .almostMaximize: r = v.insetBy(dx: w * 0.05, dy: h * 0.05)
        case .maximizeHeight: return CGRect(x: c.minX, y: v.minY, width: c.width, height: h)
        case .center:
            let cw = min(c.width, w), ch = min(c.height, h)
            return CGRect(x: v.midX - cw / 2, y: v.midY - ch / 2, width: cw, height: ch)
        case .larger, .smaller:
            let d: CGFloat = self == .larger ? 30 : -30
            var n = c.insetBy(dx: -d, dy: -d)
            n.size.width = max(200, min(n.width, w)); n.size.height = max(150, min(n.height, h))
            n.origin.x = max(v.minX, min(n.minX, v.maxX - n.width)); n.origin.y = max(v.minY, min(n.minY, v.maxY - n.height))
            return n
        case .restore, .nextDisplay, .previousDisplay: return c
        }
        return Self.withGap(r, in: v, gap: CGFloat(g))
    }

    /// Gap: full gap at screen edges, half a gap on inner edges, so two neighbours are `gap` apart.
    static func withGap(_ r: CGRect, in v: CGRect, gap g: CGFloat) -> CGRect {
        guard g > 0 else { return r }
        let l = abs(r.minX - v.minX) < 1 ? g : g / 2, rt = abs(r.maxX - v.maxX) < 1 ? g : g / 2
        let b = abs(r.minY - v.minY) < 1 ? g : g / 2, tp = abs(r.maxY - v.maxY) < 1 ? g : g / 2
        return CGRect(x: r.minX + l, y: r.minY + b, width: r.width - l - rt, height: r.height - b - tp)
    }
}
