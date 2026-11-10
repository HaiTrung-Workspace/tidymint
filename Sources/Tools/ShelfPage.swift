// Mintdrop: dragging files out, the panel content, the sidebar page and the Settings switch (core in Shelf.swift).
import AppKit
import Carbon
import SwiftUI
import QuickLook
import UniformTypeIdentifiers

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
