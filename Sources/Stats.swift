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

// MARK: - Stats (from the activity log)

struct LogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let text: String
    let freed: Int64
    let freeGB: Double?
}

enum Stats {
    static let dir = NSHomeDirectory() + "/Library/Application Support/" + (isDevBuild ? "Tidymint Dev" : "Tidymint")
    static let oldDir = NSHomeDirectory() + "/Library/Application Support/Disk Cleanup"   // name before the rename
    static var path: String {
        let fm = FileManager.default
        if !isDevBuild && !fm.fileExists(atPath: dir) && fm.fileExists(atPath: oldDir) { try? fm.moveItem(atPath: oldDir, toPath: dir) }
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir + "/activity.log"
    }
    static func load() -> [LogEntry] {
        guard let s = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm"
        var out: [LogEntry] = []
        for line in s.split(separator: "\n") {
            let parts = line.components(separatedBy: " | ")
            guard parts.count >= 2, let d = df.date(from: parts[0].trimmingCharacters(in: .whitespaces)) else { continue }
            let msg = parts[1]
            var free: Double? = nil
            if parts.count >= 3 {
                let digits = parts[2].filter { $0.isNumber || $0 == "." }
                free = Double(digits)
            }
            out.append(LogEntry(date: d, text: msg, freed: freedBytes(msg), freeGB: free))
        }
        return out
    }
    /// Bytes freed by one log line. Lines that moved 0 files count as 0.
    static func freedBytes(_ m: String) -> Int64 {
        if m.hasPrefix("ERROR") { return 0 }
        let isUninstall = m.hasPrefix("Uninstalled") || m.hasPrefix("Đã gỡ")
        if !isUninstall {
            let firstNum = m.split(whereSeparator: { !$0.isNumber }).first.flatMap { Int($0) } ?? 0
            if firstNum == 0 { return 0 }
        }
        // First "(number unit)" group: an app name can carry its own parentheses ("Foo (Beta)").
        let units: [String: Double] = ["bytes": 1, "KB": 1e3, "MB": 1e6, "GB": 1e9, "TB": 1e12]
        var rest = m[...]
        while let open = rest.firstIndex(of: "("), let close = rest[open...].firstIndex(of: ")") {
            let bits = rest[rest.index(after: open)..<close].replacingOccurrences(of: ",", with: ".").split(separator: " ")
            if bits.count == 2, let v = Double(bits[0]), let mult = units[String(bits[1])] { return Int64(v * mult) }
            rest = rest[rest.index(after: close)...]
        }
        return 0
    }
}

/// Free space once per day (the last reading of the day), kept on this Mac for the Statistics chart. Nothing is sent anywhere.
enum DiskHistory {
    static var path: String { Stats.dir + "/disk-history.json" }
    static let key: DateFormatter = { let d = DateFormatter(); d.dateFormat = "yyyy-MM-dd"; d.locale = Locale(identifier: "en_US_POSIX"); return d }()
    static func load() -> [String: Double] {
        guard let d = FileManager.default.contents(atPath: path), let m = try? JSONDecoder().decode([String: Double].self, from: d) else { return [:] }
        return m
    }
    private static var lastWritten: (day: String, gb: Double)? = nil
    static func record(_ gb: Double) {
        let day = key.string(from: Date()), v = (gb * 10).rounded() / 10
        if let w = lastWritten, w.day == day, w.gb == v { return }   // unchanged: skip the read and rewrite of the file
        lastWritten = (day, v)
        var m = load()
        m[day] = v
        if m.count > 400 { for k in m.keys.sorted().prefix(m.count - 400) { m.removeValue(forKey: k) } }
        _ = Stats.path
        if let d = try? JSONEncoder().encode(m) { try? d.write(to: URL(fileURLWithPath: path)) }
    }
    struct Day: Identifiable { let date: Date; let free: Double; let freed: Int64; var id: Date { date } }
    /// One point per day for the last `days` days: the daily record, or the last value from the activity log for days before it existed.
    static func series(days: Int, log: [LogEntry]) -> [Day] {
        let cal = Calendar.current
        var free: [String: Double] = [:]
        var cleaned: [String: Int64] = [:]
        for e in log {   // the log is in time order, so the last reading of each day wins
            let k = key.string(from: e.date)
            if let f = e.freeGB { free[k] = f }
            cleaned[k, default: 0] += e.freed
        }
        for (k, v) in load() { free[k] = v }   // the daily record is preferred where it exists
        let today = cal.startOfDay(for: Date())
        return (0..<days).reversed().compactMap { back in
            guard let d = cal.date(byAdding: .day, value: -back, to: today) else { return nil }
            let k = key.string(from: d)
            guard let f = free[k] else { return nil }
            return Day(date: d, free: f, freed: cleaned[k] ?? 0)
        }
    }
}

final class RangePick: ObservableObject { @Published var days = 30; @Published var sel: Date? = nil }

// MARK: - Stats page

struct StatsView: View {
    @ObservedObject var vm: VM
    @StateObject private var tick = Flag()
    var body: some View {
        let log = Stats.load()
        let freed = log.reduce(0) { $0 + $1.freed }
        let runs = log.filter { $0.freed > 0 }.count
        let df: DateFormatter = { let f = DateFormatter(); f.dateFormat = "dd/MM HH:mm"; return f }()
        VStack(alignment: .leading, spacing: 16) {
            Text(t("Statistics", "Thống kê")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text).padding(.top, 34)
            HStack(spacing: 12) {
                statCard(t("Freed in total", "Tổng đã giải phóng"), fmt(freed))
                statCard(t("Cleanups", "Số lần dọn"), "\(runs)")
                statCard(t("Free now", "Đang trống"), String(format: "%.0f GB", vm.freeGB))
                statCard(t("Trash now", "Thùng rác"), fmt(vm.trashSize))
            }
            FreeSpaceChart(vm: vm, log: log)
            HStack {
                Text(t("Recent activity", "Hoạt động gần đây")).font(.system(size: fs(12), weight: .semibold)).foregroundColor(Theme.sub)
                Spacer()
                TextLink(t("Open log file", "Mở file nhật ký"), url: URL(fileURLWithPath: Stats.path))
            }
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(log.reversed().prefix(60)) { e in
                        HStack(alignment: .top, spacing: 10) {
                            Text(df.string(from: e.date)).font(.system(size: fs(11)).monospacedDigit()).foregroundColor(Theme.sub).frame(width: 78, alignment: .leading)
                            Text(e.text).font(.system(size: fs(12))).foregroundColor(e.text.hasPrefix("ERROR") ? Theme.danger : Theme.text).lineLimit(2)
                            Spacer()
                            if e.freed > 0 { Text("+" + fmt(e.freed)).font(.system(size: fs(11), weight: .semibold)).foregroundColor(Theme.green) }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .hoverBG(8, Theme.ink.opacity(0.06))
                    }
                }
            }
        }
        .padding(.horizontal, 24).padding(.bottom, 16)
        .onAppear { vm.refreshTrash(); vm.refreshDisk(); tick.v.toggle() }
    }
    func statCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: fs(11))).foregroundColor(Theme.sub)
            Text(value).font(.system(size: fs(22), weight: .bold)).foregroundColor(Theme.text)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
        .hoverBG(12, Theme.ink.opacity(0.05))
    }
}
