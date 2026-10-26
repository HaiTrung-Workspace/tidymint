#!/usr/bin/env python3
"""Generate guide pages (docs/<lang>/<slug>/index.html) and refresh sitemap.xml.
Content lives in tools/guides_content.py. Run from the repository root: python3 tools/guides.py"""
import importlib.util, json, os, html, datetime

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
            nav=[("../#tinh-nang","Tính năng"),("../#cach-dung","Cách dùng"),("../#hoi-dap","Hỏi đáp"),(S.GH,"GitHub")]),
 "en": dict(home="../", homename="Home", guides="Guides", updated="Updated", tldr="Quick answer",
            toc="On this page", faq="FAQ", src="Sources", rel="Read next",
            cta_h="Clean your Mac for free", cta_p="Tidymint is free and open source. Everything goes to the Trash first, so you stay in control.",
            cta_btn="Download Tidymint", cta_more="How to install", inst="#install",
            nav=[("../#features","Features"),("../#how","How it works"),("../#faq","FAQ"),(S.GH,"GitHub")]),
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
    hreflang = '<link rel="alternate" hreflang="%s" href="%s">' % (k, url)
    if alt:
        ok = "en" if k == "vi" else "vi"
        hreflang += '<link rel="alternate" hreflang="%s" href="https://tidymint.app/%s%s/">' % (ok, "vi/" if ok == "vi" else "", alt)
    d = datetime.date.fromisoformat(g["date"])
    dstr = d.strftime("%d/%m/%Y") if k == "vi" else d.strftime("%B %-d, %Y")
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
<meta property="og:type" content="article">
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
  <a class="brand" href="{home}"><img src="{root}icon.png" alt="">Tidymint</a>
  <div class="navr"><div class="links">{nav}</div><a class="btn primary navcta" href="{S.DL}">{t["navcta"]}</a><div class="lang" role="group" aria-label="{t["aria_lang"]}"><a {vi_on}href="{vi_href}" data-l="vi">VI</a><a {en_on}href="{en_href}" data-l="en">EN</a></div></div>
</nav></div></div>
<div class="wrap">
<article class="art">
  <p class="crumb"><a href="{home}">{l["homename"]}</a> › {g["crumb"]}</p>
  <h1>{g["h1"]}</h1>
  <p class="meta">{l["updated"]}: {dstr} · {g["read"]}</p>
  <div class="tldr"><span class="k">{l["tldr"]}</span><p>{g["tldr"]}</p></div>
  <div class="toc" role="navigation" aria-label="{l["toc"]}"><b>{l["toc"]}</b><ol>{toc}</ol></div>
  {body}
  <h2 id="faq">{l["faq"]}</h2>
  {faq}
  {cta}
  <h2>{l["src"]}</h2>
  <ul class="src">{srcs}</ul>
  {"<h2>%s</h2><div class=\"rel\">%s</div>" % (l["rel"], rel) if rel else ""}
</article>
<div class="topbar"><a href="#top" id="toTop">↑ {t["top"]}</a></div>
<div class="fcols">
  <div><a class="brand" href="{home}"><img src="{root}icon.png" alt="">Tidymint</a><p>{t["f_blurb"]}</p></div>
  {fcols}
</div>
<footer><span>{t["copy"]}{t["extra_footer"]} · <button class="linkbtn" id="ckOpen" type="button">{t["ck_link"]}</button></span></footer>
</div>
<button class="up" id="up" type="button" aria-label="{t["top"]}">↑ {t["top"]}</button>
<div class="ck" id="ck" role="dialog" aria-live="polite"><p>{t["ck_text"]} <a href="{S.GH}/blob/main/PRIVACY.md">{t["ck_more"]}</a></p><div class="row"><button class="yes" id="ckY" type="button">{t["ck_yes"]}</button><button id="ckN" type="button">{t["ck_no"]}</button></div></div>
<script>
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
    for g in guides:
        pre = "vi/" if g["lang"] == "vi" else ""
        rows.append('  <url><loc>https://tidymint.app/%s%s/</loc><lastmod>%s</lastmod></url>' % (pre, g["slug"], g["date"]))
    return ('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" '
            'xmlns:xhtml="http://www.w3.org/1999/xhtml">\n' + "\n".join(rows) + "\n</urlset>\n")

if __name__ == "__main__":
    for g in C.GUIDES:
        out = os.path.join(ROOT, "docs", "vi" if g["lang"] == "vi" else "", g["slug"], "index.html")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        open(out, "w").write(guide(g))
        print("wrote", os.path.relpath(out, ROOT))
    open(os.path.join(ROOT, "docs", "sitemap.xml"), "w").write(sitemap(C.GUIDES))
    print("wrote docs/sitemap.xml")
