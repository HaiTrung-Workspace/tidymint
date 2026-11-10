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

// MARK: - Model

struct CleanItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var size: Int64                // 0 for an APFS clone of a copy kept above it in a duplicate group
    var selected: Bool
    var running = false
    var refStrong: [String] = []   // referenced by a script or skill
    var refWeak: [String] = []     // only mentioned in notes
    var nameMatch = false          // found by app name, not bundle id: could belong to something else
    var hasDB = false              // a database sits inside: may be the user's own data
    var clone = false              // duplicate copy that shares its data with a copy above it (APFS clone)
    var cloneOfExtra = false       // clone of another extra copy (not of the kept one): both must go to free the space
    var cross = 0                  // duplicate group spans the Mac and an external drive: 1 = this copy is on the Mac, 2 = on an external drive
    /// Why the row is shown but not ticked, when none of the flags above says it (shared folder, app data, kept on purpose).
    var reason = ""
    var note: String {
        if running { return t("App is open, quit it first", "App đang mở, tắt app rồi dọn") }
        if hasDB { return t("Has a database inside, may be your data", "Có database bên trong, có thể là dữ liệu của bạn") }
        if nameMatch { return t("Matched by name only, check first", "Khớp theo tên app, kiểm tra trước") }
        if !refStrong.isEmpty { return t("Used by \(refStrong.count) script/skill", "Script/skill đang dùng (\(refStrong.count))") }
        if !refWeak.isEmpty { return t("Mentioned in \(refWeak.count) notes", "Được nhắc trong \(refWeak.count) ghi chú") }
        if cross == 1 { return t("Same file is on an external drive", "Có bản giống hệt trên ổ ngoài") }
        if cross == 2 { return t("Same file is on this Mac", "Có bản giống hệt trên máy") }
        return reason
    }
    /// Warning shown on the row itself. Where a copy sits (Mac / external drive) is said once in the duplicate group header instead.
    var rowNote: String { cross != 0 && !running && !hasDB && !nameMatch && refStrong.isEmpty && refWeak.isEmpty && reason.isEmpty ? "" : note }
    var noteColor: Color { !refStrong.isEmpty || hasDB ? Theme.danger : (running || nameMatch || !refWeak.isEmpty ? Theme.warn : Theme.sub) }
    var refHelp: String { (refStrong + refWeak).map { $0.replacingOccurrences(of: NSHomeDirectory(), with: "~") }.joined(separator: "\n") }
    var date: Date? = nil
    var label: String? = nil       // friendlier name than the file name (e.g. "My iPhone · Oct 2, 2026")
    var name: String { label ?? url.lastPathComponent }
    var shortPath: String { url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
}

/// How safe it is to move a group of items to the Trash.
enum Safety: Int, Comparable {
    case safe = 0     // the app rebuilds it on its own: pre-selected
    case review       // user data or app state: the user ticks it
    case locked       // never offered (databases, messages, settings)
    static func < (a: Safety, b: Safety) -> Bool { a.rawValue < b.rawValue }
    var label: String {
        switch self {
        case .safe: return t("Safe", "An toàn")
        case .review: return t("You choose", "Bạn tự chọn")
        case .locked: return t("Locked", "Khoá")
        }
    }
    var color: Color { self == .safe ? Theme.green : (self == .review ? Theme.warn : Theme.danger) }
    var icon: String { self == .safe ? "checkmark.shield" : (self == .review ? "hand.raised" : "lock") }
}

struct Category: Identifiable {
    let id: String
    let titleEN: String, titleVI: String
    let icon: String
    let descEN: String, descVI: String
    var safety: Safety = .safe
    /// What happens after cleaning (shown on hover of the safety badge).
    var whyEN = "", whyVI = ""
    var title: String { t(titleEN, titleVI) }
    var desc: String { t(descEN, descVI) }
    var why: String { t(whyEN, whyVI) }
    var items: [CleanItem]
    var expanded = false
    /// Items under `smallLimit` are folded into one "small items" row so the list stays readable without hiding anything.
    var smallExpanded = false
    static let smallLimit: Int64 = 500_000
    var total: Int64 { items.reduce(0) { $0 + $1.size } }
    var selectedSize: Int64 { items.filter(\.selected).reduce(0) { $0 + $1.size } }
    var state: Int {
        let n = items.filter(\.selected).count
        return n == 0 ? 0 : (n == items.count ? 2 : 1)
    }
}

struct Node: Identifiable {
    let id = UUID()
    let url: URL
    let size: Int64
    let isDir: Bool
    var otherCount = 0          // > 0: the "Other" bubble that groups small items
    var name: String { otherCount > 0 ? t("Other (\(otherCount))", "Khác (\(otherCount))") : url.lastPathComponent }
}

/// Group items under 1% of the total into one "Other" bubble (at most 40 separate bubbles).
func lensBubbles(_ nodes: [Node], folder: URL?) -> [Node] {
    let total = nodes.reduce(0) { $0 + $1.size }
    guard total > 0 else { return [] }
    var big: [Node] = [], small: [Node] = []
    for n in nodes { if Double(n.size) >= Double(total) * 0.01 && big.count < 40 { big.append(n) } else { small.append(n) } }
    if !small.isEmpty, let f = folder {
        big.append(Node(url: f, size: small.reduce(0) { $0 + $1.size }, isDir: false, otherCount: small.count))
    }
    return big
}
