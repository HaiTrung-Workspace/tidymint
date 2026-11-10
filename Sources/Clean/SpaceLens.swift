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

// MARK: - Circle packing (greedy)

struct Bubble { let node: Node; var x: CGFloat; var y: CGFloat; var r: CGFloat; let color: Color }

/// Same nodes and size give the same layout: hovering a bubble redraws the view, packing again would be wasted.
@MainActor private var packCache: (key: String, value: [Bubble])? = nil
@MainActor func pack(_ nodes: [Node], in size: CGSize) -> [Bubble] {
    let key = "\(Int(size.width))x\(Int(size.height))|" + nodes.map { "\($0.url.path)=\($0.size)" }.joined(separator: "|")
    if let c = packCache, c.key == key { return c.value }
    let v = packLayout(nodes, in: size)
    packCache = (key, v)
    return v
}
func packLayout(_ nodes: [Node], in size: CGSize) -> [Bubble] {
    // Bubble area is proportional to size (radius = square root); no forced minimum size.
    guard !nodes.isEmpty, size.width > 50 else { return [] }
    let maxS = Double(nodes.map(\.size).max() ?? 1)
    var bs: [Bubble] = []
    for (i, n) in nodes.enumerated() {
        let r = CGFloat(100 * sqrt(Double(n.size) / maxS))
        guard r > 0.5 else { continue }
        let col = n.otherCount > 0 ? Theme.ink.opacity(0.35) : Theme.bubbles[i % Theme.bubbles.count]
        if bs.isEmpty { bs.append(Bubble(node: n, x: 0, y: 0, r: r, color: col)); continue }
        var best: (CGFloat, CGFloat, CGFloat)? = nil
        for b in bs {
            for a in stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 36) {
                let d = b.r + r + 2
                let x = b.x + CGFloat(cos(a)) * d, y = b.y + CGFloat(sin(a)) * d
                if bs.allSatisfy({ hypot($0.x - x, $0.y - y) >= $0.r + r + 1.5 }) {
                    let dist = hypot(x * 0.75, y)
                    if best == nil || dist < best!.2 { best = (x, y, dist) }
                }
            }
        }
        if best == nil { // fallback: spiral outwards until there is room, so no item is dropped
            var rad: CGFloat = 0, a = 0.0
            while best == nil {
                rad += 2; a += 0.35
                let x = rad * CGFloat(cos(a)), y = rad * CGFloat(sin(a))
                if bs.allSatisfy({ hypot($0.x - x, $0.y - y) >= $0.r + r + 1.5 }) { best = (x, y, 0) }
            }
        }
        bs.append(Bubble(node: n, x: best!.0, y: best!.1, r: r, color: col))
    }
    let minX = bs.map { $0.x - $0.r }.min()!, maxX = bs.map { $0.x + $0.r }.max()!
    let minY = bs.map { $0.y - $0.r }.min()!, maxY = bs.map { $0.y + $0.r }.max()!
    let s = min((size.width - 20) / (maxX - minX), (size.height - 20) / (maxY - minY))
    let cx = (minX + maxX) / 2, cy = (minY + maxY) / 2
    return bs.map { Bubble(node: $0.node, x: ($0.x - cx) * s + size.width / 2, y: ($0.y - cy) * s + size.height / 2, r: $0.r * s, color: $0.color) }
}

/// Space Lens bubble in the "glass bubble" style of CleanMyMac's Space Lens: a translucent fill, a brighter rim that
/// fades toward the centre, a thin light outline and a soft coloured glow. No specular highlight, no drop shadow.
struct Sphere: View {
    let color: Color; let r: CGFloat; var hot = false
    static func mix(_ c: Color, _ other: NSColor, _ f: CGFloat) -> Color {
        Color(NSColor(c).usingColorSpace(.sRGB)?.blended(withFraction: f, of: other) ?? NSColor(c))
    }
    var body: some View {
        let edge = Sphere.mix(color, .white, 0.2)
        ZStack {
            // One continuous radial gradient: darkest in the centre, getting lighter towards the edge with no hard step.
            let k: Double = hot ? 1.25 : 1
            Circle().fill(RadialGradient(gradient: Gradient(stops: [
                .init(color: color.opacity(0.14 * k), location: 0.0),
                .init(color: color.opacity(0.18 * k), location: 0.45),
                .init(color: color.opacity(0.28 * k), location: 0.72),
                .init(color: color.opacity(0.42 * k), location: 0.90),
                .init(color: edge.opacity(0.55 * k), location: 1.0)]),
                center: .center, startRadius: 0, endRadius: r))
            Circle().fill(LinearGradient(colors: [Theme.ink.opacity(0.06), Theme.ink.opacity(0)], startPoint: .top, endPoint: .center))
            Circle().strokeBorder(edge.opacity(hot ? 0.55 : 0.32), lineWidth: 0.75)
        }
        .shadow(color: color.opacity(hot ? 0.5 : 0.3), radius: max(3, r * 0.12))
    }
}

// MARK: - Folder explanations (Space Lens)

func folderInfo(_ u: URL) -> String? {
    let n = u.lastPathComponent, p = u.path
    let m: [String: (String, String)] = [
        "Caches": ("Temporary app data. Safe to clear, apps rebuild it.", "Dữ liệu tạm của app. Xoá được, app tự tạo lại."),
        "Application Support": ("App data and settings. Delete only for apps you removed.", "Dữ liệu và cài đặt của app. Chỉ xoá phần của app đã gỡ."),
        "Containers": ("Data of App Store apps. Delete only for apps you removed.", "Dữ liệu app tải từ App Store. Chỉ xoá phần của app đã gỡ."),
        "Group Containers": ("Data shared between apps of one maker (Office, Messages...).", "Dữ liệu dùng chung giữa các app cùng hãng (Office, Tin nhắn...)."),
        "Mobile Documents": ("iCloud Drive files kept on this Mac.", "File iCloud Drive đang lưu trên máy."),
        "CloudStorage": ("Google Drive / OneDrive / Dropbox files on this Mac. Use Cloud Cleanup.", "File Google Drive / OneDrive / Dropbox trên máy. Dọn ở mục Dữ liệu đám mây."),
        "Developer": ("Xcode data, simulators, build files and archives. Build files can go; keep the archives of apps you released.", "Dữ liệu Xcode, máy ảo, file build và bản archive. File build xoá được; giữ archive của bản đã phát hành."),
        "DerivedData": ("Xcode build files. Xcode makes them again; the next build is slower. Quit Xcode first.", "File build của Xcode. Xcode tự tạo lại, lần build sau lâu hơn. Đóng Xcode trước."),
        "CoreSimulator": ("iPhone simulators. Delete old ones in Xcode.", "Máy ảo iPhone. Xoá bản cũ trong Xcode."),
        "Logs": ("Log files. Safe to clear.", "File nhật ký. Xoá được."),
        "Mail": ("Mail messages and attachments. Manage in the Mail app.", "Thư và tệp đính kèm. Dọn trong app Mail."),
        "Messages": ("Messages history and attachments. Manage in Settings > General > Storage.", "Lịch sử Tin nhắn và tệp đính kèm. Dọn trong Cài đặt > Cài đặt chung > Dung lượng."),
        "Downloads": ("Things you downloaded. Usually full of installers you no longer need.", "File đã tải về. Thường đầy file cài đặt không còn cần."),
        "Movies": ("Videos. Check for old exports and screen recordings.", "Video. Soi các bản xuất và quay màn hình cũ."),
        "Pictures": ("Photos and the Photos library.", "Ảnh và thư viện Ảnh."),
        "Music": ("Music and GarageBand / Logic files.", "Nhạc và file GarageBand / Logic."),
        "Desktop": ("Files on your desktop.", "File trên màn hình chính."),
        "Documents": ("Your documents.", "Tài liệu của bạn."),
        "Library": ("System and app data for your account. Be careful here.", "Dữ liệu hệ thống và app của tài khoản. Cẩn thận khi xoá."),
        "node_modules": ("Code packages of a project. Re-installable with npm install.", "Gói code của dự án. Cài lại được bằng npm install."),
        ".npm": ("npm download cache. Safe to clear.", "Bộ nhớ tạm của npm. Xoá được."),
        ".cache": ("Cache of command-line tools. Safe to clear.", "Bộ nhớ tạm của công cụ dòng lệnh. Xoá được."),
        ".Trash": ("The Trash.", "Thùng rác."),
        "Photos Library.photoslibrary": ("Photos library. Do not delete here, manage in Photos.", "Thư viện Ảnh. Đừng xoá ở đây, dọn trong app Ảnh."),
        "Saved Application State": ("Window positions of apps. Safe to clear.", "Vị trí cửa sổ app. Xoá được."),
        "iOS DeviceSupport": ("System symbols copied from each iPhone you plugged in, used to read crash reports. Old versions can go; Xcode copies them again only from a device still on that version.", "Ký hiệu hệ thống chép từ từng iPhone từng cắm, dùng để đọc báo cáo lỗi. Bản cũ xoá được; Xcode chỉ chép lại từ máy còn chạy đúng bản đó."),
        "Draw Things": ("Draw Things AI models. Large; remove unused models inside the app.", "Model AI của Draw Things. Rất nặng, gỡ model không dùng ngay trong app."),
        "huggingface": ("Downloaded AI models (Hugging Face). Re-downloadable.", "Model AI tải từ Hugging Face. Tải lại được."),
        ".ollama": ("Ollama AI models. Remove unused ones with 'ollama rm'.", "Model AI của Ollama. Gỡ model không dùng bằng 'ollama rm'."),
        "LM Studio": ("LM Studio AI models. Manage them inside the app.", "Model AI của LM Studio. Quản lý trong app."),
        "CapCut": ("CapCut data. Clear caches in CapCut Settings; never delete Projects.", "Dữ liệu CapCut. Xoá bộ nhớ đệm trong Cài đặt của CapCut, đừng xoá Projects."),
        "com.lveditor.draft": ("CapCut projects. Do not delete here; remove old projects inside CapCut.", "Dự án CapCut. Đừng xoá ở đây, xoá dự án cũ ngay trong CapCut."),
        "prerender": ("Rendering cache (CapCut). Clear in CapCut Settings > Performance.", "Bản dựng sẵn của CapCut. Xoá trong Cài đặt › Performance của CapCut."),
        "agencycache": ("Proxy copies of your clips (CapCut). Clear in CapCut Settings > Performance.", "Bản proxy video của CapCut. Xoá trong Cài đặt › Performance của CapCut."),
        "Homebrew": ("Homebrew downloads. Run 'brew cleanup' to clear what is no longer needed.", "File tải của Homebrew. Chạy 'brew cleanup' để dọn phần không cần."),
        "com.docker.docker": ("Docker data. Shrink it with 'docker system prune'; don't delete files by hand.", "Dữ liệu Docker. Thu gọn bằng 'docker system prune', đừng xoá tay."),
        "Docker.raw": ("Docker's disk image. Shrink it with 'docker system prune'; deleting it wipes all containers and images.", "Ổ đĩa ảo của Docker. Thu gọn bằng 'docker system prune'; xoá file này là mất hết container và image.")
    ]
    if p.hasSuffix("/Developer/Xcode/Archives") {
        return t("Xcode archives. Keep the ones you shipped: you need them to read crash reports.", "Bản archive Xcode. Giữ các bản đã phát hành: cần để đọc báo cáo lỗi.")
    }
    if let v = m[n] {
        if Scanner.limited && (n == "Pictures" || n == "Music") {
            return t(v.0, v.1) + t(" Library not counted: needs Full Disk Access.", " Chưa tính thư viện: cần quyền Truy cập toàn bộ ổ đĩa.")
        }
        return t(v.0, v.1)
    }
    if p.contains("/Library/Containers/") || p.contains("/Library/Application Support/") { return t("Data of one app.", "Dữ liệu của một app.") }
    return nil
}

struct LensView: View {
    @ObservedObject var vm: VM
    var body: some View {
        if vm.sysOpen {
            SysDataView(vm: vm)
        } else if vm.lensPath.isEmpty {
            VStack(spacing: 28) {
                Header(title: t("Space Lens", "Bản đồ ổ đĩa"), sub: t("See what takes up space, folder by folder. Cloud folders (Google Drive, iCloud Drive...) are not measured here; see the Cloud page.\nClick a bubble to look inside.", "Xem thư mục nào chiếm chỗ. Thư mục đám mây (Google Drive, iCloud Drive...) không đo ở đây, xem trang Đám mây.\nBấm vào bong bóng để xem bên trong."))
                BigScanButton(label: t("Scan", "Quét")) { vm.openLens(Scanner.home) }
                HStack(spacing: 12) {
                    GhostButton(title: "Library") { vm.openLens(Scanner.lib) }
                    GhostButton(title: "Documents") { vm.openLens(Scanner.home.appendingPathComponent("Documents")) }
                    // External drives plugged in right now (local disks under /Volumes, not network shares or hidden volumes).
                    ForEach(externalDrives(), id: \.path) { d in
                        GhostButton(title: d.lastPathComponent) { vm.openLens(d) }.tip(t("Map this external drive", "Xem bản đồ ổ cứng rời này"))
                    }
                }
                TextLink(t("Disk full of \"System Data\"? See what is in it", "Ổ đầy vì \"System Data\"? Xem nó gồm những gì"), size: fs(13), weight: .semibold) { vm.openSys() }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                // breadcrumb
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Button { vm.lensBack() } label: { Image(systemName: "chevron.left") }.buttonStyle(.icon)
                            .foregroundColor(vm.lensPath.count > 1 ? Theme.text : Theme.sub.opacity(0.4)).disabled(vm.lensPath.count <= 1).tip(t("Back", "Lùi"))
                        Button { vm.lensForward() } label: { Image(systemName: "chevron.right") }.buttonStyle(.icon)
                            .foregroundColor(vm.lensFwd.isEmpty ? Theme.sub.opacity(0.4) : Theme.text).disabled(vm.lensFwd.isEmpty).tip(t("Forward", "Tiến"))
                            .padding(.trailing, 8)
                        Button { vm.stopLens(); vm.lensPath = []; vm.lensNodes = []; vm.lensSel = []; vm.lensFwd = [] } label: { Image(systemName: "house") }.buttonStyle(.icon).tip(t("Go to your home folder", "Về thư mục người dùng")).foregroundColor(Theme.text)
                        ForEach(Array(vm.lensPath.enumerated()), id: \.offset) { i, u in
                            Image(systemName: "chevron.right").font(.system(size: fs(10))).foregroundColor(Theme.sub)
                            Button { vm.lensUp(to: i) } label: {
                                Text(i == 0 && u.path == NSHomeDirectory() ? t("Home", "Nhà") : u.lastPathComponent).padding(.horizontal, 4).padding(.vertical, 2).hoverTile()
                            }.buttonStyle(.plain).foregroundColor(i == vm.lensPath.count - 1 ? Theme.text : Theme.sub)
                        }
                    }
                }.padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 10)
                DoneBanner(vm: vm, page: .lens)

                if vm.lensBusy {
                    HStack(spacing: 10) {
                        ProgressView(value: Double(vm.lensDone), total: Double(max(vm.lensTotal, 1))).tint(Theme.accentSolid).frame(width: 160)
                        Text(t("Measured \(vm.lensDone)/\(vm.lensTotal)", "Đã đo \(vm.lensDone)/\(vm.lensTotal)") + (vm.lensCurrent.isEmpty ? "" : t(" · now: ", " · đang đo: ") + vm.lensCurrent))
                            .font(.system(size: fs(11))).foregroundColor(Theme.sub).lineLimit(1)
                        Spacer()
                        TextLink(t("Stop", "Dừng"), size: 11, weight: .semibold, color: Theme.text) { vm.stopLens() }
                    }.padding(.horizontal, 24).padding(.bottom, 8)
                }
                if vm.lensBusy && vm.lensNodes.isEmpty {
                    Scanning(text: t("Measuring folders...", "Đang đo thư mục...")).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 0) {
                        // list
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(vm.lensNodes) { n in
                                    HStack(spacing: 10) {
                                        let blocked = Scanner.blocked(n.url.path)
                                        Button { if vm.lensSel.contains(n.url) { vm.lensSel.remove(n.url) } else { vm.lensSel.insert(n.url) } } label: {
                                            CheckBox(state: vm.lensSel.contains(n.url) ? 2 : 0).opacity(blocked ? 0.25 : 1)
                                        }.buttonStyle(.plain).disabled(blocked).tip(blocked ? t("Protected", "Được bảo vệ") : "")
                                        FileThumb(url: n.url, side: 22 * uiScale)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(n.name).foregroundColor(Theme.text).font(.system(size: fs(13))).lineLimit(1)
                                            if n.otherCount == 0, let info = folderInfo(n.url) {
                                                Text(info).foregroundColor(Theme.sub).font(.system(size: fs(10))).lineLimit(1)
                                            }
                                        }.tip(n.otherCount == 0 ? (folderInfo(n.url) ?? "") : "")
                                        Spacer()
                                        Text(fmt(n.size)).foregroundColor(Theme.sub).font(.system(size: fs(12)).monospacedDigit())
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(vm.hoverNode == n.id || vm.lensSel.contains(n.url) ? Theme.cardHi : Color.clear))
                                    .contentShape(Rectangle())
                                    // Folder: click goes into it. File: click = Quick Look, double-click = open. Space = Quick Look.
                                    .onTapGesture(count: 2) { if !n.isDir && n.otherCount == 0 { vm.fileQL = nil; vm.openFile(n.url) } }
                                    .onTapGesture { if n.isDir { vm.openLens(n.url) } else if n.otherCount == 0 { vm.fileQL = n.url } }
                                    .onHover { h in
                                        vm.hoverNode = h ? n.id : nil
                                        if n.otherCount == 0 { if h { vm.hoverFile = n.url } else if vm.hoverFile == n.url { vm.hoverFile = nil } }
                                    }
                                    .contextMenu { nodeMenu(n) }
                                }
                            }.padding(.horizontal, 12)
                        }.frame(width: 300 * uiScale).background(Theme.shade.opacity(0.15))
                        // bubbles
                        GeometryReader { g in
                            let total = max(vm.lensNodes.reduce(0) { $0 + $1.size }, 1)
                            let bs = pack(lensBubbles(vm.lensNodes, folder: vm.lensPath.last), in: g.size)
                            ZStack {
                                ForEach(bs, id: \.node.id) { b in
                                    ZStack {
                                        Sphere(color: b.color, r: b.r, hot: vm.hoverNode == b.node.id || vm.lensSel.contains(b.node.url))
                                        if vm.lensSel.contains(b.node.url) && b.node.otherCount == 0 {
                                            Circle().strokeBorder(Theme.accent, lineWidth: 2.5)
                                        }
                                        let pct = Double(b.node.size) / Double(total) * 100
                                        let pctText = pct < 1 ? "<1%" : String(format: "%.0f%%", pct)
                                        if b.r > 34 {
                                            VStack(spacing: 2) {
                                                Text(b.node.name).font(.system(size: max(9, min(14, b.r / 5)), weight: .semibold)).lineLimit(1)
                                                Text(fmt(b.node.size) + " · " + pctText).font(.system(size: max(8, min(12, b.r / 6))))
                                            }.foregroundColor(.white).frame(width: b.r * 1.6).shadow(color: .black.opacity(Theme.p.light ? 0.7 : 0.5), radius: Theme.p.light ? 3 : 2, y: 1)
                                        } else if b.r > 14 {
                                            Text(pctText).font(.system(size: fs(9), weight: .semibold)).foregroundColor(Theme.text)
                                        }
                                    }
                                    .frame(width: b.r * 2, height: b.r * 2)
                                    .scaleEffect(vm.hoverNode == b.node.id ? 1.03 : 1)
                                    .animation(.easeOut(duration: 0.18), value: vm.hoverNode == b.node.id)
                                    .position(x: b.x, y: b.y)
                                    .onTapGesture { if b.node.isDir && b.node.otherCount == 0 { vm.openLens(b.node.url) } }
                                    .onHover { h in vm.hoverNode = h ? b.node.id : nil }
                                    .contextMenu { if b.node.otherCount == 0 { nodeMenu(b.node) } }
                                    .tip(b.node.otherCount > 0
                                          ? t("\(b.node.otherCount) small items (under 1% each), \(fmt(b.node.size)). See the list on the left.",
                                              "\(b.node.otherCount) mục nhỏ (mỗi mục dưới 1%), \(fmt(b.node.size)). Xem ở danh sách bên trái.")
                                          : "\(b.node.name): \(fmt(b.node.size))" + (folderInfo(b.node.url).map { "\n" + $0 } ?? ""))
                                }
                            }
                        }.padding(12)
                    }
                }
                HStack {
                    if vm.lensSel.isEmpty {
                        Text(t("Total: ", "Tổng: ") + fmt(vm.lensNodes.reduce(0) { $0 + $1.size })).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                        Spacer()
                        Text(t("Click a folder to open it. Tick items to move them to the Trash.", "Bấm vào thư mục để mở. Tick mục muốn chuyển vào Thùng rác.")).foregroundColor(Theme.sub).font(.system(size: fs(11)))
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selLabel(vm.lensSel.count, vm.lensSelSize)).foregroundColor(Theme.text).font(.system(size: fs(15), weight: .semibold))
                            Text(t("Moved to the Trash, not deleted yet.", "Chỉ chuyển vào Thùng rác, chưa xoá hẳn.")).foregroundColor(Theme.sub).font(.system(size: fs(11)))
                        }
                        Spacer()
                        GhostButton(title: t("Deselect", "Bỏ chọn")) { vm.lensSel = [] }.padding(.trailing, 8)
                        PrimaryButton(title: t("Move to Trash", "Chuyển vào Thùng rác"), action: { vm.trashLensSelection() })
                    }
                }.padding(.horizontal, 24).padding(.vertical, 12).background(Theme.shade.opacity(0.25))
            }
        }
    }
    @ViewBuilder func nodeMenu(_ n: Node) -> some View {
        if n.isDir {
            Button(t("Open in Space Lens", "Xem trong Bản đồ ổ đĩa")) { vm.openLens(n.url) }
            FileMenu(url: n.url, vm: vm, openWith: false)
        } else {
            FileMenu(url: n.url, vm: vm)
        }
        if Scanner.blocked(n.url.path) {
            Text(t("Protected: cannot be removed here", "Được bảo vệ: không xoá từ đây được"))
        } else {
            Button(t("Move to Trash...", "Chuyển vào Thùng rác...")) { DispatchQueue.main.async { vm.trashNode(n) } }
        }
        Button(t("Ignore", "Bỏ qua")) { let u = n.url; DispatchQueue.main.async { vm.ignore(u) } }
    }
}
