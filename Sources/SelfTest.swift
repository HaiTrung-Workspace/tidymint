import AppKit
import UserNotifications

/// Dev build only. `--selftest <what> ... <out.txt>` drives the same code the buttons call, on test files, and writes
/// what happened to a text file, so clean and Undo can be checked without clicking. Start it with `open` so macOS
/// judges this app's own permissions.
@MainActor
enum SelfTest {
    static var lines: [String] = []
    static var out = ""
    static func say(_ s: String) { lines.append(s); try? lines.joined(separator: "\n").write(toFile: out, atomically: true, encoding: .utf8) }
    static func short(_ p: String) -> String { p.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
    static func ms(_ since: Date) -> Int { Int(Date().timeIntervalSince(since) * 1000) }
    static func row(_ it: CleanItem) -> String { "   \(it.selected ? "[x]" : "[ ]") \(short(it.url.path)) \(it.size)\(it.hasDB ? " DB" : "")\(it.nameMatch ? " byname" : "")" }

    static func run(_ a: [String]) {
        guard let last = a.last, a.count >= 2 else { return }
        out = last
        let vm = sharedVM
        switch a[0] {
        case "related":   // related <app path> <out>: what the Uninstaller would list and tick for that app
            let app = URL(fileURLWithPath: a[1])
            guard let (id, name) = TrashHint.plistID(app) else { say("no bundle id"); exit(0) }
            say("\(name) \(id)")
            for it in Apps.related(AppEntry(url: app, name: name, bundleID: id, size: 0, lastUsed: nil)) { say(row(it)) }
            exit(0)
        case "hint":      // hint <seconds> <out>: wait for Trash hints, tick everything, clean, then Undo
            let wait = Double(a[1]) ?? 20
            say("watcher on: \(TrashHint.on)")
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                say("hints: \(vm.trashHints.count)")
                for h in vm.trashHints { say("\(h.name) \(h.bundleID)"); h.items.forEach { say(row($0)) } }
                var moved: [URL] = []
                for h in vm.trashHints {
                    if let i = vm.trashHints.firstIndex(where: { $0.id == h.id }) { for j in vm.trashHints[i].items.indices { vm.trashHints[i].items[j].selected = true } }
                    let urls = h.items.map(\.url)
                    vm.cleanTrashHint(h.id)
                    say("clean \(h.name): \(vm.doneInfo.map { "ok \($0.count) fail \($0.fail)" } ?? "nothing") \(vm.appsMsg) \(vm.lastErr)")
                    for u in urls { say("   after clean \(FileManager.default.fileExists(atPath: u.path) ? "STILL THERE" : "gone") \(short(u.path))") }
                    moved += urls
                    if let s = vm.undoable {
                        let r = Journal.restore(s); vm.undoable = nil; Journal.clear()
                        say("undo: put back \(r.ok), skipped \(r.skipped)")
                        for u in urls { say("   after undo \(FileManager.default.fileExists(atPath: u.path) ? "back" : "MISSING") \(short(u.path))") }
                    } else { say("no undo session") }
                }
                say("hints left: \(vm.trashHints.count)"); say("done"); exit(0)
            }
        case "quiet":     // quiet <app path> <out>: an app Tidymint moved itself must not raise a hint
            let app = URL(fileURLWithPath: a[1])
            say("watcher on: \(TrashHint.on)")
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                TrashHint.quiet()
                // moveItem on purpose (test app only, never a user's file): the point is a move that does not go
                // through VM.trash but still falls inside the quiet period.
                let to = Scanner.trashURL.appendingPathComponent(app.lastPathComponent)
                do { try FileManager.default.moveItem(at: app, to: to); say("moved into the Trash") } catch { say("move failed: \(error.localizedDescription)") }
                try? await Task.sleep(nanoseconds: 9_000_000_000)
                say("hints after a quiet move: \(vm.trashHints.count)")
                try? FileManager.default.moveItem(at: to, to: app)
                say("done"); exit(0)
            }
        case "openhint":  // openhint <out>: what a click on the hint notification does, with the main window closed first
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                func vis() -> Int { NSApp.windows.filter { $0.isVisible && $0.canBecomeMain && !($0 is NSPanel) }.count }
                say("windows before: \(vis())")
                for w in NSApp.windows where w.isVisible && w.canBecomeMain && !(w is NSPanel) { w.close() }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                say("windows after closing: \(vis())"); vm.page = .smart
                // `openhint <bundle id> <out>`: the click carries the app's id, as after a restart (no card in memory).
                TrashHint.openPage(a.count >= 3 ? a[1] : "")
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                say("windows after the click: \(vis()), page: \(vm.page)")
                say("cards: \(vm.trashHints.map { "\($0.name) \($0.items.count) items" }) note: \(vm.trashHintNote)")
                let d = await UNUserNotificationCenter.current().deliveredNotifications()
                say("delivered: \(d.map { $0.request.identifier }.filter { $0.hasPrefix("trashhint") })")
                if let h = vm.trashHints.first { vm.trashHints.removeAll { $0.id == h.id }; TrashHint.forget(h.id)
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    let e = await UNUserNotificationCenter.current().deliveredNotifications()
                    say("delivered after dismiss: \(e.map { $0.request.identifier }.filter { $0.hasPrefix("trashhint") })") }
                say("done")
            }
        case "notif":     // notif <out>: is this app allowed to show notifications, and what does asking return
            UNUserNotificationCenter.current().getNotificationSettings { st in
                let before = "status before: \(st.authorizationStatus.rawValue) (0 not asked, 1 denied, 2 allowed, 3 provisional), alert style \(st.alertStyle.rawValue)"
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, err in
                    Task { @MainActor in
                        say(before); say("asking: granted \(ok), error \(err.map { "\($0)" } ?? "none")")
                        vm.showTrashHint(TrashHintInfo(name: "SelfTest", bundleID: "com.tmtest.selftest", items: []))
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        let d = await UNUserNotificationCenter.current().deliveredNotifications()
                        say("delivered now: \(d.count)")
                        for n in d { say("   \(n.request.identifier): \(n.request.content.title)") }
                        say("done")
                    }
                }
            }
        case "appstale":  // appstale <seconds> <out>: scan Clean by App, say whether code-built rows read the same again, now and after a wait
            vm.scanByApp()
            Task { @MainActor in
                while vm.appBusy { try? await Task.sleep(nanoseconds: 300_000_000) }
                for r in vm.appReports where r.groups.contains(where: { $0.section.custom != nil }) {
                    say("\(r.id): rows \(r.groups.map { $0.rows.count }) changed right after the scan: \(vm.customRowsChanged(r))")
                }
                let w = Double(a[1]) ?? 0
                say("waiting \(Int(w)) s"); try? await Task.sleep(nanoseconds: UInt64(w * 1_000_000_000))
                for r in vm.appReports where r.groups.contains(where: { $0.section.custom != nil }) { say("\(r.id): changed after the wait: \(vm.customRowsChanged(r))") }
                say("done"); exit(0)
            }
        case "dupes":     // dupes <path prefix> <out>: scan Duplicates and print the groups under the prefix (nothing is moved)
            vm.scanDupes()
            Task { @MainActor in
                while vm.dupBusy { try? await Task.sleep(nanoseconds: 300_000_000) }
                for g in vm.dupes where g.items.contains(where: { $0.url.path.hasPrefix(a[1]) }) {
                    say("group, wasted \(g.wasted), selected \(g.selectedSize)")
                    for it in g.items { say("   \(it.selected ? "[x]" : "[ ]") \(short(it.url.path)) size \(it.size)\(it.clone ? " clone" : "")\(it.cloneOfExtra ? " of-extra" : "") \(it.reason)") }
                }
                say("done"); exit(0)
            }
        case "junk":      // junk <path prefix> <out>: scan, tick only test items under the prefix, clean, then Undo
            let prefix = a[1]
            vm.scanJunk(thenReview: true)
            Task { @MainActor in
                let t0 = Date()
                while vm.phase == .scanning { try? await Task.sleep(nanoseconds: 300_000_000) }
                say("scan \(ms(t0)) ms")
                var picked: [URL] = []
                for i in vm.cats.indices { for j in vm.cats[i].items.indices {
                    let it = vm.cats[i].items[j]
                    let mine = ["devdeps", "worktrees"].contains(vm.cats[i].id) && it.url.path.hasPrefix(prefix)
                    if ["devdeps", "worktrees"].contains(vm.cats[i].id) { say("\(vm.cats[i].id) \(it.selected ? "[x]" : "[ ]") \(short(it.url.path)) \(it.size)") }
                    vm.cats[i].items[j].selected = mine
                    if mine { picked.append(it.url) }
                } }
                guard !picked.isEmpty else { say("nothing under the prefix"); say("done"); exit(0) }
                // `junk <prefix> <seconds> <out>`: wait between scan and clean, so a test can change a project meanwhile.
                if a.count >= 4, let w = Double(a[2]) { say("waiting \(Int(w)) s"); try? await Task.sleep(nanoseconds: UInt64(w * 1_000_000_000)) }
                let t1 = Date()
                vm.cleanJunk()
                say("clean \(ms(t1)) ms: \(vm.lastResult) \(vm.lastErr)")
                for c in vm.cats where ["devdeps", "worktrees"].contains(c.id) { for it in c.items where !it.selected && picked.contains(it.url) { say("   unticked: \(short(it.url.path)) \(it.reason)") } }
                for u in picked { say("   after clean \(FileManager.default.fileExists(atPath: u.path) ? "STILL THERE" : "gone") \(short(u.path))") }
                if let s = vm.undoable {
                    let t2 = Date()
                    let r = Journal.restore(s); vm.undoable = nil; Journal.clear()
                    say("undo \(ms(t2)) ms: put back \(r.ok), skipped \(r.skipped)")
                    for u in picked { say("   after undo \(FileManager.default.fileExists(atPath: u.path) ? "back" : "MISSING") \(short(u.path))") }
                } else { say("no undo session") }
                say("done"); exit(0)
            }
        default: say("unknown test"); exit(0)
        }
    }
}
