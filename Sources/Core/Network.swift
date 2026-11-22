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

/// Update check, always on (the switch in Settings went on 20/11/2026): at most once a day while the app runs, asks
/// update.tidymint.app (backup: tidymint.app, then GitHub) for the latest version number, with the usage counts; in
/// between, every 6 hours, only the version file on tidymint.app. Shows a line if it is newer. No auto-install.
/// A copy that must stay out of every count: the Dev build, and any Mac of the team
/// (`defaults write com.haitrung.diskcleanup internalUse -bool true`). Such a copy still learns about new versions,
/// from tidymint.app, but adds nothing to the checks, the Download clicks, usage statistics or the check-in card.
enum Uncounted {
    static var on: Bool { isDevBuild || UserDefaults.standard.bool(forKey: "internalUse") }
}

enum Updates {
    static let api = URL(string: "https://api.github.com/repos/HaiTrung-Workspace/tidymint/releases/latest")!
    static let page = URL(string: "https://github.com/HaiTrung-Workspace/tidymint/releases/latest")!
    /// Where the Download button goes: update.tidymint.app counts the click by version and passes the browser on to `page`.
    static var download: URL {
        if Uncounted.on { return page }
        return URL(string: "https://update.tidymint.app/update?from=\(current)") ?? page
    }
    static var current: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }
    static func parts(_ v: String) -> [Int] { v.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").map { Int($0) ?? 0 } }
    static func newer(_ a: String, than b: String) -> Bool {
        let x = parts(a), y = parts(b)
        for i in 0..<max(x.count, y.count) { let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0; if p != q { return p > q } }
        return false
    }
    /// Calls back with the newer version string, or nil. update.tidymint.app (the counted check, with the usage counts)
    /// at most once a day; in between, every 6 hours, only the version file on the website, which counts and sends
    /// nothing (20/11/2026: a new version reached people too slowly). Under 6 hours since any check: no network.
    /// `source`: "w" from the window, "b" from the hourly look while the app sits in the menu bar.
    static func check(force: Bool = false, source: String = "w", _ done: @escaping (String?) -> Void) {
        let ud = UserDefaults.standard
        let last = ud.object(forKey: "upd-last") as? Date ?? .distantPast
        let any = max(last, ud.object(forKey: "upd-last-any") as? Date ?? .distantPast)
        if !force, Date().timeIntervalSince(any) < 6 * 3600 {
            let cached = ud.string(forKey: "upd-latest") ?? ""
            done(newer(cached, than: current) ? cached : nil); return
        }
        if !force, Date().timeIntervalSince(last) < 86400 {
            var req = URLRequest(url: site); req.timeoutInterval = 6; req.cachePolicy = .reloadIgnoringLocalCacheData
            URLSession.shared.dataTask(with: req) { data, resp, _ in
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                let v = data.flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    if code == 200, let v, v.range(of: #"^v?\d+(\.\d+){1,3}$"#, options: .regularExpression) != nil {
                        ud.set(Date(), forKey: "upd-last-any"); ud.set(v, forKey: "upd-latest")
                        done(newer(v, than: current) ? v : nil)
                    } else {
                        let cached = ud.string(forKey: "upd-latest") ?? ""
                        done(newer(cached, than: current) ? cached : nil)
                    }
                }
            }.resume()
            return
        }
        // Plain text first: update.tidymint.app (counts the check per day; code in backend/update-worker.js), then the
        // copy on the website, then GitHub's API. Each is tried only if the one before gave no version.
        func plain(_ urls: [URL], _ fallback: @escaping () -> Void) {
            guard let u = urls.first else { fallback(); return }
            var req = URLRequest(url: u); req.timeoutInterval = 6; req.cachePolicy = .reloadIgnoringLocalCacheData
            URLSession.shared.dataTask(with: req) { data, resp, _ in
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if code == 200, let d = data, let v = String(data: d, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   v.range(of: #"^v?\d+(\.\d+){1,3}$"#, options: .regularExpression) != nil {   // a Wi-Fi login page also answers 200
                    if u.host == counter.host { Usage.checked() }
                    DispatchQueue.main.async { record(v, done) }; return
                }
                plain(Array(urls.dropFirst()), fallback)
            }.resume()
        }
        plain(Uncounted.on ? [site] : [Usage.stamped(counter, source: source), site]) {
            var r2 = URLRequest(url: api); r2.timeoutInterval = 8
            r2.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            URLSession.shared.dataTask(with: r2) { data, _, _ in
                var tag: String? = nil
                if let d = data, let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let tg = j["tag_name"] as? String { tag = tg }
                DispatchQueue.main.async { if let tg = tag { record(tg, done) } else { done(nil) } }
            }.resume()
        }
    }
    static let counter = URL(string: "https://update.tidymint.app/version")!
    static let site = URL(string: "https://tidymint.app/version.txt")!
    private static func record(_ v: String, _ done: (String?) -> Void) {
        let ud = UserDefaults.standard
        ud.set(Date(), forKey: "upd-last"); ud.set(v, forKey: "upd-latest")
        done(newer(v, than: current) ? v : nil)
    }
}

// MARK: - Usage statistics

/// A few counts a day, sent with the daily update check (always on since 20/11/2026: the switch was taken out of
/// Settings). Never from an uncounted copy, a demo or a self-test run. Fields and their shapes: backend/update-worker.js.
enum Usage {
    static let endpoint = URL(string: "https://update.tidymint.app/usage")!
    /// A build with more tools adds their counts here at launch, and their switches to `moreTools`.
    static var keys = ["opens", "cleans", "cleaned_mb", "uninstalls", "angle", "drop", "bar"]
    static var moreTools: () -> [Bool] = { [] }
    /// One character a build may add to the check ("p"), empty when it has nothing to say.
    static var plan: () -> String = { "" }
    private static let d = UserDefaults.standard
    private static let q = DispatchQueue(label: "app.tidymint.usage")
    private static var quiet: Bool { Uncounted.on || CommandLine.arguments.contains("--demo") || CommandLine.arguments.contains("--selftest") }

    static var on: Bool { !quiet }
    /// A random number for this copy of the app.
    static var id: String {
        if let v = d.string(forKey: "usage.id"), v.count == 32 { return v }
        let v = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        d.set(v, forKey: "usage.id"); return v
    }
    static var days: Int {
        guard let f = d.object(forKey: "firstOpenDate") as? Date else { return 0 }
        return max(0, Int(Date().timeIntervalSince(f) / 86400))
    }
    /// Which tools are switched on: Mintangle, Mintdrop, Mintbar, open at login, menu bar icon.
    static var tools: String {
        let login = SMAppService.mainApp.status == .enabled
        let flags = [d.bool(forKey: "mt.enabled"), d.bool(forKey: "sh.enabled"), d.bool(forKey: "mb.enabled"), login,
                     d.object(forKey: "showMenuBar") as? Bool ?? true] + moreTools()
        return flags.map { $0 ? "1" : "0" }.joined()
    }
    /// One more use of a tool today. Nothing is kept while the automatic check is off.
    static func count(_ key: String, _ n: Int = 1) {
        guard n > 0, keys.contains(key), on else { return }
        q.async {
            var c = d.dictionary(forKey: "usage.counts") as? [String: Int] ?? [:]
            c[key] = min((c[key] ?? 0) + n, 10_000_000)
            d.set(c, forKey: "usage.counts")
        }
    }
    /// A line of the activity log: one clean or one uninstall, and how much it freed.
    static func logged(_ line: String) {
        guard on, !line.hasPrefix("ERROR") else { return }
        count(line.hasPrefix("Uninstalled") || line.hasPrefix("Đã gỡ") ? "uninstalls" : "cleans")
        count("cleaned_mb", Int(Stats.freedBytes(line) / 1_000_000))
    }
    /// The update check address with the few extra fields.
    static func stamped(_ url: URL, source: String) -> URL {
        guard on, var c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        let n = days, age = n < 1 ? "d0" : n < 7 ? "d1" : n < 30 ? "d7" : n < 90 ? "d30" : "d90"
        c.queryItems = [URLQueryItem(name: "f", value: d.bool(forKey: "usage.first") ? "0" : "1"),
                        URLQueryItem(name: "a", value: age), URLQueryItem(name: "s", value: source == "b" ? "b" : "w"),
                        URLQueryItem(name: "l", value: appLang == "vi" ? "vi" : "en"),
                        URLQueryItem(name: "t", value: tools), URLQueryItem(name: "i", value: id)]
        let p = plan()
        if !p.isEmpty { c.queryItems?.append(URLQueryItem(name: "p", value: p)) }
        return c.url ?? url
    }
    /// After a check that reached update.tidymint.app: send the counts gathered since the last one, then start again from zero.
    static func checked() {
        guard on else { return }
        d.set(true, forKey: "usage.first")
        q.async {
            var c = d.dictionary(forKey: "usage.counts") as? [String: Int] ?? [:]
            c["days"] = days
            guard let body = try? JSONSerialization.data(withJSONObject: ["i": id, "d": c]) else { return }
            var req = URLRequest(url: endpoint); req.httpMethod = "POST"; req.timeoutInterval = 10; req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            d.removeObject(forKey: "usage.counts")
            URLSession.shared.dataTask(with: req) { _, _, _ in }.resume()
        }
    }
}

// MARK: - Feedback & newsletter

/// Where feedback and newsletter sign-ups go. `endpoint` is a Google Apps Script web app that appends
/// one row per submission to a Google Sheet (see backend/Code.gs). No email address is published on purpose.
enum Backend {
    static let endpoint = "https://script.google.com/macros/s/AKfycbz07aYQ8kI0u0OV842dt-LxeN5TedqfOzNvhmuVAPmgXdcIGtpzI-GNwLE_kiUMiGDKag/exec"
    /// Public privacy policy (PRIVACY.md on GitHub). The link is hidden while empty.
    static let privacyURL = "https://github.com/HaiTrung-Workspace/tidymint/blob/main/PRIVACY.md"
    static let consentVersion = "2026-10"
    static var newsletterText: String {
        t("Get the latest updates. Unsubscribe any time.",
          "Nhận thông tin cập nhật mới nhất. Huỷ bất kỳ lúc nào.")
    }
    static var systemInfo: [String: String] {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        var model = "Mac"
        var size = 0; sysctlbyname("hw.model", nil, &size, nil, 0)
        if size > 0 { var buf = [CChar](repeating: 0, count: size); sysctlbyname("hw.model", &buf, &size, nil, 0); model = String(cString: buf) }
        return ["app": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
                "macos": "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)", "model": model, "lang": appLang]
    }
    static func send(_ fields: [String: String], done: @escaping @MainActor (Bool) -> Void) {
        guard let url = URL(string: endpoint), !endpoint.isEmpty else { Task { @MainActor in done(false) }; return }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 20
        req.setValue("text/plain;charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: fields)
        URLSession.shared.dataTask(with: req) { data, resp, err in
            let ok = err == nil && ((resp as? HTTPURLResponse)?.statusCode ?? 0) < 400
                && (String(data: data ?? Data(), encoding: .utf8) ?? "").contains("ok")
            Task { @MainActor in done(ok) }
        }.resume()
    }
    static func validEmail(_ e: String) -> Bool {
        e.range(of: #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
