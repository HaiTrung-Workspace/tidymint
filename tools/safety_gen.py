"""Builds the "never touches" tables on the Safety page straight from the app's source code,
so the page cannot drift from what the app does. Read by tools/guides.py ({SAFETY_RULES})."""
import os, re, html

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Sources")
GH = "https://github.com/HaiTrung-Workspace/tidymint/blob/main/Sources/"

def _path(name):
    """Path of a source file relative to Sources/ (files live in subfolders, names are unique)."""
    for d, _, fs in os.walk(SRC):
        if name in fs:
            return os.path.relpath(os.path.join(d, name), SRC).replace(os.sep, "/")
    raise SystemExit("safety_gen: %s not found under Sources/" % name)

def _read(name):
    with open(os.path.join(SRC, _path(name)), encoding="utf-8") as f:
        return f.read()

def _set(text, name):
    """Items of `static let <name>: Set<String> = [ ... ]`, with the line it starts on."""
    m = re.search(r"static let %s\s*:\s*Set<String>\s*=\s*\[(.*?)\]" % re.escape(name), text, re.S)
    if not m:
        raise SystemExit("safety_gen: %s not found, update tools/safety_gen.py" % name)
    return re.findall(r'"([^"]+)"', m.group(1)), text[:m.start()].count("\n") + 1

def locked_sections():
    """[(app names, titleEN, titleVI, line)] for every AppSection with safety .locked in AppRules.swift."""
    lines = _read("AppRules.swift").split("\n")
    chromium = [m.group(1) for l in lines for m in [re.search(r'^\s*chromium\(id: "[^"]+", nameEN: "([^"]+)"', l)] if m]
    out, app, title = [], None, None
    for i, l in enumerate(lines, 1):
        if "static func chromium(" in l:
            app = chromium
        m = re.search(r'AppRule\(id: "[^"]+", nameEN: "([^"]+)"', l)
        if m:
            app = [m.group(1)]
        m = re.search(r'AppSection\(id: "[^"]+", titleEN: "([^"]+)", titleVI: "([^"]+)"', l)
        if m:
            title = (m.group(1), m.group(2), i)
        if "safety: .locked" in l and title and app:
            out.append((list(app), title[0], title[1], title[2])); title = None
    if not out:
        raise SystemExit("safety_gen: no locked sections found, update tools/safety_gen.py")
    return out

def _code(items):
    return ", ".join("<code>%s</code>" % html.escape(x) for x in items)

T = {
 "en": dict(
    lead="This list is not written by hand. The website builder reads it from the app's source code every time the site is rebuilt, so it always matches the version you download. Each row links to the exact lines.",
    h_app="Locked inside each app (Clean by App)", th_app=("App", "Never touched", "Code"),
    h_gen="Blocked everywhere", th_gen=("Rule", "What it covers", "Code"),
    home=("Space Lens and every other page refuse to move these folders themselves to the Trash (items inside them can still be offered)", "In your home folder: "),
    sysd=("Large Files skips these system folders on every drive", ""),
    dup=("Duplicates never looks inside these folders", ""),
    trash=("A drive's own Trash folder is never moved", "<code>.Trashes</code> and <code>.Trash</code> at the top of an external drive"),
    line="line"),
 "vi": dict(
    lead="Danh sách này không viết tay. Mỗi lần dựng lại web, công cụ dựng đọc thẳng từ mã nguồn của app, nên luôn khớp với bản bạn tải về. Mỗi dòng có link tới đúng đoạn code.",
    h_app="Khoá trong từng ứng dụng (Dọn theo ứng dụng)", th_app=("Ứng dụng", "Không bao giờ đụng", "Code"),
    h_gen="Chặn ở mọi nơi", th_gen=("Luật", "Áp dụng cho", "Code"),
    home=("Bản đồ ổ đĩa và mọi trang khác từ chối chuyển chính các thư mục này vào Thùng rác (các mục bên trong vẫn có thể được đưa ra)", "Trong thư mục Nhà: "),
    sysd=("File lớn bỏ qua các thư mục hệ thống này trên mọi ổ", ""),
    dup=("File trùng không bao giờ quét bên trong các thư mục này", ""),
    trash=("Thư mục Thùng rác của ổ không bao giờ bị chuyển đi", "<code>.Trashes</code> và <code>.Trash</code> ở gốc ổ ngoài"),
    line="dòng"),
}

def html_for(lang):
    t = T[lang]; ti = 1 if lang == "en" else 2
    def link(f, n): return '<a href="%s%s#L%d" rel="nofollow">%s, %s %d</a>' % (GH, _path(f), n, f, t["line"], n)
    rows = "".join('<tr><td data-l="%s"><b>%s</b></td><td data-l="%s">%s</td><td data-l="%s">%s</td></tr>'
                   % (t["th_app"][0], html.escape(", ".join(a)), t["th_app"][1], html.escape(s[ti - 1]), t["th_app"][2], link("AppRules.swift", s[2]))
                   for a, *s in [(x[0], x[1], x[2], x[3]) for x in locked_sections()])
    trash, scan, dup = _read("Trash.swift"), _read("Scanner.swift"), _read("Duplicates.swift")
    home, hl = _set(trash, "protectedHomeItems"); sysd, sl = _set(scan, "systemHiddenDirs"); dd, dl = _set(dup, "skipDirs")
    gen = [(t["home"][0], t["home"][1] + _code(home), link("Trash.swift", hl)),
           (t["trash"][0], t["trash"][1], link("Trash.swift", hl)),
           (t["sysd"][0], _code(sysd), link("Scanner.swift", sl)),
           (t["dup"][0], _code(dd), link("Duplicates.swift", dl))]
    grows = "".join('<tr><td data-l="%s">%s</td><td data-l="%s">%s</td><td data-l="%s">%s</td></tr>'
                    % (t["th_gen"][0], a, t["th_gen"][1], b, t["th_gen"][2], c) for a, b, c in gen)
    head = lambda th: "<tr>" + "".join("<th>%s</th>" % x for x in th) + "</tr>"
    return ('<p>%s</p><h3>%s</h3><div class="tbl"><table>%s%s</table></div><h3>%s</h3><div class="tbl"><table>%s%s</table></div>'
            % (t["lead"], t["h_app"], head(t["th_app"]), rows, t["h_gen"], head(t["th_gen"]), grows))

if __name__ == "__main__":
    for a, en, vi, n in locked_sections(): print(n, a, "|", en, "|", vi)
