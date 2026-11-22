#!/usr/bin/env python3
"""Generate the Tidymint Plus page: docs/plus/index.html and docs/vi/plus/index.html.
The app's Plus button opens these two addresses. Run from the repository root: python3 tools/plus_page.py

The shell (head, top bar, footer, cookie notice) is the homepage's (site.py), so the two cannot drift.
Until ON_SALE is True and every checkout link in BUY is filled in, the buy buttons are off, no link is in the page,
the page is noindex and the build says so."""
import html, json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib.util
from stamp import stamp
import plus_scenes

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_spec = importlib.util.spec_from_file_location("tmsite", os.path.join(ROOT, "tools", "site.py"))
S = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(S)

# Polar checkout links, one per product. Each single link also offers Plus at checkout (metadata: chon=<tool>).
try:
    from plus_links import BUY
except ModuleNotFoundError as e:
    if e.name != "plus_links":
        raise
    BUY = dict.fromkeys(("plus", "mintbar", "mintangle", "mintdrop", "mintclip", "mintsort"), "")   # the public copy
# The sales switch. Turn it on only with the owner's word, after Polar has approved the account and the 1.0.0 download is out.
ON_SALE = True
READY = ON_SALE and all(BUY.values())
# Order of demand (Semrush, US and VN, 22/11/2026: research/2026-11-22_thu-tu-tinh-nang-plus.md). In each list below the
# Plus rows go: the limit it lifts, then pain and search volume, then the finer options. Keep that order when adding.
TOOLS = [("mintangle", "Mintangle", "tiling"), ("mintclip", "Mintclip", "clip"), ("mintbar", "Mintbar", "menubar"),
         ("mintdrop", "Mintdrop", "shelf"), ("mintsort", "Mintsort", "byapp")]

CSS = """
.plus-hero{padding-bottom:8px}
.plus-hero .kicker{display:inline-block;margin-bottom:14px;font-size:13px;font-weight:700;letter-spacing:.04em;color:var(--leaf)}
.plus-hero .cta{justify-content:center}
.plans{display:grid;grid-template-columns:minmax(0,41fr) minmax(0,59fr);gap:20px;max-width:1080px;margin:0 auto}
.plans:has(.more[open]){align-items:start}
.plan{display:flex;flex-direction:column;padding:30px;border-radius:20px;border:1px solid var(--line);background:var(--card)}
.plan.full{border-color:#2fd39f88;background:linear-gradient(160deg,#0f3d30,#08201a)}
.plan h2{font-size:22px;line-height:1.3;margin:0}
.plan .top{display:flex;align-items:center;justify-content:space-between;gap:10px;min-height:30px}
.plan .best{padding:4px 12px;border-radius:999px;background:var(--leaf);color:var(--bg);font-size:13px;font-weight:700;white-space:nowrap}
.plan .was{display:flex;flex-wrap:wrap;align-items:baseline;gap:0 8px;margin:14px 0 0;color:var(--sub);font-size:14px}
.plan .was s{font-size:22px;font-weight:600;white-space:nowrap}
.plan .price{display:flex;flex-wrap:wrap;align-items:baseline;gap:0 10px;margin:2px 0 0}
.plan .price b{font-size:52px;line-height:1.1;letter-spacing:-.02em;white-space:nowrap}
.plan .price span,.plan .when{color:var(--sub);font-size:14px}
.plan .when{margin:4px 0 0}
.plan .when b{color:var(--leaf)}
.plan .pitch{font-size:19px;font-weight:600;line-height:1.4;margin:22px 0 12px}
.plan ul{list-style:none;padding:0;margin:0 0 18px}
.plan li.f{display:flex;gap:10px;align-items:flex-start;padding:5px 0}
.plan li.f svg{flex:none;color:var(--leaf);margin-top:5px}
.plan li.f small{display:block;color:var(--sub);font-size:13px;line-height:1.45}
.plan .only{margin:0 0 20px;padding:14px 16px 10px;border-radius:12px;border:1px solid #2fd39f55;background:#2fd39f14}
.plan .only h3{margin:0 0 4px;color:var(--leaf);font-size:14px;line-height:1.4}
.plan .only ul{margin:0}
.plan .full-buy{margin-top:auto}
.sums{max-width:1080px;margin:20px auto 0;padding:16px 20px;border-radius:16px;background:#ffffff0d;font-size:14px}
.sums p{margin:0 0 8px;color:var(--sub);text-align:center}
.sums dl{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:8px;margin:0;text-align:center}
.sums dt{color:var(--sub)}
.sums dd{margin:0;font-size:19px;font-weight:700;white-space:nowrap}
.sums .w dt,.sums .w dd{color:var(--leaf);font-weight:700}
@media (max-width:600px){.sums dl{grid-template-columns:repeat(2,minmax(0,1fr));gap:12px 8px}}
.plan .btn{justify-content:center;white-space:nowrap}
.plan .btn.wide{width:100%}
.plan .btn[disabled]{cursor:default}
.plan .btn[disabled]:hover{filter:none}
.plan .freenote{margin:18px 0 10px;padding:9px 12px;border-radius:10px;background:#ffffff0d;color:var(--text);font-size:13px;line-height:1.45}
/* one grid for the header, each tool and its drop-down, so Free and Plus stand in two straight columns */
.plan.one{--cols:22px minmax(0,1fr) 98px 114px 72px}
.colhead,.singles .row,.sub .r{display:grid;grid-template-columns:var(--cols);column-gap:8px}
.colhead{font-size:13px;font-weight:700;color:var(--sub)}
.colhead>span{padding:8px 4px;text-align:center}
.colhead .name{grid-column:1/3;text-align:left;padding-left:0}
.colhead .a{grid-column:3}
.colhead .b{grid-column:4;color:var(--leaf);background:#2fd39f14;border-radius:8px 8px 0 0}
.plan .singles{margin-bottom:12px}
.singles>li{border-top:1px solid var(--line)}
.singles .row>svg{grid-column:1;align-self:center;color:var(--leaf)}
.singles .row>.name{grid-column:2;align-self:center;padding:10px 0 2px;min-width:0}
.singles .name b{display:block;line-height:1.3;white-space:nowrap}
.singles .name small{display:block;color:var(--sub);font-size:13px;line-height:1.4}
.singles .pl{color:var(--leaf);font-size:inherit}
.singles .row>.a,.singles .row>.b,.sub .r>.a,.sub .r>.b{display:flex;flex-direction:column;justify-content:center;align-items:center;padding:6px 4px;text-align:center;font-size:13px;line-height:1.3}
.singles .row>.a,.sub .r>.a{grid-column:3;color:var(--sub)}
.singles .row>.b,.sub .r>.b{grid-column:4;color:var(--text)}
/* one unbroken Plus band under every row, open or closed (72 buy button + 8 gap from the right) */
.plan .singles{position:relative}
.singles:before{content:"";position:absolute;top:0;bottom:0;right:80px;width:114px;background:#2fd39f14;border-radius:0 0 8px 8px;pointer-events:none}
.singles .row>.b{color:var(--leaf);font-weight:700}
.singles .k{display:none}
.singles .no{opacity:.7}
.singles .btn{grid-column:5;align-self:center;justify-self:end;min-width:72px;padding:7px 12px;font-size:14px}
.singles .more{margin:0;padding:0;border:0;border-radius:0;background:none}
.singles .more>summary{display:flex;align-items:center;gap:8px;min-height:36px;padding:4px 0 8px 30px;color:var(--leaf);font-size:13px;font-weight:600;line-height:1.3}
.singles .more>summary:after,.singles .more[open]>summary:after{content:"";float:none;flex:none;width:7px;height:7px;margin-top:-4px;border:solid currentColor;border-width:0 1.5px 1.5px 0;transform:rotate(45deg)}
.singles .more[open]>summary:after{margin-top:4px;transform:rotate(225deg)}
.singles .sub{margin:0 0 14px}
.sub .r>.f{grid-column:1/3;padding:7px 6px 7px 30px;color:var(--sub);font-size:13px;line-height:1.35}
.sub .r:not(.h){border-top:1px solid #ffffff12}
.sub svg{color:var(--leaf)}
.sub .h>.f{padding-top:14px;color:var(--text);font-weight:700}
.sub .h>.a,.sub .h>.b{padding-top:14px;font-weight:700}
.sub .h>.b{color:var(--leaf)}
.plan .nocredit{margin:auto 0 0;padding-top:12px;color:var(--sub);font-size:13px}
.planfine{max-width:760px;margin:18px auto 0;text-align:center;color:var(--sub);font-size:13px}
.trial,.safe{display:grid;gap:16px;max-width:1080px;margin:0 auto;padding:0;list-style:none}
.trial{grid-template-columns:repeat(3,minmax(0,1fr))}
.trial li,.safe>div{padding:22px;border:1px solid var(--line);border-radius:16px;background:var(--card)}
.trial .num{display:flex;align-items:center;justify-content:center;width:38px;height:38px;margin-bottom:14px;border-radius:50%;background:var(--leaf);color:var(--bg);font-weight:800}
.trial b,.safe b{display:block;margin-bottom:5px;line-height:1.35}
.trial p,.safe p{margin:0;color:var(--sub);font-size:14px;line-height:1.5}
.trial-go{margin-top:22px;text-align:center}
.trial-go p{margin:10px 0 0;color:var(--sub);font-size:13px}
.safe{grid-template-columns:repeat(4,minmax(0,1fr))}
.safe svg{display:block;margin-bottom:14px;color:var(--leaf)}
.safe a{display:inline-block;margin-top:10px;font-size:14px;font-weight:600}
.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}
.plus-faq{max-width:820px;margin:0 auto}
.plus-faq summary{display:flex;justify-content:space-between;align-items:center;gap:12px}
.plus-faq summary:after{flex:none}
.plus-end .cta{justify-content:center}
@media (max-width:1060px){
 .plans{grid-template-columns:minmax(0,1fr);max-width:720px}
 .sums{max-width:720px}
}
@media (max-width:820px){
 .plan{padding:24px 20px}
 .trial{grid-template-columns:minmax(0,1fr)}
 .trial li{display:grid;grid-template-columns:38px minmax(0,1fr);gap:0 14px;padding:18px}
 .trial .num{grid-row:1/3;margin:0}
 .safe{grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}
 .safe>div{padding:18px}
}
@media (max-width:600px){
 .plan .price b{font-size:44px}
 .safe{grid-template-columns:minmax(0,1fr)}
 .safe>div{display:grid;grid-template-columns:24px minmax(0,1fr);gap:0 12px}
 .safe svg{grid-row:1/4;margin:0}
 .colhead{display:none}
 .singles .row{grid-template-columns:22px minmax(0,1fr) minmax(0,1fr) 72px;column-gap:0;padding-top:10px}
 .singles .row>svg{grid-row:1}
 .singles .row>.name{grid-column:2/4;grid-row:1;padding:0 4px 0 8px}
 .singles .btn{grid-column:4;grid-row:1}
 .singles .row>.a,.singles .row>.b{grid-row:2;margin-top:10px;padding:8px 4px}
 .singles:before{display:none}
 .singles .row>.a,.singles .row>.b{grid-column:1/-1;width:50%}
 .singles .row>.a{justify-self:start;background:#ffffff0d;border-radius:8px 0 0 8px}
 .singles .row>.b{justify-self:end;background:#2fd39f14;border-radius:0 8px 8px 0}
 .sub .r>.b{background:#2fd39f14}
 .singles .k{display:block;font-size:11px;font-weight:400;color:var(--sub)}
 .singles .more>summary{padding:8px 0}
 .sub .r{grid-template-columns:minmax(0,1fr) 62px 78px;column-gap:0}
 .sub .r>.f{grid-column:1;padding-left:0}
 .sub .r>.a{grid-column:2;padding-left:2px;padding-right:2px}
 .sub .r>.b{grid-column:3;padding-left:2px;padding-right:2px}
}
"""

Y, N = True, False  # in the table; a string is shown as written

T = {
"vi": dict(
  title="Tidymint Plus: mua một lần, lẻ hoặc trọn gói | Tidymint",
  desc="Mở rộng Mintbar, Mintangle, Mintdrop, Mintclip, thêm Mintsort. Trọn gói 10,99 USD hoặc 3,99 USD mỗi công cụ. Dùng thử 14 ngày.",
  kicker="Tidymint Plus", h1="Gọn hơn nữa. <span>Theo cách của bạn.</span>",
  sub="Plus thêm việc cho từng công cụ Mint. Dọn dẹp vẫn miễn phí.",
  see="Xem giá", dl="Tải Tidymint", reassure="Mua một lần · Không thuê bao · Dùng thử 14 ngày",
  pid="gia", full_h="Plus trọn gói", cur="USD", full_price="10,99", single_price="3,99", once="mua một lần",
  best="Lợi nhất", full_was=("19,99", "giá sau mở bán"), single_was=("6,99", "giá sau mở bán"),
  full_when="Giá mở bán. <b>Chỉ khoảng 2,20 USD mỗi công cụ.</b>", pitch="Full tính năng Plus",
  full_li=[("Plus cho cả 5 công cụ", "Mintangle, Mintclip, Mintbar, Mintdrop, Mintsort"),
           ("Khỏi phải chọn món", "Cần tới công cụ nào cũng đã có sẵn"),
           ("Một lần mua, một key", "Khỏi giữ 5 key, khỏi nhập từng key"),
           ("Dùng trên 2 máy Mac", "Máy bàn và máy mang đi dùng chung một key")],
  only_h="Chỉ có trong trọn gói, không bán lẻ",
  only=[("Tự dọn Thùng rác", "Tắt sẵn. Bật thì xoá hẳn món cũ trong Thùng rác theo số ngày hoặc GB bạn đặt"),
        ("Đồng bộ cài đặt", "Mang cách bạn cài đặt sang máy Mac kia qua iCloud Drive")],
  sums_h="Cần hơn một công cụ?",
  sums=[("Mua lẻ 2", "7,98 USD", N), ("Mua lẻ 3", "11,97 USD", N), ("Mua lẻ 5", "19,95 USD", N), ("Trọn gói cả 5", "10,99 USD", Y)],
  buy_full="Mua trọn gói", single_h="Plus từng công cụ", each="mỗi công cụ, mua một lần",
  single_when="Giá mở bán",
  about=dict(mintbar="Gọn menu bar", mintangle="Gọn cửa sổ", mintdrop="Gọn kéo thả", mintclip="Gọn copy", mintsort="Gọn Tải về, Desktop"),
  free_note="Chỉ mua khi cần thêm. Phần miễn phí vẫn dùng được, không hết hạn.",
  tiers=dict(mintbar=("2 nhóm", "Không giới hạn"), mintangle=("11 thao tác", "24 thao tác"), mintdrop=("5 món", "Không giới hạn"),
             mintclip=("100 mục", "500 mục"), mintsort=("Không có", "Đủ tính năng")),
  cols=("Công cụ", "Miễn phí", "Plus"), adds="Xem %d điểm Plus thêm", only_plus="Xem %d tính năng", feature="Tính năng",
  buy="Mua", nocredit="Mua lẻ không được trừ vào giá trọn gói.",
  fine="Mỗi key dùng cho 2 máy Mac. Thanh toán qua Polar. Ở Mỹ, Canada, Ấn Độ, thuế có thể tính thêm khi thanh toán.",
  yes="Có", no="Không",
  groups=[
    ("mintangle", "Mintangle", [
      ("Chia đôi màn hình, 4 góc, phóng to, căn giữa", Y, Y),
      ("Kéo vào mép để xếp, đổi được phím tắt", Y, Y),
      ("Tổng số thao tác", "11", "24"),
      ("Chia 3 màn hình: 1/3 và 2/3", N, Y),
      ("Chuyển sang màn hình khác", N, Y),
      ("Gần kín, cao hết, to thêm, nhỏ lại", N, Y),
      ("Lưu cách xếp cửa sổ rồi xếp lại", N, Y),
      ("Cỡ và vị trí tự đặt", N, Y),
      ("Bảng chọn vị trí, vùng mép tự đặt", N, Y),
      ("Bấm lại phím tắt để đổi cỡ", N, Y),
      ("Chuyển sang Desktop khác", N, Y),
      ("Giữ phím rồi kéo, vòng chọn quanh con trỏ", N, Y),
      ("Khoảng cách giữa cửa sổ, app bỏ qua", N, Y),
      ("Kéo cửa sổ ra là về cỡ cũ", N, Y),
      ("Phím tắt cho cửa sổ dưới con trỏ", N, Y)]),
    ("mintclip", "Mintclip", [
      ("Lịch sử copy: chữ, link, ảnh, file", Y, Y),
      ("Tìm kiếm, cả chữ trong ảnh", Y, Y),
      ("Bỏ qua trình quản lý mật khẩu", Y, Y),
      ("Số mục được giữ", "100", "500"),
      ("Dán không kèm định dạng", N, Y),
      ("Đồng bộ iCloud giữa các Mac, tắt sẵn", N, Y),
      ("Ghim mục hay dùng", N, Y),
      ("Bảng ghim, đặt tên và sửa mục", N, Y),
      ("Dán lần lượt hoặc gộp nhiều mục", N, Y),
      ("Dán nhanh bằng ⌘1 tới ⌘9", N, Y),
      ("Tạm dừng ghi, mở ngay chỗ con trỏ", N, Y)]),
    ("mintbar", "Mintbar", [
      ("Giấu icon, bấm là hiện", Y, Y),
      ("Bộ icon cơ bản, chấm dưới nhóm", Y, Y),
      ("Nhóm icon (macOS 27)", "2", "Không giới hạn"),
      ("App trong mỗi nhóm", "4", "Không giới hạn"),
      ("Wi-Fi, Bluetooth trong nhóm", N, Y),
      ("Tiện ích CPU, bộ nhớ, mạng", N, Y),
      ("Chỉnh khoảng cách giữa các icon", N, Y),
      ("Tìm icon bằng cách gõ tên", N, Y),
      ("Phím tắt cho nhóm, cho app, chọn bằng phím", N, Y),
      ("Mọi bộ icon, màu riêng, kiểu chấm", N, Y),
      ("Vạch ngăn, nhãn chữ hay emoji", N, Y),
      ("Hồ sơ tự đổi theo màn hình và nguồn điện", N, Y),
      ("Kéo đổi thứ tự app trong nhóm", N, Y),
      ("Nhãn hiện kết quả script của bạn", N, Y)]),
    ("mintdrop", "Mintdrop", [
      ("Lắc là có kệ, xem nhanh", Y, Y),
      ("Hoàn tác khi kéo nhầm", Y, Y),
      ("Số món trên kệ", "5", "Không giới hạn"),
      ("Kéo cả nhóm ra một lần", N, Y),
      ("Đổi HEIC sang JPG, đổi cỡ ảnh", N, Y),
      ("Gộp, nén PDF; nén ZIP, video", N, Y),
      ("Chuyển tới thư mục hay Thùng rác", N, Y),
      ("Nhiều kệ, kệ ghim, kệ gần đây", N, Y),
      ("Thư mục theo dõi, có file mới là mở kệ", N, Y),
      ("Lấy chữ từ ảnh, xoá vị trí trong ảnh", N, Y),
      ("Mở kệ từ menu bar hay mép màn hình", N, Y),
      ("Giữ lịch sử Hoàn tác sau khi tắt app", N, Y),
      ("Kéo to kệ", N, Y),
      ("Hành động riêng: Phím tắt, AppleScript", N, Y)]),
    ("mintsort", "Mintsort", [
      ("Sắp Tải về và Desktop theo nhóm", N, Y),
      ("Xem trước rồi mới dời", N, Y),
      ("Hoàn tác: 30 ngày, xếp tự động 7 ngày", N, Y),
      ("Tự giữ Tải về gọn", N, Y),
      ("Tìm thư mục trùng và thư mục rỗng", N, Y),
      ("Gắn tag màu, mở sau khi xếp", N, Y),
      ("Chạy hành động sau khi xếp", N, Y)])],
  trial_id="dung-thu", trial_h="Thử trước, mua sau",
  trial=[("Tải Tidymint", "Phần miễn phí dùng được luôn, không cần tài khoản."),
         ("Bấm Dùng thử 14 ngày", "Trong Cài đặt › Key. Mở cả Plus, không cần thẻ."),
         ("Giữ món bạn cần", "Mua một công cụ hoặc trọn gói. Không mua thì dùng tiếp phần miễn phí.")],
  trial_fine="Mỗi máy thử một lần. Không tự trừ tiền.",
  safe_id="yen-tam", safe_h="Mua yên tâm",
  safe=[("free", "Dọn dẹp vẫn miễn phí", "Dọn, gỡ app, tìm file trùng: trọn vẹn, mã nguồn mở.", None),
        ("check", "Mua một lần", "Không thuê bao, không có khoản trừ hằng tháng.", None),
        ("listed", "Polar lo thanh toán", "Tidymint không thấy đầy đủ số thẻ của bạn.", None),
        ("privacy", "File không rời máy", "Đồng bộ iCloud tắt sẵn, chỉ chạy khi bạn bật.", ("../quyen-rieng-tu-tidymint/", "Quyền riêng tư của Tidymint"))],
  qid="hoi-dap", faq_h="Hỏi trước khi mua",
  faq=[
    ("Mua lẻ rồi, muốn trọn gói thì sao?", "Bạn trả đủ giá trọn gói. Tiền mua lẻ không được trừ, nên hãy dùng thử trước khi chọn."),
    ("Mua xong thì dùng key thế nào?", "Dán key vào Cài đặt › Key. Mua nhiều món thì thêm từng key, các công cụ cùng mở. Mất key thì bấm Tìm lại key ở đó."),
    ("Một key dùng cho mấy máy?", "Hai máy Mac. Khi thêm một máy, bạn nhập mã được gửi về email lúc mua."),
    ("Không có mạng thì Plus có chạy không?", "Có, tới 14 ngày kể từ lần kiểm key gần nhất. Có mạng lại thì app tự kiểm, bạn không phải nhập lại key."),
    ("Hết 14 ngày thử thì sao?", "Phần Plus mờ đi, những gì bạn đã tạo vẫn còn. Phần miễn phí chạy tiếp và bạn không bị trừ tiền."),
    ("Công cụ ra sau này có trong trọn gói không?", "Không tự có. Trọn gói hôm nay gồm 5 công cụ, thêm tự dọn Thùng rác và đồng bộ cài đặt."),
    ("Thanh toán thế nào?", "Polar bán và xử lý thanh toán cho Tidymint. Hoá đơn gửi qua email."),
    ("Tidymint biết gì về tôi khi dùng Plus?", "Dùng thử và key chỉ cần nhận ra máy Mac của bạn, không cần tên. Khi bạn mua, Tidymint biết thông tin đơn hàng, để hỗ trợ và thống kê công cụ nào được mua. Tidymint không thấy đầy đủ số thẻ. Chi tiết ở trang Quyền riêng tư.")],
  end_h="Giữ MacBook luôn <span class=\"mt\">như mới.</span>", end_p="Tải Tidymint rồi thử cả Plus trong 14 ngày.",
),
"en": dict(
  title="Tidymint Plus: One Tool or All Five, Pay Once | Tidymint",
  desc="More from Mintbar, Mintangle, Mintdrop and Mintclip, plus Mintsort. $10.99 for all five or $3.99 per tool. Pay once, with a 14-day trial.",
  kicker="Tidymint Plus", h1="Tidier still. <span>Your way.</span>",
  sub="Plus adds more to every Mint tool. Cleaning stays free.",
  see="See prices", dl="Download Tidymint", reassure="Pay once · No subscription · 14-day trial",
  pid="pricing", full_h="Plus for all five", cur="", full_price="$10.99", single_price="$3.99", once="one-time",
  best="Best value", full_was=("$19.99", "price after launch"), single_was=("$6.99", "price after launch"),
  full_when="Launch price. <b>About $2.20 a tool.</b>", pitch="Every Plus feature",
  full_li=[("Plus for all 5 tools", "Mintangle, Mintclip, Mintbar, Mintdrop, Mintsort"),
           ("No need to pick", "Whichever tool you need, you already have it"),
           ("One purchase, one key", "No five keys to keep or enter one by one"),
           ("Works on 2 Macs", "One key for your desk and the Mac you carry")],
  only_h="Only in the full set, not sold separately",
  only=[("Trash rules", "Off by default. Once on, old Trash items are deleted for good, by the days or GB you set"),
        ("Settings sync", "Bring your setup to your other Mac through iCloud Drive")],
  sums_h="Need more than one tool?",
  sums=[("2 single tools", "$7.98", N), ("3 single tools", "$11.97", N), ("5 single tools", "$19.95", N), ("All five together", "$10.99", Y)],
  buy_full="Buy all five", single_h="Plus for one tool", each="per tool, one-time",
  single_when="Launch price",
  about=dict(mintbar="Tidy menu bar", mintangle="Tidy windows", mintdrop="Tidy drag and drop", mintclip="Tidy clipboard", mintsort="Tidy Downloads, Desktop"),
  free_note="Buy only when you need more. The free part keeps working, with no time limit.",
  tiers=dict(mintbar=("2 groups", "No limit"), mintangle=("11 actions", "24 actions"), mintdrop=("5 items", "No limit"),
             mintclip=("100 items", "500 items"), mintsort=("None", "All features")),
  cols=("Tool", "Free", "Plus"), adds="See %d Plus additions", only_plus="See all %d features", feature="Feature",
  buy="Buy", nocredit="Single tools don't count toward the price of all five.",
  fine="Each key works on 2 Macs. Payment through Polar. In the US, Canada and India, tax may be added at checkout.",
  yes="Yes", no="No",
  groups=[
    ("mintangle", "Mintangle", [
      ("Split screen, 4 corners, maximize, center", Y, Y),
      ("Drag to an edge, change any shortcut", Y, Y),
      ("Actions in total", "11", "24"),
      ("Split screen in three: thirds, two thirds", N, Y),
      ("Move to another display", N, Y),
      ("Almost maximize, full height, larger, smaller", N, Y),
      ("Save a window layout and put it back", N, Y),
      ("Your own sizes and places", N, Y),
      ("Snap panel, your own edge zones", N, Y),
      ("Press again to change size", N, Y),
      ("Move to another desktop (Space)", N, Y),
      ("Hold keys and drag, a ring around the pointer", N, Y),
      ("Gaps between windows, apps to skip", N, Y),
      ("Drag a window away to get its size back", N, Y),
      ("Shortcuts for the window under the pointer", N, Y)]),
    ("mintclip", "Mintclip", [
      ("Clipboard history: text, links, images, files", Y, Y),
      ("Search, even text inside images", Y, Y),
      ("Skips password managers", Y, Y),
      ("Items kept", "100", "500"),
      ("Paste without formatting", N, Y),
      ("iCloud sync between Macs, off by default", N, Y),
      ("Pin what you use often", N, Y),
      ("Pinboards, name and edit items", N, Y),
      ("Paste in sequence or merge items", N, Y),
      ("Quick paste with ⌘1 to ⌘9", N, Y),
      ("Pause, open at the pointer", N, Y)]),
    ("mintbar", "Mintbar", [
      ("Hide icons, show them with a click", Y, Y),
      ("Basic icons, dots under a group", Y, Y),
      ("Icon groups (macOS 27)", "2", "No limit"),
      ("Apps in each group", "4", "No limit"),
      ("Wi-Fi and Bluetooth in a group", N, Y),
      ("CPU, memory and network widgets", N, Y),
      ("Adjust the space between icons", N, Y),
      ("Find an icon by typing its name", N, Y),
      ("Shortcuts for groups and apps, pick by keyboard", N, Y),
      ("Every icon set, your colors, dot styles", N, Y),
      ("Dividers, text or emoji labels", N, Y),
      ("Profiles that follow your display and power", N, Y),
      ("Drag to reorder apps in a group", N, Y),
      ("Labels that show your script's result", N, Y)]),
    ("mintdrop", "Mintdrop", [
      ("Shake for a shelf, Quick Look", Y, Y),
      ("Undo a wrong drop", Y, Y),
      ("Items on the shelf", "5", "No limit"),
      ("Drag all at once", N, Y),
      ("Convert HEIC to JPG, resize images", N, Y),
      ("Merge or compress PDFs, zip, shrink video", N, Y),
      ("Move to a folder or the Trash", N, Y),
      ("Several, pinned and recent shelves", N, Y),
      ("Watched folders open the shelf", N, Y),
      ("Text from images, remove photo location", N, Y),
      ("Open from the menu bar or a screen edge", N, Y),
      ("Undo history kept after quitting", N, Y),
      ("A bigger shelf", N, Y),
      ("Your own actions: Shortcuts, AppleScript", N, Y)]),
    ("mintsort", "Mintsort", [
      ("Sort Downloads and Desktop into groups", N, Y),
      ("Preview before anything moves", N, Y),
      ("Undo: 30 days, 7 for automatic sorting", N, Y),
      ("Keep Downloads tidy by itself", N, Y),
      ("Find duplicate and empty folders", N, Y),
      ("Color tags, open after sorting", N, Y),
      ("Run an action after sorting", N, Y)])],
  trial_id="trial", trial_h="Try first, buy later",
  trial=[("Download Tidymint", "The free part works right away, with no account."),
         ("Click Try 14 Days", "In Settings › Key. All of Plus opens, no card needed."),
         ("Keep what you need", "Buy one tool or all five. Or keep using the free part.")],
  trial_fine="One trial per Mac. No automatic charge.",
  safe_id="buy-safely", safe_h="Buy with peace of mind",
  safe=[("free", "Cleaning stays free", "Clean, uninstall, find duplicates: complete and open source.", None),
        ("check", "Pay once", "No subscription, no monthly charge.", None),
        ("listed", "Polar handles payment", "Tidymint never sees your full card number.", None),
        ("privacy", "Files stay on your Mac", "iCloud sync is off until you turn it on.", ("../tidymint-privacy/", "Tidymint privacy"))],
  qid="faq", faq_h="Before you buy",
  faq=[
    ("I bought one tool. Can I get all five later?", "Yes, at the full price. What you paid for single tools is not deducted, so try before you choose."),
    ("How do I use my key?", "Paste it in Settings › Key. If you bought several tools, add each key and they open together. If you lose one, click Find it again there."),
    ("How many Macs per key?", "Two. To add a Mac, enter the code sent to the email you bought with."),
    ("Does Plus work offline?", "Yes, for up to 14 days after the last key check. Once you are back online the app checks by itself, with no need to enter the key again."),
    ("What happens when the 14-day trial ends?", "Plus features dim and what you made stays. The free part keeps working and you are not charged."),
    ("Are future tools included in the full set?", "Not automatically. Today's full set has five tools, plus Trash rules and settings sync."),
    ("How do I pay?", "Polar sells Tidymint Plus and handles payment. Your receipt comes by email."),
    ("What does Tidymint know about me with Plus?", "The trial and a key only need to recognize your Mac, with no name. When you buy, Tidymint knows your order details, to help you and to count which tools are bought. It never sees your full card number. Details are on the Privacy page.")],
  end_h="Keep your Mac in <span class=\"mt\">mint condition.</span>", end_p="Download Tidymint and try all of Plus for 14 days.",
)}


def buy_button(product, label, cls, aria=None):
    a = ' aria-label="%s"' % aria if aria else ""
    if READY:
        return '<a class="btn %s" data-buy="%s" href="%s"%s>%s</a>' % (cls, product, html.escape(BUY[product]), a, label)
    return '<button class="btn %s" data-buy="%s" type="button" disabled%s>%s</button>' % (cls, product, a, label)


def body(k):
    t = T[k]; ok = S.icon("check", 16)
    cur = (" " + t["cur"]) if t["cur"] else ""
    items_of = {key: items for key, _, items in t["groups"]}
    def mark(v):
        if v is Y: return '%s<span class="sr">%s</span>' % (ok, t["yes"])
        return t["no"] if v is N else v
    def tool(key, name, ic):
        free, plus = t["tiers"][key]
        had = [r for r in items_of[key] if r[1] is Y]
        new = [r for r in items_of[key] if r[1] is not Y]
        line = lambda r: ('<div class="r" role="row"><span class="f" role="rowheader">%s</span><span class="a%s" role="cell">%s</span>'
                          '<span class="b" role="cell">%s</span></div>') % (r[0], " no" if r[1] is N else "", mark(r[1]), mark(r[2]))
        # one header for the whole list: what is already free first, then the limits Plus lifts, then what it adds
        table = ('<div class="r h" role="row"><span class="f" role="columnheader">%s</span><span class="a" role="columnheader">%s</span>'
                 '<span class="b" role="columnheader">%s</span></div>%s') % (t["feature"], t["cols"][1], t["cols"][2], "".join(map(line, had + new)))
        return ('<li id="plus-%s"><div class="row">%s<span class="name"><b>%s <span class="pl">Plus</span></b><small>%s</small></span>'
                '<span class="a%s"><small class="k">%s</small>%s</span><span class="b"><small class="k">%s</small>%s</span>%s</div>'
                '<details class="more"><summary>%s</summary><div class="sub" role="table" aria-label="%s">%s</div></details></li>') % (
            key, S.icon(ic, 22), name, t["about"][key], " no" if not had else "", t["cols"][1], free, t["cols"][2], plus,
            buy_button(key, t["buy"], "ghost", "%s %s Plus" % (t["buy"], name)),
            (t["adds"] if had else t["only_plus"]) % len(new), name, table)
    singles = "".join(tool(*x) for x in TOOLS)
    faq = "".join('<details><summary>%s</summary><p>%s</p></details>' % (html.escape(q), html.escape(a)) for q, a in t["faq"])
    li = lambda items: "".join('<li class="f">%s<span>%s<small>%s</small></span></li>' % (ok, a, b) for a, b in items)
    # The struck price always says what it is: the price after launch (Chú, 22/11/2026: 19.99 for all five, 6.99 a tool).
    was = lambda w: '<p class="was"><s>%s%s</s><span>%s</span></p>' % (w[0], cur, w[1])
    sums = "".join('<div%s><dt>%s</dt><dd>%s</dd></div>' % (c, a, b) for a, b, best in t["sums"] for c in [' class="w"' if best else ""])
    dl = '<a class="btn %%s lg" href="%s">%s <span class="arr">↓</span></a>' % (S.DL, t["dl"])
    return f'''<header class="hero plus-hero">
  <span class="kicker">{t["kicker"]}</span>
  <h1>{t["h1"]}</h1>
  <p>{t["sub"]}</p>
  <div class="cta"><a class="btn primary lg" href="#{t["pid"]}">{t["see"]}</a>{dl % "ghost"}</div>
  <div class="micro">{t["reassure"]}</div>
</header>

<section id="{t["pid"]}" style="padding-top:48px">
  <div class="plans">
    <div class="plan full">
      <div class="top"><h2>{t["full_h"]}</h2><span class="best">{t["best"]}</span></div>
      {was(t["full_was"])}
      <div class="price"><b>{t["full_price"]}{cur}</b><span>{t["once"]}</span></div>
      <p class="when">{t["full_when"]}</p>
      <p class="pitch">{t["pitch"]}</p>
      <ul>{li(t["full_li"])}</ul>
      <div class="only"><h3>{t["only_h"]}</h3><ul>{li(t["only"])}</ul></div>
      <div class="full-buy">{buy_button("plus", t["buy_full"], "primary lg wide")}</div>
    </div>
    <div class="plan one">
      <div class="top"><h2>{t["single_h"]}</h2></div>
      {was(t["single_was"])}
      <div class="price"><b>{t["single_price"]}{cur}</b><span>{t["each"]}</span></div>
      <p class="when">{t["single_when"]}</p>
      <p class="freenote">{t["free_note"]}</p>
      <div class="colhead" aria-hidden="true"><span class="name">{t["cols"][0]}</span><span class="a">{t["cols"][1]}</span><span class="b">{t["cols"][2]}</span></div>
      <ul class="singles" id="singles">{singles}</ul>
      <p class="nocredit">{t["nocredit"]}</p>
    </div>
  </div>
  <div class="sums"><p>{t["sums_h"]}</p><dl>{sums}</dl></div>
  <p class="planfine">{t["fine"]}</p>
</section>

{plus_scenes.section(k, TOOLS, S.icon)}

<section id="{t["trial_id"]}" style="padding-top:32px">
  <div class="sechead" style="margin-bottom:24px"><h2>{t["trial_h"]}</h2></div>
  <ol class="trial">{"".join('<li><span class="num">%d</span><b>%s</b><p>%s</p></li>' % (i + 1, a, b) for i, (a, b) in enumerate(t["trial"]))}</ol>
  <div class="trial-go">{dl % "primary"}<p>{t["trial_fine"]}</p></div>
</section>

<section id="{t["safe_id"]}" style="padding-top:32px">
  <div class="sechead" style="margin-bottom:24px"><h2>{t["safe_h"]}</h2></div>
  <div class="safe">{"".join('<div>%s<b>%s</b><p>%s%s</p></div>' % (S.icon(ic, 24), a, b, '<br><a href="%s">%s →</a>' % more if more else "") for ic, a, b, more in t["safe"])}</div>
</section>

<section id="{t["qid"]}">
  <div class="sechead" style="margin-bottom:24px"><h2>{t["faq_h"]}</h2></div>
  <div class="plus-faq">{faq}</div>
</section>

<section style="padding-top:24px">
  <div class="band plus-end"><h2>{t["end_h"]}</h2><p>{t["end_p"]}</p>
  <div class="cta">{dl % "primary"}<a class="btn ghost lg" href="#{t["pid"]}">{t["see"]}</a></div></div>
</section>

'''


# Where the visitor came from in the app (/plus/?tu=<tool>) is carried to checkout as utm_content, so a sale can be
# traced to the dimmed row. The single tools keep the order of TOOLS (Chú, 22/11/2026: fixed by demand, not shuffled).
JS = """<script>
(function(){var f=new URLSearchParams(location.search).get('tu');if(!/^(mintbar|mintangle|mintdrop|mintclip|mintsort|suite)$/.test(f||''))return;
var d=document.querySelector('#plus-'+f+' details');if(d)d.open=true;
document.querySelectorAll('a[data-buy]').forEach(function(b){var l=new URL(b.href);l.searchParams.set('utm_content',f);b.href=l.toString()})})();
</script>
"""


def once(s, old, new):
    if s.count(old) != 1:
        sys.exit("STOP: plus_page expected one %r in the homepage, found %d" % (old[:70], s.count(old)))
    return s.replace(old, new)


def between(s, start, end, new):
    i = s.index(start); j = s.index(end, i)
    return s[:i] + new + s[j:]


def page(k):
    t = T[k]; home = S.T[k]; ids = S.IDS[k]
    path = home["path"] + "plus/"; url = "https://tidymint.app/" + path
    s = S.page(k)

    # head
    s = between(s, "<title>", "</title>", "<title>" + t["title"])
    for tag in ('<meta name="description" content="', '<meta property="og:description" content="'):
        s = between(s, tag, '">', tag + html.escape(t["desc"]))
    s = between(s, '<meta property="og:title" content="', '">', '<meta property="og:title" content="' + t["title"])
    s = between(s, '<meta property="og:url" content="', '">', '<meta property="og:url" content="' + url)
    s = between(s, '<link rel="canonical"', "<link rel=\"icon\"", (
        f'<link rel="canonical" href="{url}">\n'
        '<link rel="alternate" hreflang="en" href="https://tidymint.app/plus/">\n'
        '<link rel="alternate" hreflang="vi" href="https://tidymint.app/vi/plus/">\n'
        '<link rel="alternate" hreflang="x-default" href="https://tidymint.app/plus/">\n'
        + ("" if READY else '<meta name="robots" content="noindex">\n')))
    ld = [S.ORG, {"@context": "https://schema.org", "@type": "FAQPage", "mainEntity": [
        {"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}} for q, a in t["faq"]]}]
    s = between(s, '<script type="application/ld+json">', "</script>",
                '<script type="application/ld+json">' + json.dumps(ld, ensure_ascii=False))
    s = once(s, "</style>\n</head>", CSS + plus_scenes.CSS + "</style>\n</head>")

    # body
    s = between(s, '<header class="hero">', '<div class="topbar">', "@BODY@")
    # no sign-up form and no language redirect on this page
    s = between(s, "const ENDPOINT = ", "</script>\n</body>", "")
    s = once(s, "</body>", JS + plus_scenes.JS + "</body>")
    s = s.replace("try{if(!localStorage.getItem('tm-lang')&&/^vi\\b/i.test(navigator.language||'')&&!location.hash)location.replace('vi/')}catch(e){}\n", "")
    if "location.replace(" in s:
        sys.exit("STOP: the homepage's language redirect changed; plus_page must drop it")

    # nav: Plus before GitHub, and the language switch stays on this page
    s = once(s, '<a href="plus/">Plus</a>', '<a href="plus/" aria-current="page">Plus</a>')
    vi, en = ("plus/", "../plus/") if k == "vi" else ("vi/plus/", "plus/")
    s = re.sub(r'href="[^"]*"( data-l="vi")', 'href="%s"\\1' % vi, s)
    s = re.sub(r'href="[^"]*"( data-l="en")', 'href="%s"\\1' % en, s)
    s = once(s, '<a class="btn primary navcta" href="#%s">' % ids["i"], '<a class="btn primary navcta" href="%s">' % S.DL)

    # everything so far is relative to the homepage; this page sits one folder below it
    def up(m):
        ref = m.group(2)
        if re.match(r"([a-z]+:|//|/)", ref) or ref == "#top":
            return m.group(0)
        return m.group(1) + "../" + ("" if ref == "./" else ref) + m.group(3)
    s = re.sub(r'((?:href|src)=\\?")([^"\\]+)(\\?")', up, s)
    img = home["img"]
    for f in ("downloads.txt", "version.txt"):
        s = s.replace('fetch("%s%s"' % (img, f), 'fetch("../%s%s"' % (img, f))
    return s.replace("@BODY@", body(k))  # last: the body's own #anchors stay on this page


if __name__ == "__main__":
    for k, out in (("en", "docs/plus/index.html"), ("vi", "docs/vi/plus/index.html")):
        p = os.path.join(ROOT, out)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w") as f:
            f.write(stamp(page(k), p, ROOT))
        print("wrote", out)
    if not READY:
        missing = [k for k, v in BUY.items() if not v]
        why = "checkout links missing for %s" % ", ".join(missing) if missing else "ON_SALE is False"
        print("NOT READY TO PUBLISH: %s (buy buttons off, page noindex)" % why)
