#!/usr/bin/env python3
"""Generate docs/index.html (English) and docs/vi/index.html (Vietnamese) from one template.
Run from the repository root: python3 tools/site.py"""
import json, os, html
from stamp import stamp

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GH = "https://github.com/HaiTrung-Workspace/tidymint"
DL = GH + "/releases/latest/download/Tidymint.zip"
GA_ID = "G-19HEJDJPN3"
# Line icons (Lucide style, MIT): 24px grid, 1.75 stroke, currentColor. Used in feature and audience cards.
ICONS = {'byapp': '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>', 'undo': '<path d="M3 7v6h6"/><path d="M21 17a9 9 0 0 0-15-6.7L3 13"/>', 'shield': '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>', 'scan': '<path d="M9.94 15.5A2 2 0 0 0 8.5 14.06l-6.14-1.58a.5.5 0 0 1 0-.96L8.5 9.94A2 2 0 0 0 9.94 8.5l1.58-6.14a.5.5 0 0 1 .96 0l1.58 6.14a2 2 0 0 0 1.44 1.44l6.14 1.58a.5.5 0 0 1 0 .96l-6.14 1.58a2 2 0 0 0-1.44 1.44l-1.58 6.14a.5.5 0 0 1-.96 0z"/><path d="M20 3v4M22 5h-4"/>', 'dupes': '<rect x="8" y="8" width="14" height="14" rx="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>', 'lens': '<circle cx="8.5" cy="14.5" r="5.5"/><circle cx="17" cy="7.5" r="4"/><circle cx="18.5" cy="18" r="2.5"/>', 'apps': '<path d="M11 21.73a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73z"/><path d="M12 22V12M3.3 7 12 12l8.7-5"/>', 'large': '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7z"/><path d="M14 2v4a2 2 0 0 0 2 2h4M12 11v7M9 15l3 3 3-3"/>', 'menu': '<path d="m12 14 4-4"/><path d="M3.34 19a10 10 0 1 1 17.32 0"/>', 'ai': '<rect x="4" y="4" width="16" height="16" rx="2"/><rect x="9" y="9" width="6" height="6" rx="1"/><path d="M15 2v2M15 20v2M2 15h2M2 9h2M20 15h2M20 9h2M9 2v2M9 20v2"/>', 'dev': '<path d="m16 18 6-6-6-6M8 6l-6 6 6 6"/>', 'video': '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M7 3v18M17 3v18M3 12h18M3 7.5h4M3 16.5h4M17 7.5h4M17 16.5h4"/>', 'full': '<path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/>', 'drive': '<path d="M22 12H2"/><path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/><path d="M6 16h.01M10 16h.01"/>'}
def icon(k):
    return '<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">%s</svg>' % ICONS[k]
ENDPOINT = "https://script.google.com/macros/s/AKfycbz07aYQ8kI0u0OV842dt-LxeN5TedqfOzNvhmuVAPmgXdcIGtpzI-GNwLE_kiUMiGDKag/exec"
BASE_CSS = open(os.path.join(ROOT, "tools", "site.css")).read()
EXTRA_CSS = """
.topnav{position:sticky;top:0;z-index:10;background:#030c09e6;-webkit-backdrop-filter:blur(10px);backdrop-filter:blur(10px);border-bottom:1px solid #ffffff12}
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
.how{display:grid;grid-template-columns:1fr auto 1fr auto 1fr;align-items:stretch;gap:12px;counter-reset:h}.how .arr{flex:none;width:36px;height:36px;border-radius:50%;background:#2fd39f14;border:1px solid #2fd39f33;color:var(--leaf);display:flex;align-items:center;justify-content:center;justify-self:center;align-self:center}.how .arr svg{width:20px;height:20px}
.card .hd{display:flex;align-items:center;gap:12px;margin-bottom:10px}.card .hd b{margin:0;font-size:17px}
.how .card{counter-increment:h}.how .n{flex:none;width:30px;height:30px;border-radius:50%;background:var(--mint2);color:#fff;font-weight:700;display:flex;align-items:center;justify-content:center}.how .n:before{content:counter(h)}
.ico{flex:none;display:flex;align-items:center;justify-content:center;width:40px;height:40px;border-radius:10px;color:var(--leaf);background:#2fd39f14;border:1px solid #2fd39f33}.ico svg{display:block}
details{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:0 18px;margin-bottom:10px}
summary{cursor:pointer;padding:16px 0;font-weight:600;list-style:none}summary::-webkit-details-marker{display:none}summary:after{content:"+";float:right;color:var(--leaf);font-size:20px;line-height:1}details[open] summary:after{content:"−"}
details p{color:var(--sub);margin:0 0 16px}
.steps{counter-reset:s;list-style:none;padding:0;margin:0 0 20px}.steps li{counter-increment:s;position:relative;padding:14px 16px 14px 58px;margin-bottom:10px;background:var(--card);border:1px solid var(--line);border-radius:12px;color:var(--sub)}.steps li b{color:var(--text)}.steps li:before{content:counter(s);position:absolute;left:16px;top:14px;width:28px;height:28px;border-radius:50%;background:var(--mint2);color:#fff;font-weight:700;display:flex;align-items:center;justify-content:center}
.note{background:#ffb02014;border:1px solid #ffb02055;border-radius:12px;padding:14px 16px;color:var(--sub);font-size:15px;margin-bottom:20px}
.fcols{display:grid;grid-template-columns:1.4fr 1fr 1fr 1fr;gap:24px;padding:36px 0 20px;border-top:1px solid var(--line)}
.fcols h4{margin:0 0 10px;font-size:14px;color:var(--text)}.fcols .brand{display:flex;align-items:center;gap:10px;padding:0;font-size:18px;color:var(--text)}.fcols .brand:hover{text-decoration:none}.fcols a{display:block;color:var(--sub);font-size:14px;padding:3px 0}.fcols p{color:var(--sub);font-size:14px;margin:8px 0 0}
footer{border-top:0;padding:0 0 28px}
@media (max-width:820px){.vs,.def,.how,.fcols{grid-template-columns:1fr}.how .arr svg{transform:rotate(90deg)}.navcta{display:none}}

/* Hover only on things that can be clicked. Nothing moves its box on hover (moving boxes made the
   pointer slip off the edge and flicker); feedback is a glow ring, border and background change. */
.btn,.topbar a,.lang a,details,nav .links a,.fcols a{transition:box-shadow .18s ease,border-color .18s ease,background-color .18s ease,color .18s ease}
.btn:hover{filter:none}
@media (hover:hover){
 .btn.primary:hover{box-shadow:0 0 0 3px #2fd39f40,0 10px 26px #0f8f6866}
 .btn.ghost:hover{border-color:#2fd39faa;background-color:#ffffff0d}
 .topbar a:hover{border-color:#2fd39faa;background-color:#ffffff0d;box-shadow:0 0 0 3px #2fd39f26}
 details:hover{border-color:#2fd39f66}
 nav .links a:hover{color:var(--text);text-decoration:none}.fcols a:hover{color:var(--text);text-decoration:underline;text-underline-offset:3px}
footer span a{color:var(--leaf);text-decoration:underline;text-decoration-color:#ffffff40;text-underline-offset:3px}footer span a:hover{text-decoration-color:var(--leaf)}
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
.ck{position:fixed;left:16px;bottom:16px;z-index:30;max-width:380px;background:#0b2620f7;border:1px solid #2fd39f55;border-radius:14px;padding:14px 16px;box-shadow:0 12px 30px #0009;font-size:14px;color:var(--sub);display:none}
.ck.show{display:block}.ck p{margin:0 0 10px}.ck .row{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
.ck button{font:600 14px/1 inherit;font-family:inherit;padding:9px 16px;border-radius:999px;cursor:pointer;border:1px solid #ffffff33;background:transparent;color:var(--text)}
.ck button.yes{background:linear-gradient(90deg,var(--mint),var(--mint2));border:0;color:#fff}
.linkbtn{background:none;border:0;padding:0;color:var(--sub);font:inherit;cursor:pointer;text-decoration:underline}
@media (max-width:820px){.ck{left:12px;right:12px;max-width:none}}
.topnav nav{clip-path:none;box-shadow:none;background:transparent;position:static}
.mbtn{display:none;background:none;border:1px solid #ffffff33;border-radius:8px;color:var(--text);font:600 18px/1 inherit;font-family:inherit;width:38px;height:34px;cursor:pointer;align-items:center;justify-content:center}
@media (max-width:820px){.mbtn{display:inline-flex}.navr{gap:10px}
 .topnav.open nav .links{display:flex;flex-direction:column;gap:0;position:absolute;top:100%;left:0;right:0;background:#030c09;padding:6px 20px 14px;z-index:30;border-bottom:1px solid #ffffff1a;box-shadow:0 18px 30px #0008}
 .topnav.open nav .links a{padding:13px 0;border-bottom:1px solid #ffffff12;color:var(--text);font-size:16px}.topnav.open nav .links a:last-child{border-bottom:0}}
@media (prefers-reduced-motion:reduce){*{transition:none!important;scroll-behavior:auto!important}}
"""

T = {
"en": dict(
  lang="en", path="", other="vi/", title="Free App to Free Up Storage on Mac (Open Source) | Tidymint",
  desc="Free, open-source macOS disk space app. See what fills your Mac, clear caches and System Data, find duplicates, uninstall apps fully. Trash first, with Undo.",
  nav=[("#features","Features"),("#how","How it works"),("guides/","Guides"),("#faq","FAQ"),(GH,"GitHub")], navcta="Download",
  h1='Keep your Mac in <span>mint condition</span>.',
  sub="Tidymint is a free, open-source Mac cleaner. Clear caches and System Data, remove duplicate files, uninstall apps completely and see exactly what fills your disk.",
  cta1="Download free", cta2="How to install",
  badges=["✓ Free and open source (MIT)","✓ Everything goes to the Trash first","✓ Works offline, no tracking",'★ Listed in <a href="https://github.com/jaywcjlove/awesome-mac">awesome-mac</a>'],
  shot_alt="Tidymint home page after a scan: what is safe to clean, grouped and sized", byapp_alt="Clean by App showing browser caches pre-selected and chat photos by month", lens_alt="Space Lens bubble map showing which folders fill a Mac disk", dupes_alt="Tidymint duplicate file finder with the copy to keep marked", cleanup_alt="Tidymint cleanup details listing caches and logs by size", vs_more='Full comparison: <a href="cleanmymac-alternative/">free CleanMyMac alternatives</a> · Guide: <a href="clear-system-data-mac/">how to clear System Data on Mac</a>',
  vs_tag="Why Tidymint", vs_h="A cleaner you can actually trust",
  vs_bad_h="Typical paid cleaners", vs_bad=["Paid licence or subscription, major upgrades often cost extra","Closed source: you cannot see what it deletes","Cracked copies are a common way to get malware"],
  vs_good_h="Tidymint", vs_good=["Free, with no account and no subscription","Open source (MIT): anyone can read every line","Only moves items to the Trash, you empty it yourself"],
  def_tag="Good to know", def_h="What is “System Data” on a Mac?",
  def_p="In <b>System Settings › General › Storage</b>, macOS groups everything it cannot sort into a category called <b>System Data</b>. It often grows to tens of gigabytes and is hard to inspect from Finder.",
  def_li=["App and browser caches, logs and temporary files","Leftovers from apps you already deleted","Local Time Machine snapshots and old installers","For AI work: model weights and package caches"],
  def_p2="Tidymint shows which of these folders are large on your Mac, explains each one in plain words, and lets you move the safe ones to the Trash.",
  how_tag="How it works", how_h="Three steps, you stay in control",
  how=[("Scan","One click looks through caches, logs, old installers and large files. Nothing is touched yet."),("Review","Every item is grouped, sized and explained. Risky items are never pre-selected, files still used by your scripts are flagged."),("Clean","Selected items move to the Trash. Change your mind? Undo puts the last run back. Empty the Trash when you are ready.")],
  feat_tag="Features", feat_h="Everything in one small app",
  feats=[("scan","Clean Now","Scans caches, logs, npm cache and old installers, shows what it found, and cleans only when you press Clean."),("byapp","Clean by App","Chrome, Edge, CapCut and more: caches pre-selected, photos and files by month for you to pick, messages and logins locked."),("undo","Undo","Every clean is recorded. One button puts the last run back where it was while it is still in the Trash."),("dupes","Duplicates","Identical files found by content. Keeps the best copy, checks your scripts before deleting."),("lens","Space Lens","A bubble map of what fills your disk, with notes for common folders."),("apps","Uninstaller","Removes apps with their caches and leftovers. Only bundle-id matches are pre-selected; anything holding a database is left to you."),("large","Large files","Files over 100 MB, sorted by size or last opened. Never pre-selected."),("shield","Startup Items","Who signed each background item, and a flag on unusual locations or names. Facts, not verdicts.")],
  use_tag="Made for", use_h="Who fills their Mac the fastest",
  uses=[("ai","AI work","Model weights, Hugging Face and Ollama caches, generated images."),("dev","Developers","node_modules, npm and Homebrew caches, old builds."),("video","Video and photo","Exports, render drafts and duplicate assets."),("full","Full, no idea why","System Data and “Other” swell: caches, Time Machine snapshots, old iPhone backups.")],
  faq_h="Questions",
  faq=[("Is Tidymint really free?","Yes. It is open source under the MIT licence, with no account, no subscription and no paid tier."),
       ("Is it safe?","Tidymint only moves items to the Trash, and Undo puts the last clean back in one click. It never touches Photos, Mail, keychains, cloud storage roots or Apple system caches, and risky items are never pre-selected."),
       ("Why does macOS block it the first time?","Tidymint is not notarized by Apple yet (that needs a paid developer account). Open it once from System Settings › Privacy & Security › Open Anyway, as Apple describes in its own guide. The source code is public on GitHub."),
       ("Does it send my data anywhere?","No. It works offline. Data only leaves your Mac if you send feedback or join the newsletter yourself."),
       ("How is it different from CleanMyMac?","Tidymint is free and open source and focuses on cleaning and disk space. It has no scanner of its own and relies on the protection built into macOS (XProtect, Gatekeeper); CleanMyMac bundles its own and charges a subscription."),
       ("Where do I download it safely?","Only from tidymint.app or the GitHub releases page. Tidymint has no other website, no app store listing and no paid version. Anything else is not us."),
       ("Which Macs are supported?","macOS 14 or later, on both Apple silicon and Intel."),
       ("Is there a Windows or iPhone version?","No. iOS does not allow apps to clean other apps' data, and Windows is not planned for now.")],
  inst_h="Install", inst_lead="macOS 14 or later, Apple silicon and Intel.",
  inst_note="Tidymint is not notarized by Apple yet, so macOS blocks the first launch. This happens to every app that is not notarized. The source code is public on GitHub. Notarization needs an Apple Developer account (99 USD a year); <a href=\"https://github.com/sponsors/HaiTrung-Workspace\">GitHub Sponsors</a> is where that is being collected.",
  inst=['<b>Download</b> <a href="%s">Tidymint.zip</a>, open it and drag <b>Tidymint</b> to <b>Applications</b>.' % DL,
        '<b>First launch:</b> double-click Tidymint. When macOS says it cannot be opened, click <b>Done</b>.',
        '<b>Allow it:</b> open <b>System Settings › Privacy &amp; Security</b>, scroll to the <b>Security</b> heading (halfway down) and click <b>Open Anyway</b>, then confirm with your password. <a href="install/">Step-by-step guide with screenshots</a>.',
        '<b>Full Disk Access</b> (optional): in Privacy &amp; Security, open <b>Full Disk Access</b> and turn on Tidymint, so Mail, Messages and Library are measured too. <a href="install/#s6">How</a>.'],
  inst_small='Steps from Apple: <a href="https://support.apple.com/102445">Safely open apps on your Mac</a>. Source code and build steps are on <a href="%s">GitHub</a>.' % GH,
  sign_h="Get updates", sign_p="Mac tips and new releases, at most one email a month.", sign_ph="name@example.com", sign_btn="Subscribe",
  consent="Get the latest updates. Unsubscribe any time.",
  end_h="Ready to tidy up?", end_p="Free, open source, and everything goes to the Trash first.",
  f_blurb="Free, open-source Mac cleaner. Provided as is, without warranty. Official site: tidymint.app, downloads only from GitHub.",
  f_cols=[("Product",[("#features","Features"),("#how","How it works"),("#install","Install"),("changelog/","Changelog"),(GH+"/releases","Releases"),("https://github.com/sponsors/HaiTrung-Workspace","Sponsor")]),
          ("Guides",[("install/","Install step by step"),("clear-system-data-mac/","Clear System Data"),("free-up-space-mac/","Free up space on Mac"),("cleanmymac-alternative/","CleanMyMac alternative"),(GH+"/issues","Report a bug")]),
          ("Legal",[(GH+"/blob/main/PRIVACY.md","Privacy"),(GH+"/blob/main/LICENSE","MIT License"),("mailto:hello@tidymint.app","hello@tidymint.app")])],
  copy="© 2026 Tidymint", extra_footer="",
  msg=dict(bad="Please enter a valid email.",sending="Sending...",ok="Thanks! You are on the list.",err="Could not send right now. Please try again later."),
  src="website", img="", shot="", aria_lang="Language", top="Back to top",
  ck_text="This website uses Google Analytics cookies to count visits. The Tidymint app itself tracks nothing.", ck_yes="Accept", ck_no="Decline", ck_link="Cookie settings", ck_more="Privacy"),
"vi": dict(
  lang="vi", path="vi/", other="../", title="Dọn dẹp MacBook miễn phí, thay CleanMyMac | Tidymint",
  desc="Dọn dẹp MacBook miễn phí: xoá bộ nhớ đệm, gọn Dữ liệu hệ thống, gỡ ứng dụng sạch, tìm file trùng. Mã nguồn mở, tiếng Việt, mọi thứ vào Thùng rác trước.",
  nav=[("#tinh-nang","Tính năng"),("#cach-dung","Cách dùng"),("huong-dan/","Hướng dẫn"),("#hoi-dap","Hỏi đáp"),(GH,"GitHub")], navcta="Tải về",
  h1='Giữ MacBook <span>luôn như mới</span>.',
  sub="Tidymint giúp bạn dọn dẹp MacBook an toàn và miễn phí: xoá bộ nhớ đệm, gọn Dữ liệu hệ thống, gỡ ứng dụng sạch sẽ, tìm file trùng và biết chính xác cái gì đang chiếm ổ.",
  cta1="Tải miễn phí", cta2="Hướng dẫn cài",
  badges=["✓ Miễn phí, mã nguồn mở (MIT)","✓ Chỉ chuyển vào Thùng rác","✓ Chạy không cần mạng, không theo dõi",'★ Có trong danh sách <a href="https://github.com/jaywcjlove/awesome-mac">awesome-mac</a>'],
  shot_alt="Trang đầu Tidymint sau khi quét: phần an toàn để dọn, chia nhóm và ghi dung lượng", byapp_alt="Dọn theo ứng dụng: bộ nhớ đệm Zalo chọn sẵn, ảnh tin nhắn xếp theo tháng", lens_alt="Bản đồ bong bóng cho thấy thư mục nào chiếm ổ MacBook", dupes_alt="Tìm file trùng trên MacBook, đánh dấu bản giữ lại", cleanup_alt="Chi tiết dọn dẹp: bộ nhớ đệm và nhật ký xếp theo dung lượng", vs_more='So sánh chi tiết: <a href="cleanmymac-mien-phi/">CleanMyMac miễn phí? Lựa chọn hợp pháp</a> · Hướng dẫn: <a href="xoa-ung-dung-macbook/">cách xóa ứng dụng trên MacBook sạch hoàn toàn</a>',
  vs_tag="Vì sao chọn Tidymint", vs_h="App dọn dẹp bạn tin được",
  vs_bad_h="App dọn dẹp trả phí thường gặp", vs_bad=["Trả tiền bản quyền hoặc thuê bao, lên đời bản lớn thường tốn thêm","Mã nguồn đóng: không biết app xoá những gì","Bản crack là đường lây mã độc rất phổ biến"],
  vs_good_h="Tidymint", vs_good=["Miễn phí, không cần tài khoản, không thuê bao","Mã nguồn mở (MIT): ai cũng đọc được từng dòng","Chỉ chuyển vào Thùng rác, bạn tự đổ"],
  def_tag="Nên biết", def_h="“Dữ liệu hệ thống” trên Mac là gì?",
  def_p="Trong <b>Cài đặt hệ thống › Cài đặt chung › Dung lượng</b>, macOS gom mọi thứ không xếp được vào mục <b>Dữ liệu hệ thống</b> (System Data). Mục này hay phình lên hàng chục GB và khó xem bằng Finder.",
  def_li=["Bộ nhớ đệm, nhật ký, file tạm của app và trình duyệt","Phần sót lại của app đã xoá","Bản chụp Time Machine trên máy và file cài đặt cũ","Với người làm AI: file model và bộ nhớ đệm thư viện"],
  def_p2="Tidymint chỉ ra thư mục nào đang lớn trên máy bạn, giải thích từng thư mục bằng lời dễ hiểu, và cho bạn chuyển các mục an toàn vào Thùng rác.",
  how_tag="Cách dùng", how_h="Ba bước, bạn luôn là người quyết",
  how=[("Quét","Một cú bấm xem qua bộ nhớ đệm, nhật ký, file cài đặt cũ và file lớn. Chưa động vào gì."),("Xem lại","Từng mục được chia nhóm, ghi dung lượng và giải thích. Mục rủi ro không bao giờ chọn sẵn, file còn được script dùng sẽ được đánh dấu."),("Dọn","Mục đã chọn chuyển vào Thùng rác. Đổi ý thì bấm Hoàn tác. Xem lại rồi tự đổ Thùng rác khi sẵn sàng.")],
  feat_tag="Tính năng", feat_h="Đủ cả trong một app nhỏ",
  feats=[("scan","Dọn ngay","Quét bộ nhớ đệm, nhật ký, npm cache, file cài đặt cũ, cho xem tìm được gì, và chỉ dọn khi bạn bấm Dọn."),("byapp","Dọn theo ứng dụng","Zalo, Chrome, Edge, Cốc Cốc, CapCut: bộ nhớ đệm chọn sẵn, ảnh và file xếp theo tháng để bạn tự chọn, tin nhắn và đăng nhập bị khoá."),("undo","Hoàn tác","Mỗi lần dọn đều được ghi lại. Một nút trả mọi thứ về chỗ cũ khi còn trong Thùng rác."),("dupes","File trùng","Tìm theo nội dung. Giữ bản tốt nhất, kiểm tra script trước khi xoá."),("lens","Bản đồ ổ đĩa","Bong bóng cho thấy cái gì chiếm ổ, kèm giải thích thư mục hay gặp."),("apps","Gỡ app","Gỡ app cùng bộ nhớ đệm và phần sót lại. Chỉ chọn sẵn phần khớp bundle id; có database bên trong thì để bạn quyết."),("large","File lớn","File trên 100 MB, xếp theo dung lượng hoặc lần mở cuối. Không chọn sẵn."),("shield","Khởi động cùng máy","Ai đã ký từng mục chạy ngầm, đánh dấu vị trí hoặc tên bất thường. Nêu sự thật, không phán xét.")],
  use_tag="Dành cho", use_h="Ai hay đầy ổ nhất",
  uses=[("ai","Người làm AI","File model, bộ nhớ đệm Hugging Face, Ollama, ảnh tạo bằng AI."),("dev","Lập trình viên","node_modules, npm, Homebrew, bản build cũ."),("video","Làm video, ảnh","File xuất, bản nháp render, ảnh trùng."),("full","Đầy ổ, không rõ vì sao","Dữ liệu hệ thống và “Khác” phình to: bộ nhớ đệm, snapshot Time Machine, sao lưu iPhone cũ.")],
  faq_h="Hỏi đáp",
  faq=[("Tidymint có miễn phí thật không?","Có. App mã nguồn mở theo giấy phép MIT, không tài khoản, không thuê bao, không có bản trả phí."),
       ("Có an toàn không?","Tidymint chỉ chuyển vào Thùng rác, và nút Hoàn tác trả lại cả lần dọn vừa rồi bằng một cú bấm. App không bao giờ động tới Ảnh, Mail, mật khẩu, thư mục đám mây hay bộ nhớ đệm hệ thống của Apple, và mục rủi ro không bao giờ chọn sẵn."),
       ("Sao lần đầu macOS lại chặn?","Tidymint chưa được Apple công chứng (cần tài khoản nhà phát triển trả phí). Mở một lần qua Cài đặt hệ thống › Quyền riêng tư & Bảo mật › Vẫn mở, đúng như hướng dẫn của Apple. Mã nguồn công khai trên GitHub."),
       ("App có gửi dữ liệu của tôi đi không?","Không. App chạy không cần mạng. Dữ liệu chỉ rời máy khi bạn tự gửi góp ý hoặc đăng ký bản tin."),
       ("Khác gì CleanMyMac?","Tidymint miễn phí, mã nguồn mở, tập trung vào dọn dẹp và dung lượng ổ. App không có bộ quét riêng mà dựa vào lớp bảo vệ sẵn của macOS (XProtect, Gatekeeper); CleanMyMac có bộ quét riêng và thu phí thuê bao."),
       ("Tải ở đâu cho an toàn?","Chỉ tải từ tidymint.app hoặc trang phát hành trên GitHub. Tidymint không có trang web nào khác, không có bản trả phí. Thấy ở chỗ khác thì không phải của chúng tôi."),
       ("Chạy trên máy nào?","macOS 14 trở lên, cả máy chip Apple lẫn máy Intel."),
       ("Có bản Windows hay iPhone không?","Không. iOS không cho app dọn dữ liệu của app khác, còn Windows hiện chưa có kế hoạch.")],
  inst_h="Cài đặt", inst_lead="Cần macOS 14 trở lên, chạy được cả máy chip Apple và máy Intel.",
  inst_note="Tidymint chưa được Apple công chứng (tài khoản nhà phát triển Apple tốn 99 USD/năm, app miễn phí nên chưa mua). Vì vậy lần đầu mở, macOS sẽ chặn. Đây là cảnh báo chung cho mọi app chưa công chứng. Mã nguồn công khai trên GitHub để ai cũng kiểm tra được. Ai muốn góp cho tài khoản nhà phát triển thì có <a href=\"https://github.com/sponsors/HaiTrung-Workspace\">GitHub Sponsors</a>.",
  inst=['<b>Tải về:</b> bấm <a href="%s">Tải Tidymint</a>, mở file <b>Tidymint.zip</b> trong Downloads, kéo <b>Tidymint</b> vào thư mục <b>Ứng dụng</b> (Applications).' % DL,
        '<b>Mở lần đầu:</b> nhấp đúp Tidymint. macOS báo không mở được, bấm <b>Xong</b> (Done). Đừng chọn Chuyển vào Thùng rác.',
        '<b>Cho phép mở:</b> vào <b>Cài đặt hệ thống › Quyền riêng tư &amp; Bảo mật</b>, kéo tới mục <b>Bảo mật</b> (giữa trang), bấm <b>Vẫn mở</b> (Open Anyway) rồi xác nhận bằng mật khẩu máy. <a href="cai-dat/">Hướng dẫn từng bước có ảnh</a>.',
        '<b>Truy cập toàn bộ ổ đĩa</b> (không bắt buộc): trong Quyền riêng tư &amp; Bảo mật, mở <b>Truy cập toàn bộ ổ đĩa</b> và bật Tidymint để quét được cả Mail, Tin nhắn, Library. <a href="cai-dat/#b6">Xem cách làm</a>.'],
  inst_small='Các bước mở app chưa công chứng theo hướng dẫn chính thức của Apple: <a href="https://support.apple.com/102445">Mở app an toàn trên máy Mac</a>. Mã nguồn công khai trên <a href="%s">GitHub</a>.' % GH,
  sign_h="Nhận tin khi có bản mới", sign_p="Mẹo giữ máy gọn và thông báo phiên bản mới, mỗi tháng tối đa một thư.", sign_ph="ten@example.com", sign_btn="Đăng ký",
  consent="Nhận thông tin cập nhật mới nhất. Huỷ bất kỳ lúc nào.",
  end_h="Dọn máy thôi?", end_p="Miễn phí, mã nguồn mở, mọi thứ vào Thùng rác trước.",
  f_blurb="Ứng dụng dọn dẹp MacBook miễn phí, mã nguồn mở. Cung cấp nguyên trạng, không bảo hành. Trang chính thức duy nhất: tidymint.app, tải chỉ từ GitHub.",
  f_cols=[("Sản phẩm",[("#tinh-nang","Tính năng"),("#cach-dung","Cách dùng"),("#cai-dat","Cài đặt"),("lich-su-cap-nhat/","Lịch sử cập nhật"),(GH+"/releases","Các phiên bản"),("https://github.com/sponsors/HaiTrung-Workspace","Ủng hộ dự án")]),
          ("Hướng dẫn",[("cai-dat/","Cài đặt từng bước"),("cleanmymac-mien-phi/","CleanMyMac miễn phí?"),("zalo-chiem-dung-luong-macbook/","Zalo chiếm dung lượng"),("xoa-ung-dung-macbook/","Xóa ứng dụng trên MacBook"),(GH,"Mã nguồn"),(GH+"/issues","Báo lỗi")]),
          ("Pháp lý",[(GH+"/blob/main/PRIVACY.md","Quyền riêng tư"),(GH+"/blob/main/LICENSE","Giấy phép MIT"),("mailto:hello@tidymint.app","hello@tidymint.app")])],
  copy="© 2026 Tidymint", extra_footer=' · Cùng tác giả: <a href="https://concao.org/?utm_source=tidymint&amp;utm_medium=web&amp;utm_campaign=footer">Cồn Cào</a>',
  msg=dict(bad="Email chưa đúng.",sending="Đang gửi...",ok="Cảm ơn bạn! Đã đăng ký.",err="Chưa gửi được, bạn thử lại sau nhé."),
  src="website-vi", img="../", shot="", aria_lang="Ngôn ngữ", top="Lên đầu trang",
  ck_text="Website dùng cookie Google Analytics để đếm lượt truy cập. Bản thân app Tidymint không theo dõi gì.", ck_yes="Đồng ý", ck_no="Từ chối", ck_link="Cài đặt cookie", ck_more="Quyền riêng tư"),
}
IDS = {"en": dict(f="features", h="how", q="faq", i="install", s="signup"),
       "vi": dict(f="tinh-nang", h="cach-dung", q="hoi-dap", i="cai-dat", s="dang-ky")}

def page(k):
    t = T[k]; i = IDS[k]; img = t["img"]; shot = t["shot"]
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
    feats = "".join('<div class="card"><div class="hd"><span class="ico">%s</span><b>%s</b></div><span>%s</span></div>' % (icon(k), h, d) for k, h, d in t["feats"])
    uses = "".join('<div class="card"><div class="hd"><span class="ico">%s</span><b>%s</b></div><span>%s</span></div>' % (icon(k), h, d) for k, h, d in t["uses"])
    arr = '<span class="arr" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"/><path d="m13 6 6 6-6 6"/></svg></span>'
    how = arr.join('<div class="card"><div class="hd"><span class="n"></span><b>%s</b></div><span>%s</span></div>' % h for h in t["how"])
    faq = "".join('<details><summary>%s</summary><p>%s</p></details>' % (html.escape(q), html.escape(a)) for q, a in t["faq"])
    inst = "".join("<li>%s</li>" % s.replace("{img}", img) for s in t["inst"])
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
<link rel="apple-touch-icon" href="{img}apple-touch-icon.png">
<meta property="og:title" content="{t["title"]}">
<meta property="og:description" content="{t["desc"]}">
<meta property="og:image" content="https://tidymint.app/{"vi/" if k == "vi" else ""}smart.jpg">
<meta property="og:url" content="{url}">
<meta name="twitter:card" content="summary_large_image">
<script>
window.dataLayer=window.dataLayer||[];function gtag(){{dataLayer.push(arguments)}}
var tmC=null;try{{tmC=localStorage.getItem('tm-consent');var nt=new URLSearchParams(location.search).get('notrack');if(nt==='1')localStorage.setItem('tm-notrack','1');if(nt==='0')localStorage.removeItem('tm-notrack');if(localStorage.getItem('tm-notrack')==='1')window['ga-disable-{GA_ID}']=true}}catch(e){{}}
gtag('consent','default',{{ad_storage:'denied',ad_user_data:'denied',ad_personalization:'denied',analytics_storage:tmC==='yes'?'granted':'denied',wait_for_update:500}});
gtag('js',new Date());gtag('config','{GA_ID}');
</script>
<script async src="https://www.googletagmanager.com/gtag/js?id={GA_ID}"></script>
<script type="application/ld+json">{json.dumps(ld, ensure_ascii=False)}</script>
<style>{BASE_CSS}{EXTRA_CSS}</style>
</head>
<body id="top">
<div class="topnav"><div class="wrap"><nav>
  <a class="brand" href="./"><img src="{img}icon.png" alt=""><span>Tidy<span class="mint">mint</span></span></a>
  <div class="navr"><div class="links">{nav}</div><a class="btn primary navcta" href="#{i["i"]}">{t["navcta"]}</a><div class="lang" role="group" aria-label="{t["aria_lang"]}"><a {vi_on}href="{vi_href}" data-l="vi">VI</a><a {en_on}href="{en_href}" data-l="en">EN</a></div><button class="mbtn" id="mbtn" type="button" aria-label="Menu" aria-expanded="false">☰</button></div>
</nav></div></div>
<div class="wrap">

<header class="hero">
  <h1>{t["h1"]}</h1>
  <p>{t["sub"]}</p>
  <div class="cta"><a class="btn primary" href="{DL}">{t["cta1"]} <span class="arr">→</span></a><a class="btn ghost" href="#{i["i"]}">{t["cta2"]}</a></div>
  <div class="badges">{"".join("<span>%s</span>" % b for b in t["badges"])}</div>
  <div class="shot"><img src="{shot}smart.jpg" alt="{t["shot_alt"]}" width="1600" height="1013"></div>
</header>

<section>
  <span class="tag">{t["vs_tag"]}</span><h2>{t["vs_h"]}</h2>
  <div class="vs" style="margin-top:24px">
    <div class="col bad"><h3>{t["vs_bad_h"]}</h3><ul>{"".join("<li>%s</li>" % x for x in t["vs_bad"])}</ul></div>
    <div class="col good"><h3>{t["vs_good_h"]}</h3><ul>{"".join("<li>%s</li>" % x for x in t["vs_good"])}</ul></div>
  </div>
  <p class="small" style="margin-top:14px">{t["vs_more"]}</p>
</section>

<section>
  <div class="def">
    <div><span class="tag">{t["def_tag"]}</span><h2>{t["def_h"]}</h2><p>{t["def_p"]}</p><ul>{"".join("<li>%s</li>" % x for x in t["def_li"])}</ul><p>{t["def_p2"]}</p></div>
    <img src="{shot}lens.jpg" alt="{t["lens_alt"]}" loading="lazy" style="width:100%;height:auto;border-radius:12px;border:1px solid var(--line)">
  </div>
</section>

<section id="{i["h"]}">
  <span class="tag">{t["how_tag"]}</span><h2>{t["how_h"]}</h2>
  <div class="how" style="margin-top:24px">{how}</div>
</section>

<section id="{i["f"]}">
  <span class="tag">{t["feat_tag"]}</span><h2>{t["feat_h"]}</h2>
  <div class="grid" style="margin-top:24px">{feats}</div>
  <div class="feature" style="margin-top:48px"><img src="{shot}byapp.jpg" alt="{t["byapp_alt"]}" loading="lazy" width="1600" height="1013"><img src="{shot}dupes.jpg" alt="{t["dupes_alt"]}" loading="lazy" width="1600" height="1013"></div>
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
  <div><a class="brand" href="./"><img src="{img}icon.png" alt=""><span>Tidy<span class="mint">mint</span></span></a><p>{t["f_blurb"]}</p></div>
  {fcols}
</div>
<footer><span>{t["copy"]}{t["extra_footer"]} · <button class="linkbtn" id="ckOpen" type="button">{t["ck_link"]}</button></span></footer>
</div>
<button class="up" id="up" type="button" aria-label="{t["top"]}">↑ {t["top"]}</button>
<div class="ck" id="ck" role="dialog" aria-live="polite"><p>{t["ck_text"]} <a href="{GH}/blob/main/PRIVACY.md">{t["ck_more"]}</a></p><div class="row"><button class="yes" id="ckY" type="button">{t["ck_yes"]}</button><button id="ckN" type="button">{t["ck_no"]}</button></div></div>
<script>
(function(){{var b=document.getElementById('mbtn'),n=document.querySelector('.topnav');function close(){{n.classList.remove('open');b.setAttribute('aria-expanded',false);b.textContent='☰'}}b.addEventListener('click',function(e){{e.stopPropagation();var o=n.classList.toggle('open');b.setAttribute('aria-expanded',o);b.textContent=o?'✕':'☰'}});n.querySelectorAll('.links a').forEach(function(a){{a.addEventListener('click',close)}});document.addEventListener('click',function(e){{if(n.classList.contains('open')&&!n.contains(e.target))close()}});document.addEventListener('keydown',function(e){{if(e.key==='Escape'&&n.classList.contains('open')){{close();b.focus()}}}})}})();
document.querySelectorAll('.lang a').forEach(a=>a.addEventListener('click',()=>{{try{{localStorage.setItem('tm-lang',a.dataset.l)}}catch(e){{}}}}));
{redirect}(function(){{var up=document.getElementById('up'),bar=document.getElementById('toTop'),barIn=false,tick=false;
function top(e){{if(e)e.preventDefault();scrollTo({{top:0,behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'}})}}
up.addEventListener('click',top);bar.addEventListener('click',top);
function upd(){{tick=false;up.classList.toggle('show',scrollY>600&&!barIn)}}
if('IntersectionObserver' in window)new IntersectionObserver(function(es){{barIn=es[0].isIntersecting;upd()}}).observe(bar);
addEventListener('scroll',function(){{if(!tick){{tick=true;requestAnimationFrame(upd)}}}},{{passive:true}});upd();}})();
(function(){{var ck=document.getElementById('ck'),up=document.getElementById('up');
function show(v){{ck.classList.toggle('show',v)}}
function set(v){{try{{localStorage.setItem('tm-consent',v)}}catch(e){{}};gtag('consent','update',{{analytics_storage:v==='yes'?'granted':'denied'}});show(false)}}
document.getElementById('ckY').onclick=function(){{set('yes')}};document.getElementById('ckN').onclick=function(){{set('no')}};
document.getElementById('ckOpen').onclick=function(){{show(true)}};
if(!tmC)show(true);
document.querySelectorAll('a[href*="releases/latest/download"]').forEach(function(a){{a.addEventListener('click',function(){{gtag('event','download_click',{{link_url:a.href,page_lang:document.documentElement.lang}})}})}});}})();
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

if __name__ == "__main__":
    for k, out in (("en", "docs/index.html"), ("vi", "docs/vi/index.html")):
        with open(os.path.join(ROOT, out), "w") as f:
            f.write(stamp(page(k), os.path.join(ROOT, out), ROOT))
        print("wrote", out)
