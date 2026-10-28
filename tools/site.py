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
ICONS = {'byapp': '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>', 'undo': '<path d="M3 7v6h6"/><path d="M21 17a9 9 0 0 0-15-6.7L3 13"/>', 'shield': '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>', 'scan': '<path d="M9.94 15.5A2 2 0 0 0 8.5 14.06l-6.14-1.58a.5.5 0 0 1 0-.96L8.5 9.94A2 2 0 0 0 9.94 8.5l1.58-6.14a.5.5 0 0 1 .96 0l1.58 6.14a2 2 0 0 0 1.44 1.44l6.14 1.58a.5.5 0 0 1 0 .96l-6.14 1.58a2 2 0 0 0-1.44 1.44l-1.58 6.14a.5.5 0 0 1-.96 0z"/><path d="M20 3v4M22 5h-4"/>', 'dupes': '<rect x="8" y="8" width="14" height="14" rx="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>', 'lens': '<circle cx="8.5" cy="14.5" r="5.5"/><circle cx="17" cy="7.5" r="4"/><circle cx="18.5" cy="18" r="2.5"/>', 'apps': '<path d="M11 21.73a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73z"/><path d="M12 22V12M3.3 7 12 12l8.7-5"/>', 'large': '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7z"/><path d="M14 2v4a2 2 0 0 0 2 2h4M12 11v7M9 15l3 3 3-3"/>', 'menu': '<path d="m12 14 4-4"/><path d="M3.34 19a10 10 0 1 1 17.32 0"/>', 'ai': '<rect x="4" y="4" width="16" height="16" rx="2"/><rect x="9" y="9" width="6" height="6" rx="1"/><path d="M15 2v2M15 20v2M2 15h2M2 9h2M20 15h2M20 9h2M9 2v2M9 20v2"/>', 'dev': '<path d="m16 18 6-6-6-6M8 6l-6 6 6 6"/>', 'video': '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M7 3v18M17 3v18M3 12h18M3 7.5h4M3 16.5h4M17 7.5h4M17 16.5h4"/>', 'full': '<path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/>', 'check': '<path d="M20 6 9 17l-5-5"/>', 'arrow': '<path d="M5 12h14"/><path d="m13 6 6 6-6 6"/>', 'bug': '<circle cx="12" cy="12" r="9"/><path d="M12 8v4M12 16h.01"/>', 'drive': '<path d="M22 12H2"/><path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/><path d="M6 16h.01M10 16h.01"/>'}
def icon(k, size=22):
    return '<svg viewBox="0 0 24 24" width="%d" height="%d" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">%s</svg>' % (size, size, ICONS[k])
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
.how{display:grid;grid-template-columns:1fr auto 1fr auto 1fr;align-items:stretch;gap:12px;counter-reset:h}.how .arr{flex:none;width:36px;height:36px;background:none;border:0;color:var(--leaf);opacity:.75;display:flex;align-items:center;justify-content:center;justify-self:center;align-self:center}.how .arr svg{width:20px;height:20px}
.card .hd{display:flex;align-items:center;gap:12px;margin-bottom:10px}.card .hd b{margin:0;font-size:17px}
.how .card{counter-increment:h}.how .hd{display:block;margin-bottom:4px}.how .n{display:block;font-size:34px;font-weight:800;line-height:1;color:#2fd39f44;margin-bottom:6px;letter-spacing:-1px}.how .n:before{content:"0" counter(h)}.how .hd b{font-size:18px}
.ico{flex:none;display:flex;align-items:center;justify-content:center;width:40px;height:40px;border-radius:10px;color:var(--leaf);background:#2fd39f14;border:1px solid #2fd39f33}.ico svg{display:block}
details{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:0 18px;margin-bottom:10px}
summary{cursor:pointer;padding:16px 0;font-weight:600;list-style:none}summary::-webkit-details-marker{display:none}summary:after{content:"+";float:right;color:var(--leaf);font-size:20px;line-height:1}details[open] summary:after{content:"−"}
details p{color:var(--sub);margin:0 0 16px}
.ins{display:grid;grid-template-columns:340px 1fr;gap:48px;align-items:start}.tl{list-style:none;margin:0;padding:0;position:relative}.tl:before{content:"";position:absolute;left:19px;top:20px;bottom:20px;width:2px;background:var(--line)}.tl li{position:relative;padding:0 0 28px 60px;color:var(--sub)}.tl li:last-child{padding-bottom:0}.tl .n{position:absolute;left:4px;top:0;width:32px;height:32px;border-radius:50%;background:var(--mint2);color:#fff;font-weight:700;display:flex;align-items:center;justify-content:center}.tl h4{margin:4px 0 4px;font-size:18px;color:var(--text)}.tl p{margin:0}.tl b{color:var(--text)}.opt{font-size:13px;color:var(--sub);border:1px solid var(--line);border-radius:999px;padding:1px 8px;margin-left:8px;font-weight:500;vertical-align:middle}
.steps{counter-reset:s;list-style:none;padding:0;margin:0 0 20px}.steps li{counter-increment:s;position:relative;padding:14px 16px 14px 58px;margin-bottom:10px;background:var(--card);border:1px solid var(--line);border-radius:12px;color:var(--sub)}.steps li b{color:var(--text)}.steps li:before{content:counter(s);position:absolute;left:16px;top:14px;width:28px;height:28px;border-radius:50%;background:var(--mint2);color:#fff;font-weight:700;display:flex;align-items:center;justify-content:center}
.note{background:#ffb02014;border:1px solid #ffb02055;border-radius:12px;padding:14px 16px;color:var(--sub);font-size:15px;margin-bottom:20px}
.fcols{display:grid;grid-template-columns:1.4fr 1fr 1fr 1fr;gap:24px;padding:36px 0 20px;border-top:1px solid var(--line)}
.fcols h4{margin:0 0 10px;font-size:14px;color:var(--text)}.fcols .brand{display:flex;align-items:center;gap:10px;padding:0;font-size:18px;color:var(--text)}.fcols .brand:hover{text-decoration:none}.fcols a{display:block;color:var(--sub);font-size:14px;padding:3px 0}.fcols p{color:var(--sub);font-size:14px;margin:8px 0 0}
footer{border-top:0;padding:0 0 28px}
@media (max-width:820px){.def,.fcols{grid-template-columns:1fr}.ins{grid-template-columns:1fr;gap:24px}.grid{grid-template-columns:repeat(3,1fr);gap:10px}.grid.uses{grid-template-columns:1fr 1fr}.grid .card{padding:14px}.grid .card span{font-size:14px}.grid .card .hd b{font-size:15px}.vs{gap:12px}.vs .col{padding:18px}.vs h3{font-size:18px}.how{gap:8px}.how .arr{width:26px;height:26px}.how .arr svg{width:14px;height:14px}.how .card{padding:16px}.how .card>span{font-size:14px}.how .n{font-size:30px}.navcta{display:none}}
@media (max-width:600px){.vs,.how,.grid,.grid.uses{grid-template-columns:1fr}.how .arr svg{transform:rotate(90deg)}#how,#cach-dung{text-align:center}.how{justify-items:center}.how .card{text-align:center;width:100%;max-width:260px;padding:18px 20px}.how .card .hd{margin-bottom:4px}.how .card>span{text-wrap:balance;display:block}.how .arr{width:30px;height:30px}.how .arr svg{width:16px;height:16px}#features .grid,#tinh-nang .grid{gap:0;border-top:1px solid var(--line)}#features .grid .card,#tinh-nang .grid .card{display:grid;grid-template-columns:36px 1fr;column-gap:12px;row-gap:2px;background:none;border:0;border-bottom:1px solid var(--line);border-radius:0;padding:12px 0}#features .grid .card .hd,#tinh-nang .grid .card .hd{display:contents}#features .grid .card .ico,#tinh-nang .grid .card .ico{width:36px;height:36px;grid-row:1/3;align-self:center}#features .grid .card .hd b,#tinh-nang .grid .card .hd b{align-self:center;font-size:15px}#features .grid .card>span,#tinh-nang .grid .card>span{grid-column:2;font-size:13.5px;line-height:1.4}}

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
.arr{display:inline-block;transition:transform .18s ease}a:hover .arr{transform:translateY(3px)}a:hover .arr.r{transform:translateX(4px)}
.topbar{text-align:center;padding:8px 0 28px}
.topbar a{display:inline-flex;align-items:center;gap:8px;padding:10px 20px;border-radius:999px;border:1px solid #ffffff33;color:var(--text);font-size:14px;font-weight:600}
.topbar a:hover{text-decoration:none}
.up{position:fixed;left:50%;bottom:22px;transform:translate(-50%,90px);opacity:0;pointer-events:none;z-index:20;display:inline-flex;align-items:center;justify-content:center;width:44px;height:44px;padding:0;border-radius:50%;border:1px solid #2fd39f66;background:#0b2620f2;color:var(--text);font-family:inherit;font-size:18px;font-weight:600;box-shadow:0 12px 30px #0008;cursor:pointer;transition:transform .25s ease,opacity .25s ease,box-shadow .18s ease,border-color .18s ease}
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

HOME_CSS = """
/* Homepage long-form layout (10/2026). Homepage only: guides use EXTRA_CSS. */
.hero{padding:72px 0 8px}
.hero .eyebrow{display:inline-flex;align-items:center;gap:8px;font-size:13px;font-weight:600;color:var(--leaf);background:#2fd39f14;border:1px solid #2fd39f40;border-radius:999px;padding:5px 12px;margin-bottom:22px}
.hero .eyebrow i{width:7px;height:7px;border-radius:50%;background:var(--leaf);box-shadow:0 0 10px var(--leaf)}
.hero h1{font-size:clamp(38px,6.4vw,72px)}
.btn.lg{padding:16px 30px;font-size:17px}
.micro{margin-top:14px;font-size:13px;color:var(--sub)}
.trust{display:grid;grid-template-columns:repeat(5,1fr);gap:12px;margin:44px auto 0;max-width:1040px}
.trust div{display:flex;flex-direction:column;align-items:center;gap:8px;text-align:center;padding:16px 10px;border-radius:14px;background:#ffffff06;border:1px solid var(--line);font-size:14px;color:var(--sub)}
.trust b{color:var(--text);font-size:15px}
.trust .ico{width:38px;height:38px}
.shot{position:relative}
.shot:before{content:"";position:absolute;inset:8% 10% -4%;background:radial-gradient(closest-side,#2fd39f55,transparent);filter:blur(40px);z-index:-1}
.stats{display:grid;grid-template-columns:repeat(3,1fr);gap:16px}
.stat{padding:26px 24px;border-radius:18px;background:linear-gradient(160deg,#145c4740,#0c231c99);border:1px solid var(--line)}
.stat .big{display:block;font-size:clamp(34px,4.5vw,48px);font-weight:800;letter-spacing:-.02em;line-height:1;background:linear-gradient(90deg,var(--leaf),var(--mint));-webkit-background-clip:text;background-clip:text;color:transparent;margin-bottom:10px}
.stat b{display:block;margin-bottom:4px}.stat span{color:var(--sub);font-size:15px}
.sechead{text-align:center;max-width:720px;margin:0 auto 48px}.sechead .lead{margin:0 auto}
.fx{display:grid;grid-template-columns:1fr 1.25fr;gap:56px;align-items:center;padding:44px 0;border-top:1px solid #ffffff0d}
.fx:first-of-type{border-top:0}
.fx.flip .fx-t{order:2}
.fx .ico{width:46px;height:46px;border-radius:12px;margin-bottom:16px}
.fx h3{font-size:clamp(24px,2.8vw,32px);line-height:1.15;letter-spacing:-.01em;margin:0 0 12px}
.fx p{color:var(--sub);margin:0 0 16px;font-size:17px}
.fx ul{list-style:none;padding:0;margin:0 0 18px}.fx li{display:flex;gap:10px;align-items:flex-start;color:var(--sub);padding:5px 0}.fx li svg{flex:none;margin-top:4px;color:var(--leaf)}
.fx .more{font-weight:600;font-size:15px}
.fx-i{position:relative}
.fx-i img{width:100%;height:auto;border-radius:16px;border:1px solid var(--line);box-shadow:0 30px 70px #000a}
.fx-i:before{content:"";position:absolute;inset:10%;background:radial-gradient(closest-side,#2fd39f40,transparent);filter:blur(36px);z-index:-1}
.strip{display:grid;grid-template-columns:repeat(3,1fr);margin-top:28px;background:var(--card);border:1px solid var(--line);border-radius:14px}
.strip div{display:flex;gap:12px;align-items:flex-start;padding:16px 18px;border-left:1px solid var(--line)}.strip div:first-child{border-left:0}
.strip p{margin:0}.strip .ico{width:36px;height:36px}.strip b{display:block;color:var(--text);font-size:15px;margin-bottom:2px}.strip p span{display:block;color:var(--sub);font-size:14px;line-height:1.45}
.band{position:relative;overflow:hidden;text-align:center;padding:56px 28px;border-radius:24px;background:radial-gradient(700px 300px at 50% 0%,#2fd39f33,transparent),linear-gradient(160deg,#0f3d30,#08201a);border:1px solid #2fd39f40}
.band img{width:72px;height:72px;margin-bottom:14px}
.band h2{font-size:clamp(28px,3.8vw,44px)}.band p{color:var(--sub);max-width:560px;margin:0 auto 26px}
.open{display:grid;grid-template-columns:repeat(4,1fr);gap:16px}
.open a.card{color:var(--text);display:block}.open a.card:hover{text-decoration:none;border-color:#2fd39f88}
.open .card span{display:block;margin-top:4px}
.specs{display:grid;grid-template-columns:repeat(6,1fr);border:1px solid var(--line);border-radius:16px;overflow:hidden}
.specs div{padding:18px 16px;border-left:1px solid var(--line)}.specs div:first-child{border-left:0}
.specs small{display:block;font-size:12px;text-transform:uppercase;letter-spacing:.06em;color:var(--sub);margin-bottom:4px}
.specs b{font-size:15px}
@media (max-width:980px){.trust{grid-template-columns:repeat(3,1fr)}.open{grid-template-columns:1fr 1fr}.specs{grid-template-columns:repeat(3,1fr)}.specs div:nth-child(4){border-left:0}.specs div:nth-child(n+4){border-top:1px solid var(--line)}}
@media (max-width:820px){.fx{grid-template-columns:1fr;gap:24px;padding:32px 0}.fx.flip .fx-t{order:0}.stats{grid-template-columns:1fr}.strip div{padding:14px}}
@media (max-width:600px){.trust{grid-template-columns:1fr 1fr}.trust div:last-child{grid-column:1/-1}.open,.specs{grid-template-columns:1fr 1fr}.specs div{border-left:0;border-top:1px solid var(--line)}.specs div:nth-child(-n+2){border-top:0}.specs div:nth-child(even){border-left:1px solid var(--line)}.band{padding:40px 18px}
 .strip{grid-template-columns:1fr}.strip div{border-left:0;border-top:1px solid var(--line);padding:12px 14px}.strip div:first-child{border-top:0}}
"""

T = {
"en": dict(
  lang="en", path="", other="vi/", title="Free App to Free Up Storage on Mac (Open Source) | Tidymint",
  desc="Free, open-source macOS disk space app. See what fills your Mac, clear caches and System Data, find duplicates, uninstall apps fully. Trash first, with Undo.",
  nav=[("#features","Features"),("#how","How it works"),("guides/","Guides"),("#faq","FAQ"),(GH,"GitHub")], navcta="Download",
  eyebrow=("changelog/", 'New: version <span class="ver">{v}</span> is out'),
  h1='Your Mac is full.<br><span>Let’s find out why.</span>',
  sub="Free up gigabytes, see exactly what fills your disk, and undo any clean. A free, open-source Mac cleaner that only ever moves things to the Trash.",
  cta1="Download free", cta2="How to install", cta_how="See how it works",
  micro='macOS 14 or later · Apple silicon and Intel · Version <span class="ver">{v}</span>',
  trust=[("apps","Open source","MIT licence, every line public"),("undo","Trash first","Undo the last clean in one click"),("shield","No tracking","No account, works offline"),("scan","Listed in awesome-mac","The community list of Mac apps"),("drive","Free forever","No subscription, no paid tier")],
  stats=[("$0","Free, for good","No trial, no subscription, no upsell inside the app."),("100%","Open code","Every line is on GitHub, so you can check what it deletes."),("1 click","To undo","Changed your mind? Put the last clean back from the Trash.")],
  fx=[("scan","Clean Now","Free up space in one click","One scan finds caches, logs and old installers, sorted by size. Nothing moves until you press Clean.",["Grouped and explained in plain words","Safe items pre-selected, the rest left to you","Apple system caches are never touched"],None,"cleanup.jpg","Clean Now scan results grouped by type and size"),
      ("byapp","Clean by App","Clean app by app, keep what matters","Browsers, chat apps and video editors pile up gigabytes of cache. Clean them one app at a time.",["Chrome, Edge, CapCut, Zalo and more","Caches ticked, your photos and files unticked","Chat photos grouped by month"],None,"byapp.jpg","Clean by App showing browser caches pre-selected and chat photos by month"),
      ("lens","Space Lens","See what is really eating your disk","A bubble map of your whole drive. Bigger bubble, bigger folder. Click to dig in.",["Plain notes for common folders","Shows System Data you cannot see in Finder","Great for “full, no idea why”"],("clear-system-data-mac/","What is System Data?"),"lens.jpg","Space Lens bubble map showing which folders fill a Mac disk"),
      ("dupes","Duplicates","Remove duplicates without breaking projects","Files are matched by content and one copy is always kept. Copies still used by a script in your project folders are flagged and skipped.",["Matched by content, not by name","One copy always kept","Files your projects use are protected"],None,"dupes.jpg","Tidymint duplicate file finder with the copy to keep marked"),
      ("apps","Uninstaller","Uninstall apps, leftovers included","Dragging an app to the Trash leaves its caches and support files behind. Tidymint removes those too.",["Finds caches, preferences and support files","Anything holding a database is left to you","Everything goes to the Trash first"],None,"apps.jpg","Tidymint uninstaller listing apps with their leftover files"),
      ("large","Large files","Find the big, forgotten files","Old exports, disk images and downloads you forgot about. Sort by size or by last opened.",["Everything over 100 MB in one list","Never pre-selected, you pick what goes","Full path shown, so you know what each file is"],None,"large.jpg","Tidymint large files list sorted by size, nothing selected")],
  minis=[("undo","Undo","Every clean is recorded. One click puts the last run back while it is still in the Trash."),("shield","Startup Items","Who signed each background item, with a flag on odd names or locations."),("drive","Menu bar monitor","Free GB in the menu bar, alerts when disk or memory runs low. About 70&nbsp;MB of RAM.")],
  band_h="Nine tools. One small, free app.", band_p="No account, no subscription, no tracking. Download it, scan, and see what you get back.",
  open_tag="Built in the open", open_h="Nothing hidden, nothing to sign up for", open_lead="Tidymint is a small open-source project. You can read the code, follow every release and report a bug in public.",
  open=[("dev",GH,"Source code","Read every line on GitHub."),("undo","changelog/","Changelog","What changed in each version."),("shield",GH+"/blob/main/PRIVACY.md","Privacy","The app collects nothing."),("bug",GH+"/issues","Report a bug","Issues are public and answered.")],
  specs=[("Requires","macOS 14+"),("Chips","Apple silicon, Intel"),("Price","Free"),("Licence","MIT"),("Latest",'v<span class="ver">{v}</span>'),("Source",'<a href="%s">GitHub</a>' % GH)],
  faq_tag="FAQ",
  shot_alt="Tidymint home page after a scan: what is safe to clean, grouped and sized", byapp_alt="Clean by App showing browser caches pre-selected and chat photos by month", lens_alt="Space Lens bubble map showing which folders fill a Mac disk", dupes_alt="Tidymint duplicate file finder with the copy to keep marked", cleanup_alt="Tidymint cleanup details listing caches and logs by size", vs_more='Full comparison: <a href="cleanmymac-alternative/">free CleanMyMac alternatives</a> · Guide: <a href="clear-system-data-mac/">how to clear System Data on Mac</a>',
  vs_tag="Why Tidymint", vs_h="A cleaner you can actually trust",
  vs_bad_h="Typical paid cleaners", vs_bad=["Paid licence or subscription, major upgrades often cost extra","Closed source: you cannot see what it deletes","Cracked copies are a common way to get malware"],
  vs_good_h="Tidymint", vs_good=["Free, with no account and no subscription","Open source (MIT): anyone can read every line","Only moves items to the Trash, you empty it yourself"],
  def_tag="Good to know", def_h="What is “System Data” on a Mac?",
  def_p="In <b>System Settings › General › Storage</b>, macOS groups everything it cannot sort into a category called <b>System Data</b>. It often grows to tens of gigabytes and is hard to inspect from Finder.",
  def_li=["App and browser caches, logs and temporary files","Leftovers from apps you already deleted","Local Time Machine snapshots and old installers","For AI work: model weights and package caches"],
  def_p2="Tidymint shows which of these are big on your Mac and moves the safe ones to the Trash.",
  how_tag="How it works", how_h="Three steps, you stay in control",
  how=[("Scan","One click scans caches, logs and large files."),("Review","Everything grouped, sized and explained."),("Clean","Selected items go to the Trash, with Undo.")],
  feat_tag="Features", feat_h="Everything you need to win back space",
  feat_lead="Six tools for the jobs that fill a Mac, plus a few small helpers. Each one shows you first and cleans only when you say so.",
  use_tag="Made for", use_h="Who fills their Mac the fastest",
  uses=[("ai","AI work","Model weights, Hugging Face and Ollama caches, generated images."),("dev","Developers","node_modules, npm and Homebrew caches, old builds."),("video","Video and photo","Exports, render drafts and duplicate assets."),("full","Full, no idea why","System Data and “Other” swell: caches, Time Machine snapshots, old iPhone backups.")],
  faq_h="Before you download",
  faq=[("Is Tidymint really free?","Yes. It is open source under the MIT licence, with no account, no subscription and no paid tier."),
       ("Is it safe?","Tidymint only moves items to the Trash and Undo puts the last clean back. Photos, Mail, keychains, cloud folders and Apple system caches are never touched."),
       ("Why does macOS block it the first time?","Tidymint is not notarized by Apple yet (that needs a paid developer account). Open it once via System Settings › Privacy & Security › Open Anyway. The source is public on GitHub."),
       ("Does it send my data anywhere?","No. The only network call is a once-a-day check for a new version, which reads a version number and sends nothing about your Mac. Data leaves your Mac only when you send feedback yourself."),
       ("How does the duplicate check protect my projects?","Add your project folders once in Settings. Before deleting duplicates, Tidymint searches those folders: any file still named in a script or skill is flagged in red and unticked. Without project folders the app reminds you first."),
       ("How is it different from CleanMyMac?","Tidymint is free and open source and focuses on cleaning and disk space. It has no scanner of its own and relies on the protection built into macOS (XProtect, Gatekeeper); CleanMyMac bundles its own and charges a subscription."),
       ("Where do I download it safely?","Only from tidymint.app or the GitHub releases page. Tidymint has no other website, no app store listing and no paid version. Anything else is not us."),
       ("Which Macs are supported?","macOS 14 or later, on both Apple silicon and Intel."),
       ("Is there a Windows or iPhone version?","A Windows version is in development, no release date yet. iPhone: no, iOS does not let apps clean other apps' data.")],
  inst_h="Install", inst_lead="macOS 14 or later, Apple silicon and Intel.",
  inst_note="Tidymint is not notarized by Apple yet, so macOS blocks the first launch, like any app without notarization. <a href=\"%s\">Sponsoring the project</a> pays for the Apple Developer account: then the app just opens and updates arrive faster." % "https://github.com/sponsors/HaiTrung-Workspace",
  inst=[("Download",'Click <a href="%s">Download Tidymint</a>, open <b>Tidymint.zip</b> in Downloads and drag <b>Tidymint</b> to <b>Applications</b>.' % DL),
        ("First launch",'Double-click Tidymint. When macOS says it cannot be opened, click <b>Done</b>. Do not choose Move to Trash.'),
        ("Allow it",'Open <b>System Settings › Privacy &amp; Security</b>, scroll to the <b>Security</b> heading and click <b>Open Anyway</b>, then confirm with your password. <a href="install/">Step-by-step guide with screenshots</a>.'),
        ("Full Disk Access <span class=\"opt\">optional</span>",'In Privacy &amp; Security, open <b>Full Disk Access</b> and turn on Tidymint, so Mail, Messages and Library are measured too. <a href="install/#s6">How</a>.')],
  inst_small='Steps from Apple: <a href="https://support.apple.com/102445">Safely open apps on your Mac</a>. Source code and build steps are on <a href="%s">GitHub</a>.' % GH,
  sign_h="Get updates", sign_p="Mac tips and new releases, at most one email a month.", sign_ph="name@example.com", sign_btn="Subscribe",
  consent="Get the latest updates. Unsubscribe any time.",
  end_h="Ready to tidy up?", end_p="Free, open source, and everything goes to the Trash first.",
  f_blurb="Free, open-source Mac cleaner. Provided as is, without warranty. Official site: tidymint.app, downloads only from GitHub.",
  f_cols=[("Product",[("#features","Features"),("#how","How it works"),("#install","Install"),("changelog/","Changelog"),(GH+"/releases","Releases"),("https://github.com/sponsors/HaiTrung-Workspace","Sponsor")]),
          ("Guides",[("install/","Install step by step"),("mac-storage-keeps-filling-up/","Mac keeps filling up"),("clear-system-data-mac/","Clear System Data"),("adobe-storage-mac/","Adobe taking up space"),("free-up-space-mac/","Free up space on Mac"),("cleanmymac-alternative/","CleanMyMac alternative"),(GH+"/issues","Report a bug")]),
          ("Legal",[(GH+"/blob/main/PRIVACY.md","Privacy"),(GH+"/blob/main/LICENSE","MIT License"),("mailto:hello@tidymint.app","hello@tidymint.app")])],
  copy="© 2026 Tidymint", extra_footer="",
  msg=dict(bad="Please enter a valid email.",sending="Sending...",ok="Thanks! You are on the list.",err="Could not send right now. Please try again later."),
  src="website", img="", shot="", aria_lang="Language", top="Back to top",
  ck_text="This website uses Google Analytics cookies to count visits. The Tidymint app itself tracks nothing.", ck_yes="Accept", ck_no="Decline", ck_link="Cookie settings", ck_more="Privacy"),
"vi": dict(
  lang="vi", path="vi/", other="../", title="Dọn dẹp MacBook miễn phí, thay CleanMyMac | Tidymint",
  desc="Dọn dẹp MacBook miễn phí: xoá bộ nhớ đệm, gọn Dữ liệu hệ thống, gỡ ứng dụng sạch, tìm file trùng. Mã nguồn mở, tiếng Việt, mọi thứ vào Thùng rác trước.",
  nav=[("#tinh-nang","Tính năng"),("#cach-dung","Cách dùng"),("huong-dan/","Hướng dẫn"),("#hoi-dap","Hỏi đáp"),(GH,"GitHub")], navcta="Tải về",
  eyebrow=("lich-su-cap-nhat/", 'Mới: đã có bản <span class="ver">{v}</span>'),
  h1='MacBook đầy ổ?<br><span>Xem ngay cái gì chiếm chỗ.</span>',
  sub="Lấy lại dung lượng, thấy rõ thứ gì làm đầy ổ, và hoàn tác được mọi lần dọn. App dọn MacBook miễn phí, mã nguồn mở, chỉ chuyển đồ vào Thùng rác.",
  cta1="Tải miễn phí", cta2="Hướng dẫn cài", cta_how="Xem cách dùng",
  micro='macOS 14 trở lên · Chip Apple và Intel · Bản <span class="ver">{v}</span>',
  trust=[("apps","Mã nguồn mở","Giấy phép MIT, ai cũng đọc được"),("undo","Vào Thùng rác trước","Hoàn tác lần dọn bằng một cú bấm"),("shield","Không theo dõi","Không tài khoản, chạy không cần mạng"),("scan","Có trong awesome-mac","Danh sách app Mac của cộng đồng"),("drive","Miễn phí mãi","Không thuê bao, không bản trả phí")],
  stats=[("0đ","Miễn phí thật sự","Không dùng thử, không thuê bao, không mời mua thêm trong app."),("100%","Mã nguồn công khai","Mọi dòng code đều trên GitHub, xem được app xoá những gì."),("1 cú bấm","Để hoàn tác","Đổi ý thì trả lần dọn vừa rồi về chỗ cũ từ Thùng rác.")],
  fx=[("scan","Dọn ngay","Dọn một cú bấm","Một lần quét thấy ngay bộ nhớ đệm, nhật ký, file cài cũ, xếp theo dung lượng. Không gì bị dọn cho tới khi bạn bấm Dọn.",["Nhóm rõ ràng, giải thích dễ hiểu","Phần an toàn chọn sẵn, phần còn lại để bạn quyết","Không động tới bộ nhớ đệm hệ thống của Apple"],None,"cleanup.jpg","Kết quả Dọn ngay chia nhóm theo loại và dung lượng"),
      ("byapp","Dọn theo ứng dụng","Dọn từng app, giữ lại thứ cần giữ","Zalo, trình duyệt, app dựng video tích tụ hàng GB bộ nhớ đệm. Dọn riêng từng app một.",["Zalo, Chrome, Edge, Cốc Cốc, CapCut","Bộ nhớ đệm chọn sẵn, ảnh và file để bạn tự chọn","Ảnh tin nhắn xếp theo tháng"],("zalo-chiem-dung-luong-macbook/","Zalo chiếm dung lượng MacBook"),"byapp.jpg","Dọn theo ứng dụng: bộ nhớ đệm Zalo chọn sẵn, ảnh tin nhắn xếp theo tháng"),
      ("lens","Bản đồ ổ đĩa","Thấy rõ cái gì đang ăn ổ","Bản đồ bong bóng của cả ổ. Bong bóng càng to, thư mục càng nặng. Bấm vào để xem sâu hơn.",["Giải thích các thư mục hay gặp","Thấy cả Dữ liệu hệ thống mà Finder không cho xem","Hợp khi máy đầy mà không rõ vì sao"],("mac-tu-day-o/","Vì sao Mac tự đầy ổ?"),"lens.jpg","Bản đồ bong bóng cho thấy thư mục nào chiếm ổ MacBook"),
      ("dupes","File trùng","Xoá file trùng mà không hỏng dự án","So theo nội dung, luôn giữ lại một bản. Bản nào script trong thư mục dự án còn dùng sẽ được đánh dấu và bỏ qua.",["So nội dung, không so tên","Luôn giữ lại một bản","File dự án còn dùng được bảo vệ"],None,"dupes.jpg","Tìm file trùng trên MacBook, đánh dấu bản giữ lại"),
      ("apps","Gỡ app","Gỡ app sạch, cả phần sót lại","Kéo app vào Thùng rác vẫn sót bộ nhớ đệm và file hỗ trợ. Tidymint gỡ luôn phần đó.",["Tìm bộ nhớ đệm, file cài đặt, file hỗ trợ","App có database bên trong thì để bạn quyết","Mọi thứ vào Thùng rác trước"],("xoa-ung-dung-macbook/","Cách xoá app sạch hoàn toàn"),"apps.jpg","Gỡ app Zoom cùng các file sót lại trong Library"),
      ("large","File lớn","Tìm file to bị bỏ quên","File xuất cũ, file ảnh đĩa, đồ tải về rồi quên. Xếp theo dung lượng hoặc theo lần mở cuối.",["Mọi file trên 100 MB trong một danh sách","Không chọn sẵn, bạn tự chọn file nào bỏ","Hiện đường dẫn đầy đủ, biết rõ file nào là gì"],None,"large.jpg","Danh sách file lớn trên MacBook xếp theo dung lượng, chưa chọn file nào")],
  minis=[("undo","Hoàn tác","Mỗi lần dọn đều được ghi lại. Một cú bấm trả lần dọn vừa rồi về chỗ cũ khi còn trong Thùng rác."),("shield","Khởi động cùng máy","Ai đã ký từng mục chạy ngầm, đánh dấu tên hay vị trí bất thường."),("drive","Thanh menu","Số GB còn trống ngay trên thanh menu, báo khi ổ hay RAM sắp đầy. Khoảng 70&nbsp;MB RAM.")],
  band_h="Chín công cụ. Một app nhỏ, miễn phí.", band_p="Không tài khoản, không thuê bao, không theo dõi. Tải về, quét thử, xem lấy lại được bao nhiêu.",
  open_tag="Làm công khai", open_h="Không giấu gì, không phải đăng ký", open_lead="Tidymint là một dự án mã nguồn mở nhỏ. Bạn đọc được code, theo dõi từng bản phát hành và báo lỗi công khai.",
  open=[("dev",GH,"Mã nguồn","Đọc từng dòng trên GitHub."),("undo","lich-su-cap-nhat/","Lịch sử cập nhật","Mỗi bản thay đổi những gì."),("shield",GH+"/blob/main/PRIVACY.md","Quyền riêng tư","App không thu thập gì."),("bug",GH+"/issues","Báo lỗi","Lỗi được báo công khai và có người trả lời.")],
  specs=[("Cần","macOS 14+"),("Chip","Apple, Intel"),("Giá","Miễn phí"),("Giấy phép","MIT"),("Bản mới nhất",'v<span class="ver">{v}</span>'),("Mã nguồn",'<a href="%s">GitHub</a>' % GH)],
  faq_tag="Hỏi đáp",
  shot_alt="Trang đầu Tidymint sau khi quét: phần an toàn để dọn, chia nhóm và ghi dung lượng", byapp_alt="Dọn theo ứng dụng: bộ nhớ đệm Zalo chọn sẵn, ảnh tin nhắn xếp theo tháng", lens_alt="Bản đồ bong bóng cho thấy thư mục nào chiếm ổ MacBook", dupes_alt="Tìm file trùng trên MacBook, đánh dấu bản giữ lại", cleanup_alt="Chi tiết dọn dẹp: bộ nhớ đệm và nhật ký xếp theo dung lượng", vs_more='So sánh chi tiết: <a href="cleanmymac-mien-phi/">CleanMyMac miễn phí? Lựa chọn hợp pháp</a> · Hướng dẫn: <a href="xoa-ung-dung-macbook/">cách xóa ứng dụng trên MacBook sạch hoàn toàn</a>',
  vs_tag="Vì sao chọn Tidymint", vs_h="App dọn dẹp bạn tin được",
  vs_bad_h="App dọn dẹp trả phí thường gặp", vs_bad=["Trả tiền bản quyền hoặc thuê bao, lên đời bản lớn thường tốn thêm","Mã nguồn đóng: không biết app xoá những gì","Bản crack là đường lây mã độc rất phổ biến"],
  vs_good_h="Tidymint", vs_good=["Miễn phí, không cần tài khoản, không thuê bao","Mã nguồn mở (MIT): ai cũng đọc được từng dòng","Chỉ chuyển vào Thùng rác, bạn tự đổ"],
  def_tag="Nên biết", def_h="“Dữ liệu hệ thống” trên Mac là gì?",
  def_p="Trong <b>Cài đặt hệ thống › Cài đặt chung › Dung lượng</b>, macOS gom mọi thứ không xếp được vào mục <b>Dữ liệu hệ thống</b> (System Data). Mục này hay phình lên hàng chục GB và khó xem bằng Finder.",
  def_li=["Bộ nhớ đệm, nhật ký, file tạm của app và trình duyệt","Phần sót lại của app đã xoá","Bản chụp Time Machine trên máy và file cài đặt cũ","Với người làm AI: file model và bộ nhớ đệm thư viện"],
  def_p2="Tidymint chỉ ra mục nào đang to trên máy bạn và đưa phần an toàn vào Thùng rác.",
  how_tag="Cách dùng", how_h="Ba bước, bạn luôn là người quyết",
  how=[("Quét","Một cú bấm quét bộ nhớ đệm, nhật ký, file lớn."),("Xem lại","Mọi thứ được nhóm, đo và giải thích rõ."),("Dọn","Phần đã chọn vào Thùng rác, hoàn tác được.")],
  feat_tag="Tính năng", feat_h="Đủ công cụ để lấy lại dung lượng",
  feat_lead="Sáu công cụ cho những thứ hay làm đầy máy, thêm vài tiện ích nhỏ. Công cụ nào cũng cho bạn xem trước, chỉ dọn khi bạn bấm.",
  use_tag="Dành cho", use_h="Ai hay đầy ổ nhất",
  uses=[("ai","Người làm AI","File model, bộ nhớ đệm Hugging Face, Ollama, ảnh tạo bằng AI."),("dev","Lập trình viên","node_modules, npm, Homebrew, bản build cũ."),("video","Làm video, ảnh","File xuất, bản nháp render, ảnh trùng."),("full","Đầy ổ, không rõ vì sao","Dữ liệu hệ thống và “Khác” phình to: bộ nhớ đệm, snapshot Time Machine, sao lưu iPhone cũ.")],
  faq_h="Trước khi tải về",
  faq=[("Tidymint có miễn phí thật không?","Có. App mã nguồn mở theo giấy phép MIT, không tài khoản, không thuê bao, không có bản trả phí."),
       ("Có an toàn không?","Tidymint chỉ chuyển vào Thùng rác, Hoàn tác trả lại lần dọn vừa rồi. Ảnh, Mail, mật khẩu, thư mục đám mây và bộ nhớ đệm hệ thống không bao giờ bị động tới."),
       ("Sao lần đầu macOS lại chặn?","Tidymint chưa được Apple công chứng (cần tài khoản nhà phát triển trả phí). Mở một lần qua Cài đặt hệ thống › Quyền riêng tư & Bảo mật › Vẫn mở. Mã nguồn công khai trên GitHub."),
       ("App có gửi dữ liệu của tôi đi không?","Không. Lần duy nhất app ra mạng là kiểm bản mới một lần mỗi ngày: chỉ đọc số phiên bản, không gửi gì về máy bạn. Dữ liệu chỉ rời máy khi bạn tự bấm gửi góp ý."),
       ("Kiểm tra file trùng bảo vệ dự án thế nào?","Khai thư mục dự án một lần ở Cài đặt. Trước khi xoá file trùng, Tidymint tìm trong các thư mục đó: file nào còn được script hay skill gọi tên sẽ gắn nhãn đỏ và bỏ tick. Chưa khai thư mục thì app nhắc trước."),
       ("Khác gì CleanMyMac?","Tidymint miễn phí, mã nguồn mở, tập trung vào dọn dẹp và dung lượng ổ. App không có bộ quét riêng mà dựa vào lớp bảo vệ sẵn của macOS (XProtect, Gatekeeper); CleanMyMac có bộ quét riêng và thu phí thuê bao."),
       ("Tải ở đâu cho an toàn?","Chỉ tải từ tidymint.app hoặc trang phát hành trên GitHub. Tidymint không có trang web nào khác, không có bản trả phí. Thấy ở chỗ khác thì không phải của chúng tôi."),
       ("Chạy trên máy nào?","macOS 14 trở lên, cả máy chip Apple lẫn máy Intel."),
       ("Có bản Windows hay iPhone không?","Bản Windows đang làm, chưa có ngày ra. iPhone: không, iOS không cho app dọn dữ liệu app khác.")],
  inst_h="Cài đặt", inst_lead="Cần macOS 14 trở lên, chạy được cả máy chip Apple và máy Intel.",
  inst_note="Tidymint chưa được Apple công chứng nên lần mở đầu macOS sẽ chặn, như mọi app chưa công chứng. <a href=\"%s\">Ủng hộ dự án</a> giúp mua tài khoản Apple Developer: khi đó app mở là chạy, cập nhật tới nhanh hơn." % "https://github.com/sponsors/HaiTrung-Workspace",
  inst=[("Tải về",'Bấm <a href="%s">Tải Tidymint</a>, mở <b>Tidymint.zip</b> trong Downloads, kéo <b>Tidymint</b> vào thư mục <b>Ứng dụng</b> (Applications).' % DL),
        ("Mở lần đầu",'Nhấp đúp Tidymint. macOS báo không mở được, bấm <b>Xong</b> (Done). Đừng chọn Chuyển vào Thùng rác.'),
        ("Cho phép mở",'Vào <b>Cài đặt hệ thống › Quyền riêng tư &amp; Bảo mật</b>, kéo tới mục <b>Bảo mật</b>, bấm <b>Vẫn mở</b> (Open Anyway) rồi xác nhận bằng mật khẩu máy. <a href="cai-dat/">Hướng dẫn từng bước có ảnh</a>.'),
        ("Truy cập toàn bộ ổ đĩa <span class=\"opt\">không bắt buộc</span>",'Trong Quyền riêng tư &amp; Bảo mật, mở <b>Truy cập toàn bộ ổ đĩa</b> và bật Tidymint để quét được cả Mail, Tin nhắn, Library. <a href="cai-dat/#s6">Xem cách làm</a>.')],
  inst_small='Các bước mở app chưa công chứng theo hướng dẫn chính thức của Apple: <a href="https://support.apple.com/102445">Mở app an toàn trên máy Mac</a>. Mã nguồn công khai trên <a href="%s">GitHub</a>.' % GH,
  sign_h="Nhận tin khi có bản mới", sign_p="Mẹo giữ máy gọn và thông báo phiên bản mới, mỗi tháng tối đa một thư.", sign_ph="ten@example.com", sign_btn="Đăng ký",
  consent="Nhận thông tin cập nhật mới nhất. Huỷ bất kỳ lúc nào.",
  end_h="Dọn máy thôi?", end_p="Miễn phí, mã nguồn mở, mọi thứ vào Thùng rác trước.",
  f_blurb="Ứng dụng dọn dẹp MacBook miễn phí, mã nguồn mở. Cung cấp nguyên trạng, không bảo hành. Trang chính thức duy nhất: tidymint.app, tải chỉ từ GitHub.",
  f_cols=[("Sản phẩm",[("#tinh-nang","Tính năng"),("#cach-dung","Cách dùng"),("#cai-dat","Cài đặt"),("lich-su-cap-nhat/","Lịch sử cập nhật"),(GH+"/releases","Các phiên bản"),("https://github.com/sponsors/HaiTrung-Workspace","Ủng hộ dự án")]),
          ("Hướng dẫn",[("cai-dat/","Cài đặt từng bước"),("mac-tu-day-o/","Mac tự đầy ổ"),("zalo-chiem-dung-luong-macbook/","Zalo chiếm dung lượng"),("adobe-chiem-dung-luong-mac/","Adobe chiếm dung lượng"),("cleanmymac-mien-phi/","CleanMyMac miễn phí?"),("xoa-ung-dung-macbook/","Xóa ứng dụng trên MacBook"),(GH,"Mã nguồn"),(GH+"/issues","Báo lỗi")]),
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
    ver = open(os.path.join(ROOT, "docs", "version.txt")).read().strip()
    V = lambda x: x.replace("{v}", ver)
    ok = icon("check", 16)
    trust = "".join('<div><span class="ico">%s</span><b>%s</b>%s</div>' % (icon(a), b, c) for a, b, c in t["trust"])
    stats = "".join('<div class="stat"><span class="big">%s</span><b>%s</b><span>%s</span></div>' % x for x in t["stats"])
    fx = "".join('<div class="fx%s"><div class="fx-t"><span class="ico">%s</span><span class="tag">%s</span><h3>%s</h3><p>%s</p><ul>%s</ul>%s</div><div class="fx-i"><img src="%s%s" alt="%s" loading="lazy" width="1600" height="1013"></div></div>'
                 % (" flip" if n % 2 else "", icon(ic), tg, h3, p_, "".join("<li>%s<span>%s</span></li>" % (ok, b) for b in bl),
                    ('<a class="more" href="%s">%s <span class="arr r">→</span></a>' % more) if more else "", shot, im, alt)
                 for n, (ic, tg, h3, p_, bl, more, im, alt) in enumerate(t["fx"]))
    minis = "".join('<div><span class="ico">%s</span><p><b>%s</b><span>%s</span></p></div>' % (icon(a), b, c) for a, b, c in t["minis"])
    opn = "".join('<a class="card" href="%s"><div class="hd"><span class="ico">%s</span><b>%s</b></div><span class="small">%s</span></a>' % (h, icon(a), b, c) for a, h, b, c in t["open"])
    specs = "".join("<div><small>%s</small><b>%s</b></div>" % (a, V(b)) for a, b in t["specs"])
    uses = "".join('<div class="card"><div class="hd"><span class="ico">%s</span><b>%s</b></div><span>%s</span></div>' % (icon(k), h, d) for k, h, d in t["uses"])
    arr = '<span class="arr" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"/><path d="m13 6 6 6-6 6"/></svg></span>'
    arr = '<span class="arr" aria-hidden="true">%s</span>' % icon("arrow", 20)
    how = arr.join('<div class="card"><div class="hd"><span class="n"></span><b>%s</b></div><span>%s</span></div>' % h for h in t["how"])
    faq = "".join('<details><summary>%s</summary><p>%s</p></details>' % (html.escape(q), html.escape(a)) for q, a in t["faq"])
    inst = "".join('<li><span class="n">%d</span><h4>%s</h4><p>%s</p></li>' % (k+1, a, b.replace("{img}", img)) for k, (a, b) in enumerate(t["inst"]))
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
<style>{BASE_CSS}{EXTRA_CSS}{HOME_CSS}</style>
</head>
<body id="top">
<div class="topnav"><div class="wrap"><nav>
  <a class="brand" href="./"><img src="{img}icon.png" alt=""><span>Tidy<span class="mint">mint</span></span></a>
  <div class="navr"><div class="links">{nav}</div><a class="btn primary navcta" href="#{i["i"]}">{t["navcta"]}</a><div class="lang" role="group" aria-label="{t["aria_lang"]}"><a {vi_on}href="{vi_href}" data-l="vi">VI</a><a {en_on}href="{en_href}" data-l="en">EN</a></div><button class="mbtn" id="mbtn" type="button" aria-label="Menu" aria-expanded="false">☰</button></div>
</nav></div></div>
<div class="wrap">

<header class="hero">
  <a class="eyebrow" href="{t["eyebrow"][0]}"><i></i>{V(t["eyebrow"][1])} <span class="arr r">→</span></a>
  <h1>{t["h1"]}</h1>
  <p>{t["sub"]}</p>
  <div class="cta"><a class="btn primary lg" href="{DL}">{t["cta1"]} <span class="arr">↓</span></a><a class="btn ghost lg" href="#{i["h"]}">{t["cta_how"]}</a></div>
  <div class="micro">{V(t["micro"])}</div>
  <div class="trust">{trust}</div>
  <div class="shot"><img src="{shot}smart.jpg" alt="{t["shot_alt"]}" width="1600" height="1013"></div>
</header>

<section>
  <div class="stats">{stats}</div>
</section>

<section id="{i["f"]}" style="padding-top:24px">
  <div class="sechead"><span class="tag">{t["feat_tag"]}</span><h2>{t["feat_h"]}</h2><p class="lead">{t["feat_lead"]}</p></div>
  {fx}
  <div class="strip">{minis}</div>
</section>

<section style="padding-top:24px">
  <div class="band"><img src="{img}icon.png" alt=""><h2>{t["band_h"]}</h2><p>{t["band_p"]}</p><a class="btn primary lg" href="{DL}">{t["cta1"]} <span class="arr">↓</span></a></div>
</section>

<section id="{i["h"]}">
  <div class="sechead"><span class="tag">{t["how_tag"]}</span><h2>{t["how_h"]}</h2></div>
  <div class="how">{how}</div>
</section>

<section>
  <div class="sechead"><span class="tag">{t["vs_tag"]}</span><h2>{t["vs_h"]}</h2></div>
  <div class="vs">
    <div class="col bad"><h3>{t["vs_bad_h"]}</h3><ul>{"".join("<li>%s</li>" % x for x in t["vs_bad"])}</ul></div>
    <div class="col good"><h3>{t["vs_good_h"]}</h3><ul>{"".join("<li>%s</li>" % x for x in t["vs_good"])}</ul></div>
  </div>
  <p class="small" style="margin-top:14px;text-align:center">{t["vs_more"]}</p>
</section>

<section>
  <div class="sechead"><span class="tag">{t["use_tag"]}</span><h2>{t["use_h"]}</h2></div>
  <div class="grid uses">{uses}</div>
</section>

<section>
  <div class="sechead"><span class="tag">{t["open_tag"]}</span><h2>{t["open_h"]}</h2><p class="lead">{t["open_lead"]}</p></div>
  <div class="open">{opn}</div>
</section>

<section style="padding-top:24px">
  <div class="def">
    <div><span class="tag">{t["def_tag"]}</span><h2>{t["def_h"]}</h2><p>{t["def_p"]}</p><ul>{"".join("<li>%s</li>" % x for x in t["def_li"])}</ul><p>{t["def_p2"]}</p></div>
    <img src="{shot}lens.jpg" alt="{t["lens_alt"]}" loading="lazy" style="width:100%;height:auto;border-radius:12px;border:1px solid var(--line)">
  </div>
</section>

<section id="{i["q"]}">
  <div class="sechead" style="margin-bottom:24px"><span class="tag">{t["faq_tag"]}</span><h2>{t["faq_h"]}</h2></div>
  <div style="margin-top:20px">{faq}</div>
</section>

<section id="{i["i"]}">
  <div class="ins">
    <div>
      <h2>{t["inst_h"]}</h2>
      <p class="lead">{t["inst_lead"]}</p>
      <div class="note">{t["inst_note"]}</div>
      <p class="small">{t["inst_small"]}</p>
    </div>
    <ol class="tl">{inst}</ol>
  </div>
</section>

<section style="padding-top:0">
  <div class="specs">{specs}</div>
</section>

<section style="padding-top:24px">
  <div class="band"><img src="{img}icon.png" alt=""><h2>{t["end_h"]}</h2><p>{t["end_p"]}</p><div class="cta"><a class="btn primary lg" href="{DL}">{t["cta1"]} <span class="arr">↓</span></a><a class="btn ghost lg" href="#{i["i"]}">{t["cta2"]}</a></div></div>
  <div class="signup" id="{i["s"]}" style="margin-top:36px">
    <h2 style="margin-bottom:6px">{t["sign_h"]}</h2>
    <p class="small" style="margin:0">{t["sign_p"]}</p>
    <form id="f"><input type="email" id="email" required placeholder="{t["sign_ph"]}" autocomplete="email"><button class="btn primary" type="submit">{t["sign_btn"]}</button></form>
    <div id="msg"></div>
    <p class="small">{t["consent"]}</p>
  </div>
</section>

<div class="topbar"><a href="#top" id="toTop">↑ {t["top"]}</a></div>
<div class="fcols">
  <div><a class="brand" href="./"><img src="{img}icon.png" alt=""><span>Tidy<span class="mint">mint</span></span></a><p>{t["f_blurb"]}</p></div>
  {fcols}
</div>
<footer><span>{t["copy"]}{t["extra_footer"]} · <button class="linkbtn" id="ckOpen" type="button">{t["ck_link"]}</button></span></footer>
</div>
<button class="up" id="up" type="button" aria-label="{t["top"]}" title="{t["top"]}">↑</button>
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
fetch("{img}version.txt",{{cache:"no-store"}}).then(function(r){{return r.ok?r.text():null}}).then(function(v){{v=(v||"").trim();if(/^\\d+(\\.\\d+)+$/.test(v))document.querySelectorAll(".ver").forEach(function(e){{e.textContent=v}})}}).catch(function(){{}});
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
