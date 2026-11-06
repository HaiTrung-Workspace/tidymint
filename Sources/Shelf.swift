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

// MARK: - Dragging files out of the shelf

/// AppKit layer that starts a real multi-file drag (SwiftUI's onDrag carries one item only).
final class ShelfDragNSView: NSView, NSDraggingSource {
    var urls: () -> [URL] = { [] }
    var onClick: (NSEvent) -> Void = { _ in }
    var onDouble: () -> Void = {}
    var isSelected: () -> Bool = { false }
    private var down: NSEvent?
    /// Click on a row that is already selected: applied on mouse up only if no drag started (Finder behaviour), so
    /// Command-drag or a plain drag on any selected row carries the whole selection instead of first unselecting it.
    private var pending: NSEvent?
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with e: NSEvent) {
        down = e
        window?.makeKey()
        pending = nil
        if e.clickCount == 2 { onDouble() } else if isSelected() { pending = e } else { onClick(e) }
    }
    override func mouseUp(with e: NSEvent) {
        down = nil
        if let p = pending { pending = nil; onClick(p) }
    }
    override func mouseDragged(with e: NSEvent) {
        guard let d = down else { return }
        down = nil; pending = nil
        let list = urls()
        guard !list.isEmpty else { return }
        let pt = convert(d.locationInWindow, from: nil)
        let items: [NSDraggingItem] = list.enumerated().map { i, u in
            let it = NSDraggingItem(pasteboardWriter: u as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: u.path)
            icon.size = NSSize(width: 40, height: 40)
            let k = CGFloat(min(i, 4)) * 4
            it.setDraggingFrame(NSRect(x: pt.x - 20 + k, y: pt.y - 20 - k, width: 40, height: 40), contents: i < 5 ? icon : nil)
            return it
        }
        Shelf.shared.dragStarted(list)
        beginDraggingSession(with: items, event: d, source: self)
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .move, .generic, .link] : []
    }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { Shelf.shared.dragEnded() }
    }
}

struct ShelfDragArea: NSViewRepresentable {
    let urls: () -> [URL]
    var onClick: (NSEvent) -> Void = { _ in }
    var onDouble: () -> Void = {}
    var isSelected: () -> Bool = { false }
    func makeNSView(context: Context) -> ShelfDragNSView { let v = ShelfDragNSView(); updateNSView(v, context: context); return v }
    func updateNSView(_ v: ShelfDragNSView, context: Context) { v.urls = urls; v.onClick = onClick; v.onDouble = onDouble; v.isSelected = isSelected }
}

/// Grab area that moves the shelf (SwiftUI content does not let the window be dragged by its background).
final class ShelfMoveNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with e: NSEvent) { window?.performDrag(with: e) }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
}
struct ShelfMoveArea: NSViewRepresentable {
    func makeNSView(context: Context) -> ShelfMoveNSView { ShelfMoveNSView() }
    func updateNSView(_ v: ShelfMoveNSView, context: Context) {}
}

// MARK: - Shelf panel content

struct ShelfRowFrames: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) { value.merge(nextValue()) { $1 } }
}

/// Rebuilds the shelf when the theme or text size changes, like the main window (Root.swift), since Theme values are read, not observed.
struct ShelfRoot: View {
    @ObservedObject var vm: VM
    var body: some View {
        ShelfView().id(vm.theme + vm.textSize)
            .preferredColorScheme(Theme.p.light ? .light : .dark)
    }
}

struct ShelfView: View {
    @ObservedObject private var s = Shelf.shared
    var body: some View {
        VStack(spacing: 0) {
            header
            if s.items.isEmpty { empty } else { list; footer }
        }
        .frame(width: 300 * uiScale, height: 380 * uiScale)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.bg))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(s.targeted ? Theme.brandMint : Theme.ink.opacity(0.18), lineWidth: s.targeted ? 2 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onDrop(of: [UTType.fileURL], isTargeted: Binding(get: { s.targeted }, set: { s.targeted = $0 })) { providers in
            for p in providers {
                p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let u: URL? = (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) } ?? (item as? URL)
                    if let u { DispatchQueue.main.async { Shelf.shared.add([u]) } }
                }
            }
            return true
        }
        .quickLookPreview(Binding(get: { s.preview }, set: { s.preview = $0 }), in: s.items.map(\.url))
    }

    var header: some View {
        HStack(spacing: 8) {
            // The whole title area is a grab handle: drag it to move the shelf.
            HStack(spacing: 8) {
                Image(systemName: "tray.and.arrow.down").foregroundColor(Theme.brandMint).font(.system(size: fs(13)))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Mintdrop").font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                    if !s.items.isEmpty {
                        Text(t("\(s.items.count) items · \(fmt(s.totalSize))", "\(s.items.count) mục · \(fmt(s.totalSize))") + (s.measuring ? "…" : ""))
                            .font(.system(size: fs(11))).foregroundColor(Theme.sub)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 14).padding(.vertical, 10)
            .contentShape(Rectangle())
            .overlay(ShelfMoveArea())
            Button { s.closeAndClear() } label: {
                Image(systemName: "xmark").font(.system(size: fs(10), weight: .bold)).foregroundColor(Theme.sub)
                    .frame(width: 22, height: 22).background(Circle().fill(Theme.ink.opacity(0.08)))
            }.buttonStyle(.plain).tip(t("Empty the shelf and close it", "Xoá hết khỏi kệ và đóng (file không bị xoá)"))
            .padding(.trailing, 14)
        }
        .padding(.top, 2)
    }

    var empty: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "arrow.down.doc").font(.system(size: fs(28))).foregroundColor(s.targeted ? Theme.brandMint : Theme.sub)
            Text(t("Drop files here", "Thả file vào đây")).font(.system(size: fs(13), weight: .medium)).foregroundColor(Theme.text)
            Text(t("Gather files, handle them in one go.", "Gom file, xử lý một lần."))
                .multilineTextAlignment(.center).font(.system(size: fs(11))).foregroundColor(Theme.sub).padding(.horizontal, 22)
            Spacer()
            // After the last file goes to the Trash the list is empty: keep the result and Undo visible.
            statusLine.padding(.horizontal, 24).padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            .foregroundColor(s.targeted ? Theme.brandMint : Theme.ink.opacity(0.2)).padding(12))
    }

    var list: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(s.items) { item in row(item) }
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                // The empty space below and beside the rows takes a click (clear the selection) or a selection box.
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .top)
                .background(
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture { s.selection = [] }
                        .gesture(DragGesture(minimumDistance: 3, coordinateSpace: .named("shelfList"))
                            .onChanged { v in s.marqueeChanged(from: v.startLocation, to: v.location) }
                            .onEnded { _ in s.marqueeEnded() })
                )
                .overlay(alignment: .topLeading) {
                    if let r = s.marquee {
                        RoundedRectangle(cornerRadius: 3).fill(Theme.brandMint.opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.brandMint.opacity(0.7), lineWidth: 1))
                            .frame(width: r.width, height: r.height).offset(x: r.minX, y: r.minY)
                            .allowsHitTesting(false)
                    }
                }
                .coordinateSpace(name: "shelfList")
                .onPreferenceChange(ShelfRowFrames.self) { s.rowFrames = $0 }
            }
        }
    }

    func row(_ item: ShelfItem) -> some View {
        let sel = s.selection.contains(item.id)
        return HStack(spacing: 8) {
            // Photos, videos and PDFs show a real thumbnail (same cache as the rest of the app), other files their Finder icon.
            FileThumb(url: item.url, side: 26).id(item.url)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                    .font(.system(size: fs(12))).foregroundColor(Theme.text)
                Text(item.size.map(fmt) ?? "…").font(.system(size: fs(10))).foregroundColor(Theme.sub)
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(sel ? Theme.brandMint.opacity(0.18) : Color.clear))
        .background(GeometryReader { g in Color.clear.preference(key: ShelfRowFrames.self, value: [item.id: g.frame(in: .named("shelfList"))]) })
        .overlay(ShelfDragArea(urls: { s.selection.contains(item.id) ? s.targets.map(\.url) : [item.url] },
                               onClick: { e in s.click(item, command: e.modifierFlags.contains(.command), shift: e.modifierFlags.contains(.shift)) },
                               onDouble: { NSWorkspace.shared.open(item.url) },
                               isSelected: { s.selection.contains(item.id) }))
        .overlay(alignment: .trailing) {
            Button { s.remove(item) } label: {
                Image(systemName: "minus.circle").font(.system(size: fs(12))).foregroundColor(Theme.sub)
            }.buttonStyle(.plain).padding(.trailing, 8).tip(t("Take off the shelf", "Bỏ khỏi kệ (file không bị xoá)")).accessibilityLabel(t("Take off the shelf", "Bỏ khỏi kệ"))
        }
    }

    var footer: some View {
        let n = s.targets.count
        return VStack(spacing: 8) {
            // Drag handle for the whole group (or the selected ones).
            HStack(spacing: 8) {
                Image(systemName: "hand.draw").font(.system(size: fs(12)))
                Text(s.selection.isEmpty ? t("Drag all \(n) out", "Kéo cả \(n) mục đi") : t("Drag \(n) selected", "Kéo \(n) mục đã chọn"))
                    .font(.system(size: fs(12), weight: .medium))
            }
            .foregroundColor(Theme.brandMint)
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.brandMint.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .overlay(ShelfDragArea(urls: { s.targets.map(\.url) }))
            HStack(spacing: 8) {
                GhostButton(title: t("Move to…", "Dời vào…"), action: { s.moveToFolder() }, compact: true)
                Spacer()
                GhostButton(title: t("Move to Trash", "Chuyển vào Thùng rác"), action: { s.trash() }, compact: true)
            }
            statusLine
        }
        .padding(.horizontal, 12).padding(.bottom, 12).padding(.top, 6)
    }

    @ViewBuilder var statusLine: some View {
        if let st = s.status {
            HStack(spacing: 6) {
                Text(st).font(.system(size: fs(11))).foregroundColor(Theme.sub).lineLimit(2)
                if s.canUndo { TextLink(t("Undo", "Hoàn tác"), size: fs(11), weight: .semibold) { s.undo() } }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Sidebar page, nav badge, Settings switch

struct ShelfNavState: View {
    let selected: Bool
    @ObservedObject private var s = Shelf.shared
    var body: some View {
        if !s.enabled {
            Text(t("Off", "Tắt")).font(.system(size: fs(10), weight: .semibold))
                .foregroundColor(selected ? .white : Theme.sub)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Capsule().stroke(selected ? Color.white.opacity(0.7) : Theme.ink.opacity(0.3), lineWidth: 1))
        } else if !s.items.isEmpty {
            Text("\(s.items.count)").font(.system(size: fs(10), weight: .bold))
                .foregroundColor(selected ? Theme.accentSolid : .white)
                .frame(minWidth: 16, minHeight: 16)
                .background(Capsule().fill(selected ? Color.white : Theme.accentSolid))
        }
    }
}

struct ShelfPageView: View {
    @ObservedObject private var s = Shelf.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Mintdrop: drop shelf", "Mintdrop: kệ thả file")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text)
                    Text(t("Gather files from many places, then handle them in one go.",
                           "Gom file từ nhiều nơi, xử lý một lần."))
                        .foregroundColor(Theme.sub).font(.system(size: fs(12)))
                }
                Spacer(minLength: 16)
                if s.enabled { GhostButton(title: t("Turn off", "Tắt Mintdrop"), action: { s.enabled = false }, compact: true) }
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !s.enabled { offCard } else { onContent }
                    section(t("How to use", "Cách dùng"))
                    howTo
                    TextLink(t("Full guide: move or copy, selecting, Undo →", "Hướng dẫn đầy đủ: chuyển hay chép, chọn nhiều, Hoàn tác →"),
                             url: URL(string: appLang == "vi" ? "https://tidymint.app/vi/mintdrop-ke-tha-file-mac/" : "https://tidymint.app/mintdrop-drop-shelf-mac/")!)
                }.frame(maxWidth: 760 * uiScale, alignment: .leading)
                .padding(.horizontal, 24).padding(.bottom, 24).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear { s.refreshRivals() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in s.refreshRivals() }
    }

    var offCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "tray.and.arrow.down").font(.system(size: fs(20))).foregroundColor(Theme.brandMint)
                Text(t("Mintdrop is off", "Mintdrop đang tắt")).font(.system(size: fs(14), weight: .semibold)).foregroundColor(Theme.text)
            }
            Text(t("No permission needed. Files are not copied or uploaded.",
                   "Không cần cấp quyền. Không chép, không gửi file đi đâu."))
                .foregroundColor(Theme.sub).font(.system(size: fs(12))).fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: t("Turn on", "Bật Mintdrop"), action: { s.enabled = true }, compact: true)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
    }

    @ViewBuilder var onContent: some View {
        ForEach(s.rivalsRunning, id: \.self) { id in
            let name = Shelf.rivalIDs[id] ?? id
            VStack(alignment: .leading, spacing: 6) {
                SettingsBox {
                    HStack {
                        HStack(spacing: 6) {
                            Circle().fill(Theme.warn).frame(width: 7, height: 7)
                            Text(t("\(name) is running", "\(name) đang chạy")).foregroundColor(Theme.text).font(.system(size: fs(13)))
                        }
                        Spacer()
                        PrimaryButton(title: t("Quit \(name)", "Thoát \(name)"), action: { s.quitRival(id) }, compact: true)
                    }.settingFlat()
                }
                SettingNote(t("Shaking may open both shelves. Quit \(name) to avoid conflicts.",
                              "Lắc chuột có thể mở cả hai kệ. Thoát \(name) để tránh xung đột."))
            }
        }
        SettingsBox {
            HStack {
                Text(t("Current shelf", "Kệ hiện tại")).foregroundColor(Theme.text).font(.system(size: fs(13)))
                Text(s.items.isEmpty ? t("empty", "đang trống") : t("\(s.items.count) items · \(fmt(s.totalSize))", "\(s.items.count) mục · \(fmt(s.totalSize))"))
                    .foregroundColor(Theme.sub).font(.system(size: fs(12)))
                Spacer()
                PrimaryButton(title: s.visible ? t("Hide shelf", "Ẩn kệ") : t("Open shelf", "Mở kệ"), action: { s.toggle() }, compact: true)
            }.settingFlat()
        }
        section(t("Open the shelf", "Cách mở kệ"))
        SettingsBox {
            HStack {
                Text(t("Shake while dragging", "Lắc chuột khi kéo file")).foregroundColor(Theme.text).font(.system(size: fs(13)))
                Spacer(minLength: 16)
                Toggle("", isOn: $s.shake).toggleStyle(.switch).labelsHidden().controlSize(.mini)
            }.settingFlat()
            HStack {
                HStack(spacing: 8) {
                    Text(t("Shortcut", "Phím tắt")).foregroundColor(Theme.text).font(.system(size: fs(13)))
                    MTKeycap(text: Shelf.key.label, warn: s.useKey && s.keyFailed).tip(Shelf.key.spoken)
                }
                Spacer(minLength: 16)
                Toggle("", isOn: $s.useKey).toggleStyle(.switch).labelsHidden().controlSize(.mini)
            }.settingFlat()
        }
        if s.useKey && s.keyFailed {
            SettingNote(t("Another app uses \(Shelf.key.label). Free it there, or shake to open.",
                          "App khác đang giữ \(Shelf.key.label). Tắt phím ở app kia, hoặc lắc chuột để mở."))
        }
    }

    var howTo: some View {
        VStack(alignment: .leading, spacing: 8) {
            step("1", t("Drag a file and shake, or press \(Shelf.key.label).",
                        "Kéo file rồi lắc chuột, hoặc bấm \(Shelf.key.label)."))
            step("2", t("Drop files in. The shelf shows the total size.",
                        "Thả file vào kệ. Kệ hiện tổng dung lượng."))
            step("3", t("Drag them out, Move to…, or Move to Trash (undoable).",
                        "Kéo ra chỗ khác, Dời vào…, hoặc Chuyển vào Thùng rác (hoàn tác được)."))
            step("4", t("Space: preview. ⌘-click: select several. ⌘W: hide.",
                        "Phím cách: xem trước. ⌘ + bấm: chọn nhiều. ⌘W: ẩn kệ."))
        }
    }
    func step(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(n).font(.system(size: fs(11), weight: .bold)).foregroundColor(Theme.brandMint)
                .frame(width: 20, height: 20).background(Circle().fill(Theme.brandMint.opacity(0.15)))
            Text(text).font(.system(size: fs(12))).foregroundColor(Theme.text).fixedSize(horizontal: false, vertical: true)
        }
    }
    func section(_ title: String) -> some View {
        Text(title).font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text).padding(.top, 6)
    }
}

struct ShelfSettings: View {
    @ObservedObject var groups: OpenGroups
    let open: () -> Void
    @ObservedObject private var s = Shelf.shared
    var body: some View {
        SettingsGroup(id: "shelf", icon: "tray.and.arrow.down", title: t("Mintdrop: drop shelf", "Mintdrop: kệ thả file"),
                      summary: s.enabled ? t("On", "Đang bật") : t("Off", "Đang tắt"), badge: nil, groups: groups) {
            VStack(alignment: .leading, spacing: 6) {
                SettingsBox {
                    HStack {
                        Text(t("Drop shelf", "Kệ thả file")).foregroundColor(Theme.text).font(.system(size: fs(13)))
                        Spacer(minLength: 16)
                        Toggle("", isOn: Binding(get: { s.enabled }, set: { s.enabled = $0 })).toggleStyle(.switch).labelsHidden().controlSize(.mini)
                    }.settingFlat()
                }
                HStack(spacing: 4) {
                    SettingNote(t("Off by default. No permission needed.", "Mặc định tắt. Không cần cấp quyền."))
                    TextLink(t("How to use", "Cách dùng"), size: 11) { open() }
                }
            }
        }
    }
}
