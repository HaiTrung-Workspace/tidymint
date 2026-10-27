#!/usr/bin/env python3
"""Generate guide pages (docs/<lang>/<slug>/index.html) and refresh sitemap.xml.
Content lives in tools/guides_content.py. Run from the repository root: python3 tools/guides.py"""
import importlib.util, json, os, html, datetime
from stamp import stamp

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_spec = importlib.util.spec_from_file_location("tmsite", os.path.join(ROOT, "tools", "site.py"))
S = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(S)
_spec2 = importlib.util.spec_from_file_location("tmcontent", os.path.join(ROOT, "tools", "guides_content.py"))
C = importlib.util.module_from_spec(_spec2); _spec2.loader.exec_module(C)

ART_CSS = """
.crumb{font-size:14px;color:var(--sub);margin:28px 0 0}.crumb a{color:var(--sub)}
.art{max-width:760px;margin:0 auto;padding:12px 0 40px}
.art h1{font-size:clamp(30px,4.4vw,46px);line-height:1.15;letter-spacing:-.02em;margin:14px 0 14px}
.art .meta{color:var(--sub);font-size:14px;margin:0 0 26px}
.art h2{font-size:clamp(23px,2.8vw,30px);margin:46px 0 12px;scroll-margin-top:80px}
.art h3{font-size:19px;margin:28px 0 8px}
.art p,.art li{color:#cfe6dc;font-size:17px;line-height:1.7}.art li{margin-bottom:6px}
.art strong,.art b{color:var(--text)}
.tldr{background:linear-gradient(135deg,#145c4755,#0b262099);border:1px solid #2fd39f55;border-radius:14px;padding:18px 22px;margin:0 0 26px}
.tldr p{margin:0}.tldr .k{display:block;font-size:12px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;color:var(--leaf);margin-bottom:6px}
.toc{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:16px 22px;margin:0 0 10px}
.toc b{display:block;margin-bottom:6px}.toc ol{margin:0;padding-left:20px}.toc li{font-size:15px;margin:3px 0}.toc a{color:var(--sub)}
.tbl{overflow-x:auto;margin:18px 0}
.art table{border-collapse:collapse;width:100%;font-size:15px;min-width:560px}
.art th,.art td{border:1px solid var(--line);padding:10px 12px;text-align:left;vertical-align:top;color:#cfe6dc}
.art th{background:#ffffff0d;color:var(--text)}
.art td.y{color:var(--leaf)}.art td.n{color:#ff9a9a}
.box{border-radius:16px;padding:22px 24px;margin:30px 0;background:linear-gradient(135deg,#145c4766,#10302780);border:1px solid #2fd39f66}
.box h3{margin:0 0 6px}.box p{margin:0 0 14px}
.gsearch input{width:100%;max-width:520px;padding:10px 14px;border-radius:999px;border:1px solid rgba(255,255,255,.2);background:rgba(255,255,255,.06);color:inherit;font:inherit;font-size:15px;outline:none}.gsearch input:focus{border-color:var(--leaf)}.gsec h2{margin-top:28px}
.pair{display:flex;align-items:center;justify-content:center;gap:14px;margin:14px 0 6px}.pair img{flex:1 1 0;min-width:0;max-width:360px}.pair-arrow{flex:none;width:44px;height:44px;border-radius:50%;background:#2fd39f14;border:1px solid #2fd39f33;color:var(--leaf);display:flex;align-items:center;justify-content:center}.pair-arrow svg{width:22px;height:22px}@media (max-width:640px){.pair{flex-direction:column}.pair img{max-width:100%}.pair-arrow svg{transform:rotate(90deg)}}
.warn{background:#ffb02014;border:1px solid #ffb02055;border-radius:12px;padding:14px 18px;margin:18px 0}.warn p{margin:0}
.art code{overflow-wrap:anywhere}.art pre{max-width:100%;white-space:pre-wrap;overflow-wrap:anywhere}
.src{font-size:14px}.src li{font-size:14px;color:var(--sub)}
.rel{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px;margin-top:14px}
.rel a{display:block;background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px 16px;color:var(--text)}
@media (hover:hover){.rel a:hover{border-color:#2fd39f88;text-decoration:none}.toc a:hover{color:var(--text)}}
"""

L = {
 "vi": dict(home="../", homename="Trang chủ", guides="Hướng dẫn", updated="Cập nhật", tldr="Tóm tắt nhanh",
            toc="Trong bài", faq="Câu hỏi thường gặp", src="Nguồn tham khảo", rel="Đọc thêm",
            cta_h="Dọn Mac miễn phí, hợp pháp", cta_p="Tidymint miễn phí, mã nguồn mở, có tiếng Việt. Mọi thứ chuyển vào Thùng rác trước, bạn tự quyết.",
            cta_btn="Tải Tidymint", cta_more="Xem cách cài", inst="#cai-dat",
            nav=[("../#tinh-nang","Tính năng"),("../#cach-dung","Cách dùng"),("../huong-dan/","Hướng dẫn"),("../#hoi-dap","Hỏi đáp"),(S.GH,"GitHub")]),
 "en": dict(home="../", homename="Home", guides="Guides", updated="Updated", tldr="Quick answer",
            toc="On this page", faq="FAQ", src="Sources", rel="Read next",
            cta_h="Clean your Mac for free", cta_p="Tidymint is free and open source. Everything goes to the Trash first, so you stay in control.",
            cta_btn="Download Tidymint", cta_more="How to install", inst="#install",
            nav=[("../#features","Features"),("../#how","How it works"),("../guides/","Guides"),("../#faq","FAQ"),(S.GH,"GitHub")]),
}

def guide(g):
    k = g["lang"]; t = S.T[k]; l = L[k]
    pre = "vi/" if k == "vi" else ""
    url = "https://tidymint.app/%s%s/" % (pre, g["slug"])
    root = "../../" if k == "vi" else "../"          # path to site root for assets
    home = "../" if k == "vi" else "../"             # path to this language's home page
    alt = g.get("alt")                               # counterpart guide url path, if any
    if k == "vi":
        vi_href, en_href = "./", ("../../" + alt + "/" if alt else "../../")
    else:
        vi_href, en_href = ("../vi/" + alt + "/" if alt else "../vi/"), "./"
    vi_on, en_on = ('class="on" ', '') if k == "vi" else ('', 'class="on" ')
    nav = "".join('<a href="%s">%s</a>' % (h, n) for h, n in l["nav"])
    toc = "".join('<li><a href="#%s">%s</a></li>' % (i, n) for i, n in g["toc"])
    faq = "".join('<details><summary>%s</summary><p>%s</p></details>' % (html.escape(q), a) for q, a in g["faq"])
    srcs = "".join('<li><a href="%s" rel="nofollow">%s</a></li>' % (u, n) for n, u in g["sources"])
    rel = "".join('<a href="%s">%s <span class="arr">→</span></a>' % (u, n) for n, u in g.get("related", [])).replace("{HOME}", home)
    cta = ('<div class="box"><h3>%s</h3><p>%s</p><a class="btn primary" href="%s">%s <span class="arr">→</span></a> '
           '<a class="btn ghost" href="%s%s">%s</a></div>') % (l["cta_h"], l["cta_p"], S.DL, l["cta_btn"], home, l["inst"], l["cta_more"])
    body = g["body"].replace("{CTA}", cta).replace("{DL}", S.DL).replace("{HOME}", home)
    fcols = "".join('<div><h4>%s</h4>%s</div>' % (h, "".join('<a href="%s">%s</a>' % ((home + u) if not u.startswith(("http","mailto")) else u, n) for u, n in links)) for h, links in t["f_cols"])
    strip = lambda s: html.unescape(__import__("re").sub("<[^>]+>", "", s))
    ld = [
      {"@context":"https://schema.org","@type":"Article","headline":g["h1"],"description":g["desc"],"inLanguage":k,
       "datePublished":g["date"],"dateModified":g["date"],"mainEntityOfPage":url,"image":"https://tidymint.app/smart.jpg",
       "author":{"@type":"Organization","name":"Tidymint","url":"https://tidymint.app/"},
       "publisher":{"@type":"Organization","name":"Tidymint","logo":{"@type":"ImageObject","url":"https://tidymint.app/icon.png"}}},
      {"@context":"https://schema.org","@type":"FAQPage","mainEntity":[{"@type":"Question","name":q,"acceptedAnswer":{"@type":"Answer","text":strip(a)}} for q, a in g["faq"]]},
      {"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[
        {"@type":"ListItem","position":1,"name":l["homename"],"item":"https://tidymint.app/" + pre},
        {"@type":"ListItem","position":2,"name":g["crumb"],"item":url}]},
    ]
    hub = g.get("hub", False)
    head_extra = g.get("lead", "") if hub else ('<p class="meta">%s: %s · %s</p><div class="tldr"><span class="k">%s</span><p>%s</p></div>'
        '<div class="toc" role="navigation" aria-label="%s"><b>%s</b><ol>%s</ol></div>') % (l["updated"], "{DSTR}", g["read"], l["tldr"], g["tldr"], l["toc"], l["toc"], toc)
    tail = cta if hub else '<h2 id="faq">%s</h2>%s%s<h2>%s</h2><ul class="src">%s</ul>' % (l["faq"], faq, cta, l["src"], srcs)
    if hub:
        ld = [ld[2], {"@context":"https://schema.org","@type":"CollectionPage","name":g["h1"],"description":g["desc"],"url":url,"inLanguage":k}]
    hreflang = '<link rel="alternate" hreflang="%s" href="%s">' % (k, url)
    if alt:
        ok = "en" if k == "vi" else "vi"
        hreflang += '<link rel="alternate" hreflang="%s" href="https://tidymint.app/%s%s/">' % (ok, "vi/" if ok == "vi" else "", alt)
    d = datetime.date.fromisoformat(g["date"])
    dstr = d.strftime("%d/%m/%Y") if k == "vi" else d.strftime("%B %-d, %Y")
    head_extra = head_extra.replace("{DSTR}", dstr)
    return f'''<!doctype html>
<html lang="{k}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{g["title"]}</title>
<meta name="description" content="{g["desc"]}">
<link rel="canonical" href="{url}">
{hreflang}
<link rel="icon" href="{root}favicon.png">
<link rel="apple-touch-icon" href="{root}apple-touch-icon.png">
<meta property="og:type" content="{"website" if hub else "article"}">
<meta property="og:title" content="{g["title"]}">
<meta property="og:description" content="{g["desc"]}">
<meta property="og:image" content="https://tidymint.app/smart.jpg">
<meta property="og:url" content="{url}">
<meta name="twitter:card" content="summary_large_image">
<script>
window.dataLayer=window.dataLayer||[];function gtag(){{dataLayer.push(arguments)}}
var tmC=null;try{{tmC=localStorage.getItem('tm-consent');var nt=new URLSearchParams(location.search).get('notrack');if(nt==='1')localStorage.setItem('tm-notrack','1');if(nt==='0')localStorage.removeItem('tm-notrack');if(localStorage.getItem('tm-notrack')==='1')window['ga-disable-{S.GA_ID}']=true}}catch(e){{}}
gtag('consent','default',{{ad_storage:'denied',ad_user_data:'denied',ad_personalization:'denied',analytics_storage:tmC==='yes'?'granted':'denied',wait_for_update:500}});
gtag('js',new Date());gtag('config','{S.GA_ID}');
</script>
<script async src="https://www.googletagmanager.com/gtag/js?id={S.GA_ID}"></script>
<script type="application/ld+json">{json.dumps(ld, ensure_ascii=False)}</script>
<style>{S.BASE_CSS}{S.EXTRA_CSS}{ART_CSS}</style>
</head>
<body id="top">
<div class="topnav"><div class="wrap"><nav>
  <a class="brand" href="{home}"><img src="{root}icon.png" alt=""><span>Tidy<span class="mint">mint</span></span></a>
  <div class="navr"><div class="links">{nav}</div><a class="btn primary navcta" href="{S.DL}">{t["navcta"]}</a><div class="lang" role="group" aria-label="{t["aria_lang"]}"><a {vi_on}href="{vi_href}" data-l="vi">VI</a><a {en_on}href="{en_href}" data-l="en">EN</a></div><button class="mbtn" id="mbtn" type="button" aria-label="Menu" aria-expanded="false">☰</button></div>
</nav></div></div>
<div class="wrap">
<article class="art">
  <p class="crumb"><a href="{home}">{l["homename"]}</a> › {g["crumb"]}</p>
  <h1>{g["h1"]}</h1>
  {head_extra}
  {body}
  {tail}
  {"<h2>%s</h2><div class=\"rel\">%s</div>" % (l["rel"], rel) if rel else ""}
</article>
<div class="topbar"><a href="#top" id="toTop">↑ {t["top"]}</a></div>
<div class="fcols">
  <div><a class="brand" href="{home}"><img src="{root}icon.png" alt=""><span>Tidy<span class="mint">mint</span></span></a><p>{t["f_blurb"]}</p></div>
  {fcols}
</div>
<footer><span>{t["copy"]}{t["extra_footer"]} · <button class="linkbtn" id="ckOpen" type="button">{t["ck_link"]}</button></span></footer>
</div>
<button class="up" id="up" type="button" aria-label="{t["top"]}" title="{t["top"]}">↑</button>
<div class="ck" id="ck" role="dialog" aria-live="polite"><p>{t["ck_text"]} <a href="{S.GH}/blob/main/PRIVACY.md">{t["ck_more"]}</a></p><div class="row"><button class="yes" id="ckY" type="button">{t["ck_yes"]}</button><button id="ckN" type="button">{t["ck_no"]}</button></div></div>
<script>
(function(){{var b=document.getElementById('mbtn'),n=document.querySelector('.topnav');function close(){{n.classList.remove('open');b.setAttribute('aria-expanded',false);b.textContent='☰'}}b.addEventListener('click',function(e){{e.stopPropagation();var o=n.classList.toggle('open');b.setAttribute('aria-expanded',o);b.textContent=o?'✕':'☰'}});n.querySelectorAll('.links a').forEach(function(a){{a.addEventListener('click',close)}});document.addEventListener('click',function(e){{if(n.classList.contains('open')&&!n.contains(e.target))close()}});document.addEventListener('keydown',function(e){{if(e.key==='Escape'&&n.classList.contains('open')){{close();b.focus()}}}})}})();
document.querySelectorAll('.lang a').forEach(a=>a.addEventListener('click',()=>{{try{{localStorage.setItem('tm-lang',a.dataset.l)}}catch(e){{}}}}));
(function(){{var up=document.getElementById('up'),bar=document.getElementById('toTop'),barIn=false,tick=false;
function top(e){{if(e)e.preventDefault();scrollTo({{top:0,behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'}})}}
up.addEventListener('click',top);bar.addEventListener('click',top);
function upd(){{tick=false;up.classList.toggle('show',scrollY>600&&!barIn)}}
if('IntersectionObserver' in window)new IntersectionObserver(function(es){{barIn=es[0].isIntersecting;upd()}}).observe(bar);
addEventListener('scroll',function(){{if(!tick){{tick=true;requestAnimationFrame(upd)}}}},{{passive:true}});upd();}})();
(function(){{var ck=document.getElementById('ck');
function show(v){{ck.classList.toggle('show',v)}}
function set(v){{try{{localStorage.setItem('tm-consent',v)}}catch(e){{}};gtag('consent','update',{{analytics_storage:v==='yes'?'granted':'denied'}});show(false)}}
document.getElementById('ckY').onclick=function(){{set('yes')}};document.getElementById('ckN').onclick=function(){{set('no')}};
document.getElementById('ckOpen').onclick=function(){{show(true)}};
if(!tmC)show(true);
document.querySelectorAll('a[href*="releases/latest/download"]').forEach(function(a){{a.addEventListener('click',function(){{gtag('event','download_click',{{link_url:a.href,page_lang:document.documentElement.lang,page_type:'guide'}})}})}});}})();
</script>
</body>
</html>
'''

def sitemap(guides):
    today = max([g["date"] for g in guides] + ["2026-10-26"])
    rows = ['  <url><loc>https://tidymint.app/</loc><lastmod>%s</lastmod>'
            '<xhtml:link rel="alternate" hreflang="en" href="https://tidymint.app/"/>'
            '<xhtml:link rel="alternate" hreflang="vi" href="https://tidymint.app/vi/"/></url>' % today,
            '  <url><loc>https://tidymint.app/vi/</loc><lastmod>%s</lastmod>'
            '<xhtml:link rel="alternate" hreflang="en" href="https://tidymint.app/"/>'
            '<xhtml:link rel="alternate" hreflang="vi" href="https://tidymint.app/vi/"/></url>' % today]
    rows += ['  <url><loc>https://tidymint.app/guides/</loc><lastmod>%s</lastmod></url>' % today,
             '  <url><loc>https://tidymint.app/vi/huong-dan/</loc><lastmod>%s</lastmod></url>' % today,
             '  <url><loc>https://tidymint.app/changelog/</loc><lastmod>%s</lastmod></url>' % today,
             '  <url><loc>https://tidymint.app/vi/lich-su-cap-nhat/</loc><lastmod>%s</lastmod></url>' % today]
    for g in guides:
        pre = "vi/" if g["lang"] == "vi" else ""
        rows.append('  <url><loc>https://tidymint.app/%s%s/</loc><lastmod>%s</lastmod></url>' % (pre, g["slug"], g["date"]))
    return ('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" '
            'xmlns:xhtml="http://www.w3.org/1999/xhtml">\n' + "\n".join(rows) + "\n</urlset>\n")

HUB = {
 "vi": dict(slug="huong-dan", title="Hướng dẫn dọn dẹp và tăng dung lượng Mac | Tidymint", crumb="Hướng dẫn",
            h1="Hướng dẫn giữ máy Mac gọn gàng", desc="Các bài hướng dẫn dọn dẹp MacBook, gỡ ứng dụng và lấy lại dung lượng trên Mac, viết dễ hiểu, có nguồn chính thức.",
            lead='<p class="lead" style="margin-top:6px">Bài viết dễ hiểu, có nguồn chính thức, chỉ cách làm tay trước rồi mới gợi ý công cụ.</p>'),
 "en": dict(slug="guides", title="Mac Cleanup and Storage Guides | Tidymint", crumb="Guides",
            h1="Guides to a tidy Mac", desc="Plain-language guides to clearing System Data, freeing up space and uninstalling apps on macOS, with official sources.",
            lead='<p class="lead" style="margin-top:6px">Plain-language guides with official sources. Manual steps first, tools second.</p>'),
}
# Guide topics, in display order. A guide without "topic" lands in "disk".
TOPICS = [
    ("start", "Bắt đầu", "Getting started"),
    ("disk", "Hiểu ổ đĩa Mac", "Understanding your Mac's disk"),
    ("apps", "Dọn theo từng app", "App by app"),
    ("compare", "So sánh app dọn máy", "Cleaner apps compared"),
]
SEARCH_JS = """<script>
(function(){var q=document.getElementById('gq');if(!q)return;var cards=[].slice.call(document.querySelectorAll('.rel a[data-t]'));
var secs=[].slice.call(document.querySelectorAll('.gsec'));var none=document.getElementById('gnone');
function norm(s){return s.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'');}
q.addEventListener('input',function(){var v=norm(q.value.trim());var n=0;
cards.forEach(function(c){var hit=!v||norm(c.getAttribute('data-t')).indexOf(v)>-1;c.style.display=hit?'':'none';if(hit)n++;});
secs.forEach(function(s){s.style.display=s.querySelector('.rel a:not([style*="none"])')?'':'none';});
if(none)none.style.display=n?'none':'';});})();
</script>"""
def hubpage(k):
    h = dict(HUB[k]); items = [g for g in C.GUIDES if g["lang"] == k]
    ph = "Tìm bài: Zalo, System Data, Adobe..." if k == "vi" else "Search guides: Zalo, System Data, Adobe..."
    body = '<p class="gsearch"><input id="gq" type="search" placeholder="%s" aria-label="%s"></p>' % (ph, ph)
    body += '<p id="gnone" class="small" style="display:none">%s</p>' % ("Không có bài nào khớp." if k == "vi" else "No guide matches.")
    for tid, tvi, ten in TOPICS:
        grp = sorted([g for g in items if g.get("topic", "disk") == tid], key=lambda g: g["date"], reverse=True)
        if not grp: continue
        cards = "".join('<a href="../%s/" data-t="%s"><b>%s</b><br><span class="small">%s</span></a>'
                        % (g["slug"], html.escape(g["h1"] + " " + g["desc"], quote=True), g["h1"], g["desc"]) for g in grp)
        body += '<div class="gsec"><h2>%s</h2><div class="rel">%s</div></div>' % (tvi if k == "vi" else ten, cards)
    body += SEARCH_JS
    h.update(lang=k, date=max(g["date"] for g in C.GUIDES), hub=True, read="", tldr="", toc=[], faq=[], sources=[],
             body=body, alt=("guides" if k == "vi" else "huong-dan"))
    return h

CL = {
 "vi": dict(slug="lich-su-cap-nhat", title="Lịch sử cập nhật Tidymint", crumb="Lịch sử cập nhật",
            h1="Lịch sử cập nhật", desc="Những gì thay đổi qua từng bản Tidymint, bản mới nhất ở trên cùng.",
            next="Đang làm cho bản", dl="Tải bản mới nhất", alt="changelog"),
 "en": dict(slug="changelog", title="Tidymint Changelog", crumb="Changelog",
            h1="Changelog", desc="What changed in each Tidymint release, newest first.",
            next="In progress for", dl="Download the latest", alt="lich-su-cap-nhat"),
}
def changelogpage(k):
    import changelog as CLG
    h = dict(CL[k]); parts = []
    for r in CLG.RELEASES:
        head = "%s %s" % (h["next"], r["ver"]) if r["status"] == "next" else "%s <span class=\"small\">(%s)</span>" % (r["ver"], r["date"])
        parts.append("<h2>%s</h2><ul>%s</ul>" % (head, "".join("<li>%s</li>" % x for x in r[k])))
    body = "".join(parts) + '<p><a class="btn" href="%s">%s</a></p>' % (S.DL, h["dl"])
    dates = [r["date"] for r in CLG.RELEASES if r["date"]]
    h.update(lang=k, date=max(dates), hub=True, read="", tldr="", toc=[], faq=[], sources=[], body=body, lead="")
    return h

if __name__ == "__main__":
    for k in ("vi", "en"):
        h = changelogpage(k)
        out = os.path.join(ROOT, "docs", "vi" if k == "vi" else "", h["slug"], "index.html")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        open(out, "w").write(stamp(guide(h), out, ROOT)); print("wrote", os.path.relpath(out, ROOT))
    for k in ("vi", "en"):
        h = hubpage(k)
        out = os.path.join(ROOT, "docs", "vi" if k == "vi" else "", h["slug"], "index.html")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        open(out, "w").write(stamp(guide(h), out, ROOT)); print("wrote", os.path.relpath(out, ROOT))
    for g in C.GUIDES:
        out = os.path.join(ROOT, "docs", "vi" if g["lang"] == "vi" else "", g["slug"], "index.html")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        open(out, "w").write(stamp(guide(g), out, ROOT))
        print("wrote", os.path.relpath(out, ROOT))
    open(os.path.join(ROOT, "docs", "sitemap.xml"), "w").write(sitemap(C.GUIDES))
    print("wrote docs/sitemap.xml")
