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

/// Update check: when the window opens, at most once a day, asks update.tidymint.app (backup: tidymint.app, then GitHub)
/// for the latest version number and shows a line if it is newer. No auto-install. Off in Settings: no automatic check.
enum Updates {
    static let api = URL(string: "https://api.github.com/repos/HaiTrung-Workspace/tidymint/releases/latest")!
    static let page = URL(string: "https://github.com/HaiTrung-Workspace/tidymint/releases/latest")!
    static var current: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }
    static func parts(_ v: String) -> [Int] { v.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").map { Int($0) ?? 0 } }
    static func newer(_ a: String, than b: String) -> Bool {
        let x = parts(a), y = parts(b)
        for i in 0..<max(x.count, y.count) { let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0; if p != q { return p > q } }
        return false
    }
    /// Calls back with the newer version string, or nil. Skips the network when the last check was under a day ago.
    static func check(force: Bool = false, _ done: @escaping (String?) -> Void) {
        let ud = UserDefaults.standard
        let last = ud.object(forKey: "upd-last") as? Date ?? .distantPast
        if !force, Date().timeIntervalSince(last) < 86400 {
            let cached = ud.string(forKey: "upd-latest") ?? ""
            done(newer(cached, than: current) ? cached : nil); return
        }
        // Plain text first: update.tidymint.app (counts the check per day, app version and macOS from the standard
        // User-Agent, nothing else is sent and no IP is kept; code in app/dev/worker-update), then the copy on the website,
        // then GitHub's API. Each is tried only if the one before gave no version.
        func plain(_ urls: [URL], _ fallback: @escaping () -> Void) {
            guard let u = urls.first else { fallback(); return }
            var req = URLRequest(url: u); req.timeoutInterval = 6; req.cachePolicy = .reloadIgnoringLocalCacheData
            URLSession.shared.dataTask(with: req) { data, resp, _ in
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if code == 200, let d = data, let v = String(data: d, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   v.range(of: #"^v?\d+(\.\d+){1,3}$"#, options: .regularExpression) != nil {   // a Wi-Fi login page also answers 200
                    DispatchQueue.main.async { record(v, done) }; return
                }
                plain(Array(urls.dropFirst()), fallback)
            }.resume()
        }
        let isDev = Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true   // the Dev build is not counted
        plain(isDev ? [site] : [counter, site]) {
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
