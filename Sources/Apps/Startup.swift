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

// MARK: - Startup model

/// Code-signing state of the program a launch item starts. Facts from codesign/spctl, no verdict.
enum SignState {
    case unknown, apple, developer(String), adhoc, unsigned, invalid, script, empty
    var label: String {
        switch self {
        case .unknown: return ""
        case .empty: return t("Empty, does nothing", "Rỗng, không làm gì")
        case .apple: return "Apple"
        case .developer(let n): return n
        case .adhoc: return t("Ad-hoc signed", "Ký tạm")
        case .unsigned: return t("Unsigned", "Chưa ký")
        case .invalid: return t("Signature invalid or revoked", "Chữ ký hỏng hoặc bị thu hồi")
        case .script: return t("Script", "Script")
        }
    }
    var color: Color {
        switch self {
        case .unknown, .apple, .adhoc, .script, .empty: return Theme.sub
        case .developer: return Theme.green
        case .unsigned: return Theme.warn
        case .invalid: return Theme.danger
        }
    }
    var help: String {
        switch self {
        case .apple: return t("Signed by Apple.", "Do Apple ký.")
        case .developer: return t("Signed with an Apple Developer ID. The maker is known.", "Ký bằng Developer ID của Apple. Biết được hãng làm ra.")
        case .adhoc: return t("Signed without a registered identity. Common for tools from Homebrew or built locally; fine if you installed it yourself.", "Ký không có danh tính đăng ký. Thường gặp ở tool cài qua Homebrew hoặc tự build; ổn nếu bạn tự cài.")
        case .unsigned: return t("No signature, so the maker cannot be confirmed. Check that it belongs to software you know.", "Không có chữ ký nên không xác nhận được ai làm ra. Kiểm tra xem nó thuộc phần mềm bạn biết không.")
        case .invalid: return t("The signature does not verify, or Apple revoked the certificate. Apple revokes certificates when it finds a problem.", "Chữ ký không khớp, hoặc Apple đã thu hồi chứng chỉ. Apple thu hồi khi phát hiện có vấn đề.")
        case .script: return t("Starts a script. Scripts cannot be signed, so make sure it belongs to software you know.", "Khởi động một script. Script không ký được, hãy chắc nó thuộc phần mềm bạn biết.")
        case .empty: return t("The file names no program, so it starts nothing. Usually left behind by an updater that removed itself. Safe to remove.", "File không ghi chương trình nào nên không khởi động gì. Thường là vỏ còn lại của trình cập nhật đã tự gỡ. Gỡ được.")
        case .unknown: return ""
        }
    }
}

/// Structural red flags, the patterns adware uses to persist. Each one is "worth a look", never "malware".
enum LaunchFlag: Hashable {
    case fakeApple, hiddenDir, tempDir, randomName, inlineScript
    var label: String {
        switch self {
        case .fakeApple: return t("Looks like an Apple name", "Tên giống của Apple")
        case .hiddenDir: return t("In a hidden folder", "Nằm trong thư mục ẩn")
        case .tempDir: return t("In a temp or shared folder", "Nằm trong thư mục tạm")
        case .randomName: return t("Random-looking name", "Tên như chuỗi ngẫu nhiên")
        case .inlineScript: return t("Runs a shell command", "Chạy thẳng lệnh shell")
        }
    }
    var help: String {
        switch self {
        case .fakeApple: return t("The label starts with com.apple but the program is not in an Apple system folder. Apple never installs items here.", "Nhãn bắt đầu bằng com.apple nhưng chương trình không nằm trong thư mục hệ thống của Apple. Apple không bao giờ cài mục ở đây.")
        case .hiddenDir: return t("Normal software does not hide its program in a dot-folder.", "Phần mềm bình thường không giấu chương trình trong thư mục có dấu chấm.")
        case .tempDir: return t("Anything can write to temp and shared folders; normal software does not run from there at startup.", "Ai cũng ghi được vào thư mục tạm và thư mục chia sẻ; phần mềm bình thường không khởi động từ đó.")
        case .randomName: return t("Generated-looking names are a common way to avoid being recognised.", "Tên sinh ngẫu nhiên là cách phổ biến để tránh bị nhận ra.")
        case .inlineScript: return t("Runs a command through a shell instead of an app, so there is nothing to sign.", "Chạy lệnh qua shell thay vì mở app, nên không có gì để ký.")
        }
    }
}

struct LaunchEntry: Identifiable {
    let id = UUID()
    let url: URL
    let label: String
    let program: String
    let scope: Int          // 0: this user (~/Library), 1: all users agent, 2: all users daemon (needs admin)
    let running: Bool?
    let orphan: Bool
    var sign: SignState = .unknown
    var flags: [LaunchFlag] = []
    var attention: Bool {
        if case .invalid = sign { return true }
        return !flags.isEmpty
    }
    var selected = false
    var owner: String {
        let l = label.lowercased()
        let known: [(String, String)] = [("google", "Google (Chrome/Drive)"), ("adobe", "Adobe"), ("microsoft", "Microsoft"), ("teamviewer", "TeamViewer"),
            ("macpaw", "CleanMyMac"), ("p5sys", "Jump Desktop"), ("mullvad", "Mullvad VPN"), ("alt-tab", "AltTab"), ("sunshine", "Sunshine"),
            ("dropbox", "Dropbox"), ("zoom", "Zoom"), ("spotify", "Spotify")]
        for (k, v) in known where l.contains(k) { return v }
        if let app = program.range(of: ".app/") { return ((String(program[..<app.lowerBound]) as NSString).lastPathComponent) }
        return label
    }
}

enum Startup {
    static func scan() -> [LaunchEntry] {
        let fm = FileManager.default
        // labels loaded in the user session
        var loaded = Set<String>()
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/launchctl"); p.arguments = ["list"]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        if (try? p.run()) != nil {
            let d = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
            for line in (String(data: d, encoding: .utf8) ?? "").split(separator: "\n") {
                if let last = line.split(separator: "\t").last { loaded.insert(String(last)) }
            }
        }
        let dirs: [(String, Int)] = [(NSHomeDirectory() + "/Library/LaunchAgents", 0), ("/Library/LaunchAgents", 1), ("/Library/LaunchDaemons", 2)]
        var out: [LaunchEntry] = []
        for (dir, scope) in dirs {
            for f in (try? fm.contentsOfDirectory(atPath: dir)) ?? [] where f.hasSuffix(".plist") {
                let u = URL(fileURLWithPath: dir).appendingPathComponent(f)
                let d = NSDictionary(contentsOf: u) as? [String: Any] ?? [:]
                let label = d["Label"] as? String ?? String(f.dropLast(6))
                let prog = d["Program"] as? String ?? (d["ProgramArguments"] as? [String])?.first ?? ""
                let orphan = prog.hasPrefix("/") && !prog.hasPrefix("/usr/") && !prog.hasPrefix("/bin/") && !prog.hasPrefix("/System/") && !fm.fileExists(atPath: prog)
                out.append(LaunchEntry(url: u, label: label, program: prog, scope: scope,
                                       running: scope == 2 ? nil : loaded.contains(label), orphan: orphan,
                                       // A program on an external drive is only missing while the drive is unplugged: never pre-selected.
                                       selected: orphan && scope == 0 && !prog.hasPrefix("/Volumes/")))
            }
        }
        return out.sorted { ($0.scope, $0.owner.lowercased()) < ($1.scope, $1.owner.lowercased()) }
    }

    static func run(_ exe: String, _ args: [String]) -> (Int32, String) {
        let p = Process(); p.executableURL = URL(fileURLWithPath: exe); p.arguments = args
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        do { try p.run() } catch { return (-1, "") }
        let d = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        return (p.terminationStatus, String(data: d, encoding: .utf8) ?? "")
    }

    static let interpreters: Set<String> = ["sh", "bash", "zsh", "python", "python3", "perl", "ruby", "osascript", "node"]

    /// The thing to check with codesign: the .app bundle when the program sits inside one, else the program itself.
    static func signTarget(_ program: String) -> String {
        if let r = program.range(of: ".app/") { return String(program[..<r.upperBound].dropLast()) }
        return program
    }

    /// Signature state and red flags for one item. Facts only; runs codesign and spctl, so call it off the main thread.
    static func inspect(_ e: LaunchEntry) -> (SignState, [LaunchFlag]) {
        var flags: [LaunchFlag] = []
        let d = NSDictionary(contentsOf: e.url) as? [String: Any] ?? [:]
        let args = d["ProgramArguments"] as? [String] ?? []
        let prog = e.program
        let exeName = (prog as NSString).lastPathComponent
        let isInterp = interpreters.contains(exeName)
        if isInterp && args.contains("-c") { flags.append(.inlineScript) }
        let appleDirs = ["/System/", "/usr/", "/bin/", "/sbin/", "/Library/Apple/", "/Applications/Safari.app", "/Applications/Xcode.app"]
        if e.label.hasPrefix("com.apple."), !prog.isEmpty, !appleDirs.contains(where: { prog.hasPrefix($0) }) { flags.append(.fakeApple) }
        let comps = prog.split(separator: "/").map(String.init)
        if comps.dropLast().contains(where: { $0.hasPrefix(".") }) { flags.append(.hiddenDir) }
        for tmp in ["/tmp/", "/private/tmp/", "/var/folders/", "/private/var/folders/", "/Users/Shared/", "/private/var/tmp/"] where prog.hasPrefix(tmp) { flags.append(.tempDir); break }
        let last = e.label.split(separator: ".").last.map(String.init) ?? e.label
        let lettersDigits = last.filter { $0.isLetter || $0.isNumber }
        if lettersDigits.count >= 14, last.contains(where: { $0.isNumber }), !last.contains("-"), last.lowercased() == last, Set(last).count > 8 {
            flags.append(.randomName)
        }
        // Signature
        var sign: SignState = .unknown
        let scriptExts: Set<String> = ["sh", "py", "rb", "pl", "scpt", "applescript", "js", "command"]
        let target = isInterp ? (args.dropFirst().first { !$0.hasPrefix("-") } ?? prog) : signTarget(prog)
        if prog.isEmpty && args.isEmpty {
            sign = .empty
        } else if isInterp || scriptExts.contains((target as NSString).pathExtension.lowercased()) {
            sign = .script
        } else if !prog.isEmpty, FileManager.default.fileExists(atPath: target) {
            let (code, out) = run("/usr/bin/codesign", ["-dv", "--verbose=2", target])
            if code != 0 && out.contains("not signed") { sign = .unsigned }
            else if code != 0 { sign = .invalid }
            else if out.contains("Signature=adhoc") { sign = .adhoc }
            else if out.contains("Authority=Software Signing") && out.contains("Authority=Apple Root CA") && !out.contains("Developer ID") { sign = .apple }
            else if let line = out.split(separator: "\n").first(where: { $0.hasPrefix("Authority=Developer ID Application:") || $0.hasPrefix("Authority=Apple Development:") || $0.hasPrefix("Authority=Apple Distribution:") }) {
                var n = String(line.split(separator: ":", maxSplits: 1).last ?? "").trimmingCharacters(in: .whitespaces)
                if let p = n.range(of: " (") { n = String(n[..<p.lowerBound]) }
                sign = .developer(n)
            } else if out.contains("Authority=Apple Mac OS Application Signing") || out.contains("Authority=Apple Worldwide Developer Relations") { sign = .developer(t("App Store app", "App từ App Store")) }
            else { sign = .developer(t("Signed", "Có ký")) }
            // A signed program that verifies but Gatekeeper rejects usually means a revoked certificate.
            if case .developer = sign {
                let (vc, _) = run("/usr/bin/codesign", ["-v", target])
                if vc != 0 { sign = .invalid }
                else {
                    let (_, so) = run("/usr/sbin/spctl", ["-a", "-t", "exec", "-vv", target])
                    if so.contains("rejected") && (so.contains("revoked") || so.contains("CSSMERR_TP_CERT_REVOKED")) { sign = .invalid }
                }
            }
        }
        return (sign, flags)
    }
}

// MARK: - Startup page

struct StartupView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("Startup Items", "Khởi động cùng máy")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text)
                Text(t("Background helpers that start with your Mac, each with who signed it. This is not antivirus: Tidymint states facts, you decide. For a second opinion use KnockKnock (free, open source) or Malwarebytes.",
                       "Các tiến trình chạy ngầm khi bật máy, kèm ai đã ký chúng. Đây không phải diệt virus: Tidymint chỉ nêu sự thật, bạn tự quyết. Muốn kiểm thêm, dùng KnockKnock (miễn phí, mã mở) hoặc Malwarebytes."))
                    .foregroundColor(Theme.sub).font(.system(size: fs(12)))
                HStack(spacing: 8) {
                    if vm.launchBusy { ProgressView().controlSize(.small).tint(Theme.text); Text(t("Checking signatures...", "Đang kiểm chữ ký...")).foregroundColor(Theme.sub).font(.system(size: fs(12))) }
                    else if vm.launchAttention > 0 {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.warn)
                        Text(t("\(vm.launchAttention) items worth a look. Hover a badge to see why.", "\(vm.launchAttention) mục đáng để ý. Rê chuột lên nhãn để xem lý do.")).foregroundColor(Theme.text).font(.system(size: fs(12)))
                    } else if !vm.launch.isEmpty {
                        Image(systemName: "checkmark.shield").foregroundColor(Theme.green)
                        Text(t("Nothing unusual in \(vm.launch.count) items.", "Không có gì bất thường trong \(vm.launch.count) mục.")).foregroundColor(Theme.text).font(.system(size: fs(12)))
                    }
                }.padding(.top, 4)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 12)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach([0, 1, 2], id: \.self) { sc in
                        let rows = vm.launch.indices.filter { vm.launch[$0].scope == sc }
                        if !rows.isEmpty {
                            // Section title 13 semibold + a short note in the secondary colour (style guide 1f).
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(sc == 0 ? t("Your account", "Tài khoản của bạn") : sc == 1 ? t("All users · agents", "Cả máy · agent") : t("All users · system services", "Cả máy · dịch vụ hệ thống"))
                                    .font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                                Text(sc == 0 ? t("can remove here", "gỡ được ở đây") : sc == 1 ? t("needs admin, remove via the app or Settings", "cần quyền admin, gỡ bằng app gốc hoặc Cài đặt") : t("needs admin", "cần quyền admin"))
                                    .font(.system(size: fs(11))).foregroundColor(Theme.sub)
                            }.padding(.top, 12).padding(.bottom, 2).padding(.leading, 4)
                            ForEach(rows, id: \.self) { i in LaunchRow(e: $vm.launch[i], vm: vm) }
                        }
                    }
                }.padding(.horizontal, 24).padding(.bottom, 12)
            }
            HStack(spacing: 12) {
                Text(vm.launchMsg.isEmpty ? t("\(vm.launch.count) items", "\(vm.launch.count) mục") : vm.launchMsg)
                    .foregroundColor(Theme.text).font(.system(size: fs(13))).lineLimit(2)
                Spacer()
                GhostButton(title: t("Login Items…", "Mục đăng nhập…")) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
                }
                .tip(t("Shows LaunchAgents and LaunchDaemons. Login Items that apps register themselves are managed in System Settings.",
                       "Trang này hiện LaunchAgents và LaunchDaemons. Mục đăng nhập do app tự đăng ký được quản lý trong Cài đặt hệ thống."))
                PrimaryButton(title: t("Remove selected", "Gỡ mục đã chọn"), action: { vm.removeLaunch() },
                              disabled: !vm.launch.contains { $0.selected && $0.scope == 0 })
            }.padding(.horizontal, 24).padding(.vertical, 12).background(Theme.shade.opacity(0.25))
        }
        .onAppear { vm.scanLaunch() }
    }
}

struct LaunchRow: View {
    @Binding var e: LaunchEntry
    let vm: VM
    var body: some View {
        HStack(spacing: 12) {
            if e.scope == 0 {
                Button { e.selected.toggle() } label: { CheckBox(state: e.selected ? 2 : 0) }.buttonStyle(.plain)
            } else {
                Image(systemName: "lock.fill").font(.system(size: fs(12))).foregroundColor(Theme.sub).frame(width: 17)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(e.owner).foregroundColor(Theme.text).font(.system(size: fs(13))).lineLimit(1)
                Text(e.label).foregroundColor(Theme.sub).font(.system(size: fs(11))).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 12)
            HStack(spacing: 6) {
                if e.orphan {
                    if e.program.hasPrefix("/Volumes/") { StatusTag(t("Drive not connected", "Ổ ngoài chưa cắm"), Theme.warn) }
                    else { StatusTag(t("App removed", "App đã gỡ"), Theme.danger) }
                }
                if e.running == true { StatusTag(t("Running", "Đang chạy"), Theme.green) }
                if case .apple = e.sign {} else if !e.sign.label.isEmpty { StatusTag(e.sign.label, e.sign.color).tip(e.sign.help) }
                ForEach(e.flags, id: \.self) { f in StatusTag(f.label, Theme.warn).tip(f.help) }
            }
            TextLink(t("Reveal", "Xem file")) { vm.reveal(e.url) }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
        .hoverBG(10, Theme.ink.opacity(0.06))
        .tip(e.program)
    }
    func badge(_ s: String, _ c: Color) -> some View {
        Text(s).font(.system(size: fs(10), weight: .semibold)).foregroundColor(c)
            .padding(.horizontal, 6).padding(.vertical, 1).background(Capsule().fill(c.opacity(0.15)))
    }
}
