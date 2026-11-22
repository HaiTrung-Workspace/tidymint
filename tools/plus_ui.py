"""Drawing kit for the animated scenes of the Plus page (plus_scenes.py).

A scene is a Mac screen 720 x 450 points. Sizes are written in those points ("26p") and come out as cqw, so a scene is
the same picture at any width and text stays sharp. Panels, rows and tiles use the app's own measures (read from
dev/0.6.0-mintbar, 22/11/2026): check the Swift before changing one.

A scene moves in steps. Each element has a base style and, per mode (free, plus), what changes from a step on; the page's
script only adds the classes s1, s2... one after another, and CSS transitions do the moving."""
import os
import re

LOGO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "logo.svg")
W, H = 720, 450
ON, OFF = "opacity:1", "opacity:0"
_P = re.compile(r"(?<![\w#.-])(-?(?:\d*\.)?\d+)p\b")


def px(style):
    """Points to cqw."""
    return _P.sub(lambda m: "0" if float(m.group(1)) == 0 else ("%.3f" % (float(m.group(1)) * 100 / W)).rstrip("0").rstrip(".") + "cqw", style)


def box(x, y, w=None, h=None):
    s = "left:%sp;top:%sp" % (round(x, 1), round(y, 1))
    if w is not None: s += ";width:%sp" % round(w, 1)
    if h is not None: s += ";height:%sp" % round(h, 1)
    return s


def flow(inner, style="", cls=""):
    """A plain child that never changes."""
    return '<span class="%s" style="%s">%s</span>' % (cls, px(style), inner)


class Scene:
    def __init__(self, key, times):
        """times: {mode: [ms from the start for step 1, step 2, ...]}"""
        self.key, self.times, self.css, self.n = key, times, [], 0

    def el(self, style, inner="", free=None, plus=None, both=None, cls="", fixed=True):
        """fixed=False: the element flows in its parent instead of standing at left/top."""
        self.n += 1
        name = "%s%d" % (self.key, self.n)
        self.css.append(".%s{%s}" % (name, px(style)))
        for mode, own in (("free", free), ("plus", plus)):
            steps = dict(both or {})
            for step, st in (own or {}).items():
                steps[step] = steps[step] + ";" + st if step in steps else st
            for step in sorted(steps):
                if step > len(self.times[mode]):
                    if own and step in own:
                        raise SystemExit("STOP: scene %s: %s step %d has no time" % (self.key, mode, step))
                    continue
                at = ".s%d" % step if step else ""
                self.css.append("[data-mode=%s] .sc-%s%s .%s{%s}" % (mode, self.key, at, name, px(steps[step])))
        return '<div class="%s %s%s">%s</div>' % ("a" if fixed else "f", name, " " + cls if cls else "", inner)

    def icon(self, name, size, style="", colour=None, **kw):
        return self.el(style + ";width:%sp;height:%sp" % (size, size) + (";color:%s" % colour if colour else ""), svg(name), **kw)

    def pointer(self, at, free=None, plus=None):
        """The macOS pointer. Steps: (x, y) or (x, y, 'down') while the button is held."""
        def track(steps):
            return {k: box(v[0] - 2, v[1] - 1) + (";transform:scale(.82)" if len(v) > 2 else ";transform:none") for k, v in (steps or {}).items()}
        return self.el(box(at[0] - 2, at[1] - 1, 17, 23) + ";z-index:95;transform-origin:0 0", svg("pointer"),
                       free=track(free), plus=track(plus), cls="ptr")

    def click(self, x, y, free=(), plus=()):
        """A ring where a click lands, for one step."""
        def track(steps):
            out = {}
            for s in steps:
                out[s] = "opacity:1;transform:scale(1)"
                out.setdefault(s + 1, "opacity:0;transform:scale(1.5)")
            return out
        f = {k: v for k, v in track(free).items() if k <= len(self.times["free"])}
        p = {k: v for k, v in track(plus).items() if k <= len(self.times["plus"])}
        return self.el(box(x - 13, y - 13, 26, 26) + ";border-radius:50%;border:2p solid var(--leaf);opacity:0;transform:scale(.4);z-index:94", free=f, plus=p)

    def keys(self, x, y, text, free=None, plus=None):
        """Key caps shown while the keys are pressed."""
        caps = "".join(flow(k, cls="cap-key") for k in text.split())
        return self.el(box(x, y) + ";display:flex;gap:5p;opacity:0;transform:translate(-50%,0);z-index:90", caps, free=free, plus=plus)

    def stage(self, body, free=None, plus=None):
        """The screen. Camera steps: (zoom, centre x, centre y), kept inside the screen."""
        def cam(steps):
            out = {}
            for k, (z, x, y) in (steps or {}).items():
                tx = min(0, max(W - z * W, W / 2 - z * x))
                ty = min(0, max(H - z * H, H / 2 - z * y))
                out[k] = "transform:translate(%sp,%sp) scale(%s)" % (round(tx, 1), round(ty, 1), z)
            return out
        camera = self.el("left:0;top:0;width:720p;height:450p;transform-origin:0 0;transform:none", body, free=cam(free), plus=cam(plus), cls="cam")
        last = " ".join("s%d" % (i + 1) for i in range(len(self.times["plus"])))
        return '<div class="sc sc-%s %s" data-free="%s" data-plus="%s">%s</div>' % (
            self.key, last, ",".join(map(str, self.times["free"])), ",".join(map(str, self.times["plus"])), camera)


# line icons, 24 x 24, in the manner of the SF Symbols the app uses
LINE = {
    "wifi": '<path d="M3 9a13 13 0 0 1 18 0M6.5 12.800a8 8 0 0 1 11 0M10 16.500a3 3 0 0 1 4 0"/><circle cx="12" cy="19" r="1" fill="currentColor"/>',
    "battery": '<rect x="2" y="7" width="18" height="10" rx="3"/><rect x="4" y="9" width="11" height="6" rx="1.500" fill="currentColor" stroke="none"/><path d="M22 11v2"/>',
    "clip": '<path d="m20 11-8.500 8.500a5 5 0 0 1-7-7l9-9a3.400 3.400 0 0 1 5 5l-9 9a1.700 1.700 0 0 1-2.500-2.500L15 7"/>',
    "search": '<circle cx="10.500" cy="10.500" r="6.500"/><path d="m16 16 5 5"/>',
    "filter": '<path d="M4 7h16M7 12h10M10 17h4"/>',
    "lines": '<path d="M4 7h16M4 12h16M4 17h16"/>',
    "text": '<path d="M4 6h16M4 10h10M4 14h16M4 18h8"/>',
    "link": '<path d="M10 14a4 4 0 0 0 6 0l4-4a4 4 0 0 0-6-6l-1.500 1.500M14 10a4 4 0 0 0-6 0l-4 4a4 4 0 0 0 6 6l1.500-1.500"/>',
    "pin": '<path d="M9 3h6M10 3v6l-3.500 4v1h11v-1L14 9V3M12 14v7"/>',
    "pinned": '<path d="M9 3h6l-1 1v5l3.500 4v1h-11v-1L10 9V4z" fill="currentColor"/><path d="M12 14v7"/>',
    "x": '<path d="M6 6l12 12M18 6 6 18"/>',
    "plus": '<path d="M12 5v14M5 12h14"/>',
    "minus": '<circle cx="12" cy="12" r="9"/><path d="M8 12h8"/>',
    "trash": '<path d="M4 7h16M9 7V4h6v3M6 7l1 14h10l1-14M10 11v6M14 11v6"/>',
    "hand": '<path d="M8 13V6a1.500 1.500 0 0 1 3 0v5-1a1.500 1.500 0 0 1 3 0v1a1.500 1.500 0 0 1 3 0v1a1.500 1.500 0 0 1 3 0v4a6 6 0 0 1-6 6h-1a6 6 0 0 1-5-2.500L5 15a1.500 1.500 0 0 1 3-2"/>',
    "tray": '<path d="M3 13l3-8h12l3 8v6H3zM3 13h5c0 2 2 3 4 3s4-1 4-3h5"/>',
    "drop": '<path d="M7 3h7l4 4v14H6V3zM12 9v8M9 14l3 3 3-3"/>',
    "right": '<path d="m9 5 7 7-7 7"/>',
    "down": '<path d="m5 9 7 7 7-7"/>',
    "check": '<path d="m5 12.500 4.500 4.500L19 7"/>',
    "done": '<circle cx="12" cy="12" r="10" fill="currentColor" stroke="none"/><path d="m7.500 12.500 3 3 6-6.500" stroke="#06241b"/>',
    "folder": '<path d="M3 19V6a1 1 0 0 1 1-1h5l2 2h9a1 1 0 0 1 1 1v11zM3 10h18"/>',
    "photo": '<rect x="3" y="4" width="18" height="16" rx="3"/><circle cx="9" cy="9.500" r="1.800"/><path d="m4 18 5-5 3 3 4-5 5 6"/>',
    "doc": '<path d="M6 2.500h8l4 4v15H6zM14 2.500v4h4M9 12h6M9 16h6"/>',
    "box": '<path d="M3 8l9-5 9 5v9l-9 5-9-5zM3 8l9 5 9-5M12 13v9"/>',
    "sparkles": '<path d="M11 5l2 5 5 2-5 2-2 5-2-5-5-2 5-2zM19 3v4M17 5h4"/>',
    "grid": '<rect x="4" y="4" width="6.500" height="6.500" rx="1"/><rect x="13.500" y="4" width="6.500" height="6.500" rx="1"/><rect x="4" y="13.500" width="6.500" height="6.500" rx="1"/><rect x="13.500" y="13.500" width="6.500" height="6.500" rx="1"/>',
    "halves": '<rect x="3" y="4" width="18" height="16" rx="3"/><rect x="5.500" y="6.500" width="6" height="11" rx="1" fill="currentColor" stroke="none"/>',
    "dots": '<rect x="2.500" y="6" width="19" height="12" rx="3"/><path d="M7 12h.01M12 12h.01M17 12h.01"/>',
    "sorted": '<path d="M3 19V6a1 1 0 0 1 1-1h5l2 2h9a1 1 0 0 1 1 1v3M3 10h9M3 19h8"/><circle cx="17.500" cy="17" r="3"/><path d="M17.500 12.500V14M17.500 20v1.500M13 17h1.500M20.500 17H22"/>',
    "case": '<rect x="3" y="7" width="18" height="13" rx="2.500"/><path d="M9 7V4h6v3M3 12.500h18"/>',
    "globe": '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c-6 6-6 12 0 18M12 3c6 6 6 12 0 18"/>',
    "star": '<path d="m12 3 2.800 5.800 6.200.9-4.500 4.400 1 6.200-5.500-2.900-5.500 2.900 1-6.200L3 9.700l6.200-.9z" fill="currentColor"/>',
    "cloud": '<path d="M7 19a5 5 0 1 1 1-9.900A6 6 0 0 1 19.500 11 4 4 0 0 1 18 19z" fill="currentColor"/>',
    "chat": '<path d="M4 4h16v12H10l-5 4v-4H4z" fill="currentColor"/>',
    "music": '<path d="M9 18V6l11-2v12" /><circle cx="6.500" cy="18" r="2.500" fill="currentColor"/><circle cx="17.500" cy="16" r="2.500" fill="currentColor"/>',
    "shield": '<path d="M12 2.500 20 6v6c0 5-3.500 8-8 10-4.500-2-8-5-8-10V6z" fill="currentColor"/>',
    "bell": '<path d="M5 17h14l-2-3V9a5 5 0 0 0-10 0v5zM10 21h4" fill="currentColor"/>',
    "bolt": '<path d="M13 2 4 14h7l-1 8 10-13h-7z" fill="currentColor"/>',
    "cup": '<path d="M4 8h13v6a6 6 0 0 1-6 6h-1a6 6 0 0 1-6-6zM17 10h2a2 2 0 0 1 0 5h-2M8 2v3M12 2v3"/>',
    "calendar": '<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M3 10h18M8 2v5M16 2v5"/>',
    "camera": '<path d="M3 7h4l2-3h6l2 3h4v13H3z"/><circle cx="12" cy="13" r="4"/>',
    "send": '<path d="M21 3 3 10.500l7 3 3 7z" fill="currentColor"/>',
    "atom": '<circle cx="12" cy="12" r="1.600" fill="currentColor"/><ellipse cx="12" cy="12" rx="10" ry="3.800"/><ellipse cx="12" cy="12" rx="10" ry="3.800" transform="rotate(60 12 12)"/><ellipse cx="12" cy="12" rx="10" ry="3.800" transform="rotate(120 12 12)"/>',
    "cycle": '<path d="M4 12a8 8 0 0 1 14-5.300L20 9M20 4v5h-5M20 12a8 8 0 0 1-14 5.300L4 15M4 20v-5h5"/>',
    "hammer": '<path d="M3 8c3-5 9-6 13-3l4 4-3 3-3-3c-3-1-7-1-11-1zM12.500 10 5 19.500l2.500 2L15 12" fill="currentColor"/>',
    "monitor": '<rect x="2" y="3" width="20" height="14" rx="2.500"/><path d="M12 17v4M8 21h8"/>',
    "tools": '<path d="m5 3 4 4v2l-2 2H5L2 7M9 9l11 11M19 3l2 2-4 5M15 11 5 21l-2-2 10-10"/>',
    "bluetooth": '<path d="m6 7 12 10-6 5V2l6 5L6 17"/>',
    "mirror": '<rect x="2" y="3" width="15" height="12" rx="2"/><rect x="8" y="9" width="14" height="11" rx="2"/>',
    "displays": '<path d="M9 5H5a3 3 0 0 0-3 3v8a3 3 0 0 0 3 3h4M15 5h4a3 3 0 0 1 3 3v8a3 3 0 0 1-3 3h-4M12 2v20"/><path d="m16 10 4 4h-4z" fill="currentColor"/>',
    "keys": '<circle cx="6" cy="7" r="4"/><circle cx="17" cy="7" r="4"/><path d="M6 11v10l2-2M17 11v10l2-2M11.500 11v8"/>',
    "input": '<rect x="1.500" y="4" width="21" height="16" rx="4"/><path d="m6 9 2.500 6L11 9M15.500 9v6"/>',
    "siri": '<circle cx="12" cy="12" r="9"/><path d="M4 14c4-7 12 3 16-4"/>',
    "timer": '<circle cx="12" cy="13" r="8"/><path d="M12 9v4l3 2M9 2h6"/>',
}


def svg(name):
    if name == "pointer":
        return '<svg viewBox="0 0 17 23"><path d="M1.500 1v17.500l4.300-4 2.900 7 3.100-1.300-2.900-6.800h5.800z" fill="#000" stroke="#fff" stroke-width="1.400"/></svg>'
    if name == "leaf":
        return '<svg viewBox="0 0 845 1311"><use href="#tm-leaf"/></svg>'
    return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.900" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % LINE[name]


def leaf_mark():
    """The app's leaf, taken from the site's logo, once per page; icons point to it."""
    path = re.search(r'<path fill="[^"]*" d="([^"]+)"', open(LOGO).read())
    if not path:
        raise SystemExit("STOP: no leaf path in %s" % LOGO)
    return ('<svg width="0" height="0" style="position:absolute" aria-hidden="true" focusable="false">'
            '<path id="tm-leaf" fill="currentColor" d="%s"/></svg>') % path.group(1).replace(".0 ", " ")


def ic(name, size=12, style=""):
    """An icon that flows with the text beside it."""
    return flow(svg(name), "width:%sp;height:%sp;%s" % (size, size, style), "ic")


def lights():
    return flow("<i></i><i></i><i></i>", cls="lights")


def menubar(app, right=""):
    """Left half of the menu bar; each scene puts its own icons on the right."""
    return ('<div class="a bar" style="%s">%s%s%s</div>%s' % (
        px("left:0;top:0;width:720p;height:24p"), ic("leaf", 13, "color:#fff"), flow(app, "font-weight:700"),
        flow("File") + flow("Edit"), right))


def status_icons(clock="9:30", wifi=True):
    return ('<div class="a tray" style="%s">%s%s%s</div>' % (
        px("right:10p;top:0;height:24p"), ic("wifi", 14) if wifi else "", ic("battery", 17), flow(clock)))


CSS = px("""
.screen{container-type:inline-size;width:100%}
.sc{position:relative;aspect-ratio:16/10;overflow:hidden;border-radius:14p;outline:1px solid #ffffff29;outline-offset:-1px;color:#fff;text-align:left;font-size:12p;line-height:1.22;
font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","Segoe UI",Roboto,sans-serif;user-select:none;-webkit-user-select:none}
.sc .a,.sc .f,.sc .a span,.sc .f span{box-sizing:border-box}
.sc .a{position:absolute;transition:left .55s cubic-bezier(.3,.8,.3,1),top .55s cubic-bezier(.3,.8,.3,1),width .5s cubic-bezier(.3,.8,.3,1),height .5s cubic-bezier(.3,.8,.3,1),opacity .28s ease,transform .5s cubic-bezier(.3,.8,.3,1),background-color .3s ease,color .3s ease,border-color .3s ease}
.sc .f{position:relative;transition:opacity .28s ease,background-color .3s ease,color .3s ease}
.sc .cam{overflow:hidden;transition:transform .8s cubic-bezier(.4,0,.2,1);background:radial-gradient(560p 380p at 8% 108%,#2fa77d,transparent 70%),radial-gradient(430p 340p at 102% 4%,#1c6680,transparent 72%),radial-gradient(300p 240p at 62% 72%,#14604a,transparent 75%),linear-gradient(160deg,#06251f,#0b3529)}
.sc .ptr{transition:left .6s cubic-bezier(.45,.05,.3,1),top .6s cubic-bezier(.45,.05,.3,1),transform .12s ease;filter:drop-shadow(0 1p 2p #0008)}
.sc svg{display:block;width:100%;height:100%}
.sc .ic{display:inline-block;flex:none;vertical-align:middle}
.sc .bar{display:flex;align-items:center;gap:14p;padding:0 12p;background:#05261dd9;font-size:12p;white-space:nowrap;z-index:70}
.sc .tray{display:flex;align-items:center;gap:10p;z-index:71;font-size:12p;white-space:nowrap}
.sc .lights{display:inline-flex;flex:none;gap:6p}
.sc .lights i{width:9p;height:9p;border-radius:50%;background:#ff5f57}
.sc .lights i+i{background:#febc2e}
.sc .lights i+i+i{background:#28c840}
.sc .win{overflow:hidden;border-radius:11p;background:#f7f8f8;color:#24302c;box-shadow:0 10p 26p #0007,0 0 0 .6p #0006}
.sc .win.dk{background:#1b211f;color:#eef4f2;box-shadow:0 10p 26p #0008,0 0 0 .6p #ffffff30}
.sc .tbar{display:flex;align-items:center;gap:10p;height:28p;padding:0 10p;border-bottom:.6p solid #00000018;background:#e9ebeb;font-size:11p;font-weight:700;white-space:nowrap;overflow:hidden}
.sc .dk .tbar{background:#262d2b;border-color:#ffffff14}
.sc .glass{background:linear-gradient(145deg,#142b25f5,#081411f7);border:.8p solid #ffffff2b;box-shadow:0 12p 30p #0007;-webkit-backdrop-filter:blur(14p);backdrop-filter:blur(14p)}
.sc .app{background:linear-gradient(135deg,#030c09,#061712 55%,#0a2a21);color:#fff}
.sc .t{white-space:nowrap}
.sc .cut{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.sc .sub{color:#ffffff9e}
.sc .mint{color:#5ff0c0}
.sc .row{display:flex;align-items:center;white-space:nowrap}
.sc .mid{display:flex;align-items:center;justify-content:center;white-space:nowrap}
.sc .cap-key{display:flex;align-items:center;justify-content:center;min-width:27p;height:27p;padding:0 7p;border-radius:7p;background:#f4f7f6;color:#10201b;box-shadow:0 2p 0 #8fa59e,0 5p 12p #0007;font-size:13p;font-weight:700;white-space:nowrap}
.sc.now .a,.sc.now .f{transition:none!important}
""") + """
@media (prefers-reduced-motion:reduce){.sc .a,.sc .f{transition:none!important}}
"""
