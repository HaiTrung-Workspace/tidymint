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

// MARK: - Ignore list

/// User settings stored in UserDefaults.
enum Prefs {
    /// Folders where the user keeps projects (code, AI workspaces). Used to look for drafts,
    /// to never pre-select duplicates inside them, and to check links before deleting.
    /// Extra path keywords that must never be touched (e.g. a browser-profile folder name).
    static var protectedKeywords: [String] { UserDefaults.standard.stringArray(forKey: "protectedKeywords") ?? [] }
    private static var projectCache: [String]? = nil
    private static let projectLock = NSLock()
    static var projectFolders: [String] {
        get { projectLock.lock(); defer { projectLock.unlock() }
              if let c = projectCache { return c }
              let v = UserDefaults.standard.stringArray(forKey: "projectFolders") ?? []; projectCache = v; return v }
        set { projectLock.lock(); projectCache = newValue; projectLock.unlock(); UserDefaults.standard.set(newValue, forKey: "projectFolders") }
    }
    static func inProject(_ p: String) -> Bool { let q = canonical(p); return projectFolders.contains { q == $0 || q.hasPrefix($0 + "/") } }
    /// Drive name as it was when a path on it was saved (project folder, extra folder, ignore list), by volume UUID.
    /// A renamed drive ("SSD" became "SSD 1") then still matches those saved paths.
    private static var volCache: [String: String]? = nil
    static var volumeNames: [String: String] {
        get { projectLock.lock(); defer { projectLock.unlock() }
              if let c = volCache { return c }
              let v = UserDefaults.standard.dictionary(forKey: "volumeNames") as? [String: String] ?? [:]; volCache = v; return v }
        set { projectLock.lock(); volCache = newValue; projectLock.unlock(); UserDefaults.standard.set(newValue, forKey: "volumeNames") }
    }
    static func rememberVolume(of path: String) {
        guard onOtherDrive(path), let root = volumeRoot(path),
              let id = (try? URL(fileURLWithPath: root).resourceValues(forKeys: [.volumeUUIDStringKey]))?.volumeUUIDString else { return }
        if volumeNames[id] == nil { volumeNames[id] = root }
    }
    static func volumeRoot(_ p: String) -> String? {
        let parts = p.split(separator: "/", omittingEmptySubsequences: true)
        return parts.count >= 2 && parts[0] == "Volumes" ? "/" + parts.prefix(2).joined(separator: "/") : nil
    }
    /// The path with the drive name it was saved under (see volumeNames); unchanged for anything else.
    static func canonical(_ p: String) -> String {
        guard let root = volumeRoot(p) else { return p }
        driveLock.lock(); let known = uuidCache[root]; driveLock.unlock()
        let id: String?
        if let known { id = known }
        else {
            id = (try? URL(fileURLWithPath: root).resourceValues(forKeys: [.volumeUUIDStringKey]))?.volumeUUIDString
            if let id { driveLock.lock(); uuidCache[root] = id; driveLock.unlock() }
        }
        guard let id, let saved = volumeNames[id], saved != root else { return p }
        return saved + p.dropFirst(root.count)
    }
    private static var uuidCache: [String: String] = [:]
    /// Extra places scanned by Duplicates and Large & Old Files: external drives, or folders in the home folder
    /// outside the usual six (Documents, Downloads...). Added by the user in Settings. Several drives are fine.
    static var extraFolders: [String] {
        get { UserDefaults.standard.stringArray(forKey: "extraScanFolders") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "extraScanFolders") }
    }
    /// Volume UUID of each extra folder on an external drive, so the folder is found again when the drive comes back
    /// under another name ("SSD 1" when two drives share a name, or after a rename).
    static var extraVolumeIDs: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: "extraScanVolumeIDs") as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "extraScanVolumeIDs") }
    }
    /// Where an extra folder is right now, or nil when its drive is not plugged in.
    static func resolveExtra(_ path: String) -> String? {
        let fm = FileManager.default
        guard onOtherDrive(path) else { return fm.fileExists(atPath: path) ? path : nil }
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)   // ["Volumes", name, rest...]
        guard parts.count >= 2 else { return nil }
        let root = "/" + parts.prefix(2).joined(separator: "/")
        let rest = parts.dropFirst(2).joined(separator: "/")
        let want = extraVolumeIDs[path]
        func uuid(_ u: URL) -> String? { (try? u.resourceValues(forKeys: [.volumeUUIDStringKey]))?.volumeUUIDString }
        if fm.fileExists(atPath: path) {
            // Same name, but a different drive is mounted there: not our folder.
            if let w = want, let now = uuid(URL(fileURLWithPath: root)), now != w { return nil }
            return path
        }
        guard let w = want else { return nil }
        let vols = fm.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeUUIDStringKey], options: [.skipHiddenVolumes]) ?? []
        guard let v = vols.first(where: { uuid($0) == w }) else { return nil }
        let p = rest.isEmpty ? v.path : v.appendingPathComponent(rest).path
        return fm.fileExists(atPath: p) ? p : nil
    }
    /// Extra folders present right now: a drive that is not plugged in is skipped, not reported as an error.
    static var extraRoots: [URL] { extraFolders.compactMap(resolveExtra).map { URL(fileURLWithPath: $0) } }
    enum ExtraCheck { case ok, outside, network, readOnly, timeMachine }
    /// Allowed: a folder on another local, writable drive (/Volumes/<name>), or a folder inside the home folder that is not Library.
    /// The startup disk seen through /Volumes resolves to "/" and is refused. Network drives are refused: macOS has no Trash
    /// there, so a "move to Trash" would fail. Time Machine backups are refused: macOS manages them.
    static func extraCheck(_ u: URL) -> ExtraCheck {
        let real = u.resolvingSymlinksInPath().path
        let home = FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().path
        if real.hasPrefix("/Volumes/") {
            let v = try? u.resourceValues(forKeys: [.volumeIsLocalKey, .volumeIsReadOnlyKey, .volumeURLKey])
            if v?.volumeIsLocal == false { return .network }
            if v?.volumeIsReadOnly == true { return .readOnly }
            let rootKids = (try? FileManager.default.contentsOfDirectory(atPath: v?.volume?.path ?? real)) ?? []
            // HFS+ backups keep Backups.backupdb; APFS backups are folders named like 2026-11-04-101500.backup.
            if rootKids.contains(where: { $0 == "Backups.backupdb" || $0.range(of: #"^\d{4}-\d{2}-\d{2}-\d{6}\.(backup|previous|inprogress|interrupted)$"#, options: .regularExpression) != nil }) { return .timeMachine }
            return .ok
        }
        guard real.hasPrefix(home + "/") else { return .outside }
        return (real == home + "/Library" || real.hasPrefix(home + "/Library/")) ? .outside : .ok
    }
    /// True when the path is on a drive other than the startup disk.
    /// A second volume on the internal disk is not "another drive": the space stays on the same SSD.
    /// Cached per volume, called from scans on background threads.
    static func onOtherDrive(_ p: String) -> Bool {
        guard p.hasPrefix("/Volumes/") else { return false }
        let parts = p.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return false }
        let root = "/" + parts.prefix(2).joined(separator: "/")
        driveLock.lock(); defer { driveLock.unlock() }
        if let v = driveCache[root] { return v }
        guard let r = try? URL(fileURLWithPath: root).resourceValues(forKeys: [.volumeIsEjectableKey, .volumeIsRemovableKey, .volumeIsInternalKey]) else {
            return true   // not mounted right now: nothing to cache, and a /Volumes path that is not there is not the startup disk
        }
        let other = r.volumeIsEjectable == true || r.volumeIsRemovable == true || r.volumeIsInternal == false
        driveCache[root] = other
        return other
    }
    private static var driveCache: [String: Bool] = [:]
    static let driveLock = NSLock()
    /// Which copy to keep when the same file is on the Mac and on an external drive:
    /// "ask" (nothing pre-selected, the user picks), "external" (free space on the Mac), "mac" (keep the Mac copy).
    static var crossKeep: String {
        get { UserDefaults.standard.string(forKey: "crossDriveKeep") ?? "ask" }
        set { UserDefaults.standard.set(newValue, forKey: "crossDriveKeep") }
    }
}

enum IgnoreList {
    static let key = "ignoredPaths"
    /// Kept in memory: `contains` runs for every file a scan walks.
    private static var cached: [String]? = nil
    private static let lock = NSLock()
    static var paths: [String] {
        get { lock.lock(); defer { lock.unlock() }
              if let c = cached { return c }
              let v = UserDefaults.standard.stringArray(forKey: key) ?? []; cached = v; return v }
        set { lock.lock(); cached = newValue; lock.unlock(); UserDefaults.standard.set(newValue, forKey: key) }
    }
    static func add(_ p: String) { Prefs.rememberVolume(of: p); let q = Prefs.canonical(p); if !paths.contains(q) { paths.append(q) } }
    static func remove(_ p: String) { paths.removeAll { $0 == p } }
    static func contains(_ p: String) -> Bool { let q = Prefs.canonical(p); return paths.contains { q == $0 || q.hasPrefix($0 + "/") } }
}
