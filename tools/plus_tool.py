"""The "Free and Plus" section at the end of each Mint tool's guide (guides.py).

Rows, numbers and the price come from plus_page.py, so a tool's guide and the Plus page cannot drift. What is free goes
first, then the limits Plus lifts, then what Plus adds in the Plus page's order (by demand): the first few in view, the
rest in a drop-down. Mintsort has no guide and no free part: it is only on the Plus page."""
import html

import plus_page as P

SHOWN = 3   # Plus-only rows in view before the drop-down

PAGES = {  # (lang, slug): tool
    ("vi", "mintangle-xep-cua-so-mac"): "mintangle", ("en", "mintangle-window-tiling-mac"): "mintangle",
    ("vi", "mintclip-lich-su-clipboard-mac"): "mintclip", ("en", "mintclip-clipboard-history-mac"): "mintclip",
    ("vi", "mintbar-gon-thanh-menu-mac"): "mintbar", ("en", "mintbar-tidy-menu-bar-mac"): "mintbar",
    ("vi", "mintdrop-ke-tha-file-mac"): "mintdrop", ("en", "mintdrop-drop-shelf-mac"): "mintdrop",
}

T = {
"vi": dict(id="mien-phi-va-plus", h="Miễn phí và Plus", more="Xem thêm %d tính năng Plus",
  lead=dict(mintangle="Chia đôi và 4 góc là miễn phí. Plus dành cho lúc bạn cần chia ba hoặc có nhiều màn hình.",
            mintclip="Lưu, tìm và dán lại là miễn phí. Plus dành cho lúc bạn cần dán sạch định dạng hoặc giữ nhiều hơn.",
            mintbar="Gom vào 2 nhóm là miễn phí. Plus dành cho lúc menu bar của bạn cần nhiều hơn thế.",
            mintdrop="Gom 5 món và kéo từng món là miễn phí. Plus dành cho lúc bạn cần kéo hay xử lý cả nhóm."),
  price="%s Plus: <b>%s</b>, mua một lần", sub="Dùng thử 14 ngày, không cần thẻ. Trọn gói 5 công cụ: %s.", btn="Xem giá %s Plus",
  q="%s có miễn phí không?",
  a=dict(mintangle="Có. 11 thao tác cơ bản và kéo vào mép là miễn phí, không hết hạn. Mintangle Plus có 24 thao tác, thêm chia ba và lưu bố cục.",
         mintclip="Có. Mintclip miễn phí giữ 100 mục, không hết hạn. Mintclip Plus giữ 500 mục, thêm ghim và dán không kèm định dạng.",
         mintbar="Có. Mintbar miễn phí có 2 nhóm, mỗi nhóm 4 app, không hết hạn. Mintbar Plus không giới hạn nhóm và app.",
         mintdrop="Có. Kệ miễn phí giữ 5 món, không hết hạn. Mintdrop Plus không giới hạn số món, thêm kéo cả nhóm và đổi định dạng ảnh.")),
"en": dict(id="free-and-plus", h="Free and Plus", more="See %d more Plus features",
  lead=dict(mintangle="Halves and the four corners are free. Plus is for when you need thirds or use several displays.",
            mintclip="Keeping, finding and pasting back are free. Plus is for clean pasting and a longer history.",
            mintbar="Two groups are free. Plus is for when your menu bar needs more than that.",
            mintdrop="Gathering 5 items and dragging each out is free. Plus is for handling the whole group at once."),
  price="%s Plus: <b>%s</b>, one-time", sub="Try it for 14 days, no card needed. All five tools: %s.", btn="See %s Plus price",
  q="Is %s free?",
  a=dict(mintangle="Yes. The 11 basic actions and drag to an edge are free, with no time limit. Mintangle Plus has 24 actions, adding thirds and saved layouts.",
         mintclip="Yes. Free Mintclip keeps 100 items, with no time limit. Mintclip Plus keeps 500, adding pins and paste without formatting.",
         mintbar="Yes. Free Mintbar has 2 groups of 4 apps, with no time limit. Mintbar Plus has no limit on groups or apps.",
         mintdrop="Yes. The free shelf holds 5 items, with no time limit. Mintdrop Plus has no limit, and adds drag all at once and image conversion.")),
}

CSS = """
.art .fp-t{margin:18px 0 0;border:1px solid var(--line);border-radius:14px;overflow:hidden;font-size:15px;line-height:1.4}
.art .fp-r{display:grid;grid-template-columns:minmax(0,1fr) 120px 152px;align-items:center;border-top:1px solid var(--line)}
.art .fp-r:first-child{border-top:0}
.art .fp-r>span{padding:11px 14px;min-width:0}
.art .fp-r .v{align-self:stretch;display:flex;align-items:center;justify-content:center;text-align:center;font-weight:600;color:var(--text)}
.art .fp-r .p{background:#2fd39f12;color:var(--leaf)}
.art .fp-r .no{color:var(--sub);font-weight:400}
.art .fp-r svg{color:var(--leaf)}
.art .fp-h{background:#ffffff0d;font-size:13px;font-weight:700}
.art .fp-h>span{font-weight:700!important}
.art .fp-t details{margin:0;padding:0;border:0;border-top:1px solid var(--line);border-radius:0;background:none}
.art .fp-t summary{margin:0;padding:12px 14px;color:var(--leaf);font-size:15px;font-weight:600;cursor:pointer}
.art .fp-t details[open] summary{border-bottom:1px solid var(--line)}
.art .fp-buy{display:flex;align-items:center;justify-content:space-between;gap:12px 20px;flex-wrap:wrap;margin:18px 0 8px}
.art .fp-buy p{margin:0}
.art .fp-buy small{display:block;color:var(--sub);font-size:14px;margin-top:2px}
.art .fp-buy .btn{flex:none;white-space:nowrap}
.art .sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}
@media (max-width:600px){
 .art .fp-t{font-size:14px}
 .art .fp-r{grid-template-columns:minmax(0,1fr) 76px 92px}
 .art .fp-r>span{padding:10px 8px}
 .art .fp-h{font-size:12px}
 .art .fp-buy .btn{width:100%;justify-content:center}
}
"""


def _money(p, value):
    return value + (" " + p["cur"] if p["cur"] else "")


def section(lang, key, ids, home):
    """HTML of the section. ids: the guide's own anchors, so its id never repeats."""
    t, p = T[lang], P.T[lang]
    name = next(n for k, n, _ in P.TOOLS if k == key)
    items = next(i for k, _, i in p["groups"] if k == key)
    if t["id"] in ids:
        raise SystemExit("STOP: %s already has #%s" % (key, t["id"]))
    had = [r for r in items if r[1] is P.Y]
    limits = [r for r in items if r[1] is not P.Y and r[1] is not P.N]
    adds = [r for r in items if r[1] is P.N]
    ok = P.S.icon("check", 16)

    def cell(v, cls=""):
        if v is P.Y:
            inner = '%s<span class="sr">%s</span>' % (ok, p["yes"])
        else:
            inner = p["no"] if v is P.N else v.replace("giới hạn", "giới\u00a0hạn")
        return '<span class="v%s%s" role="cell">%s</span>' % (cls, " no" if v is P.N else "", inner)

    def row(r):
        return '<div class="fp-r" role="row"><span role="rowheader">%s</span>%s%s</div>' % (r[0], cell(r[1]), cell(r[2], " p"))

    head = ('<div class="fp-r fp-h" role="row"><span role="columnheader">%s</span><span class="v" role="columnheader">%s</span>'
            '<span class="v p" role="columnheader">%s</span></div>') % (p["feature"], p["cols"][1], p["cols"][2])
    rest = adds[SHOWN:]
    return ('<style>%s</style><h2 id="%s">%s</h2><p>%s</p>'
            '<div class="fp-t" role="table" aria-label="%s">%s%s<details><summary>%s</summary>%s</details></div>'
            '<div class="fp-buy"><p>%s<small>%s</small></p><a class="btn ghost" href="%splus/?tu=%s">%s <span class="arr r">→</span></a></div>') % (
        CSS, t["id"], t["h"], t["lead"][key],
        html.escape("%s: %s" % (name, t["h"])), head, "".join(map(row, had + limits + adds[:SHOWN])), t["more"] % len(rest), "".join(map(row, rest)),
        t["price"] % (name, _money(p, p["single_price"])), t["sub"] % _money(p, p["full_price"]), home, key, t["btn"] % name)


def extend(g):
    """A tool's guide with its section, contents line and question; any other guide unchanged."""
    key = PAGES.get((g["lang"], g["slug"]))
    if not key:
        return g
    if "{CTA}" in g["body"]:
        raise SystemExit("STOP: %s places the download box itself; choose where Free and Plus goes" % g["slug"])
    t = T[g["lang"]]
    name = next(n for k, n, _ in P.TOOLS if k == key)
    toc = list(g["toc"])
    toc.insert(-1 if toc and toc[-1][0] == "faq" else len(toc), (t["id"], t["h"]))
    return dict(g, body=g["body"] + section(g["lang"], key, [i for i, _ in g["toc"]], "{HOME}"), toc=toc,
                faq=[(t["q"] % name, t["a"][key])] + list(g["faq"]))
