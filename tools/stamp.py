"""Append ?v=<short hash> to local image references so browsers fetch a new image after it changes."""
import hashlib, os, re

_IMG = re.compile(r'((?:src|href|content)=")([^"?#]+\.(?:png|jpe?g|webp|svg|gif|ico))(")')

def stamp(html_text, page_path, root):
    """page_path: absolute path of the HTML file being written; root: repo root (docs/ lives under it)."""
    page_dir = os.path.dirname(page_path)
    docs = os.path.join(root, "docs")
    def rep(m):
        ref = m.group(2)
        if ref.startswith(("http://", "https://", "data:")):
            return m.group(0)
        local = os.path.join(docs, ref.lstrip("/")) if ref.startswith("/") else os.path.normpath(os.path.join(page_dir, ref))
        if not os.path.isfile(local):
            return m.group(0)
        h = hashlib.md5(open(local, "rb").read()).hexdigest()[:8]
        return f'{m.group(1)}{ref}?v={h}{m.group(3)}'
    return _IMG.sub(rep, html_text)
