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

// MARK: - Check-in ("Is Tidymint helping you?")

/// A one-line card at the top of Clean Now, asked once: 14 days after the first launch and 2 uses of a main feature
/// (or 60 days and 1 use). X on the question = later (14 more days, once), then never again.
/// The answer goes to the same form endpoint as Contact: no email, no machine id. The Dev build never asks.
@MainActor final class CheckIn: ObservableObject {
    static let shared = CheckIn()
    enum Step { case hidden, ask, why, thanks, sent }
    @Published var step: Step = .hidden
    @Published var reasons = Set<String>()
    @Published var note = ""
    var answer = ""
    let d = UserDefaults.standard

    /// First launch, saved once. Updating the app keeps UserDefaults (same bundle id), so a release never restarts the clock.
    /// Someone upgrading from 0.3.7 has no key yet: the oldest trace of earlier use is taken (activity log, data folder).
    var firstOpen: Date {
        if let v = d.object(forKey: "firstOpenDate") as? Date { return v }
        var cands = [Date()]
        if let e = Stats.load().first?.date { cands.append(e) }
        if let c = (try? FileManager.default.attributesOfItem(atPath: Stats.dir))?[.creationDate] as? Date { cands.append(c) }
        let v = cands.min()!
        d.set(v, forKey: "firstOpenDate")
        return v
    }
    /// Uses of a main feature (scan, clean by app, uninstaller, space lens, large files, duplicates).
    /// Started from the activity log for people upgrading, so their earlier cleanups count.
    var uses: Int {
        if d.object(forKey: "featureUses") == nil { d.set(Stats.load().count, forKey: "featureUses") }
        return d.integer(forKey: "featureUses")
    }
    func used() { d.set(uses + 1, forKey: "featureUses") }

    var isDev: Bool { Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true }
    func shouldAsk(now: Date = Date()) -> Bool {
        guard !isDev, !Demo.active else { return false }
        let state = d.string(forKey: "checkinState") ?? ""
        if state == "done" { return false }
        if let next = d.object(forKey: "checkinNext") as? Date, now < next { return false }
        let days = now.timeIntervalSince(firstOpen) / 86400, n = uses
        return (days >= 14 && n >= 2) || (days >= 60 && n >= 1)
    }
    /// Called when the Clean Now page shows.
    func refresh() { if step == .hidden && shouldAsk() { step = .ask }; flushPending() }

    func later() {
        if (d.string(forKey: "checkinState") ?? "") == "" {
            d.set("later", forKey: "checkinState"); d.set(Date().addingTimeInterval(14 * 86400), forKey: "checkinNext")
        } else { d.set("done", forKey: "checkinState") }
        step = .hidden
    }
    func choose(_ a: String) {
        answer = a
        d.set("done", forKey: "checkinState")
        send(["answer": a])
        step = a == "helpful" ? .thanks : .why
    }
    func sendWhy() {
        send(["answer": answer, "reasons": reasons.sorted().joined(separator: ", "), "message": note.trimmingCharacters(in: .whitespacesAndNewlines)])
        step = .sent
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { if self.step == .sent { self.step = .hidden } }
    }
    func close() { d.set("done", forKey: "checkinState"); step = .hidden }

    private func send(_ extra: [String: String]) {
        var f = ["source": "checkin", "type": "checkin", "email": "", "newsletter": "no", "message": "",
                 "app": Backend.systemInfo["app"] ?? "?", "lang": appLang]
        f.merge(extra) { _, b in b }
        Backend.send(f) { ok in if !ok { self.queue(f) } }
    }
    /// No network: kept and sent at the next launch.
    private func queue(_ f: [String: String]) {
        var f = f
        let n = (Int(f["tries"] ?? "0") ?? 0) + 1
        guard n <= 5 else { return }   // given up after 5 tries: no endless requests on every page visit
        f["tries"] = String(n)
        var q = d.array(forKey: "checkinPending") as? [[String: String]] ?? []
        q.append(f); d.set(Array(q.suffix(5)), forKey: "checkinPending")
    }
    private func flushPending() {
        guard let q = d.array(forKey: "checkinPending") as? [[String: String]], !q.isEmpty else { return }
        d.removeObject(forKey: "checkinPending")
        for f in q { Backend.send(f) { ok in if !ok { self.queue(f) } } }
    }
    static func freeHelpURL() -> URL {
        URL(string: t("https://tidymint.app/sponsor/", "https://tidymint.app/vi/ung-ho/") + "?utm_source=tidymint&utm_medium=app&utm_campaign=checkin#free")!
    }
}

struct CheckInCard: View {
    @ObservedObject var c = CheckIn.shared
    static let reasons: [(String, String, String)] = [
        ("little", "Frees too little", "Dọn được ít"), ("hard", "Hard to follow", "Khó hiểu"),
        ("apps", "Missing my apps", "Thiếu app hay dùng"), ("rare", "Rarely need it", "Ít khi cần dọn"), ("other", "Something else", "Lý do khác")]
    func pill(_ title: String, _ icon: String, _ a: String) -> some View {
        Button { c.choose(a) } label: {
            Label(title, systemImage: icon).font(.system(size: fs(12), weight: .medium)).foregroundColor(Theme.text)
                .padding(.horizontal, 10).padding(.vertical, 5).background(Capsule().stroke(Theme.ink.opacity(0.3), lineWidth: 1))
        }.buttonStyle(.plain).hoverLift()
    }
    func xButton(_ act: @escaping () -> Void, tip: String) -> some View {
        Button(action: act) { Image(systemName: "xmark").font(.system(size: fs(11), weight: .semibold)).foregroundColor(Theme.sub) }
            .buttonStyle(.plain).tip(tip)
    }
    var body: some View {
        Group {
            switch c.step {
            case .hidden: EmptyView()
            case .ask:
                HStack(spacing: 8) {
                    Text(t("Is Tidymint helping you?", "Tidymint có giúp ích cho bạn không?")).font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                    Spacer(minLength: 6)
                    pill(t("Helpful", "Hữu ích"), "hand.thumbsup", "helpful")
                    pill(t("It's okay", "Bình thường"), "face.smiling", "okay")
                    pill(t("Not yet", "Chưa hữu ích"), "hand.thumbsdown", "not")
                    xButton({ c.later() }, tip: t("Later", "Để sau"))
                }.onExitCommand { c.later() }
            case .why:
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(t("What is Tidymint missing?", "Tidymint còn thiếu gì?")).font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                        Spacer()
                        xButton({ c.close() }, tip: t("Skip", "Bỏ qua"))
                    }
                    HStack(spacing: 6) {
                        ForEach(Self.reasons, id: \.0) { r in
                            let on = c.reasons.contains(r.0)
                            Button { if on { c.reasons.remove(r.0) } else { c.reasons.insert(r.0) } } label: {
                                HStack(spacing: 4) {
                                    if on { Image(systemName: "checkmark").font(.system(size: fs(10), weight: .bold)) }
                                    Text(t(r.1, r.2))
                                }.font(.system(size: fs(12), weight: .medium)).foregroundColor(on ? Theme.text : Theme.sub)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Capsule().fill(on ? Theme.accentSolid.opacity(0.25) : Color.clear))
                                    .overlay(Capsule().stroke(on ? Theme.accentSolid : Theme.ink.opacity(0.3), lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                    HStack(spacing: 8) {
                        TextField(t("Add a line (optional)", "Thêm một dòng (không bắt buộc)"), text: $c.note)
                            .textFieldStyle(.roundedBorder).font(.system(size: fs(12)))
                        PrimaryButton(title: t("Send", "Gửi"), action: { c.sendWhy() },
                                      disabled: c.reasons.isEmpty && c.note.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }.onExitCommand { c.close() }
            case .thanks:
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "leaf").foregroundColor(Theme.accentSolid)
                        Text(t("Thank you. Tidymint stays free thanks to Mint keepers like you.", "Cảm ơn bạn. Tidymint miễn phí nhờ những Mint keepers như bạn."))
                            .font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                        Spacer()
                        xButton({ c.close() }, tip: t("Close", "Đóng"))
                    }
                    HStack(spacing: 12) {
                        PrimaryButton(title: t("3 free ways to help", "3 cách giúp miễn phí"), action: { NSWorkspace.shared.open(CheckIn.freeHelpURL()); c.close() })
                        TextLink(t("Support the project", "Ủng hộ dự án"), url: sponsorURL("checkin"))
                    }
                }.onExitCommand { c.close() }
            case .sent:
                HStack(spacing: 8) {
                    Image(systemName: "checkmark").foregroundColor(Theme.green)
                    Text(t("Sent. Thank you, we read every reply.", "Đã gửi. Cảm ơn bạn, chúng tôi sẽ đọc từng góp ý.")).font(.system(size: fs(13))).foregroundColor(Theme.text)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, c.step == .hidden ? 0 : 14).padding(.vertical, c.step == .hidden ? 0 : 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(c.step == .hidden ? Color.clear : Theme.card))
        .frame(maxWidth: 680)
        .animation(.easeOut(duration: 0.2), value: c.step)
    }
}

/// When to show the newsletter invitation after a cleanup: never again after signing up or "Don't ask again",
/// otherwise at most once every 14 days.
enum Invite {
    static func shouldShow() -> Bool {
        let d = UserDefaults.standard
        if ["subscribed", "never"].contains(d.string(forKey: "inviteState") ?? "") { return false }
        if let last = d.object(forKey: "inviteLast") as? Date, Date().timeIntervalSince(last) < 14 * 86400 { return false }
        return true
    }
    static func later() { UserDefaults.standard.set(Date(), forKey: "inviteLast") }
    static func never() { UserDefaults.standard.set("never", forKey: "inviteState") }
    static func subscribed() { UserDefaults.standard.set("subscribed", forKey: "inviteState") }
}

final class FormState: ObservableObject {
    @Published var email = UserDefaults.standard.string(forKey: "contactEmail") ?? ""
    @Published var kind = "feedback"
    @Published var message = ""
    @Published var includeInfo = true
    @Published var sending = false
    @Published var result = ""
    @Published var ok = false
    @Published var hidden = false
}

/// A gentle pointer to the author's Vietnamese drinks site, shown only in Vietnamese,
/// at most once a day on the "done" screen, and never again after "Don't show again".
/// Nothing is sent anywhere: the link only opens when the user clicks it.
enum ConCao {
    static let lastKey = "concaoHintLast", offKey = "concaoHintOff"
    static func url(_ place: String) -> URL {
        URL(string: "https://concao.org/?utm_source=tidymint&utm_medium=app&utm_campaign=\(place)")!
    }
    static func shouldShow() -> Bool {
        guard appLang == "vi", !UserDefaults.standard.bool(forKey: offKey) else { return false }
        if let d = UserDefaults.standard.object(forKey: lastKey) as? Date, Calendar.current.isDateInToday(d) {
            return shownThisSession
        }
        return true
    }
    static var shownThisSession = false
    static func markShown() {
        if !shownThisSession { shownThisSession = true; UserDefaults.standard.set(Date(), forKey: lastKey) }
    }
}

final class HintState: ObservableObject { @Published var hidden = false }

struct ConCaoHint: View {
    @StateObject private var h = HintState()
    var body: some View {
        if !h.hidden {
            HStack(spacing: 10) {
                Image(systemName: "wineglass").foregroundColor(Theme.link)
                Text("Dọn xong rồi, thưởng mình một ly?").foregroundColor(Theme.sub)
                TextLink("Gợi ý ở Cồn Cào →", url: ConCao.url("done"), size: 13)
                Spacer()
                Button { UserDefaults.standard.set(true, forKey: ConCao.offKey); h.hidden = true } label: {
                    Text("Đừng hiện nữa").padding(.horizontal, 6).padding(.vertical, 3).hoverTile()
                }.buttonStyle(.plain).foregroundColor(Theme.sub)
            }
            .font(.system(size: fs(12)))
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
            .onAppear { ConCao.markShown() }
        }
    }
}

struct FieldBox<C: View>: View {
    let title: String
    @ViewBuilder let content: () -> C
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: fs(12), weight: .semibold)).foregroundColor(Theme.sub)
            content()
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.shade.opacity(0.25)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.ink.opacity(0.15), lineWidth: 1))
        }
    }
}

/// Brand logos for the Contact footer: Simple Icons (CC0) / Lucide (LinkedIn), the same shapes as the website footer,
/// as 64 px template PNGs so they take the theme colour. Brand logos are the one exception to SF Symbols (style guide 1e).
enum BrandIcon {
    static let png: [String: String] = [
        "facebook": "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAEqklEQVR4nOSbaahNXRjH/7je9/XKEG4hwzVe81AocxK+yRSSKRER8oFuQr4gpYxdUcoUGTOVWRkzRzJPtwjJkMwyPf+7zqnd7pxz99p7re2s61f/2z17r3vuXs9ew7Oe9awcxEN3UQtRc1FTUW1RdVGNxP1XoteiZ6K7otuim6KzsEwZ2KGNaKCoN1Tlw/JFdF50XLRV9BCGMWmAXNFE0RhRY9jhhmiTaK3oHQxgwgBNRAWicYiPz6L1ooWip4hAOYSnrGiWaJuoI+KlfOJ/ThC9EV1BSMK2AL71zaJOyA44RowSPYcmZaHPJNE1ZE/lCQdbzhoDoIluC9ghGoLsplA0JWjhoAaoJjog6gw3OCgaBDWNZiSIASpDzcXN4RanRD1LKlQuwP1Dog5wj/qiBqI9mQqVZIBlomFwl3ZQ0+TFdAUydQE6NusQD/ehuhnFGeZtQi88ZWpCvdV8UTOoWah3sK8vLnci1Y10BqCTwYVIedjjh2inaAGUi6sLDXEnYFm2AraGJ/4b6fyAXbBb+ctQq8LhCFd58lOjLGexLalupDLAfFFd2IOLma6iR4iGrhPXTTTUf9HfBepA9cf/YAeOKeNhBrrj96AHu0A97wW/FefBXuVPQi2XTRHGjWfLnuq94G0BtAwDDjkwz6/E90dauvrQGQS9cMGUJ/rGD14rzoSdypP9MFt58gvhqAW1cizGa4CRsMdKmCesAciY5C/JN95fVBX2OIbw0OGhS8s3533G6ggP45Qc8J8mDTAC9rgEff6HcsP5XBVhB/ogS9gFOBD2gz10w1V8Ji5nGe6yVXnSlz/YAtrDbvO/BT34ZnrAPnSMig3QC3b5AD3iii5XEHWlAVrBLroG6Ib4aEkDNIVd3muU5ebKv4iPxjRAPuzyXaNsBcRLPg1QCdlDGP8+CrVpgCi7Q66TSwPEbfVsIpeV1+mj6WAEqUwa6bjBRRm+x68ziE4ODfAJbtIe0XlPA3yEezC2YMJNfkcDaO+oZgFtYYYXNEAR3KMNzPCAs4DxvJsYaA0zFBvgKtzDVAu4SgNchlv8AzPuOzdWTnIMYBdwaSDk6tWE88YX/yH5RfvgDqaa/17+SO4LMDx0GHbog+DeYJ7oMeKhIf9XsgUcgZv+QFguIGFob1+KKxcgGyhM/uI1wGr8HTAxe2Pyg9cAzNRejtLPUu8H/3TC3FvdIKZL8CUv9F7wG+ClaA5KLwX+C6kcCnaD6yh9MNFzk/9iOo+K6bCuBkpSwWyz0alupDPAA8Sb/28b5ga9TXUjk0/NcwCL4D5MnD6d7mZJi4rZUAFPV+EWe2GmAkFWVdyjPwf3YOVnlFQoiAGYTMT8AZcCJ4sRoPIk6LqazlEX0RpkP0yDKwhaWCew8BXquAyzx3V2fOOCBy8Hi1bp/FGYyMp2UUtkGFn/AFzccJt/NzQJG1piyilPY0zDn91Y4TFb5h0z7e0NQhAltsY8Peb/MUa3AvEuovgCJkOdG4g0Q5kILhaJpkMdaOBD3YY9WNmxUFtjRuIXJrfG2RX4UDwlzjwfnu810Sq4CzxX1AiquW+AQWydHvdSBcEPOudBRagZRD0KdfLL6hjzGwAA///8mGIKAAAABklEQVQDABV6wtD33EZdAAAAAElFTkSuQmCC",
        "instagram": "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",
        "x": "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",
        "linkedin": "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAACdUlEQVR4nOyaS0gWURiGX82CDLoH3SkoCqJoUxEVtO2yKIhqE0S1rhZdFkGbaNMmWqQbcSGCC0HFlbhVBG/gwoUiiO68gW5UULy8H+NCZM7MOf6/Z/7xOw88CHO+Ec7LzJzbXwHlVEA5IQAoR30AeyxqrtD39Au9Q1fpKHYJZSlt0unfdO+Wthb6js4i5yQF8Jn+TWjvpA/pCnKM6RU4R5voPvOtOE+naC9yTLnh+hN6AOm8Qc4xjQI3YcdV5BxTAHOwYwI5xxTAAOywrStZTKNAJe2h18y3Ypnepf3IMaaP4AJ9tfHXxDfkvPNC0kxwmlbTE/QgoqdiEtGw95I2YxdQBuWE1SCUEwKAcko5gOv0KT1Lj9OjdJ7OIBqNOmgbCqTUAthPP9IP9JJFvUzZG+gfOoZtUCrDoEzI3tJf9DTcWaL/N+532qQxBdBIX6Cw/2HLYdpKH6BwZPL2CA4z1HJki6w1ZEFVjM4LMmvtgsM+RZbfgAuIPmRHUFxkF6uOrtH6tOKsngBZW7Sj+J3fTC29l1aUVQD/6GXsLLKTLd+yyqSiLAK4geiL74NT9EdSQRYB1MAvXxHtYMfiO4D79Bb8Iq/CJ1Oj7wCewZ0q+pgeorfpd0TjvQvPTQ2+J0JypnjRoVbOJ4Zi2uTMQl6l17BH1haDWy/6fAJkyLPtvIzh0rkhQ7ssiuRschz2xL56PgM46VArh69pR26L9CfsiV1j+JwJnnGo7bOs64Y9mQfgMusbsawbhj3H4i76DCDrpXfs6x62xKCcEACUEwKAckIAUE4IAMoJAUA5IQAoJwQA5agPIPxOEMoJAUA5IQAoJwQA5awDAAD//48o/vsAAAAGSURBVAMAe85Nuv8OnGMAAAAASUVORK5CYII=",
        "github": "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAGOElEQVR4nNSbaYwURRTH/yoqRrmCgC5RRHFdPOItRIhuPONNBIlG8YxAxOOLGI2JWaPRaPygon4wMcZzjfE+UIgYFTxwN0iCwiJ4gBKCqCiurgoB3n+qC3qb7ul61d0zPb/kv9nuqZqZelNd/eq9131QHwaKBov2DY5/Ff0m+gM1pg+Kp1U0XnSEaLSoWbRXQtse0XLRMtHXogWiT1AguyB/hoouF10kOhX5ME/0uqhd9DtyJE8DcMA3iU5Hsbwjekw0BzmQhwGuFN0lOgS1hZfJHaI3kYEsBmgSPSM6A/XlJdEMeF4au8KPKaKlqP/gyaUws+FceKA1QH/Rq6JnRQNQHrjwviuaJdpT01FzCfAan4PaX+taOmFmw3qXxq4GOEE0WzQEjcEqmLvRd2kNXQxA56VDtDcai7Wio5EyE9LWgEGiuWi8wZP9YXyGqmvCbqgOB38UGpfhooNFryU1qGaA50QXoPHhD9gt+jzuxaRLYLroClRnI8ymhutIi+g20fconq9gHJ8RwWcf6NDnISS46HGLID28lUjesVleQLyRJsC4qCchX14RPSz6NOa1hQ6fxzvDQdGTcdvhB5E+eLIg4fwbgSaLHhUNE/0tWixaJFoDs++nGAfYAyY+YHWA6DiYFbyvaIXoGsQP3PIF0g3AGcMf5v7wyegMGBO8mQt0g+eltOGA6KV9Cz8YQ+C9/N+UdjeLHkE6jDeMFK2zJ6JrwD1wZ4NDG/7KvoMn3yB98ORPuMGZPTN8ImyAsaIz4U4tokmu9FW05QJqQ3G9DDATOoajPIxQtKWxptsDawB6fBdDxzEoD8dCx9X2H2uAydAzBuVhpLI9d7TH8x9rgEugg07QDJSHKdAziX9oAK6M2kDmDXDYatYQ7lbvhI7T+Id+AFf+uYqOjNu3oHxwx0pvb7Bj+y2iAZwBJ0PHfSgn9DYfV7Tn2Mfxz+GKTluRMQxdMLOV7VtogMMUHejPu3pd9YCbom5F+2YaQBPkXIPys0rRdhQNoAkjO0Va68xaRdth9Oc1uYFNKD//KdoOoQHS4oJhNJuOeuESy7A0aXd0/VF+Bina9nD6a6oyNLuueqHZF/yjNcChKDfMXA1UtN9AA/ys6LCP6EiUl/HK9qtpgJ+gwysNXSPOh46KAZbp+uwIJpQMrv6TdF2wlAZYpOtTSZa2onxMg/4u1cHtMBeOX6DjS5QrIsRiDUafh+q6oR9nAN3bhbp+lSSENgBRJMxjagf/gajbusFvQc+9outQf56CXxKX2avtmSGmkH1DXG2iu1F7eL/n4LXRbAtnzHo7A5jV7YAfbUHfWobJGcTtgv/g30ewsw1vhGiMuPsoq6+4ws6HSWYyHrh7pA0zykw2nCXaDFOztxH5wjz/VJgKtethnDJfbkdw+48mR3k3iBZCLRGdgh0uM1d/Vlw0oTpclZlC7wzeQ+twTYQZNL/PZdBtcqrBbHOzPYgagEUOD8R04vpAJ2NxcMz6G6arXTcenEUaL40RXl5Wo5E/V8HMogpxBRK00KiY85zSnOL2lslZ8THSYbSWYbd10HEijL+RJ/zReu0X4qJBUxM608tqDx2zjv9WpPME9IMnnAG5VISHmBY9ERcN+hEmUhxXHcbrkIvc/OCYhUecruOQTBv8a4f6ic5DPvDSbo+eTCqU3A8mAxTnW3MxZGHSX6FznK50iviAhM0acYa8B1O50QM/+H4fITs/wFSb7PQ9qlWKMneWVAJzC0z9T9FwJnYhG8xjjE16n2oR4Q9hVsw4+IBE2m0wDzQR3iR490k0YlpInLeLG2POMwHJ2VF08XTWJ1rORnI1WwWXnAATjnHlM7zWP0OxD01kMQB/+dSst+YDOBNmJbzGKcYFL+z+sv6P1/BE+EN/ZIWuS6WqjINPK+GroLXwhaIXoaseZ+rtf/hBl3W5ov1qmMEvce2gfWSGcQM+PKGp/fMdPNH8QCyNZ3Wp8+CJz0NTXcEHPYnicf1+vC0zKKJ+9Nb3qTFeZ3QrWV6zEsWR9v3ehrlMvH0SXwNYGFdjtoj7hywlsUkkZaO5u2yFWZO0i2Qv8n52+BwYY0wIjp8WXYtscMfJnScXw5dFzyNHYxfx8DRhGS1jBp3IByZlNZUfzmwDAAD//5M94tAAAAAGSURBVAMA4fEEQpAZsWwAAAAASUVORK5CYII=",
    ]
    static func image(_ k: String) -> NSImage? {
        guard let s = png[k], let d = Data(base64Encoded: s), let i = NSImage(data: d) else { return nil }
        i.isTemplate = true; i.size = NSSize(width: 16, height: 16); return i
    }
}

/// Round icon link in a footer (email, social): icon only, name as tooltip.
struct FooterIcon: View {
    let tip: String; let url: URL; var brand: String? = nil; var symbol: String? = nil
    @StateObject private var h = Flag()
    var body: some View {
        Button { NSWorkspace.shared.open(url) } label: {
            Group {
                if let b = brand, let img = BrandIcon.image(b) { Image(nsImage: img).renderingMode(.template).resizable().frame(width: 15, height: 15) }
                else { Image(systemName: symbol ?? "link").font(.system(size: fs(13))) }
            }
            .foregroundColor(h.v ? Theme.brandMint : Theme.sub)
            .frame(width: 30, height: 30).background(Circle().fill(Theme.ink.opacity(h.v ? 0.12 : 0.07)))
        }.buttonStyle(.plain).onHover { h.v = $0 }.tip(tip)
    }
}

struct ContactView: View {
    static let social: [(String, String, String)] = [("Facebook", "facebook", "https://www.facebook.com/tidymintapp"), ("Instagram", "instagram", "https://www.instagram.com/tidymint.app/"),
                                             ("X", "x", "https://x.com/tidymintapp"), ("LinkedIn", "linkedin", "https://www.linkedin.com/company/tidymint/"),
                                             ("GitHub", "github", "https://github.com/HaiTrung-Workspace/tidymint")]
    @ObservedObject var vm: VM
    @StateObject private var f = FormState()
    var body: some View {
      VStack(spacing: 0) {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Contact the developer", "Liên hệ nhà phát triển")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text)
                    Text(t("Feedback, bug reports and questions go straight to the developer. An email address is needed so you can get a reply.",
                           "Góp ý, báo lỗi, câu hỏi đều tới thẳng nhà phát triển. Cần email để có thể trả lời bạn."))
                        .foregroundColor(Theme.sub).font(.system(size: fs(12)))
                }.padding(.top, 34)
                Picker("", selection: $f.kind) {
                    Text(t("Feedback", "Góp ý")).tag("feedback")
                    Text(t("Bug report", "Báo lỗi")).tag("bug")
                    Text(t("Question", "Câu hỏi")).tag("question")
                }.pickerStyle(.segmented).labelsHidden().controlSize(.small).fixedSize()
                FieldBox(title: t("Your email (required)", "Email của bạn (bắt buộc)")) {
                    TextField("name@example.com", text: $f.email).textFieldStyle(.plain).foregroundColor(Theme.text)
                        .onSubmit { submit(newsletter: true) }
                }
                FieldBox(title: t("Message", "Nội dung")) {
                    TextEditor(text: $f.message).font(.system(size: fs(13))).foregroundColor(Theme.text)
                        .scrollContentBackground(.hidden).frame(minHeight: 140)
                }
                Toggle(isOn: $f.includeInfo) {
                    Text(t("Attach app version, macOS version and Mac model", "Kèm phiên bản app, phiên bản macOS và đời máy"))
                        .font(.system(size: fs(12))).foregroundColor(Theme.sub)
                }.toggleStyle(.checkbox)
                if !f.result.isEmpty {
                    Text(f.result).font(.system(size: fs(13), weight: .medium)).foregroundColor(f.ok ? Theme.green : Theme.warn)
                }
                HStack(spacing: 10) {
                    TextLink(t("Report a bug on GitHub", "Báo lỗi trên GitHub"), url: URL(string: "https://github.com/HaiTrung-Workspace/tidymint/issues")!)
                    if f.sending { ProgressView().controlSize(.small).tint(Theme.text) }
                    Spacer()
                    // Return (outside the message box) = the main button.
                    GhostButton(title: t("Send Only", "Chỉ gửi"), action: { submit(newsletter: false) }).disabled(f.sending)
                    PrimaryButton(title: t("Send & Subscribe", "Gửi và nhận bản tin"), action: { submit(newsletter: true) }, disabled: f.sending)
                        .keyboardShortcut(.defaultAction)
                }
                // The newsletter consent stays right under the button it belongs to.
                HStack(spacing: 6) {
                    Spacer()
                    Text(Backend.newsletterText).font(.system(size: fs(11))).foregroundColor(Theme.sub)
                    if let u = URL(string: Backend.privacyURL), !Backend.privacyURL.isEmpty {
                        TextLink(t("Privacy", "Quyền riêng tư"), url: u, size: 11)
                    }
                }
            }.padding(.horizontal, 24).padding(.bottom, 24)
        }
        // Footer: email and brand accounts as icons (plain links: nothing loads until clicked).
        RowLine()
        HStack(spacing: 8) {
            Spacer()
            FooterIcon(tip: "hello@tidymint.app", url: URL(string: "mailto:hello@tidymint.app")!, symbol: "envelope")
            ForEach(ContactView.social, id: \.1) { s in FooterIcon(tip: s.0, url: URL(string: s.2)!, brand: s.1) }
        }.padding(.horizontal, 24).padding(.vertical, 12)
      }
    }
    func submit(newsletter: Bool) {
        let email = f.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let msg = f.message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Backend.validEmail(email) else { f.ok = false; f.result = t("Please enter a valid email.", "Bạn nhập email hợp lệ giúp nhé."); return }
        guard !msg.isEmpty else { f.ok = false; f.result = t("Please write a message.", "Bạn viết nội dung giúp nhé."); return }
        UserDefaults.standard.set(email, forKey: "contactEmail")
        var fields = ["source": "contact", "type": f.kind, "email": email, "message": msg,
                      "newsletter": newsletter ? "yes" : "no", "consent": newsletter ? Backend.newsletterText : "",
                      "consentVersion": Backend.consentVersion]
        if f.includeInfo { fields.merge(Backend.systemInfo) { a, _ in a } }
        f.sending = true; f.result = ""
        Backend.send(fields) { ok in
            f.sending = false
            if ok {
                f.ok = true; f.message = ""
                f.result = t("Sent. Thank you!", "Đã gửi. Cảm ơn bạn!") + (newsletter ? t(" You're on the newsletter list.", " Bạn đã có tên trong danh sách nhận bản tin.") : "")
                if newsletter { Invite.subscribed() }
            } else {
                f.ok = false
                // Keep the text so nothing is lost; the user can simply press Send again.
                f.result = t("Could not send right now. Check your connection and try again; your message is kept.",
                             "Chưa gửi được lúc này. Bạn kiểm tra mạng rồi bấm gửi lại nhé, nội dung vẫn được giữ nguyên.")
            }
        }
    }
}

/// Newsletter invitation shown after a successful cleanup.
struct InviteCard: View {
    let source: String
    @StateObject private var f = FormState()
    var body: some View {
        if !f.hidden {
            VStack(alignment: .leading, spacing: 10) {
                Text(t("Want monthly tips to keep your Mac lean?", "Nhận mẹo giữ máy gọn mỗi tháng?")).font(.system(size: fs(15), weight: .semibold)).foregroundColor(Theme.text)
                Text(Backend.newsletterText).font(.system(size: fs(11))).foregroundColor(Theme.sub).fixedSize(horizontal: false, vertical: true)
                if f.ok {
                    Text(t("Thanks! You're on the list.", "Cảm ơn bạn! Đã đăng ký.")).foregroundColor(Theme.green).font(.system(size: fs(13), weight: .medium))
                } else {
                    HStack(spacing: 8) {
                        TextField("name@example.com", text: $f.email).textFieldStyle(.plain).foregroundColor(Theme.text)
                            .onSubmit { join() }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.shade.opacity(0.25)))
                        if f.sending { ProgressView().controlSize(.small).tint(Theme.text) }
                        Button { join() } label: {
                            Text(t("Subscribe", "Nhận bản tin")).font(.system(size: fs(13), weight: .semibold)).foregroundColor(.white)
                                .padding(.horizontal, 16).padding(.vertical, 7).background(Capsule().fill(Theme.accent))
                        }.buttonStyle(.plain).hoverLift()
                    }
                    // Same choice as the Contact form (PRIVACY.md: optional, on by default, can be unticked).
                    Toggle(isOn: $f.includeInfo) {
                        Text(t("Attach app version, macOS version and Mac model", "Kèm phiên bản app, phiên bản macOS và đời máy"))
                            .font(.system(size: fs(11))).foregroundColor(Theme.sub)
                    }.toggleStyle(.checkbox)
                    if !f.result.isEmpty { Text(f.result).font(.system(size: fs(11))).foregroundColor(Theme.warn) }
                    HStack(spacing: 14) {
                        TextLink(t("Later", "Để sau"), size: 11, weight: .regular, color: Theme.sub) { Invite.later(); f.hidden = true }
                        TextLink(t("Don't ask again", "Không hỏi lại"), size: 11, weight: .regular, color: Theme.sub) { Invite.never(); f.hidden = true }
                    }
                }
            }
            .padding(16).background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.ink.opacity(0.12), lineWidth: 1))
        }
    }
    func join() {
        let email = f.email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Backend.validEmail(email) else { f.result = t("Please enter a valid email.", "Bạn nhập email hợp lệ giúp nhé."); return }
        UserDefaults.standard.set(email, forKey: "contactEmail")
        f.sending = true; f.result = ""
        var fields = ["source": source, "type": "newsletter", "email": email, "message": "", "newsletter": "yes",
                      "consent": Backend.newsletterText, "consentVersion": Backend.consentVersion]
        if f.includeInfo { fields.merge(Backend.systemInfo) { a, _ in a } }   // only when the box is ticked
        Backend.send(fields) { ok in
            f.sending = false
            if ok { f.ok = true; Invite.subscribed() }
            else { f.result = t("Could not sign up right now. Please try again later.", "Chưa đăng ký được lúc này. Bạn thử lại sau nhé.") }
        }
    }
}
