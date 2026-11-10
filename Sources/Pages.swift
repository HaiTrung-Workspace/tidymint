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

// MARK: - Pages

struct Tile: View {
    let icon: String, title: String, value: String, sub: String
    let action: () -> Void
    @StateObject private var hover = Flag()
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).font(.system(size: fs(26))).foregroundStyle(Theme.accent)
                Text(title).foregroundColor(Theme.sub).font(.system(size: fs(13)))
                Text(value).foregroundColor(Theme.text).font(.system(size: fs(24), weight: .bold))
                Text(sub).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                Text(t("Review", "Xem")).font(.system(size: fs(12), weight: .semibold)).foregroundColor(Theme.text).padding(.top, 4)
            }
            .padding(20).frame(width: 200 * uiScale, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(hover.v ? Theme.cardHi : Theme.card))
        }.buttonStyle(.plain).onHover { hover.v = $0 }
    }
}

struct SmartView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(spacing: 22) {
            if !vm.fullDiskAccess && vm.phase != .scanning {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.warn)
                    Text(t("Full Disk Access is off, so Mail, Safari, Messages and the Photos and Music libraries stay hidden from the scan. Turn on Tidymint in System Settings, then come back.",
                           "Chưa có quyền Truy cập toàn bộ ổ đĩa, nên Mail, Safari, Tin nhắn và thư viện Ảnh, Nhạc bị ẩn khỏi lượt quét. Bật Tidymint trong Cài đặt hệ thống rồi quay lại."))
                        .font(.system(size: fs(12))).foregroundColor(Theme.text).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    GhostButton(title: t("Open Settings", "Mở Cài đặt")) { NSWorkspace.shared.open(VM.fdaSettings) }
                }.padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Theme.warn.opacity(0.12))).frame(maxWidth: 620)
            }
            switch vm.phase {
            case .scanning:
                ScanSteps(title: t("Scanning your Mac...", "Đang quét máy..."), steps: VM.junkSteps + [t("Large files", "File lớn")], current: vm.scanStep, detail: vm.scanDetail)
            case .idle:
                CheckInCard()
                Header(title: t("Tidy up a little?", "Dọn máy chút nhé?"),
                       sub: t("Scan finds the safe part: caches, logs, old downloads. You see what it is, then press Clean.\nEverything goes to the Trash first, so you can change your mind.",
                              "Quét sẽ tìm phần an toàn: bộ nhớ đệm, nhật ký, Downloads cũ. Bạn xem rồi mới bấm Dọn.\nMọi thứ vào Thùng rác trước, đổi ý thì lấy lại được."))
                if let v = vm.newVersion {
                    Button { NSWorkspace.shared.open(Updates.page) } label: {
                        Label(t("Tidymint \(v) is available. Download", "Đã có Tidymint \(v). Tải về"), systemImage: "arrow.down.circle")
                            .font(.system(size: fs(12), weight: .medium)).foregroundColor(Theme.text)
                            .padding(.horizontal, 12).padding(.vertical, 6).background(Capsule().fill(Theme.ink.opacity(0.12)))
                    }.buttonStyle(.plain).hoverLift()
                }
                BigScanButton(label: t("Scan", "Quét")) { vm.smartScan() }
                    .onAppear { CheckIn.shared.refresh() }   // the card itself is empty while hidden, so it cannot carry onAppear
                Text(t("Nothing is moved until you press Clean.", "Chưa dọn gì cho tới khi bạn bấm Dọn.")).font(.system(size: fs(12))).foregroundColor(Theme.sub)
                HStack(spacing: 14) {
                    HomeCard(title: t("Chrome, Slack, Telegram...", "Zalo, Chrome, Telegram..."), value: t("Clean by App", "Dọn theo ứng dụng"), sub: t("by type and by month", "theo loại, theo tháng")) { vm.page = .byapp }
                    HomeCard(title: t("Photos, videos, old files", "Ảnh, video, file cũ"), value: t("Large Files", "File lớn"), sub: t("you choose", "bạn tự chọn")) { vm.page = .large }
                    HomeCard(title: t("Trash", "Thùng rác"), value: fmt(vm.trashSize), sub: t("empty it to delete for good", "đổ là xoá sạch")) { vm.page = .trash }
                }.padding(.top, 6)
            case .done:
                Image(systemName: "checkmark.circle.fill").font(.system(size: fs(54))).foregroundColor(Theme.green)
                Text(vm.lastFreed > 0 ? t("\(fmt(vm.lastFreed)) tidier", "Gọn thêm \(fmt(vm.lastFreed))") : t("Already tidy", "Máy đang gọn rồi"))
                    .font(.system(size: fs(40), weight: .bold)).foregroundColor(Theme.text)
                Text(vm.lastFreed > 0
                     ? t("\(vm.lastCount) items moved to the Trash. Nothing is lost yet: empty the Trash to free the space for real, or undo if you change your mind.",
                         "Đã chuyển \(vm.lastCount) mục vào Thùng rác. Chưa mất gì cả: đổ Thùng rác thì ổ mới trống thật, hoặc bấm Hoàn tác nếu đổi ý.")
                     : t("Nothing safe to clean right now. Try Clean by App or Large Files for things only you can decide on.",
                         "Không có gì an toàn để dọn lúc này. Thử Dọn theo ứng dụng hoặc File lớn, là phần chỉ bạn quyết được."))
                    .foregroundColor(Theme.sub).multilineTextAlignment(.center).frame(maxWidth: 520)
                HStack(spacing: 12) {
                    if vm.undoable != nil { GhostButton(title: t("Undo", "Hoàn tác")) { vm.undoLast(); if vm.undoable == nil { vm.phase = .idle } } }
                    GhostButton(title: t("Open Trash", "Xem Thùng rác")) { vm.page = .trash }
                    PrimaryButton(title: t("Empty Trash", "Đổ Thùng rác"), action: { vm.emptyTrash() }, disabled: vm.trashCount == 0)
                }
                Button { vm.page = .byapp } label: {
                    (Text(t("Want more room? ", "Muốn gọn hơn nữa? ")).foregroundColor(Theme.sub)
                     + Text(t("Clean by App", "Dọn theo ứng dụng")).foregroundColor(Theme.text).underline()
                     + Text(t(" lists what Zalo, Chrome and CapCut keep.", " cho xem Zalo, Chrome, CapCut đang giữ gì.")).foregroundColor(Theme.sub))
                        .font(.system(size: fs(12)))
                }.buttonStyle(.plain).linkHover().padding(.top, 6)
                if Invite.shouldShow() { InviteCard(source: "after-clean").frame(maxWidth: 520).padding(.top, 8) }
                if ConCao.shouldShow() { ConCaoHint().frame(maxWidth: 520) }
            default:
                Text(vm.junkSelected > 0 ? t("\(fmt(vm.junkSelected)) safe to clean", "\(fmt(vm.junkSelected)) an toàn để dọn") : t("Already tidy", "Máy đang gọn rồi"))
                    .font(.system(size: fs(40), weight: .bold)).foregroundColor(Theme.text)
                Text(vm.junkSelected > 0
                     ? t("Apps rebuild all of this on their own. Everything goes to the Trash first.", "Toàn bộ phần này app tự tạo lại được. Mọi thứ vào Thùng rác trước.")
                     : t("Nothing safe to clean right now. Try Clean by App or Large Files for things only you can decide on.", "Không có gì an toàn để dọn lúc này. Thử Dọn theo ứng dụng hoặc File lớn, là phần chỉ bạn quyết được."))
                    .foregroundColor(Theme.sub).multilineTextAlignment(.center).frame(maxWidth: 520)
                // What will be cleaned, one card per group: the decision is informed without opening the full list.
                // Cleaning itself stays on the single button below (preview first, then Clean).
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190 * uiScale, maximum: 260 * uiScale), spacing: 12)], spacing: 12) {
                    ForEach(vm.cats) { c in
                        JunkCard(cat: c) {
                            if let i = vm.cats.firstIndex(where: { $0.id == c.id }) { for j in vm.cats.indices { vm.cats[j].expanded = j == i } }
                            vm.page = .cleanup; vm.phase = .review
                        }
                    }
                }.frame(maxWidth: 820).padding(.horizontal, 24)
                HStack(spacing: 14) {
                    GhostButton(title: t("Review every item", "Xem từng mục")) { vm.page = .cleanup; vm.phase = .review }
                    PrimaryButton(title: t("Clean (\(fmt(vm.junkSelected)))", "Dọn (\(fmt(vm.junkSelected)))"), action: { vm.cleanJunk() }, disabled: vm.junkSelected == 0)
                }
                if vm.junkSelected > 0 {
                    Text(t("Not selected: \(fmt(vm.junkTotal - vm.junkSelected)) that only you can decide on. Tick it under Review every item.", "Chưa tick: \(fmt(vm.junkTotal - vm.junkSelected)) là phần bạn tự quyết. Muốn dọn thì tick ở Xem từng mục."))
                        .font(.system(size: fs(11))).foregroundColor(Theme.sub)
                }
                TextLink(t("Disk still full of \"System Data\"? See what is in it", "Ổ vẫn đầy vì \"System Data\"? Xem nó gồm những gì"), size: fs(12), weight: .semibold) {
                    vm.page = .lens; vm.openSys()
                }.padding(.top, 2)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { vm.refreshTrash() }
    }
}

/// Small navigation card on the home page: what it is, where it goes, who decides.
struct HomeCard: View {
    let title: String, value: String, sub: String
    let action: () -> Void
    @StateObject private var hover = Flag()
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).foregroundColor(Theme.sub).font(.system(size: fs(11))).lineLimit(1)
                Text(value).foregroundColor(Theme.text).font(.system(size: fs(16), weight: .semibold))
                Text(sub).foregroundColor(Theme.sub).font(.system(size: fs(11)))
            }
            .padding(14).frame(width: 190 * uiScale, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(hover.v ? Theme.cardHi : Theme.card))
        }.buttonStyle(.plain).onHover { hover.v = $0 }
    }
}

struct CleanupView: View {
    @ObservedObject var vm: VM
    var body: some View {
        switch vm.phase {
        case .idle:
            VStack(spacing: 28) {
                Header(title: t("Cleanup", "Dọn rác"), sub: t("Find caches, logs, drafts and old downloads.\nItems are moved to the Trash, not deleted.", "Tìm bộ nhớ đệm, nhật ký, nháp và Downloads cũ.\nChỉ chuyển vào Thùng rác, chưa xoá hẳn."))
                BigScanButton(label: t("Scan", "Quét")) { vm.scanJunk() }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .scanning:
            ScanSteps(title: t("Looking for junk...", "Đang tìm rác..."), steps: VM.junkSteps, current: vm.scanStep, detail: vm.scanDetail).frame(maxWidth: .infinity, maxHeight: .infinity)
        case .summary:
            VStack(spacing: 24) {
                Text(fmt(vm.junkTotal)).font(.system(size: fs(54), weight: .bold)).foregroundColor(Theme.text)
                Text(t("can be cleaned. \(fmt(vm.junkSelected)) is rebuilt by apps on their own and is pre-selected.", "có thể dọn. \(fmt(vm.junkSelected)) là phần app tự tạo lại được, đã chọn sẵn.")).foregroundColor(Theme.sub)
                HStack(spacing: 14) {
                    GhostButton(title: t("Review Details", "Xem chi tiết")) { vm.phase = .review }
                    PrimaryButton(title: t("Clean", "Dọn"), action: { vm.cleanJunk() }, disabled: vm.junkSelected == 0)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .review:
            ReviewView(vm: vm)
        case .done:
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: fs(64))).foregroundColor(Theme.green)
                Text(vm.lastFreed > 0 ? t("\(fmt(vm.lastFreed)) tidier", "Gọn thêm \(fmt(vm.lastFreed))") : t("All done!", "Xong rồi!")).font(.system(size: fs(40), weight: .bold)).foregroundColor(Theme.text)
                Text(vm.lastResult).foregroundColor(Theme.sub).multilineTextAlignment(.center)
                Text(t("Last step: review the Trash, then empty it.", "Bước cuối: xem lại Thùng rác rồi đổ.")).foregroundColor(Theme.sub)
                HStack(spacing: 14) {
                    if vm.undoable != nil { GhostButton(title: t("Undo", "Hoàn tác")) { vm.undoLast() } }
                    GhostButton(title: t("Scan Again", "Quét lại"), action: { vm.scanJunk() }, compact: true)
                    PrimaryButton(title: t("Open Trash", "Xem Thùng rác"), action: { vm.page = .trash })
                }
                if Invite.shouldShow() { InviteCard(source: "after-clean").frame(maxWidth: 520).padding(.top, 8) }
                if ConCao.shouldShow() { ConCaoHint().frame(maxWidth: 520) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ReviewView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { vm.phase = .summary } label: { Label(t("Back", "Quay lại"), systemImage: "chevron.left").padding(.horizontal, 6).padding(.vertical, 3).hoverTile() }.buttonStyle(.plain).foregroundColor(Theme.text)
                Spacer()
                Text(t("Cleanup Details", "Dọn rác chi tiết")).font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                Spacer()
                Menu(t("Select", "Chọn")) {
                    Button(t("Select All", "Chọn tất cả")) { vm.setAll(true) }
                    Button(t("Deselect All", "Bỏ chọn tất cả")) { vm.setAll(false) }
                    Button(t("Smart Selection", "Chọn thông minh")) { vm.scanJunk(thenReview: true) }
                }.menuStyle(.borderlessButton).frame(width: 70).foregroundColor(Theme.text).padding(.vertical, 3).hoverTile()
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 14)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach($vm.cats) { $cat in
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Button { vm.toggleCat(cat.id) } label: { CheckBox(state: cat.state) }.buttonStyle(.plain)
                                Image(systemName: cat.icon).font(.system(size: fs(15))).foregroundStyle(Theme.accent).frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.title).foregroundColor(Theme.text).font(.system(size: fs(13)))
                                    Text(cat.desc).foregroundColor(Theme.sub).font(.system(size: fs(11)))
                                }
                                Spacer()
                                SafetyBadge(level: cat.safety, why: cat.why)
                                Text(t("\(cat.items.count) items", "\(cat.items.count) mục")).foregroundColor(Theme.sub).font(.system(size: fs(12)))
                                Text(fmt(cat.selectedSize) + " / " + fmt(cat.total)).foregroundColor(Theme.text)
                                    .font(.system(size: fs(13), weight: .medium).monospacedDigit()).frame(width: 150, alignment: .trailing)
                                Image(systemName: "chevron.down").rotationEffect(.degrees(cat.expanded ? 0 : -90)).foregroundColor(Theme.sub)
                            }
                            .padding(14).hoverBG(14, Theme.ink.opacity(0.06)).contentShape(Rectangle())
                            .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { cat.expanded.toggle() } }

                            if cat.expanded {
                                Divider().background(Theme.ink.opacity(0.1))
                                // Big items one by one; everything under 512 KB folded into one row (still selectable and expandable).
                                ForEach($cat.items) { $it in if it.size >= Category.smallLimit { ItemRow(item: $it, vm: vm) } }.padding(.leading, 26)
                                SmallItemsRow(cat: $cat, vm: vm).padding(.leading, 26)
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                    }
                }.padding(.horizontal, 24).padding(.bottom, 16)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selLabel(vm.cats.reduce(0) { $0 + $1.items.filter(\.selected).count }, vm.junkSelected)).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                    Text(t("Moved to the Trash, not deleted yet. Right-click an item for more.", "Chỉ chuyển vào Thùng rác, chưa xoá hẳn. Chuột phải vào một mục để xem thêm.")).foregroundColor(Theme.sub).font(.system(size: fs(11)))
                }
                Spacer()
                PrimaryButton(title: t("Clean", "Dọn"), action: { vm.cleanJunk() }, disabled: vm.junkSelected == 0)
            }.padding(.horizontal, 24).padding(.vertical, 14).background(Theme.shade.opacity(0.25))
        }
    }
}

struct ByAppView: View {
    @ObservedObject var vm: VM
    var body: some View {
        if vm.appBusy {
            Scanning(text: t("Measuring app data...", "Đang đo dữ liệu từng app...")).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !vm.appScanned {
            VStack(spacing: 28) {
                Header(title: t("Clean by App", "Dọn theo ứng dụng"),
                       sub: t("Zalo, Telegram, WhatsApp, Slack, Outlook, VS Code, CapCut and Chrome, Edge, Cốc Cốc: see what each app keeps on your Mac and clean it by type.\nAlso the AI models of Ollama, LM Studio and Hugging Face, one by one.\nMessages and logins are never touched.",
                              "Zalo, Telegram, WhatsApp, Slack, Outlook, VS Code, CapCut và Chrome, Edge, Cốc Cốc: xem từng app đang giữ gì trên máy và dọn theo loại.\nCó cả model AI của Ollama, LM Studio, Hugging Face, hiện từng model một.\nTin nhắn và đăng nhập không bao giờ bị đụng."))
                BigScanButton(label: t("Scan", "Quét")) { vm.scanByApp() }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let id = vm.appSel, let r = vm.appReports.first(where: { $0.id == id }) {
            AppDetail(vm: vm, report: r)
        } else {
            AppList(vm: vm)
        }
    }
}

/// Local external drives mounted now (under /Volumes, not hidden, not network): for Space Lens.
func externalDrives() -> [URL] {
    (FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeIsLocalKey, .volumeIsInternalKey], options: [.skipHiddenVolumes]) ?? [])
        .filter { $0.path.hasPrefix("/Volumes/") && (try? $0.resourceValues(forKeys: [.volumeIsLocalKey]))?.volumeIsLocal == true }
        .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
}
func appIcon(_ bundleIDs: [String]) -> NSImage {
    for b in bundleIDs { if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: b) { return NSWorkspace.shared.icon(forFile: u.path) } }
    return NSWorkspace.shared.icon(for: .applicationBundle)
}
func appInstalled(_ bundleIDs: [String]) -> Bool { bundleIDs.contains { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil } }

/// App icon for a Clean by App rule. The app may be gone while its data stays (e.g. CapCut removed, Movies/CapCut left):
/// then a neutral tile with the app's initial instead of macOS's blank "application" icon, which looks broken.
struct RuleIcon: View {
    let name: String; let bundleIDs: [String]; let side: CGFloat
    var body: some View {
        if appInstalled(bundleIDs) {
            Image(nsImage: appIcon(bundleIDs)).resizable().frame(width: side, height: side)
        } else {
            RoundedRectangle(cornerRadius: side * 0.22).fill(Theme.ink.opacity(0.12))
                .overlay(Text(String(name.prefix(1))).font(.system(size: side * 0.48, weight: .semibold)).foregroundColor(Theme.sub))
                .frame(width: side * 0.86, height: side * 0.86).frame(width: side, height: side)
        }
    }
}

struct AppList: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("Clean by App", "Dọn theo ứng dụng")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text)
                    Text(t("\(vm.appReports.count) apps, \(fmt(vm.appReports.reduce(0) { $0 + $1.cleanable })) can be cleaned. Folders with a database inside are always left out.", "\(vm.appReports.count) app, có thể dọn \(fmt(vm.appReports.reduce(0) { $0 + $1.cleanable })). Thư mục có database bên trong luôn được bỏ qua."))
                        .font(.system(size: fs(12))).foregroundColor(Theme.sub)
                }
                Spacer()
                GhostButton(title: t("Scan Again", "Quét lại"), action: { vm.scanByApp() }, compact: true)
            }.padding(.horizontal, 24).padding(.top, 30).padding(.bottom, 14)
            DoneBanner(vm: vm, page: .byapp)
            if !vm.appMsg.isEmpty { Text(vm.appMsg).font(.system(size: fs(12))).foregroundColor(Theme.green).padding(.horizontal, 24).padding(.bottom, 8) }
            if vm.appReports.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "app.dashed").font(.system(size: fs(40))).foregroundColor(Theme.sub)
                    Text(t("None of the supported apps keeps data on this Mac.", "Không thấy dữ liệu của các app được hỗ trợ trên máy này.")).foregroundColor(Theme.sub)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.appReports) { r in
                            HStack(spacing: 14) {
                                RuleIcon(name: r.rule.name, bundleIDs: r.rule.bundleIDs, side: 40)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(r.rule.name).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .semibold))
                                    Text(r.groups.map { "\($0.section.title) \(fmt($0.total))" }.joined(separator: " · ")).font(.system(size: fs(11))).foregroundColor(Theme.sub).lineLimit(1)
                                }
                                Spacer(minLength: 12)
                                if r.running { StatusTag(t("Open", "Đang mở"), Theme.warn) }
                                else if !r.rule.noApp && !appInstalled(r.rule.bundleIDs) { StatusTag(t("App removed", "App đã gỡ"), Theme.sub).tip(t("The app is gone but its data is still here.", "App đã gỡ nhưng dữ liệu vẫn còn.")) }
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(fmt(r.total)).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .semibold).monospacedDigit())
                                    Text(t("\(fmt(r.cleanable)) cleanable", "dọn được \(fmt(r.cleanable))")).font(.system(size: fs(11))).foregroundColor(Theme.sub)
                                }.frame(minWidth: 110 * uiScale, alignment: .trailing)
                                Image(systemName: "chevron.right").foregroundColor(Theme.sub)
                            }
                            .padding(14).background(RoundedRectangle(cornerRadius: 10).fill(Theme.card)).hoverBG(10, Theme.ink.opacity(0.06))
                            .contentShape(Rectangle()).onTapGesture { vm.appSel = r.id; vm.appAge = 0 }
                        }
                    }.padding(.horizontal, 24).padding(.bottom, 16)
                }
            }
        }
        .onAppear { vm.refreshAppRunning() }
    }
}

struct AppDetail: View {
    @ObservedObject var vm: VM
    let report: AppReport
    var hasAge: Bool { report.groups.contains { $0.section.byAge } }
    var body: some View {
        if let ref = vm.monthRef, ref.app == report.id { MonthViewer(vm: vm, report: report, ref: ref) } else { list }
    }
    var list: some View {
        VStack(spacing: 0) {
            HStack {
                Button { vm.closeMonth(); vm.appSel = nil } label: { Label(t("Back", "Quay lại"), systemImage: "chevron.left").padding(.horizontal, 6).padding(.vertical, 3).hoverTile() }.buttonStyle(.plain).foregroundColor(Theme.text)
                Spacer()
                HStack(spacing: 8) {
                    RuleIcon(name: report.rule.name, bundleIDs: report.rule.bundleIDs, side: 22)
                    Text(report.rule.name).font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                    Text(fmt(report.total)).font(.system(size: fs(13))).foregroundColor(Theme.sub)
                }
                Spacer()
                if hasAge {
                    Picker("", selection: Binding(get: { vm.appAge }, set: { vm.selectOlder(report.id, months: $0) })) {
                        Text(t("Pick by hand", "Tự tick")).tag(0)
                        Text(t("Older than 3 months", "Cũ hơn 3 tháng")).tag(3)
                        Text(t("Older than 6 months", "Cũ hơn 6 tháng")).tag(6)
                        Text(t("Older than 1 year", "Cũ hơn 1 năm")).tag(12)
                    }.pickerStyle(.menu).frame(width: 170)
                } else { Color.clear.frame(width: 170, height: 1) }
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 14)

            if report.running {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.warn)
                    Text(t("\(report.rule.name) is open. Quit it before cleaning so it does not write to these files.", "\(report.rule.name) đang mở. Tắt app trước khi dọn để app không ghi vào các file này."))
                        .font(.system(size: fs(12))).foregroundColor(Theme.text)
                    Spacer()
                    GhostButton(title: t("Quit \(report.rule.name)", "Tắt \(report.rule.name)")) { vm.quitApp(report.id) }
                }.padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Theme.warn.opacity(0.12))).padding(.horizontal, 24).padding(.bottom, 10)
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(report.groups) { g in
                        let locked = g.section.safety == .locked
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                if locked { Image(systemName: "lock.fill").foregroundColor(Theme.danger).frame(width: 18) }
                                else { Button { vm.toggleAppGroup(report.id, g.id) } label: { CheckBox(state: g.state) }.buttonStyle(.plain) }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(g.section.title).foregroundColor(Theme.text).font(.system(size: fs(13)))
                                    Text(g.section.why).foregroundColor(Theme.sub).font(.system(size: fs(11))).lineLimit(2)
                                }
                                Spacer()
                                SafetyBadge(level: g.section.safety, why: g.section.why)
                                Text(locked ? fmt(g.total) : fmt(g.selected) + " / " + fmt(g.total)).foregroundColor(Theme.text)
                                    .font(.system(size: fs(13), weight: .medium).monospacedDigit()).frame(width: 150, alignment: .trailing)
                                Image(systemName: "chevron.down").rotationEffect(.degrees(g.expanded ? 0 : -90)).foregroundColor(Theme.sub).opacity(locked ? 0 : 1)
                            }
                            .padding(14).hoverBG(14, Theme.ink.opacity(0.06)).contentShape(Rectangle())
                            .onTapGesture { if !locked { vm.toggleAppExpand(report.id, g.id) } }
                            if g.expanded && !locked {
                                Divider().background(Theme.ink.opacity(0.1))
                                ForEach(g.rows) { row in
                                    HStack(spacing: 12) {
                                        Button { vm.toggleAppRow(report.id, g.id, row.id) } label: { CheckBox(state: row.checkState) }.buttonStyle(.plain)
                                        if let u = row.urls.first, row.month == nil {
                                            Image(nsImage: NSWorkspace.shared.icon(forFile: u.path)).resizable().frame(width: 22, height: 22)
                                        } else { Image(systemName: "calendar").foregroundColor(Theme.sub).frame(width: 22) }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(row.title).foregroundColor(Theme.text).font(.system(size: fs(13))).lineLimit(1)
                                            RowSubLine(row: row)
                                        }
                                        Spacer()
                                        Text(fmt(row.size)).foregroundColor(Theme.text).font(.system(size: fs(13), weight: .medium).monospacedDigit()).frame(width: 80, alignment: .trailing)
                                        if row.month != nil { Image(systemName: "chevron.right").foregroundColor(Theme.sub).font(.system(size: fs(12))) }
                                    }
                                    .padding(.vertical, 6).padding(.horizontal, 12).hoverBG(8, Theme.ink.opacity(0.07)).contentShape(Rectangle())
                                    // A month opens the month viewer; a single file or folder: click = Quick Look,
                                    // double-click = open in its default app, Space over it = Quick Look (like Finder).
                                    .onTapGesture(count: 2) { if row.month == nil, let u = row.urls.first { vm.fileQL = nil; vm.openFile(u) } }
                                    .onTapGesture { if row.month != nil { vm.openMonth(report.id, g.id, row.id) } else if let u = row.urls.first { vm.fileQL = u } }
                                    .onHover { inside in
                                        guard row.month == nil, let u = row.urls.first else { return }
                                        if inside { vm.hoverFile = u } else if vm.hoverFile == u { vm.hoverFile = nil }
                                    }
                                    .contextMenu {
                                        if row.month != nil {
                                            Button(t("View files", "Xem các file")) { vm.openMonth(report.id, g.id, row.id) }
                                            if let u = row.urls.first { Button(t("Show in Finder", "Hiện trong Finder")) { vm.reveal(u) } }
                                        } else if let u = row.urls.first { FileMenu(url: u, vm: vm) }
                                    }
                                }.padding(.leading, 26)
                                // Data several rows share (Ollama): no tick of its own, it goes when every row that uses it is ticked.
                                if g.sharedParts(freed: false).reduce(0, { $0 + $1.size }) > 0 {
                                    let all = g.sharedParts(freed: false).reduce(0) { $0 + $1.size }, going = g.sharedParts(freed: true).reduce(0) { $0 + $1.size }
                                    HStack(spacing: 12) {
                                        Image(systemName: going == all ? "checkmark.circle.fill" : "link").foregroundColor(going == all ? Theme.green : Theme.sub).frame(width: 18)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(t("Shared part", "Phần dùng chung")).foregroundColor(Theme.text).font(.system(size: fs(13)))
                                            Text(going == all ? t("Every model that uses it is ticked: it goes to the Trash with them", "Đã tick hết các model dùng nó: sẽ vào Thùng rác cùng lúc")
                                                 : going > 0 ? t("\(fmt(going)) of it goes now; the rest waits for the other models that use it", "\(fmt(going)) sẽ được dọn; phần còn lại chờ tick hết các model dùng nó")
                                                 : t("Used by several models above. It goes only when all of them are ticked", "Nhiều model ở trên cùng dùng. Chỉ được dọn khi tick hết các model đó"))
                                                .foregroundColor(Theme.sub).font(.system(size: fs(11))).lineLimit(2)
                                        }
                                        Spacer()
                                        Text(fmt(all)).foregroundColor(going == all ? Theme.text : Theme.sub).font(.system(size: fs(13), weight: .medium).monospacedDigit()).frame(width: 80, alignment: .trailing)
                                    }
                                    .padding(.vertical, 6).padding(.horizontal, 12).padding(.leading, 26)
                                }
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                    }
                }.padding(.horizontal, 24).padding(.bottom, 16)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selLabel(report.groups.filter { $0.section.safety != .locked }.reduce(0) { $0 + $1.rows.filter(\.selected).count }, report.selected)).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                    Text(t("Everything goes to the Trash first. Undo is on the Trash page.", "Mọi thứ vào Thùng rác trước. Hoàn tác ở trang Thùng rác.")).foregroundColor(Theme.sub).font(.system(size: fs(11)))
                }
                Spacer()
                PrimaryButton(title: t("Move to Trash", "Chuyển vào Thùng rác"), action: { vm.cleanApp(report.id) }, disabled: report.selected == 0)
            }.padding(.horizontal, 24).padding(.vertical, 14).background(Theme.shade.opacity(0.25))
        }
        .onAppear { vm.refreshAppRunning() }
    }
}

struct LargeView: View {
    @ObservedObject var vm: VM
    @StateObject private var sortByDate = Flag()
    var body: some View {
        VStack(spacing: 0) {
            switch vm.largePhase {
            case .idle:
                VStack(spacing: 28) {
                    Header(title: t("Large & Old Files", "File lớn và cũ"), sub: t("Files over 100 MB in your folders and the drives added in Settings, hidden files included. App and library packages are listed whole, not opened.\nNothing is ticked; you choose.", "File trên 100 MB trong các thư mục của bạn và ổ đã thêm ở Cài đặt, gồm cả file ẩn. Gói của app hay thư viện được liệt kê nguyên gói, không mở ra.\nKhông tick sẵn, bạn tự chọn."))
                    BigScanButton(label: t("Scan", "Quét")) { vm.scanLarge() }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            case .scanning:
                Scanning(text: t("Looking for large files...", "Đang tìm file lớn...")).frame(maxWidth: .infinity, maxHeight: .infinity)
            default:
                HStack {
                    Text(t("Large Files (\(vm.large.count))", "File lớn (\(vm.large.count))")).font(.system(size: fs(13), weight: .semibold)).foregroundColor(Theme.text)
                    Spacer()
                    Picker("", selection: $sortByDate.v) { Text(t("By Size", "Theo dung lượng")).tag(false); Text(t("Oldest Opened", "Lâu không mở")).tag(true) }
                        .pickerStyle(.segmented).controlSize(.small).fixedSize()
                    Button { vm.scanLarge() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.icon).tip(t("Scan again", "Quét lại"), trailing: true).foregroundColor(Theme.text).padding(.leading, 8)
                }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 14)
                DoneBanner(vm: vm, page: .large)
                if vm.large.isEmpty {
                    Text(t("No files over 100 MB.", "Không có file nào trên 100 MB.")).foregroundColor(Theme.sub).frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            let index = Dictionary(uniqueKeysWithValues: vm.large.enumerated().map { ($1.id, $0) })
                            ForEach(sortedIDs(), id: \.self) { id in
                                if let i = index[id] {
                                    ItemRow(item: $vm.large[i], vm: vm, showDate: true)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                                }
                            }
                        }.padding(.horizontal, 24)
                    }
                }
                HStack {
                    Text(selLabel(vm.large.filter(\.selected).count, vm.largeSelected)).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                    Spacer()
                    PrimaryButton(title: t("Move to Trash", "Chuyển vào Thùng rác"), action: { vm.cleanLarge() }, disabled: vm.largeSelected == 0)
                }.padding(.horizontal, 24).padding(.vertical, 14).background(Theme.shade.opacity(0.25))
            }
        }
    }
    /// Rows keyed by item id, so a row never shows another file's thumbnail after items are removed.
    func sortedIDs() -> [UUID] {
        let l = vm.large
        if sortByDate.v { return l.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }.map(\.id) }
        return l.sorted { $0.size > $1.size }.map(\.id)
    }
}

struct IgnoreView: View {
    @ObservedObject var vm: VM
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Ignore List", "Danh sách bỏ qua")).font(.system(size: fs(15), weight: .bold)).foregroundColor(Theme.text)
                    Text(t("Items here never show up in scans. Add files or folders here, or right-click an item in a scan list.", "Mục ở đây không bao giờ hiện trong kết quả quét. Thêm file, thư mục ở đây, hoặc chuột phải vào một mục trong danh sách quét."))
                        .foregroundColor(Theme.sub).font(.system(size: fs(12)))
                }
                Spacer(minLength: 16)
                GhostButton(title: t("Add…", "Thêm…"), action: { vm.addIgnoredByPicker() }, compact: true)
            }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 16)
            if vm.ignored.isEmpty {
                Text(t("Nothing ignored yet.", "Chưa bỏ qua mục nào.")).foregroundColor(Theme.sub).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(vm.ignored, id: \.self) { p in
                            HStack(spacing: 10) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: p)).resizable().frame(width: 20, height: 20)
                                Text(p.replacingOccurrences(of: NSHomeDirectory(), with: "~")).foregroundColor(Theme.text).font(.system(size: fs(12)))
                                    .lineLimit(1).truncationMode(.middle)
                                Spacer()
                                TextLink(t("Remove", "Gỡ"), size: 13) { vm.unignore(p) }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                            .hoverBG(10, Theme.ink.opacity(0.06))
                        }
                    }.padding(.horizontal, 24)
                }
            }
        }
    }
}
