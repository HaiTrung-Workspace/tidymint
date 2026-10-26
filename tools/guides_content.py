# Guide page content for tools/guides.py. Body is HTML; {CTA} inserts the download box, {HOME} the language home path.
# Keep facts sourced (see "sources"), update "date" when a page changes.

GUIDES = [
dict(
  lang="vi", slug="cleanmymac-mien-phi", date="2026-10-26", read="8 phút đọc",
  title="CleanMyMac miễn phí? Lựa chọn hợp pháp thay bản crack | Tidymint",
  desc="CleanMyMac không có bản miễn phí, chỉ dùng thử 7 ngày. Bản crack có rủi ro mã độc. Đây là các cách dọn Mac miễn phí và hợp pháp, kèm bảng so sánh.",
  crumb="CleanMyMac miễn phí",
  h1="CleanMyMac miễn phí: có cách nào hợp pháp không?",
  tldr="CleanMyMac <b>không có bản miễn phí lâu dài</b>, chỉ cho dùng thử 7 ngày, sau đó phải trả khoảng 40 USD/năm cho một máy. Bản crack trôi nổi trên mạng là con đường lây mã độc quen thuộc trên Mac. Nếu bạn chỉ cần <b>dọn rác, gỡ app sạch và lấy lại dung lượng</b>, có thể dùng công cụ sẵn trong macOS hoặc các app miễn phí, mã nguồn mở như <b>Tidymint</b>.",
  toc=[("co-mien-phi-khong","CleanMyMac có miễn phí không?"),("vi-sao-khong-crack","Vì sao không nên dùng bản crack"),
       ("ban-can-gi","Bạn thật sự cần CleanMyMac để làm gì?"),("lua-chon-mien-phi","4 lựa chọn miễn phí, hợp pháp"),
       ("tidymint-vs-cleanmymac","Tidymint và CleanMyMac khác nhau thế nào"),("cai-tidymint","Cài Tidymint trong 2 phút"),("faq","Câu hỏi thường gặp")],
  body="""
<h2 id="co-mien-phi-khong">CleanMyMac có miễn phí không?</h2>
<p><b>Không.</b> CleanMyMac của hãng MacPaw (Ukraina) là app trả phí. Hãng cho <b>dùng thử 7 ngày đầy đủ tính năng</b>, sau đó bạn phải mua mới dùng tiếp.</p>
<p>Giá tham khảo trên trang của MacPaw (ghi nhận tháng 8/2026, giá thực tế thay đổi theo quốc gia và thuế):</p>
<div class="tbl"><table>
<tr><th>Gói</th><th>Trả theo năm</th><th>Trả theo tháng</th></tr>
<tr><td>1 máy Mac</td><td>khoảng 40 USD/năm (3,33 USD/tháng)</td><td>9,95 USD/tháng</td></tr>
<tr><td>2 máy Mac</td><td>khoảng 64 USD/năm</td><td>15,95 USD/tháng</td></tr>
<tr><td>5 máy Mac</td><td>khoảng 128 USD/năm</td><td>32,95 USD/tháng</td></tr>
</table></div>
<p>MacPaw vẫn bán bản mua đứt (một lần), nhưng bản này <b>không được nâng cấp lên phiên bản lớn tiếp theo</b>. Muốn lên đời thì phải mua tiếp hoặc chuyển sang thuê bao. Với người dùng ở Việt Nam, 40 USD/năm tương đương khoảng 1 triệu đồng mỗi năm, chỉ để dọn máy.</p>
<p>Đó là lý do mỗi tháng có hàng nghìn lượt tìm "cleanmymac crack" hoặc "cleanmymac miễn phí".</p>

<h2 id="vi-sao-khong-crack">Vì sao không nên dùng CleanMyMac crack</h2>
<p>Với hầu hết phần mềm, bản crack đã rủi ro. Với <b>app dọn dẹp</b>, rủi ro còn lớn hơn, vì loại app này cần quyền cao nhất trên máy:</p>
<ul>
<li><b>Quyền đọc toàn bộ ổ đĩa</b> (Full Disk Access): đọc được ảnh, tin nhắn, tài liệu, dữ liệu trình duyệt của bạn.</li>
<li><b>Mật khẩu quản trị</b>: nhiều thao tác dọn hệ thống đòi bạn nhập mật khẩu máy.</li>
<li><b>Chạy nền liên tục</b>: biểu tượng trên thanh menu, tự khởi động cùng máy.</li>
</ul>
<p>Một bản crack bị cài thêm mã độc sẽ được bạn tự tay trao đủ cả ba quyền trên. Đây không phải chuyện giả định: tháng 1/2024, nhóm bảo mật Jamf Threat Labs công bố đã tìm thấy <b>nhiều app Mac lậu bị cài cửa hậu</b> (backdoor, đoạn mã cho kẻ gian điều khiển máy từ xa), phát tán qua các trang chia sẻ phần mềm crack.</p>
<div class="warn"><p>Ngoài mã độc, bản crack không nhận được bản vá lỗi, dễ hỏng sau mỗi lần cập nhật macOS, và là vi phạm bản quyền.</p></div>
<p>Tin tốt: phần lớn người tìm CleanMyMac chỉ cần vài việc cơ bản, và những việc đó làm miễn phí được.</p>

<h2 id="ban-can-gi">Bạn thật sự cần CleanMyMac để làm gì?</h2>
<p>Đối chiếu nhu cầu của bạn với bảng dưới. Nếu nhu cầu nằm ở mấy dòng đầu, bạn không cần trả tiền.</p>
<div class="tbl"><table>
<tr><th>Nhu cầu</th><th>Tự làm bằng macOS</th><th>Tidymint (miễn phí)</th><th>CleanMyMac (trả phí)</th></tr>
<tr><td>Dọn bộ nhớ đệm, file tạm, nhật ký</td><td class="n">Làm tay, khá mất công</td><td class="y">Có</td><td class="y">Có</td></tr>
<tr><td>Xem "Dữ liệu hệ thống" gồm những gì</td><td class="n">Khó, phải mò Finder</td><td class="y">Có (bản đồ ổ đĩa)</td><td class="y">Có</td></tr>
<tr><td>Gỡ app sạch cả phần sót lại</td><td class="n">Kéo vào Thùng rác chỉ xoá app, còn sót cài đặt</td><td class="y">Có</td><td class="y">Có</td></tr>
<tr><td>Tìm file trùng, file lớn</td><td class="n">Chỉ xem được file lớn</td><td class="y">Có</td><td class="y">Có</td></tr>
<tr><td>Quét mã độc</td><td class="y">macOS có sẵn XProtect</td><td class="n">Không</td><td class="y">Có</td></tr>
<tr><td>Tối ưu hiệu năng, quản lý cập nhật app</td><td class="n">Không</td><td class="n">Không</td><td class="y">Có</td></tr>
</table></div>

<h2 id="lua-chon-mien-phi">4 lựa chọn miễn phí, hợp pháp</h2>
<h3>1. Công cụ có sẵn trong macOS</h3>
<p>Vào <b>Cài đặt hệ thống › Cài đặt chung › Dung lượng</b>. macOS sẽ gợi ý tối ưu: tự đổ Thùng rác sau 30 ngày, đưa file lên iCloud, xem danh sách app và tài liệu lớn. Ưu điểm: an toàn tuyệt đối. Nhược điểm: không đụng tới bộ nhớ đệm, không giải thích được "Dữ liệu hệ thống" gồm gì.</p>
<h3>2. Tidymint: dọn dẹp toàn diện, có tiếng Việt</h3>
<p><a href="{HOME}">Tidymint</a> là app dọn Mac <b>miễn phí, mã nguồn mở</b> (giấy phép MIT), giao diện tiếng Việt. Một lần quét tìm bộ nhớ đệm, nhật ký, Downloads cũ, file lớn, file trùng; có bản đồ bong bóng cho thấy thư mục nào chiếm ổ; gỡ app kèm phần sót lại. Điểm khác biệt: <b>mọi thứ chỉ chuyển vào Thùng rác</b>, bạn kiểm tra xong mới tự đổ, nên lỡ chọn nhầm vẫn lấy lại được.</p>
<h3>3. AppCleaner hoặc Pearcleaner: chuyên gỡ app</h3>
<p>Nếu bạn chỉ cần gỡ app cho sạch, <b>AppCleaner</b> (miễn phí) và <b>Pearcleaner</b> (miễn phí, mã nguồn mở) làm rất tốt việc này: kéo app vào, chúng liệt kê các file cài đặt, bộ nhớ đệm đi kèm để xoá cùng.</p>
<h3>4. OnyX: cho người rành máy</h3>
<p><b>OnyX</b> là công cụ bảo trì miễn phí lâu đời, có nhiều tuỳ chọn dọn và chỉnh hệ thống. Mạnh nhưng giao diện nhiều thuật ngữ, hợp với người đã quen macOS.</p>
{CTA}

<h2 id="tidymint-vs-cleanmymac">Tidymint và CleanMyMac khác nhau thế nào</h2>
<p>Nói thẳng: Tidymint <b>không thay được toàn bộ</b> CleanMyMac. Tidymint tập trung vào một việc là dọn dẹp và lấy lại dung lượng.</p>
<div class="tbl"><table>
<tr><th></th><th>Tidymint</th><th>CleanMyMac</th></tr>
<tr><td>Giá</td><td class="y">Miễn phí, không tài khoản</td><td>Khoảng 40 USD/năm/máy</td></tr>
<tr><td>Mã nguồn</td><td class="y">Mở (ai cũng đọc được)</td><td>Đóng</td></tr>
<tr><td>Khi dọn</td><td class="y">Chuyển vào Thùng rác, bạn kiểm tra rồi tự đổ</td><td>Dọn theo thiết lập của app</td></tr>
<tr><td>Quét mã độc, tối ưu hiệu năng</td><td class="n">Không có</td><td class="y">Có</td></tr>
<tr><td>Apple công chứng (notarize)</td><td class="n">Chưa, lần đầu mở phải bấm "Vẫn mở"</td><td class="y">Có</td></tr>
<tr><td>Hỗ trợ</td><td>Qua email và GitHub</td><td class="y">Đội hỗ trợ chuyên nghiệp</td></tr>
</table></div>
<p><b>Nên chọn CleanMyMac</b> nếu bạn muốn một app trọn gói có quét mã độc và sẵn sàng trả phí. <b>Nên chọn Tidymint</b> nếu bạn chỉ cần máy gọn, ổ trống, và muốn biết chính xác cái gì bị xoá.</p>

<h2 id="cai-tidymint">Cài Tidymint trong 2 phút</h2>
<ol class="steps">
<li><b>Tải về:</b> bấm <a href="{DL}">Tải Tidymint</a>, mở file zip, kéo Tidymint vào thư mục <b>Ứng dụng</b>.</li>
<li><b>Mở lần đầu:</b> macOS báo không mở được vì app chưa được Apple công chứng. Bấm <b>Xong</b>.</li>
<li><b>Cho phép:</b> vào <b>Cài đặt hệ thống › Quyền riêng tư &amp; Bảo mật</b>, kéo xuống, bấm <b>Vẫn mở</b>.</li>
<li><b>Cấp quyền đọc ổ đĩa</b> trong mục <b>Truy cập toàn bộ ổ đĩa</b> để app đo được mọi thư mục.</li>
</ol>
<p>Hướng dẫn có hình chi tiết ở <a href="{HOME}#cai-dat">trang chủ</a>. Ứng dụng cần macOS 14 trở lên, chạy được trên cả máy chip Apple và Intel.</p>
""",
  faq=[
    ("CleanMyMac dùng thử được bao lâu?", "7 ngày với đầy đủ tính năng, áp dụng cho bản mua trên trang MacPaw, App Store và Setapp. Hết hạn thì phải mua mới dùng tiếp."),
    ("Dùng CleanMyMac crack có sao không?", "Rủi ro cao. App dọn dẹp cần quyền đọc toàn bộ ổ đĩa và mật khẩu quản trị, nên bản crack bị cài mã độc có thể đọc dữ liệu hoặc điều khiển máy từ xa. Jamf Threat Labs từng phát hiện app Mac lậu bị cài cửa hậu (01/2024)."),
    ("Tidymint có miễn phí mãi không?", "Có. Tidymint là mã nguồn mở theo giấy phép MIT, không có bản trả phí, không cần tài khoản. Mã nguồn công khai trên GitHub."),
    ("Mac có cần app dọn dẹp không?", "Không bắt buộc. macOS tự quản lý khá tốt. App dọn dẹp hữu ích khi ổ gần đầy, nhất là máy 256 GB, hoặc khi mục Dữ liệu hệ thống phình to mà bạn không biết vì sao."),
    ("Gỡ CleanMyMac đang cài thế nào cho sạch?", "Thoát CleanMyMac (cả biểu tượng trên thanh menu), rồi dùng tính năng Gỡ app của Tidymint hoặc AppCleaner để xoá app cùng các file đi kèm."),
  ],
  sources=[
    ("MacPaw: các phiên bản CleanMyMac và thời gian dùng thử", "https://macpaw.com/support/cleanmymac/knowledgebase/editions"),
    ("PricingSaaS: bảng giá CleanMyMac (ghi nhận 08/2026)", "https://pricingsaas.com/companies/cleanmymac"),
    ("Jamf Threat Labs: mã độc trong app Mac lậu (01/2024)", "https://www.jamf.com/blog/jtl-malware-pirated-applications/"),
    ("Apple: Mở app an toàn trên máy Mac", "https://support.apple.com/102445"),
  ],
  related=[("Trang chủ Tidymint", "{HOME}"), ("Mã nguồn trên GitHub", "https://github.com/HaiTrung-Workspace/tidymint")],
),
]
