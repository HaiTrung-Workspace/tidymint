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

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: fs(10), weight: .semibold)).tracking(0.8)
            .foregroundColor(Theme.sub.opacity(0.8))
            .padding(.horizontal, 12).padding(.top, 14).padding(.bottom, 4)
    }
}

/// Sidebar Trash icon drawn as lines (same weight as the system symbols next to it), in two states:
/// lid flat when empty; lid resting askew on a crumpled ball when there is something inside.
struct TrashShape: Shape {
    var full: Bool
    func path(in r: CGRect) -> Path {
        let u = r.width / 20
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * u, y: r.minY + y * u) }
        var p = Path()
        // body: slight taper, rounded bottom corners
        p.move(to: pt(5.0, 6.8)); p.addLine(to: pt(5.9, 16.2))
        p.addQuadCurve(to: pt(7.7, 17.8), control: pt(6.1, 17.8))
        p.addLine(to: pt(12.3, 17.8))
        p.addQuadCurve(to: pt(14.1, 16.2), control: pt(13.9, 17.8))
        p.addLine(to: pt(15.0, 6.8))
        // ribs and rim
        p.move(to: pt(8.5, 9.4)); p.addLine(to: pt(8.7, 15.2))
        p.move(to: pt(11.5, 9.4)); p.addLine(to: pt(11.3, 15.2))
        p.move(to: pt(4.0, 6.8)); p.addLine(to: pt(16.0, 6.8))
        if !full {
            p.move(to: pt(3.6, 4.7)); p.addLine(to: pt(16.4, 4.7))
            p.move(to: pt(8.4, 4.7)); p.addLine(to: pt(8.4, 3.1)); p.addLine(to: pt(11.6, 3.1)); p.addLine(to: pt(11.6, 4.7))
        } else {
            // lid resting askew from (5.2, 2.6) to (16.6, 5.2); handle follows the same angle; crumpled ball underneath
            let a = CGPoint(x: 5.2, y: 2.6), b = CGPoint(x: 16.6, y: 5.2)
            let dx = b.x - a.x, dy = b.y - a.y, len = (dx * dx + dy * dy).squareRoot()
            let ux = dx / len, uy = dy / len, nx = uy, ny = -ux
            func on(_ t: CGFloat, _ h: CGFloat) -> CGPoint { pt(a.x + ux * t + nx * h, a.y + uy * t + ny * h) }
            p.move(to: pt(a.x, a.y)); p.addLine(to: pt(b.x, b.y))
            p.move(to: on(5.0, 0)); p.addLine(to: on(5.0, 1.6)); p.addLine(to: on(8.2, 1.6)); p.addLine(to: on(8.2, 0))
            p.addEllipse(in: CGRect(x: r.minX + 6.1 * u, y: r.minY + 3.5 * u, width: 3.4 * u, height: 3.3 * u))
        }
        return p
    }
}

struct NavItem: View {
    let p: Page
    @ObservedObject var vm: VM
    var body: some View {
        // Cleanup details has no menu row of its own (reached from Clean Now), so Clean Now stays highlighted there.
        let selected = vm.page == p || (p == .smart && vm.page == .cleanup)
        Button { vm.page = p } label: {
            HStack(spacing: 10) {
                // The Trash row has its own two-state line icon (see TrashShape).
                if p == .trash {
                    TrashShape(full: vm.trashSize > 0)
                        .stroke(selected ? Color.white : Theme.ink.opacity(0.8), style: StrokeStyle(lineWidth: 1.15, lineCap: .round, lineJoin: .round))
                        .frame(width: 18, height: 18).frame(width: 20)
                } else {
                    Image(systemName: p.icon).frame(width: 20)
                }
                Text(p.label).lineLimit(1)
                Spacer()
                NavBadge(p: p, vm: vm)
            }
            .font(.system(size: fs(13), weight: selected ? .semibold : .regular))
            .foregroundColor(selected ? .white : Theme.ink.opacity(0.8))
            .padding(.horizontal, 12).padding(.vertical, 8)
            // Selected item uses the theme colour; Smart Scan always keeps a light theme tint as the main entry point.
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? AnyShapeStyle(Theme.accentSolid.opacity(0.8))
                : (p == .smart ? AnyShapeStyle(Theme.accentSolid.opacity(Theme.p.light ? 0.12 : 0.22)) : AnyShapeStyle(Color.clear))))
            .hoverBG(8, Theme.ink.opacity(0.07))
            .contentShape(Rectangle())
        }.buttonStyle(.plain).id(p)
    }
}

/// Right edge of a sidebar row: spinner while that page scans, a small dot when a result is waiting to be seen,
/// a number on Settings only (count of pending things). Colours follow the theme.
struct NavBadge: View {
    let p: Page
    @ObservedObject var vm: VM
    var body: some View {
        let selected = vm.page == p
        if vm.isBusy(p) {
            ProgressView().controlSize(.mini).tint(selected ? .white : Theme.accentSolid)
        } else if p == .windows {
            MintangleNavState(selected: selected)
        } else if p == .shelf {
            ShelfNavState(selected: selected)
        } else if p == .settings {
            // A number only where it counts several pending things.
            if vm.settingsPending > 0 {
                Text("\(vm.settingsPending)").font(.system(size: fs(10), weight: .bold))
                    .foregroundColor(selected ? Theme.accentSolid : .white)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(Capsule().fill(selected ? Color.white : Theme.accentSolid))
            }
        } else if vm.fresh.contains(p) {
            // A new result not seen yet: a small dot. Startup Items with something worth a look: warning colour.
            let warn = p == .startup && vm.launchAttention > 0
            Circle().fill(selected ? Color.white : (warn ? Theme.warn : Theme.accentSolid)).frame(width: 8, height: 8)
                .tip(warn ? t("\(vm.launchAttention) items worth a look", "\(vm.launchAttention) mục đáng để ý") : t("New results", "Có kết quả mới"))
        }
    }
}

/// Compact language switch: 20pt tall, 10pt text.
struct LangSwitch: View {
    @ObservedObject var vm: VM
    var body: some View {
        HStack(spacing: 0) {
            ForEach(["vi", "en"], id: \.self) { l in
                Button { vm.setLang(l) } label: {
                    Text(l.uppercased())
                        .font(.system(size: fs(10), weight: .semibold))
                        .foregroundColor(Theme.ink.opacity(vm.lang == l ? 1 : 0.55))
                        .frame(width: 22, height: 16)
                        .background(RoundedRectangle(cornerRadius: 4).fill(vm.lang == l ? Theme.ink.opacity(0.22) : .clear))
                        .hoverTile(vm.lang != l)
                }.buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 6).stroke(Theme.ink.opacity(0.2), lineWidth: 1))
        .tip(vm.lang == "vi" ? "Ngôn ngữ" : "Language")
    }
}

// MARK: - Root

/// Tracks whether the sidebar menu has more items above or below the visible area.
final class ScrollEdges: ObservableObject {
    @Published var view: CGRect = .zero      // visible scroll area (global coordinates)
    @Published var content: CGRect = .zero   // menu content (global coordinates)
    var moreBelow: Bool { view.height > 0 && content.maxY - 6 > view.maxY + 4 }   // 6 = bottom padding under the last item
    var moreAbove: Bool { view.height > 0 && content.minY < view.minY - 4 }
}

struct Sidebar: View {
    @ObservedObject var vm: VM
    @StateObject private var edges = ScrollEdges()
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fixed header, kept clear of the window's traffic-light buttons.
            HStack(spacing: 8) {
                Image(nsImage: cachedIcon(Theme.p)).resizable().frame(width: 28, height: 28)
                (Text("Tidy").foregroundColor(Theme.text) + Text("mint").foregroundColor(Theme.brandMint)).font(.system(size: fs(15), weight: .bold))
            }.padding(.top, 44).padding(.bottom, 12)
            // The menu scrolls when the window is short, so nothing overlaps.
            // A fade and a "More" chevron show that items are hidden below (and a fade at the top when scrolled).
            ScrollViewReader { proxy in
            VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 2) {
            NavItem(p: .smart, vm: vm)
            NavItem(p: .byapp, vm: vm)
            NavItem(p: .apps, vm: vm)
            NavItem(p: .trash, vm: vm)
            // Advanced pages fold away so the first screen stays simple. The fold opens itself when one of them is active.
            Button { withAnimation(.easeOut(duration: 0.2)) { vm.setAdvanced(!vm.advancedOpen) } } label: {
                HStack {
                    SectionTitle(text: t("ADVANCED", "NÂNG CAO"))
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: fs(9), weight: .bold)).foregroundColor(Theme.sub)
                        .rotationEffect(.degrees(vm.advancedOpen ? 90 : 0)).padding(.trailing, 10)
                }.padding(.vertical, 2).hoverTile()
            }.buttonStyle(.plain)
            if vm.advancedOpen {
                NavItem(p: .lens, vm: vm)
                NavItem(p: .large, vm: vm)
                NavItem(p: .dupes, vm: vm)
                NavItem(p: .cloud, vm: vm)
                NavItem(p: .startup, vm: vm)
                NavItem(p: .stats, vm: vm)
                NavItem(p: .ignore, vm: vm)
            }
            // Not cleaning: tools that organize files get their own group, always open.
            if featureMintangle || featureShelf {
            HStack(alignment: .top, spacing: 1) {
                SectionTitle(text: t("TOOLS", "CÔNG CỤ")).padding(.trailing, -12)
                Image(systemName: "sparkle").font(.system(size: fs(8), weight: .bold)).foregroundColor(Theme.accentSolid)
                    .padding(.top, 9)
            }
            if featureMintangle { NavItem(p: .windows, vm: vm) }
            if featureShelf { NavItem(p: .shelf, vm: vm) }
            }
            SectionTitle(text: "")
            NavItem(p: .settings, vm: vm)
            NavItem(p: .contact, vm: vm)
            }.padding(.bottom, 6)
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { edges.content = g.frame(in: .global) }
                    .onChange(of: g.frame(in: .global)) { _, r in edges.content = r }
            })
            }
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { edges.view = g.frame(in: .global) }
                    .onChange(of: g.frame(in: .global)) { _, r in edges.view = r }
            })
            .onAppear { DispatchQueue.main.async { proxy.scrollTo(vm.page, anchor: .center) } }
            .onChange(of: vm.page) { _, pg in withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(pg, anchor: .center) } }
            .overlay(alignment: .top) {
                if edges.moreAbove {
                    LinearGradient(colors: [Theme.shade.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 22).allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottom) {
                if edges.moreBelow {
                    LinearGradient(colors: [.clear, Theme.shade.opacity(0.45)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 28).allowsHitTesting(false)
                }
            }
            // The "More" chip sits in its own row under the list, so it can never cover a menu item.
            if edges.moreBelow {
                Button { withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(Page.contact, anchor: .bottom) } } label: {
                    HStack(spacing: 4) {
                        Text(t("More", "Xem thêm")).font(.system(size: fs(10), weight: .semibold))
                        Image(systemName: "chevron.down").font(.system(size: fs(9), weight: .bold))
                    }
                    .foregroundColor(Theme.ink.opacity(0.85))
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.ink.opacity(0.14)))
                }.buttonStyle(.plain).hoverLift().padding(.vertical, 4).frame(maxWidth: .infinity)
            }
            }
            }
            Divider().overlay(Theme.ink.opacity(0.08)).padding(.bottom, 10)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Macintosh HD").font(.system(size: fs(11))).foregroundColor(Theme.sub)
                    Spacer()
                    LangSwitch(vm: vm)
                }
                (Text(String(format: t("%.0f GB free", "Trống %.0f GB"), vm.freeGB)).font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                 + Text(String(format: " / %.0f GB", vm.totalGB)).font(.system(size: fs(12))).foregroundColor(Theme.sub))
                DiskBar(free: vm.freeGB, total: vm.totalGB, low: vm.freeGB > 0 && vm.freeGB < vm.lowSpaceGB,
                        usedColor: Theme.ink.opacity(0.28))
                Text(String(format: t("%.0f GB used", "Đã dùng %.0f GB"), max(0, vm.totalGB - vm.freeGB)))
                    .font(.system(size: fs(10))).foregroundColor(Theme.sub)
            }.padding(.bottom, 16)
        }
        .padding(.horizontal, 14).frame(width: 120 + 140 * uiScale).background(Theme.sidebar)  // fixed parts (padding, icon, badge) do not scale, only the label does
    }
}

/// Gives the VM the NSWindow that hosts the main view, so window limits can be set on it directly.
struct WindowGrabber: NSViewRepresentable {
    let vm: VM
    final class V: NSView {
        var onWindow: ((NSWindow) -> Void)?
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); if let w = window { onWindow?(w) } }
    }
    func makeNSView(context: Context) -> V {
        let v = V(); v.onWindow = { w in MainActor.assumeIsolated { vm.mainWindow = w; vm.applyWindowLimits() } }; return v
    }
    func updateNSView(_ v: V, context: Context) {}
}

struct RootView: View {
    @ObservedObject var vm: VM
    @StateObject private var keys = KeyTap()
    var body: some View {
        HStack(spacing: 0) {
            Sidebar(vm: vm)
            Group {
                switch vm.page {
                case .smart: SmartView(vm: vm)
                case .cleanup: CleanupView(vm: vm)
                case .byapp: ByAppView(vm: vm)
                case .large: LargeView(vm: vm)
                case .lens: LensView(vm: vm)
                case .trash: TrashView(vm: vm)
                case .ignore: IgnoreView(vm: vm)
                case .cloud: CloudView(vm: vm)
                case .settings: SettingsView(vm: vm)
                case .apps: AppsView(vm: vm)
                case .dupes: DupesView(vm: vm)
                case .startup: StartupView(vm: vm)
                case .stats: StatsView(vm: vm)
                case .contact: ContactView(vm: vm)
                case .windows: MintangleView()
                case .shelf: ShelfPageView()
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.bg)
        .frame(minWidth: 980 * uiScale, minHeight: 600)
        .background(WindowGrabber(vm: vm))
        .id(vm.theme + vm.textSize)
        .preferredColorScheme(Theme.p.light ? .light : .dark)
        .ignoresSafeArea()
        .quickLookPreview(Binding(get: { vm.fileQL }, set: { vm.fileQL = $0 }))
        .onAppear {
            vm.checkUpdates(); vm.windowShown()
            // Space over a file row shows it (Quick Look), Space again closes it, like Finder.
            // Not while typing in a field, and not in the month viewer (it has its own Space).
            keys.start { e in
                MainActor.assumeIsolated {
                    guard e.keyCode == 49, e.modifierFlags.intersection([.command, .option, .control]).isEmpty,
                          vm.monthRef == nil, !(NSApp.keyWindow?.firstResponder is NSTextView) else { return false }
                    if vm.fileQL != nil { vm.fileQL = nil; return true }
                    if let h = vm.hoverFile, FileManager.default.fileExists(atPath: h.path) { vm.fileQL = h; return true }
                    return false
                }
            }
        }
        .onDisappear { vm.windowGone(); keys.stop() }
    }
}
