"""The five flows of the Plus page, one function per tool (kit: plus_ui.py; words around them: plus_scenes.py).

Each flow starts from the pain with the most searches (research/2026-11-22_thu-tu-tinh-nang-plus.md), then goes on with
the Plus features that follow in one movement of the hand. Free plays what the free app really does, up to its limit."""
import base64
import colorsys
import math
import os

from plus_ui import OFF, ON, Scene, box, flow, ic, lights, menubar, status_icons, svg

T = {
"vi": dict(
  doc="Kế hoạch tháng 12", sheet="Chi phí", chat="Trò chuyện", let_go="Thả vào một ô để xếp", third="1/3 bên trái",
  saved="Đã lưu “Bố cục 1”: 3 cửa sổ", chat_lines=("Xong bảng chưa?", "Đang làm", "Gửi mình nhé", "5 phút nữa"),
  web="Trang web", web_head="Tin nội bộ", copied="Họp lúc 9:30 thứ Hai", note="Ghi chú",
  search="Tìm", kinds=("Tất cả", "Chữ", "Link", "File", "Ảnh"), clips=("tidymint.app", "Mã đơn 2048", "#5FF0C0", "bao-gia.pdf", "Ảnh 640 × 400"),
  from_="Từ Safari · vừa xong", board="Bảng", edit="Sửa", pause="Tạm dừng 10 phút", delete="Xoá", open_clip="Mở Mintclip",
  apps_n="3 app", code="Mã màu", cpu="CPU", ram="RAM",
  finder="Tải về", shelf_empty="Thả file vào đây", shelf_sub="Gom file về một kệ.", items="%d mục · %s MB", one="%d mục · %s MB",
  drag_all="Kéo cả %d mục đi", move="Dời vào…", quick="Làm nhanh", full="Kệ chứa tối đa 5 món. Lấy bớt ra để thả thêm.",
  locked="Dời cả nhóm một lần, mở bằng", menu=("Đổi cỡ ảnh", "Đổi định dạng ảnh", "Lấy chữ từ ảnh", "Nén thành .zip", "Hành động của tôi"),
  converted="Đã đổi 1 ảnh sang JPEG.", undo="Hoàn tác", mail="Thư mới", to="Tới: nhóm dự án", subject="Tài liệu họp thứ Hai",
  side=("Dọn ngay", "Dọn theo ứng dụng", "Gỡ app", "Thùng rác"), tools="CÔNG CỤ", nothing="Không xoá hẳn file nào.", folder="~/Tải về", choose="Chọn thư mục",
  switches=("Đọc nội dung ảnh và PDF", "Gồm cả thư mục con", "Bỏ bản trùng y hệt vào Thùng rác", "Tự xếp thư mục Tải về"), plan="Lập kế hoạch",
  only_plus="Mintsort thuộc bản Tidymint Plus.", reading=("Đang đọc 4/9", "Đang đọc 9/9"), plan_for="Kế hoạch cho Tải về (9 file)", into="Sắp xếp vào thư mục",
  creates="Tạo 3 thư mục mới trong Tải về.", edit_tab="Chỉnh sửa", preview="Xem trước", groups=("Ảnh", "Tài liệu", "Bộ cài app"), new="MỚI",
  files_n="%d file", now="BÂY GIỜ", after="SAU KHI ÁP DỤNG", selected="Đã chọn 9 file", cancel="Huỷ", apply="Áp dụng",
  sorted_="Đã sắp xếp Tải về", reveal="Mở trong Finder", ok="Xong"),
"en": dict(
  doc="December plan", sheet="Budget", chat="Chat", let_go="Let go on a layout", third="First third",
  saved="Saved “Layout 1”: 3 windows", chat_lines=("Table done?", "Working on it", "Send it over", "5 more minutes"),
  web="Web page", web_head="Team news", copied="Meet at 9:30 Monday", note="Notes",
  search="Search", kinds=("All", "Text", "Link", "File", "Image"), clips=("tidymint.app", "Order 2048", "#5FF0C0", "quote.pdf", "Image 640 × 400"),
  from_="From Safari · just now", board="Board", edit="Edit", pause="Pause 10 min", delete="Delete", open_clip="Open Mintclip",
  apps_n="3 apps", code="Colour code", cpu="CPU", ram="RAM",
  finder="Downloads", shelf_empty="Drop files here", shelf_sub="Gather files on one shelf.", items="%d items · %s MB", one="%d item · %s MB",
  drag_all="Drag all %d out", move="Move to…", quick="Quick actions", full="The shelf holds up to 5 items. Take some off to add more.",
  locked="Move the whole group at once, open with", menu=("Resize image", "Convert image to", "Copy text from image", "Compress into .zip", "My actions"),
  converted="Converted 1 to JPEG.", undo="Undo", mail="New message", to="To: project team", subject="Files for Monday",
  side=("Clean Now", "Clean by App", "Uninstaller", "Trash"), tools="TOOLS", nothing="Nothing is permanently deleted.", folder="~/Downloads", choose="Choose folder",
  switches=("Read content of images and PDFs", "Include sub-folders", "Put identical copies in the Trash", "Keep Downloads tidy"), plan="Plan",
  only_plus="Mintsort is part of Tidymint Plus.", reading=("Reading 4 of 9", "Reading 9 of 9"), plan_for="Plan for Downloads (9 files)", into="Sort into folders",
  creates="Creates 3 new folders in Downloads.", edit_tab="Edit", preview="Preview", groups=("Images", "Documents", "Installers"), new="NEW",
  files_n="%d files", now="NOW", after="AFTER APPLY", selected="9 files selected", cancel="Cancel", apply="Apply",
  sorted_="Downloads is sorted", reveal="Show in Finder", ok="Done"),
}


def bar_line(x, y, w, colour="#24302c22", h=6):
    return flow("", "position:absolute;left:%sp;top:%sp;width:%s;height:%sp;border-radius:3p;background:%s" % (x, y, w, h, colour))


# MARK: Mintangle. Split screen is what people search for; thirds is what Plus adds to it, then the saved layout.

def mintangle(t):
    S = Scene("ma", dict(free=[500, 1300, 2300, 3300, 4100], plus=[500, 1300, 2100, 3000, 4000, 4900, 5800, 6800]))
    half = [box(2, 26, 356, 422), box(362, 26, 356, 422)]
    third = [box(2, 26, 236, 422), box(242, 26, 236, 422), box(482, 26, 236, 422)]

    doc = ('<div class="tbar">%s%s</div>' % (lights(), flow(t["doc"]))
           + flow(t["doc"], "position:absolute;left:18p;top:44p;font-size:17p;font-weight:700;white-space:nowrap")
           + "".join(bar_line(18, 78 + i * 18, "calc(100%% - %d%%)" % (14 if i % 3 else 30)) for i in range(17)))
    cells = ""
    for r in range(19):
        cells += flow("", "position:absolute;left:0;right:0;top:%dp;height:22p;border-bottom:.7p solid #00000014;background:%s" % (28 + r * 22, "#1f9d6e14" if r % 4 == 0 else "transparent"))
        for c in range(3):
            v = ("A", "B", "C")[c] if r == 0 else (("%d" % (120 + r * 37 * c % 530)) if c else "T%d" % r)
            cells += flow(v, "position:absolute;left:%d%%;top:%dp;font-size:10p;font-weight:%d;padding-left:8p" % (c * 33, 33 + r * 22, 700 if r == 0 else 400))
    sheet = '<div class="tbar">%s%s</div>' % (lights(), flow(t["sheet"])) + cells
    talk = ""
    for i in range(8):
        me = i % 2
        talk += flow(t["chat_lines"][i % 4], "position:absolute;top:%dp;%s;padding:7p 10p;border-radius:12p;background:%s;font-size:11p;white-space:nowrap" % (
            40 + i * 40, "right:10p" if me else "left:10p", "#1d8f6a" if me else "#ffffff1f"))
    chat = '<div class="tbar">%s%s</div>' % (lights(), flow(t["chat"])) + talk

    w3 = S.el(box(44, 206, 262, 208) + ";z-index:1", chat, plus={7: third[2] + ";z-index:4"}, cls="win dk")
    w2 = S.el(box(318, 146, 344, 262) + ";z-index:2", sheet, free={4: half[1] + ";z-index:4"}, plus={6: third[1]}, cls="win")
    w1 = S.el(box(132, 92, 328, 252) + ";z-index:3", doc,
              free={2: box(-86, 152, 328, 252) + ";z-index:6", 3: half[0] + ";z-index:3"},
              plus={2: box(196, 30, 328, 252) + ";z-index:6", 4: box(86, 52, 328, 252), 5: third[0] + ";z-index:3"}, cls="win")
    # the footprint: 0x5ff0c0 at 22%, its edge at 85%, radius 12 (MintangleSnap.swift)
    print_ = ";z-index:7;border:2p solid #5ff0c0d9;background:#5ff0c038;border-radius:12p;opacity:0"
    foot = (S.el(box(4, 28, 352, 418) + print_, free={2: ON, 3: OFF})
            + S.el(box(4, 28, 232, 418) + print_, plus={4: ON, 5: OFF}))

    # the snap panel: tiles 46 x 30, gap 8, groups 20 apart, pad 12, radius 18 (MintangleSnapPanel.swift)
    def tile(x, y, w, place, hot=False):
        a, b, c, d = place
        iw, ih = w - 6, 24
        fill = box(3 + a * iw + 1, 3 + b * ih + 1, max(c * iw - 2, 2), max(d * ih - 2, 2)) + ";border-radius:3p"
        inner = S.el(fill + ";background:#ffffff73", plus={4: "background:#5ff0c0"} if hot else None)
        return S.el(box(x, y, w, 30) + ";border-radius:6p;background:#ffffff14", inner,
                    plus={4: "background:#5ff0c02e;transform:scale(1.06)"} if hot else None)
    tiles = ""
    for i in range(3):
        tiles += tile(12 + i * 54, 12, 46, (i / 3, 0, 1 / 3, 1), i == 0)
    for i in range(2):
        tiles += tile(12 + i * 81, 50, 73, (i / 3, 0, 2 / 3, 1))
    for i, p in enumerate([(0, 0, .5, 1), (0, 0, 1, 1), (.5, 0, .5, 1), (0, 0, 1, .5), (.22, .22, .56, .56), (0, .5, 1, .5)]):
        tiles += tile(186 + i % 3 * 54, 12 + i // 3 * 38, 46, p)
    for i, p in enumerate([(0, 0, .5, .5), (.5, 0, .5, .5), (0, .5, .5, .5), (.5, .5, .5, .5)]):
        tiles += tile(360 + i % 2 * 54, 12 + i // 2 * 38, 46, p)
    tiles += S.el(box(0, 86, 472, 16) + ";font-size:11p;color:#ffffff88", t["let_go"], plus={4: OFF}, cls="mid")
    tiles += S.el(box(0, 86, 472, 16) + ";font-size:11p;font-weight:700;opacity:0", t["third"], plus={4: ON}, cls="mid")
    panel = S.el(box(124, 34, 472, 110) + ";z-index:20;border-radius:18p;opacity:0;transform:translate(0,-10p)", tiles,
                 plus={3: "opacity:1;transform:none", 5: "opacity:0;transform:translate(0,-10p)"}, cls="glass")

    caps = (S.keys(540, 386, "⌃ ⌥ →", free={4: ON, 5: OFF})
            + S.keys(360, 386, "⌃ ⌥ F", plus={6: ON, 7: OFF}) + S.keys(600, 386, "⌃ ⌥ G", plus={7: ON, 8: OFF}))
    saved = S.el(box(360, 40) + ";z-index:22;transform:translate(-50%,-8p);padding:8p 14p;border-radius:100p;font-size:13p;font-weight:700;gap:8p;opacity:0",
                 ic("check", 13, "color:#5ff0c0") + flow(t["saved"]), plus={8: "opacity:1;transform:translate(-50%,0)"}, cls="glass mid")
    hand = S.pointer((600, 330),
                     free={1: (286, 106), 2: (5, 168, "down"), 3: (12, 170), 4: (330, 270), 5: (420, 300)},
                     plus={1: (286, 106), 2: (360, 28, "down"), 4: (159, 61, "down"), 5: (170, 80), 6: (300, 300), 8: (420, 330)})
    body = w3 + w2 + w1 + foot + panel + caps + saved + menubar("Tidymint", status_icons()) + hand + S.click(286, 106, free=[1], plus=[1])
    return S.stage(body), S.css


# MARK: Mintclip. Paste without formatting (1,900 searches) is the point; pinning happens on the way.

def mintclip(t):
    S = Scene("mc", dict(free=[500, 1300, 2300, 3300, 4300], plus=[500, 1300, 2300, 3400, 4500, 5400, 6400]))
    raw = "display:inline-block;padding:1p 3p;font:italic 700 18p/1.200 Georgia,serif;color:#c21f5b;background:#ffe45c;white-space:nowrap"
    page = ('<div class="tbar">%s%s</div>' % (lights(), flow(t["web"]))
            + flow(t["web_head"], "position:absolute;left:18p;top:42p;font-size:16p;font-weight:700")
            + bar_line(18, 74, "286p") + bar_line(18, 90, "214p")
            + S.el(box(15, 108), S.el(raw, t["copied"], both={1: "background:#a9cdff"}, fixed=False))
            + bar_line(18, 148, "270p"))
    source = S.el(box(16, 38, 344, 178), page, cls="win")
    paper = ('<div class="tbar">%s%s</div>' % (lights(), flow(t["note"]))
             + flow(t["doc"], "position:absolute;left:18p;top:42p;font-size:16p;font-weight:700")
             + bar_line(18, 74, "290p") + bar_line(18, 90, "190p")
             + S.el(box(15, 106) + ";opacity:0", flow(t["copied"], raw), free={5: ON}, plus={7: OFF})
             + S.el(box(18, 110) + ";font-size:13p;opacity:0", t["copied"], free={5: OFF}, plus={7: ON}, cls="t")
             + S.el(box(18, 108, 1.5, 18) + ";background:#1f9d6e", free={5: OFF}, plus={7: OFF})
             + bar_line(18, 148, "250p") + bar_line(18, 164, "140p"))
    note = S.el(box(16, 228, 344, 208), paper, cls="win")

    # the list: 360 wide in the app, radius 16; a paid control is drawn dimmed on a free copy
    dim = dict(free={0: "opacity:.4"})
    p = flow("", "position:absolute;left:147p;top:8p;width:36p;height:4p;border-radius:2p;background:#ffffff40")
    p += S.el(box(14, 20, 180, 22) + ";gap:9p;font-size:14p", ic("search", 15) + flow(t["search"], cls="sub"), cls="row")
    for i, name in enumerate(("filter", "pin", "x")):
        p += S.el(box(242 + i * 28, 20, 22, 22) + ";border-radius:50%;background:#ffffff14;color:#ffffffaa", ic(name, 11), cls="mid")
    p += S.el(box(25, 50, 280, 21) + ";border-radius:6p;background:#ffffff0f")
    for i in (2, 3, 4):
        p += S.el(box(25 + i * 56, 55, 1, 11) + ";background:#ffffff26")
    for i, name in enumerate(t["kinds"]):
        p += S.el(box(25 + i * 56, 50, 56, 21) + ";border-radius:6p;font-size:11p%s" % (";background:#ffffff26" if i == 0 else ""), name, cls="mid")
    p += S.el(box(0, 79, 330, 1) + ";background:#ffffff1a")
    top = lambda i: 88 + i * 29
    # the selection: the new copy, then (Plus) the same copy one row down, under the pinned one
    p += S.el(box(6, top(0), 318, 27) + ";border-radius:6p;background:#0f8f6840", plus={4: box(6, top(1), 318, 27)})
    rows = [(t["copied"], "text")] + list(zip(t["clips"], ("link", "text", "text", "doc", "photo")))
    for i, (text, kind) in enumerate(rows):
        moved = {4: "top:%dp" % top(0 if i == 2 else i + 1)} if i <= 2 else None   # item 2 is pinned and goes first
        inner = ic(kind, 13, "color:#ffffff9e;margin-right:9p") + flow(text, "max-width:186p", "cut")
        if text.startswith("#"):
            inner += flow("", "width:11p;height:11p;margin-left:7p;border-radius:50%;background:" + text)
        if i == 2:
            inner += S.icon("pin", 12, "left:271p;top:7.500p", "#ffffff9e", free={0: "opacity:.4"}, plus={4: OFF})
            inner += S.icon("pinned", 12, "left:271p;top:7.500p;opacity:0", "#5ff0c0", plus={4: ON})
        else:
            inner += S.icon("pin", 12, "left:271p;top:7.500p", "#ffffff9e", **dim)
        inner += S.icon("x", 10, "left:294p;top:8.500p", "#ffffff9e")
        p += S.el(box(6, top(i), 318, 27) + ";padding:0 9p;border-radius:6p;font-size:12p", inner, plus=moved, cls="row")
        p += S.el(box(242, top(i), 26, 27) + ";font-size:10p;color:#ffffff9e", "⌘%d" % (i + 1), cls="mid", **dim)
    card = (flow(t["copied"], "position:absolute;left:9p;top:8p;font-size:12p;white-space:nowrap")
            + flow(t["from_"], "position:absolute;left:9p;bottom:7p;font-size:10p;color:#ffffff9e;white-space:nowrap")
            + S.el("right:9p;bottom:7p;gap:9p;font-size:10p;font-weight:700", flow(t["board"]) + flow(t["edit"]), cls="row mint", **dim))
    p += S.el(box(12, 270, 306, 92) + ";border-radius:10p;background:#ffffff14", card)
    p += S.el(box(14, 372, 150, 16) + ";font-size:11p;font-weight:700", t["pause"], cls="row mint", **dim)
    p += S.el(box(148, 372, 70, 16) + ";font-size:11p;font-weight:700;gap:4p", flow(t["delete"]) + ic("down", 9), cls="row mint")
    p += S.el("right:14p;top:372p;height:16p;font-size:11p;font-weight:700", t["open_clip"], cls="row mint")
    up, down = "opacity:1;transform:none", "opacity:0;transform:translate(0,-10p) scale(.97)"
    panel = S.el(box(376, 30, 330, 398) + ";z-index:40;border-radius:16p;overflow:hidden;transform-origin:70% 0;" + down, p,
                 free={3: up, 5: down}, plus={3: up, 7: down}, cls="glass")

    lit = S.el(box(594, 2, 26, 20) + ";z-index:71;border-radius:5p;background:#ffffff2b;opacity:0", free={3: ON, 5: OFF}, plus={3: ON, 7: OFF})
    clip = S.icon("clip", 14, box(600, 5) + ";z-index:72")
    first, second, pinb = (441, 130), (441, 159), (659, 189)
    hand = S.pointer((330, 206),
                     free={1: (222, 160), 3: (560, 70), 4: first, 5: (250, 352)},
                     plus={1: (222, 160), 3: (560, 70), 4: pinb, 5: second, 7: (250, 352)})
    rings = S.click(*first, free=[4]) + S.click(*pinb, plus=[4]) + S.click(*second, plus=[6])
    caps = (S.keys(188, 174, "⌘ C", free={2: ON, 3: OFF}, plus={2: ON, 3: OFF})
            + S.keys(272, 398, "⌃ ⌥ V", free={3: ON, 4: OFF}, plus={3: ON, 4: OFF})
            + S.keys(470, 176, "⌥", plus={6: ON, 7: OFF}))
    body = source + note + lit + clip + panel + menubar("Safari", status_icons()) + rings + caps + hand
    return S.stage(body, free={1: (1.5, 220, 150), 3: (1, 360, 225), 4: (1.5, 530, 170), 5: (1.65, 200, 330)},
                   plus={1: (1.5, 220, 150), 3: (1, 360, 225), 4: (1.5, 530, 170), 7: (1.65, 200, 330)}), S.css


# MARK: Mintbar. Crowded bar first (Bartender's searches), then colour, widgets (iStat's searches), the fan and reorder.

def fan_points(n, hub):
    """MintbarFan.toggle: tiles 26, 6 apart, on a circle round the group's icon, opening downwards."""
    clear, r = 12 + 13 + 5, 36
    need = 0
    for _ in range(60):
        need = (26 * n + 6 * (n - 1) - 26) / r
        if need <= 2 * math.acos(min(1, clear / r)):
            break
        r += 6
    pts = [(hub[0] + r * math.sin(-need / 2 + i * 32 / r), hub[1] + r * math.cos(-need / 2 + i * 32 / r)) for i in range(n)]
    return pts


def swatches():
    """Mintbar.swatches: white to black, then nine hues from light tints to deep shades."""
    rows = [["#%02X%02X%02X" % ((round((1 - i / 8) * 255),) * 3) for i in range(9)]]
    for s, b in ((.25, 1), (.45, 1), (.65, 1), (.85, 1), (1, .9), (1, .75), (1, .6), (1, .45)):
        rows.append(["#%02X%02X%02X" % tuple(round(c * 255) for c in colorsys.hsv_to_rgb(h, s, b))
                     for h in (0, .07, .14, .33, .45, .53, .61, .76, .91)])
    return rows


# The groups, their names, symbols, apps and order are a real set (22/11/2026). Third-party icons are
# the ones Mintbar saved; macOS's are redrawn here. The VPN is a plain shield: whose it is stays off a public page.
GROUPS = [("AI", "atom", ["claude.png", "gemini.png", "siri"]),
          ("Connection", "cycle", ["keys", "shield", "wifi", "bluetooth"]),
          ("Tools", "hammer", ["input", "leaf", "drive.png", "clip"]),
          ("Monitor", "monitor", ["bolt", "betterdisplay.png", "mirror", "displays"])]
# the same bar on a free copy: two groups of four, symbols of the basic twelve, macOS's own icons stay out of groups
FREE = [("AI", "sparkles", ["claude.png", "gemini.png", "siri"]),
        ("Tools", "tools", ["input", "leaf", "drive.png", "betterdisplay.png"])]


def glyph(name):
    """An app's icon as it stands in the bar and in the fan (22 high, its own margins inside)."""
    if name.endswith(".png"):
        raw = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "plus-icons", name), "rb").read()
        return flow('<img alt="" style="display:block;height:100%%;width:auto;margin:auto" src="data:image/png;base64,%s">'
                    % base64.b64encode(raw).decode(), "display:block;width:22p;height:22p")
    return ic(name, 15)


def mintbar(t):
    S = Scene("mb", dict(free=[500, 1400, 2300, 3200, 4100, 4900, 5800],
                         plus=[500, 1400, 2300, 3100, 3900, 4600, 5600, 6600, 7600, 8600, 9700, 10500]))
    gx = (532, 560, 588, 616)
    hubs = [(x + 12, 12) for x in gx]
    out = ""
    # the bar before: every icon on its own. They fly into their groups; free keeps what does not fit in view.
    icons = [(g, a) for g, group in enumerate(GROUPS) for a in group[2]]
    icons = [x for x in icons if x[1] != "bolt"]             # the combined widget is made inside Mintbar
    freed = {a: g + 2 for g, group in enumerate(FREE) for a in group[2]}
    loose = [a for _, a in icons if a not in freed]
    for i, (g, a) in enumerate(icons):
        f = box(gx[freed[a]] + 1, 1) + ";opacity:0;transform:scale(.4)" if a in freed else box(586 - (len(loose) - loose.index(a)) * 21, 1)
        out += S.el(box(350 + i * 21.3, 1, 22, 22) + ";z-index:73", glyph(a), free={1: f},
                    plus={1: box(gx[g] + 1, 1) + ";opacity:0;transform:scale(.4)"}, cls="mid")
    pink, orange = "#ff375f", swatches()[4][1]

    def group_icon(x, sym, n, **kw):
        dots = "".join(flow("", "position:absolute;left:%.2fp;top:18.500p;width:2.300p;height:2.300p;border-radius:50%%;background:currentColor"
                            % (12 + (k - (n - 1) / 2) * 4.6 - 1.15)) for k in range(n))
        return S.el(box(x, 0, 24, 24) + ";z-index:74;color:#fff;opacity:0", S.icon(sym, 12.5, "left:5.800p;top:3.500p") + dots, **kw)
    for i, (_, sym, members) in enumerate(GROUPS):
        colour = {3: "color:%s" % pink, 4: "color:%s" % orange} if i == 0 else {}
        out += group_icon(gx[i], sym, len(members), plus={1: ON, **colour})
    for i, (_, sym, members) in enumerate(FREE):
        out += group_icon(gx[i + 2], sym, len(members), free={1: ON})
    # the open group's icon stays lit, and the light follows to the next group
    lit = ";z-index:72;border-radius:5p;background:#ffffff30;opacity:0"
    lights_on = [({}, {6: ON, 7: OFF}), ({}, {7: ON, 8: OFF}), ({2: ON, 3: OFF, 4: ON, 5: OFF}, {8: ON, 9: OFF}), ({3: ON, 4: OFF, 5: ON}, {9: ON})]
    for x, (f, p) in zip(gx, lights_on):
        out += S.el(box(x - 1, 2, 26, 20) + lit, free=f, plus=p)

    # the group's row of the Mintbar page, with the colour popover open under its button
    row = (S.el(box(10, 8, 24, 24) + ";border-radius:6p;background:#ffffff14", S.icon("atom", 14, "left:5p;top:5p", "#fff", plus={3: "color:%s" % pink, 4: "color:%s" % orange}))
           + S.el(box(44, 6, 120, 16) + ";font-size:12p;font-weight:700", GROUPS[0][0], cls="row")
           + S.el(box(44, 21, 120, 13) + ";font-size:10p", t["apps_n"], cls="row sub")
           + S.el(box(213, 6, 28, 28) + ";border-radius:6p;background:#ffffff29",
                  flow("", "position:absolute;left:5.600p;top:5.600p;width:16.800p;height:16.800p;border-radius:50%;background:conic-gradient(red,yellow,lime,cyan,blue,magenta,red)")
                  + S.el(box(5.6, 5.6, 16.8, 16.8) + ";border-radius:50%%;background:%s;opacity:0" % pink, plus={3: ON, 4: "opacity:1;background:%s" % orange})))
    sys_ = ("#ff453a", "#ff9f0a", "#ffd60a", "#30d158", "#63e6e2", "#0a84ff", "#bf5af2", pink)
    pop = flow("", "position:absolute;left:10p;top:9p;width:15p;height:15p;border-radius:50%;background:conic-gradient(red,yellow,lime,cyan,blue,magenta,red)")
    for i, c in enumerate(sys_):
        pop += S.el(box(31 + i * 21, 9, 15, 15) + ";border-radius:50%%;background:%s" % c,
                    plus={3: "transform:scale(1.18)", 4: "transform:none"} if i == 7 else None)
    for r, line in enumerate(swatches()):
        for c, hexa in enumerate(line):
            st = box(10 + c * 21, 31 + r * 12, 19, 10) + ";border-radius:2.500p;background:%s" % hexa
            pop += S.el(st, plus={4: "transform:scale(1.3)"}) if (r, c) == (4, 1) else flow("", "position:absolute;" + st)
    pop += S.el(box(10, 143, 190, 18) + ";gap:8p;font-size:11p", flow(t["code"]), cls="row")
    field = box(88, 142, 84, 19) + ";padding:0 7p;border-radius:4p;border:.700p solid #ffffff33;font-size:11p"
    pop += S.el(field + ";color:#ffffff66", "#RRGGBB", plus={3: OFF}, cls="row")
    pop += S.el(field + ";opacity:0", pink.upper(), plus={3: ON, 4: OFF}, cls="row")
    pop += S.el(field + ";opacity:0", orange.upper(), plus={4: ON}, cls="row")
    hide = {5: "opacity:0;transform:translate(0,-6p)"}
    out += S.el(box(362, 32, 250, 40) + ";z-index:50;border-radius:10p;opacity:0", row, plus={2: "opacity:1;transform:none", **hide}, cls="glass")
    out += S.el(box(402, 74, 210, 166) + ";z-index:51;border-radius:11p;opacity:0;overflow:hidden", pop, plus={2: "opacity:1;transform:none", **hide}, cls="glass")

    # the fan: tiles of glass, spring out 0.025 s apart, 1.25 under the pointer, the name in a bubble below.
    # A click on another group closes this fan and opens that one at once (MintbarFan.toggle).
    tile = lambda p, s=1: "left:%sp;top:%sp;opacity:1;transform:scale(%s)" % (round(p[0] - 13, 1), round(p[1] - 13, 1), s)
    shut = lambda h: box(h[0] - 13, h[1] - 13) + ";opacity:0;transform:scale(.3)"
    look = ";border-radius:50%%;background:#123f33ed;border:.800p solid #ffffff30;box-shadow:0 3p 8p #0005;opacity:0;transform:scale(.3);transition-timing-function:cubic-bezier(.2,1.250,.4,1);transition-duration:.380s;transition-delay:%dms"
    pts = [fan_points(len(g[2]), h) for g, h in zip(GROUPS, hubs)]
    fpts = [fan_points(len(g[2]), h) for g, h in zip(FREE, hubs[2:])]
    for g, (_, _, members) in enumerate(GROUPS[:3]):
        for i, a in enumerate(members):
            out += S.el(box(hubs[g][0] - 13, hubs[g][1] - 13, 26, 26) + ";z-index:60" + look % (i * 25), glyph(a),
                        plus={6 + g: tile(pts[g][i]), 7 + g: shut(hubs[g])}, cls="mid")
    # Monitor: the combined widget is dragged from second to first place, which is where it is in the real set
    last, h = pts[3], hubs[3]
    before = [1, 0, 2, 3]
    for i, a in enumerate(GROUPS[3][2]):
        big = 1.25 if i == 0 else 1
        out += S.el(box(h[0] - 13, h[1] - 13, 26, 26) + (";z-index:%d" % (62 if i == 0 else 60)) + look % (before[i] * 25), glyph(a),
                    plus={9: tile(last[before[i]]), 10: tile(last[before[i]], big),
                          11: tile((last[0][0], last[0][1] + 8) if i == 0 else last[i], big), 12: tile(last[i], big)}, cls="mid")
    for g, (_, _, members) in enumerate(FREE):
        for i, a in enumerate(members):
            p, h, big = fpts[g][i], hubs[g + 2], 1.25 if (g, i) == (1, 2) else 1
            f = ({2: tile(p), 3: shut(h), 4: tile(p), 5: shut(h)} if g == 0
                 else {3: tile(p), 4: shut(h), 5: tile(p), 6: tile(p, big), 7: shut(h)})
            out += S.el(box(h[0] - 13, h[1] - 13, 26, 26) + (";z-index:%d" % (62 if big > 1 else 60)) + look % (i * 25), glyph(a), free=f, cls="mid")
    bubble = ";z-index:63;height:18p;padding:0 8p;border-radius:100p;background:#123f33f2;border:.800p solid #ffffff30;font-size:11p;transform:translate(-50%,0);opacity:0"
    drive, widget = fpts[1][2], "%s 23%% · %s 61%%" % (t["cpu"], t["ram"])
    out += S.el(box(drive[0], drive[1] + 21) + bubble, "Google Drive", free={6: ON, 7: OFF}, cls="mid")
    out += S.el(box(last[1][0], last[1][1] + 21) + bubble, widget, plus={10: ON, 11: OFF}, cls="mid")
    out += S.el(box(last[0][0], last[1][1] + 21) + bubble, widget, plus={12: ON}, cls="mid")
    # free: the picked app's own menu
    menu = "".join(S.el(box(7, 7 + i * 20, 126, 18) + ";padding:0 6p;border-radius:4p;font-size:11p%s" % (";background:#2f7cf6" if i == 0 else ""), w, cls="row")
                   for i, w in enumerate(("Google Drive", "Sync", "Settings…", "Quit")))
    out += S.el(box(558, 27, 140, 92) + ";z-index:64;border-radius:9p;opacity:0", menu, free={7: ON}, cls="glass")

    pk = (402 + 31 + 7 * 21 + 7.5, 74 + 16.5)
    sw = (402 + 10 + 1 * 21 + 9.5, 74 + 31 + 4 * 12 + 5)
    at = [(x, 14) for x, _ in hubs]
    hand = S.pointer((560, 170),
                     free={1: (540, 120), 2: at[2], 3: at[3], 4: at[2], 5: at[3], 6: drive, 7: (630, 60)},
                     plus={1: (540, 120), 2: (589, 52), 3: pk, 4: sw, 5: (540, 150), 6: at[0], 7: at[1], 8: at[2], 9: at[3],
                           10: last[1], 11: (last[0][0], last[0][1] + 8, "down"), 12: last[0]})
    out += (S.click(589, 52, plus=[2]) + S.click(*pk, plus=[3]) + S.click(*sw, plus=[4]) + S.click(*drive, free=[7])
            + S.click(hubs[0][0], 12, plus=[6]) + S.click(hubs[1][0], 12, plus=[7])
            + S.click(hubs[2][0], 12, free=[2], plus=[8]) + S.click(hubs[2][0], 12, free=[4])
            + S.click(hubs[3][0], 12, free=[3], plus=[9]) + S.click(hubs[3][0], 12, free=[5]))
    body = menubar("Tidymint", status_icons(wifi=False)) + out + hand
    cam = {0: (1.78, 522, 118)}
    return S.stage(body, free=cam, plus=cam), S.css


# MARK: Mintdrop. Gather by shaking, then the two most searched chores (HEIC to JPG, then hand it all over).

FILES = [("IMG_2041.heic", "photo", 2.4, "#f3a75b,#7b4fd0"), ("bao-gia.pdf", "PDF", 1.1, "#e5484d"), ("logo.png", "photo", .4, "#37c6a0,#2266c8"),
         ("hop-dong.pdf", "PDF", 2.0, "#e5484d"), ("video.mp4", "MP4", 6.1, "#7b61ff"), ("bang-gia.xlsx", "XLS", .6, "#1f9d6e")]


EN_NAMES = {"bao-gia.pdf": "quote.pdf", "hop-dong.pdf": "contract.pdf", "bang-gia.xlsx": "prices.xlsx"}


def file_icon(f, size):
    name, kind, mb, colour = f
    if kind == "photo":
        return flow("", "display:block;flex:none;width:%sp;height:%sp;border-radius:4p;border:1.500p solid #fff;background:linear-gradient(150deg,%s)" % (size, size * .82, colour))
    return flow(flow(kind, "position:absolute;left:0;right:0;bottom:12%%;text-align:center;font-size:%sp;font-weight:800;color:%s" % (round(size * .25, 1), colour)),
                "position:relative;display:block;flex:none;width:%sp;height:%sp;border-radius:3p;background:#fff;border:.700p solid #00000022" % (round(size * .8, 1), size))


def mintdrop(t):
    shown = (lambda n: n) if t is T["vi"] else (lambda n: EN_NAMES.get(n, n))
    S = Scene("md", dict(free=[500, 1300, 2300, 3100, 4000, 4900, 5900], plus=[500, 1300, 2300, 3100, 3900, 4700, 5600, 6800, 7700, 8700, 9800, 10700]))
    FX, FY, SX, SY = 14, 38, 400, 36
    at = [(FX + 26 + i % 3 * 112, FY + 44 + i // 3 * 92) for i in range(6)]
    finder = '<div class="tbar">%s%s</div>' % (lights(), flow(t["finder"]))
    for i, f in enumerate(FILES):
        x, y = at[i][0] - FX, at[i][1] - FY
        picked = {5: "background:#2f7cf633"}              # Command-A
        picked.update({1: "background:#2f7cf633", 4: "background:transparent"} if i == 0 else {})
        finder += S.el(box(x + 7, y - 5, 60, 60) + ";border-radius:7p;background:transparent", both=picked)
        finder += S.el(box(x + 14, y, 46, 50), file_icon(f, 46), cls="mid")
        finder += S.el(box(x - 8, y + 55, 92, 14) + ";font-size:10p", shown(f[0]), cls="mid")
    out = S.el(box(FX, FY, 360, 250), finder, cls="win")

    mail = ('<div class="tbar">%s%s</div>' % (lights(), flow(t["mail"]))
            + flow(t["to"], "position:absolute;left:14p;top:38p;font-size:11p;color:#24302c99;white-space:nowrap")
            + flow(t["subject"], "position:absolute;left:14p;top:58p;font-size:13p;font-weight:700;white-space:nowrap")
            + bar_line(14, 84, "250p"))
    for i, f in enumerate(FILES + [("IMG_2041.jpg", "photo", 1.8, FILES[0][3])]):
        mail += S.el(box(14 + i * 46, 99, 40, 34) + ";opacity:0;transition-delay:%dms" % (i * 60), file_icon(f, 30), plus={12: ON}, cls="mid")
    out += S.el(box(FX, 298, 360, 142), mail, cls="win")

    # the shelf: 300 wide, radius 14, rows with a 26 thumbnail (ShelfPage.swift)
    s = S.icon("tray", 15, "left:14p;top:17p", "#5ff0c0")
    s += S.el(box(37, 10, 120, 16) + ";font-size:13p;font-weight:700", "Mintdrop", cls="row")
    num = lambda v: ("%.1f" % v).replace(".", "," if t is T["vi"] else ".")
    size = lambda n: num(sum(f[2] for f in (FILES + [("", "", 1.8, "")])[:n]))
    sub = box(37, 26, 130, 14) + ";font-size:11p;opacity:0"
    s += S.el(sub, t["one"] % (1, size(1)), free={4: ON, 7: OFF}, plus={4: ON, 7: OFF}, cls="row sub")
    s += S.el(sub, t["items"] % (5, size(5)), free={7: ON}, cls="row sub")
    s += S.el(sub, t["items"] % (6, size(6)), plus={7: ON, 10: OFF}, cls="row sub")
    s += S.el(sub, t["items"] % (7, size(7)), plus={10: ON}, cls="row sub")
    for i, name in enumerate(("lines", "plus", "x")):
        s += S.el(box(206 + i * 29, 13, 22, 22) + ";border-radius:50%;background:#ffffff14;color:#ffffffb0", ic(name, 11),
                  free={0: "opacity:.4"} if i < 2 else None, cls="mid")
    empty = (S.icon("drop", 30, "left:123p;top:58p", "#5ff0c0")
             + S.el(box(0, 100, 276, 16) + ";font-size:13p;font-weight:700", t["shelf_empty"], cls="mid")
             + S.el(box(0, 120, 276, 14) + ";font-size:11p", t["shelf_sub"], cls="mid sub"))
    s += S.el(box(12, 54, 276, 336) + ";border:1.500p dashed #5ff0c099;border-radius:10p", empty, both={4: OFF})
    y = lambda i: 49 + i * 32
    row = lambda f: (file_icon(f, 24) + flow(flow(shown(f[0]), "display:block", "cut") + flow("%s MB" % num(f[2]), "display:block;font-size:9.500p;color:#ffffff9e"),
                                              "width:196p;margin-left:9p") + ic("minus", 13, "margin-left:auto;color:#ffffff9e"))
    for i, f in enumerate(FILES):
        at_step = 4 if i == 0 else 7
        st = box(8, y(i), 284, 31) + ";padding:0 7p;border-radius:6p;font-size:12p;opacity:0;transition-delay:%dms" % (i * 70)
        sel = {8: "opacity:1;background:#5ff0c02e;transition-delay:0ms", 10: "background:transparent"} if i == 0 else {}
        s += S.el(st, row(f), free={at_step: ON} if i < 5 else {}, plus={at_step: ON, **sel}, cls="row")
    s += S.el(box(8, y(6), 284, 31) + ";padding:0 7p;border-radius:6p;font-size:12p;opacity:0", row(("IMG_2041.jpg", "photo", 1.8, FILES[0][3])),
              plus={10: "opacity:1;background:#5ff0c02e"}, cls="row")
    count = lambda n, **kw: S.el(box(0, 0, 276, 32) + ";gap:8p;font-size:12p;font-weight:600;color:#5ff0c0;opacity:0",
                                 ic("hand", 14) + flow(t["drag_all"] % n), cls="mid", **kw)
    foot = S.el(box(0, 0, 276, 32) + ";border:1p dashed #5ff0c099;border-radius:8p", plus={11: "background:#5ff0c024"})
    foot += count(1, free={4: ON, 7: OFF}, plus={4: ON, 7: OFF}) + count(5, free={7: ON}) + count(6, plus={7: ON, 10: OFF}) + count(7, plus={10: ON})
    foot += S.el(box(0, 39, 76, 24) + ";border-radius:6p;background:#ffffff1f;font-size:11p", t["move"], cls="mid")
    foot += S.el(box(84, 39, 112, 24) + ";gap:5p;border-radius:6p;font-size:11p", flow(t["quick"]) + ic("down", 9), plus={8: "background:#ffffff26", 10: "background:transparent"}, cls="mid")
    foot += S.icon("trash", 15, "left:254p;top:43p", "#ff453a")
    s += S.el(box(12, 280, 276, 64) + ";opacity:0", foot, free={4: "opacity:.4"}, plus={4: ON})
    s += S.el(box(12, 347, 276, 14) + ";font-size:10p;gap:3p;opacity:0", flow(t["locked"], cls="sub") + flow("Plus", "color:#5ff0c0;font-weight:700"), free={4: ON}, cls="row")
    s += S.el(box(12, 364, 276, 28) + ";font-size:10.500p;color:#ffc56b;white-space:normal;opacity:0", t["full"], free={7: ON})
    s += S.el(box(12, 356, 276, 16) + ";gap:6p;font-size:11p;opacity:0", flow(t["converted"], cls="sub") + flow(t["undo"], "color:#5ff0c0;font-weight:700"), plus={10: ON}, cls="row")
    s += S.el(box(284, 384, 11, 11), '<svg viewBox="0 0 12 12" fill="none" stroke="#ffffff66"><path d="M11 1 1 11M11 6 6 11"/></svg>', free={0: OFF})
    out += S.el(box(SX, SY, 300, 400) + ";z-index:30;border-radius:14p;overflow:hidden;opacity:0;transform:scale(.9)", s,
                both={3: "opacity:1;transform:none"}, free={3: "border-color:#5ff0c0", 4: "border-color:#ffffff2b", 6: "border-color:#5ff0c0", 7: "border-color:#ffc56b"},
                plus={3: "border-color:#5ff0c0", 4: "border-color:#ffffff2b", 6: "border-color:#5ff0c0", 7: "border-color:#ffffff2b"}, cls="glass")

    # files in flight: the first one alone, then all six by Command-A (the one already on the shelf is not added twice)
    to = lambda i: box(SX + 14, SY + y(i) + 2)
    move = {2: box(300, 104) + ";opacity:.9", 3: box(470, 120) + ";opacity:.9", 4: to(0) + ";opacity:0;transform:scale(.55)"}
    out += S.el(box(at[0][0] + 14, at[0][1], 46, 50) + ";z-index:80;opacity:0", file_icon(FILES[0], 46), free=move, plus=move, cls="mid")
    held = "".join(S.el(box(i * 7, 12 - i * 5, 46, 50), file_icon(f, 42), cls="mid") for i, f in enumerate(FILES[3:6]))
    held += S.el(box(48, -8, 22, 22) + ";border-radius:50%;background:#ff3b30;font-size:12p;font-weight:700", "6", cls="mid")
    from_, over = box(at[4][0] + 10, at[4][1] - 4), box(SX + 112, SY + 168)
    out += S.el(from_ + ";width:70p;height:66p;z-index:80;opacity:0", held, both={5: "opacity:0", 6: over + ";opacity:.92", 7: to(2) + ";opacity:0;transform:scale(.5)"})
    for i, (dx, dy) in enumerate(((-16, 4), (16, -3), (0, 8))):      # the shake
        out += S.el(box(312 + dx, 128 + dy, 22, 22) + ";z-index:79;border:1.500p solid #ffffff66;border-radius:50%;opacity:0",
                    both={2: ON + ";transition-delay:%dms" % (150 + i * 160), 3: OFF})

    mi = lambda i: 7 + i * 24 + (7 if i >= 3 else 0)
    menu = ""
    for i, w in enumerate(t["menu"]):
        menu += S.el(box(6, mi(i), 188, 21) + ";padding:0 8p;border-radius:5p;font-size:11.500p",
                     flow(w) + (ic("right", 10, "margin-left:auto") if i in (0, 1, 4) else ""),
                     plus={9: "background:#2f7cf6"} if i == 1 else None, cls="row")
    out += S.el(box(SX - 50, SY + 162, 200, 140) + ";z-index:40;border-radius:9p;background:#202825f7;opacity:0", menu, plus={8: ON, 10: OFF}, cls="glass")
    fmts = "".join(S.el(box(6, 6 + i * 23, 98, 20) + ";padding:0 8p;border-radius:5p;font-size:11.500p", f,
                        plus={9: "background:#2f7cf6"} if i == 0 else None, cls="row") for i, f in enumerate(("JPEG", "PNG", "HEIC", "WebP")))
    out += S.el(box(SX + 153, SY + 188, 110, 102) + ";z-index:41;border-radius:9p;background:#202825f7;opacity:0", fmts, plus={9: ON, 10: OFF}, cls="glass")
    stack = (file_icon(FILES[0], 42) + S.el(box(30, -7, 20, 20) + ";border-radius:50%;background:#ff3b30;font-size:11p;font-weight:700", "7", cls="mid"))
    out += S.el(box(SX + 120, SY + 280, 46, 46) + ";z-index:81;opacity:0", stack, plus={11: box(250, 360) + ";opacity:1", 12: box(150, 392) + ";opacity:0"}, cls="mid")

    q = (SX + 12 + 140, SY + 280 + 51)
    j = (SX + 153 + 40, SY + 188 + 16)
    d = (SX + 150, SY + 296)
    first = (at[0][0] + 37, at[0][1] + 25)
    pick, drop = (at[4][0] + 37, at[4][1] + 25), (SX + 140, SY + 200)
    hand = S.pointer((250, 250),
                     free={1: first, 2: (323, 129, "down"), 3: (493, 145, "down"), 4: (520, 120), 5: pick, 6: drop + ("down",), 7: (SX + 160, SY + 250)},
                     plus={1: first, 2: (323, 129, "down"), 3: (493, 145, "down"), 4: (520, 120), 5: pick, 6: drop + ("down",), 7: (SX + 160, SY + 250),
                           8: q, 9: j, 10: d, 11: (273, 383, "down"), 12: (200, 396)})
    out += S.click(*q, plus=[8]) + S.click(*j, plus=[9])
    out += S.keys(194, 248, "⌘ A", free={5: ON, 6: OFF}, plus={5: ON, 6: OFF})
    body = out + menubar("Finder", status_icons()) + hand
    return S.stage(body, free={1: (1.35, 250, 150), 3: (1, 360, 225), 7: (1.22, 500, 270)},
                   plus={1: (1.35, 250, 150), 3: (1, 360, 225), 8: (1.45, 545, 270), 10: (1.25, 520, 300), 11: (1, 360, 225)}), S.css


# MARK: Mintsort. Messy Downloads, the fear of losing files answered by Preview and Undo.

def mintsort(t):
    S = Scene("ms", dict(free=[700, 1800, 2700], plus=[500, 1300, 2300, 3400, 4400, 5300, 7000, 8000]))
    WX, WY, CW, CH = 16, 32, 540, 406
    side = flow(lights(), "position:absolute;left:12p;top:12p")
    side += S.el(box(12, 36, 124, 22) + ";gap:7p;font-size:14p;font-weight:800", ic("leaf", 17, "color:#5ff0c0") + flow('Tidy<b style="color:#5ff0c0">mint</b>'), cls="row")
    for i, (w, name) in enumerate(zip(t["side"], ("sparkles", "grid", "box", "trash"))):
        side += S.el(box(8, 68 + i * 27, 132, 24) + ";padding:0 8p;gap:8p;border-radius:6p;font-size:11p", ic(name, 12) + flow(w), cls="row")
    side += S.el(box(16, 186, 110, 14) + ";font-size:9.500p;font-weight:700;letter-spacing:.500p", t["tools"], cls="row sub")
    for i, (w, name) in enumerate((("Mintangle", "halves"), ("Mintdrop", "tray"), ("Mintbar", "dots"), ("Mintclip", "clip"), ("Mintsort", "sorted"))):
        side += S.el(box(8, 206 + i * 27, 132, 24) + ";padding:0 8p;gap:8p;border-radius:6p;font-size:11p%s" % (";background:#17704f" if i == 4 else ""), ic(name, 12) + flow(w), cls="row")
    win = S.el(box(0, 0, 148, CH) + ";background:#ffffff0d;border-right:.700p solid #ffffff14", side)

    def page(inner, **kw):
        return S.el(box(148, 0, CW, CH) + ";opacity:0", inner, **kw)

    # start: title, the folder, three switches, the big round button
    p = S.el(box(0, 24, CW, 28) + ";font-size:22p;font-weight:800", "Mintsort", cls="mid")
    p += S.el(box(0, 53, CW, 16) + ";font-size:12p", t["nothing"], cls="mid sub")
    p += S.el(box(70, 80, 400, 46) + ";padding:0 12p;gap:10p;border-radius:10p;background:#ffffff14;font-size:12p",
              ic("folder", 17, "color:#17a878") + flow(t["folder"]) + flow(t["choose"], "margin-left:auto;padding:5p 12p;border-radius:100p;border:.800p solid #ffffff66"), cls="row")
    for i, w in enumerate(t["switches"]):
        knob = flow("", "position:absolute;top:1.500p;%s:1.500p;width:13p;height:11p;border-radius:6p;background:#fff" % ("right" if i in (0, 2) else "left"))
        p += S.el(box(82, 133 + i * 24, 378, 23) + ";font-size:12p",
                  flow(w) + flow(knob, "position:relative;margin-left:auto;width:28p;height:14p;border-radius:7p;background:%s" % ("#2fd39f" if i in (0, 2) else "#ffffff22")), cls="row")
    # BigScanButton: the leaf alone; under the pointer it fades and the word shows
    disc = (S.el(box(0, 0, 126, 126) + ";border-radius:50%;background:#0f8f6824", plus={1: "background:#0f8f6838;transform:scale(1.08)"})
            + S.el(box(13, 13, 100, 100) + ";border-radius:50%;background:#0c211a;border:1.400p solid #0f8f6899;box-shadow:0 0 22p #0f8f6866",
                   plus={1: "border-color:#0f8f68"})
            + S.icon("leaf", 58, "left:34p;top:34p", "#25b887", plus={1: "opacity:.18;transform:scale(1.06)"})
            + S.el(box(0, 53, 126, 20) + ";font-size:13p;font-weight:700;opacity:0", t["plan"], plus={1: ON}, cls="mid"))
    p += S.el(box(207, 234, 126, 126), disc, free={0: "opacity:.4"}, plus={2: "transform:scale(.94)"})
    p += S.el(box(0, 368, CW, 18) + ";font-size:12p;opacity:0", t["only_plus"], free={0: ON}, cls="mid")
    win += page(p, free={0: ON}, plus={0: ON, 2: OFF})

    # reading
    p = S.el(box(110, 180, 320, 6) + ";border-radius:3p;background:#ffffff22;overflow:hidden", S.el(box(0, 0, 8, 6) + ";background:#2fd39f;transition-duration:.900s", plus={2: "width:130p", 3: "width:320p"}))
    for i, w in enumerate(t["reading"]):
        p += S.el(box(0, 200, CW, 20) + ";font-size:15p;font-weight:700;opacity:%d" % (1 - i), w, plus={3: ON if i else OFF}, cls="mid")
    p += S.el(box(0, 222, CW, 16) + ";font-size:12p", "IMG_2041.heic", cls="mid sub")
    win += page(p, plus={2: ON, 4: OFF})

    # the plan
    names = [("IMG_2041.heic", "logo.png", "banner.png"), ("CV.pdf", t["clips"][3], "notes.txt"), ("Zoom.pkg", "App.dmg", "Tool.dmg")]
    icons = ("photo", "doc", "box")
    p = S.el(box(20, 24, 300, 20) + ";font-size:13p;font-weight:700", t["plan_for"], cls="row")
    p += S.el("right:20p;top:22p;height:24p;padding:0 11p;border-radius:100p;background:#17704f;font-size:11p;font-weight:700", t["into"], cls="mid")
    p += S.el(box(20, 48, 300, 16) + ";font-size:11p", t["creates"], cls="row sub")
    p += S.el(box(318, 52, 202, 26) + ";border-radius:100p;background:#ffffff14")
    for i, w in enumerate((t["edit_tab"], t["preview"])):
        p += S.el(box(320 + i * 100, 54, 98, 22) + ";border-radius:100p;font-size:11p;font-weight:700;background:transparent", w,
                  plus={4: "background:#17704f", 6: "background:transparent"} if i == 0 else {6: "background:#17704f"}, cls="mid")
    board = ""
    for g in range(3):
        y = g * 84
        head = ic("check", 11, "padding:1.500p;border-radius:3p;background:#2fd39f;color:#06241b") + ic(icons[g], 14, "color:#2fd39f")
        head += flow(t["groups"][g] + "/", "font-size:13p;font-weight:700") + flow(t["files_n"] % 3, "font-size:10p;color:#ffffff9e")
        head += flow(t["new"], "padding:1p 6p;border-radius:100p;background:#0f8f682e;color:#2fd39f;font-size:8.500p;font-weight:700")
        card = S.el(box(10, 6, 480, 24) + ";gap:8p", head, cls="row")
        for i, n in enumerate(names[g]):
            card += S.el(box(34 + i * 152, 38, 146, 26) + ";padding:0 8p;gap:6p;border-radius:6p;background:#ffffff0f;font-size:10.500p", ic(icons[g], 11, "color:#ffffff9e") + flow(n, "max-width:112p", "cut"), cls="row")
        board += S.el(box(0, y, 500, 76) + ";border-radius:10p;background:#ffffff14", card)
    p += S.el(box(20, 90, 500, 250), board, plus={6: OFF})
    tree = ""
    for c, title in enumerate((t["now"], t["after"])):
        tree += S.el(box(c * 256, 0, 244, 262) + ";border-radius:12p;background:#ffffff14")
        tree += S.el(box(c * 256 + 12, 9, 220, 14) + ";font-size:9.500p;font-weight:700;letter-spacing:.600p", title, cls="row sub")
        tree += S.el(box(c * 256 + 12, 28, 220, 18) + ";gap:6p;font-size:11.500p", ic("folder", 13, "color:#2fd39f") + flow(t["finder"]), cls="row")
    for g in range(3):
        fy = 48 + g * 70
        tree += S.el(box(282, fy, 208, 18) + ";gap:6p;font-size:11.500p;opacity:0;transition-delay:%dms" % (g * 180),
                     ic("folder", 12, "color:#2fd39f") + flow(t["groups"][g]) + flow(t["new"], "padding:1p 6p;border-radius:100p;background:#17a878;font-size:8.500p;font-weight:700"),
                     plus={6: ON}, cls="row")
        for i, n in enumerate(names[g]):
            here = box(32, 48 + ((g * 3 + i) * 4 % 9) * 23, 186, 16)
            there = box(302, fy + 19 + i * 16, 186, 16)
            tree += S.el(here + ";font-size:10.500p;color:#ffffff66", n, cls="row")
            tree += S.el(here + ";font-size:10.500p;color:#6ee7a8;opacity:0;transition-delay:%dms" % (250 + (g * 3 + i) * 80), n, plus={6: there + ";opacity:1"}, cls="row")
    p += S.el(box(20, 88, 500, 262) + ";opacity:0", tree, plus={6: ON})
    foot = flow(t["selected"], "font-size:13p;font-weight:700") + flow(t["cancel"], "margin-left:auto;padding:5p 12p;border-radius:100p;background:#ffffff14;font-size:11p")
    foot += flow(t["apply"], "margin-left:8p;padding:6p 16p;border-radius:100p;background:linear-gradient(90deg,#2fd39f,#0f8f68);font-size:11p;font-weight:700")
    p += S.el(box(0, 358, CW, 48) + ";padding:0 20p;background:#00000040", foot, cls="row")
    win += page(p, plus={4: ON, 8: OFF})

    # done
    p = S.icon("done", 46, "left:247p;top:50p", "#6ee7a8")
    p += S.el(box(0, 104, CW, 26) + ";font-size:20p;font-weight:800", t["sorted_"], cls="mid")
    rows = ""
    for g in range(3):
        rows += S.el(box(0, g * 38, 340, 38) + ";padding:0 14p;gap:9p;font-size:12p" + (";border-top:.700p solid #ffffff14" if g else ""),
                     ic(icons[g], 14, "color:#2fd39f") + flow(t["groups"][g]) + flow(t["files_n"] % 3, "margin-left:auto;color:#ffffff9e"), cls="row")
    p += S.el(box(100, 146, 340, 114) + ";border-radius:10p;background:#ffffff14", rows)
    p += S.el(box(78, 282, 132, 30) + ";border-radius:100p;background:#ffffff14;font-size:11.500p", t["reveal"], cls="mid")
    p += S.el(box(220, 282, 112, 30) + ";border-radius:100p;border:.800p solid #5ff0c066;background:#5ff0c01f;color:#5ff0c0;font-size:11.500p;font-weight:700", t["undo"], cls="mid")
    p += S.el(box(342, 282, 120, 30) + ";border-radius:100p;background:linear-gradient(90deg,#2fd39f,#0f8f68);font-size:11.500p;font-weight:700", t["ok"], cls="mid")
    win += page(p, plus={8: ON})

    cx = WX + 148
    go, tab, app = (cx + 270, WY + 297), (cx + 469, WY + 65), (cx + 476, WY + 382)
    hand = S.pointer((600, 400), free={1: go, 3: (cx + 400, WY + 372)},
                     plus={1: go, 3: (cx + 400, WY + 300), 5: tab, 7: app, 8: (cx + 276, WY + 297)})
    rings = S.click(*go, free=[2], plus=[2]) + S.click(*tab, plus=[6]) + S.click(*app, plus=[7])
    body = S.el(box(WX, WY, 688, CH), win, cls="win app") + menubar("Tidymint", status_icons()) + rings + hand
    return S.stage(body, free={1: (1.18, 434, 290)},
                   plus={1: (1.18, 434, 290), 4: (1.06, 434, 235), 8: (1.45, 434, 225)}), S.css


FLOWS = dict(mintangle=mintangle, mintclip=mintclip, mintbar=mintbar, mintdrop=mintdrop, mintsort=mintsort)
