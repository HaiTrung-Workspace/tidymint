// Back up and restore: one file with the person's settings and, from format 2, their history and statistics (the
// files in the app's data folder), to move to another Mac or keep before experimenting. Paths under the home folder
// are written with a placeholder, so they fit a Mac where the user name differs. Import shows what the file holds,
// the person picks the parts, the current state is saved first, then the app reopens: the data files are merged
// into what is there (never overwritten) by the new copy, before anything reads them.
// macOS permissions cannot be carried by any app: after an import, Settings lists the ones still to grant.
import AppKit
import CryptoKit

enum SettingsBackup {
    struct Part { let id: String; let name: String; let prefixes: [String]; let keys: [String] }
    static let fileExt = "tidymint"
    /// Layout of the file. A file with a higher number comes from a newer Tidymint and is refused, not half-read.
    /// 1: settings only. 2: settings and data files in one checked payload.
    static let format = 2
    /// Shown in every build (switched on 16/11/2026, ships with the next release).
    static let released = true
    /// Values that belong to this Mac or this run, never carried over.
    static let skip: Set<String> = {
        var s: Set<String> = ["extraScanVolumeIDs", "volumeNames"]
        #if TIDYMINT_PRIVATE
        s.formUnion(["mb.pending", "mb.names", "mb.ownGrouped"])
        #endif
        return s
    }()

    static var parts: [Part] {
        var p = [Part(id: "general", name: t("General: language, theme, alerts, scanning", "Chung: ngôn ngữ, giao diện, cảnh báo, quét"), prefixes: [],
                      keys: ["lang", "theme", "textSize", "showMenuBar", "ramAlert", "lowSpaceGB", "projectFolders",
                             "extraScanFolders", "protectedKeywords", "ignoredPaths", "crossDriveKeep", "devStaleDays", "appsSort", "trashHint"])]
        #if TIDYMINT_PRIVATE
        p += [Part(id: "mintangle", name: "Mintangle", prefixes: ["mt."], keys: []),
              Part(id: "mintbar", name: "Mintbar", prefixes: ["mb."], keys: []),
              Part(id: "mintdrop", name: "Mintdrop", prefixes: ["sh."], keys: [])]
        #endif
        return p
    }
    static func belongs(_ key: String, _ p: Part) -> Bool { !skip.contains(key) && !key.hasPrefix("sync.") && (p.keys.contains(key) || p.prefixes.contains { key.hasPrefix($0) }) }

    /// The current settings of the chosen parts, as a property list.
    static func snapshot(_ chosen: [Part], _ ud: UserDefaults = .standard, domain: String? = nil) -> [String: Any] {
        let all = ud.persistentDomain(forName: domain ?? Bundle.main.bundleIdentifier ?? "") ?? [:]
        var out: [String: Any] = [:]
        for (k, v) in all where chosen.contains(where: { belongs(k, $0) }) { out[k] = v }
        return out
    }
    static func fileData(_ chosen: [Part], withData: Bool = true, home: String = NSHomeDirectory(), dataDir: String = Stats.dir) -> Data? {
        let settings = portable(snapshot(chosen), home: home) as? [String: Any] ?? [:]
        let files = withData ? dataFiles(dataDir, home: home) : [:]
        guard let payload = try? PropertyListSerialization.data(fromPropertyList: ["settings": settings, "data": files] as [String: Any], format: .binary, options: 0) else { return nil }
        let doc: [String: Any] = ["app": "Tidymint", "format": format, "version": Updates.current, "date": Date(),
                                  "parts": chosen.map(\.id) + (files.isEmpty ? [] : [dataPart.id]), "payload": payload, "sha256": sha(payload)]
        return try? PropertyListSerialization.data(fromPropertyList: doc, format: .binary, options: 0)
    }
    static func sha(_ d: Data) -> String { SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined() }

    // MARK: data files and paths
    /// History and statistics: the files in the data folder (cleaning log, disk history, and the history and logs
    /// the tools keep there).
    static let dataPart = Part(id: "data", name: t("History and statistics", "Lịch sử và thống kê"), prefixes: [], keys: [])
    /// Not carried: menu bar icon pictures (taken again on the new Mac), backups of settings, an import still waiting,
    /// and the undo lists whose originals sit in this Mac's Trash (on another Mac, Undo could pull back a different
    /// file of the same name). The cleaning log itself goes.
    static var dataSkip: Set<String> {
        var s: Set<String> = ["mintbar-icons", "Settings backups", pendingName, "last-clean.json"]
        return s
    }
    static let pendingName = "pending-import.plist"
    /// Stands for the home folder in a file, so a path fits whatever the user name is on the Mac that reads it.
    static let homeToken = "~TIDYMINT-HOME~"
    static func dataFiles(_ dir: String, home: String) -> [String: Data] {
        var out: [String: Data] = [:]
        let fm = FileManager.default
        guard let e = fm.enumerator(atPath: dir) else { return out }
        while let rel = e.nextObject() as? String {
            let top = rel.split(separator: "/").first.map(String.init) ?? rel
            if dataSkip.contains(top) || rel.hasPrefix(".") { if (e.fileAttributes?[.type] as? FileAttributeType) == .typeDirectory { e.skipDescendants() }; continue }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir + "/" + rel, isDirectory: &isDir), !isDir.boolValue,
                  let d = fm.contents(atPath: dir + "/" + rel), d.count < 20_000_000 else { continue }
            out[rel] = swapBytes(d, home: home, toToken: true)
        }
        return out
    }
    /// Home paths in settings values (text, lists, dictionaries, and data blobs) to the placeholder.
    static func portable(_ v: Any, home: String) -> Any { swap(v, home: home, toToken: true) }
    static func local(_ v: Any, home: String) -> Any { swap(v, home: home, toToken: false) }
    static func swap(_ v: Any, home: String, toToken: Bool) -> Any {
        switch v {
        case let s as String: return swapText(s, home: home, toToken: toToken)
        case let a as [Any]: return a.map { swap($0, home: home, toToken: toToken) }
        case let d as [String: Any]: return d.mapValues { swap($0, home: home, toToken: toToken) }
        case let d as Data: return swapBytes(d, home: home, toToken: toToken)
        default: return v
        }
    }
    static func swapText(_ s: String, home: String, toToken: Bool) -> String {
        // The home folder itself, a path under it, and the same written by JSON with escaped slashes.
        let esc = home.replacingOccurrences(of: "/", with: "\\/")
        var out = s
        if toToken {
            if out == home { return homeToken }
            for h in [home, esc] {
                for end in ["/", "\\/", "\"", "\n", "'"] where out.contains(h + end) { out = out.replacingOccurrences(of: h + end, with: homeToken + end) }
            }
            return out
        }
        guard out.contains(homeToken) else { return out }
        // Back the way it was written: escaped where JSON escaped it, so the bytes match what the app itself writes.
        out = out.replacingOccurrences(of: homeToken + "\\/", with: esc + "\\/")
        return out.replacingOccurrences(of: homeToken, with: home)
    }
    static func swapBytes(_ d: Data, home: String, toToken: Bool) -> Data {
        guard let s = String(data: d, encoding: .utf8) else { return d }   // binary data carries no path we can read
        let r = swapText(s, home: home, toToken: toToken)
        return r == s ? d : Data(r.utf8)
    }

    /// Merges imported data files into `dir`: a file that is not there is written; JSON lists gain the entries they
    /// lack and JSON dictionaries the keys they lack (what is there wins); text logs gain the lines they lack, in date
    /// order. Anything else that is already there is kept. Loading the same file twice adds nothing.
    static func merge(_ files: [String: Data], into dir: String) {
        let fm = FileManager.default
        for (rel, incoming) in files {
            // A file this app never puts in a backup is not taken from one either (a file made by an earlier build, or
            // by hand, may hold it).
            if dataSkip.contains(String(rel.split(separator: "/").first ?? "")) { continue }
            let path = dir + "/" + rel
            try? fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            guard let have = fm.contents(atPath: path) else { try? incoming.write(to: URL(fileURLWithPath: path)); continue }
            if let merged = mergeJSON(have, incoming) ?? mergeText(have, incoming, rel) { try? merged.write(to: URL(fileURLWithPath: path)) }
        }
    }
    static func mergeJSON(_ have: Data, _ new: Data) -> Data? {
        guard let a = try? JSONSerialization.jsonObject(with: have), let b = try? JSONSerialization.jsonObject(with: new) else { return nil }
        func key(_ x: Any) -> Data { (try? JSONSerialization.data(withJSONObject: x, options: [.sortedKeys, .fragmentsAllowed])) ?? Data() }
        if let la = a as? [Any], let lb = b as? [Any] {
            let seen = Set(la.map(key))
            let add = lb.filter { !seen.contains(key($0)) }
            return add.isEmpty ? have : try? JSONSerialization.data(withJSONObject: la + add)
        }
        if var da = a as? [String: Any], let db = b as? [String: Any] {
            let before = da.count
            for (k, v) in db where da[k] == nil { da[k] = v }
            return da.count == before ? have : try? JSONSerialization.data(withJSONObject: da)
        }
        return have
    }
    static func mergeText(_ have: Data, _ new: Data, _ rel: String) -> Data? {
        guard rel.hasSuffix(".log") || rel.hasSuffix(".txt"), let a = String(data: have, encoding: .utf8), let b = String(data: new, encoding: .utf8) else { return nil }
        var lines = a.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        let seen = Set(lines)
        let add = b.split(separator: "\n", omittingEmptySubsequences: true).map(String.init).filter { !seen.contains($0) }
        guard !add.isEmpty else { return have }
        lines += add
        // A log whose lines start with a date stays in date order.
        if lines.allSatisfy({ $0.first?.isNumber == true }) { lines.sort() }
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }
    /// The new copy of the app, at launch before anything reads the data folder: merges a waiting import.
    static func applyPending(dir: String = Stats.dir) {
        let path = dir + "/" + pendingName
        guard let d = FileManager.default.contents(atPath: path),
              let files = (try? PropertyListSerialization.propertyList(from: d, options: [], format: nil)) as? [String: Data] else { return }
        try? FileManager.default.removeItem(atPath: path)
        merge(files, into: dir)
    }
    static var backupDir: URL { URL(fileURLWithPath: Stats.dir).appendingPathComponent("Settings backups") }
    static func stamp() -> String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH.mm"; return f.string(from: Date()) }

    // MARK: export
    @MainActor static func export() {
        NSApp.activate(ignoringOtherApps: true)
        let p = NSSavePanel()
        p.nameFieldStringValue = "Tidymint \(stamp()).\(fileExt)"
        p.allowedContentTypes = []; p.allowsOtherFileTypes = true
        p.message = t("Holds your file and folder names. Do not send it to others.", "File chứa tên file và thư mục của bạn. Đừng gửi cho người khác.")
        let withData = NSButton(checkboxWithTitle: t("Include history and statistics", "Kèm lịch sử và thống kê"), target: nil, action: nil)
        withData.state = .on; p.accessoryView = withData
        guard p.runModal() == .OK, let u = p.url, let d = fileData(parts, withData: withData.state == .on) else { return }
        do { try d.write(to: u); sharedVM.log(t("Settings saved to \(u.lastPathComponent).", "Đã lưu cài đặt ra \(u.lastPathComponent).")) }
        catch { alert(t("Could not save the file", "Không lưu được file"), error.localizedDescription) }
    }

    // MARK: import
    static func read(_ u: URL) -> (doc: [String: Any], settings: [String: Any])? { readAll(u).map { ($0.doc, $0.settings) } }
    /// Settings with this Mac's home folder in their paths, and the data files (format 2).
    static func readAll(_ u: URL, home: String = NSHomeDirectory()) -> (doc: [String: Any], settings: [String: Any], data: [String: Data])? {
        guard let d = try? Data(contentsOf: u),
              let doc = try? PropertyListSerialization.propertyList(from: d, options: [], format: nil) as? [String: Any],
              doc["app"] as? String == "Tidymint", (doc["format"] as? Int ?? 1) <= format else { return nil }
        if let s = doc["settings"] as? [String: Any] { return (doc, local(s, home: home) as? [String: Any] ?? s, [:]) }   // format 1
        // Format 2: the payload must match its checksum, or nothing of it is read.
        guard let payload = doc["payload"] as? Data, doc["sha256"] as? String == sha(payload),
              let inner = try? PropertyListSerialization.propertyList(from: payload, options: [], format: nil) as? [String: Any],
              let s = inner["settings"] as? [String: Any] else { return nil }
        let files = (inner["data"] as? [String: Data] ?? [:]).mapValues { swapBytes($0, home: home, toToken: false) }
        return (doc, local(s, home: home) as? [String: Any] ?? s, files)
    }
    /// A Tidymint file whose payload does not match its checksum (cut short or changed).
    static func isDamaged(_ u: URL) -> Bool {
        guard let d = try? Data(contentsOf: u),
              let doc = try? PropertyListSerialization.propertyList(from: d, options: [], format: nil) as? [String: Any],
              doc["app"] as? String == "Tidymint", let payload = doc["payload"] as? Data else { return false }
        return doc["sha256"] as? String != sha(payload)
    }
    /// A Tidymint settings file in a layout this version does not know yet.
    static func isNewer(_ u: URL) -> Bool {
        guard let d = try? Data(contentsOf: u),
              let doc = try? PropertyListSerialization.propertyList(from: d, options: [], format: nil) as? [String: Any] else { return false }
        return doc["app"] as? String == "Tidymint" && (doc["format"] as? Int ?? 1) > format
    }
    @MainActor static func importFile() {
        NSApp.activate(ignoringOtherApps: true)
        let o = NSOpenPanel(); o.canChooseFiles = true; o.canChooseDirectories = false; o.allowsMultipleSelection = false
        o.message = t("Pick a Tidymint settings file", "Chọn file cài đặt Tidymint")
        guard o.runModal() == .OK, let u = o.url else { return }
        load(u)
    }
    /// Loads a picked file. `only`: the parts to load without asking (a dev test of the whole app); nil asks with ticks.
    @MainActor static func load(_ u: URL, only: Set<String>? = nil) {
        if isNewer(u) { alert(t("This file comes from a newer Tidymint", "File này của bản Tidymint mới hơn"), t("Update Tidymint on this Mac, then load it again.", "Cập nhật Tidymint trên máy này rồi nạp lại.")); return }
        if isDamaged(u) { alert(t("This file is damaged", "File này bị hỏng"), t("Nothing was loaded.", "Chưa nạp gì.")); return }
        guard let (doc, s, files) = readAll(u) else {
            // A .tidymint file that does not read at all was cut short (a copy stopped part way): say so, not "foreign".
            if u.pathExtension.lowercased() == fileExt { alert(t("This file is damaged", "File này bị hỏng"), t("Nothing was loaded.", "Chưa nạp gì.")) }
            else { alert(t("This is not a Tidymint settings file", "Đây không phải file cài đặt Tidymint"), u.lastPathComponent) }
            return
        }
        let here = parts.filter { p in s.keys.contains { belongs($0, p) } } + (files.isEmpty ? [] : [dataPart])
        guard !here.isEmpty else { alert(t("Nothing in this file applies here", "File này không có gì dùng được ở đây"), u.lastPathComponent); return }
        // Native alert with one tick per part, like a macOS import sheet.
        let a = NSAlert()
        let when = (doc["date"] as? Date).map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .short) } ?? ""
        a.messageText = t("Load these settings?", "Nạp các cài đặt này?")
        a.informativeText = t("From \(u.lastPathComponent) (\(when)). What you have now is saved first; history is added to yours. Tidymint reopens.",
                              "Từ \(u.lastPathComponent) (\(when)). Bản hiện tại được lưu lại trước; lịch sử được gộp vào. Tidymint mở lại.")
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 6
        let boxes = here.map { p -> NSButton in let b = NSButton(checkboxWithTitle: p.name, target: nil, action: nil); b.state = .on; stack.addArrangedSubview(b); return b }
        stack.frame = NSRect(x: 0, y: 0, width: 320, height: CGFloat(here.count) * 22)
        a.accessoryView = stack
        a.addButton(withTitle: t("Load", "Nạp")); a.addButton(withTitle: t("Cancel", "Huỷ"))
        let chosen: [Part]
        if let only { chosen = here.filter { only.contains($0.id) } } else {
            guard a.runModal() == .alertFirstButtonReturn else { return }
            chosen = zip(here, boxes).filter { $0.1.state == .on }.map(\.0)
        }
        guard !chosen.isEmpty else { return }
        apply(s, chosen.filter { $0.id != dataPart.id })
        var data = files
        if chosen.contains(where: { $0.id == dataPart.id }), let d = try? PropertyListSerialization.data(fromPropertyList: data, format: .binary, options: 0) {
            // Written by the new copy at launch, so this one cannot save its own state over the merged files on quit.
            try? FileManager.default.createDirectory(atPath: Stats.dir, withIntermediateDirectories: true)
            try? d.write(to: URL(fileURLWithPath: Stats.dir + "/" + pendingName))
        }
        UserDefaults.standard.set(true, forKey: permCheckKey)   // Settings lists the permissions to grant again
        relaunch()
    }
    /// After an import: Settings shows the macOS permissions still to grant, until they are or the person closes it.
    static let permCheckKey = "backup.permCheck"
    /// Saves the current settings, then replaces the chosen parts with the file's values (keys missing from the file are removed).
    static func apply(_ s: [String: Any], _ chosen: [Part], _ ud: UserDefaults = .standard, domain: String? = nil) {
        if domain == nil {   // the real settings: keep a copy first (a test domain has nothing to keep)
            try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
            if let d = fileData(parts) { try? d.write(to: backupDir.appendingPathComponent("Before import \(stamp()).\(fileExt)")) }
        }
        let all = ud.persistentDomain(forName: domain ?? Bundle.main.bundleIdentifier ?? "") ?? [:]
        for k in all.keys where chosen.contains(where: { belongs(k, $0) }) { ud.removeObject(forKey: k) }
        for (k, v) in s where chosen.contains(where: { belongs(k, $0) }) { ud.set(v, forKey: k) }
        ud.synchronize()
    }
    /// Opens a second copy of the app, which reads the new settings; this one quits (a new copy asks the old one to
    /// quit anyway). No shell involved.
    static func relaunch() {
        let cfg = NSWorkspace.OpenConfiguration(); cfg.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: cfg) { app, _ in
            if app != nil { DispatchQueue.main.async { NSApp.terminate(nil) } }
        }
    }
    @MainActor static func alert(_ title: String, _ text: String) {
        let a = NSAlert(); a.messageText = title; a.informativeText = text; a.runModal()
    }
}
