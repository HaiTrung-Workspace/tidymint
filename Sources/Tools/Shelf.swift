// Mintdrop (code name Shelf), a drop shelf in the spirit of Dropover: a small floating panel to collect files from several places, see their total size,
// then drag them all out at once, move them to a folder, or put them in the Trash (undoable like every clean).
// Opens by shaking the pointer while dragging files, or with a shortcut. Off by default.
// Keeps only paths in memory: nothing is copied, nothing leaves the Mac.

import AppKit
import Carbon
import SwiftUI
import QuickLook
import UniformTypeIdentifiers

var featureShelf: Bool { true }   // released in 0.5.0 (was a dev-shelf flag); stays off until the user turns it on

struct ShelfItem: Identifiable, Equatable {
    var url: URL
    var size: Int64?
    var id: String { url.path }
}

final class Shelf: ObservableObject {
    static let shared = Shelf()
    private let d = UserDefaults.standard

    @Published var enabled: Bool { didSet { d.set(enabled, forKey: "sh.enabled"); apply() } }
    @Published var shake: Bool { didSet { d.set(shake, forKey: "sh.shake"); apply() } }
    @Published var useKey: Bool { didSet { d.set(useKey, forKey: "sh.key"); apply() } }

    @Published var items: [ShelfItem] = []
    @Published var selection: Set<String> = []
    /// Box being dragged over the list to select several files, in the list's coordinates.
    @Published var marquee: CGRect?
    /// Where each row sits in the list (for the selection box). Not published: it changes on every layout pass.
    var rowFrames: [String: CGRect] = [:]
    private var anchor: String?
    private var marqueeBase: Set<String> = []
    @Published var preview: URL?
    @Published var targeted = false
    /// Result of the last action, shown at the bottom of the shelf.
    @Published var status: String?
    @Published var canUndo = false
    @Published private(set) var visible = false
    @Published private(set) var keyFailed = false
    @Published private(set) var rivalsRunning: [String] = []

    static let rivalIDs: [String: String] = ["me.damir.dropover-mac": "Dropover"]
    /// Control + Option + S. Not a macOS default and not one of Rectangle's.
    static let key = MTKey(code: UInt32(kVK_ANSI_S), mods: UInt32(controlKey | optionKey), char: "S")
    private static let signature = OSType(0x5348_4C46)   // "SHLF"

    private var panel: ShelfPanel?
    private var hotRef: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var downMon: Any?
    private var localDownMon: Any?
    private var timer: Timer?
    private var lastTrashed: [URL] = []
    /// Date of the shelf's own clean session: Undo on the shelf only acts while the app's last session is still this one.
    private var lastSession: Date?
    /// Last "Move to…": where each file was and where it went, so Undo can move it back.
    private var lastMoves: [(from: URL, to: URL)] = []
    /// Where the user dragged the shelf to last (kept for this run of the app).
    private var savedOrigin: NSPoint?
    func moved(to o: NSPoint) { savedOrigin = o }

    private init() {
        enabled = d.bool(forKey: "sh.enabled")
        shake = d.object(forKey: "sh.shake") as? Bool ?? true
        useKey = d.object(forKey: "sh.key") as? Bool ?? true
    }

    // MARK: Switches

    func apply() {
        refreshRivals()
        if enabled && useKey { registerKey() } else { unregisterKey() }
        if enabled && shake { startWatch() } else { stopWatch() }
        if !enabled { hide() }
    }

    func refreshRivals() {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        rivalsRunning = Self.rivalIDs.keys.filter { running.contains($0) }.sorted()
    }
    func quitRival(_ id: String) {
        NSRunningApplication.runningApplications(withBundleIdentifier: id).forEach { $0.terminate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.refreshRivals() }
    }

    private func registerKey() {
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, ev, _ in
                var hk = EventHotKeyID()
                let st = GetEventParameter(ev, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
                guard st == noErr, hk.signature == Shelf.signature else { return OSStatus(eventNotHandledErr) }
                DispatchQueue.main.async { Shelf.shared.toggle() }
                return noErr
            }, 1, &spec, nil, &handler)
        }
        guard hotRef == nil else { return }
        var ref: EventHotKeyRef?
        let st = RegisterEventHotKey(Self.key.code, Self.key.mods, EventHotKeyID(signature: Self.signature, id: 1), GetApplicationEventTarget(), 0, &ref)
        hotRef = ref
        keyFailed = st != noErr
    }
    private func unregisterKey() {
        if let hotRef { UnregisterEventHotKey(hotRef) }
        hotRef = nil; keyFailed = false
    }

    // MARK: Shake while dragging files
    // No permission needed: on each mouse press anywhere, a light 60 Hz check runs only while the button is held,
    // and only reacts once a file drag has started (the drag pasteboard changed and holds file URLs).

    private var downCount = 0
    private var lastX: CGFloat?
    private var dir: CGFloat = 0
    private var run: CGFloat = 0
    private var flips: [Date] = []
    private var fired = false

    private func startWatch() {
        guard downMon == nil else { return }
        downMon = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in self?.pressed() }
        localDownMon = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] e in self?.pressed(); return e }
    }
    private func stopWatch() {
        if let downMon { NSEvent.removeMonitor(downMon) }
        if let localDownMon { NSEvent.removeMonitor(localDownMon) }
        downMon = nil; localDownMon = nil
        timer?.invalidate(); timer = nil
    }
    private func pressed() {
        downCount = NSPasteboard(name: .drag).changeCount
        lastX = nil; dir = 0; run = 0; flips = []; fired = false
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
    }
    private func tick() {
        if NSEvent.pressedMouseButtons & 1 == 0 { timer?.invalidate(); timer = nil; return }
        guard !fired else { return }
        // The pointer is read only once a file drag is under way (PRIVACY.md): a plain click or a text selection is never followed.
        let pb = NSPasteboard(name: .drag)
        guard pb.changeCount != downCount, pb.types?.contains(.fileURL) == true else { return }
        let x = NSEvent.mouseLocation.x
        defer { lastX = x }
        guard let lastX else { return }
        let dx = x - lastX
        guard abs(dx) > 0.5 else { return }
        let s: CGFloat = dx > 0 ? 1 : -1
        if s == dir { run += abs(dx) } else {
            if run > 25 { flips.append(Date()) }   // a real stroke one way just ended
            dir = s; run = abs(dx)
        }
        flips = flips.filter { Date().timeIntervalSince($0) < 0.8 }
        if flips.count >= 3 { fired = true; flips = []; show(atPointer: true) }
    }

    // MARK: Panel

    func toggle() { visible ? hide() : show(atPointer: false) }

    func show(atPointer: Bool) {
        let p = panel ?? makePanel()
        panel = p
        let size = p.frame.size
        let mouse = NSEvent.mouseLocation
        let scr = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let vf = scr?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        // Under the pointer when shaken (let go and the files land in it), otherwise near the top right.
        // Opened by shortcut: where the user last left it, else near the top right.
        var o = atPointer ? NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height / 2)
                          : (savedOrigin ?? NSPoint(x: vf.maxX - size.width - 24, y: vf.maxY - size.height - 24))
        o.x = min(max(o.x, vf.minX + 8), vf.maxX - size.width - 8)
        o.y = min(max(o.y, vf.minY + 8), vf.maxY - size.height - 8)
        if !visible || atPointer { p.setFrameOrigin(o) }
        p.orderFrontRegardless()
        visible = true
        prune()
    }

    func hide() {
        preview = nil
        panel?.orderOut(nil)
        visible = false
    }

    /// The close button: empty the shelf and put it away.
    func closeAndClear() {
        items = []; selection = []; status = nil; canUndo = false; lastMoves = []
        hide()
    }

    private func makePanel() -> ShelfPanel {
        let p = ShelfPanel(contentRect: NSRect(x: 0, y: 0, width: 300 * uiScale, height: 380 * uiScale),
                           styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isMovableByWindowBackground = true
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: p, queue: .main) { [weak p] _ in
            if let p { Shelf.shared.moved(to: p.frame.origin) }
        }
        let host = NSHostingView(rootView: MainActor.assumeIsolated { ShelfRoot(vm: sharedVM) })
        host.frame = p.contentRect(forFrameRect: p.frame)
        p.contentView = host
        return p
    }

    // MARK: Items

    func add(_ urls: [URL]) {
        var fresh: [ShelfItem] = []
        for u in urls where u.isFileURL {
            let u = u.standardizedFileURL
            if !items.contains(where: { $0.url == u }) && !fresh.contains(where: { $0.url == u }) { fresh.append(ShelfItem(url: u)) }
        }
        guard !fresh.isEmpty else { return }
        items.append(contentsOf: fresh)
        status = nil
        measure(fresh.map(\.url))
    }
    private func measure(_ urls: [URL]) {
        DispatchQueue.global(qos: .userInitiated).async {
            let sizes = urls.map { ($0, Scanner.size($0)) }
            DispatchQueue.main.async {
                for (u, s) in sizes { if let i = self.items.firstIndex(where: { $0.url == u }) { self.items[i].size = s } }
            }
        }
    }
    /// Drop items whose file is gone (moved away by a drag out, deleted elsewhere).
    /// Files dragged out of the shelf, with a bookmark that follows a file moved on the same volume, so after the drop
    /// the shelf knows where Finder put them and can offer Undo. (A Swift URL cannot hold a file reference URL: it turns
    /// back into the old path, checked 06/11/2026; a bookmark resolves to the new path.)
    private var dragRefs: [(from: URL, bookmark: Data)] = []
    func dragStarted(_ urls: [URL]) {
        dragRefs = urls.compactMap { u in (try? u.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)).map { (u, $0) } }
    }
    func dragEnded() {
        let fm = FileManager.default
        var moves: [(from: URL, to: URL)] = []
        for d in dragRefs where !fm.fileExists(atPath: d.from.path) {
            // Still the same file (same volume): the reference resolves to its new path. Copied to another drive: the original
            // stays, nothing to undo. Gone with no new path (dropped into an app that deleted it): nothing to undo either.
            var stale = false
            if let now = try? URL(resolvingBookmarkData: d.bookmark, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale),
               now.standardizedFileURL != d.from.standardizedFileURL, fm.fileExists(atPath: now.path) {
                moves.append((d.from, now))
            }
        }
        dragRefs = []
        prune()
        guard !moves.isEmpty else { return }
        lastMoves = moves; lastTrashed = []; lastSession = nil; canUndo = true
        let dirs = Set(moves.map { $0.to.deletingLastPathComponent() })
        let place = dirs.count == 1 ? dirs.first!.lastPathComponent : t("\(dirs.count) places", "\(dirs.count) nơi")
        MainActor.assumeIsolated { sharedVM.log(t("Mintdrop: dragged \(moves.count) items to \(place).", "Mintdrop: đã kéo \(moves.count) mục sang \(place).")) }
        status = t("Moved \(moves.count) to \(place).", "Đã chuyển \(moves.count) mục sang \(place).")
    }
    func prune() {
        let before = items.count
        items.removeAll { !FileManager.default.fileExists(atPath: $0.url.path) }
        selection = selection.filter { id in items.contains { $0.id == id } }
        if items.count != before && items.isEmpty { status = nil }
    }
    func remove(_ item: ShelfItem) { items.removeAll { $0 == item }; selection.remove(item.id) }
    func removeSelected() { items.removeAll { selection.contains($0.id) }; selection = [] }
    func selectAll() { selection = Set(items.map(\.id)) }

    /// Finder-style: click selects one, Command-click adds or removes one, Shift-click selects the range from the last clicked file.
    func click(_ item: ShelfItem, command: Bool, shift: Bool) {
        if shift, let a = anchor, let ai = items.firstIndex(where: { $0.id == a }), let bi = items.firstIndex(of: item) {
            let range = Set(items[min(ai, bi)...max(ai, bi)].map(\.id))
            selection = command ? selection.union(range) : range
        } else if command {
            if selection.contains(item.id) { selection.remove(item.id) } else { selection.insert(item.id) }
            anchor = item.id
        } else {
            selection = [item.id]; anchor = item.id
        }
        if preview != nil { preview = item.url }
    }
    /// Drag on the empty part of the list: a box selects every row it touches (added to the selection with Command held).
    func marqueeChanged(from a: CGPoint, to b: CGPoint) {
        if marquee == nil { marqueeBase = NSEvent.modifierFlags.contains(.command) ? selection : [] }
        let r = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
        marquee = r
        let hit = Set(rowFrames.filter { $0.value.intersects(r) }.map(\.key))
        selection = marqueeBase.union(hit)
    }
    func marqueeEnded() { marquee = nil; marqueeBase = [] }
    /// Space: show or hide the preview of the selected file (the same Quick Look window Finder uses).
    func togglePreview() {
        if preview != nil { preview = nil; return }
        preview = items.first { selection.contains($0.id) }?.url ?? items.first?.url
    }

    /// Selected files, or all of them when nothing is selected.
    var targets: [ShelfItem] { selection.isEmpty ? items : items.filter { selection.contains($0.id) } }
    var totalSize: Int64 { items.compactMap(\.size).reduce(0, +) }
    var measuring: Bool { items.contains { $0.size == nil } }

    // MARK: Actions

    func trash() {
        let list = targets
        guard !list.isEmpty else { return }
        var sizes: [URL: Int64] = [:]
        for i in list { if let s = i.size { sizes[i.url] = s } }
        let urls = list.map(\.url)
        let (ok, fail, okSet, err) = MainActor.assumeIsolated { () -> (Int, Int, Set<URL>, String) in
            let r = sharedVM.trash(urls, label: "Mintdrop", sizes: sizes)
            if r.0 > 0 {
                let freed = list.filter { sharedVM.lastOK.contains($0.url) }.compactMap(\.size).reduce(0, +)
                sharedVM.log(t("Mintdrop: moved \(r.0) items (\(fmt(freed))) to the Trash.", "Mintdrop: đã chuyển \(r.0) mục (\(fmt(freed))) vào Thùng rác."))
            }
            sharedVM.refreshTrash(); sharedVM.refreshDisk()
            return (r.0, r.1, sharedVM.lastOK, sharedVM.lastErr)
        }
        lastSession = MainActor.assumeIsolated { sharedVM.undoable?.date }
        let freed = list.filter { okSet.contains($0.url) }.compactMap(\.size).reduce(0, +)
        items.removeAll { okSet.contains($0.url) }
        selection = []
        lastTrashed = Array(okSet); lastMoves = []
        canUndo = ok > 0
        status = ok > 0
            ? t("Moved \(ok) to the Trash, \(fmt(freed)).", "Đã chuyển \(ok) mục vào Thùng rác, \(fmt(freed)).")
              + (fail > 0 ? t(" \(fail) skipped: \(err).", " Bỏ qua \(fail) mục: \(err).") : "")
            : t("Nothing moved: \(err).", "Không chuyển được: \(err).")
    }

    func undo() {
        if !lastMoves.isEmpty { undoMove(); return }
        let current = MainActor.assumeIsolated { sharedVM.undoable?.date }
        guard let lastSession, current == lastSession else {
            // Another clean (or emptying the Trash) has replaced the shelf's session: Undo here would put back something else.
            canUndo = false; lastTrashed = []
            status = t("A later clean replaced this one. Put files back from the Trash in Finder.", "Một lần dọn khác đã thay lần này. Lấy lại file từ Thùng rác trong Finder.")
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        MainActor.assumeIsolated { sharedVM.undoLast() }
        let back = lastTrashed.filter { FileManager.default.fileExists(atPath: $0.path) }
        if !back.isEmpty {
            add(back)
            canUndo = false; lastTrashed = []
            status = t("Put back \(back.count).", "Đã trả lại \(back.count) mục.")
        }
    }

    func moveToFolder() {
        let list = targets
        guard !list.isEmpty else { return }
        NSApp.activate(ignoringOtherApps: true)
        let op = NSOpenPanel()
        op.canChooseDirectories = true; op.canChooseFiles = false; op.canCreateDirectories = true
        op.allowsMultipleSelection = false
        op.prompt = t("Move here", "Dời vào đây")
        op.message = t("Move \(list.count) item(s) from the shelf into this folder", "Dời \(list.count) mục trên kệ vào thư mục này")
        guard op.runModal() == .OK, let dir = op.url else { return }
        var ok = 0, fail = 0
        var firstErr = ""
        var moves: [(from: URL, to: URL)] = []
        for item in list {
            if item.url.deletingLastPathComponent().standardizedFileURL == dir.standardizedFileURL { continue }
            let dest = Self.unique(dir.appendingPathComponent(item.url.lastPathComponent))
            do {
                try FileManager.default.moveItem(at: item.url, to: dest)
                ok += 1; moves.append((item.url, dest))
                if let i = items.firstIndex(of: item) { items[i].url = dest }
            } catch {
                fail += 1
                if firstErr.isEmpty { firstErr = (error as NSError).localizedDescription }
            }
        }
        selection = []
        lastMoves = moves; lastTrashed = []; lastSession = nil
        canUndo = ok > 0
        if ok > 0 { MainActor.assumeIsolated { sharedVM.log(t("Mintdrop: moved \(ok) items to \(dir.path).", "Mintdrop: đã dời \(ok) mục vào \(dir.path).")) } }
        status = t("Moved \(ok) to \(dir.lastPathComponent).", "Đã dời \(ok) mục vào \(dir.lastPathComponent).")
            + (fail > 0 ? t(" \(fail) failed: \(firstErr)", " Lỗi \(fail) mục: \(firstErr)") : "")
    }

    /// Undo for "Move to…": each file goes back to where it was, never over a file that now sits there.
    private func undoMove() {
        let fm = FileManager.default
        var ok = 0, skipped = 0
        for m in lastMoves.reversed() {
            guard fm.fileExists(atPath: m.to.path), !fm.fileExists(atPath: m.from.path),
                  fm.fileExists(atPath: m.from.deletingLastPathComponent().path) else { skipped += 1; continue }
            do {
                try fm.moveItem(at: m.to, to: m.from)
                ok += 1
                if let i = items.firstIndex(where: { $0.url == m.to }) { items[i].url = m.from } else { add([m.from]) }   // dragged out: back on the shelf too
            } catch { skipped += 1 }
        }
        lastMoves = []; canUndo = false
        if ok > 0 { MainActor.assumeIsolated { sharedVM.log(t("Mintdrop: moved \(ok) items back.", "Mintdrop: đã dời lại \(ok) mục về chỗ cũ.")) } }
        status = t("Moved \(ok) back to where they were.", "Đã dời lại \(ok) mục về chỗ cũ.")
            + (skipped > 0 ? t(" \(skipped) could not go back (moved again, or a file with that name is there now).",
                               " \(skipped) mục không trả được (đã bị dời tiếp, hoặc chỗ cũ đã có file cùng tên).") : "")
    }

    /// "Report.pdf" -> "Report 2.pdf" when the name is taken.
    static func unique(_ u: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: u.path) else { return u }
        let base = u.deletingPathExtension().lastPathComponent, ext = u.pathExtension, dir = u.deletingLastPathComponent()
        var n = 2
        while true {
            let c = dir.appendingPathComponent(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)")
            if !fm.fileExists(atPath: c.path) { return c }
            n += 1
        }
    }
}

/// A floating panel that can take keys (Space for preview) without pulling the whole app to the front.
final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    /// ⌘W hides the shelf like closing a window; the files stay on it for next time (✕ empties it).
    override func performKeyEquivalent(with e: NSEvent) -> Bool {
        if e.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command, e.charactersIgnoringModifiers?.lowercased() == "w" {
            Shelf.shared.hide(); return true
        }
        return super.performKeyEquivalent(with: e)
    }
    override func keyDown(with e: NSEvent) {
        let s = Shelf.shared
        switch e.keyCode {
        case 49: s.togglePreview()                                                      // Space
        case 53: if s.preview != nil { s.preview = nil } else { s.selection = [] }      // Esc
        case 51 where e.modifierFlags.contains(.command): s.removeSelected()           // ⌘⌫: off the shelf (not the Trash)
        case 0 where e.modifierFlags.contains(.command): s.selectAll()                 // ⌘A
        default: super.keyDown(with: e)
        }
    }
}
