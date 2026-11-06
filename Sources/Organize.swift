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

// MARK: - Organize (sort a folder, suggest tags, keep notes)
//
// Everything runs on this Mac. "Quick" sorts by file type and name; "Read content" adds Apple's built-in Vision
// (text recognition + image classification) and PDFKit text, no model download. Nothing moves until the person
// reviews the plan and clicks Apply; every apply can be undone. Only files directly inside the chosen folder are
// touched, never subfolders, and nothing is ever deleted or overwritten.

/// Where one group goes when sorting: a new folder name inside the chosen folder, or a folder picked elsewhere.
struct OrgDest: Codable, Equatable { var name: String? = nil; var path: String? = nil }

enum OrgGroup: String, CaseIterable, Codable {
    case screens, receipts, cv, images, video, audio, docs, sheets, slides, archives, installers, code, other
    var label: String { let n = names; return t(n.0, n.1) }
    /// English and Vietnamese names, to find a group folder made in the other language.
    var names: (String, String) {
        switch self {
        case .screens: return ("Screenshots", "Ảnh màn hình")
        case .receipts: return ("Receipts and invoices", "Hoá đơn và biên lai")
        case .cv: return ("CVs", "CV")
        case .images: return ("Images", "Ảnh")
        case .video: return ("Videos", "Video")
        case .audio: return ("Audio", "Âm thanh")
        case .docs: return ("Documents", "Tài liệu")
        case .sheets: return ("Spreadsheets", "Bảng tính")
        case .slides: return ("Presentations", "Trình chiếu")
        case .archives: return ("Archives", "File nén")
        case .installers: return ("Installers", "Bộ cài app")
        case .code: return ("Code", "Code")
        case .other: return ("Other", "Khác")
        }
    }
    var icon: String {
        switch self {
        case .screens: return "camera.viewfinder"
        case .receipts: return "doc.text.magnifyingglass"
        case .cv: return "person.text.rectangle"
        case .images: return "photo"
        case .video: return "film"
        case .audio: return "waveform"
        case .docs: return "doc.text"
        case .sheets: return "tablecells"
        case .slides: return "rectangle.on.rectangle"
        case .archives: return "archivebox"
        case .installers: return "shippingbox"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .other: return "questionmark.folder"
        }
    }
}

enum NameToken: String, CaseIterable, Codable {
    case date, time, parent, kind, desc, seq, old, text
    var label: String {
        switch self {
        case .date: return t("Date", "Ngày")
        case .time: return t("Time", "Giờ")
        case .parent: return t("Parent folder", "Thư mục mẹ")
        case .kind: return t("Type", "Loại")
        case .desc: return t("Description", "Mô tả")
        case .seq: return t("Number", "Số thứ tự")
        case .old: return t("Old name", "Tên cũ")
        case .text: return t("Your text", "Chữ tự gõ")
        }
    }
}
/// One part of a name rule. `text` holds what the person typed for a .text part (a prefix, suffix or tag like "ACME").
struct NamePart: Codable, Equatable, Identifiable {
    var id = UUID()
    var kind: NameToken
    var text = ""
}
/// How new names are built: the parts in order, the separator, and two switches for web-safe names.
struct NameRule: Codable, Equatable {
    var parts: [NamePart]
    var sep: String
    var noAccents: Bool
    var lower: Bool
}
enum NamePreset: String, CaseIterable {
    case dateDesc, dateTime, parentSeq, web, custom
    var label: String {
        switch self {
        case .dateDesc: return t("Date + description", "Ngày + mô tả")
        case .dateTime: return t("Date and time taken", "Ngày giờ chụp")
        case .parentSeq: return t("Folder + date + number", "Thư mục mẹ + ngày + số")
        case .web: return t("Web style (no accents, lower case)", "Kiểu web (không dấu, viết thường)")
        case .custom: return t("Custom", "Tuỳ chỉnh")
        }
    }
    var rule: NameRule? {
        switch self {
        case .dateDesc: return NameRule(parts: [.init(kind: .date), .init(kind: .desc)], sep: " ", noAccents: false, lower: false)
        case .dateTime: return NameRule(parts: [.init(kind: .date), .init(kind: .time)], sep: " ", noAccents: false, lower: false)
        case .parentSeq: return NameRule(parts: [.init(kind: .parent), .init(kind: .date), .init(kind: .seq)], sep: "_", noAccents: false, lower: false)
        case .web: return NameRule(parts: [.init(kind: .date), .init(kind: .desc)], sep: "_", noAccents: true, lower: true)
        case .custom: return nil
        }
    }
}

struct OrgFile: Identifiable {
    let id = UUID()
    let url: URL
    var size: Int64
    var date: Date?
    var group: OrgGroup
    var why: String = ""
    var tags: [String] = []          // suggested tags
    var tagOn: Set<String> = []      // tags the person keeps
    var newName: String? = nil       // suggested clearer name (editable)
    var renameOn = false             // apply the new name
    var title: String? = nil         // title read from the content (PDF title or first line of text)
    var desc: String? = nil          // what the file is, for the [Description] part of a name
    var needsName = false            // current name says nothing (IMG_, scan, Untitled...) or it is a receipt/CV
    var nameEdited = false           // the person typed a name: rules no longer overwrite it
    var note: String = ""
    var include = true
    var pairOf: UUID? = nil          // this file travels with another one (Live Photo video, RAW, subtitle, sidecar)
    var warn: String? = nil          // what will happen differently from the plan (name clash, too long, duplicate)
    var fate: String? = nil          // the name it will really get (" 2" added), or "" when it goes to the Trash
    var name: String { url.lastPathComponent }
}

/// One line on the result screen: a file that did not go as planned, and why.
struct OrgNote: Identifiable { enum Kind { case skipped, kept, numbered, trashed }; let id = UUID(); let kind: Kind; let name: String; let detail: String }

struct OrgMove: Codable { let from: String; let to: String; let addedTags: [String]; var trashed: Bool? = nil
    /// File number of the moved file: Undo only moves back the very same file, never a newer one with the same name.
    var fileID: String? = nil }
struct OrgSession: Codable { let folder: String; var date: Date; var moves: [OrgMove]; var madeDirs: [String]; var auto: Bool? = nil; var id: String? = nil }

enum OrgEngine {
    static let fm = FileManager.default
    static let ext: [OrgGroup: Set<String>] = [
        .images: ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "tif", "bmp", "svg", "raw", "dng", "cr2", "nef", "arw", "psd", "avif"],
        .video: ["mov", "mp4", "m4v", "avi", "mkv", "webm"],
        .audio: ["mp3", "m4a", "wav", "aac", "flac", "ogg", "aiff", "aif"],
        .docs: ["pdf", "doc", "docx", "pages", "txt", "rtf", "md", "odt", "epub"],
        .sheets: ["xls", "xlsx", "numbers", "csv", "ods"],
        .slides: ["ppt", "pptx", "key", "odp"],
        .archives: ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz"],
        .installers: ["dmg", "pkg", "mpkg", "iso"],
        .code: ["py", "js", "ts", "swift", "json", "html", "css", "sh", "ipynb", "java", "c", "cpp", "h", "go", "rs", "yml", "yaml", "sql", "rb", "php"],
    ]
    static let screenPrefixes = ["screenshot", "screen shot", "ảnh màn hình", "ảnh chụp màn hình", "screen recording", "bản ghi màn hình", "cleanshot"]
    static let cameraPrefixes = ["img_", "img-", "dsc_", "dsc0", "pxl_", "dji_", "gopr", "photo_", "image_", "mvimg_"]

    /// A folder is allowed if it sits inside the home folder, is not the home folder itself and not inside ~/Library.
    static func allowed(_ u: URL) -> Bool {
        let p = u.standardizedFileURL.path, h = NSHomeDirectory()
        return p.hasPrefix(h + "/") && !p.hasPrefix(h + "/Library") && !p.hasPrefix(h + "/.")
    }

    /// Folders never entered when sub-folders are included: app bundles and libraries (packages), code projects, dependency folders.
    static let skipDirs: Set<String> = ["node_modules", ".git", "Library", "venv", ".venv", "build", "DerivedData", "Pods"]
    static func isProject(_ d: URL) -> Bool {
        ["\(d.path)/.git", "\(d.path)/package.json", "\(d.path)/Package.swift", "\(d.path)/.xcodeproj"].contains { fm.fileExists(atPath: $0) }
    }
    /// Files in the folder and its sub-folders (up to 6 levels, at most 5,000 files), skipping packages and code projects.
    static func filesDeep(in folder: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey, .isPackageKey, .isDirectoryKey]
        guard let en = fm.enumerator(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, _ in true }) else { return [] }
        var out: [URL] = []
        let base = folder.pathComponents.count
        for case let u as URL in en {
            guard let v = try? u.resourceValues(forKeys: Set(keys)) else { continue }
            if v.isDirectory == true {
                if v.isPackage == true || skipDirs.contains(u.lastPathComponent) || u.pathComponents.count - base >= 6 || isProject(u) { en.skipDescendants() }
                continue
            }
            if v.isRegularFile == true && v.isSymbolicLink != true { out.append(u) }
            if out.count >= 5000 { break }
        }
        return out.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }
    static func files(in folder: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey, .isPackageKey]
        let kids = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        return kids.filter {
            guard let v = try? $0.resourceValues(forKeys: Set(keys)) else { return false }
            return v.isRegularFile == true && v.isSymbolicLink != true && v.isPackage != true
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    static func quick(_ u: URL) -> OrgFile {
        let v = try? u.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .creationDateKey, .contentModificationDateKey])
        let e = u.pathExtension.lowercased(), n = u.lastPathComponent.lowercased()
        var g = OrgGroup.other
        for (k, s) in ext where s.contains(e) { g = k }
        var why = ""
        if (g == .images || g == .video), screenPrefixes.contains(where: { n.hasPrefix($0) }) { g = .screens; why = t("Name says it is a screen capture", "Tên file cho thấy là ảnh chụp màn hình") }
        // When it was taken, not when it was copied here: camera date first, else the earlier of created and modified
        // (a copy gets a new creation date but keeps its modification date).
        let fileDate = [v?.creationDate, v?.contentModificationDate].compactMap { $0 }.min()
        let media = g == .images || g == .video || g == .screens
        var taken = media ? takenDate(u, video: g == .video) : nil
        // Spotlight falls back to the file's own date for videos without a recording date: keep the earliest.
        if g == .video, let d = taken, let fd = fileDate { taken = min(d, fd) }
        var f = OrgFile(url: u, size: Int64(v?.totalFileAllocatedSize ?? 0), date: taken ?? fileDate, group: g, why: why)
        f.desc = describe(f, label: nil); f.needsName = meaningless(u)
        return f
    }

    static let exifFmt: DateFormatter = { let d = DateFormatter(); d.locale = Locale(identifier: "en_US_POSIX"); d.dateFormat = "yyyy:MM:dd HH:mm:ss"; return d }()
    static let exifFmtZ: DateFormatter = { let d = DateFormatter(); d.locale = Locale(identifier: "en_US_POSIX"); d.dateFormat = "yyyy:MM:dd HH:mm:ssxxx"; return d }()
    /// The capture date stored inside the file: EXIF for photos (read from the header only), the recording date for videos.
    static func takenDate(_ u: URL, video: Bool) -> Date? {
        if video {
            guard let item = MDItemCreateWithURL(nil, u as CFURL), let d = MDItemCopyAttribute(item, kMDItemContentCreationDate) as? Date else { return nil }
            return d
        }
        guard let src = CGImageSourceCreateWithURL(u as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let s = (exif[kCGImagePropertyExifDateTimeOriginal] ?? exif[kCGImagePropertyExifDateTimeDigitized]) as? String else { return nil }
        if let off = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String, let d = exifFmtZ.date(from: s + off) { return d }
        return exifFmt.date(from: s)
    }

    /// Files that belong together and must keep the same name and folder: a Live Photo (photo + video),
    /// RAW + JPG, a video and its subtitles, any file and its .xmp / .aae edit sidecar.
    static let pairMain: Set<String> = ["heic", "heif", "jpg", "jpeg", "png"]
    static let rawExt: Set<String> = ["dng", "cr2", "cr3", "nef", "arw", "raf", "orf", "rw2", "raw"]
    static let subExt: Set<String> = ["srt", "vtt", "ass", "ssa"]
    static let sideExt: Set<String> = ["xmp", "aae"]
    static func linkPairs(_ files: inout [OrgFile]) {
        var byStem: [String: [Int]] = [:]
        for i in files.indices {
            let k = files[i].url.deletingPathExtension().path.lowercased()
            byStem[k, default: []].append(i)
        }
        for (_, ix) in byStem where ix.count > 1 {
            func e(_ i: Int) -> String { files[i].url.pathExtension.lowercased() }
            let videoExt = ext[.video]!
            // The leader carries the name: the photo, else the RAW, else the video, else the first non-sidecar file.
            guard let lead = ix.first(where: { pairMain.contains(e($0)) }) ?? ix.first(where: { rawExt.contains(e($0)) })
                    ?? ix.first(where: { videoExt.contains(e($0)) }) ?? ix.first(where: { !sideExt.contains(e($0)) }) else { continue }
            let le = e(lead)
            for i in ix where i != lead {
                let x = e(i)
                var why: String? = nil
                if sideExt.contains(x) { why = t("edit sidecar", "file chỉnh sửa đi kèm") }
                else if videoExt.contains(x) && pairMain.contains(le) { why = "Live Photo" }
                else if rawExt.contains(x) && pairMain.contains(le) { why = "RAW + JPG" }
                else if subExt.contains(x) && videoExt.contains(le) { why = t("subtitles", "phụ đề") }
                guard let w = why else { continue }
                files[i].pairOf = files[lead].id
                files[i].why = t("Goes with \(files[lead].name) (\(w))", "Đi cùng \(files[lead].name) (\(w))")
            }
        }
    }

    /// Finder accepts up to 255 bytes per name. Drop characters it refuses or hides the file with, keep room for " 2".
    static func safeStem(_ s: String, ext: String) -> String {
        var x = String(String.UnicodeScalarView(s.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }))
        x = x.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        x = x.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        while x.hasPrefix(".") { x.removeFirst() }
        let room = 255 - (ext.isEmpty ? 0 : ext.utf8.count + 1) - 6
        while x.utf8.count > room { x.removeLast() }
        return x.trimmingCharacters(in: .whitespaces)
    }

    /// Same file on disk (also when the paths differ only in upper/lower case on a case-insensitive disk).
    static func sameFile(_ a: URL, _ b: URL) -> Bool {
        guard let x = try? a.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject,
              let y = try? b.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject else { return false }
        return x.isEqual(y)
    }
    /// Move or rename. A change of case only (IMG.JPG to IMG.jpg) goes through a temporary name, because the disk sees one file.
    /// Another process has this file open (a torrent client still writing, an installer reading). Checked before moving a new download.
    static func isOpen(_ u: URL) -> Bool {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof"); p.arguments = ["-t", "--", u.path]
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }
    /// One lsof call for many files: the paths another process has open.
    static func openPaths(_ us: [URL]) -> Set<String> {
        guard !us.isEmpty else { return [] }
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof"); p.arguments = ["-Fn", "--"] + us.map(\.path)
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return [] }
        let d = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        return Set((String(data: d, encoding: .utf8) ?? "").split(separator: "\n").filter { $0.hasPrefix("n") }.map { String($0.dropFirst()) })
    }
    static func move(_ from: URL, _ to: URL) throws {
        if from.path != to.path, from.path.lowercased() == to.path.lowercased() || sameFile(from, to) {
            let tmp = to.deletingLastPathComponent().appendingPathComponent(".tidymint-\(UUID().uuidString)")
            try fm.moveItem(at: from, to: tmp)
            do { try fm.moveItem(at: tmp, to: to) } catch { try? fm.moveItem(at: tmp, to: from); throw error }
        } else { try fm.moveItem(at: from, to: to) }
    }
    /// Quick check for the preview: same size, same first and last megabyte. Apply still runs `identical`.
    static func likelyIdentical(_ a: URL, _ b: URL) -> Bool {
        guard let sa = (try? fm.attributesOfItem(atPath: a.path))?[.size] as? Int64,
              let sb = (try? fm.attributesOfItem(atPath: b.path))?[.size] as? Int64, sa == sb, sa <= 500_000_000,
              let ha = try? FileHandle(forReadingFrom: a), let hb = try? FileHandle(forReadingFrom: b) else { return false }
        defer { try? ha.close(); try? hb.close() }
        let mb: UInt64 = 1 << 20
        if ha.readData(ofLength: Int(mb)) != hb.readData(ofLength: Int(mb)) { return false }
        if UInt64(sa) > 2 * mb {
            try? ha.seek(toOffset: UInt64(sa) - mb); try? hb.seek(toOffset: UInt64(sa) - mb)
            if ha.readData(ofLength: Int(mb)) != hb.readData(ofLength: Int(mb)) { return false }
        }
        return true
    }
    /// Byte-for-byte identical (files over 500 MB are never treated as duplicates, to keep this fast).
    static func identical(_ a: URL, _ b: URL) -> Bool {
        guard let sa = (try? fm.attributesOfItem(atPath: a.path))?[.size] as? Int64,
              let sb = (try? fm.attributesOfItem(atPath: b.path))?[.size] as? Int64, sa == sb, sa <= 500_000_000,
              let ha = try? FileHandle(forReadingFrom: a), let hb = try? FileHandle(forReadingFrom: b) else { return false }
        defer { try? ha.close(); try? hb.close() }
        while true {
            let x = ha.readData(ofLength: 1 << 20), y = hb.readData(ofLength: 1 << 20)
            if x != y { return false }
            if x.isEmpty { return true }
        }
    }

    static let df: DateFormatter = { let d = DateFormatter(); d.dateFormat = "yyyy-MM-dd"; return d }()
    /// Names that say nothing about the file: camera dumps, scans, "Untitled", "download (3)", long random strings.
    static func meaningless(_ url: URL) -> Bool {
        let n = url.deletingPathExtension().lastPathComponent.lowercased()
        if cameraPrefixes.contains(where: { n.hasPrefix($0) }) || screenPrefixes.contains(where: { n.hasPrefix($0) }) { return true }
        let generic = ["scan", "untitled", "document", "download", "image", "file", "photo", "img", "new document", "tài liệu", "không có tiêu đề", "unnamed"]
        let core = n.replacingOccurrences(of: #"[\s_\-\(\)\d]+$"#, with: "", options: .regularExpression)
        if generic.contains(core) || core.isEmpty { return true }
        // Random strings: hex/UUID-like, or one long run of letters and digits with several digits and no separators.
        if n.range(of: #"^[a-f0-9\-]{16,}$"#, options: .regularExpression) != nil { return true }
        if n.range(of: #"^[a-z0-9]{16,}$"#, options: .regularExpression) != nil && n.filter(\.isNumber).count >= 4 { return true }
        return false
    }
    /// Keep a name safe for Finder: no slashes or colons, single spaces, at most 60 characters.
    static func clean(_ s: String) -> String {
        // Keep letters, digits and a few safe signs only; text read from images can contain stray control characters.
        let ok = CharacterSet.letters.union(.decimalDigits).union(CharacterSet(charactersIn: " -_.,()&'+#"))
        var x = String(String.UnicodeScalarView(s.unicodeScalars.map { ok.contains($0) ? $0 : " " }))
        // ALL-CAPS text read from a scan becomes Title Case so the name stays readable.
        if x == x.uppercased(), x.rangeOfCharacter(from: .lowercaseLetters) == nil, x.count > 4 { x = x.capitalized(with: Locale(identifier: "vi")) }
        x = x.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return String(x.prefix(60)).trimmingCharacters(in: .whitespaces)
    }
    /// What the file is, in a few words: used for the [Description] part of a name.
    static func describe(_ f: OrgFile, label: String?) -> String {
        // A name the person chose is kept as the description (dates and copy marks stripped); content only names files whose name says nothing.
        if !meaningless(f.url), let old = oldDesc(f.url) { return old }
        let title = f.title.map(clean).flatMap { $0.isEmpty ? nil : $0 }
        switch f.group {
        case .screens: return t("Screenshot", "Ảnh màn hình")
        case .receipts: return t("Receipt", "Hoá đơn") + (title.map { " " + $0 } ?? "")
        case .cv: return "CV" + (title.map { " " + $0 } ?? "")
        default: return clean(title ?? label ?? f.group.label)
        }
    }
    static let datePatterns: [(String, String)] = [
        (#"(19|20)\d{2}[-_.](0[1-9]|1[0-2])[-_.](0[1-9]|[12]\d|3[01])"#, "yyyy-MM-dd"),
        (#"(0[1-9]|[12]\d|3[01])[-_.](0[1-9]|1[0-2])[-_.](19|20)\d{2}"#, "dd-MM-yyyy"),
        (#"(?<!\d)(19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])(?!\d)"#, "yyyyMMdd"),
    ]
    /// A date already written in the name (2025-03-14, 14.03.2025, 20250314): kept instead of the file's own date.
    private static var formatters: [String: DateFormatter] = [:]
    private static let fmtLock = NSLock()
    static func dateFormatter(_ f: String) -> DateFormatter {
        fmtLock.lock(); defer { fmtLock.unlock() }
        if let d = formatters[f] { return d }
        let d = DateFormatter(); d.dateFormat = f; d.isLenient = false; formatters[f] = d; return d
    }
    static func nameDate(_ url: URL) -> Date? {
        let n = url.deletingPathExtension().lastPathComponent
        for (p, fmt) in datePatterns {
            guard let r = n.range(of: p, options: .regularExpression) else { continue }
            let raw = n[r].replacingOccurrences(of: "_", with: "-").replacingOccurrences(of: ".", with: "-")
            if let v = dateFormatter(fmt).date(from: raw) { return v }
        }
        return nil
    }
    /// The words of the current name without dates, "copy", "(2)" or "final final": what the person called the file.
    static func oldDesc(_ url: URL) -> String? {
        var n = url.deletingPathExtension().lastPathComponent
        for (p, _) in datePatterns { n = n.replacingOccurrences(of: p, with: " ", options: .regularExpression) }
        n = n.replacingOccurrences(of: #"[_\-]+"#, with: " ", options: .regularExpression)
        n = n.replacingOccurrences(of: #"(?i)\b(copy|bản sao)\b|\(\d+\)|\s\d{1,2}$"#, with: " ", options: .regularExpression)
        let c = clean(n)
        return c.isEmpty ? nil : c
    }
    static let tf: DateFormatter = { let d = DateFormatter(); d.dateFormat = "HH.mm.ss"; return d }()
    /// Extensions in lower case, and .jpeg shortened to .jpg, so the same kind of file always ends the same way.
    static func normExt(_ e: String) -> String { let x = e.lowercased(); return x == "jpeg" ? "jpg" : x }
    static func stripAccents(_ s: String) -> String {
        s.replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "D").folding(options: .diacriticInsensitive, locale: Locale(identifier: "vi"))
    }
    /// Build a name from a rule. seq is the file's number within its folder (001, 002...).
    static func makeName(_ f: OrgFile, _ r: NameRule, seq: Int, parent: String) -> String {
        var parts: [String] = []
        for part in r.parts {
            var p: String
            switch part.kind {
            case .date: p = df.string(from: nameDate(f.url) ?? f.date ?? Date())
            case .time: p = tf.string(from: f.date ?? Date())
            case .parent: p = clean(parent)
            case .kind: p = f.group.label
            case .desc: p = f.desc ?? f.group.label
            case .seq: p = String(format: "%03d", seq)
            case .old: p = clean(f.url.deletingPathExtension().lastPathComponent)
            // Typed text is kept as typed, only characters Finder refuses are dropped.
            case .text: p = part.text.replacingOccurrences(of: #"[/:\\\n\r\t]"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            }
            if r.noAccents { p = stripAccents(p) }
            if r.lower { p = p.lowercased() }
            if r.noAccents && r.lower { p = p.replacingOccurrences(of: " ", with: "-") }
            if !p.isEmpty { parts.append(p) }
        }
        let e = normExt(f.url.pathExtension)
        let stem = safeStem(parts.joined(separator: r.sep), ext: e)
        return stem + (e.isEmpty ? "" : "." + e)
    }
    /// The first line of text that reads like a title: 3 to 60 characters, mostly letters, not a known heading word.
    static func titleLine(_ text: String) -> String? {
        let skip = Set(["curriculum vitae", "resume", "résumé", "hóa đơn", "hoá đơn", "hóa đơn bán hàng", "hoá đơn bán hàng", "invoice", "receipt", "biên lai", "cv"].map(fold))
        for l in text.split(whereSeparator: \.isNewline).prefix(8) {
            let s = l.trimmingCharacters(in: .whitespaces)
            let letters = s.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
            guard s.count >= 3, s.count <= 60, letters * 10 >= s.count * 6, !skip.contains(fold(s)) else { continue }
            return s
        }
        return nil
    }

    // MARK: content (Vision + PDFKit)
    static let receiptWords = ["hóa đơn", "hoá đơn", "biên lai", "invoice", "receipt", "tổng cộng", "subtotal", "total", "vat", "thanh toán", "payment", "order #", "mã đơn", "tax"]
    static let cvWords = ["curriculum vitae", "resume", "résumé", "kinh nghiệm làm việc", "work experience", "education", "học vấn", "kỹ năng", "skills", "mục tiêu nghề nghiệp"]
    static let vi: [String: String] = [
        "food": "Đồ ăn", "meal": "Đồ ăn", "dessert": "Đồ ngọt", "drink": "Đồ uống", "beverage": "Đồ uống", "wine": "Rượu vang", "cocktail": "Cocktail",
        "coffee": "Cà phê", "bottle": "Chai", "dog": "Chó", "cat": "Mèo", "animal": "Động vật", "bird": "Chim", "people": "Người", "adult": "Người",
        "child": "Trẻ em", "baby": "Em bé", "beach": "Biển", "sea": "Biển", "ocean": "Biển", "sky": "Bầu trời", "mountain": "Núi", "plant": "Cây",
        "tree": "Cây", "flower": "Hoa", "car": "Ô tô", "vehicle": "Xe", "building": "Toà nhà", "city": "Thành phố", "interior_room": "Trong nhà",
        "sunset_sunrise": "Hoàng hôn", "night_sky": "Trời đêm", "document": "Giấy tờ", "receipt": "Hoá đơn", "book": "Sách", "art": "Nghệ thuật",
        "illustrations": "Minh hoạ", "computer": "Máy tính", "screenshot": "Ảnh màn hình", "text": "Có chữ", "clothing": "Quần áo", "shoes": "Giày",
        "furniture": "Đồ nội thất", "outdoor": "Ngoài trời", "blue_sky": "Trời xanh", "indoor": "Trong nhà", "portrait": "Chân dung", "selfie": "Ảnh tự chụp", "kitchen": "Bếp", "landscape": "Phong cảnh", "water": "Nước", "snow": "Tuyết", "party": "Tiệc",
    ]
    static let generic: Set<String> = ["printed_page", "structure", "material", "liquid", "container", "wood_processed", "textile", "paper", "consumer_electronics", "machine"]

    static func readText(_ u: URL) -> String {
        let e = u.pathExtension.lowercased()
        if e == "pdf", let d = PDFDocument(url: u) {
            var s = ""
            if let tt = d.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String, tt.count > 2,
               !["untitled", "microsoft word"].contains(where: { tt.lowercased().hasPrefix($0) }) { s = tt + "\n" }
            for i in 0..<min(2, d.pageCount) { s += d.page(at: i)?.string ?? "" }
            return s
        }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .fast
        if let langs = try? req.supportedRecognitionLanguages() { req.recognitionLanguages = ["vi-VT", "en-US"].filter { langs.contains($0) } }
        try? VNImageRequestHandler(url: u).perform([req])
        return (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }

    /// Words that make a screenshot a real document (bill, contract, ticket, statement, ID), not just a screen full of text.
    static let docWords = ["hợp đồng", "contract", "agreement", "vé", "ticket", "boarding pass", "booking", "đặt chỗ", "sao kê", "statement",
                           "số tài khoản", "account number", "căn cước", "passport", "hộ chiếu", "giấy phép", "license", "certificate", "chứng nhận"]
    /// Labels for an image. Measured on real files (29/10/2026): Apple returns "document" with exactly the same confidence as
    /// "screenshot" for every screen capture (it is the parent label), and guesses on tiny images sit around 0.5. So: skip tiny
    /// images, keep labels from 0.6 up, and drop "document" when it only comes along with "screenshot".
    static func labels(_ u: URL) -> [String] {
        let bytes = (try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        var side = 0
        if let src = CGImageSourceCreateWithURL(u as CFURL, nil), let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] {
            side = max(p[kCGImagePropertyPixelWidth] as? Int ?? 0, p[kCGImagePropertyPixelHeight] as? Int ?? 0)
        }
        if bytes < 20_000 || (side > 0 && side < 300) { return [] }
        let req = VNClassifyImageRequest()
        try? VNImageRequestHandler(url: u).perform([req])
        var obs = (req.results ?? []).filter { $0.confidence >= 0.6 && !generic.contains($0.identifier) }
        if obs.contains(where: { $0.identifier == "screenshot" }) { obs.removeAll { $0.identifier == "document" } }
        var out: [String] = []
        for o in obs.sorted(by: { $0.confidence > $1.confidence }) {
            let name = vi[o.identifier].map { appLang == "vi" ? $0 : o.identifier.replacingOccurrences(of: "_", with: " ").capitalized }
                ?? o.identifier.replacingOccurrences(of: "_", with: " ").capitalized
            if !out.contains(name) { out.append(name) }
            if out.count == 3 { break }
        }
        return out
    }

    /// Lowercase without accents ("Hóa đơn" -> "hoa don"), so text read without diacritics still matches.
    static func fold(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "đ", with: "d").folding(options: .diacriticInsensitive, locale: Locale(identifier: "vi"))
    }

    static func deep(_ f: inout OrgFile) {
        let e = f.url.pathExtension.lowercased()
        let image = ext[.images]!.contains(e) && e != "svg" && e != "psd"
        guard image || e == "pdf" else { return }
        let raw = readText(f.url)
        let text = fold(raw)
        let r = receiptWords.map(fold).filter { text.contains($0) }.count
        let c = cvWords.map(fold).filter { text.contains($0) }.count
        if r >= 2 { f.group = .receipts; f.why = t("Text in the file looks like a receipt or invoice", "Chữ trong file giống hoá đơn, biên lai") }
        else if c >= 2 { f.group = .cv; f.why = t("Text in the file looks like a CV", "Chữ trong file giống CV") }
        if image {
            f.tags = labels(f.url)
            // A screenshot of a bill, contract or ticket is still a document: add it back when the text says so.
            let doc = t("Document", "Giấy tờ")
            if f.tags.contains(t("Screenshot", "Ảnh màn hình")), !f.tags.contains(doc),
               r >= 2 || c >= 2 || docWords.map(fold).contains(where: { text.contains($0) }) {
                f.tags.insert(doc, at: min(1, f.tags.count))
            }
            if raw.count > 40, !f.tags.contains(t("Has text", "Có chữ")) { f.tags.append(t("Has text", "Có chữ")) }
        }
        f.tagOn = Set(f.tags)
        f.title = titleLine(raw)
        f.desc = describe(f, label: f.tags.first); f.needsName = meaningless(f.url)
    }
}

/// Notes are kept by Tidymint (a small JSON file), keyed by the file's path after organizing.
enum OrgNotes {
    static let path = Stats.dir + "/notes.json"
    static func load() -> [String: String] {
        guard let d = FileManager.default.contents(atPath: path), let m = try? JSONDecoder().decode([String: String].self, from: d) else { return [:] }
        return m
    }
    static func save(_ m: [String: String]) {
        try? FileManager.default.createDirectory(atPath: Stats.dir, withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(m) { try? d.write(to: URL(fileURLWithPath: path)) }
    }
}

@MainActor final class OrgVM: ObservableObject {
    @Published var folder: URL = Scanner.home.appendingPathComponent("Downloads") { didSet { dests = Self.loadDests(for: folder) } }
    @Published var readContent = true
    /// Sort into folders (one per group, inside the chosen folder unless the person picked another) or rename only.
    @Published var moveIntoFolders = UserDefaults.standard.object(forKey: "org-move") as? Bool ?? true {
        didSet { UserDefaults.standard.set(moveIntoFolders, forKey: "org-move"); recomputeNames() }
    }
    /// Include files in sub-folders. Those are renamed and tagged where they are; only loose files are sorted into folders.
    @Published var includeSub = UserDefaults.standard.bool(forKey: "org-sub") {
        didSet { UserDefaults.standard.set(includeSub, forKey: "org-sub") }
    }
    /// Where each group goes when sorting, remembered per chosen folder (key: group raw value).
    @Published var dests: [String: OrgDest] = OrgVM.loadDests(for: Scanner.home.appendingPathComponent("Downloads"))
    @Published var editingGroup: OrgGroup? = nil
    @Published var groupDraft = ""
    @Published var phase: Phase = .idle
    @Published var files: [OrgFile] = []
    @Published var progress = 0
    @Published var total = 0
    @Published var current = ""
    @Published var collapsed = Set<OrgGroup>()
    @Published var preset: NamePreset = NamePreset(rawValue: UserDefaults.standard.string(forKey: "org-preset") ?? "") ?? .dateDesc {
        didSet { UserDefaults.standard.set(preset.rawValue, forKey: "org-preset"); recomputeNames() }
    }
    @Published var custom: NameRule = (UserDefaults.standard.data(forKey: "org-custom")).flatMap { try? JSONDecoder().decode(NameRule.self, from: $0) }
        ?? NameRule(parts: [.init(kind: .date), .init(kind: .desc)], sep: " ", noAccents: false, lower: false) {
        didSet { if let d = try? JSONEncoder().encode(custom) { UserDefaults.standard.set(d, forKey: "org-custom") }; recomputeNames() }
    }
    @Published var renameAll = UserDefaults.standard.bool(forKey: "org-rename-all") {
        didSet { UserDefaults.standard.set(renameAll, forKey: "org-rename-all"); recomputeNames() }
    }
    @Published var showRule = false
    /// When a new name is taken by a byte-for-byte identical file, send the extra copy to the Trash instead of adding " 2".
    @Published var dedupe = UserDefaults.standard.object(forKey: "org-dedupe") as? Bool ?? true {
        didSet { UserDefaults.standard.set(dedupe, forKey: "org-dedupe"); validate() }
    }
    /// Keep Downloads tidy: new downloads go into their type folder on their own.
    @Published var watchDownloads = UserDefaults.standard.bool(forKey: "org-watch") {
        didSet { UserDefaults.standard.set(watchDownloads, forKey: "org-watch"); if watchDownloads { startWatch() } else { stopWatch() } }
    }
    var rule: NameRule { preset.rule ?? custom }
    @Published var editing: UUID? = nil
    @Published var result = ""
    @Published var canUndo = OrgVM.lastSession() != nil
    weak var vm: VM?
    static let sessionPath = Stats.dir + "/organize-last.json"

    var included: [OrgFile] { files.filter(\.include) }
    /// What the list shows: everything, only files that get a new name, or only files with a warning.
    enum Show: Int { case all, rename, check }
    @Published var show: Show = .all
    /// Show the plan as two folder trees (now / after Apply) instead of the grouped list.
    @Published var treeView = UserDefaults.standard.bool(forKey: "org-tree") { didSet { UserDefaults.standard.set(treeView, forKey: "org-tree") } }
    /// A file picked in the tree: the list scrolls to it and marks it.
    @Published var focus: UUID? = nil
    func reveal(_ id: UUID) {
        if let f = file(id) { collapsed.remove(f.group); if !shown(f) { show = .all } }
        focus = id; treeView = false
    }

    /// The two trees: where planned files are now, and where they will be after Apply (filtered like the list).
    func trees() -> (now: [OrgTreeRow], after: [OrgTreeRow]) {
        let inc = files.filter { $0.include && shown($0) }
        let by = Dictionary(uniqueKeysWithValues: files.filter(\.include).map { ($0.id, $0) })
        let c = ctx, base = folder.standardizedFileURL.path
        func rel(_ u: URL) -> [String] {
            let p = u.standardizedFileURL.path
            if p.hasPrefix(base + "/") { return String(p.dropFirst(base.count + 1)).split(separator: "/").map(String.init) }
            // A folder outside the chosen one shows as one "~/..." line.
            return [u.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"), u.lastPathComponent]
        }
        var now: [(path: [String], f: OrgFile, state: Int)] = [], after: [(path: [String], f: OrgFile, state: Int)] = []
        for f in inc {
            let to = Self.target(f, by, c)
            let changed = to.path != f.url.path
            now.append((rel(f.url), f, changed ? 3 : 0))
            // Show what will really happen: the numbered name, or a line saying it goes to the Trash.
            var p = rel(to)
            if let fa = f.fate { if fa.isEmpty { p[p.count - 1] += t("  → Trash", "  → Thùng rác") } else { p[p.count - 1] = fa } }
            after.append((p, f, f.warn != nil ? 2 : (changed ? 1 : 0)))
        }
        return (OrgTreeRow.build(now, root: folder, markNew: false), OrgTreeRow.build(after, root: folder, markNew: true))
    }
    func shown(_ f: OrgFile) -> Bool {
        switch show {
        case .all: return true
        case .rename: return f.include && f.renameOn && f.newName != nil
        case .check: return f.include && f.warn != nil
        }
    }
    var groups: [OrgGroup] { OrgGroup.allCases.filter { g in files.contains { $0.group == g && shown($0) } } }
    func idx(_ g: OrgGroup) -> [Int] { files.indices.filter { files[$0].group == g && shown(files[$0]) } }
    /// Files that did not go as planned in the last Apply, for the result screen.
    @Published var report: [OrgNote] = []

    func choose() {
        let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false; p.allowsMultipleSelection = false
        p.directoryURL = folder; p.prompt = t("Choose", "Chọn")
        guard p.runModal() == .OK, let u = p.url else { return }
        if OrgEngine.allowed(u) { folder = u; phase = .idle; files = [] }
        else {
            let a = NSAlert(); a.messageText = t("Pick a folder inside your home folder", "Chọn một thư mục bên trong thư mục người dùng")
            a.informativeText = t("Tidymint does not organize your whole home folder, Library or system folders.", "Tidymint không sắp xếp cả thư mục người dùng, thư mục Library hay thư mục hệ thống.")
            a.runModal()
        }
    }

    func plan() {
        guard OrgEngine.allowed(folder) else { return }
        phase = .scanning; progress = 0; result = ""
        let f = folder, deep = readContent, sub = includeSub
        Task.detached {
            let urls = sub ? OrgEngine.filesDeep(in: f) : OrgEngine.files(in: f)
            await MainActor.run { self.total = urls.count }
            var out: [OrgFile] = []
            for (i, u) in urls.enumerated() {
                var o = OrgEngine.quick(u)
                if deep { OrgEngine.deep(&o) }
                out.append(o)
                if i % 3 == 0 || i == urls.count - 1 {
                    let n = i + 1, name = u.lastPathComponent
                    await MainActor.run { self.progress = n; self.current = name }
                }
            }
            OrgEngine.linkPairs(&out)
            // A file that goes with another one is listed right under it.
            let lone = out.filter { $0.pairOf == nil }
            out = lone.flatMap { l in [l] + out.filter { $0.pairOf == l.id } }
            let notes = OrgNotes.load()
            for i in out.indices { out[i].note = notes[out[i].url.path] ?? "" }
            await MainActor.run { self.files = out; self.sameCache = [:]; self.show = .all; self.focus = nil; self.recomputeNames(); self.phase = .review; self.vm?.markDone(.organize) }
        }
    }

    /// Access by id, not by index: the list can change (apply, plan again) while a row is still on screen.
    func file(_ id: UUID) -> OrgFile? { files.first { $0.id == id } }
    func edit(_ id: UUID, check: Bool = true, _ change: (inout OrgFile) -> Void) {
        if let i = files.firstIndex(where: { $0.id == id }) { change(&files[i]); if check { validate() } }
    }
    func setGroup(_ id: UUID, _ g: OrgGroup) {
        guard let i = files.firstIndex(where: { $0.id == id }) else { return }
        files[i].group = g; files[i].desc = OrgEngine.describe(files[i], label: files[i].tags.first); recomputeNames()
    }

    /// Re-run the naming rule on every file (numbers restart in each destination folder, oldest first).
    /// Names the person typed are kept; a rename they switched off stays off. Files that go with another one take its name later.
    func recomputeNames() {
        let r = rule
        var counters: [String: Int] = [:]
        let order = files.indices.sorted { (files[$0].date ?? .distantPast, files[$0].name) < (files[$1].date ?? .distantPast, files[$1].name) }
        for i in order where files[i].pairOf == nil {
            if files[i].nameEdited { continue }
            guard renameAll || files[i].needsName else { files[i].newName = nil; files[i].renameOn = false; continue }
            // Numbers restart per destination folder: the type folder when moving, otherwise the folder the file sits in.
            let own = files[i].url.deletingLastPathComponent()
            let mv = moves(files[i])
            let key = mv ? destURL(files[i].group).standardizedFileURL.path : own.standardizedFileURL.path
            let parent = mv ? folder.lastPathComponent : own.lastPathComponent
            counters[key, default: 0] += 1
            let n = OrgEngine.makeName(files[i], r, seq: counters[key]!, parent: parent)
            let had = files[i].newName != nil
            files[i].newName = n == files[i].name ? nil : n
            if !had { files[i].renameOn = files[i].newName != nil }
            if files[i].newName == nil { files[i].renameOn = false }
        }
        validate()
    }
    var renameCount: Int { files.filter { $0.include && $0.renameOn && $0.newName != nil }.count }
    var warnCount: Int { files.filter { $0.include && $0.warn != nil }.count }
    var namedCount: Int { files.filter { $0.needsName }.count }
    /// Example of the current rule on the first file it applies to, for the rule editor.
    var example: String {
        let f = files.first { $0.pairOf == nil && (renameAll || $0.needsName) } ?? files.first
        guard let f else { return "" }
        return OrgEngine.makeName(f, rule, seq: 1, parent: moves(f) ? folder.lastPathComponent : f.url.deletingLastPathComponent().lastPathComponent)
    }

    // MARK: destination folders

    nonisolated static let destKey = "org-dest"
    nonisolated static func allDests() -> [String: [String: OrgDest]] {
        UserDefaults.standard.data(forKey: destKey).flatMap { try? JSONDecoder().decode([String: [String: OrgDest]].self, from: $0) } ?? [:]
    }
    nonisolated static func loadDests(for f: URL) -> [String: OrgDest] { allDests()[f.standardizedFileURL.path] ?? [:] }
    func saveDests() {
        var all = Self.allDests(); all[folder.standardizedFileURL.path] = dests.isEmpty ? nil : dests
        if let d = try? JSONEncoder().encode(all) { UserDefaults.standard.set(d, forKey: Self.destKey) }
    }
    /// A folder the person picked, or a folder named after the group (or their name for it) inside the chosen folder.
    static func destURL(_ g: OrgGroup, _ folder: URL, _ d: [String: OrgDest]) -> URL {
        if let p = d[g.rawValue]?.path { return URL(fileURLWithPath: p, isDirectory: true) }
        if let n = d[g.rawValue]?.name { return folder.appendingPathComponent(n, isDirectory: true) }
        // A folder made earlier keeps being used when the app language changes ("Images" stays, no second "Ảnh").
        for n in [g.label, g.names.0, g.names.1] where isDir(folder.appendingPathComponent(n)) { return folder.appendingPathComponent(n, isDirectory: true) }
        return folder.appendingPathComponent(g.label, isDirectory: true)
    }
    nonisolated static func isDir(_ u: URL) -> Bool { var d: ObjCBool = false; return FileManager.default.fileExists(atPath: u.path, isDirectory: &d) && d.boolValue }
    /// Keep Downloads tidy only uses folders inside the watched folder: a group set to go elsewhere uses its default folder there.
    nonisolated static func autoDests(for dir: URL) -> [String: OrgDest] {
        let base = dir.standardizedFileURL.path + "/"
        return loadDests(for: dir).filter { $0.value.path.map { URL(fileURLWithPath: $0).standardizedFileURL.path.hasPrefix(base) } ?? true }
    }
    func destURL(_ g: OrgGroup) -> URL { Self.destURL(g, folder, dests) }
    func isInside(_ u: URL) -> Bool { u.standardizedFileURL.path.hasPrefix(folder.standardizedFileURL.path + "/") }
    /// Short path for the screen: "Downloads/Images" inside the chosen folder, "~/Documents/Work" elsewhere.
    func destLabel(_ g: OrgGroup) -> String {
        let u = destURL(g).standardizedFileURL, base = folder.standardizedFileURL.path
        if isInside(u) { return folder.lastPathComponent + String(u.path.dropFirst(base.count)) }
        return u.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
    func destExists(_ g: OrgGroup) -> Bool { var d: ObjCBool = false; return FileManager.default.fileExists(atPath: destURL(g).path, isDirectory: &d) && d.boolValue }
    /// A file sorts into its group folder only when it sits loose in the chosen folder.
    func moves(_ f: OrgFile) -> Bool { moveIntoFolders && f.url.deletingLastPathComponent().standardizedFileURL.path == folder.standardizedFileURL.path }
    func groupMoves(_ g: OrgGroup) -> Bool { files.contains { $0.group == g && $0.include && $0.pairOf == nil && moves($0) } }
    var movingGroups: [OrgGroup] { OrgGroup.allCases.filter { groupMoves($0) } }
    var newDirCount: Int { Set(movingGroups.filter { !destExists($0) }.map { destURL($0).standardizedFileURL.path }).count }
    var outsideGroups: [OrgGroup] { movingGroups.filter { !isInside(destURL($0)) && destURL($0).standardizedFileURL.path != folder.standardizedFileURL.path } }
    func setDest(_ g: OrgGroup, _ d: OrgDest?) { dests[g.rawValue] = d; saveDests(); recomputeNames() }
    func renameDest(_ g: OrgGroup, _ typed: String) {
        let n = typed.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        let clean = n.hasPrefix(".") ? String(n.drop { $0 == "." }) : n
        setDest(g, clean.isEmpty || clean == g.label ? nil : OrgDest(name: clean))
        editingGroup = nil
    }
    func chooseDest(_ g: OrgGroup) {
        let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false; p.allowsMultipleSelection = false; p.canCreateDirectories = true
        p.directoryURL = destExists(g) ? destURL(g) : folder; p.prompt = t("Use this folder", "Dùng thư mục này")
        p.message = t("Files in \(g.label) will go into the folder you pick. You can make a new folder here.",
                      "File nhóm \(g.label) sẽ vào thư mục bạn chọn. Có thể tạo thư mục mới ngay tại đây.")
        guard p.runModal() == .OK, let u = p.url else { return }
        guard OrgEngine.allowed(u) else {
            let a = NSAlert(); a.messageText = t("Pick a folder inside your home folder", "Chọn một thư mục bên trong thư mục người dùng")
            a.informativeText = t("Tidymint does not move files into Library or system folders.", "Tidymint không chuyển file vào Library hay thư mục hệ thống.")
            a.runModal(); return
        }
        setDest(g, OrgDest(path: u.standardizedFileURL.path))
    }

    // MARK: where each file ends up

    struct Ctx { let folder: URL; let moving: Bool; var dests: [String: OrgDest] = [:] }
    var ctx: Ctx { Ctx(folder: folder, moving: moveIntoFolders, dests: dests) }

    /// The name a file will have after Apply. A typed name is cleaned the same way Apply cleans it;
    /// a file that goes with another one takes that file's new name with its own extension.
    static func finalName(_ f: OrgFile, _ by: [UUID: OrgFile]) -> String {
        let ext = OrgEngine.normExt(f.url.pathExtension)
        if let l = f.pairOf.flatMap({ by[$0] }) {
            let ln = finalName(l, by)
            let stem = (ln as NSString).deletingPathExtension
            guard stem != l.url.deletingPathExtension().lastPathComponent else { return f.name }
            return stem + (ext.isEmpty ? "" : "." + ext)
        }
        guard f.renameOn, let typed = f.newName else { return f.name }
        let nn = OrgEngine.safeStem(stripExt(typed, f), ext: ext)
        return nn.isEmpty ? f.name : nn + (ext.isEmpty ? "" : "." + ext)
    }
    /// A typed name may or may not include the extension.
    static func stripExt(_ typed: String, _ f: OrgFile) -> String {
        var nn = typed.trimmingCharacters(in: .whitespaces)
        for e in [f.url.pathExtension, OrgEngine.normExt(f.url.pathExtension)] where !e.isEmpty && nn.lowercased().hasSuffix("." + e.lowercased()) { nn = String(nn.dropLast(e.count + 1)) }
        return nn.trimmingCharacters(in: .whitespaces)
    }
    static func target(_ f: OrgFile, _ by: [UUID: OrgFile], _ c: Ctx) -> URL {
        let dir: URL
        if let l = f.pairOf.flatMap({ by[$0] }) { dir = target(l, by, c).deletingLastPathComponent() }
        else {
            let own = f.url.deletingLastPathComponent()
            // Only loose files are sorted; files already in a sub-folder stay there.
            dir = c.moving && own.standardizedFileURL.path == c.folder.standardizedFileURL.path ? Self.destURL(f.group, c.folder, c.dests) : own
        }
        return dir.appendingPathComponent(finalName(f, by))
    }

    var sameCache: [String: Bool] = [:]
    func same(_ a: URL, _ b: URL) -> Bool {
        let k = a.path + "|" + b.path
        if let v = sameCache[k] { return v }
        let v = OrgEngine.likelyIdentical(a, b); sameCache[k] = v; return v   // preview only; Apply compares every byte
    }

    /// Check the plan before anything moves: two files given the same name, a name already taken, an identical copy
    /// already there, a typed name that had to be fixed. Each row shows what will happen instead.
    func validate() {
        // Files that go with another one follow its checkbox, rename switch and group.
        let lead = Dictionary(uniqueKeysWithValues: files.filter { $0.pairOf == nil }.map { ($0.id, $0) })
        for i in files.indices { if let l = files[i].pairOf.flatMap({ lead[$0] }) { files[i].include = l.include; files[i].renameOn = l.renameOn; files[i].group = l.group } }
        let inc = files.filter(\.include)
        let by = Dictionary(uniqueKeysWithValues: inc.map { ($0.id, $0) })
        let c = ctx, fm = FileManager.default
        var tg: [UUID: URL] = [:]
        for f in inc { tg[f.id] = Self.target(f, by, c) }
        func stays(_ f: OrgFile) -> Bool { tg[f.id]!.path.lowercased() == f.url.path.lowercased() }
        // Paths freed during Apply because their file moves away.
        let leaving = Set(inc.filter { !stays($0) }.map { $0.url.path.lowercased() })
        // Files that keep their place claim their name first.
        var claimed: [String: OrgFile] = [:]
        for f in inc where stays(f) { claimed[f.url.path.lowercased()] = f }
        var warn: [UUID: String] = [:], fate: [UUID: String] = [:]
        // The name a clash will really get: the first free "name 2", "name 3"... among files and names already handed out.
        var given = Set<String>()
        func numbered(_ to: URL) -> String {
            let base = to.deletingPathExtension().lastPathComponent, e = to.pathExtension
            var n = 2
            while true {
                let c = to.deletingLastPathComponent().appendingPathComponent("\(base) \(n)" + (e.isEmpty ? "" : ".\(e)"))
                if !given.contains(c.path.lowercased()) && !fm.fileExists(atPath: c.path) { given.insert(c.path.lowercased()); return c.lastPathComponent }
                n += 1
            }
        }
        for f in inc where !stays(f) {
            let to = tg[f.id]!, k = to.path.lowercased()
            if let first = claimed[k] {
                let dup = dedupe && same(f.url, first.url)
                warn[f.id] = dup
                    ? t("Identical to \(first.name): this copy goes to the Trash", "Giống hệt \(first.name): bản này vào Thùng rác")
                    : t("Same new name as \(first.name): gets \" 2\"", "Trùng tên mới với \(first.name): thêm \" 2\"")
                fate[f.id] = dup ? "" : numbered(to)
            } else if fm.fileExists(atPath: to.path), !leaving.contains(k) {
                let dup = dedupe && same(f.url, to)
                warn[f.id] = dup
                    ? t("An identical \(to.lastPathComponent) is already there: this copy goes to the Trash", "Đã có \(to.lastPathComponent) giống hệt: bản này vào Thùng rác")
                    : t("\(to.lastPathComponent) already exists: gets \" 2\"", "Đã có file \(to.lastPathComponent): thêm \" 2\"")
                fate[f.id] = dup ? "" : numbered(to)
            } else if given.contains(k) {
                // Its own new name was already handed to another file as "name 2": Apply would number this one too.
                warn[f.id] = t("Same new name as another file: gets a number", "Trùng tên mới với file khác: thêm số")
                fate[f.id] = numbered(to)
            } else { claimed[k] = f; given.insert(k) }
        }
        for f in inc where f.pairOf == nil && f.renameOn {
            guard let typed = f.newName else { continue }
            let raw = Self.stripExt(typed, f), safe = OrgEngine.safeStem(raw, ext: OrgEngine.normExt(f.url.pathExtension))
            var w: String? = nil
            if safe.isEmpty { w = t("Empty name: keeps the old name", "Tên trống: giữ tên cũ") }
            else if safe != raw { w = t("Name fixed to be valid: \(safe)", "Tên được sửa cho hợp lệ: \(safe)") }
            if let w { warn[f.id] = warn[f.id].map { $0 + " · " + w } ?? w }
        }
        for i in files.indices {
            files[i].warn = warn[files[i].id]
            files[i].fate = fate[files[i].id]
            if files[i].pairOf != nil {
                let n = Self.finalName(files[i], by)
                files[i].newName = n == files[i].name ? nil : n
            }
        }
    }

    // MARK: carrying out a plan

    struct Outcome { var moves: [OrgMove] = []; var made: [String] = []; var moved = 0, tagged = 0, fail = 0, trashed = 0; var notes: [OrgNote] = [] }
    /// Plain reason for a refused move, instead of the system's English message.
    static func reason(_ e: Error) -> String {
        switch (e as? CocoaError)?.code {
        case .fileWriteNoPermission?, .fileReadNoPermission?: return t("No permission to change it", "Không có quyền đổi file này")
        case .fileNoSuchFile?, .fileReadNoSuchFile?: return t("The file is no longer there", "File không còn ở đó")
        case .fileWriteVolumeReadOnly?: return t("The disk is read-only", "Ổ đĩa chỉ cho đọc")
        case .fileWriteFileExists?: return t("That name is already taken", "Tên này đã có file khác")
        case .fileLocking?: return t("The file is locked or in use", "File đang bị khoá hoặc đang mở")
        default: return (e as NSError).localizedDescription
        }
    }

    /// Never overwrite: "name 2.ext", "name 3.ext"... The file itself does not count as taken (a change of case only).
    static func free(_ u: URL, keeping src: URL) -> URL {
        let fm = FileManager.default
        if !fm.fileExists(atPath: u.path) || OrgEngine.sameFile(u, src) { return u }
        let base = u.deletingPathExtension().lastPathComponent, e = u.pathExtension, dir = u.deletingLastPathComponent()
        var n = 2
        while true {
            let c = dir.appendingPathComponent("\(base) \(n)" + (e.isEmpty ? "" : ".\(e)"))
            if !fm.fileExists(atPath: c.path) || OrgEngine.sameFile(c, src) { return c }
            n += 1
        }
    }

    /// Carry out a plan. A file whose new name is still held by another planned file waits until that file has moved;
    /// a real clash gets " 2", or goes to the Trash when it is a byte-for-byte copy (if that switch is on).
    /// Files that go with another one follow it last, so they get its final name even if that got " 2".
    static func execute(_ list: [OrgFile], _ c: Ctx, dedupe: Bool) -> Outcome {
        let fm = FileManager.default
        var o = Outcome(), notes = OrgNotes.load()
        let by = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
        var dest: [UUID: URL] = [:], order: [UUID] = []
        func ensureDir(_ d: URL) -> Bool {
            if fm.fileExists(atPath: d.path) { return true }
            do { try fm.createDirectory(at: d, withIntermediateDirectories: false); o.made.append(d.path); return true } catch { return false }
        }
        func place(_ f: OrgFile, _ want: URL, mayTrash: Bool) {
            var to = want
            defer { if dest[f.id] != nil { order.append(f.id) } }
            // Moved or deleted since the plan was made: nothing to do, say so.
            guard fm.fileExists(atPath: f.url.path) else {
                o.fail += 1
                o.notes.append(OrgNote(kind: .skipped, name: f.name, detail: t("The file is no longer there (moved or deleted after planning)", "File không còn ở đó (đã bị chuyển hoặc xoá sau khi lập kế hoạch)")))
                return
            }
            if to.path == f.url.path { dest[f.id] = f.url; return }
            guard ensureDir(to.deletingLastPathComponent()) else {
                o.fail += 1; dest[f.id] = f.url
                o.notes.append(OrgNote(kind: .skipped, name: f.name, detail: t("Could not create the folder \(to.deletingLastPathComponent().lastPathComponent)", "Không tạo được thư mục \(to.deletingLastPathComponent().lastPathComponent)")))
                return
            }
            if fm.fileExists(atPath: to.path) && !OrgEngine.sameFile(to, f.url) {
                if mayTrash && dedupe && OrgEngine.identical(f.url, to) {
                    var res: NSURL?
                    if (try? fm.trashItem(at: f.url, resultingItemURL: &res)) != nil {
                        o.trashed += 1
                        o.moves.append(OrgMove(from: f.url.path, to: (res as URL?)?.path ?? "", addedTags: [], trashed: true))
                        notes.removeValue(forKey: f.url.path)
                        o.notes.append(OrgNote(kind: .trashed, name: f.name, detail: t("Identical to \(to.lastPathComponent), this copy is in the Trash", "Giống hệt \(to.lastPathComponent), bản này đã vào Thùng rác")))
                        return
                    }
                }
                let taken = to.lastPathComponent
                to = free(to, keeping: f.url)
                if to.lastPathComponent != taken {
                    o.notes.append(OrgNote(kind: .numbered, name: f.name, detail: t("\(taken) was taken, named \(to.lastPathComponent)", "Đã có \(taken), nên đặt là \(to.lastPathComponent)")))
                }
            }
            do { try OrgEngine.move(f.url, to) }
            catch {
                // The new name was refused: keep the original name rather than skip the file.
                let why = reason(error)
                to = free(to.deletingLastPathComponent().appendingPathComponent(f.name), keeping: f.url)
                if to.path != f.url.path {
                    do { try OrgEngine.move(f.url, to) } catch {
                        o.fail += 1; dest[f.id] = f.url
                        o.notes.append(OrgNote(kind: .skipped, name: f.name, detail: reason(error)))
                        return
                    }
                }
                o.notes.append(OrgNote(kind: to.path == f.url.path ? .skipped : .kept, name: f.name, detail: t("Could not use the new name (\(why)), kept the old one", "Không đặt được tên mới (\(why)), giữ tên cũ")))
            }
            dest[f.id] = to
            if to.path != f.url.path { o.moved += 1 }
        }
        var pending = list.filter { $0.pairOf.flatMap { by[$0] } == nil }
        let followers = list.filter { $0.pairOf.flatMap { by[$0] } != nil }
        while !pending.isEmpty {
            // Who still sits on a path it is about to leave.
            var owner: [String: UUID] = [:]
            for f in pending where target(f, by, c).path.lowercased() != f.url.path.lowercased() { owner[f.url.path.lowercased()] = f.id }
            var later: [OrgFile] = []
            for f in pending {
                let want = target(f, by, c), k = want.path.lowercased()
                if k != f.url.path.lowercased(), let w = owner[k], w != f.id, dest[w] == nil { later.append(f); continue }
                place(f, want, mayTrash: true)
            }
            // A loop (A wants B's name and B wants A's): " 2" breaks it.
            if later.count == pending.count { for f in later { place(f, target(f, by, c), mayTrash: true) }; break }
            pending = later
        }
        for f in followers {
            guard let l = by[f.pairOf!], let ld = dest[l.id] else { continue }   // its file went to the Trash or failed: leave it
            let ext = OrgEngine.normExt(f.url.pathExtension), stem = ld.deletingPathExtension().lastPathComponent
            let name = stem == l.url.deletingPathExtension().lastPathComponent ? f.name : stem + (ext.isEmpty ? "" : "." + ext)
            place(f, ld.deletingLastPathComponent().appendingPathComponent(name), mayTrash: false)
        }
        for id in order {
            guard let f = by[id], let d = dest[id] else { continue }
            let old = (try? d.resourceValues(forKeys: [.tagNamesKey]).tagNames) ?? []
            let add = f.tags.filter { f.tagOn.contains($0) && !old.contains($0) }
            if !add.isEmpty {
                do { try (d as NSURL).setResourceValue(old + add, forKey: .tagNamesKey); o.tagged += 1 } catch { }
            }
            notes.removeValue(forKey: f.url.path)
            if !f.note.trimmingCharacters(in: .whitespaces).isEmpty { notes[d.path] = f.note }
            o.moves.append(OrgMove(from: f.url.path, to: d.path, addedTags: add, fileID: OrgVM.fileNumber(d)))
        }
        OrgNotes.save(notes)
        return o
    }

    /// Apply the reviewed plan: optional move into a subfolder per group, optional rename, tags and notes.
    func apply() {
        validate()
        let away = outsideGroups.map { "\(destURL($0).lastPathComponent) → \(destLabel($0))" }
        let o = Self.execute(included, ctx, dedupe: dedupe)
        report = o.notes
        if !o.moves.isEmpty {
            let s = OrgSession(folder: folder.path, date: Date(), moves: o.moves, madeDirs: o.made)
            if let d = try? JSONEncoder().encode(s) { try? d.write(to: URL(fileURLWithPath: OrgVM.sessionPath)) }
            shownSession = OrgVM.sessionPath
            // Files the person just organized by hand are theirs: Keep Downloads tidy must not sort them again.
            for m in o.moves where m.trashed != true {
                watchSeen.insert(m.to)
                if let id = m.fileID { movedIDs[id] = Date() }
            }
            saveMoved()
        }
        canUndo = OrgVM.lastSession() != nil
        let dup = o.trashed > 0 ? t(" \(o.trashed) identical copies went to the Trash.", " \(o.trashed) bản trùng y hệt đã vào Thùng rác.") : ""
        result = t("Organized \(o.moved) files, tagged \(o.tagged).", "Đã sắp xếp \(o.moved) file, gắn tag \(o.tagged) file.") + dup + (o.fail > 0 ? t(" \(o.fail) skipped.", " Bỏ qua \(o.fail) file.") : "")
            + (away.isEmpty ? "" : t(" Moved out of \(folder.lastPathComponent): ", " Chuyển ra ngoài \(folder.lastPathComponent): ") + away.joined(separator: ", ") + ".")
        vm?.log(t("Organized \(folder.lastPathComponent): moved or renamed \(o.moved) files, tagged \(o.tagged)", "Sắp xếp \(folder.lastPathComponent): chuyển hoặc đổi tên \(o.moved) file, gắn tag \(o.tagged) file")
                + (o.trashed > 0 ? t(", \(o.trashed) identical copies to the Trash", ", \(o.trashed) bản trùng vào Thùng rác") : "")
                + (o.fail > 0 ? t(", skipped \(o.fail)", ", bỏ qua \(o.fail)") : ""))
        phase = .done; files = []
    }

    static func load(_ p: String) -> OrgSession? {
        guard let d = FileManager.default.contents(atPath: p) else { return nil }
        return try? JSONDecoder().decode(OrgSession.self, from: d)
    }
    /// The newest thing to undo: the last manual organize or the newest automatic batch.
    static func latest() -> (String, OrgSession)? {
        let manual = load(sessionPath).map { (sessionPath, $0) }
        let auto = history().first.map { ("auto:" + ($0.id ?? ""), $0) }
        return [manual, auto].compactMap { $0 }.max { $0.1.date < $1.1.date }
    }
    static let historyPath = Stats.dir + "/organize-auto-history.json"
    /// Automatic batches from the last 7 days, newest first. Each one can be undone on its own.
    static func history() -> [OrgSession] {
        var h = FileManager.default.contents(atPath: historyPath).flatMap { try? JSONDecoder().decode([OrgSession].self, from: $0) } ?? []
        // Older builds kept one automatic session per day in a single file.
        if var old = load(autoPath) {
            old.id = old.id ?? UUID().uuidString; h.append(old); h.sort { $0.date > $1.date }
            try? FileManager.default.removeItem(atPath: autoPath); saveHistory(h)
        }
        let cut = Date().addingTimeInterval(-7 * 86400)
        return h.filter { $0.date > cut }
    }
    static func saveHistory(_ h: [OrgSession]) {
        let cut = Date().addingTimeInterval(-7 * 86400)
        let keep = Array(h.filter { $0.date > cut }.sorted { $0.date > $1.date }.prefix(300))
        try? FileManager.default.createDirectory(atPath: Stats.dir, withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(keep) { try? d.write(to: URL(fileURLWithPath: historyPath)) }
    }
    /// Undo one automatic batch (from the list or the notification).
    func undoBatch(_ id: String) {
        guard let s = Self.history().first(where: { $0.id == id }) else { return }
        // From a notification while a plan is open: undo, but keep the plan on screen.
        let keep = phase == .review || phase == .scanning ? phase : nil, msg = result
        revert(s, key: "auto:" + id)
        if let keep { phase = keep; result = msg }
    }
    @Published var historyOpen = false
    @Published var historyTick = 0
    static func lastSession() -> OrgSession? { latest()?.1 }

    /// Put every file back where it was (also copies sent to the Trash), remove the tags this session added,
    /// remove folders it created if now empty.
    /// The manual organize whose result is on screen: its Undo button undoes that one, even if an automatic batch ran since.
    var shownSession: String? = nil
    func undo() {
        if let p = shownSession, phase == .done, let s = OrgVM.load(p) { shownSession = nil; revert(s, key: p); return }
        guard let (path, s) = OrgVM.latest() else { return }
        revert(s, key: path)
    }
    func revert(_ s: OrgSession, key path: String) {
        let fm = FileManager.default
        var back = 0, fail = 0, notes = OrgNotes.load()
        for m in s.moves.reversed() {
            let to = URL(fileURLWithPath: m.to), from = URL(fileURLWithPath: m.from)
            if !m.addedTags.isEmpty, m.fileID == nil || OrgVM.fileNumber(to) == m.fileID, let cur = try? to.resourceValues(forKeys: [.tagNamesKey]).tagNames {
                try? (to as NSURL).setResourceValue(cur.filter { !m.addedTags.contains($0) }, forKey: .tagNamesKey)
            }
            if let n = notes.removeValue(forKey: m.to) { notes[m.from] = n }
            if m.to != m.from {
                guard !m.to.isEmpty, fm.fileExists(atPath: m.to), !fm.fileExists(atPath: m.from) || OrgEngine.sameFile(to, from) else { fail += 1; continue }
                // Another file now sits at the destination (the original was deleted, a new one took its name): leave it.
                if let id = m.fileID, m.trashed != true, OrgVM.fileNumber(to) != id { fail += 1; continue }
                do { try OrgEngine.move(to, from); back += 1 } catch { fail += 1 }
            }
        }
        for d in s.madeDirs.reversed() where ((try? fm.contentsOfDirectory(atPath: d))?.filter { $0 != ".DS_Store" }.isEmpty ?? false) {
            try? fm.removeItem(atPath: d + "/.DS_Store"); _ = rmdir(d)   // rmdir fails if a file arrived meanwhile: never deletes content
        }
        OrgNotes.save(notes)
        if path.hasPrefix("auto:") { Self.saveHistory(Self.history().filter { $0.id != s.id }) } else { try? fm.removeItem(atPath: path) }
        historyTick += 1
        report = []
        canUndo = OrgVM.lastSession() != nil
        result = t("Put back \(back) files.", "Đã đưa \(back) file về chỗ cũ.") + (fail > 0 ? t(" \(fail) could not be moved back.", " \(fail) file không đưa về được.") : "")
        vm?.log(t("Undid organizing \((s.folder as NSString).lastPathComponent): \(back) files back", "Hoàn tác sắp xếp \((s.folder as NSString).lastPathComponent): đưa \(back) file về chỗ cũ") + (fail > 0 ? t(", \(fail) could not be moved back", ", \(fail) file không đưa về được") : ""))
        phase = .done
    }

    // MARK: keep Downloads tidy

    static let autoPath = Stats.dir + "/organize-auto.json"
    /// The watched folder: Downloads, or a test folder given with `--watch-folder`.
    static var watchDir = Scanner.home.appendingPathComponent("Downloads")
    static let partialExt: Set<String> = ["crdownload", "download", "part", "partial", "tmp", "opdownload", "aria2"]
    private var watchTimer: Timer?
    private var watchSeen = Set<String>()
    private var watchSize: [String: Int64] = [:]
    private var watchBusy = false
    static let lastRunKey = "org-watch-last"

    /// Files Tidymint sorted, by file number (it survives renames and moves): one the person brings back to Downloads is left alone.
    nonisolated static let movedPath = Stats.dir + "/organize-auto-moved.json"
    private var movedIDs: [String: Date] = OrgVM.loadMoved()
    nonisolated static func loadMoved() -> [String: Date] {
        let m = FileManager.default.contents(atPath: movedPath).flatMap { try? JSONDecoder().decode([String: Date].self, from: $0) } ?? [:]
        let cut = Date().addingTimeInterval(-90 * 86400)
        return m.filter { $0.value > cut }
    }
    func saveMoved() { if let d = try? JSONEncoder().encode(movedIDs) { try? d.write(to: URL(fileURLWithPath: Self.movedPath)) } }
    nonisolated static func fileNumber(_ u: URL) -> String? {
        ((try? FileManager.default.attributesOfItem(atPath: u.path))?[.systemFileNumber] as? NSNumber).map { $0.stringValue }
    }

    /// Never touched by Keep Downloads tidy: ".torrent" is an extension, anything else is part of the name. Comma separated.
    @Published var exclude = UserDefaults.standard.string(forKey: "org-exclude") ?? "" {
        didSet { UserDefaults.standard.set(exclude, forKey: "org-exclude") }
    }
    nonisolated static func excluded(_ u: URL, _ pats: String) -> Bool {
        let n = u.lastPathComponent.lowercased(), e = u.pathExtension.lowercased()
        for raw in pats.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" }) {
            let p = raw.trimmingCharacters(in: .whitespaces).lowercased()
            if p.isEmpty { continue }
            if p.hasPrefix("."), !p.dropFirst().contains(".") { if e == String(p.dropFirst()) { return true } }
            else if n.contains(p) { return true }
        }
        return false
    }

    /// Watch Downloads while Tidymint runs (window or menu bar). Turning the switch on leaves files already there alone;
    /// when the app starts (catchUp), files that landed while it was closed are sorted too.
    /// A new file is moved once it has stopped changing for 2 minutes and no other app has it open.
    func startWatch(catchUp: Bool = false) {
        stopWatch()
        let since = catchUp ? (UserDefaults.standard.object(forKey: Self.lastRunKey) as? Date)?.addingTimeInterval(-300) : nil
        watchSeen = Set(OrgEngine.files(in: Self.watchDir).filter { u in
            guard let s = since, let added = (try? u.resourceValues(forKeys: [.addedToDirectoryDateKey]))?.addedToDirectoryDate else { return true }
            return added <= s
        }.map(\.path))
        UserDefaults.standard.set(Date(), forKey: Self.lastRunKey)
        watchTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { _ in Task { @MainActor in sharedOrg.watchTick() } }
    }
    func stopWatch() { watchTimer?.invalidate(); watchTimer = nil; watchSize = [:] }

    func watchTick() {
        UserDefaults.standard.set(Date(), forKey: Self.lastRunKey)
        // Not while the person is planning that same folder by hand.
        let busyHere = (phase == .scanning || phase == .review) && folder.standardizedFileURL.path == Self.watchDir.standardizedFileURL.path
        guard !watchBusy, !busyHere else { return }
        var ready: [URL] = []
        let now = Date(), pats = exclude
        let inDir = OrgEngine.files(in: Self.watchDir)
        let names = Set(inDir.map { $0.lastPathComponent.lowercased() })
        for u in inDir where !watchSeen.contains(u.path) {
            if Self.partialExt.contains(u.pathExtension.lowercased()) { continue }
            // Still downloading: the browser keeps a sibling "name.part" / "name.crdownload" next to an empty placeholder.
            let low = u.lastPathComponent.lowercased()
            if Self.partialExt.contains(where: { names.contains(low + "." + $0) }) { continue }
            // Brought back by the person after Tidymint sorted it, or on the do-not-touch list: leave it where it is.
            if let id = Self.fileNumber(u), movedIDs[id] != nil { watchSeen.insert(u.path); continue }
            if Self.excluded(u, pats) { watchSeen.insert(u.path); continue }
            let v = try? u.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(v?.fileSize ?? -1)
            if size == 0 { continue }   // an empty placeholder is never a finished download
            // Same size as last check and untouched for 2 minutes: the download has finished.
            if watchSize[u.path] == size, let m = v?.contentModificationDate, now.timeIntervalSince(m) > 120 { ready.append(u) }
            else { watchSize[u.path] = size }
        }
        guard !ready.isEmpty else { return }
        watchBusy = true
        let deep = readContent, r = rule, all = renameAll, dd = dedupe
        Task.detached {
            // A file still open in another app waits for the next check.
            let busy = OrgEngine.openPaths(ready)
            let free = ready.filter { !busy.contains($0.path) }
            var list: [OrgFile] = free.map { var o = OrgEngine.quick($0); if deep { OrgEngine.deep(&o) }; return o }
            OrgEngine.linkPairs(&list)
            let done = list
            await MainActor.run { sharedOrg.autoApply(done, rule: r, renameAll: all, dedupe: dd) }
        }
    }

    func autoApply(_ input: [OrgFile], rule r: NameRule, renameAll all: Bool, dedupe dd: Bool) {
        defer { watchBusy = false }
        for f in input { watchSeen.insert(f.url.path); watchSize.removeValue(forKey: f.url.path) }
        var list = input
        let dir = Self.watchDir, dd2 = Self.autoDests(for: dir)
        let lead = Dictionary(uniqueKeysWithValues: list.filter { $0.pairOf == nil }.map { ($0.id, $0) })
        for i in list.indices { if let l = list[i].pairOf.flatMap({ lead[$0] }) { list[i].group = l.group } }
        // Names follow the current rule: only names that say nothing, unless "rename all" is on. Numbers continue the folder's count.
        var counters: [String: Int] = [:]
        for i in list.indices where list[i].pairOf == nil && (all || list[i].needsName) {
            let g = list[i].group.label
            if counters[g] == nil { counters[g] = OrgEngine.files(in: Self.destURL(list[i].group, dir, dd2)).count }
            counters[g]! += 1
            let n = OrgEngine.makeName(list[i], r, seq: counters[g]!, parent: dir.lastPathComponent)
            if n != list[i].name { list[i].newName = n; list[i].renameOn = true }
        }
        let o = Self.execute(list, Ctx(folder: dir, moving: true, dests: dd2), dedupe: dd)
        guard !o.moves.isEmpty else { return }
        // Each batch is kept for 7 days and can be undone on its own.
        let s = OrgSession(folder: dir.path, date: Date(), moves: o.moves, madeDirs: o.made, auto: true, id: UUID().uuidString)
        Self.saveHistory([s] + Self.history())
        for m in o.moves where m.trashed != true { if let n = Self.fileNumber(URL(fileURLWithPath: m.to)) { movedIDs[n] = Date() } }
        saveMoved()
        canUndo = true; historyTick += 1
        vm?.log(t("Kept \(dir.lastPathComponent) tidy: moved \(o.moved) new files", "Tự xếp \(dir.lastPathComponent): chuyển \(o.moved) file mới")
                + (o.trashed > 0 ? t(", \(o.trashed) identical copies to the Trash", ", \(o.trashed) bản trùng vào Thùng rác") : ""))
        notifyAuto(s, moved: o.moved, trashed: o.trashed)
    }

    /// "Sorted 3 new downloads · Screenshots: 2 · Documents: 1", with Show in Finder and Undo.
    func notifyAuto(_ s: OrgSession, moved: Int, trashed: Int) {
        let kept = s.moves.filter { $0.trashed != true }
        let by = Dictionary(grouping: kept) { URL(fileURLWithPath: $0.to).deletingLastPathComponent().lastPathComponent }
        let c = UNMutableNotificationContent()
        c.title = t("Sorted \(moved) new downloads", "Đã xếp \(moved) file vừa tải về")
        c.body = by.keys.sorted().map { "\($0): \(by[$0]!.count)" }.joined(separator: " · ")
            + (trashed > 0 ? t(" · \(trashed) identical copies to the Trash", " · \(trashed) bản trùng vào Thùng rác") : "")
        c.categoryIdentifier = "org-auto"
        let dirs = Set(kept.map { URL(fileURLWithPath: $0.to).deletingLastPathComponent().path })
        let reveal = kept.count == 1 ? kept[0].to : (dirs.count == 1 ? dirs.first! : s.folder)
        c.userInfo = ["batch": s.id ?? "", "reveal": reveal]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: s.id ?? UUID().uuidString, content: c, trigger: nil))
    }
}

/// Notifications: shown while Tidymint is in front too; Show in Finder and Undo on a Keep Downloads tidy batch.
final class OrgNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = OrgNotifier()
    func install() {
        let open = UNNotificationAction(identifier: "open", title: t("Show in Finder", "Mở thư mục"), options: [.foreground])
        let undo = UNNotificationAction(identifier: "undo", title: t("Undo", "Hoàn tác"), options: [])
        let c = UNUserNotificationCenter.current()
        c.setNotificationCategories([UNNotificationCategory(identifier: "org-auto", actions: [open, undo], intentIdentifiers: [], options: [])])
        c.delegate = self
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) { done([.banner, .sound]) }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler done: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let batch = info["batch"] as? String ?? "", reveal = info["reveal"] as? String ?? "", act = response.actionIdentifier
        let isAuto = response.notification.request.content.categoryIdentifier == "org-auto"
        Task { @MainActor in
            if act == "undo" { sharedOrg.undoBatch(batch) }
            else if isAuto && !reveal.isEmpty {
                let u = URL(fileURLWithPath: reveal)
                if OrgVM.isDir(u) { NSWorkspace.shared.open(u) } else if FileManager.default.fileExists(atPath: reveal) { NSWorkspace.shared.activateFileViewerSelecting([u]) }
            }
        }
        done()
    }
}

let sharedOrg = MainActor.assumeIsolated { OrgVM() }

struct OrganizeView: View {
    @ObservedObject var vm: VM
    @ObservedObject var org = sharedOrg
    var body: some View {
        VStack(spacing: 0) {
            switch org.phase {
            case .idle: OrgStart(org: org)
            case .scanning:
                VStack(spacing: 18) {
                    ProgressView(value: Double(org.progress), total: Double(max(org.total, 1))).tint(Theme.accentSolid).frame(width: 320)
                    Text(t("Reading \(org.progress) of \(org.total)", "Đang đọc \(org.progress)/\(org.total)")).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                    Text(org.current).foregroundColor(Theme.sub).font(.system(size: fs(12))).lineLimit(1).truncationMode(.middle).frame(maxWidth: 420)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            case .done:
                VStack(spacing: 18) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: fs(40))).foregroundColor(Theme.green)
                    Text(org.result).font(.system(size: fs(17), weight: .semibold)).foregroundColor(Theme.text).multilineTextAlignment(.center)
                    if !org.report.isEmpty { OrgReport(lines: org.report).frame(width: 560) }
                    HStack(spacing: 12) {
                        GhostButton(title: t("Show in Finder", "Mở trong Finder")) { NSWorkspace.shared.open(org.folder) }
                        if org.canUndo { GhostButton(title: t("Undo", "Hoàn tác")) { org.undo() } }
                        PrimaryButton(title: t("Done", "Xong"), action: { org.phase = .idle })
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            default: OrgPlan(org: org)
            }
        }.onAppear { org.vm = vm }
    }
}

struct OrgStart: View {
    @ObservedObject var org: OrgVM
    var body: some View {
        VStack(spacing: 24) {
            Header(title: t("Organize a Folder", "Sắp xếp thư mục"),
                   sub: t("Tidymint proposes subfolders, clearer names and tags. You review everything before it moves.\nRuns on this Mac, nothing is uploaded. Nothing is deleted.",
                          "Tidymint đề xuất thư mục con, tên dễ đọc và tag. Bạn xem hết rồi mới chuyển.\nChạy ngay trên máy, không gửi gì đi. Không xoá file nào."))
            HStack(spacing: 12) {
                Image(systemName: "folder").font(.system(size: fs(18))).foregroundColor(Theme.accentSolid)
                Text(org.folder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")).foregroundColor(Theme.text).font(.system(size: fs(14))).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 12)
                GhostButton(title: t("Choose folder", "Chọn thư mục")) { org.choose() }
            }.padding(14).frame(width: 520).background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
            VStack(spacing: 4) {
                OrgSwitchRow(title: t("Read content of images and PDFs", "Đọc nội dung ảnh và PDF"),
                             sub: t("Finds receipts and CVs, suggests tags like Food or Beach. Uses macOS's built-in recognition, slower.",
                                    "Nhận ra hoá đơn, CV, gợi ý tag như Đồ ăn, Biển. Dùng nhận diện có sẵn của macOS, chậm hơn."), on: $org.readContent)
                OrgSwitchRow(title: t("Include sub-folders", "Gồm cả thư mục con"),
                             sub: t("Files in sub-folders are renamed and tagged where they are. Only loose files are sorted into folders. App bundles and code projects are skipped.",
                                    "File trong thư mục con được đổi tên và gắn tag tại chỗ. Chỉ file nằm rời mới được xếp vào thư mục. Bỏ qua gói app và thư mục dự án code."), on: $org.includeSub)
                OrgSwitchRow(title: t("Put identical copies in the Trash", "Bỏ bản trùng y hệt vào Thùng rác"),
                             sub: t("When a new name is taken by a file with exactly the same content, the extra copy goes to the Trash instead of getting \" 2\". Undo brings it back.",
                                    "Khi tên mới trùng một file có nội dung giống hệt, bản thừa vào Thùng rác thay vì thêm \" 2\". Hoàn tác sẽ lấy lại."), on: $org.dedupe)
                OrgSwitchRow(title: t("Keep Downloads tidy", "Tự xếp thư mục Tải về"),
                             sub: t("New downloads go into their type folder inside Downloads about 2 minutes after they finish, named by your rule. A file still open in another app waits, and a file you drag back to Downloads stays there. Works while Tidymint is open, even only in the menu bar; downloads that came while it was closed are sorted when it opens. Files already there when you turn this on are left alone.",
                                    "File mới tải về được chuyển vào thư mục theo loại ngay trong Tải về, khoảng 2 phút sau khi tải xong, đặt tên theo quy tắc của bạn. File đang mở trong app khác sẽ chờ; file bạn kéo ra lại Tải về được để yên. Chạy khi Tidymint đang mở, kể cả chỉ ở thanh menu; file tải lúc app tắt được xếp khi mở lại. File có sẵn lúc bật không bị động tới."), on: $org.watchDownloads)
                if org.watchDownloads {
                    HStack(spacing: 8) {
                        Text(t("Never touch:", "Không động tới:")).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                        TextField(t(".torrent, invoice", ".torrent, hoá đơn"), text: $org.exclude).textFieldStyle(.roundedBorder).font(.system(size: fs(12)))
                            .tip(t("Comma separated. \".mkv\" skips that extension, any other word skips files whose name contains it.",
                                    "Cách nhau bằng dấu phẩy. \".mkv\" bỏ qua đuôi đó, chữ khác thì bỏ qua file có tên chứa chữ đó."))
                    }.padding(.horizontal, 14).padding(.bottom, 4)
                }
                OrgHistory(org: org)
            }.frame(width: 520)
            BigScanButton(label: t("Plan", "Lập kế hoạch")) { org.plan() }
            if org.canUndo { TextLink(t("Undo the last organize", "Hoàn tác lần sắp xếp gần nhất"), size: fs(12)) { org.undo() } }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct OrgPlan: View {
    @ObservedObject var org: OrgVM
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(t("Plan for \(org.folder.lastPathComponent) (\(org.files.count) files)", "Kế hoạch cho \(org.folder.lastPathComponent) (\(org.files.count) file)"))
                    .font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                Spacer()
                PillSwitch(options: [(false, t("Rename only", "Chỉ đổi tên"), t("Keep files where they are, only rename them", "Giữ file ở chỗ cũ, chỉ đổi tên"), nil),
                                     (true, t("Sort into folders", "Sắp xếp vào thư mục"), t("Make a folder per type and move files into it", "Tạo thư mục theo loại và chuyển file vào"), nil)],
                           value: $org.moveIntoFolders)
                Button { org.plan() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.icon).foregroundColor(Theme.text).tip(t("Plan again", "Lập lại kế hoạch"), trailing: true)
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 8)
            if org.moveIntoFolders && !org.files.isEmpty {
                let n = org.newDirCount
                let made = n > 0 ? t("Creates \(n) new folders in \(org.folder.lastPathComponent).", "Tạo \(n) thư mục mới trong \(org.folder.lastPathComponent).") : ""
                let stay = org.includeSub ? t(" Files already in sub-folders stay where they are, only renamed.", " File đã nằm trong thư mục con cũ giữ nguyên chỗ, chỉ đổi tên.") : ""
                if !(made + stay).isEmpty {
                    Text((made + stay).trimmingCharacters(in: .whitespaces)).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.bottom, 6)
                }
            }
            OrgNameBar(org: org).padding(.horizontal, 24).padding(.bottom, 10)
            OrgShowBar(org: org).padding(.horizontal, 24).padding(.bottom, 10)
            if org.files.isEmpty {
                Text(org.includeSub ? t("No files in this folder.", "Không có file nào trong thư mục này.") : t("No files directly in this folder. Turn on \"Include sub-folders\" to look inside.", "Không có file nào nằm trực tiếp trong thư mục này. Bật \"Gồm cả thư mục con\" để xem bên trong.")).foregroundColor(Theme.sub).frame(maxHeight: .infinity)
            } else if org.groups.isEmpty {
                VStack(spacing: 10) {
                    Text(org.show == .check ? t("Nothing to check: every file goes as planned.", "Không còn file nào cần xem: mọi file đều đúng kế hoạch.")
                                            : t("No file gets a new name.", "Không có file nào đổi tên."))
                        .foregroundColor(Theme.sub).font(.system(size: fs(14)))
                    TextLink(t("Show all files", "Xem tất cả file"), size: fs(13)) { org.show = .all }
                }.frame(maxHeight: .infinity)
            } else if org.treeView {
                OrgTreeView(org: org)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(org.groups, id: \.self) { g in OrgGroupBlock(org: org, g: g).id(g) }
                        }.padding(.horizontal, 24).padding(.bottom, 12)
                    }
                    // Rows sit inside lazily built groups: bring the group in first, then the row.
                    .onAppear {
                        guard let id = org.focus, let f = org.file(id) else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { proxy.scrollTo(f.group, anchor: .top) }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                    }
                }
            }
            HStack {
                let inc = org.included
                Text(selLabel(inc.count, inc.reduce(0) { $0 + $1.size })).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                Text(t("· \(inc.reduce(0) { $0 + $1.tagOn.count }) tags", "· \(inc.reduce(0) { $0 + $1.tagOn.count }) tag")).foregroundColor(Theme.sub).font(.system(size: fs(13)))
                Spacer()
                if org.moveIntoFolders && !org.outsideGroups.isEmpty {
                    let n = org.outsideGroups.count
                    let auto = org.watchDownloads && org.folder.standardizedFileURL.path == OrgVM.watchDir.standardizedFileURL.path
                    Text(t("\(n) group(s) go outside \(org.folder.lastPathComponent). Undo puts everything back.", "Có \(n) nhóm chuyển ra ngoài \(org.folder.lastPathComponent). Hoàn tác trả lại tất cả.")
                         + (auto ? t(" New downloads still stay inside Downloads.", " File mới tải về vẫn xếp trong Tải về.") : ""))
                        .foregroundColor(Theme.sub).font(.system(size: fs(12))).lineLimit(2).padding(.trailing, 6)
                }
                GhostButton(title: t("Cancel", "Huỷ")) { org.phase = .idle; org.files = [] }
                PrimaryButton(title: t("Apply", "Áp dụng"), action: { org.apply() }, disabled: inc.isEmpty)
            }.padding(.horizontal, 24).padding(.vertical, 14).background(Theme.shade.opacity(0.25))
        }
    }
}

struct OrgGroupBlock: View {
    @ObservedObject var org: OrgVM
    let g: OrgGroup
    var body: some View {
        let ids = org.idx(g)
        let on = ids.filter { org.files[$0].include }.count
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    let v = on < ids.count
                    for i in ids where i < org.files.count { org.files[i].include = v }
                    org.validate()
                } label: { CheckBox(state: on == 0 ? 0 : (on == ids.count ? 2 : 1)) }.buttonStyle(.plain)
                Image(systemName: g.icon).font(.system(size: fs(15))).foregroundColor(Theme.accentSolid).frame(width: 24)
                let mv = org.groupMoves(g)
                VStack(alignment: .leading, spacing: 2) {
                    if org.editingGroup == g {
                        TextField(g.label, text: $org.groupDraft).textFieldStyle(.plain).foregroundColor(Theme.text)
                            .font(.system(size: fs(15), weight: .semibold)).frame(width: 220 * uiScale)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accentSolid, lineWidth: 1))
                            .onSubmit { org.renameDest(g, org.groupDraft) }
                            .onExitCommand { org.editingGroup = nil }
                    } else {
                        Text(mv ? org.destURL(g).lastPathComponent + "/" : g.label).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                    }
                    HStack(spacing: 6) {
                        Text(t("\(ids.count) files · \(fmt(ids.reduce(0) { $0 + org.files[$1].size }))", "\(ids.count) file · \(fmt(ids.reduce(0) { $0 + org.files[$1].size }))"))
                        if mv {
                            Text("→ " + org.destLabel(g)).lineLimit(1).truncationMode(.middle)
                            let fresh = !org.destExists(g)
                            Text(fresh ? t("NEW", "MỚI") : t("EXISTING", "CÓ SẴN")).font(.system(size: fs(9), weight: .semibold))
                                .foregroundColor(fresh ? Theme.accentSolid : Theme.text).padding(.horizontal, 6).padding(.vertical, 1)
                                .background(Capsule().fill(fresh ? Theme.accentSolid.opacity(0.18) : Theme.sub.opacity(0.18)))
                                .tip(fresh ? t("This folder is created when you Apply", "Thư mục sẽ được tạo khi áp dụng") : t("This folder already exists, files are added to it", "Thư mục đã có, file được thêm vào"))
                        }
                    }.foregroundColor(Theme.sub).font(.system(size: fs(11)))
                }
                Spacer()
                if mv {
                    Menu {
                        Button(t("Rename folder…", "Đổi tên thư mục…")) { org.groupDraft = org.destURL(g).lastPathComponent; org.editingGroup = g }
                        Button(t("Choose an existing folder…", "Chọn thư mục có sẵn…")) { org.chooseDest(g) }
                        Divider()
                        Button(t("Back to default (in \(org.folder.lastPathComponent))", "Về mặc định (trong \(org.folder.lastPathComponent))")) { org.setDest(g, nil) }
                            .disabled(org.dests[g.rawValue] == nil)
                    } label: { Text(t("Change", "Đổi")).font(.system(size: fs(12))) }
                        .menuStyle(.borderlessButton).fixedSize().foregroundColor(Theme.text)
                        .padding(.horizontal, 8).padding(.vertical, 3).hoverTile()
                        .tip(t("Rename this folder or pick another one", "Đổi tên thư mục này hoặc chọn thư mục khác"), trailing: true)
                }
                Button { if org.collapsed.contains(g) { org.collapsed.remove(g) } else { org.collapsed.insert(g) } } label: {
                    Image(systemName: "chevron.down").rotationEffect(.degrees(org.collapsed.contains(g) ? -90 : 0))
                }.buttonStyle(.icon).foregroundColor(Theme.sub)
                    .tip(org.collapsed.contains(g) ? t("Expand group", "Mở nhóm") : t("Collapse group", "Thu gọn nhóm"), trailing: true)
            }.padding(.horizontal, 14).padding(.vertical, 12)
            if !org.collapsed.contains(g) {
                ForEach(ids, id: \.self) { i in OrgRow(org: org, i: i) }
            }
        }.background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
    }
}

struct OrgRow: View {
    @ObservedObject var org: OrgVM
    let i: Int
    var body: some View {
        if i < org.files.count {
            let f = org.files[i]
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    // A file that goes with another one follows that file's checkbox.
                    if f.pairOf != nil { CheckBox(state: f.include ? 2 : 0).opacity(0.4) }
                    else { Button { org.edit(f.id) { $0.include.toggle() } } label: { CheckBox(state: f.include ? 2 : 0) }.buttonStyle(.plain) }
                    FileThumb(url: f.url, side: 34 * uiScale)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.name).foregroundColor(Theme.text).font(.system(size: fs(14))).lineLimit(1).truncationMode(.middle)
                        HStack(spacing: 6) {
                            let rel = f.url.deletingLastPathComponent().path.replacingOccurrences(of: org.folder.path, with: "")
                            if !rel.isEmpty {
                                Image(systemName: "folder").font(.system(size: fs(10))).foregroundColor(Theme.sub)
                                Text(String(rel.dropFirst())).foregroundColor(Theme.sub).font(.system(size: fs(11))).lineLimit(1).truncationMode(.head)
                            }
                            if !f.why.isEmpty {
                                Text(f.why).foregroundColor(Theme.sub).font(.system(size: fs(11))).lineLimit(1)
                            } else {
                                Text(fmt(f.size)).foregroundColor(Theme.sub).font(.system(size: fs(11)))
                            }
                        }
                    }
                    Spacer(minLength: 8)
                    ForEach(f.tags, id: \.self) { tg in OrgTag(text: tg, on: f.tagOn.contains(tg)) {
                        org.edit(f.id, check: false) { if $0.tagOn.contains(tg) { $0.tagOn.remove(tg) } else { $0.tagOn.insert(tg) } }
                    } }
                    if f.pairOf == nil {
                        Menu {
                            ForEach(OrgGroup.allCases, id: \.self) { g in Button(g.label) { org.setGroup(f.id, g) } }
                        } label: { Image(systemName: "folder") }.menuStyle(.borderlessButton).fixedSize().padding(.horizontal, 5).padding(.vertical, 3).hoverTile().tip(t("Move to another group", "Chuyển sang nhóm khác"), trailing: true)
                    }
                    Button { org.editing = org.editing == f.id ? nil : f.id } label: {
                        Image(systemName: f.note.isEmpty ? "square.and.pencil" : "note.text").foregroundColor(f.note.isEmpty ? Theme.sub : Theme.accentSolid)
                    }.buttonStyle(.icon).tip(t("Add a note (kept in Tidymint only, not written into the file)", "Thêm ghi chú (chỉ lưu trong Tidymint, không ghi vào file)"), trailing: true)
                }
                if f.pairOf != nil, let n = f.newName {
                    // Its name comes from the file it goes with.
                    HStack(spacing: 8) {
                        Image(systemName: "link").font(.system(size: fs(12))).foregroundColor(Theme.sub)
                        Text(t("Rename to", "Đổi tên thành")).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                        Text(n).foregroundColor(Theme.text).font(.system(size: fs(12))).lineLimit(1).truncationMode(.middle)
                    }.padding(.leading, 76 * uiScale).opacity(f.renameOn ? 1 : 0.6)
                } else if f.newName != nil {
                    HStack(spacing: 8) {
                        Button { org.edit(f.id) { $0.renameOn.toggle() } } label: {
                            Image(systemName: f.renameOn ? "checkmark.square.fill" : "square").font(.system(size: fs(13)))
                                .foregroundStyle(f.renameOn ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.ink.opacity(0.5)))
                                .contentShape(Rectangle()).onHover { ($0 ? NSCursor.pointingHand : NSCursor.arrow).set() }
                        }.buttonStyle(.plain)
                        Text(t("Rename to", "Đổi tên thành")).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                        TextField("", text: Binding(get: { org.file(f.id)?.newName ?? "" }, set: { v in org.edit(f.id) { $0.newName = v; $0.renameOn = true; $0.nameEdited = true } }))
                            .textFieldStyle(.roundedBorder).font(.system(size: fs(12))).frame(maxWidth: 420)
                    }.padding(.leading, 76 * uiScale).opacity(f.renameOn ? 1 : 0.6)
                }
                if let w = f.warn, f.include {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: fs(11)))
                        Text(w).font(.system(size: fs(12))).lineLimit(2)
                    }.foregroundColor(Theme.warn).padding(.leading, 76 * uiScale)
                }
                if org.editing == f.id || !f.note.isEmpty {
                    TextField(t("Add a note for this file", "Thêm ghi chú cho file này"), text: Binding(get: { org.file(f.id)?.note ?? "" }, set: { v in org.edit(f.id, check: false) { $0.note = v } }))
                        .textFieldStyle(.roundedBorder).font(.system(size: fs(12))).padding(.leading, 76 * uiScale)
                }
            }.padding(.horizontal, 14).padding(.vertical, 8).opacity(f.include ? 1 : 0.55)
            .background(RoundedRectangle(cornerRadius: 8).stroke(Theme.accentSolid, lineWidth: org.focus == f.id ? 2 : 0))
            .id(f.id)
        }
    }
}

/// After Apply: each file that did not go exactly as planned, with the reason. Skipped files first.
struct OrgReport: View {
    let lines: [OrgNote]
    func icon(_ k: OrgNote.Kind) -> (String, Color) {
        switch k {
        case .skipped: return ("xmark.circle.fill", Theme.danger)
        case .kept: return ("exclamationmark.triangle.fill", Theme.warn)
        case .numbered: return ("number.circle.fill", Theme.sub)
        case .trashed: return ("trash.fill", Theme.sub)
        }
    }
    var body: some View {
        let order: [OrgNote.Kind] = [.skipped, .kept, .numbered, .trashed]
        let sorted = lines.sorted { order.firstIndex(of: $0.kind)! < order.firstIndex(of: $1.kind)! }
        VStack(alignment: .leading, spacing: 8) {
            Text(t("\(lines.count) files did not go exactly as planned", "\(lines.count) file không đúng như kế hoạch"))
                .font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
            let list = VStack(alignment: .leading, spacing: 8) {
                    ForEach(sorted) { l in
                        let ic = icon(l.kind)
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: ic.0).font(.system(size: fs(12))).foregroundColor(ic.1)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.name).font(.system(size: fs(13))).foregroundColor(Theme.text).lineLimit(1).truncationMode(.middle)
                                Text(l.detail).font(.system(size: fs(12))).foregroundColor(Theme.sub).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            // A short list sits at its own height; a long one scrolls inside a fixed box.
            if sorted.count <= 5 { list } else { ScrollView { list }.frame(height: 220) }
        }.padding(14).background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
    }
}

/// One line of a folder tree. state: 0 unchanged, 1 renamed or moved (after), 2 needs a look, 3 will leave this place (now).
struct OrgTreeRow: Identifiable {
    let id = UUID()
    let depth: Int; let name: String; let isDir: Bool
    var isNew = false; var existing = false; var count = 0
    var file: UUID? = nil; var state = 0; var pair: String? = nil

    final class Node { var dirs: [String: Node] = [:]; var files: [(String, OrgFile, Int)] = [] }
    static func build(_ items: [(path: [String], f: OrgFile, state: Int)], root: URL, markNew: Bool) -> [OrgTreeRow] {
        let top = Node()
        for it in items {
            var n = top
            for d in it.path.dropLast() { if n.dirs[d] == nil { n.dirs[d] = Node() }; n = n.dirs[d]! }
            n.files.append((it.path.last ?? it.f.name, it.f, it.state))
        }
        var out = [OrgTreeRow(depth: 0, name: root.lastPathComponent, isDir: true, count: items.count)]
        func walk(_ n: Node, _ depth: Int, _ at: URL) {
            for d in n.dirs.keys.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending }) {
                let u = d.hasPrefix("~/") ? URL(fileURLWithPath: NSHomeDirectory() + d.dropFirst()) : at.appendingPathComponent(d), k = n.dirs[d]!
                var r = OrgTreeRow(depth: depth, name: d, isDir: true, count: k.files.count)
                r.isNew = markNew && !FileManager.default.fileExists(atPath: u.path)
                r.existing = markNew && !r.isNew
                out.append(r)
                walk(k, depth + 1, u)
            }
            for (name, f, st) in n.files.sorted(by: { $0.0.localizedStandardCompare($1.0) == .orderedAscending }) {
                var r = OrgTreeRow(depth: depth, name: name, isDir: false, file: f.id, state: st)
                if f.pairOf != nil, let w = f.why.range(of: "(") { r.pair = String(f.why[w.lowerBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "()")) }
                out.append(r)
            }
        }
        walk(top, 1, root)
        return out
    }
}

/// Plan as two trees side by side: where the files are now, and where they will be after Apply.
/// Green: renamed or moved. Yellow: needs a look. Folders that will be created carry a NEW badge.
/// Clicking a file opens the list at that file.
struct OrgTreeView: View {
    @ObservedObject var org: OrgVM
    var body: some View {
        let tr = org.trees()
        HStack(alignment: .top, spacing: 12) {
            column(t("Now", "Bây giờ"), tr.now, after: false)
            column(t("After Apply", "Sau khi áp dụng"), tr.after, after: true)
        }.padding(.horizontal, 24).padding(.bottom, 12)
    }
    func column(_ title: String, _ rows: [OrgTreeRow], after: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.system(size: fs(11), weight: .semibold)).tracking(1).foregroundColor(Theme.sub)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { r in line(r, after: after) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
    }
    @ViewBuilder func line(_ r: OrgTreeRow, after: Bool) -> some View {
        let color: Color = r.isDir ? Theme.text : (r.state == 1 ? Theme.green : (r.state == 2 ? Theme.warn : (r.state == 3 ? Theme.sub : Theme.text)))
        HStack(spacing: 6) {
            if r.isDir {
                Image(systemName: r.depth == 0 ? "folder.fill" : "folder").font(.system(size: fs(13))).foregroundColor(Theme.accentSolid)
                Text(r.name).font(.system(size: fs(13))).foregroundColor(Theme.text).lineLimit(1)
                if r.isNew {
                    Text(t("NEW", "MỚI")).font(.system(size: fs(10), weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 1).background(Capsule().fill(Theme.accentSolid))
                }
                if r.depth > 0 {
                    Text((r.existing ? t("already there · ", "đã có · ") : "") + t("\(r.count) files", "\(r.count) file")).font(.system(size: fs(11))).foregroundColor(Theme.sub)
                }
            } else {
                if r.state == 2 { Image(systemName: "exclamationmark.triangle.fill").font(.system(size: fs(11))).foregroundColor(Theme.warn) }
                Text(r.name).font(.system(size: fs(14))).foregroundColor(color).lineLimit(1).truncationMode(.middle)
                if after, let p = r.pair {
                    Image(systemName: "link").font(.system(size: fs(10))).foregroundColor(Theme.sub)
                    Text(p).font(.system(size: fs(11))).foregroundColor(Theme.sub).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(r.depth) * 20 * uiScale).padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { if let id = r.file { org.reveal(id) } }
        .tip(r.file != nil ? t("Show this file in the list", "Xem file này trong danh sách") : "")
    }
}

/// Above the list: show everything, only renames, or only files to check (like f2's status column).
struct OrgShowBar: View {
    @ObservedObject var org: OrgVM
    var body: some View {
        let inc = org.files.filter(\.include)
        HStack {
            Picker("", selection: $org.show) {
                Text(t("All (\(org.files.count))", "Tất cả (\(org.files.count))")).tag(OrgVM.Show.all)
                Text(t("Renamed (\(org.renameCount))", "Sẽ đổi tên (\(org.renameCount))")).tag(OrgVM.Show.rename)
                Text(t("To check (\(inc.filter { $0.warn != nil }.count))", "Cần xem (\(inc.filter { $0.warn != nil }.count))")).tag(OrgVM.Show.check)
            }.pickerStyle(.segmented).controlSize(.small).labelsHidden().fixedSize()
            Spacer()
            // Named by what each side is for: the list is where files are changed, the tree only shows the result.
            PillSwitch(options: [(false, t("Edit", "Chỉnh sửa"), t("Rename, tag and regroup each file", "Đổi tên, tag, nhóm cho từng file"), "square.and.pencil"),
                                 (true, t("Preview", "Xem trước"), t("See the folders before and after Apply", "Xem thư mục trước và sau khi áp dụng"), "eye")],
                       value: $org.treeView)
        }
    }
}

struct OrgTag: View {
    let text: String; let on: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: on ? "tag.fill" : "tag").font(.system(size: fs(9)))
                Text(text).font(.system(size: fs(11), weight: .medium))
            }
            .foregroundColor(on ? Theme.text : Theme.sub)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(on ? Theme.accentSolid.opacity(0.25) : Color.clear))
            .overlay(Capsule().stroke(on ? Theme.accentSolid.opacity(0.6) : Theme.ink.opacity(0.25), lineWidth: 1))
        }.buttonStyle(.plain).tip(on ? t("Click to drop this tag", "Bấm để bỏ tag này") : t("Click to keep this tag", "Bấm để giữ tag này"), trailing: true)
    }
}

extension Demo {
    static func organize(_ o: OrgVM) {
        func f(_ n: String, _ g: OrgGroup, _ mb: Double, _ tags: [String] = [], why: String = "", new: String? = nil, note: String = "", days: Double = 3) -> OrgFile {
            var x = OrgFile(url: u("Downloads/" + n), size: Int64(mb * 1_000_000), date: Date().addingTimeInterval(-days * 86400), group: g, why: why, tags: tags, tagOn: Set(tags), newName: new, renameOn: new != nil, desc: new.map { ($0 as NSString).deletingPathExtension.components(separatedBy: " ").dropFirst().joined(separator: " ") }, needsName: new != nil, note: note)
            x.include = true; return x
        }
        o.folder = u("Downloads")
        o.files = [
            f("Screenshot 2026-10-21 at 09.14.22.png", .screens, 1.2, [t("Has text", "Có chữ")], why: t("Name says it is a screen capture", "Tên file cho thấy là ảnh chụp màn hình"), new: "2026-10-21 " + t("Screenshot", "Ảnh màn hình") + ".png"),
            f("Screenshot 2026-10-25 at 18.02.10.png", .screens, 0.9, [], why: t("Name says it is a screen capture", "Tên file cho thấy là ảnh chụp màn hình"), new: "2026-10-25 " + t("Screenshot", "Ảnh màn hình") + ".png"),
            f("IMG_4821.HEIC", .receipts, 2.4, [t("Document", "Giấy tờ"), t("Has text", "Có chữ")], why: t("Text in the file looks like a receipt or invoice", "Chữ trong file giống hoá đơn, biên lai"), new: "2026-10-19 " + t("Receipt", "Hoá đơn") + ".HEIC", note: t("Office chair, keep for warranty", "Ghế văn phòng, giữ để bảo hành")),
            f("invoice_88213.pdf", .receipts, 0.2, [], why: t("Text in the file looks like a receipt or invoice", "Chữ trong file giống hoá đơn, biên lai")),
            f("IMG_4790.JPG", .images, 3.1, [t("Food", "Đồ ăn"), t("Drink", "Đồ uống")], new: "2026-10-12 " + t("Food", "Đồ ăn") + ".JPG"),
            f("IMG_4802.JPG", .images, 2.8, [t("Beach", "Biển"), t("Sky", "Bầu trời")], new: "2026-10-14 " + t("Beach", "Biển") + ".JPG"),
            f("PXL_20261002_0815.jpg", .images, 3.6, [t("Dog", "Chó")], new: "2026-10-02 " + t("Dog", "Chó") + ".jpg"),
            f("hero-banner-v3.png", .images, 4.2, [t("Illustrations", "Minh hoạ")]),
            f("interview-raw.mp4", .video, 410, []),
            f("Bao-cao-Q3.docx", .docs, 0.4, []),
            f("ngan-sach-2026.xlsx", .sheets, 0.1, []),
            f("Tidymint.zip", .archives, 3.5, []),
            f("ubuntu-24.04-desktop-arm64.iso", .installers, 3200, []),
        ]
        o.phase = .review
    }
}

/// Naming rule bar above the plan: preset menu, example, edit button, "keep all old names".
struct OrgNameBar: View {
    @ObservedObject var org: OrgVM
    var body: some View {
        let named = org.files.indices.filter { org.files[$0].newName != nil }
        HStack(spacing: 10) {
            Image(systemName: "character.cursor.ibeam").foregroundColor(Theme.accentSolid).font(.system(size: fs(14)))
            Text(t("Names:", "Đặt tên:")).foregroundColor(Theme.sub).font(.system(size: fs(12)))
            Menu {
                ForEach(NamePreset.allCases, id: \.self) { p in Button(p.label) { org.preset = p } }
            } label: { Text(org.preset.label).font(.system(size: fs(12), weight: .semibold)) }.menuStyle(.borderlessButton).fixedSize()
                .padding(.horizontal, 6).padding(.vertical, 3).hoverTile().tip(t("Pick a ready-made naming style", "Chọn kiểu đặt tên có sẵn"))
            // The whole pill takes the click (a bare icon only reacts on its thin strokes), and a click always opens the editor.
            Button { org.showRule = true } label: {
                Label(t("Customize", "Tuỳ chỉnh"), systemImage: "slider.horizontal.3").font(.system(size: fs(12)))
            }.buttonStyle(.icon).foregroundColor(Theme.text)
                .tip(t("Edit the rule", "Sửa quy tắc"))
                .popover(isPresented: $org.showRule, arrowEdge: .bottom) { OrgRuleEditor(org: org).frame(width: 380).padding(16) }
            Text(t("e.g. ", "ví dụ: ") + org.example).foregroundColor(Theme.sub).font(.system(size: fs(12))).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 8)
            if org.warnCount > 0 {
                Button { org.show = .check } label: {
                    Label(t("\(org.warnCount) to check", "\(org.warnCount) file cần xem"), systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.warn).font(.system(size: fs(12), weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 3).hoverTile()
                }.buttonStyle(.plain)
                    .tip(t("Show only these files", "Chỉ hiện các file này"))
            }
            if org.renameCount == 0 && !org.renameAll && named.isEmpty && !org.files.isEmpty {
                // Say why nothing is renamed: every name is already readable, so the rule leaves them alone.
                Text(t("Names already clear, kept", "Tên đã rõ ràng, giữ nguyên")).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                    .tip(t("Only names that say nothing (IMG_, Screenshot, scan, random strings) are renamed by default.",
                            "Mặc định chỉ đổi tên file có tên vô nghĩa (IMG_, Screenshot, scan, chuỗi ngẫu nhiên)."))
                TextLink(t("Rename these too", "Đổi cả các file này"), size: fs(12)) { org.renameAll = true }
            } else {
                Text(t("\(org.renameCount) to rename", "\(org.renameCount) file sẽ đổi tên")).foregroundColor(Theme.text).font(.system(size: fs(12), weight: .semibold))
            }
            if !named.isEmpty {
                let allOn = named.allSatisfy { org.files[$0].renameOn }
                TextLink(allOn ? t("Keep all old names", "Giữ tên cũ tất cả") : t("Rename all", "Đổi tên tất cả"), size: fs(12)) {
                    for i in named where i < org.files.count { org.files[i].renameOn = !allOn }
                    org.validate()
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8).background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
    }
}

/// Custom rule editor: the parts in use (drag to reorder, or use the arrows), parts to add (including your own text),
/// separator and web-safe switches. Any change switches the preset to Custom and is remembered.
struct OrgRuleEditor: View {
    @ObservedObject var org: OrgVM
    func set(_ change: (inout NameRule) -> Void) { var r = org.rule; change(&r); org.custom = r; if org.preset != .custom { org.preset = .custom } }
    func move(_ i: Int, _ d: Int) { set { r in let j = i + d; guard r.parts.indices.contains(i), r.parts.indices.contains(j) else { return }; r.parts.swapAt(i, j) } }
    var body: some View {
        let r = org.rule
        VStack(alignment: .leading, spacing: 10) {
            Text(t("Naming rule", "Quy tắc đặt tên")).font(.system(size: fs(13)))
            Text(t("Drag the parts to reorder them, or use the arrows.", "Kéo thả để đổi thứ tự các phần, hoặc bấm mũi tên.")).font(.system(size: fs(11))).foregroundColor(.secondary)
            List {
                ForEach(r.parts) { p in
                    let i = r.parts.firstIndex(of: p) ?? 0
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal").foregroundColor(.secondary).tip(t("Drag to reorder", "Kéo để đổi chỗ"))
                        if p.kind == .text {
                            TextField(t("Your text, e.g. ACME", "Chữ tự gõ, ví dụ ACME"), text: Binding(
                                get: { org.rule.parts.first { $0.id == p.id }?.text ?? "" },
                                set: { v in set { r in if let k = r.parts.firstIndex(where: { $0.id == p.id }) { r.parts[k].text = v } } }))
                                .textFieldStyle(.roundedBorder).font(.system(size: fs(12)))
                        } else {
                            Text(p.kind.label).font(.system(size: fs(12)))
                            Spacer()
                        }
                        Button { move(i, -1) } label: { Image(systemName: "chevron.up") }.buttonStyle(.icon).disabled(i == 0)
                        Button { move(i, 1) } label: { Image(systemName: "chevron.down") }.buttonStyle(.icon).disabled(i == r.parts.count - 1)
                        Button { set { r in r.parts.removeAll { $0.id == p.id } } } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
                            .buttonStyle(.icon).tip(t("Remove", "Bỏ phần này"))
                    }.padding(.vertical, 2)
                }
                .onMove { from, to in set { r in r.parts.move(fromOffsets: from, toOffset: to) } }
            }
            .frame(height: CGFloat(max(r.parts.count, 1)) * 34 + 12)
            Text(t("Add a part", "Thêm phần")).font(.system(size: fs(11))).foregroundColor(.secondary)
            let unused = NameToken.allCases.filter { k in k != .text && !r.parts.contains { $0.kind == k } }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(unused + [.text], id: \.self) { k in
                    Button { set { r in r.parts.append(NamePart(kind: k)) } } label: {
                        Label(k.label, systemImage: k == .text ? "character.cursor.ibeam" : "plus").font(.system(size: fs(11)))
                            .padding(.horizontal, 8).padding(.vertical, 4).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Capsule().stroke(Color.secondary.opacity(0.4))).hoverTile()
                    }.buttonStyle(.plain)
                }
            }
            Divider()
            HStack {
                Text(t("Separator", "Dấu nối")).font(.system(size: fs(12)))
                Picker("", selection: Binding(get: { org.rule.sep }, set: { v in set { $0.sep = v } })) {
                    Text(t("Space", "Khoảng trắng")).tag(" "); Text("_").tag("_"); Text("-").tag("-")
                }.pickerStyle(.segmented).controlSize(.small).fixedSize()
            }
            Toggle(t("Remove Vietnamese accents", "Bỏ dấu tiếng Việt"), isOn: Binding(get: { org.rule.noAccents }, set: { v in set { $0.noAccents = v } })).font(.system(size: fs(12)))
            Toggle(t("Lower case", "Viết thường"), isOn: Binding(get: { org.rule.lower }, set: { v in set { $0.lower = v } })).font(.system(size: fs(12)))
            Toggle(t("Also rename files that already have a clear name", "Đổi cả file đã có tên rõ ràng"), isOn: $org.renameAll).font(.system(size: fs(12)))
            Divider()
            Text(t("Example", "Ví dụ")).font(.system(size: fs(11))).foregroundColor(.secondary)
            Text(org.example).font(.system(size: fs(13), weight: .medium)).textSelection(.enabled)
            Text(t("Extensions are always lower case (.JPG becomes .jpg). Nothing is overwritten: a clash gets \" 2\". Dates come from the camera when the photo or video has one. A Live Photo, RAW + JPG or a video and its subtitles keep the same name.",
                   "Đuôi file luôn viết thường (.JPG thành .jpg). Không ghi đè: trùng tên thì thêm \" 2\". Ngày lấy theo ngày chụp nếu ảnh hoặc video có ghi. Live Photo, RAW + JPG, video và phụ đề luôn giữ chung một tên."))
                .font(.system(size: fs(11))).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            // Say plainly what the rule will do to this list, and why nothing changes when every name is already clear.
            if org.renameCount == 0 && !org.renameAll {
                Text(t("All \(org.files.count) files already have clear names, so they keep them. Turn on \"Also rename files that already have a clear name\" to apply the rule to them.",
                       "Cả \(org.files.count) file đã có tên rõ ràng nên được giữ nguyên. Bật \"Đổi cả file đã có tên rõ ràng\" để áp quy tắc cho chúng."))
                    .font(.system(size: fs(12))).foregroundColor(Theme.warn).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Text(t("\(org.renameCount) files will be renamed when you click Apply.", "\(org.renameCount) file sẽ được đổi tên khi bấm Áp dụng."))
                    .font(.system(size: fs(12), weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                Spacer()
                PrimaryButton(title: t("Use this rule", "Dùng quy tắc này"), action: { org.recomputeNames(); org.showRule = false })
            }
        }
    }
}

/// A settings-style row: title and explanation on the left, the switch pinned to the right edge,
/// so every switch lines up with the others and with the button in the folder card above.
/// Keep Downloads tidy batches from the last 7 days, each with its own Undo.
struct OrgHistory: View {
    @ObservedObject var org: OrgVM
    var body: some View {
        let _ = org.historyTick
        let h = OrgVM.history()
        if !h.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                TextLink(org.historyOpen ? t("Hide automatic batches", "Ẩn các đợt tự xếp") : t("Automatic batches, last 7 days (\(h.count))", "Các đợt tự xếp 7 ngày qua (\(h.count))"), size: fs(12)) {
                    org.historyOpen.toggle()
                }
                if org.historyOpen {
                    let df: DateFormatter = { let f = DateFormatter(); f.dateFormat = "dd/MM HH:mm"; return f }()
                    ForEach(h.prefix(30), id: \.date) { b in
                        let kept = b.moves.filter { $0.trashed != true }
                        let dirs = Array(Set(kept.map { URL(fileURLWithPath: $0.to).deletingLastPathComponent().lastPathComponent })).sorted()
                        HStack(spacing: 8) {
                            Text(df.string(from: b.date)).foregroundColor(Theme.sub).monospacedDigit()
                            Text(t("\(kept.count) files", "\(kept.count) file") + (dirs.isEmpty ? "" : " · " + dirs.joined(separator: ", ")))
                                .foregroundColor(Theme.text).lineLimit(1).truncationMode(.tail)
                            Spacer(minLength: 8)
                            TextLink(t("Undo", "Hoàn tác"), size: fs(12)) { if let id = b.id { org.undoBatch(id) } }
                        }.font(.system(size: fs(12)))
                    }
                }
            }.padding(.horizontal, 14).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Two-option switch made of buttons, so each option has its own tooltip and hover tile (a segmented picker has neither).
struct PillSwitch: View {
    let options: [(Bool, String, String, String?)]   // value, label, tooltip, SF symbol
    @Binding var value: Bool
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { v, label, tip, icon in
                Button { value = v } label: {
                    HStack(spacing: 5) {
                        if let icon { Image(systemName: icon) }
                        Text(label)
                    }.font(.system(size: fs(12), weight: .medium)).foregroundColor(value == v ? .white : Theme.sub)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(value == v ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.clear)))
                        .hoverTile(value != v)
                }.buttonStyle(.plain).tip(tip)
            }
        }.padding(3).background(Capsule().fill(Theme.card))
    }
}

struct OrgSwitchRow: View {
    let title: String; let sub: String
    @Binding var on: Bool
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundColor(Theme.text).font(.system(size: fs(14), weight: .medium))
                Text(sub).foregroundColor(Theme.sub).font(.system(size: fs(12))).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: $on).labelsHidden().toggleStyle(.switch).controlSize(.mini).tint(Theme.accentSolid)
        }.padding(.horizontal, 14).padding(.vertical, 8)
    }
}

/// Free space per day: a line with a soft fill, a green dot on days with a cleanup, 7/30/90-day ranges, hover for the day's numbers.
struct FreeSpaceChart: View {
    @ObservedObject var vm: VM
    let log: [LogEntry]
    @StateObject private var pick = RangePick()
    var body: some View {
        let data = DiskHistory.series(days: pick.days, log: log)
        let dm: DateFormatter = { let f = DateFormatter(); f.dateFormat = "dd/MM"; return f }()
        let top = max(vm.totalGB, (data.map(\.free).max() ?? 1) * 1.1)
        let sel = pick.sel.flatMap { s in data.min { abs($0.date.timeIntervalSince(s)) < abs($1.date.timeIntervalSince(s)) } }
        // Built step by step: one long + chain is too slow for some Swift versions to type-check.
        let selText: String? = sel.map { d in
            var s = dm.string(from: d.date) + ": " + t("free ", "trống ")
            s += String(format: "%.0f GB", d.free)
            if d.freed > 0 { s += t(", cleaned ", ", đã dọn ") + fmt(d.freed) }
            return s
        }
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t("Free space per day (GB)", "Dung lượng trống mỗi ngày (GB)")).font(.system(size: fs(12), weight: .semibold)).foregroundColor(Theme.sub)
                Spacer()
                if let s = selText {
                    Text(s).font(.system(size: fs(11), weight: .semibold)).foregroundColor(Theme.text)
                }
                Picker("", selection: $pick.days) {
                    Text(t("7 days", "7 ngày")).tag(7); Text(t("30 days", "30 ngày")).tag(30); Text(t("90 days", "90 ngày")).tag(90)
                }.pickerStyle(.segmented).controlSize(.small).fixedSize()
            }
            if data.count < 2 {
                Text(t("Not enough days yet. Tidymint notes the free space once a day while it is open.",
                       "Chưa đủ số ngày. Tidymint ghi dung lượng trống mỗi ngày một lần khi app đang mở."))
                    .font(.system(size: fs(12))).foregroundColor(Theme.sub).frame(height: 140)
            } else {
                Chart {
                    ForEach(data) { d in
                        AreaMark(x: .value("Day", d.date, unit: .day), y: .value("GB", d.free))
                            .foregroundStyle(LinearGradient(colors: [Theme.accentSolid.opacity(0.35), Theme.accentSolid.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Day", d.date, unit: .day), y: .value("GB", d.free))
                            .foregroundStyle(Theme.accentSolid).lineStyle(StrokeStyle(lineWidth: 2))
                        if d.freed > 0 {
                            PointMark(x: .value("Day", d.date, unit: .day), y: .value("GB", d.free)).foregroundStyle(Theme.green).symbolSize(40)
                        }
                    }
                    if let d = sel {
                        RuleMark(x: .value("Day", d.date, unit: .day)).foregroundStyle(Theme.ink.opacity(0.3))
                    }
                }
                .chartYScale(domain: 0...top)
                // The axis always spans the whole range, so the line sits on the right dates even when early days are missing.
                .chartXScale(domain: (Calendar.current.date(byAdding: .day, value: -(pick.days - 1), to: Calendar.current.startOfDay(for: Date())) ?? Date())...Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: pick.days <= 7 ? 1 : (pick.days <= 30 ? 7 : 14))) { v in
                        AxisGridLine().foregroundStyle(Theme.ink.opacity(0.08))
                        AxisValueLabel { if let d = v.as(Date.self) { Text(dm.string(from: d)).font(.system(size: fs(10))).foregroundColor(Theme.sub) } }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { v in
                        AxisGridLine().foregroundStyle(Theme.ink.opacity(0.08))
                        AxisValueLabel { if let g = v.as(Double.self) { Text(String(format: "%.0f", g)).font(.system(size: fs(10))).foregroundColor(Theme.sub) } }
                    }
                }
                .chartXSelection(value: $pick.sel)
                .frame(height: 150)
            }
        }.padding(14).background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
    }
}
