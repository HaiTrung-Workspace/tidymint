# Release notes, one entry per version, newest first. Both languages are written by hand.
# `python3 tools/changelog.py` writes CHANGELOG.md; tools/guides.py renders /changelog/ and /vi/lich-su-cap-nhat/.
RELEASES = [
    dict(ver="0.3.3", date="", status="next",
         en=["Only one copy of Tidymint runs at a time: launching a new build quits the old one",
             "Install guide with a screenshot for every step"],
         vi=["Chỉ một bản Tidymint chạy tại một lúc: mở bản mới sẽ tự tắt bản cũ",
             "Hướng dẫn cài đặt có ảnh cho từng bước"]),
    dict(ver="0.3.2", date="2026-10-27", status="released",
         en=["New: Star White, a light theme",
             "New app icon and favicon",
             "Better readability on every theme",
             "Vietnamese: remaining text translated, dates in Vietnamese"],
         vi=["Mới: giao diện sáng Star White",
             "Biểu tượng app và favicon mới",
             "Dễ đọc hơn trên mọi giao diện",
             "Tiếng Việt: dịch nốt phần còn sót, ngày tháng kiểu Việt"]),
    dict(ver="0.3.1", date="2026-10-27", status="released",
         en=["New: Clean by App for Zalo, Chrome, Edge, Cốc Cốc and CapCut",
             "New: Undo the last clean from the Trash page",
             "Safety level on every cleanup group",
             "Uninstaller and Startup Items are more careful about what they pre-select and flag",
             "Update check in Settings",
             "Darker mint theme"],
         vi=["Mới: Dọn theo ứng dụng cho Zalo, Chrome, Edge, Cốc Cốc, CapCut",
             "Mới: Hoàn tác lần dọn vừa rồi ở trang Thùng rác",
             "Mỗi nhóm dọn có mức an toàn",
             "Gỡ app và Tự chạy khi bật máy chọn sẵn và cảnh báo thận trọng hơn",
             "Báo bản mới ở Cài đặt",
             "Giao diện bạc hà đậm hơn"]),
    dict(ver="0.3.0", date="2026-10-26", status="released",
         en=["Universal build for Apple silicon and Intel, macOS 14 or later",
             "Download and install guide in English and Vietnamese",
             "Contact address hello@tidymint.app in the app, website and privacy policy"],
         vi=["Bản chạy chung cho máy chip Apple và Intel, macOS 14 trở lên",
             "Hướng dẫn tải và cài bằng tiếng Anh và tiếng Việt",
             "Địa chỉ liên hệ hello@tidymint.app trong app, web và chính sách riêng tư"]),
    dict(ver="0.2.0", date="2026-10-26", status="released",
         en=["Renamed from Disk Cleanup to Tidymint, mint theme and mint-leaf icon",
             "New screenshots and the tidymint.app website"],
         vi=["Đổi tên từ Disk Cleanup thành Tidymint, giao diện và biểu tượng lá bạc hà",
             "Ảnh chụp mới và website tidymint.app"]),
    dict(ver="0.1.0", date="2026-10-25", status="released",
         en=["First public build: Smart Scan, Cleanup, Uninstaller, Large and old files, Duplicates, Space Lens, Cloud Cleanup, Startup Items, Statistics",
             "Everything goes to the Trash, nothing is deleted outright",
             "English and Vietnamese"],
         vi=["Bản đầu tiên: Quét thông minh, Dọn rác, Gỡ app, File lớn và cũ, File trùng, Bản đồ ổ đĩa, Dữ liệu đám mây, Tự chạy khi bật máy, Thống kê",
             "Mọi thứ vào Thùng rác, không xoá thẳng",
             "Tiếng Anh và tiếng Việt"]),
]

def markdown():
    out = ["# Changelog", "", "All notable changes to Tidymint. Dates are release dates.", ""]
    for r in RELEASES:
        head = "Unreleased (next: %s)" % r["ver"] if r["status"] == "next" else "%s (%s)" % (r["ver"], r["date"])
        out.append("## " + head); out.append("")
        out += ["- " + x for x in r["en"]]; out.append("")
    return "\n".join(out)

if __name__ == "__main__":
    import os
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    open(os.path.join(root, "CHANGELOG.md"), "w").write(markdown())
    print("wrote CHANGELOG.md")
