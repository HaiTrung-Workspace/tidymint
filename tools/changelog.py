# Release notes, one entry per version, newest first. Both languages are written by hand.
# `python3 tools/changelog.py` writes CHANGELOG.md; tools/guides.py renders /changelog/ and /vi/lich-su-cap-nhat/.
RELEASES = [
    dict(ver="0.3.2", date="2026-10-27", status="released",
         en=["Star White: a light theme, with every colour checked for contrast (WCAG AA or better)",
             "New mint-leaf icon with a serrated leaf; the wordmark shows \"mint\" in leaf green",
             "Text and buttons take their colour from the theme everywhere, so light themes stay readable",
             "Remaining English strings in the Vietnamese interface translated; dates follow the app language"],
         vi=["Star White: giao diện sáng, mọi màu chữ đã đo tương phản (đạt WCAG AA trở lên)",
             "Biểu tượng lá bạc hà mới có răng cưa; chữ \"mint\" trong logo mang màu lá",
             "Chữ và nút lấy màu theo giao diện ở mọi chỗ, giao diện sáng không còn chữ trắng",
             "Dịch nốt các dòng còn tiếng Anh trong bản tiếng Việt; ngày tháng theo ngôn ngữ app"]),
    dict(ver="0.3.1", date="2026-10-27", status="released",
         en=["Clean by App: Zalo, Chrome, Edge, Cốc Cốc and CapCut, by type and by month, with messages and logins locked",
             "Undo the last clean from the Trash page",
             "Safety level and a plain explanation on every cleanup group",
             "Uninstaller pre-selects only files matched by bundle id; name matches and anything holding a database are left for you",
             "Startup Items show who signed each item and flag unusual locations or names",
             "Darker mint theme with glass bubbles in Space Lens",
             "Update check: a quiet note in Settings when a newer version is on GitHub"],
         vi=["Dọn theo ứng dụng: Zalo, Chrome, Edge, Cốc Cốc, CapCut, chia theo loại và theo tháng, tin nhắn và đăng nhập bị khoá",
             "Hoàn tác lần dọn vừa rồi ngay ở trang Thùng rác",
             "Mỗi nhóm dọn có mức an toàn và một câu giải thích",
             "Gỡ app chỉ chọn sẵn file khớp theo bundle id; khớp theo tên hoặc có database bên trong thì để bạn tự quyết",
             "Tự chạy khi bật máy hiện ai đã ký từng mục và đánh dấu vị trí, tên bất thường",
             "Giao diện xanh bạc hà đậm hơn, bong bóng kính ở Bản đồ ổ đĩa",
             "Báo bản mới: một dòng nhỏ ở Cài đặt khi GitHub có bản cao hơn"]),
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
