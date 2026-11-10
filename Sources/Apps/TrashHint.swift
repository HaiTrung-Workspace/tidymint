import AppKit
import SwiftUI
import UserNotifications

/// What an app that was just dragged to the Trash left behind in Library.
struct TrashHintInfo: Identifiable {
    var id: String { bundleID }
    let name: String
    let bundleID: String
    var items: [CleanItem]
}

/// Optional and off by default: while Tidymint is running, notice an app that lands in the Trash (dragged there in
/// Finder) and offer the files it left in Library. Whole-bundle-id matches only, nothing ticked, nothing moved until
/// the user picks. Reading the Trash needs Full Disk Access; without it the watcher does not start.
enum TrashHint {
    static var on: Bool { UserDefaults.standard.bool(forKey: "trashHint") }
    private static var source: DispatchSourceFileSystemObject?
    private static var known = Set<String>()
    private static var quietUntil = Date.distantPast
    /// Bundle ids of apps Tidymint itself is uninstalling right now (until the date): never news to the user.
    private static var mine: [String: Date] = [:]
    private static let q = DispatchQueue(label: "tidymint.trashhint")

    /// Start or stop to match the setting. Safe to call again (after Full Disk Access is granted, say).
    static func apply() { let want = on; q.async { want ? start() : stop() } }

    /// Tidymint's own moves (Uninstaller, cleaning) are not news to the user: stay quiet for a moment.
    static func quiet() { q.async { quietUntil = Date().addingTimeInterval(15) } }
    /// The Uninstaller is about to move this app. By id, not by the clock: a password prompt can take any time.
    static func uninstalling(_ bundleID: String) { q.async { mine[bundleID] = Date().addingTimeInterval(900) } }

    private static func start() {
        guard source == nil else { return }
        let fd = open(Scanner.trashURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        known = trashedApps()
        let s = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .delete, .rename], queue: q)
        s.setEventHandler {
            // The Trash folder itself was removed or renamed (macOS makes a new one later): watch the new one.
            if !s.data.intersection([.delete, .rename]).isEmpty { stop(); q.asyncAfter(deadline: .now() + 5) { if on { start() } }; return }
            changed()
        }
        s.setCancelHandler { close(fd) }
        s.resume(); source = s
    }
    private static func stop() { source?.cancel(); source = nil; known = [] }

    static func trashedApps() -> Set<String> {
        Set(Scanner.children(Scanner.trashURL).filter { $0.pathExtension == "app" }.map(\.path))
    }
    /// The list is compared right away (an app put back and trashed again is new again); the look at each new app waits
    /// a few seconds, because an updater trashes the old copy first and puts the new one in place right after.
    private static func changed() {
        guard source != nil else { return }
        let now = trashedApps(), fresh = now.subtracting(known)
        known = now
        if Date() < quietUntil || fresh.isEmpty { return }
        q.asyncAfter(deadline: .now() + 4) {
            guard source != nil else { return }
            for p in fresh.sorted() where FileManager.default.fileExists(atPath: p) {
                if let id = plistID(URL(fileURLWithPath: p))?.id, let until = mine[id], until > Date() { continue }
                guard let h = inspect(URL(fileURLWithPath: p)) else { continue }
                DispatchQueue.main.async { sharedVM.showTrashHint(h) }
            }
        }
    }

    /// Bundle id and name read straight from Info.plist (Bundle(url:) caches, and the app has just moved).
    static func plistID(_ bundle: URL) -> (id: String, name: String)? {
        guard let d = NSDictionary(contentsOf: bundle.appendingPathComponent("Contents/Info.plist")),
              let id = d["CFBundleIdentifier"] as? String, !id.isEmpty else { return nil }
        let name = (d["CFBundleDisplayName"] as? String) ?? (d["CFBundleName"] as? String) ?? ""
        return (id, name.isEmpty ? bundle.deletingPathExtension().lastPathComponent : name)
    }
    /// Bundle ids of every app still in the two Applications folders (one folder level down as well).
    static func installedIDs() -> Set<String> {
        var out = Set<String>()
        for r in [URL(fileURLWithPath: "/Applications"), URL(fileURLWithPath: "/System/Applications"), Scanner.home.appendingPathComponent("Applications")] {
            for c in Scanner.children(r) {
                if c.pathExtension == "app" { if let i = plistID(c)?.id { out.insert(i) } }
                else { for a in Scanner.children(c) where a.pathExtension == "app" { if let i = plistID(a)?.id { out.insert(i) } } }
            }
        }
        return out
    }

    /// Where a copy of this app still lives outside the Trash (an update, a second copy, Put Back), or nil. The
    /// Applications folders are read directly, then LaunchServices is asked for copies anywhere else.
    static func stillInstalled(_ id: String) -> String? {
        if installedIDs().contains(id) { return "Applications" }
        for u in NSWorkspace.shared.urlsForApplications(withBundleIdentifier: id)
        where !u.path.contains("/.Trash") && FileManager.default.fileExists(atPath: u.path) { return u.path }
        return nil
    }
    /// Whether a copy of this app sits in the Trash right now.
    static func inTrash(_ id: String) -> Bool { trashedApps().contains { plistID(URL(fileURLWithPath: $0))?.id == id } }

    /// nil when there is nothing to say: Apple's or Tidymint's own app, the app is still installed (an update or a
    /// second copy), it is running, or it left nothing behind.
    static func inspect(_ app: URL) -> TrashHintInfo? { verdict(app).info }
    static func verdict(_ app: URL) -> (info: TrashHintInfo?, why: String) {
        // The name comes from Info.plist: Finder renames a clash in the Trash ("App 12.03.45.app").
        guard let (id, name) = plistID(app) else { return (nil, "no bundle id") }
        if Apps.isOwn(id) { return (nil, "Tidymint itself") }
        if id.hasPrefix("com.apple.") { return (nil, "Apple app") }
        // An app the user protected by keyword has no Uninstall button, so its data is not offered here either.
        if Prefs.protectedKeywords.contains(where: { !$0.isEmpty && (id.localizedCaseInsensitiveContains($0) || name.localizedCaseInsensitiveContains($0)) }) { return (nil, "protected by keyword") }
        if let where_ = stillInstalled(id) { return (nil, "still installed (\(where_))") }
        if !NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty { return (nil, "still running") }
        let e = AppEntry(url: app, name: name, bundleID: id, size: 0, lastUsed: nil)
        let items = Apps.related(e, strict: true)
        if items.isEmpty { return (nil, "left nothing behind") }
        return (TrashHintInfo(name: name, bundleID: id, items: items), "hint: \(items.count) items")
    }

    /// `--trashhint-probe <out.txt>`: write what the Trash watcher can see, then quit, before anything else in the app
    /// starts (test helper; run with `open` so macOS judges this app's own permissions, not the terminal's).
    static func earlyProbe() {
        let a = CommandLine.arguments
        guard isDevBuild, let i = a.firstIndex(of: "--trashhint-probe"), i + 1 < a.count else { return }
        try? probe().write(toFile: a[i + 1], atomically: true, encoding: .utf8); exit(0)
    }
    /// A click on the notification: show the Uninstaller page, opening the main window again when it was closed.
    /// The cards live in memory only, so after a restart the card is built again from the Trash; when the app is no
    /// longer there (put back, Trash emptied) the page says so instead of opening empty.
    @MainActor static func openPage(_ bundleID: String = "") {
        sharedVM.page = .apps; sharedVM.appsTab = 0
        NSApp.activate(ignoringOtherApps: true)
        if let w = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain && !($0 is NSPanel) }) { w.makeKeyAndOrderFront(nil) }
        else { NSWorkspace.shared.open(Bundle.main.bundleURL) }   // the same "reopen" a Dock click sends
        guard !bundleID.isEmpty, !sharedVM.trashHints.contains(where: { $0.id == bundleID }) else { return }
        // Turned off since the notification was sent: open the page, offer nothing, and clear the old notification.
        guard on else { forget(bundleID); return }
        q.async {
            let app = trashedApps().sorted().map { URL(fileURLWithPath: $0) }.last { plistID($0)?.id == bundleID }
            let v = app.map { verdict($0) }
            DispatchQueue.main.async {
                if let h = v?.info { sharedVM.showTrashHint(h, notify: false); return }
                // Its own line on the page: the Uninstaller clears its usual message when it scans on opening.
                sharedVM.trashHintNote = app == nil
                    ? t("That app is no longer in the Trash, so there is nothing to suggest.", "App đó không còn trong Thùng rác nên không còn gì để gợi ý.")
                    : t("Nothing of that app is left in Library.", "Không còn gì của app đó trong Library.")
                forget(bundleID)
            }
        }
    }
    /// The notification of a card that is gone (cleaned, dismissed) leaves Notification Center too.
    static func forgetAll() {
        let c = UNUserNotificationCenter.current()
        c.getDeliveredNotifications { list in c.removeDeliveredNotifications(withIdentifiers: list.map(\.request.identifier).filter { $0.hasPrefix("trashhint") }) }
    }
    static func forget(_ bundleID: String) { UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["trashhint-" + bundleID]) }

    /// Test helper text: what the watcher can see and what it would say for each app in the Trash.
    static func probe() -> String {
        let fd = open(Scanner.trashURL.path, O_EVTONLY)
        var out = ["open(O_EVTONLY) on Trash: \(fd >= 0 ? "ok" : "refused, errno \(errno)")"]
        if fd >= 0 { close(fd) }
        let list = try? FileManager.default.contentsOfDirectory(atPath: Scanner.trashURL.path)
        out.append("list Trash: \(list.map { "\($0.count) entries" } ?? "refused")")
        for p in trashedApps().sorted() {
            let v = verdict(URL(fileURLWithPath: p))
            out.append("\(URL(fileURLWithPath: p).lastPathComponent): \(v.why)")
            for it in v.info?.items ?? [] { out.append("   \(it.selected ? "[x]" : "[ ]") \(it.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")) \(it.size)") }
        }
        return out.joined(separator: "\n")
    }
}

/// Cards on the Uninstaller page after apps were dragged to the Trash (one per app).
struct TrashHintCard: View {
    @ObservedObject var vm: VM
    var body: some View {
        if !vm.trashHintNote.isEmpty && vm.trashHints.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "trash").foregroundStyle(Theme.accent)
                Text(vm.trashHintNote).font(.system(size: fs(12))).foregroundColor(Theme.sub)
                Spacer()
                GhostButton(title: t("OK", "Đã hiểu"), action: { vm.trashHintNote = "" }, compact: true)
            }
            .padding(14).background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .padding(.horizontal, 24).padding(.bottom, 10)
        }
        ForEach(vm.trashHints) { h in card(h) }
    }
    func card(_ h: TrashHintInfo) -> some View {
        let sel = h.items.filter(\.selected)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "trash").foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("\(h.name) is in the Trash, and it left \(h.items.count) items in Library",
                           "\(h.name) đã vào Thùng rác, còn \(h.items.count) mục của app này trong Library"))
                        .font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                    Text(t("Nothing is ticked: pick what to remove. Keep them if you may install the app again.",
                           "Chưa tick mục nào: chọn mục bạn muốn dọn. Giữ lại nếu có thể cài lại app."))
                        .font(.system(size: fs(12))).foregroundColor(Theme.sub).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            // Short lists and the first three rows are shown whole (a row cut in half reads as a glitch); the full
            // list opens on request and scrolls.
            let open = vm.trashHintOpen.contains(h.id) || h.items.count <= 4
            let rows = VStack(spacing: 2) {
                ForEach(open ? h.items : Array(h.items.prefix(3))) { it in
                    ItemRow(item: Binding(get: { vm.trashHints.first { $0.id == h.id }?.items.first { $0.id == it.id } ?? it },
                                          set: { v in
                        if let a = vm.trashHints.firstIndex(where: { $0.id == h.id }), let j = vm.trashHints[a].items.firstIndex(where: { $0.id == it.id }) { vm.trashHints[a].items[j] = v }
                    }), vm: vm)
                }
            }
            if open && h.items.count > 4 { ScrollView { rows }.frame(maxHeight: 300 * uiScale) } else { rows }
            if h.items.count > 4 {
                TextLink(open ? t("Show fewer", "Thu gọn") : t("Show all \(h.items.count) items", "Hiện cả \(h.items.count) mục")) {
                    if open { vm.trashHintOpen.remove(h.id) } else { vm.trashHintOpen.insert(h.id) }
                }.padding(.leading, 12)
            }
            HStack {
                Text(selLabel(sel.count, sel.reduce(0) { $0 + $1.size })).foregroundColor(Theme.text).font(.system(size: fs(12), weight: .semibold))
                Spacer()
                GhostButton(title: t("Dismiss", "Bỏ qua"), action: { vm.trashHints.removeAll { $0.id == h.id }; TrashHint.forget(h.id) }, compact: true)
                PrimaryButton(title: t("Move to Trash", "Chuyển vào Thùng rác"), action: { vm.cleanTrashHint(h.id) }, disabled: sel.isEmpty)
            }
        }
        .padding(14).background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .padding(.horizontal, 24).padding(.bottom, 10)
    }
}
