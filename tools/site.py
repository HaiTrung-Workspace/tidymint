#!/usr/bin/env python3
"""Generate docs/index.html (English) and docs/vi/index.html (Vietnamese) from one template.
Run from the repository root: python3 tools/site.py"""
import json, os, html

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GH = "https://github.com/HaiTrung-Workspace/tidymint"
DL = GH + "/releases/latest/download/Tidymint.zip"
ENDPOINT = "https://script.google.com/macros/s/AKfycbz07aYQ8kI0u0OV842dt-LxeN5TedqfOzNvhmuVAPmgXdcIGtpzI-GNwLE_kiUMiGDKag/exec"
BASE_CSS = open(os.path.join(ROOT, "tools", "site.css")).read()
EXTRA_CSS = """
.topnav{position:sticky;top:0;z-index:10;background:#06150fe6;-webkit-backdrop-filter:blur(10px);backdrop-filter:blur(10px);border-bottom:1px solid #ffffff12}
nav{display:flex;align-items:center;justify-content:space-between;padding:12px 0}
.navr{display:flex;align-items:center;gap:22px}
.lang{display:inline-flex;border:1px solid #ffffff33;border-radius:8px;padding:2px;gap:2px;font-size:13px;font-weight:600}
.lang a{padding:3px 9px;border-radius:6px;color:var(--sub)}.lang a:hover{text-decoration:none;color:var(--text)}.lang a.on{background:#ffffff26;color:var(--text)}
.navcta{padding:7px 14px;font-size:14px}
.vs{display:grid;grid-template-columns:1fr 1fr;gap:16px}
.vs .col{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:24px}
.vs .col.good{border-color:#2fd39f66;background:linear-gradient(160deg,#145c4766,#10302780)}
.vs h3{margin:0 0 12px;font-size:20px}.vs ul{list-style:none;padding:0;margin:0}.vs li{padding:8px 0 8px 30px;position:relative;color:var(--sub);border-top:1px solid var(--line)}
.vs li:before{position:absolute;left:4px;top:8px;font-weight:700}.vs .bad li:before{content:"✕";color:#ff7a7a}.vs .good li:before{content:"✓";color:var(--leaf)}
.tag{display:inline-block;font-size:12px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;color:var(--leaf);margin-bottom:8px}
.def{display:grid;grid-template-columns:1.2fr 1fr;gap:36px;align-items:center}
.def p{color:var(--sub)}.def ul{color:var(--sub);padding-left:20px}
.how{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;counter-reset:h}
.how .card{counter-increment:h;position:relative;padding-top:56px}.how .card:before{content:counter(h);position:absolute;left:20px;top:18px;width:28px;height:28px;border-radius:50%;background:var(--mint2);color:#fff;font-weight:700;display:flex;align-items:center;justify-content:center}
.ico{font-size:22px;display:block;margin-bottom:8px}
details{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:0 18px;margin-bottom:10px}
summary{cursor:pointer;padding:16px 0;font-weight:600;list-style:none}summary::-webkit-details-marker{display:none}summary:after{content:"+";float:right;color:var(--leaf);font-size:20px;line-height:1}details[open] summary:after{content:"−"}
details p{color:var(--sub);margin:0 0 16px}
.steps{counter-reset:s;list-style:none;padding:0;margin:0 0 20px}.steps li{counter-increment:s;position:relative;padding:14px 16px 14px 58px;margin-bottom:10px;background:var(--card);border:1px solid var(--line);border-radius:12px;color:var(--sub)}.steps li b{color:var(--text)}.steps li:before{content:counter(s);position:absolute;left:16px;top:14px;width:28px;height:28px;border-radius:50%;background:var(--mint2);color:#fff;font-weight:700;display:flex;align-items:center;justify-content:center}
.note{background:#ffb02014;border:1px solid #ffb02055;border-radius:12px;padding:14px 16px;color:var(--sub);font-size:15px;margin-bottom:20px}
.fcols{display:grid;grid-template-columns:1.4fr 1fr 1fr 1fr;gap:24px;padding:36px 0 20px;border-top:1px solid var(--line)}
.fcols h4{margin:0 0 10px;font-size:14px;color:var(--text)}.fcols a{display:block;color:var(--sub);font-size:14px;padding:3px 0}.fcols p{color:var(--sub);font-size:14px;margin:8px 0 0}
footer{border-top:0;padding:0 0 28px}
@media (max-width:820px){.vs,.def,.how,.fcols{grid-template-columns:1fr}.navcta{display:none}}

/* Hover only on things that can be clicked. Nothing moves its box on hover (moving boxes made the
   pointer slip off the edge and flicker); feedback is a glow ring, border and background change. */
.btn,.topbar a,.lang a,details,nav .links a,.fcols a{transition:box-shadow .18s ease,border-color .18s ease,background-color .18s ease,color .18s ease}
.btn:hover{filter:none}
@media (hover:hover){
 .btn.primary:hover{box-shadow:0 0 0 3px #2fd39f40,0 10px 26px #0f8f6866}
 .btn.ghost:hover{border-color:#2fd39faa;background-color:#ffffff0d}
 .topbar a:hover{border-color:#2fd39faa;background-color:#ffffff0d;box-shadow:0 0 0 3px #2fd39f26}
 details:hover{border-color:#2fd39f66}
 nav .links a:hover,.fcols a:hover{color:var(--text);text-decoration:none}
 .lang a:hover{background-color:#ffffff14}
 .up:hover{border-color:#2fd39f;box-shadow:0 14px 36px #0f8f6866}
}
.btn:active,.topbar a:active{filter:brightness(.92)}
.arr{display:inline-block;transition:transform .18s ease}a:hover .arr{transform:translateX(4px)}
.topbar{text-align:center;padding:8px 0 28px}
.topbar a{display:inline-flex;align-items:center;gap:8px;padding:10px 20px;border-radius:999px;border:1px solid #ffffff33;color:var(--text);font-size:14px;font-weight:600}
.topbar a:hover{text-decoration:none}
.up{position:fixed;left:50%;bottom:22px;transform:translate(-50%,90px);opacity:0;pointer-events:none;z-index:20;display:inline-flex;align-items:center;gap:8px;padding:10px 18px;border-radius:999px;border:1px solid #2fd39f66;background:#0b2620f2;color:var(--text);font-family:inherit;font-size:14px;font-weight:600;box-shadow:0 12px 30px #0008;cursor:pointer;transition:transform .25s ease,opacity .25s ease,box-shadow .18s ease,border-color .18s ease}
.up.show{transform:translate(-50%,0);opacity:1;pointer-events:auto}
.up.show:active{transform:translate(-50%,0) scale(.98)}
summary{user-select:none}
@media (prefers-reduced-motion:reduce){*{transition:none!important;scroll-behavior:auto!important}}
"""

T = {
"en": dict(
  lang="en", path="", other="vi/", title="Free Mac Cleaner, CleanMyMac Alternative | Tidymint",
  desc="Tidymint is a free, open-source Mac cleaner. Clear caches and System Data, find duplicate files, uninstall apps completely and see what fills your disk. Everything goes to the Trash first.",
  nav=[("#features","Features"),("#how","How it works"),("#faq","FAQ"),(GH,"GitHub")], navcta="Download",
  h1='Keep your Mac in <span>mint condition</span>.',
  sub="Tidymint is a free, open-source Mac cleaner. Clear caches and System Data, remove duplicate files, uninstall apps completely and see exactly what fills your disk.",
  cta1="Download free", cta2="How to install",
  badges=["✓ Free and open source (MIT)","✓ Everything goes to the Trash first","✓ Works offline, no tracking"],
  shot_alt="Tidymint Smart Scan results",
  vs_tag="Why Tidymint", vs_h="A cleaner you can actually trust",
  vs_bad_h="Typical paid cleaners", vs_bad=["Paid licence or subscription, major upgrades often cost extra","Closed source: you cannot see what it deletes","Cracked copies are a common way to get malware"],
  vs_good_h="Tidymint", vs_good=["Free, with no account and no subscription","Open source (MIT): anyone can read every line","Only moves items to the Trash, you empty it yourself"],
  def_tag="Good to know", def_h="What is “System Data” on a Mac?",
  def_p="In <b>System Settings › General › Storage</b>, macOS groups everything it cannot sort into a category called <b>System Data</b>. It often grows to tens of gigabytes and is hard to inspect from Finder.",
  def_li=["App and browser caches, logs and temporary files","Leftovers from apps you already deleted","Local Time Machine snapshots and old installers","For AI work: model weights and package caches"],
  def_p2="Tidymint shows which of these folders are large on your Mac, explains each one in plain words, and lets you move the safe ones to the Trash.",
  how_tag="How it works", how_h="Three steps, you stay in control",
  how=[("Scan","One click looks through caches, logs, old downloads, large files and duplicates. Nothing is touched yet."),("Review","Every item is grouped, sized and explained. Risky items are never pre-selected, files still used by your scripts are flagged."),("Clean","Selected items move to the Trash. Check the Trash, then empty it when you are ready.")],
  feat_tag="Features", feat_h="Everything in one small app",
  feats=[("🧹","Smart Scan","Caches, logs, npm cache, old downloads and drafts in your project folders."),("🗂️","Duplicates","Identical files found by content. Keeps the best copy, checks your scripts before deleting."),("🫧","Space Lens","A bubble map of what fills your disk, with notes for common folders."),("🧩","Uninstaller","Removes apps with their caches, preferences and leftovers."),("📦","Large & old files","Files over 100 MB, sorted by size or last opened. Never pre-selected."),("📊","Menu bar","Free space, RAM and Trash at a glance, with low-space alerts.")],
  use_tag="Made for", use_h="Who fills their Mac the fastest",
  uses=[("🤖","AI work","Model weights, Hugging Face and Ollama caches, generated images."),("👩‍💻","Developers","node_modules, npm and Homebrew caches, old builds."),("🎬","Video and photo","Exports, render drafts and duplicate assets."),("💻","256 GB Macs","Every gigabyte counts on a small SSD.")],
  faq_h="Questions",
  faq=[("Is Tidymint really free?","Yes. It is open source under the MIT licence, with no account, no subscription and no paid tier."),
       ("Is it safe?","Tidymint only moves items to the Trash, so you can put anything back. It never touches Photos, Mail, keychains, cloud storage roots or Apple system caches, and risky items are never pre-selected."),
       ("Why does macOS block it the first time?","Tidymint is not notarized by Apple yet (that needs a paid developer account). Open it once from System Settings › Privacy & Security › Open Anyway, as Apple describes in its own guide. The source code is public on GitHub."),
       ("Does it send my data anywhere?","No. It works offline. Data only leaves your Mac if you send feedback or join the newsletter yourself."),
       ("How is it different from CleanMyMac?","Tidymint is free and open source and focuses on cleaning and disk space. It has no malware scanner or performance tweaks."),
       ("Which Macs are supported?","macOS 14 or later, on both Apple silicon and Intel."),
       ("Is there a Windows or iPhone version?","No. iOS does not allow apps to clean other apps' data, and Windows is not planned for now.")],
  inst_h="Install", inst_lead="macOS 14 or later, Apple silicon and Intel.",
  inst_note="Tidymint is not notarized by Apple yet, so macOS blocks the first launch. This happens to every app that is not notarized. The source code is public on GitHub.",
  inst=['<b>Download</b> <a href="%s">Tidymint.zip</a>, open it and drag <b>Tidymint</b> to <b>Applications</b>.' % DL,
        '<b>First launch:</b> double-click Tidymint. When macOS says it cannot be opened, click <b>Done</b>.',
        '<b>Allow it:</b> open <b>System Settings › Privacy &amp; Security</b>, scroll down, click <b>Open Anyway</b>, enter your password if asked, then <b>Open</b>.',
        '<b>Full Disk Access:</b> in the same pane, turn on Tidymint under <b>Full Disk Access</b> so it can measure every folder.'],
  inst_small='Steps from Apple: <a href="https://support.apple.com/102445">Safely open apps on your Mac</a>. Prefer to build it yourself? <code>git clone %s.git &amp;&amp; cd tidymint &amp;&amp; ./build.sh --install</code>' % GH,
  sign_h="Get updates", sign_p="Mac tips and new releases, at most one email a month.", sign_ph="name@example.com", sign_btn="Subscribe",
  consent="Get the latest updates. Unsubscribe any time.",
  end_h="Ready to tidy up?", end_p="Free, open source, and everything goes to the Trash first.",
  f_blurb="Free, open-source Mac cleaner. Provided as is, without warranty.",
  f_cols=[("Product",[("#features","Features"),("#how","How it works"),("#install","Install"),(GH+"/releases","Releases")]),
          ("Resources",[(GH,"Source code"),(GH+"/issues","Report a bug"),("#faq","FAQ")]),
          ("Legal",[(GH+"/blob/main/PRIVACY.md","Privacy"),(GH+"/blob/main/LICENSE","MIT License"),("mailto:hello@tidymint.app","hello@tidymint.app")])],
  copy="© 2026 Tidymint", extra_footer="",
  msg=dict(bad="Please enter a valid email.",sending="Sending...",ok="Thanks! You are on the list.",err="Could not send right now. Please try again later."),
  src="website", img="", aria_lang="Language", top="Back to top"),
"vi": dict(
  lang="vi", path="vi/", other="../", title="App dọn rác Mac miễn phí, thay CleanMyMac | Tidymint",
  desc="Tidymint là app dọn rác Mac miễn phí, mã nguồn mở, có tiếng Việt. Dọn bộ nhớ đệm và Dữ liệu hệ thống, tìm file trùng, gỡ app sạch sẽ, xem cái gì chiếm ổ. Mọi thứ vào Thùng rác trước.",
  nav=[("#tinh-nang","Tính năng"),("#cach-dung","Cách dùng"),("#hoi-dap","Hỏi đáp"),(GH,"GitHub")], navcta="Tải về",
  h1='Giữ máy Mac <span>luôn gọn gàng</span>.',
  sub="Tidymint là app dọn rác Mac miễn phí, mã nguồn mở, giao diện tiếng Việt. Dọn bộ nhớ đệm và Dữ liệu hệ thống, tìm file trùng, gỡ app sạch sẽ và xem chính xác cái gì đang chiếm ổ.",
  cta1="Tải miễn phí", cta2="Hướng dẫn cài",
  badges=["✓ Miễn phí, mã nguồn mở (MIT)","✓ Chỉ chuyển vào Thùng rác","✓ Chạy không cần mạng, không theo dõi"],
  shot_alt="Kết quả Quét thông minh của Tidymint",
  vs_tag="Vì sao chọn Tidymint", vs_h="App dọn dẹp bạn tin được",
  vs_bad_h="App dọn dẹp trả phí thường gặp", vs_bad=["Trả tiền bản quyền hoặc thuê bao, lên đời bản lớn thường tốn thêm","Mã nguồn đóng: không biết app xoá những gì","Bản crack là đường lây mã độc rất phổ biến"],
  vs_good_h="Tidymint", vs_good=["Miễn phí, không cần tài khoản, không thuê bao","Mã nguồn mở (MIT): ai cũng đọc được từng dòng","Chỉ chuyển vào Thùng rác, bạn tự đổ"],
  def_tag="Nên biết", def_h="“Dữ liệu hệ thống” trên Mac là gì?",
  def_p="Trong <b>Cài đặt hệ thống › Cài đặt chung › Dung lượng</b>, macOS gom mọi thứ không xếp được vào mục <b>Dữ liệu hệ thống</b> (System Data). Mục này hay phình lên hàng chục GB và khó xem bằng Finder.",
  def_li=["Bộ nhớ đệm, nhật ký, file tạm của app và trình duyệt","Phần sót lại của app đã xoá","Bản chụp Time Machine trên máy và file cài đặt cũ","Với người làm AI: file model và bộ nhớ đệm thư viện"],
  def_p2="Tidymint chỉ ra thư mục nào đang lớn trên máy bạn, giải thích từng thư mục bằng lời dễ hiểu, và cho bạn chuyển các mục an toàn vào Thùng rác.",
  how_tag="Cách dùng", how_h="Ba bước, bạn luôn là người quyết",
  how=[("Quét","Một cú bấm xem qua bộ nhớ đệm, nhật ký, Downloads cũ, file lớn và file trùng. Chưa động vào gì."),("Xem lại","Từng mục được chia nhóm, ghi dung lượng và giải thích. Mục rủi ro không bao giờ chọn sẵn, file còn được script dùng sẽ được đánh dấu."),("Dọn","Mục đã chọn chuyển vào Thùng rác. Xem lại Thùng rác rồi tự đổ khi sẵn sàng.")],
  feat_tag="Tính năng", feat_h="Đủ cả trong một app nhỏ",
  feats=[("🧹","Quét thông minh","Bộ nhớ đệm, nhật ký, npm cache, Downloads cũ và file nháp trong thư mục dự án."),("🗂️","File trùng","Tìm theo nội dung. Giữ bản tốt nhất, kiểm tra script trước khi xoá."),("🫧","Bản đồ ổ đĩa","Bong bóng cho thấy cái gì chiếm ổ, kèm giải thích thư mục hay gặp."),("🧩","Gỡ app","Gỡ app cùng bộ nhớ đệm, cài đặt và phần sót lại."),("📦","File lớn và cũ","File trên 100 MB, xếp theo dung lượng hoặc lần mở cuối. Không chọn sẵn."),("📊","Thanh menu","Xem nhanh dung lượng trống, RAM, Thùng rác; báo khi ổ sắp đầy.")],
  use_tag="Dành cho", use_h="Ai hay đầy ổ nhất",
  uses=[("🤖","Người làm AI","File model, bộ nhớ đệm Hugging Face, Ollama, ảnh tạo bằng AI."),("👩‍💻","Lập trình viên","node_modules, npm, Homebrew, bản build cũ."),("🎬","Làm video, ảnh","File xuất, bản nháp render, ảnh trùng."),("💻","Mac 256 GB","Ổ nhỏ thì từng GB đều quý.")],
  faq_h="Hỏi đáp",
  faq=[("Tidymint có miễn phí thật không?","Có. App mã nguồn mở theo giấy phép MIT, không tài khoản, không thuê bao, không có bản trả phí."),
       ("Có an toàn không?","Tidymint chỉ chuyển vào Thùng rác nên lấy lại được hết. App không bao giờ động tới Ảnh, Mail, mật khẩu, thư mục đám mây hay bộ nhớ đệm hệ thống của Apple, và mục rủi ro không bao giờ chọn sẵn."),
       ("Sao lần đầu macOS lại chặn?","Tidymint chưa được Apple công chứng (cần tài khoản nhà phát triển trả phí). Mở một lần qua Cài đặt hệ thống › Quyền riêng tư & Bảo mật › Vẫn mở, đúng như hướng dẫn của Apple. Mã nguồn công khai trên GitHub."),
       ("App có gửi dữ liệu của tôi đi không?","Không. App chạy không cần mạng. Dữ liệu chỉ rời máy khi bạn tự gửi góp ý hoặc đăng ký bản tin."),
       ("Khác gì CleanMyMac?","Tidymint miễn phí, mã nguồn mở, tập trung vào dọn dẹp và dung lượng ổ. App không có quét mã độc hay tinh chỉnh hiệu năng."),
       ("Chạy trên máy nào?","macOS 14 trở lên, cả máy chip Apple lẫn máy Intel."),
       ("Có bản Windows hay iPhone không?","Không. iOS không cho app dọn dữ liệu của app khác, còn Windows hiện chưa có kế hoạch.")],
  inst_h="Cài đặt", inst_lead="Cần macOS 14 trở lên, chạy được cả máy chip Apple và máy Intel.",
  inst_note="Tidymint chưa được Apple công chứng (tài khoản nhà phát triển Apple tốn 99 USD/năm, app miễn phí nên chưa mua). Vì vậy lần đầu mở, macOS sẽ chặn. Đây là cảnh báo chung cho mọi app chưa công chứng. Mã nguồn công khai trên GitHub để ai cũng kiểm tra được.",
  inst=['<b>Tải về:</b> bấm <a href="%s">Tải Tidymint</a>, mở file <b>Tidymint.zip</b> trong Downloads, kéo <b>Tidymint</b> vào thư mục <b>Ứng dụng</b> (Applications).' % DL,
        '<b>Mở lần đầu:</b> nhấp đúp Tidymint. macOS báo không mở được, bấm <b>Xong</b> (Done). Đừng chọn Chuyển vào Thùng rác.',
        '<b>Cho phép mở:</b> vào <b>Cài đặt hệ thống › Quyền riêng tư &amp; Bảo mật</b>, kéo xuống cuối, bấm <b>Vẫn mở</b> (Open Anyway), nhập mật khẩu máy nếu được hỏi, rồi bấm <b>Mở</b>. Từ lần sau mở bình thường.',
        '<b>Cấp quyền đọc ổ đĩa:</b> vẫn trong <b>Quyền riêng tư &amp; Bảo mật</b>, chọn <b>Truy cập toàn bộ ổ đĩa</b> (Full Disk Access), bật <b>Tidymint</b>. Thiếu quyền này app vẫn chạy nhưng một số thư mục sẽ hiện trống.'],
  inst_small='Các bước mở app chưa công chứng theo hướng dẫn chính thức của Apple: <a href="https://support.apple.com/102445">Mở app an toàn trên máy Mac</a>. Bạn rành Terminal có thể tự build: <code>git clone %s.git &amp;&amp; cd tidymint &amp;&amp; ./build.sh --install</code>' % GH,
  sign_h="Nhận tin khi có bản mới", sign_p="Mẹo giữ máy gọn và thông báo phiên bản mới, mỗi tháng tối đa một thư.", sign_ph="ten@example.com", sign_btn="Đăng ký",
  consent="Nhận thông tin cập nhật mới nhất. Huỷ bất kỳ lúc nào.",
  end_h="Dọn máy thôi?", end_p="Miễn phí, mã nguồn mở, mọi thứ vào Thùng rác trước.",
  f_blurb="App dọn rác Mac miễn phí, mã nguồn mở. Cung cấp nguyên trạng, không bảo hành.",
  f_cols=[("Sản phẩm",[("#tinh-nang","Tính năng"),("#cach-dung","Cách dùng"),("#cai-dat","Cài đặt"),(GH+"/releases","Các phiên bản")]),
          ("Tài nguyên",[(GH,"Mã nguồn"),(GH+"/issues","Báo lỗi"),("#hoi-dap","Hỏi đáp")]),
          ("Pháp lý",[(GH+"/blob/main/PRIVACY.md","Quyền riêng tư"),(GH+"/blob/main/LICENSE","Giấy phép MIT"),("mailto:hello@tidymint.app","hello@tidymint.app")])],
  copy="© 2026 Tidymint", extra_footer=' · Cùng tác giả: <a href="https://concao.org/?utm_source=tidymint&amp;utm_medium=web&amp;utm_campaign=footer">Cồn Cào</a>',
  msg=dict(bad="Email chưa đúng.",sending="Đang gửi...",ok="Cảm ơn bạn! Đã đăng ký.",err="Chưa gửi được, bạn thử lại sau nhé."),
  src="website-vi", img="../", aria_lang="Ngôn ngữ", top="Lên đầu trang"),
}
IDS = {"en": dict(f="features", h="how", q="faq", i="install", s="signup"),
       "vi": dict(f="tinh-nang", h="cach-dung", q="hoi-dap", i="cai-dat", s="dang-ky")}

def page(k):
    t = T[k]; i = IDS[k]; img = t["img"]
    url = "https://tidymint.app/" + t["path"]
    ld = [
      {"@context":"https://schema.org","@type":"SoftwareApplication","name":"Tidymint","operatingSystem":"macOS 14 or later",
       "applicationCategory":"UtilitiesApplication","offers":{"@type":"Offer","price":"0","priceCurrency":"USD"},
       "downloadUrl":DL,"url":url,"license":"https://opensource.org/licenses/MIT","inLanguage":["en","vi"],"image":"https://tidymint.app/icon.png"},
      {"@context":"https://schema.org","@type":"FAQPage","mainEntity":[{"@type":"Question","name":q,"acceptedAnswer":{"@type":"Answer","text":a}} for q,a in t["faq"]]},
    ]
    nav = "".join('<a href="%s">%s</a>' % (h, l) for h, l in t["nav"])
    vi_on, en_on = ('class="on" ', '') if k == "vi" else ('', 'class="on" ')
    vi_href, en_href = ("./", "../") if k == "vi" else ("vi/", "./")
    feats = "".join('<div class="card"><span class="ico">%s</span><b>%s</b><span>%s</span></div>' % f for f in t["feats"])
    uses = "".join('<div class="card"><span class="ico">%s</span><b>%s</b><span>%s</span></div>' % u for u in t["uses"])
    how = "".join('<div class="card"><b>%s</b><span>%s</span></div>' % h for h in t["how"])
    faq = "".join('<details><summary>%s</summary><p>%s</p></details>' % (html.escape(q), html.escape(a)) for q, a in t["faq"])
    inst = "".join("<li>%s</li>" % s for s in t["inst"])
    fcols = "".join('<div><h4>%s</h4>%s</div>' % (h, "".join('<a href="%s">%s</a>' % l for l in links)) for h, links in t["f_cols"])
    m = t["msg"]
    redirect = "" if k == "vi" else "try{if(!localStorage.getItem('tm-lang')&&/^vi\\b/i.test(navigator.language||'')&&!location.hash)location.replace('vi/')}catch(e){}\n"
    return f'''<!doctype html>
<html lang="{t["lang"]}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{t["title"]}</title>
<meta name="description" content="{t["desc"]}">
<link rel="canonical" href="{url}">
<link rel="alternate" hreflang="en" href="https://tidymint.app/">
<link rel="alternate" hreflang="vi" href="https://tidymint.app/vi/">
<link rel="alternate" hreflang="x-default" href="https://tidymint.app/">
<link rel="icon" href="{img}favicon.png">
<meta property="og:title" content="{t["title"]}">
<meta property="og:description" content="{t["desc"]}">
<meta property="og:image" content="https://tidymint.app/smart.jpg">
<meta property="og:url" content="{url}">
<meta name="twitter:card" content="summary_large_image">
<script type="application/ld+json">{json.dumps(ld, ensure_ascii=False)}</script>
<style>{BASE_CSS}{EXTRA_CSS}</style>
</head>
<body id="top">
<div class="topnav"><div class="wrap"><nav>
  <a class="brand" href="./"><img src="{img}icon.png" alt="">Tidymint</a>
  <div class="navr"><div class="links">{nav}</div><a class="btn primary navcta" href="#{i["i"]}">{t["navcta"]}</a><div class="lang" role="group" aria-label="{t["aria_lang"]}"><a {vi_on}href="{vi_href}" data-l="vi">VI</a><a {en_on}href="{en_href}" data-l="en">EN</a></div></div>
</nav></div></div>
<div class="wrap">

<header class="hero">
  <h1>{t["h1"]}</h1>
  <p>{t["sub"]}</p>
  <div class="cta"><a class="btn primary" href="{DL}">{t["cta1"]} <span class="arr">→</span></a><a class="btn ghost" href="#{i["i"]}">{t["cta2"]}</a></div>
  <div class="badges">{"".join("<span>%s</span>" % b for b in t["badges"])}</div>
  <div class="shot"><img src="{img}smart.jpg" alt="{t["shot_alt"]}" width="1600" height="1084"></div>
</header>

<section>
  <span class="tag">{t["vs_tag"]}</span><h2>{t["vs_h"]}</h2>
  <div class="vs" style="margin-top:24px">
    <div class="col bad"><h3>{t["vs_bad_h"]}</h3><ul>{"".join("<li>%s</li>" % x for x in t["vs_bad"])}</ul></div>
    <div class="col good"><h3>{t["vs_good_h"]}</h3><ul>{"".join("<li>%s</li>" % x for x in t["vs_good"])}</ul></div>
  </div>
</section>

<section>
  <div class="def">
    <div><span class="tag">{t["def_tag"]}</span><h2>{t["def_h"]}</h2><p>{t["def_p"]}</p><ul>{"".join("<li>%s</li>" % x for x in t["def_li"])}</ul><p>{t["def_p2"]}</p></div>
    <img src="{img}lens.jpg" alt="Space Lens" loading="lazy" style="width:100%;height:auto;border-radius:12px;border:1px solid var(--line)">
  </div>
</section>

<section id="{i["h"]}">
  <span class="tag">{t["how_tag"]}</span><h2>{t["how_h"]}</h2>
  <div class="how" style="margin-top:24px">{how}</div>
</section>

<section id="{i["f"]}">
  <span class="tag">{t["feat_tag"]}</span><h2>{t["feat_h"]}</h2>
  <div class="grid" style="margin-top:24px">{feats}</div>
  <div class="feature" style="margin-top:48px"><img src="{img}dupes.jpg" alt="" loading="lazy"><img src="{img}cleanup.jpg" alt="" loading="lazy"></div>
</section>

<section>
  <span class="tag">{t["use_tag"]}</span><h2>{t["use_h"]}</h2>
  <div class="grid" style="grid-template-columns:repeat(auto-fit,minmax(220px,1fr));margin-top:24px">{uses}</div>
</section>

<section id="{i["q"]}">
  <h2>{t["faq_h"]}</h2>
  <div style="margin-top:20px">{faq}</div>
</section>

<section id="{i["i"]}">
  <h2>{t["inst_h"]}</h2>
  <p class="lead">{t["inst_lead"]}</p>
  <div class="note">{t["inst_note"]}</div>
  <ol class="steps">{inst}</ol>
  <p class="small">{t["inst_small"]}</p>
  <div class="signup" id="{i["s"]}" style="margin-top:36px">
    <h2 style="margin-bottom:6px">{t["sign_h"]}</h2>
    <p class="small" style="margin:0">{t["sign_p"]}</p>
    <form id="f"><input type="email" id="email" required placeholder="{t["sign_ph"]}" autocomplete="email"><button class="btn primary" type="submit">{t["sign_btn"]}</button></form>
    <div id="msg"></div>
    <p class="small">{t["consent"]}</p>
  </div>
</section>

<section style="text-align:center;padding-top:20px">
  <h2>{t["end_h"]}</h2><p class="lead" style="margin:0 auto 24px">{t["end_p"]}</p>
  <a class="btn primary" href="{DL}">{t["cta1"]} <span class="arr">→</span></a>
</section>

<div class="topbar"><a href="#top" id="toTop">↑ {t["top"]}</a></div>
<div class="fcols">
  <div><a class="brand" href="./"><img src="{img}icon.png" alt="">Tidymint</a><p>{t["f_blurb"]}</p></div>
  {fcols}
</div>
<footer><span>{t["copy"]}{t["extra_footer"]}</span></footer>
</div>
<button class="up" id="up" type="button" aria-label="{t["top"]}">↑ {t["top"]}</button>
<script>
document.querySelectorAll('.lang a').forEach(a=>a.addEventListener('click',()=>{{try{{localStorage.setItem('tm-lang',a.dataset.l)}}catch(e){{}}}}));
{redirect}(function(){{var up=document.getElementById('up'),bar=document.getElementById('toTop'),barIn=false,tick=false;
function top(e){{if(e)e.preventDefault();scrollTo({{top:0,behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'}})}}
up.addEventListener('click',top);bar.addEventListener('click',top);
function upd(){{tick=false;up.classList.toggle('show',scrollY>600&&!barIn)}}
if('IntersectionObserver' in window)new IntersectionObserver(function(es){{barIn=es[0].isIntersecting;upd()}}).observe(bar);
addEventListener('scroll',function(){{if(!tick){{tick=true;requestAnimationFrame(upd)}}}},{{passive:true}});upd();}})();
const ENDPOINT = "{ENDPOINT}";
document.getElementById('f').addEventListener('submit', async (e) => {{
  e.preventDefault();
  const email = document.getElementById('email').value.trim();
  const msg = document.getElementById('msg');
  if (!/^[^\\s@]+@[^\\s@]+\\.[^\\s@]{{2,}}$/.test(email)) {{ msg.textContent = '{m["bad"]}'; return; }}
  msg.textContent = '{m["sending"]}';
  const body = JSON.stringify({{ source: '{t["src"]}', type: 'newsletter', email, message: '', newsletter: 'yes',
    consent: '{t["consent"]}', consentVersion: '2026-10', lang: navigator.language || '' }});
  try {{
    await fetch(ENDPOINT, {{ method: 'POST', mode: 'no-cors', headers: {{ 'Content-Type': 'text/plain;charset=utf-8' }}, body }});
    msg.textContent = '{m["ok"]}'; e.target.reset();
  }} catch (err) {{ msg.textContent = '{m["err"]}'; }}
}});
</script>
</body>
</html>
'''

for k, out in (("en", "docs/index.html"), ("vi", "docs/vi/index.html")):
    with open(os.path.join(ROOT, out), "w") as f:
        f.write(page(k))
    print("wrote", out)
