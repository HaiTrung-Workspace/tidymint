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

// MARK: - Clean by app (rules)

/// One group of paths inside an app's data, with its own safety level and a plain explanation.
struct AppSection {
    let id: String
    let titleEN: String, titleVI: String
    /// Home-relative templates. A single "*" component matches every child folder (accounts, profiles).
    let paths: [String]
    let safety: Safety
    let whyEN: String, whyVI: String
    /// Offer the files by month so old media can be cleaned first.
    var byAge = false
    /// Skip a matched folder entirely if a database file sits directly inside it.
    var dbGuard = true
    /// Rows built by code instead of `paths` (AI models: one row per model, see AIModels.swift).
    var custom: (() -> [AppRow])? = nil
    var title: String { t(titleEN, titleVI) }
    var why: String { t(whyEN, whyVI) }
}

struct AppRule: Identifiable {
    let id: String
    let nameEN: String, nameVI: String
    let bundleIDs: [String]
    /// Folder whose presence means the app has data on this Mac.
    let marker: String
    let sections: [AppSection]
    /// A command-line tool or a cache with no app bundle: no "App removed" tag when no app is found.
    var noApp = false
    /// Present on this Mac when the data folder can move (AI model stores); `marker` is used when nil.
    var exists: (() -> Bool)? = nil
    /// Command-line programs that count as "open" (a Homebrew `ollama serve` has no bundle id).
    var processNames: [String] = []
    var name: String { t(nameEN, nameVI) }
}

enum AppRules {
    /// Expand a home-relative template, resolving one "*" level, to the folders that exist.
    static func expand(_ template: String) -> [URL] {
        let parts = template.split(separator: "/").map(String.init)
        var urls = [Scanner.home]
        for p in parts {
            var next: [URL] = []
            for u in urls {
                if p == "*" { next += Scanner.children(u, hidden: true).filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true } }
                else { let c = u.appendingPathComponent(p); if Scanner.fm.fileExists(atPath: c.path) { next.append(c) } }
            }
            urls = next
            if urls.isEmpty { return [] }
        }
        return urls
    }

    /// Items for one section: every matched folder, minus anything a database guard or the ignore list rejects.
    static func items(_ s: AppSection) -> [CleanItem] {
        var out: [CleanItem] = []
        for tpl in s.paths {
            for u in expand(tpl) where !Scanner.skip(u.path) {
                if s.dbGuard && Scanner.holdsDatabase(u) { continue }
                let size = Scanner.size(u)
                guard size > 0 else { continue }
                out.append(CleanItem(url: u, size: size, selected: s.safety == .safe))
            }
        }
        return out.sorted { $0.size > $1.size }
    }

    static func installed() -> [AppRule] { all.filter { $0.exists?() ?? Scanner.fm.fileExists(atPath: Scanner.home.appendingPathComponent($0.marker).path) } }
    /// The app, or one of its command-line programs, is running.
    static func isRunning(_ r: AppRule) -> Bool {
        if Scanner.running(r.bundleIDs) != nil { return true }
        return r.processNames.contains { name in
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep"); p.arguments = ["-x", name]
            p.standardOutput = Pipe(); p.standardError = Pipe()
            guard (try? p.run()) != nil else { return false }
            p.waitUntilExit(); return p.terminationStatus == 0
        }
    }

    // Rules below were measured on a real Mac (macOS 26, Oct 2026) unless marked "unverified".
    // Chromium browsers keep the HTTP cache under ~/Library/Caches/<vendor>/<profile> and the rest inside the profile.
    static func chromium(id: String, nameEN: String, nameVI: String, bundle: String, support: String, caches: String, aiModel: Bool = false) -> AppRule {
        var secs: [AppSection] = [
            AppSection(id: "cache", titleEN: "Browser cache", titleVI: "Bộ nhớ đệm trình duyệt",
                       paths: ["Library/Caches/\(caches)/*/Cache", "Library/Caches/\(caches)/*/Code Cache",
                               "Library/Application Support/\(support)/*/Cache", "Library/Application Support/\(support)/*/Code Cache",
                               "Library/Application Support/\(support)/*/GPUCache", "Library/Application Support/\(support)/*/DawnGraphiteCache",
                               "Library/Application Support/\(support)/*/DawnWebGPUCache", "Library/Application Support/\(support)/*/Service Worker/CacheStorage",
                               "Library/Application Support/\(support)/GrShaderCache", "Library/Application Support/\(support)/GraphiteDawnCache",
                               "Library/Application Support/\(support)/ShaderCache", "Library/Application Support/\(support)/component_crx_cache",
                               "Library/Application Support/\(support)/extensions_crx_cache", "Library/Application Support/\(support)/Crashpad/completed"],
                       safety: .safe,
                       whyEN: "Pages, scripts and images load from the network again. Logins, history and passwords are not touched.",
                       whyVI: "Trang web, script và ảnh sẽ tải lại từ mạng. Đăng nhập, lịch sử, mật khẩu không bị đụng.")]
        if aiModel {
            secs.append(AppSection(id: "ai", titleEN: "On-device AI models", titleVI: "Mô hình AI chạy tại máy",
                       paths: ["Library/Application Support/\(support)/OptGuideOnDeviceModel", "Library/Application Support/\(support)/OptGuideOnDeviceClassifierModel",
                               "Library/Application Support/\(support)/optimization_guide_model_store"],
                       safety: .review,
                       whyEN: "Models the browser downloaded for AI features (a few GB). It downloads them again when a feature needs them.",
                       whyVI: "Mô hình trình duyệt tải về cho tính năng AI (vài GB). Khi cần, trình duyệt sẽ tải lại."))
        }
        secs.append(AppSection(id: "profile", titleEN: "Logins, history, passwords", titleVI: "Đăng nhập, lịch sử, mật khẩu",
                       paths: ["Library/Application Support/\(support)/*/Cookies", "Library/Application Support/\(support)/*/History",
                               "Library/Application Support/\(support)/*/Login Data", "Library/Application Support/\(support)/*/Local Storage",
                               "Library/Application Support/\(support)/*/IndexedDB", "Library/Application Support/\(support)/*/Bookmarks"],
                       safety: .locked, whyEN: "Tidymint never touches these.", whyVI: "Tidymint không bao giờ đụng vào đây.", dbGuard: false))
        return AppRule(id: id, nameEN: nameEN, nameVI: nameVI, bundleIDs: [bundle], marker: "Library/Application Support/\(support)", sections: secs)
    }

    static let all: [AppRule] = [
        AppRule(id: "zalo", nameEN: "Zalo", nameVI: "Zalo", bundleIDs: ["com.vng.zalo"], marker: "Library/Application Support/ZaloData", sections: [
            AppSection(id: "cache", titleEN: "Cache, thumbnails, old installers", titleVI: "Bộ nhớ đệm, ảnh thu nhỏ, bản cài cũ",
                       paths: ["Library/Application Support/ZaloData/Cache", "Library/Application Support/ZaloData/Code Cache",
                               "Library/Application Support/ZaloData/GPUCache", "Library/Application Support/ZaloData/DawnCache",
                               "Library/Application Support/ZaloData/resp_cache", "Library/Application Support/ZaloData/media/temp",
                               "Library/Application Support/ZaloData/media/update",
                               "Library/Application Support/ZaloData/media/*/ZaloDownloads/Cache", "Library/Application Support/ZaloData/media/*/ZaloDownloads/fileThumb",
                               "Library/Application Support/ZaloData/media/*/ZaloDownloads/richThumb", "Library/Application Support/ZaloData/media/*/ZaloDownloads/sticker"],
                       safety: .safe,
                       whyEN: "Zalo rebuilds these on its own. The installer is re-downloaded at the next update.",
                       whyVI: "Zalo tự tạo lại. Bản cài sẽ tải lại khi có bản cập nhật mới."),
            AppSection(id: "picture", titleEN: "Photos in chats", titleVI: "Ảnh trong tin nhắn",
                       paths: ["Library/Application Support/ZaloData/media/*/ZaloDownloads/picture", "Library/Application Support/ZaloData/media/*/ZaloDownloads/resource"],
                       safety: .review,
                       whyEN: "Cleaning removes them from this Mac. Recent photos usually download again when you open the chat; old ones may be gone for good. Text messages are not affected.",
                       whyVI: "Dọn là mất trên máy này. Ảnh gần đây thường tải lại được khi mở lại cuộc trò chuyện, ảnh cũ có thể mất hẳn. Tin nhắn chữ không ảnh hưởng.",
                       byAge: true),
            AppSection(id: "video", titleEN: "Videos in chats", titleVI: "Video trong tin nhắn",
                       paths: ["Library/Application Support/ZaloData/media/*/ZaloDownloads/video"],
                       safety: .review,
                       whyEN: "May be gone for good on this Mac. Save the ones you want to keep first.",
                       whyVI: "Có thể mất hẳn trên máy này. Muốn giữ thì tải về trước.", byAge: true),
            AppSection(id: "file", titleEN: "Files and voice messages", titleVI: "File và tin nhắn thoại",
                       paths: ["Library/Application Support/ZaloData/media/*/ZaloDownloads/file", "Library/Application Support/ZaloData/media/*/ZaloDownloads/voice"],
                       safety: .review,
                       whyEN: "May be gone for good on this Mac. Save the ones you want to keep first.",
                       whyVI: "Có thể mất hẳn trên máy này. Muốn giữ thì tải về trước.", byAge: true),
            AppSection(id: "db", titleEN: "Messages", titleVI: "Tin nhắn",
                       paths: ["Library/Application Support/ZaloData/Database"],
                       safety: .locked, whyEN: "Your chat history. Tidymint never touches it.", whyVI: "Lịch sử trò chuyện. Tidymint không bao giờ đụng vào.", dbGuard: false),
        ]),
        chromium(id: "chrome", nameEN: "Google Chrome", nameVI: "Google Chrome", bundle: "com.google.Chrome", support: "Google/Chrome", caches: "Google/Chrome", aiModel: true),
        chromium(id: "edge", nameEN: "Microsoft Edge", nameVI: "Microsoft Edge", bundle: "com.microsoft.edgemac", support: "Microsoft Edge", caches: "Microsoft Edge", aiModel: true),
        // Unverified on a real Mac: folder names taken from the Chromium layout and public tooling that reads Cốc Cốc profiles.
        chromium(id: "coccoc", nameEN: "Cốc Cốc", nameVI: "Cốc Cốc", bundle: "com.coccoc.Coccoc", support: "Coccoc", caches: "Coccoc"),
        // Checked on a real Mac (App Store build, 10/2026): data in ~/Movies/CapCut/User Data, Settings > Draft and > Performance
        // offer their own delete buttons for Cache, rendering cache (prerender), proxies (agencycache) and remux files.
        // Other Cache subfolders can hold imported media, so they are left alone.
        AppRule(id: "capcut", nameEN: "CapCut", nameVI: "CapCut", bundleIDs: ["com.lemon.lvoverseas"], marker: "Movies/CapCut/User Data", sections: [
            // Pre-selected only what is shown to be rebuilt (thumbnails, waveforms, analysis caches, logs).
            // recognize (auto captions), ttsTemp (text-to-speech audio) and tmp are not verified: a project may point to them,
            // so they are offered but not pre-selected. Source: research/nguon-chinh-thuc/capcut.md
            AppSection(id: "cache", titleEN: "Scratch files", titleVI: "File tạm khi dựng video",
                       paths: ["frameThumbnail", "audioWave", "AlgorithmCache", "ILASDKDB"].map { "Movies/CapCut/User Data/Cache/\($0)" }
                              + ["Movies/CapCut/User Data/Log"],
                       safety: .safe,
                       whyEN: "Thumbnails, waveforms, analysis caches and logs. CapCut rebuilds them when you open a project.",
                       whyVI: "Ảnh thu nhỏ, sóng âm, dữ liệu phân tích, nhật ký. CapCut tự tạo lại khi mở dự án."),
            AppSection(id: "speech", titleEN: "Captions and voice-over scratch", titleVI: "File tạm phụ đề và giọng đọc",
                       paths: ["recognize", "ttsTemp", "tmp"].map { "Movies/CapCut/User Data/Cache/\($0)" },
                       safety: .review,
                       whyEN: "Working files for auto captions and text-to-speech. A project you are still editing may use them, so check before removing.",
                       whyVI: "File làm việc của phụ đề tự động và giọng đọc. Dự án đang dựng có thể còn dùng, nên xem kỹ trước khi bỏ."),
            AppSection(id: "render", titleEN: "Rendering cache and proxies", titleVI: "Bản dựng sẵn và proxy",
                       paths: ["prerender", "agencycache", "RemuxCache"].map { "Movies/CapCut/User Data/Cache/\($0)" },
                       safety: .review,
                       whyEN: "Preview renders, low-res proxies and converted copies of your clips. CapCut makes them again; previews may lag for a while. CapCut also clears them in Settings > Performance.",
                       whyVI: "Bản dựng sẵn, proxy và bản chuyển định dạng của video. CapCut tạo lại, xem trước có thể giật một lúc. Trong CapCut cũng xoá được ở Cài đặt › Performance."),
            AppSection(id: "projects", titleEN: "Projects", titleVI: "Dự án",
                       paths: ["Movies/CapCut/User Data/Projects"],
                       safety: .locked, whyEN: "Your edits. Tidymint never touches them.", whyVI: "Dự án bạn đang dựng. Tidymint không bao giờ đụng vào.", dbGuard: false),
        ]),
        // Measured on a real Mac (App Store build, 10/2026): media cache in postbox/media, chat database in postbox/db.
        AppRule(id: "telegram", nameEN: "Telegram", nameVI: "Telegram", bundleIDs: ["ru.keepcoder.Telegram"],
                marker: "Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/stable", sections: [
            AppSection(id: "cache", titleEN: "Temporary files and logs", titleVI: "File tạm và nhật ký",
                       paths: ["Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/stable/temp",
                               "Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/stable/logs",
                               "Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/stable/trlottie-animations"],
                       safety: .safe, whyEN: "Telegram rebuilds these on its own.", whyVI: "Telegram tự tạo lại."),
            AppSection(id: "media", titleEN: "Photos, videos and files in chats", titleVI: "Ảnh, video, file trong tin nhắn",
                       paths: ["Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/stable/*/postbox/media"],
                       safety: .review,
                       whyEN: "Local copies of media you viewed. Telegram downloads them again from its servers when you open the chat. Messages are not affected.",
                       whyVI: "Bản lưu trên máy của ảnh, video đã xem. Mở lại cuộc trò chuyện Telegram sẽ tải lại từ máy chủ. Tin nhắn không ảnh hưởng.",
                       byAge: true),
            AppSection(id: "db", titleEN: "Messages and login", titleVI: "Tin nhắn và đăng nhập",
                       paths: ["Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/stable/*/postbox/db"],
                       safety: .locked, whyEN: "Your chat history. Tidymint never touches it.", whyVI: "Lịch sử trò chuyện. Tidymint không bao giờ đụng vào.", dbGuard: false),
        ]),
        AppRule(id: "whatsapp", nameEN: "WhatsApp", nameVI: "WhatsApp", bundleIDs: ["net.whatsapp.WhatsApp"],
                marker: "Library/Group Containers/group.net.whatsapp.WhatsApp.shared", sections: [
            AppSection(id: "cache", titleEN: "Cache", titleVI: "Bộ nhớ đệm",
                       paths: ["Library/Containers/net.whatsapp.WhatsApp/Data/Library/Caches"],
                       safety: .safe, whyEN: "WhatsApp rebuilds this on its own.", whyVI: "WhatsApp tự tạo lại."),
            AppSection(id: "media", titleEN: "Photos, videos and files in chats", titleVI: "Ảnh, video, file trong tin nhắn",
                       paths: ["Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Message/Media"],
                       safety: .review,
                       whyEN: "Cleaning removes them from this Mac. They stay on your phone if the chat is still there; otherwise they may be gone for good.",
                       whyVI: "Dọn là mất trên máy này. Còn trên điện thoại nếu cuộc trò chuyện còn, không thì có thể mất hẳn.",
                       byAge: true),
            AppSection(id: "db", titleEN: "Messages and login", titleVI: "Tin nhắn và đăng nhập",
                       paths: ["Library/Group Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite"],
                       safety: .locked, whyEN: "Your chat history. Tidymint never touches it.", whyVI: "Lịch sử trò chuyện. Tidymint không bao giờ đụng vào.", dbGuard: false),
        ]),
        AppRule(id: "slack", nameEN: "Slack", nameVI: "Slack", bundleIDs: ["com.tinyspeck.slackmacgap"],
                marker: "Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application Support/Slack", sections: [
            AppSection(id: "cache", titleEN: "Cache and logs", titleVI: "Bộ nhớ đệm và nhật ký",
                       paths: ["Cache", "Code Cache", "GPUCache", "GPUPersistentCache", "DawnGraphiteCache", "DawnWebGPUCache", "GraphiteDawnCache",
                               "Service Worker/CacheStorage", "logs", "Crashpad/completed"].map { "Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application Support/Slack/\($0)" },
                       safety: .safe,
                       whyEN: "Pages, images and scripts load again from Slack's servers. Logins and messages are not touched.",
                       whyVI: "Giao diện, ảnh, script sẽ tải lại từ máy chủ Slack. Đăng nhập và tin nhắn không bị đụng."),
            AppSection(id: "profile", titleEN: "Login and workspace data", titleVI: "Đăng nhập và dữ liệu workspace",
                       paths: ["IndexedDB", "Local Storage", "Cookies", "storage"].map { "Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application Support/Slack/\($0)" },
                       safety: .locked, whyEN: "Tidymint never touches these.", whyVI: "Tidymint không bao giờ đụng vào.", dbGuard: false),
        ]),
        AppRule(id: "vscode", nameEN: "Visual Studio Code", nameVI: "Visual Studio Code", bundleIDs: ["com.microsoft.VSCode"],
                marker: "Library/Application Support/Code", sections: [
            AppSection(id: "cache", titleEN: "Cache and logs", titleVI: "Bộ nhớ đệm và nhật ký",
                       paths: ["Cache", "CachedData", "CachedExtensionVSIXs", "CachedProfilesData", "Code Cache", "GPUCache", "DawnGraphiteCache", "DawnWebGPUCache", "logs", "Crashpad/completed"].map { "Library/Application Support/Code/\($0)" }
                              + ["Library/Caches/com.microsoft.VSCode"],
                       safety: .safe,
                       whyEN: "VS Code rebuilds these on next launch. Settings, extensions and projects are not touched.",
                       whyVI: "VS Code tự tạo lại khi mở. Cài đặt, tiện ích mở rộng, dự án không bị đụng."),
            AppSection(id: "agent", titleEN: "AI agent SDK cache", titleVI: "Bộ nhớ đệm SDK trợ lý AI",
                       paths: ["Library/Application Support/Code/agent-host/sdk-cache"],
                       safety: .review,
                       whyEN: "Downloaded by the built-in AI agent features. Re-downloaded when needed.",
                       whyVI: "Tính năng trợ lý AI tải về. Khi cần sẽ tải lại."),
            AppSection(id: "workspace", titleEN: "Per-project state", titleVI: "Trạng thái từng dự án",
                       paths: ["Library/Application Support/Code/User/workspaceStorage", "Library/Application Support/Code/User/History"],
                       safety: .review,
                       whyEN: "Open editors, unsaved-file history and extension state per project. Cleaning loses that memory, not your files.",
                       whyVI: "Tab đang mở, lịch sử file chưa lưu, trạng thái tiện ích của từng dự án. Dọn là mất phần ghi nhớ này, không mất file."),
            AppSection(id: "settings", titleEN: "Settings and extensions", titleVI: "Cài đặt và tiện ích mở rộng",
                       paths: ["Library/Application Support/Code/User/settings.json", "Library/Application Support/Code/User/globalStorage", ".vscode/extensions"],
                       safety: .locked, whyEN: "Tidymint never touches these.", whyVI: "Tidymint không bao giờ đụng vào.", dbGuard: false),
        ]),
        AppRule(id: "outlook", nameEN: "Microsoft Outlook", nameVI: "Microsoft Outlook", bundleIDs: ["com.microsoft.Outlook"],
                marker: "Library/Group Containers/UBF8T346G9.Office/Outlook", sections: [
            AppSection(id: "cache", titleEN: "Cache and logs", titleVI: "Bộ nhớ đệm và nhật ký",
                       paths: ["Library/Containers/com.microsoft.Outlook/Data/Library/Caches", "Library/Containers/com.microsoft.Outlook/Data/Library/Logs"],
                       safety: .safe, whyEN: "Outlook rebuilds these on its own.", whyVI: "Outlook tự tạo lại."),
            AppSection(id: "addins", titleEN: "Add-in packages", titleVI: "Gói tiện ích bổ sung",
                       paths: ["Library/Group Containers/UBF8T346G9.Office/SolutionPackages", "Library/Group Containers/UBF8T346G9.Office/Outlook/Outlook 15 Profiles/*/Osa"],
                       safety: .review,
                       whyEN: "Office add-ins downloaded for Outlook. They download again the next time an add-in is used.",
                       whyVI: "Tiện ích bổ sung Office tải về cho Outlook. Lần sau dùng tiện ích sẽ tải lại."),
            AppSection(id: "mail", titleEN: "Mail, attachments and accounts", titleVI: "Thư, tệp đính kèm, tài khoản",
                       paths: ["Library/Group Containers/UBF8T346G9.Office/Outlook/Outlook 15 Profiles"],
                       safety: .locked,
                       whyEN: "Your mailbox. Tidymint never touches it; to shrink it, use Outlook's own storage settings.",
                       whyVI: "Hộp thư của bạn. Tidymint không bao giờ đụng vào; muốn giảm thì dùng mục lưu trữ trong Outlook.", dbGuard: false),
        ]),
        // Local AI models: one row per model (AIModels.swift). Never pre-selected.
        AppRule(id: "ollama", nameEN: "Ollama", nameVI: "Ollama", bundleIDs: ["com.electron.ollama", "com.ollama.ollama"], marker: ".ollama/models", sections: [
            AppSection(id: "models", titleEN: "AI models", titleVI: "Model AI", paths: [], safety: .review,
                       whyEN: "Large, and you can download them again. Tick the models you no longer use; they go to the Trash.",
                       whyVI: "Nặng và tải lại được. Tick model bạn không còn dùng, chúng vào Thùng rác.", dbGuard: false, custom: { AIModels.ollamaRows() }),
            AppSection(id: "key", titleEN: "Sign-in key", titleVI: "Khoá đăng nhập", paths: [],
                       safety: .locked, whyEN: "This Mac's private key for ollama.com. Tidymint never touches it.", whyVI: "Khoá riêng của máy này cho ollama.com. Tidymint không bao giờ đụng vào.", dbGuard: false, custom: { AIModels.ollamaKeyRows() }),
        ], noApp: true, exists: { AIModels.ollamaPresent }, processNames: ["ollama"]),
        AppRule(id: "huggingface", nameEN: "Hugging Face", nameVI: "Hugging Face", bundleIDs: [], marker: ".cache/huggingface/hub", sections: [
            AppSection(id: "models", titleEN: "AI models and datasets", titleVI: "Model AI và bộ dữ liệu", paths: [], safety: .review,
                       whyEN: "Large, and you can download them again. Tick the models you no longer use; they go to the Trash.",
                       whyVI: "Nặng và tải lại được. Tick model bạn không còn dùng, chúng vào Thùng rác.", dbGuard: false, custom: { AIModels.huggingFaceRows() }),
            AppSection(id: "token", titleEN: "Sign-in token", titleVI: "Mã đăng nhập", paths: [],
                       safety: .locked, whyEN: "Your Hugging Face sign-in. Tidymint never touches it.", whyVI: "Đăng nhập Hugging Face của bạn. Tidymint không bao giờ đụng vào.", dbGuard: false, custom: { AIModels.hfTokenRows() }),
        ], noApp: true, exists: { AIModels.hfPresent }),
        AppRule(id: "lmstudio", nameEN: "LM Studio", nameVI: "LM Studio", bundleIDs: ["ai.elementlabs.lmstudio"], marker: ".lmstudio", sections: [
            AppSection(id: "models", titleEN: "AI models", titleVI: "Model AI", paths: [], safety: .review,
                       whyEN: "Large, and you can download them again. Tick the models you no longer use; they go to the Trash.",
                       whyVI: "Nặng và tải lại được. Tick model bạn không còn dùng, chúng vào Thùng rác.", dbGuard: false, custom: { AIModels.lmStudioRows() }),
            AppSection(id: "old-engines", titleEN: "Old engine versions", titleVI: "Bộ máy bản cũ", paths: [], safety: .review,
                       whyEN: "Left behind when LM Studio updated its engines. The versions in use are kept, so your models still run.",
                       whyVI: "Còn sót lại sau khi LM Studio cập nhật bộ máy. Bản đang dùng được giữ nguyên nên model vẫn chạy.", dbGuard: false, custom: { AIModels.lmsEngines().old }),
            AppSection(id: "engines", titleEN: "Engines in use", titleVI: "Bộ máy đang dùng", paths: [],
                       safety: .locked, whyEN: "LM Studio needs these to run models. Tidymint never touches them.", whyVI: "LM Studio cần chúng để chạy model. Tidymint không bao giờ đụng vào.", dbGuard: false, custom: { AIModels.lmsEngines().kept }),
        ], noApp: true, exists: { AIModels.lmsPresent }),
    ]
}

/// What the clean-by-app scan produces.
struct AppRow: Identifiable {
    let id: String
    let title: String, sub: String
    let size: Int64
    let count: Int
    let urls: [URL]
    let month: Date?          // for by-age rows: the first day of that month
    var selected: Bool
    /// Month rows: the files picked one by one in the month viewer (nil = the whole row, companion files included).
    var picked: Set<String>? = nil
    var pickedSize: Int64 = 0
    var pickedCount = 0          // photos picked (a photo may have several copies on disk)
    /// Data this row shares with other rows of its group (Ollama blobs): key -> (size, files). It is freed only when
    /// every row that shares it is ticked, and it counts once in the group's totals.
    var shared: [String: SharedPart] = [:]
    var selSize: Int64 { !selected ? 0 : (picked == nil ? size : pickedSize) }
    var checkState: Int { !selected ? 0 : (picked == nil ? 2 : 1) }
    var selURLs: [URL] { !selected ? [] : (picked.map { p in urls.filter { p.contains($0.path) } } ?? urls) }
    /// Under the title in the list: "84 files", plus what was picked one by one in the month viewer.
    var subLine: String {
        guard checkState == 1 else { return sub }
        let n = pickedCount, z = fmt(pickedSize)
        return sub + t(" · \(n) picked (\(z))", " · đã chọn \(n) (\(z))")
    }
}
struct SharedPart { let size: Int64; let urls: [URL] }
struct AppGroup: Identifiable {
    let id: String
    let section: AppSection
    var rows: [AppRow]
    var expanded = false
    /// Shared parts, each once; `freed` keeps only those whose every sharer is ticked.
    func sharedParts(freed: Bool) -> [SharedPart] {
        var seen: [String: SharedPart] = [:], blocked: Set<String> = []
        for r in rows { for (k, p) in r.shared { seen[k] = p; if !r.selected { blocked.insert(k) } } }
        return seen.filter { !freed || !blocked.contains($0.key) }.map(\.value)
    }
    var total: Int64 { rows.reduce(0) { $0 + $1.size } + sharedParts(freed: false).reduce(0) { $0 + $1.size } }
    var selected: Int64 { rows.reduce(0) { $0 + $1.selSize } + sharedParts(freed: true).reduce(0) { $0 + $1.size } }
    var state: Int {
        if rows.allSatisfy({ $0.checkState == 2 }) { return 2 }
        return rows.contains(where: { $0.checkState > 0 }) ? 1 : 0
    }
}
struct AppReport: Identifiable {
    let rule: AppRule
    var groups: [AppGroup]
    var running: Bool
    var id: String { rule.id }
    var total: Int64 { groups.reduce(0) { $0 + $1.total } }
    var cleanable: Int64 { groups.filter { $0.section.safety != .locked }.reduce(0) { $0 + $1.total } }
    var selected: Int64 { groups.reduce(0) { $0 + $1.selected } }
}

extension AppRules {
    static func monthStart(_ d: Date) -> Date {
        let c = Calendar.current
        return c.date(from: c.dateComponents([.year, .month], from: d)) ?? d
    }
    static func monthLabel(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: appLang == "vi" ? "vi_VN" : "en_US"); f.dateFormat = appLang == "vi" ? "'Tháng' M/yyyy" : "MMMM yyyy"
        return f.string(from: d)
    }

    /// Rows for one section: one per matched folder, or one per month when the section is split by age.
    static func rows(_ s: AppSection) -> [AppRow] {
        let home = Scanner.home.path + "/"
        func short(_ u: URL) -> String { u.path.hasPrefix(home) ? "~/" + u.path.dropFirst(home.count) : u.path }
        if let c = s.custom { return c() }
        if !s.byAge {
            return items(s).map { AppRow(id: $0.url.path, title: $0.name, sub: short($0.url), size: $0.size, count: 1, urls: [$0.url], month: nil, selected: $0.selected) }
        }
        var bucket: [Date: (size: Int64, urls: [URL], index: Int)] = [:]   // index = app index files (Zalo .rescache), not counted as files
        var copies: [Date: Set<String>] = [:]   // Zalo photo keys seen per month: copies of one photo count once
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey, .contentModificationDateKey]
        for tpl in s.paths {
            for folder in expand(tpl) where !Scanner.skip(folder.path) {
                if s.dbGuard && Scanner.holdsDatabase(folder) { continue }
                guard let en = Scanner.fm.enumerator(at: folder, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, _ in true }) else { continue }
                for case let f as URL in en {
                    guard let v = try? f.resourceValues(forKeys: keys), v.isRegularFile == true, !Scanner.isDatabase(f) else { continue }
                    let m = monthStart(v.contentModificationDate ?? Date())
                    bucket[m, default: (0, [], 0)].size += Int64(v.totalFileAllocatedSize ?? 0)
                    bucket[m, default: (0, [], 0)].urls.append(f)
                    if MonthItem.isCompanion(f) { bucket[m, default: (0, [], 0)].index += 1 }
                    else if let k = MonthItem.variantKey(f) {
                        if copies[m, default: []].contains(k) { bucket[m, default: (0, [], 0)].index += 1 } else { copies[m, default: []].insert(k) }
                    }
                }
            }
        }
        return bucket.keys.sorted(by: >).map { m in
            let b = bucket[m]!
            let n = b.urls.count - b.index
            let sub = n > 0 ? t("\(n) files", "\(n) file")
                            : t("only \(b.index) index files of the app", "chỉ còn \(b.index) tệp chỉ mục của app")
            return AppRow(id: s.id + "|" + ISO8601DateFormatter().string(from: m), title: monthLabel(m),
                          sub: sub, size: b.size, count: n, urls: b.urls, month: m, selected: false)
        }.filter { $0.size > 0 }
    }

    static func scan() -> [AppReport] {
        installed().compactMap { rule in
            let groups = rule.sections.map { AppGroup(id: $0.id, section: $0, rows: rows($0)) }.filter { !$0.rows.isEmpty }
            guard groups.contains(where: { $0.section.safety != .locked }) else { return nil }
            return AppReport(rule: rule, groups: groups, running: isRunning(rule))
        }
    }
}
