# Guide page content for tools/guides.py. Body is HTML; {CTA} inserts the download box, {HOME} the language home path.
# Keep facts sourced (see "sources"), update "date" when a page changes.

GUIDES = [
dict(
  lang="vi", slug="cleanmymac-mien-phi", date="2026-10-26", read="8 phút đọc",
  title="CleanMyMac miễn phí? Cách thay bản crack hợp pháp | Tidymint",
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
<tr><td>Bảo vệ khỏi mã độc</td><td class="y">Có sẵn: XProtect, Gatekeeper</td><td>Dựa vào lớp sẵn có của macOS, không có bộ quét riêng</td><td class="y">Có bộ quét riêng</td></tr>
<tr><td>Tối ưu hiệu năng, quản lý cập nhật app</td><td class="n">Không</td><td class="n">Không</td><td class="y">Có</td></tr>
<tr><td>Hoàn tác sau khi dọn</td><td class="n">Không</td><td class="y">Có, mọi thứ vào Thùng rác trước</td><td>Tuỳ mục</td></tr>
<tr><td>Giao diện tiếng Việt</td><td class="y">Có</td><td class="y">Có</td><td class="n">Không (12 ngôn ngữ, không có tiếng Việt)</td></tr>
</table></div>

<h2 id="lua-chon-mien-phi">4 lựa chọn miễn phí, hợp pháp</h2>
<h3>1. Công cụ có sẵn trong macOS</h3>
<p>Vào <b>Cài đặt hệ thống › Cài đặt chung › Dung lượng</b>. macOS sẽ gợi ý tối ưu: tự đổ Thùng rác sau 30 ngày, đưa file lên iCloud, xem danh sách app và tài liệu lớn. Ưu điểm: an toàn tuyệt đối. Nhược điểm: không đụng tới bộ nhớ đệm, không giải thích được "Dữ liệu hệ thống" gồm gì.</p>
<h3>2. Tidymint: dọn dẹp toàn diện, có tiếng Việt</h3>
<p><a href="{HOME}">Tidymint</a> là app dọn Mac <b>miễn phí, mã nguồn mở</b> (giấy phép MIT), giao diện tiếng Việt. Một lần quét tìm bộ nhớ đệm, nhật ký, Downloads cũ, file lớn, file trùng, cho xem từng nhóm rồi bạn mới bấm Dọn; mục <b>Dọn theo ứng dụng</b> cho thấy Zalo, Chrome, Cốc Cốc, CapCut đang giữ gì (bộ nhớ đệm chọn sẵn, ảnh và file xếp theo tháng để bạn tự chọn, tin nhắn bị khoá); có bản đồ bong bóng cho thấy thư mục nào chiếm ổ; gỡ app kèm phần sót lại. Điểm khác biệt: <b>mọi thứ chỉ chuyển vào Thùng rác</b> và có nút <b>Hoàn tác</b>, nên lỡ chọn nhầm vẫn lấy lại được.</p>
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
<tr><td>Bảo vệ khỏi mã độc</td><td>Dựa vào XProtect và Gatekeeper sẵn trong macOS</td><td class="y">Có bộ quét riêng</td></tr>
<tr><td>Tối ưu hiệu năng, cập nhật app</td><td class="n">Không có</td><td class="y">Có</td></tr>
<tr><td>Thu thập dữ liệu sử dụng</td><td class="y">Không, không cần tài khoản</td><td>Có (thông tin máy, thống kê sử dụng, nhật ký dọn), theo chính sách riêng tư của MacPaw</td></tr>
<tr><td>Tiếng Việt</td><td class="y">Có</td><td class="n">Không</td></tr>
<tr><td>Apple công chứng (notarize)</td><td class="n">Chưa, lần đầu mở phải bấm "Vẫn mở"</td><td class="y">Có</td></tr>
<tr><td>Hỗ trợ</td><td>Qua email và GitHub</td><td class="y">Đội hỗ trợ chuyên nghiệp</td></tr>
</table></div>
<p><b>Nên chọn CleanMyMac</b> nếu bạn muốn một app trọn gói có bộ quét mã độc riêng và sẵn sàng trả phí. <b>Nên chọn Tidymint</b> nếu bạn chỉ cần máy gọn, ổ trống, và muốn biết chính xác cái gì bị xoá.</p>

<h2 id="cai-tidymint">Cài Tidymint trong 2 phút</h2>
<ol class="steps">
<li><b>Tải về:</b> bấm <a href="{DL}">Tải Tidymint</a>, mở file zip, kéo Tidymint vào thư mục <b>Ứng dụng</b>.</li>
<li><b>Mở lần đầu:</b> macOS báo không mở được vì app chưa được Apple công chứng. Bấm <b>Xong</b>.</li>
<li><b>Cho phép:</b> vào <b>Cài đặt hệ thống › Quyền riêng tư &amp; Bảo mật</b>, kéo tới mục <b>Bảo mật</b> (giữa trang), bấm <b>Vẫn mở</b> rồi <b>Mở</b>. Không thấy nút thì nhấp đúp app lần nữa rồi quay lại.</li>
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
    ("MacPaw: ngôn ngữ CleanMyMac hỗ trợ", "https://macpaw.com/support/cleanmymac/knowledgebase/languages"),
    ("MacPaw: chính sách riêng tư CleanMyMac", "https://macpaw.com/legal/cleanmymac-privacy-policy"),
    ("PricingSaaS: bảng giá CleanMyMac (ghi nhận 08/2026)", "https://pricingsaas.com/companies/cleanmymac"),
    ("Jamf Threat Labs: mã độc trong app Mac lậu (01/2024)", "https://www.jamf.com/blog/jtl-malware-pirated-applications/"),
    ("Apple: Mở app an toàn trên máy Mac", "https://support.apple.com/102445"),
  ],
  related=[("Cách xóa ứng dụng trên MacBook sạch hoàn toàn", "{HOME}xoa-ung-dung-macbook/"), ("Zalo chiếm bao nhiêu GB trên MacBook", "{HOME}zalo-chiem-dung-luong-macbook/"), ("Trang chủ Tidymint", "{HOME}")],
  alt="cleanmymac-alternative",
),

dict(
  lang="vi", slug="xoa-ung-dung-macbook", date="2026-10-26", read="6 phút đọc",
  title="Cách xóa ứng dụng trên MacBook sạch hoàn toàn | Tidymint",
  desc="Kéo app vào Thùng rác chưa xóa hết: cài đặt, bộ nhớ đệm vẫn còn. Hướng dẫn gỡ app trên MacBook đúng cách, kể cả macOS 26 Tahoe, và cách dọn phần sót lại.",
  crumb="Xóa ứng dụng trên MacBook",
  h1="Cách xóa ứng dụng trên MacBook sạch hoàn toàn",
  tldr="Cách chuẩn của Apple: thoát app, tìm app trong <b>Finder › Ứng dụng</b>, dùng trình gỡ cài đặt riêng nếu app có, nếu không thì kéo app vào <b>Thùng rác</b> rồi đổ Thùng rác. Nhưng cách này thường <b>để lại cài đặt, bộ nhớ đệm và dữ liệu</b> trong thư mục Thư viện. Muốn gỡ sạch, hãy dọn thêm các thư mục đó, hoặc dùng app gỡ cài đặt miễn phí như Tidymint hay AppCleaner.",
  toc=[("cach-1-finder","Cách 1: Xóa bằng Finder (cách của Apple)"),("cach-2-trinh-go","Cách 2: Dùng trình gỡ cài đặt của app"),
       ("macos-26","Lưu ý trên macOS 26 Tahoe"),("phan-sot-lai","Dọn phần sót lại cho sạch"),("cach-3-app","Cách 3: Gỡ sạch bằng app miễn phí"),
       ("khong-xoa-duoc","App không xóa được thì làm sao"),("faq","Câu hỏi thường gặp")],
  body="""
<h2 id="cach-1-finder">Cách 1: Xóa bằng Finder (cách của Apple)</h2>
<ol class="steps">
<li><b>Thoát app</b> đang mở (nhấn Cmd+Q). Nếu app có biểu tượng trên thanh menu, thoát cả ở đó.</li>
<li>Mở <b>Finder</b>, chọn <b>Ứng dụng</b> (Applications) ở thanh bên.</li>
<li>Kéo app vào <b>Thùng rác</b>, hoặc chọn app rồi vào <b>Tệp › Chuyển vào Thùng rác</b>. Nếu được hỏi, nhập mật khẩu máy.</li>
<li><b>Đổ Thùng rác</b> (Finder › Đổ Thùng rác) để lấy lại dung lượng thật sự.</li>
</ol>
<p>Apple lưu ý: xóa app <b>không xóa tài liệu bạn đã tạo</b> bằng app đó, và <b>không hủy gói thuê bao</b> đã mua trong app. Thuê bao phải hủy riêng trong App Store hoặc trên trang của hãng.</p>

<h2 id="cach-2-trinh-go">Cách 2: Dùng trình gỡ cài đặt của app</h2>
<p>Một số app lớn có trình gỡ riêng, ví dụ bộ Adobe, Microsoft Office, phần mềm diệt virus, driver máy in. Tìm file tên <b>Uninstall</b> hoặc <b>Uninstaller</b> trong thư mục của app, hoặc mục gỡ cài đặt trong phần Cài đặt của app.</p>
<p>Apple khuyên đây là <b>cách tốt nhất</b> nếu app có, vì trình gỡ xóa được cả mục khởi động cùng máy, tiện ích mở rộng và dữ liệu nằm ở nơi khác.</p>

<h2 id="macos-26">Lưu ý trên macOS 26 Tahoe</h2>
<p>Trên các bản macOS cũ, bạn có thể vào Launchpad, giữ biểu tượng app đến khi rung rồi bấm dấu X. Từ <b>macOS 26 Tahoe</b>, Launchpad được gộp vào Spotlight và <b>không còn nút xóa app</b>. Vì vậy trên macOS 26, hãy dùng Finder (cách 1) hoặc trình gỡ cài đặt (cách 2). Không biết máy mình bản nào thì vào <b>menu Apple › Giới thiệu về máy Mac này</b>.</p>

<h2 id="phan-sot-lai">Dọn phần sót lại cho sạch</h2>
<p>Kéo app vào Thùng rác chỉ xóa file app chính. Các file app tạo ra trong lúc dùng vẫn nằm lại trong thư mục <b>Thư viện</b> (Library) của bạn, có app để lại vài GB.</p>
<p>Để mở: trong Finder bấm <b>Đi › Đi tới thư mục</b> (Shift+Cmd+G), gõ <code>~/Library</code>. Phần sót lại thường nằm ở:</p>
<div class="tbl"><table>
<tr><th>Thư mục</th><th>Chứa gì</th></tr>
<tr><td><code>~/Library/Application Support</code></td><td>Dữ liệu app (thường lớn nhất)</td></tr>
<tr><td><code>~/Library/Caches</code></td><td>Bộ nhớ đệm</td></tr>
<tr><td><code>~/Library/Preferences</code></td><td>File cài đặt (đuôi .plist)</td></tr>
<tr><td><code>~/Library/Containers</code></td><td>Dữ liệu của app tải từ App Store</td></tr>
<tr><td><code>~/Library/Saved Application State</code></td><td>Trạng thái cửa sổ đã lưu</td></tr>
<tr><td><code>~/Library/LaunchAgents</code></td><td>Mục tự chạy cùng máy</td></tr>
</table></div>
<div class="warn"><p>Chỉ chuyển vào Thùng rác những thư mục <b>mang đúng tên app hoặc tên hãng</b> (ví dụ <code>com.spotify.client</code>). Không chắc thì để lại. Đừng xóa cả thư mục Library.</p></div>

<h2 id="cach-3-app">Cách 3: Gỡ sạch bằng app miễn phí</h2>
<p>Dò tay từng thư mục khá mất công và dễ nhầm. Các app gỡ cài đặt sẽ tự tìm phần sót lại giúp bạn:</p>
<ul>
<li><b>Tidymint</b> (miễn phí, mã nguồn mở, tiếng Việt): mục <b>Gỡ app</b> liệt kê app kèm bộ nhớ đệm, cài đặt, nhật ký, trạng thái đã lưu. Chỉ chọn sẵn file khớp đúng mã app (bundle id); file khớp theo tên hoặc có cơ sở dữ liệu bên trong thì để bạn tự quyết, tránh xóa nhầm dữ liệu như hộp thư hay ghi chú. Có thêm tab tìm <b>phần sót lại của app đã xóa từ trước</b> và file cài đặt cũ. Mọi thứ chỉ chuyển vào Thùng rác, có nút Hoàn tác.</li>
<li><b>AppCleaner</b> (miễn phí) và <b>Pearcleaner</b> (miễn phí, mã nguồn mở): kéo app vào cửa sổ, app liệt kê các file liên quan để bạn chọn xóa.</li>
</ul>
{CTA}

<h2 id="khong-xoa-duoc">App không xóa được thì làm sao</h2>
<ul>
<li><b>Báo "đang được dùng"</b>: thoát hẳn app, kể cả biểu tượng trên thanh menu. Vẫn không được thì khởi động lại máy rồi thử lại.</li>
<li><b>App của Apple</b> như Mail, Nhạc, Sách, Ghi chú, Bản đồ: là một phần của macOS nên không xóa được, và cũng không nên xóa.</li>
<li><b>App vẫn tự chạy sau khi xóa</b>: còn mục khởi động trong <code>~/Library/LaunchAgents</code> hoặc <b>Cài đặt hệ thống › Cài đặt chung › Mục đăng nhập</b>. Tắt hoặc xóa mục đó.</li>
</ul>
""",
  faq=[
    ("Kéo app vào Thùng rác đã xóa hết chưa?", "Chưa. Cách này chỉ xóa file app chính. Cài đặt, bộ nhớ đệm và dữ liệu của app vẫn nằm trong thư mục Thư viện (~/Library) cho đến khi bạn tự dọn hoặc dùng app gỡ cài đặt."),
    ("Xóa app trên Launchpad được không?", "Trên macOS 15 trở về trước thì được với app tải từ App Store. Từ macOS 26 Tahoe, Launchpad gộp vào Spotlight và không còn nút xóa, nên hãy xóa trong Finder."),
    ("Xóa app có mất tài liệu không?", "Không. Tài liệu bạn tạo bằng app vẫn giữ nguyên. Chỉ dữ liệu riêng của app (trong Thư viện) mới bị xóa nếu bạn dọn phần sót lại."),
    ("Xóa app có hủy thuê bao không?", "Không. Thuê bao mua qua App Store phải hủy trong App Store › tài khoản › Đăng ký. Thuê bao mua trên web phải hủy trên trang của hãng."),
    ("Gỡ app bằng Tidymint có an toàn không?", "Tidymint chỉ chuyển app và phần sót lại vào Thùng rác, nên lỡ nhầm vẫn lấy lại được. App đang chạy được đánh dấu và không chọn sẵn."),
  ],
  sources=[
    ("Apple: Gỡ cài đặt app trên máy Mac", "https://support.apple.com/en-lamr/102610"),
    ("Switching to Mac: gỡ app trên macOS 26 Tahoe", "https://www.switchingtomac.com/how-to-uninstall-apps-on-mac/"),
  ],
  related=[("CleanMyMac miễn phí? Lựa chọn hợp pháp", "{HOME}cleanmymac-mien-phi/"), ("Zalo chiếm bao nhiêu GB trên MacBook", "{HOME}zalo-chiem-dung-luong-macbook/"), ("Trang chủ Tidymint", "{HOME}")],
),

dict(
  lang="vi", slug="zalo-chiem-dung-luong-macbook", date="2026-10-27", read="6 phút đọc",
  title="Zalo chiếm bao nhiêu GB trên MacBook và dọn thế nào | Tidymint",
  desc="Zalo trên Mac lưu ảnh, file và bộ nhớ đệm trong thư mục ZaloData, có máy vài chục GB. Cách xem Zalo đang chiếm bao nhiêu, phần nào xoá được, phần nào mất tin nhắn.",
  crumb="Zalo chiếm dung lượng MacBook",
  h1="Zalo chiếm bao nhiêu GB trên MacBook và dọn thế nào",
  tldr="Zalo cất mọi thứ trong thư mục ẩn <code>~/Library/Application Support/ZaloData</code>. Phần nặng nhất là <b>ảnh và file trong tin nhắn</b> (thư mục <code>media</code>), rồi đến tin nhắn (<code>Database</code>, không được xoá) và bộ nhớ đệm (xoá thoải mái). Thoát Zalo trước, chuyển các thư mục cache vào Thùng rác, ảnh cũ thì tự chọn. Trên máy của tác giả, ZaloData chiếm 3,6 GB, trong đó 2,5 GB là ảnh và file.",
  toc=[("o-dau","Zalo trên Mac lưu dữ liệu ở đâu?"),("ben-trong","Bên trong ZaloData có gì, phần nào nặng?"),
       ("don-tay","Xoá bộ nhớ đệm Zalo bằng tay"),("anh-cu","Bỏ ảnh cũ, giữ ảnh mới"),("zalo-tu-don","Zalo có tự dọn không?"),("faq","Câu hỏi thường gặp")],
  body="""
<h2 id="o-dau">Zalo trên Mac lưu dữ liệu ở đâu?</h2>
<p>Zalo cất toàn bộ dữ liệu của bạn trong một thư mục ẩn: <code>~/Library/Application Support/ZaloData</code>. Finder không hiện thư mục Library theo mặc định, nên nhiều người không biết nó tồn tại và chỉ thấy mục <b>Dữ liệu hệ thống</b> trong Cài đặt phình lên.</p>
<ol class="steps">
<li>Trong Finder bấm <b>Shift+Cmd+G</b> (Đi tới thư mục).</li>
<li>Dán <code>~/Library/Application Support/ZaloData</code>, nhấn Enter.</li>
<li>Chuột phải vào thư mục <b>ZaloData</b>, chọn <b>Lấy thông tin</b> để xem tổng dung lượng.</li>
</ol>
<p>Trên máy của tác giả (MacBook 228 GB, đo ngày 27/10/2026), ZaloData chiếm <b>3,6 GB</b>, và đó là sau khi đã xoá bớt; trước đó cũng hơn 10 GB. Trên diễn đàn VOZ có người lấy lại gần 30 GB chỉ bằng cách cài lại Zalo (máy Windows, 2024). Dùng nhiều nhóm, nhận nhiều ảnh thì vài chục GB là chuyện thường.</p>

<h2 id="ben-trong">Bên trong ZaloData có gì, phần nào nặng?</h2>
<p>Thư mục <code>media</code> là phần nặng nhất: ảnh, video, file bạn nhận trong tin nhắn, Zalo tải về để hiển thị. Trên máy của tác giả, <code>media</code> chiếm 2,5 GB trên tổng 3,6 GB, riêng thư mục con <code>resource</code> đã 2 GB.</p>
<div class="tbl"><table>
<tr><th>Thư mục</th><th>Chứa gì</th><th>Máy tác giả</th><th>Xoá được không</th></tr>
<tr><td><code>media/…/ZaloDownloads/resource</code></td><td>Ảnh, sticker, file đính kèm đã tải để hiển thị</td><td>2 068 MB</td><td>Được, nhưng mất bản trên máy này</td></tr>
<tr><td><code>media/…/ZaloDownloads/picture</code></td><td>Ảnh trong tin nhắn</td><td>101 MB</td><td>Như trên</td></tr>
<tr><td><code>media/…/ZaloDownloads/file</code></td><td>File người khác gửi</td><td>52 MB</td><td>Xem trước khi xoá, có thể là file công việc</td></tr>
<tr><td><code>Database</code>, <code>Partitions</code>, các file <code>.db</code></td><td>Tin nhắn, danh bạ, chỉ mục tìm kiếm</td><td>827 MB</td><td><b>Không.</b> Xoá là mất tin nhắn trên máy</td></tr>
<tr><td><code>Cache</code>, <code>Code Cache</code>, <code>GPUCache</code>, <code>DawnCache</code>, <code>resp_cache</code></td><td>Bộ nhớ đệm giao diện</td><td>215 MB</td><td>Được, Zalo tự tạo lại</td></tr>
<tr><td><code>media/update</code></td><td>Bản cài Zalo tải về để cập nhật</td><td>0 (có máy 100–300 MB)</td><td>Được, tải lại khi có bản mới</td></tr>
<tr><td><code>…/ZaloDownloads/fileThumb</code>, <code>richThumb</code>, <code>sticker</code></td><td>Ảnh thu nhỏ, sticker</td><td>nhỏ</td><td>Được, tự tải lại</td></tr>
</table></div>
<div class="warn"><p>Xoá ảnh trong <code>media</code> là xoá <b>bản lưu trên máy này</b>. Ảnh gần đây thường tải lại được khi mở lại cuộc trò chuyện; ảnh cũ có thể không còn trên máy chủ Zalo. Tin nhắn chữ không bị ảnh hưởng vì nằm ở <code>Database</code>.</p></div>

<h2 id="don-tay">Xoá bộ nhớ đệm Zalo bằng tay</h2>
<ol class="steps">
<li><b>Thoát Zalo hẳn</b> (Cmd+Q, kể cả biểu tượng trên thanh menu). Zalo đang mở sẽ ghi lại hoặc khoá file.</li>
<li>Mở <code>~/Library/Application Support/ZaloData</code>.</li>
<li>Kéo các thư mục <code>Cache</code>, <code>Code Cache</code>, <code>GPUCache</code>, <code>DawnCache</code>, <code>resp_cache</code> và <code>media/update</code> vào <b>Thùng rác</b>.</li>
<li>Mở lại Zalo, dùng vài phút xem có gì lạ không, rồi mới <b>Đổ Thùng rác</b>.</li>
</ol>
<p>Không đụng vào <code>Database</code>, <code>Partitions</code> và các file đuôi <code>.db</code>.</p>

<h2 id="anh-cu">Bỏ ảnh cũ, giữ ảnh mới</h2>
<p>Trong <code>ZaloDownloads/picture</code> và <code>resource</code>, file xếp được theo ngày. Trong Finder chọn xem dạng <b>Danh sách</b>, sắp theo <b>Ngày sửa đổi</b>, chọn các file cũ hơn 6 tháng rồi kéo vào Thùng rác. Ảnh nào cần giữ thì lưu ra thư mục Ảnh trước.</p>
<p>Cách này hơi mất công vì hàng nghìn file nằm chung một thư mục, tên file không nói lên gì. Đây là lý do tác giả làm trang <b>Dọn theo ứng dụng</b> trong Tidymint: app gom ảnh Zalo theo tháng để bạn tick, chọn sẵn phần bộ nhớ đệm an toàn, khoá phần tin nhắn và đăng nhập, từ chối dọn khi Zalo đang mở, và mọi thứ vào Thùng rác với nút Hoàn tác. Tidymint miễn phí, mã nguồn mở, do một người Việt làm.</p>
<img src="../byapp.jpg" alt="Trang Dọn theo ứng dụng của Tidymint đang mở Zalo: bộ nhớ đệm chọn sẵn, ảnh trong tin nhắn chia theo tháng" width="1600" height="1013" loading="lazy">
{CTA}

<h2 id="zalo-tu-don">Zalo có tự dọn không?</h2>
<p>Có, và nên thử trước khi dọn tay. Trong Zalo trên Mac, vào <b>Cài đặt › Quản lý dữ liệu</b>. Màn hình <b>Dữ liệu Zalo</b> chia dữ liệu làm ba phần:</p>
<img src="../zalo-quan-ly-du-lieu.jpg" alt="Màn hình Quản lý dữ liệu của Zalo trên Mac: Tin nhắn media 2,2 GB, Bộ nhớ đệm 103 MB, Dữ liệu hệ thống 590 MB" width="1200" height="968" loading="lazy">
<ul>
<li><b>Tin nhắn media</b> (ảnh, video, file, ghi âm lưu trên máy): bấm mũi tên để xoá theo từng cuộc trò chuyện. Đây là phần nặng nhất, trùng với thư mục <code>media</code> ở trên.</li>
<li><b>Bộ nhớ đệm</b>: bấm biểu tượng thùng rác là xoá ngay, không mất gì.</li>
<li><b>Dữ liệu hệ thống</b> (tin nhắn văn bản và dữ liệu để app chạy): không xoá được ở đây, và cũng không nên.</li>
</ul>
<p>Hai điểm Zalo chưa làm: không cho xem ảnh nào cũ, ảnh nào nặng để chọn, và xoá là xoá hẳn, không qua Thùng rác. Muốn chọn theo tháng và có đường lùi thì dọn tay theo bảng ở trên, hoặc dùng Tidymint.</p>
""",
  faq=[
    ("Xoá cả thư mục ZaloData có sao không?", "Mất toàn bộ tin nhắn, ảnh và file đã lưu trên máy này, và phải đăng nhập lại. Chỉ nên xoá các thư mục bộ nhớ đệm như hướng dẫn."),
    ("Xoá bộ nhớ đệm Zalo có phải đăng nhập lại không?", "Không. Thông tin đăng nhập nằm ngoài các thư mục cache. Chỉ xoá cả ZaloData mới phải đăng nhập lại."),
    ("Dữ liệu hệ thống giảm bao nhiêu sau khi dọn Zalo?", "Đúng bằng phần bạn đã xoá, sau khi Đổ Thùng rác và khởi động lại máy để macOS tính lại."),
    ("Zalo Web có chiếm nhiều như vậy không?", "Không. Bản web lưu trong bộ nhớ đệm trình duyệt, xoá cache trình duyệt là hết."),
    ("Xoá trong Cài đặt › Quản lý dữ liệu của Zalo có lấy lại được không?", "Không. Zalo xoá thẳng, không qua Thùng rác. Ảnh cần giữ thì lưu ra ngoài trước."),
    ("Dọn Zalo bằng Tidymint có mất tin nhắn không?", "Không. Tidymint khoá mục tin nhắn và đăng nhập, không bao giờ chọn. Ảnh trong tin nhắn thì để bạn tự chọn theo tháng, và mọi thứ chỉ chuyển vào Thùng rác."),
  ],
  sources=[
    ("Apple: Tìm hiểu dung lượng lưu trữ trên máy Mac (Dữ liệu hệ thống)", "https://support.apple.com/vi-vn/102624"),
    ("VOZ: Zalo ngốn nhiều dung lượng của máy quá (3/2024)", "https://voz.vn/t/zalo-ngon-nhieu-dung-luong-cua-may-qua.930107/"),
  ],
  related=[("Xóa ứng dụng trên MacBook sạch hoàn toàn", "{HOME}xoa-ung-dung-macbook/"), ("CleanMyMac miễn phí? Lựa chọn hợp pháp", "{HOME}cleanmymac-mien-phi/"), ("Trang chủ Tidymint", "{HOME}")],
  alt="",
),

dict(
  lang="vi", slug="cai-dat", date="2026-10-27", read="4 phút đọc",
  title="Cài Tidymint trên Mac: từng bước có ảnh | Tidymint",
  desc="Tải Tidymint, mở lần đầu khi macOS báo bị chặn, bấm Vẫn mở trong Quyền riêng tư và Bảo mật, cấp quyền Truy cập toàn bộ ổ đĩa. Mỗi bước một ảnh chụp màn hình.",
  crumb="Cài đặt từng bước",
  h1="Cài Tidymint trên Mac, từng bước có ảnh",
  tldr="Tidymint chưa được Apple công chứng, nên lần đầu mở macOS sẽ chặn và bạn phải bấm <b>Vẫn mở</b> (Open Anyway) trong <b>Cài đặt hệ thống › Quyền riêng tư &amp; Bảo mật</b>, mục <b>Bảo mật</b> ở giữa trang. Cả quy trình mất khoảng 2 phút và chỉ làm một lần. Ảnh chụp trên macOS tiếng Anh; máy tiếng Việt có cùng vị trí, tên mục dịch trong ngoặc.",
  toc=[("b1","Bước 1: Tải và giải nén"),("b2","Bước 2: Kéo vào Ứng dụng"),("b3","Bước 3: Mở lần đầu, bấm Xong"),("b4","Bước 4: Bấm Vẫn mở"),
       ("b5","Bước 5: Xác nhận và nhập mật khẩu"),("b6","Bước 6: Cấp quyền Truy cập toàn bộ ổ đĩa"),("khong-thay","Không thấy nút Vẫn mở?"),("faq","Câu hỏi thường gặp")],
  body="""
<h2 id="b1">Bước 1: Tải và giải nén</h2>
<p>Bấm <a href="{DL}">Tải Tidymint</a>. File <b>Tidymint.zip</b> (khoảng 3 MB) nằm trong thư mục <b>Downloads</b>. Nhấp đúp file zip, macOS tự giải nén ra app <b>Tidymint</b> ngay cạnh.</p>
<img src="../../install-1-download.jpg" alt="Thư mục Downloads với Tidymint.zip và app Tidymint vừa giải nén" width="1200" height="800" loading="lazy" style="display:block;max-width:100%;height:auto;margin:12px 0 4px;border-radius:12px;border:1px solid var(--line)">
<h2 id="b2">Bước 2: Kéo vào Ứng dụng</h2>
<p>Kéo <b>Tidymint</b> từ Downloads vào thư mục <b>Ứng dụng</b> (Applications) ở thanh bên Finder. Để ở Downloads cũng chạy được, nhưng vào Ứng dụng thì Spotlight tìm thấy, Dock giữ được, và không bị xoá nhầm khi dọn Downloads. File zip xoá được sau khi kéo xong.</p>
<img src="../../install-2-applications.jpg" alt="Tidymint nằm trong thư mục Ứng dụng" width="1200" height="800" loading="lazy" style="display:block;max-width:100%;height:auto;margin:12px 0 4px;border-radius:12px;border:1px solid var(--line)">
<h2 id="b3">Bước 3: Mở lần đầu, bấm Xong</h2>
<p>Nhấp đúp Tidymint trong Ứng dụng. macOS hiện hộp <i>"Tidymint" Not Opened</i> (không mở được) vì app chưa được Apple công chứng. Bấm <b>Done</b> (Xong). <b>Đừng</b> bấm Move to Trash.</p>
<img src="../../install-3-blocked.jpg" alt="Hộp thoại Tidymint Not Opened, bấm Done" width="760" height="630" loading="lazy" style="display:block;max-width:380px;height:auto;margin:12px auto 4px;border-radius:12px;border:1px solid #1c1c1c">
<h2 id="b4">Bước 4: Bấm Vẫn mở</h2>
<p>Mở <b>Cài đặt hệ thống › Quyền riêng tư &amp; Bảo mật</b> (System Settings › Privacy &amp; Security). Kéo tới tiêu đề <b>Bảo mật</b> (Security), nằm ở khoảng giữa trang, ngay dưới dòng <i>Allow applications from</i>. Dòng <i>"Tidymint" was blocked to protect your Mac</i> có nút <b>Open Anyway</b> (Vẫn mở). Bấm vào.</p>
<img src="../../open-anyway.jpg" alt="Mục Bảo mật trong Quyền riêng tư và Bảo mật với nút Open Anyway" width="1200" height="449" loading="lazy" style="display:block;max-width:100%;height:auto;margin:12px 0 4px;border-radius:12px;border:1px solid var(--line)">
<h2 id="b5">Bước 5: Xác nhận và nhập mật khẩu</h2>
<p>macOS hỏi lại một lần nữa: <i>Open "Tidymint"?</i>. Bấm <b>Open Anyway</b> (nút ở giữa, không phải nút xanh Move to Trash). Sau đó nhập mật khẩu máy hoặc dùng Touch ID, bấm <b>OK</b>. Tidymint mở lên. Từ lần sau nhấp đúp là chạy, không hỏi nữa.</p>
<div class="pair"><img src="../../install-5-confirm.jpg" alt="Hộp thoại Open Tidymint, bấm Open Anyway" width="760" height="878" loading="lazy" style="display:block;max-width:100%;height:auto;margin:0;border-radius:12px;border:1px solid #1c1c1c"><span class="pair-arrow" aria-hidden="true"><svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"/><path d="m13 6 6 6-6 6"/></svg></span><img src="../../install-6-password.jpg" alt="Hộp nhập mật khẩu quản trị viên" width="760" height="878" loading="lazy" style="display:block;max-width:100%;height:auto;margin:0;border-radius:12px;border:1px solid #1c1c1c"></div>
<h2 id="b6">Bước 6: Cấp quyền Truy cập toàn bộ ổ đĩa</h2>
<p>Bước này không bắt buộc, nhưng thiếu thì Mail, Tin nhắn và một phần thư mục Library sẽ hiện trống khi quét. Trong <b>Quyền riêng tư &amp; Bảo mật</b>, kéo <b>lên</b> danh sách quyền riêng tư (nửa trên của trang), bấm <b>Full Disk Access</b> (Truy cập toàn bộ ổ đĩa). Nhanh hơn: gõ "Full Disk" vào ô tìm kiếm góc trên trái cửa sổ Cài đặt.</p>
<p>Tìm dòng <b>Tidymint</b>, gạt công tắc sang bật. Chưa có dòng này thì bấm <b>+</b> ở cuối danh sách, chọn Tidymint trong Ứng dụng, bấm Mở. Nếu Tidymint đang mở, macOS sẽ yêu cầu thoát và mở lại app, bấm đồng ý.</p>
<img src="../../install-7-fulldisk.jpg" alt="Danh sách Full Disk Access với công tắc Tidymint bật" width="1000" height="1060" loading="lazy" style="display:block;max-width:720px;height:auto;margin:12px auto 4px;border-radius:12px;border:1px solid var(--line)">
<p>Tidymint chỉ dùng quyền này để đo dung lượng và chuyển file vào Thùng rác. App chạy không cần mạng và không gửi gì ra ngoài máy, xem <a href="https://github.com/HaiTrung-Workspace/tidymint/blob/main/PRIVACY.md">chính sách riêng tư</a>.</p>
{CTA}
<h2 id="khong-thay">Không thấy nút Vẫn mở?</h2>
<ul>
<li>Nút chỉ hiện một lúc sau khi macOS vừa chặn. Nhấp đúp Tidymint lần nữa, bấm Done, rồi quay lại Quyền riêng tư &amp; Bảo mật.</li>
<li>Nút nằm ở mục <b>Bảo mật</b> giữa trang, không phải cuối trang.</li>
<li>Máy công ty có thể bị quản trị viên khoá mục này; khi đó hỏi IT.</li>
</ul>
""",
  faq=[
    ("Sao macOS lại chặn Tidymint?", "Tidymint chưa mua tài khoản nhà phát triển Apple (99 USD/năm) để công chứng. Mọi app chưa công chứng đều bị chặn kiểu này. Mã nguồn công khai trên GitHub để ai cũng kiểm tra được."),
    ("Bấm Vẫn mở có nguy hiểm không?", "Bạn đang cho phép một app cụ thể, không tắt bảo vệ của máy. Chỉ bấm với app tải từ trang chính thức tidymint.app hoặc GitHub của dự án."),
    ("Máy tiếng Việt thì các nút tên gì?", "Quyền riêng tư và Bảo mật, mục Bảo mật, nút Vẫn mở, hộp thoại Mở, Truy cập toàn bộ ổ đĩa. Vị trí giống hệt ảnh."),
    ("Cập nhật bản mới có phải làm lại không?", "Có, mỗi bản tải mới đều bị chặn một lần cho tới khi app được công chứng. Làm lại bước 3 đến 5, mất khoảng một phút."),
    ("Không cấp Truy cập toàn bộ ổ đĩa thì sao?", "App vẫn chạy và dọn được bộ nhớ đệm, file lớn, file trùng trong thư mục người dùng. Chỉ các thư mục được macOS bảo vệ như Mail, Tin nhắn hiện trống. Lần quét đầu, macOS sẽ hỏi riêng quyền vào Desktop, Documents, Downloads, bấm Cho phép là được; app cũng hiện một dải nhắc trên trang chủ kèm nút mở thẳng mục cài đặt này."),
  ],
  sources=[
    ("Apple: Mở app an toàn trên máy Mac", "https://support.apple.com/102445"),
    ("Apple: Kiểm soát quyền truy cập file và thư mục trên máy Mac", "https://support.apple.com/guide/mac-help/mchld5a35146/mac"),
  ],
  related=[("CleanMyMac miễn phí? Lựa chọn hợp pháp", "{HOME}cleanmymac-mien-phi/"), ("Zalo chiếm bao nhiêu GB trên MacBook", "{HOME}zalo-chiem-dung-luong-macbook/"), ("Trang chủ Tidymint", "{HOME}")],
  alt="install",
),

dict(
  lang="en", slug="install", date="2026-10-27", read="4 min read",
  title="Install Tidymint on Mac: Step by Step With Screenshots | Tidymint",
  desc="Download Tidymint, get past the first-launch block, click Open Anyway in Privacy & Security and grant Full Disk Access. One screenshot per step.",
  crumb="Install step by step",
  h1="Install Tidymint on your Mac, step by step",
  tldr="Tidymint is not notarized by Apple yet, so the first launch is blocked and you need to click <b>Open Anyway</b> in <b>System Settings › Privacy &amp; Security</b>, under the <b>Security</b> heading halfway down the page. The whole thing takes about two minutes and only happens once.",
  toc=[("s1","Step 1: Download and unzip"),("s2","Step 2: Move to Applications"),("s3","Step 3: First launch, click Done"),("s4","Step 4: Click Open Anyway"),
       ("s5","Step 5: Confirm and enter your password"),("s6","Step 6: Grant Full Disk Access"),("missing","No Open Anyway button?"),("faq","FAQ")],
  body="""
<h2 id="s1">Step 1: Download and unzip</h2>
<p>Click <a href="{DL}">Download Tidymint</a>. <b>Tidymint.zip</b> (about 3 MB) lands in <b>Downloads</b>. Double-click it and macOS unzips the <b>Tidymint</b> app next to it.</p>
<img src="../install-1-download.jpg" alt="Downloads folder with Tidymint.zip and the unzipped Tidymint app" width="1200" height="800" loading="lazy" style="display:block;max-width:100%;height:auto;margin:12px 0 4px;border-radius:12px;border:1px solid var(--line)">
<h2 id="s2">Step 2: Move to Applications</h2>
<p>Drag <b>Tidymint</b> from Downloads to <b>Applications</b> in the Finder sidebar. It would run from Downloads too, but in Applications Spotlight finds it, the Dock keeps it, and a Downloads cleanup can't delete it by accident. You can delete the zip afterwards.</p>
<img src="../install-2-applications.jpg" alt="Tidymint inside the Applications folder" width="1200" height="800" loading="lazy" style="display:block;max-width:100%;height:auto;margin:12px 0 4px;border-radius:12px;border:1px solid var(--line)">
<h2 id="s3">Step 3: First launch, click Done</h2>
<p>Double-click Tidymint in Applications. macOS shows <i>"Tidymint" Not Opened</i> because the app is not notarized. Click <b>Done</b>. Do <b>not</b> click Move to Trash.</p>
<img src="../install-3-blocked.jpg" alt="The Tidymint Not Opened dialog, click Done" width="760" height="630" loading="lazy" style="display:block;max-width:380px;height:auto;margin:12px auto 4px;border-radius:12px;border:1px solid #1c1c1c">
<h2 id="s4">Step 4: Click Open Anyway</h2>
<p>Open <b>System Settings › Privacy &amp; Security</b>. Scroll to the <b>Security</b> heading, about halfway down, right under <i>Allow applications from</i>. The line <i>"Tidymint" was blocked to protect your Mac</i> has an <b>Open Anyway</b> button. Click it.</p>
<img src="../open-anyway.jpg" alt="Security section of Privacy and Security with the Open Anyway button" width="1200" height="449" loading="lazy" style="display:block;max-width:100%;height:auto;margin:12px 0 4px;border-radius:12px;border:1px solid var(--line)">
<h2 id="s5">Step 5: Confirm and enter your password</h2>
<p>macOS asks once more: <i>Open "Tidymint"?</i>. Click <b>Open Anyway</b> (the middle button, not the blue Move to Trash). Then enter your Mac password or use Touch ID and click <b>OK</b>. Tidymint opens. From now on a double-click is enough.</p>
<div class="pair"><img src="../install-5-confirm.jpg" alt="The Open Tidymint dialog, click Open Anyway" width="760" height="878" loading="lazy" style="display:block;max-width:100%;height:auto;margin:0;border-radius:12px;border:1px solid #1c1c1c"><span class="pair-arrow" aria-hidden="true"><svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"/><path d="m13 6 6 6-6 6"/></svg></span><img src="../install-6-password.jpg" alt="Administrator password prompt" width="760" height="878" loading="lazy" style="display:block;max-width:100%;height:auto;margin:0;border-radius:12px;border:1px solid #1c1c1c"></div>
<h2 id="s6">Step 6: Grant Full Disk Access</h2>
<p>Optional, but without it Mail, Messages and parts of Library show as empty in scans. In <b>Privacy &amp; Security</b>, scroll <b>up</b> to the privacy list (top half of the page) and click <b>Full Disk Access</b>. Faster: type "Full Disk" in the search box at the top left of System Settings.</p>
<p>Find <b>Tidymint</b> and turn its switch on. If it is not listed, click <b>+</b> below the list, pick Tidymint in Applications and click Open. If Tidymint is running, macOS asks you to quit and reopen it; agree.</p>
<img src="../install-7-fulldisk.jpg" alt="Full Disk Access list with the Tidymint switch on" width="1000" height="1060" loading="lazy" style="display:block;max-width:720px;height:auto;margin:12px auto 4px;border-radius:12px;border:1px solid var(--line)">
<p>Tidymint uses this permission only to measure sizes and move files to the Trash. It works offline and sends nothing anywhere, see the <a href="https://github.com/HaiTrung-Workspace/tidymint/blob/main/PRIVACY.md">privacy policy</a>.</p>
{CTA}
<h2 id="missing">No Open Anyway button?</h2>
<ul>
<li>The button only appears for a while after a blocked launch. Double-click Tidymint again, click Done, then return to Privacy &amp; Security.</li>
<li>It sits under the <b>Security</b> heading in the middle of the page, not at the bottom.</li>
<li>On a managed work Mac an administrator may have locked this; ask IT.</li>
</ul>
""",
  faq=[
    ("Why does macOS block Tidymint?", "Tidymint has no Apple Developer account yet (99 USD a year) and so is not notarized. Every unnotarized app is blocked the same way. The source code is public on GitHub."),
    ("Is clicking Open Anyway safe?", "You are allowing one specific app, not switching off protection. Only do it for apps downloaded from the official site tidymint.app or the project's GitHub."),
    ("Do I have to repeat this for updates?", "Yes, each new download is blocked once until the app is notarized. Repeat steps 3 to 5, about a minute."),
    ("What if I skip Full Disk Access?", "The app still runs and cleans caches, large and duplicate files in your home folder. Only macOS-protected folders such as Mail and Messages show as empty. On the first scan macOS asks separately for Desktop, Documents and Downloads: click Allow. The home page also shows a reminder with a button that opens this setting."),
  ],
  sources=[
    ("Apple: Safely open apps on your Mac", "https://support.apple.com/102445"),
    ("Apple: Control access to files and folders on Mac", "https://support.apple.com/guide/mac-help/mchld5a35146/mac"),
  ],
  related=[("Free CleanMyMac alternative (open source)", "{HOME}cleanmymac-alternative/"), ("How to clear System Data on Mac", "{HOME}clear-system-data-mac/"), ("Tidymint home", "{HOME}")],
  alt="cai-dat",
),

dict(
  lang="vi", slug="mac-tu-day-o", date="2026-10-27", read="7 phút đọc",
  title="Vì sao Mac tự đầy ổ dù không tải gì, và cách chặn | Tidymint",
  desc="Ổ Mac cứ đầy dần dù bạn không tải gì? Sáu thứ âm thầm ngốn chỗ: snapshot Time Machine, bộ nhớ đệm, sao lưu iPhone, Mail, đồ lập trình, model AI.",
  crumb="Mac tự đầy ổ",
  h1="Vì sao Mac tự đầy ổ dù bạn không tải gì, và cách chặn",
  tldr="Mac tự tăng vài GB trong khi bạn không làm gì thường là do một trong sáu chỗ: <b>snapshot Time Machine</b>, <b>bộ nhớ đệm app và trình duyệt</b>, <b>bản sao lưu iPhone/iPad</b>, <b>file đính kèm Mail và Tin nhắn</b>, <b>đồ lập trình</b> (Xcode, Docker, node_modules) hoặc <b>model AI tải về</b>. Bài này chỉ cách tìm xem máy bạn đang phình ở đâu và chặn nó quay lại, không xoá nhầm thứ cần giữ.",
  toc=[("vi-sao","Vì sao ổ tăng khi bạn không làm gì"),("tim","Truy tìm thủ phạm"),("snapshot","Snapshot Time Machine"),("cache","Bộ nhớ đệm tự tạo lại"),
       ("sao-luu","Sao lưu iPhone, iPad"),("mail","Đính kèm Mail và Tin nhắn"),("dev","Đồ lập trình"),("ai","Model AI và app tạo ảnh"),("chan","Dọn dẹp đơn giản với Tidymint"),("faq","Câu hỏi thường gặp")],
  body="""
<h2 id="vi-sao">Vì sao ổ tăng khi bạn không làm gì</h2>
<p>macOS và các app ghi file liên tục mà không hỏi: mỗi giờ một snapshot trước khi sao lưu, mỗi trang web một bộ nhớ đệm, mỗi ảnh bạn mở trong Tin nhắn một bản sao. Phần lớn rơi vào <b>Dữ liệu hệ thống</b> (máy cũ gọi là <b>Khác</b>), cái túi mà mục Dung lượng trong Cài đặt không giải thích được. Vì thế con số cứ leo lên trong khi thư mục Tài liệu vẫn y nguyên.</p>
<p><b>Tin tốt:</b> gần như toàn bộ đều tự tạo lại được, hoặc là bản sao của thứ bạn vẫn còn ở chỗ khác, nên bỏ đi không mất gì.</p>
<p><b>Tin xấu:</b> phải biết chỗ mà tìm, vì Finder giấu hầu hết các thư mục này.</p>

<h2 id="tim">Truy tìm thủ phạm</h2>
<ol class="steps">
<li>Mở <b>menu Apple › Cài đặt hệ thống › Cài đặt chung › Dung lượng</b>, ghi lại số của <b>Dữ liệu hệ thống</b>. Hôm sau xem lại. Lệch vài GB thì thủ phạm là một trong sáu mục dưới.</li>
<li>Trong Finder bấm <b>Shift+Cmd+G</b>, gõ <code>~/Library</code>, Enter. Chuyển sang xem dạng danh sách, sắp theo dung lượng (Hiển thị › Hiện tuỳ chọn hiển thị › Tính toán tất cả kích cỡ). <code>Caches</code>, <code>Application Support</code> và <code>Containers</code> thường đứng đầu.</li>
<li>Trong Terminal, <code>tmutil listlocalsnapshots /</code> liệt kê snapshot Time Machine. Nhiều hơn hai ba dòng là chúng đang giữ chỗ.</li>
</ol>
<p>Tidymint có trang <b>Bản đồ ổ đĩa</b> vẽ trực quan mỗi thư mục thành một quả bóng to nhỏ theo dung lượng thật, kèm chú thích dễ hiểu cho các thư mục hay gặp; app miễn phí, mã nguồn mở.</p>

<h2 id="snapshot">Snapshot Time Machine</h2>
<ul>
<li><b>Là gì:</b> khi ổ Time Machine không cắm, macOS giữ snapshot mỗi giờ ngay trên ổ trong máy và chỉ dọn bớt khi sắp hết chỗ. Máy dùng nhiều có thể giữ 20–80 GB, Finder không hiện.</li>
<li><b>Nhận ra:</b> <code>tmutil listlocalsnapshots /</code> ra nhiều ngày, hoặc mục Dung lượng ghi "Time Machine" hay "Sao lưu" là một khoản lớn.</li>
<li><b>Sửa:</b> cắm ổ sao lưu cho chạy xong một lượt, hoặc gõ <code>tmutil thinlocalsnapshots / 999999999999 4</code> để bỏ ngay. Chúng sẽ quay lại theo thiết kế, nên máy nào lúc nào cũng chật thì cân nhắc tắt Time Machine và sao lưu cách khác.</li>
</ul>

<h2 id="cache">Bộ nhớ đệm tự tạo lại</h2>
<ul>
<li><b>Là gì:</b> <code>~/Library/Caches</code> và thư mục riêng của từng app trong <code>~/Library/Application Support</code>. Trình duyệt, Slack, Discord, Spotify, Zalo, Notion và nói chung app viết bằng Electron là thủ phạm quen; riêng trình duyệt đã 2–5 GB.</li>
<li><b>Nhận ra:</b> thư mục mang tên app hoặc mã app (<code>com.google.Chrome</code>, <code>com.spotify.client</code>) to và nội dung bên trong đã vài ngày tuổi.</li>
<li><b>Sửa:</b> thoát app, chuyển thư mục cache vào Thùng rác, mở lại app. App tự tạo lại phần cần. Không đụng <code>Database</code>, <code>.db</code>, <code>.sqlite</code> hay <code>Preferences</code>, đó là chỗ chứa đăng nhập và tin nhắn. Một số app có nút riêng: Chrome › Xoá dữ liệu duyệt web, Spotify › Cài đặt › Lưu trữ, Zalo › Cài đặt › Quản lý dữ liệu.</li>
</ul>

<h2 id="sao-luu">Sao lưu iPhone, iPad</h2>
<ul>
<li><b>Là gì:</b> mỗi lần sao lưu thiết bị vào Mac, một bản đầy đủ nằm ở <code>~/Library/Application Support/MobileSync/Backup</code>. Một bản sao lưu điện thoại 10–100 GB, và máy cũ đã bán vẫn để bản sao lưu lại mãi.</li>
<li><b>Nhận ra:</b> mục Dung lượng ghi "Tệp iOS", hoặc thư mục trên rất to.</li>
<li><b>Sửa:</b> trong Finder chọn thiết bị ở thanh bên, bấm <b>Quản lý bản sao lưu</b>, xoá bản của máy không còn dùng. Giữ bản mới nhất của máy đang dùng.</li>
</ul>

<h2 id="mail">Đính kèm Mail và Tin nhắn</h2>
<ul>
<li><b>Là gì:</b> Mail tải mọi file đính kèm của mọi tài khoản vào <code>~/Library/Mail</code>; Tin nhắn giữ mọi ảnh, video ai gửi cho bạn trong <code>~/Library/Messages/Attachments</code>. Cả hai lớn dần từng ngày và không bao giờ tự co lại.</li>
<li><b>Sửa:</b> Mail › Cài đặt › Tài khoản › tài khoản của bạn › Tải tệp đính kèm: chọn <b>Gần đây</b> hoặc <b>Không</b>, rồi Hộp thư › Xoá các mục đã xoá. Với Tin nhắn, trong mục Dung lượng mở <b>Tin nhắn</b> và xoá các đính kèm lớn ở đó, hoặc đặt Cài đặt › Cài đặt chung › Giữ tin nhắn trong một năm. App dọn máy phải để yên hai thư mục này, Tidymint làm đúng vậy.</li>
</ul>

<h2 id="dev">Đồ lập trình</h2>
<ul>
<li><b>Là gì:</b> <code>DerivedData</code> của Xcode, máy ảo iOS và file hỗ trợ thiết bị cũ (<code>~/Library/Developer</code>, hay 30–100 GB); file ổ đĩa duy nhất của Docker Desktop chỉ có phình không co; <code>node_modules</code> trong mọi dự án; bộ nhớ đệm Homebrew, npm, pip.</li>
<li><b>Sửa:</b> Xcode › Settings › Locations › DerivedData, xoá thư mục; <code>xcrun simctl delete unavailable</code>; Docker › Settings › Resources › Disk image size, rồi <code>docker system prune</code>; <code>npm cache clean --force</code>, <code>brew cleanup</code>. <code>node_modules</code> của dự án vài tháng không mở thì bỏ được, <code>npm install</code> là có lại.</li>
</ul>

<h2 id="ai">Model AI và app tạo ảnh</h2>
<ul>
<li><b>Là gì:</b> Ollama cất mọi model bạn từng tải trong <code>~/.ollama</code> (4–40 GB mỗi cái); Hugging Face đệm file tải về ở <code>~/.cache/huggingface</code>; các app Stable Diffusion giữ checkpoint và mọi ảnh đã tạo. Ít thứ nào trong số này hiện tên dễ hiểu ở mục Dung lượng.</li>
<li><b>Sửa:</b> <code>ollama list</code> rồi <code>ollama rm &lt;model&gt;</code> với model không dùng nữa; xoá mục cũ trong cache Hugging Face; chuyển ảnh đã tạo ra ổ ngoài. Đây là nhóm thư mục làm nhiều người bất ngờ nhất, nên Bản đồ ổ đĩa của Tidymint gọi tên chúng rõ ràng.</li>
</ul>
{CTA}
<h2 id="chan">Dọn dẹp đơn giản với Tidymint</h2>
<p>Sáu chỗ ở trên là đúng những thư mục Tidymint quét: <b>Dọn ngay</b> gom bộ nhớ đệm, nhật ký, file cài đặt cũ thành từng nhóm có nhãn an toàn và chỉ dọn khi bạn bấm; <b>Bản đồ ổ đĩa</b> vẽ snapshot, sao lưu iPhone, thư mục Xcode, Docker, Ollama thành bóng to nhỏ kèm chú thích; <b>Dọn theo ứng dụng</b> xử lý Zalo, Chrome, CapCut theo tháng. Mọi thứ vào Thùng rác, có Hoàn tác. Miễn phí, mã nguồn mở, tiếng Việt.</p>
<h3>Để ổ không đầy lại</h3>
<ul>
<li><b>Khởi động lại mỗi tuần.</b> macOS dọn file tạm và phần "có thể xoá" khi khởi động lại.</li>
<li><b>Đổ Thùng rác.</b> File trong Thùng rác vẫn tính dung lượng. Finder › Cài đặt › Nâng cao › Xoá các mục khỏi Thùng rác sau 30 ngày sẽ làm hộ bạn.</li>
<li><b>Đặt giới hạn ở app nào cho phép:</b> đính kèm Mail để Gần đây, Tin nhắn giữ một năm, Docker giới hạn file ổ đĩa, Spotify giới hạn cache.</li>
<li><b>Mỗi tháng xem một lần.</b> Năm phút nhìn bản đồ ổ đĩa đỡ hơn một lần hoảng khi hiện "ổ đĩa sắp đầy".</li>
</ul>
<p>Lỡ "dọn dẹp" quá tay? Đừng lo, Tidymint chỉ chuyển dữ liệu thừa vào Thùng rác, mọi thứ vẫn hoàn tác được nếu bạn đổi ý.</p>
""",
  faq=[
    ("Ổ Mac cứ tăng dần có phải virus không?", "Gần như không bao giờ. Phần tăng đến từ snapshot, bộ nhớ đệm, sao lưu và nhật ký mà macOS cùng app bình thường tự ghi. Quét bảo mật không hại gì, nhưng cách sửa là quản lý các thư mục đó, không phải cài diệt virus."),
    ("Sao Dữ liệu hệ thống tự lên xuống?", "macOS tạo snapshot Time Machine mỗi giờ và xoá khi cần chỗ, đồng thời dọn cache khi ổ chật. Con số bạn thấy là mục tiêu di động, nên so hai ngày cách nhau hữu ích hơn nhìn một lần."),
    ("Xoá cả thư mục Caches được không?", "Chuyển ~/Library/Caches vào Thùng rác nhìn chung an toàn, app tự tạo lại. Lần mở đầu sẽ chậm hơn và một số app mất nội dung ngoại tuyến. Tuyệt đối không xoá tay /System hay /private/var."),
    ("Dọn các thư mục này có mất ảnh hay tài liệu không?", "Không. Tài liệu, Màn hình chính, Ảnh và thư viện Ảnh nằm riêng. Các thư mục trong bài chứa bản sao, bộ nhớ đệm và sao lưu. Tránh xa cơ sở dữ liệu của Mail, Tin nhắn, thư viện Ảnh trừ khi dùng đúng cài đặt của app."),
    ("Tidymint có tự sửa chuyện này không?", "App tìm các thư mục, gắn nhãn từng nhóm an toàn, cần xem hay khoá, và chuyển phần bạn tick vào Thùng rác, có Hoàn tác. Không chạy ngầm, không tự xoá."),
  ],
  sources=[
    ("Apple: Giải phóng dung lượng lưu trữ trên máy Mac", "https://support.apple.com/vi-vn/102624"),
    ("Apple: Giới thiệu về snapshot cục bộ của Time Machine", "https://support.apple.com/vi-vn/102154"),
    ("Apple: Định vị và quản lý bản sao lưu iPhone, iPad", "https://support.apple.com/vi-vn/108809"),
  ],
  related=[("Zalo chiếm bao nhiêu GB trên MacBook", "{HOME}zalo-chiem-dung-luong-macbook/"), ("Xóa ứng dụng trên MacBook sạch hoàn toàn", "{HOME}xoa-ung-dung-macbook/"), ("Trang chủ Tidymint", "{HOME}")],
  alt="mac-storage-keeps-filling-up",
),

dict(
  lang="en", slug="mac-storage-keeps-filling-up", date="2026-10-27", read="7 min read",
  title="Why Your Mac Keeps Filling Up by Itself | Tidymint",
  desc="Mac storage grows while you change nothing? Six things quietly eat space: snapshots, caches, iPhone backups, Mail, dev tools, AI models. How to stop each one.",
  crumb="Mac keeps filling up",
  h1="Why your Mac keeps filling up on its own, and how to stop it",
  tldr="A Mac that gains gigabytes while you do nothing is usually growing in one of six places: <b>Time Machine local snapshots</b>, <b>app and browser caches</b>, <b>iPhone or iPad backups</b>, <b>Mail attachments</b>, <b>developer tools</b> (Xcode, Docker, node_modules) or <b>AI model downloads</b>. This guide shows how to find which one it is on your Mac and how to stop it coming back, without deleting anything you need.",
  toc=[("why","Why storage grows when you change nothing"),("find","Track down the culprit"),("snapshots","Time Machine local snapshots"),("caches","Caches that rebuild themselves"),
       ("backups","iPhone and iPad backups"),("mail","Mail and Messages attachments"),("dev","Developer tools"),("ai","AI models and image generators"),("stop","Free up the space with Tidymint"),("faq","FAQ")],
  body="""
<h2 id="why">Why storage grows when you change nothing</h2>
<p>macOS and the apps on it write files constantly without asking: a snapshot every hour before a backup, a cache for every web page, a copy of every photo you open in Messages. Most of this lands in <b>System Data</b> (older Macs call it <b>Other</b>), a bucket that Storage settings cannot explain. That is why the number keeps climbing while your Documents folder stays the same.</p>
<p><b>The good news:</b> almost all of it is either rebuilt automatically or is a copy of something you still have elsewhere, so it can go without loss.</p>
<p><b>The bad news:</b> you have to know where to look, because Finder hides most of these folders.</p>

<h2 id="find">Track down the culprit</h2>
<ol class="steps">
<li>Open <b>Apple menu › System Settings › General › Storage</b> and note the size of <b>System Data</b>. Come back a day later and compare. If it moved by gigabytes, the culprit is one of the six below.</li>
<li>In Finder press <b>Shift+Cmd+G</b>, type <code>~/Library</code> and press Enter. Switch to list view, sort by size (View › Show View Options › Calculate all sizes). <code>Caches</code>, <code>Application Support</code> and <code>Containers</code> are usually the top three.</li>
<li>In Terminal, <code>tmutil listlocalsnapshots /</code> lists Time Machine snapshots. More than two or three means they are holding space.</li>
</ol>
<p>Tidymint's <b>Space Lens</b> page draws every folder as a bubble sized by real usage, with plain-language notes on the common ones; it is free and open source.</p>

<h2 id="snapshots">Time Machine local snapshots</h2>
<ul>
<li><b>What it is:</b> when a Time Machine disk is not connected, macOS keeps hourly snapshots on the internal drive and thins them out when space gets tight. On a busy Mac they can hold 20 to 80 GB and they are invisible in Finder.</li>
<li><b>How to tell:</b> <code>tmutil listlocalsnapshots /</code> shows several dates, or Storage settings lists "Time Machine" or "Backups" as a big item.</li>
<li><b>Fix:</b> plug in the backup drive and let a backup finish, or run <code>tmutil thinlocalsnapshots / 999999999999 4</code> to drop them now. They come back by design, so if your Mac is always tight on space, consider turning Time Machine off and using another backup method.</li>
</ul>

<h2 id="caches">Caches that rebuild themselves</h2>
<ul>
<li><b>What it is:</b> <code>~/Library/Caches</code> and the per-app folders in <code>~/Library/Application Support</code>. Browsers, Slack, Discord, Spotify, Zalo, Notion and Electron apps in general are the usual suspects; a browser alone can hold 2 to 5 GB.</li>
<li><b>How to tell:</b> the folders named after an app or a bundle id (<code>com.google.Chrome</code>, <code>com.spotify.client</code>) are large and their contents are days old.</li>
<li><b>Fix:</b> quit the app, move its cache folder to the Trash, reopen the app. It rebuilds what it needs. Do not touch <code>Database</code>, <code>.db</code>, <code>.sqlite</code> or <code>Preferences</code>; that is where logins and messages live. Some apps have their own button: Chrome › Clear browsing data, Spotify › Settings › Storage, Zalo › Settings › Data management.</li>
</ul>

<h2 id="backups">iPhone and iPad backups</h2>
<ul>
<li><b>What it is:</b> every time you back up a device to the Mac, a full copy goes to <code>~/Library/Application Support/MobileSync/Backup</code>. A phone backup is 10 to 100 GB, and old devices leave their backups behind forever.</li>
<li><b>How to tell:</b> Storage settings shows "iOS Files" or that folder is huge.</li>
<li><b>Fix:</b> in Finder select your device in the sidebar, click <b>Manage Backups</b>, delete backups of devices you no longer own. Keep the newest one for the phone you use.</li>
</ul>

<h2 id="mail">Mail and Messages attachments</h2>
<ul>
<li><b>What it is:</b> Mail downloads every attachment of every account into <code>~/Library/Mail</code>; Messages keeps every photo and video anyone sent you in <code>~/Library/Messages/Attachments</code>. Both grow by the day and never shrink on their own.</li>
<li><b>Fix:</b> Mail › Settings › Accounts › your account › Download Attachments: set to <b>Recent</b> or <b>None</b>, then Mailbox › Erase Deleted Items. For Messages, in Storage settings open <b>Messages</b> and delete large attachments from there, or set Settings › General › Keep Messages to one year. Cleaner apps should leave these folders alone, and Tidymint does.</li>
</ul>

<h2 id="dev">Developer tools</h2>
<ul>
<li><b>What it is:</b> Xcode's <code>DerivedData</code>, iOS simulators and old device support files (<code>~/Library/Developer</code>, often 30 to 100 GB); Docker Desktop's single disk image that only ever grows; <code>node_modules</code> folders in every project; Homebrew, npm and pip caches.</li>
<li><b>Fix:</b> Xcode › Settings › Locations › DerivedData, delete the folder; <code>xcrun simctl delete unavailable</code>; Docker › Settings › Resources › Disk image size, then <code>docker system prune</code>; <code>npm cache clean --force</code>, <code>brew cleanup</code>. Old <code>node_modules</code> in projects you have not opened for months can go; <code>npm install</code> brings them back.</li>
</ul>

<h2 id="ai">AI models and image generators</h2>
<ul>
<li><b>What it is:</b> Ollama stores every model you have ever pulled in <code>~/.ollama</code> (4 to 40 GB each); Hugging Face caches downloads in <code>~/.cache/huggingface</code>; Stable Diffusion front ends keep checkpoints and every generated image. Few of these show up in Storage settings under a name you would recognise.</li>
<li><b>Fix:</b> <code>ollama list</code> then <code>ollama rm &lt;model&gt;</code> for models you no longer use; delete old entries in the Hugging Face cache; move generated images to an external drive. These are the folders that surprise people most, so they are called out by name in Tidymint's Space Lens.</li>
</ul>
{CTA}
<h2 id="stop">Free up the space with Tidymint</h2>
<p>The six places above are exactly what Tidymint scans: <b>Clean Now</b> groups caches, logs and old installers with a safety label on each group and cleans only when you click; <b>Space Lens</b> draws snapshots, iPhone backups, Xcode, Docker and Ollama folders as bubbles with plain-language notes; <b>Clean by App</b> handles Zalo, Chrome and CapCut month by month. Everything goes to the Trash, with Undo. Free and open source.</p>
<h3>Keep it from coming back</h3>
<ul>
<li><b>Restart once a week.</b> macOS purges temporary files and purgeable space on restart.</li>
<li><b>Empty the Trash.</b> Files in the Trash still count. Finder › Settings › Advanced › Remove items from the Trash after 30 days does it for you.</li>
<li><b>Set limits where the app allows it:</b> Mail attachments to Recent, Messages to one year, Docker disk image size, Spotify cache size.</li>
<li><b>Check once a month.</b> Five minutes in a disk map beats a panic when the "disk almost full" warning appears.</li>
</ul>
<p>Cleaned a bit too much? No worries: Tidymint only moves leftovers to the Trash, so everything can be undone if you change your mind.</p>
""",
  faq=[
    ("Is it a virus if my Mac storage keeps growing?", "Almost never. The growth comes from snapshots, caches, backups and logs that macOS and ordinary apps write by design. A security scan does no harm, but the fix is managing those folders, not an antivirus."),
    ("Why does System Data go up and down by itself?", "macOS creates Time Machine local snapshots hourly and deletes them when space is needed, and it purges caches under pressure. The number you see is a moving target, which is why a day-apart comparison is more useful than one reading."),
    ("Can I delete the Caches folder entirely?", "Moving ~/Library/Caches to the Trash is generally safe; apps rebuild it. Expect slower first launches and lost offline content in some apps. Never delete /System or /private/var by hand."),
    ("Will clearing these folders delete my photos or documents?", "No. Documents, Desktop, Pictures and your Photos library are separate. The folders in this guide hold copies, caches and backups. Keep away from Mail, Messages and Photos library databases unless you are using the app's own settings."),
    ("Does Tidymint fix this automatically?", "It finds the folders, labels each group safe, review or locked, and moves what you tick to the Trash with an Undo. It does not run in the background or delete on its own."),
  ],
  sources=[
    ("Apple: Free up storage space on your Mac", "https://support.apple.com/102624"),
    ("Apple: About Time Machine local snapshots", "https://support.apple.com/102154"),
    ("Apple: Locate and manage backups of your iPhone, iPad, and iPod touch", "https://support.apple.com/108809"),
  ],
  related=[("How to clear System Data on Mac", "{HOME}clear-system-data-mac/"), ("How to free up space on Mac", "{HOME}free-up-space-mac/"), ("Tidymint home", "{HOME}")],
  alt="mac-tu-day-o",
),
dict(
  lang="vi", slug="adobe-chiem-dung-luong-mac", date="2026-10-27", read="6 phút đọc",
  title="Adobe chiếm bao nhiêu GB trên Mac, dọn chỗ nào | Tidymint",
  desc="Photoshop, Premiere, Lightroom ngốn hàng chục GB trên Mac. Phần nào là app, phần nào là Media Cache, Camera Raw, file tạm xoá được, và cách đặt giới hạn.",
  crumb="Adobe chiếm dung lượng",
  h1="Adobe chiếm bao nhiêu GB trên Mac và chỗ nào dọn được",
  tldr="Bộ Adobe trên Mac gồm hai phần rất khác nhau: <b>phần cài đặt</b> (app, thư viện dùng chung, Camera Raw, plug-in) chiếm 10–15 GB và không dọn được, và <b>phần bộ nhớ đệm</b> (Media Cache của Premiere và After Effects, bộ nhớ đệm Camera Raw của Lightroom và Photoshop, file tạm Photoshop) có thể phình tới hàng trăm GB nhưng xoá được và app tự tạo lại. Bài này chỉ đúng chỗ của từng phần, kèm số đo thật trên một máy chỉ cài Photoshop.",
  toc=[("hai-phan","Hai phần của Adobe trên ổ"),("do","Số đo thật trên một máy chỉ có Photoshop"),("media-cache","Media Cache của Premiere và After Effects"),("camera-raw","Bộ nhớ đệm Camera Raw"),("temp","File tạm Photoshop"),("cu","Bản cũ và bộ cài"),("gioi-han","Đặt giới hạn để không phải dọn lại"),("tidymint","Tìm nhanh với Tidymint")],
  body="""
<h2 id="hai-phan">Hai phần của Adobe trên ổ</h2>
<p>Nhiều người mở mục Dung lượng thấy Adobe chiếm vài chục GB rồi đi xoá cache mà số vẫn không giảm. Lý do: phần lớn dung lượng Adobe là <b>phần cài đặt</b>, không phải rác.</p>
<ul>
<li><b>Phần cài đặt:</b> bản thân app (Photoshop khoảng 6 GB, Premiere và After Effects mỗi cái tương tự), thư viện dùng chung ở <code>/Library/Application Support/Adobe</code> (Camera Raw, plug-in, CEP, Creative Cloud), và app Creative Cloud. Phần này chỉ giảm khi gỡ app hoặc gỡ bản cũ.</li>
<li><b>Phần bộ nhớ đệm:</b> Media Cache của Premiere và After Effects, bộ nhớ đệm Camera Raw, file tạm của Photoshop, bản tải về của Creative Cloud. Phần này app tự tạo lại, xoá được, và là nơi "Dữ liệu hệ thống" phình lên.</li>
</ul>
<p>Trên diễn đàn Adobe có người đo thư mục <code>~/Library/Caches/Adobe</code> tới 350 GB trên ổ 1 TB, xoá xong và đặt giới hạn 30 GB thì ổ trống thêm hơn 500 GB. Đó là phần thứ hai.</p>

<h2 id="do">Số đo thật trên một máy chỉ có Photoshop</h2>
<p>Máy đo: Mac mini, chỉ cài Photoshop 2026 và Creative Cloud, không dùng Premiere, Lightroom. Số đo ngày 27/10/2026.</p>
<table>
<tr><th>Chỗ</th><th>Dung lượng</th><th>Dọn được?</th></tr>
<tr><td><code>/Applications/Adobe Photoshop 2026</code></td><td>6,2 GB</td><td>Không, là app</td></tr>
<tr><td><code>/Library/Application Support/Adobe/CameraRaw</code> (hồ sơ ống kính, model AI của Camera Raw)</td><td>2,2 GB</td><td>Không nên, Photoshop cần khi mở ảnh RAW</td></tr>
<tr><td><code>/Library/Application Support/Adobe</code> phần còn lại (Desktop Common, Plug-Ins, CEP, thư viện CC)</td><td>2,4 GB</td><td>Không, thư viện dùng chung</td></tr>
<tr><td><code>/Applications/Utilities/Adobe Creative Cloud</code> và các app Adobe Sync, Experience</td><td>0,6 GB</td><td>Không</td></tr>
<tr><td><code>~/Library/Application Support/Adobe</code> (cài đặt cá nhân, CoreSync)</td><td>126 MB</td><td>Phần nhỏ</td></tr>
<tr><td><code>~/Library/Application Support/Adobe/Adobe Photoshop 2021</code></td><td>3 MB</td><td>Sót của bản cũ, xoá được</td></tr>
<tr><td>Bộ nhớ đệm Camera Raw, Media Cache</td><td>0</td><td>Có, khi tồn tại</td></tr>
</table>
<p>Tổng 11,5 GB, trong đó phần xoá được chỉ vài MB. Máy này không có Premiere và không mở ảnh RAW nên hai thư mục bộ nhớ đệm lớn nhất chưa xuất hiện. Máy dựng video hoặc chỉnh ảnh RAW hằng ngày sẽ có thêm các khoản dưới đây.</p>

<h2 id="media-cache">Media Cache của Premiere và After Effects</h2>
<ul>
<li><b>Là gì:</b> mỗi clip đưa vào Premiere hay After Effects được dựng sẵn file âm thanh và chỉ mục (.cfa, .pek, .ims) để kéo tua mượt. Theo Adobe, trên macOS chúng nằm trong <code>~/Library/Application Support/Adobe/Common</code> (hai thư mục Media Cache Files và Media Cache). Mặc định Premiere <b>không tự xoá</b> ("Do not delete cache files automatically" là lựa chọn mặc định), nên dự án xong rồi file vẫn nằm đó.</li>
<li><b>Nhận ra:</b> hai thư mục trên to hơn vài GB, hoặc mục Dung lượng ghi "Dữ liệu hệ thống" tăng vọt sau mỗi dự án video.</li>
<li><b>Sửa:</b> trong Premiere mở <b>Premiere › Settings › Media Cache</b>, bấm <b>Delete</b> cạnh "Remove Media Cache Files", chọn <b>Delete unused media cache files</b> (chỉ bỏ phần của clip không còn tìm thấy) hoặc <b>Delete all media cache files from the system</b> (đóng hết dự án trước; file được dựng lại tự động khi dự án cần). Cùng mục đó bật <b>Automatically delete cache files older than</b> (Adobe mặc định 90 ngày khi bật) hoặc <b>Automatically delete oldest cache files when cache exceeds</b> (mặc định 10% dung lượng ổ). After Effects: <b>After Effects › Preferences › Media &amp; Disk Cache</b>, bấm <b>Empty Disk Cache</b> và <b>Clean Database &amp; Cache</b>. Xoá tay bằng Finder cũng được khi đã thoát app: theo hướng dẫn của Adobe, xoá nội dung thư mục Common rồi đổ Thùng rác; mở lại dự án sẽ chờ dựng lại.</li>
</ul>

<h2 id="camera-raw">Bộ nhớ đệm Camera Raw</h2>
<ul>
<li><b>Là gì:</b> Lightroom Classic và Camera Raw trong Photoshop giữ dữ liệu ảnh gốc của mỗi ảnh RAW đã mở để lần sau dựng bản xem nhanh hơn. Theo Adobe, Lightroom Classic mặc định giới hạn cache này ở <b>5 GB</b>, và chính Adobe gợi ý nâng lên 10–20 GB để Develop nhanh hơn, nên nhiều máy đang để rất cao. Thư mục thường mang tên <code>Adobe Camera Raw 2</code> trong <code>~/Library/Caches</code> (hoặc nơi bạn tự chọn).</li>
<li><b>Nhận ra:</b> thư mục trên to, hoặc trong Lightroom Classic vào <b>Preferences › File Handling › Camera Raw Cache Settings</b> thấy Maximum Size đặt cao.</li>
<li><b>Sửa:</b> cùng chỗ đó bấm <b>Purge Cache</b> rồi hạ Maximum Size; trong Photoshop, mục tương ứng nằm ở Camera Raw Preferences › Performance. Xoá không ảnh hưởng ảnh gốc hay chỉnh sửa đã lưu (chỉnh sửa nằm trong catalog và file XMP), chỉ mở lại ảnh sẽ chậm hơn một nhịp.</li>
</ul>

<h2 id="temp">File tạm Photoshop</h2>
<ul>
<li><b>Là gì:</b> khi thiếu RAM, Photoshop ghi tạm ra ổ (scratch disk), có thể hàng chục GB với file lớn và nhiều bước History. Thoát app bình thường thì phần này được trả lại; Adobe khuyên để trống ít nhất 100 GB trên ổ scratch.</li>
<li><b>Nhận ra:</b> ổ hết chỗ hoặc báo "Scratch disk full" ngay trong phiên Photoshop, và đầy lên theo thao tác.</li>
<li><b>Sửa:</b> thoát Photoshop (nếu app treo thì khởi động lại máy, macOS tự dọn thư mục tạm). Giảm số History States trong <b>Photoshop › Settings › Performance</b> (mặc định 50) để bớt ghi tạm, và ở <b>Settings › Scratch Disks</b> chọn ổ còn nhiều chỗ. Trên Windows Adobe hướng dẫn xoá tay file "Photoshop Temp" ở ổ C; trên Mac Adobe không chỉ xoá tay, chỉ cần thoát app và khởi động lại.</li>
</ul>

<h2 id="cu">Bản cũ và bộ cài</h2>
<ul>
<li><b>Là gì:</b> mỗi năm Adobe ra bản mới (Photoshop 2025, 2026), mỗi bản 5–6 GB. Khi cập nhật, hộp thoại Update của Creative Cloud có ô <b>Remove old versions</b> bật sẵn; ai từng bỏ tick (để giữ plug-in cũ chẳng hạn) thì máy đang có cả hai bản.</li>
<li><b>Nhận ra:</b> trong <code>/Applications</code> có hai thư mục cùng tên app khác năm.</li>
<li><b>Sửa:</b> gỡ bản cũ bằng app Creative Cloud (mục Installed, nút ba chấm, Uninstall), không kéo vào Thùng rác vì sẽ sót phần trong Library. Lần cập nhật sau để nguyên ô Remove old versions.</li>
</ul>

<h2 id="gioi-han">Đặt giới hạn để không phải dọn lại</h2>
<ol class="steps">
<li>Premiere: bật một trong hai lựa chọn tự xoá Media Cache (theo ngày hoặc theo dung lượng); với máy 256–512 GB, 30 ngày hoặc 20–30 GB là vừa. Adobe lưu ý thiết lập có hiệu lực sau khi mở lại app và dọn theo tuần.</li>
<li>Camera Raw: giữ Maximum Size ở 5–10 GB trừ khi chỉnh RAW mỗi ngày.</li>
<li>Creative Cloud: khi cập nhật, để nguyên ô Remove old versions.</li>
<li>Máy dựng video nhiều: chuyển Media Cache sang ổ SSD ngoài (cùng mục Media Cache, nút Browse; Adobe cũng khuyên dùng SSD riêng), ổ trong chỉ còn app.</li>
</ol>

<h2 id="tidymint">Tìm nhanh với Tidymint</h2>
<p>Tidymint có trang <b>Bản đồ ổ đĩa</b> vẽ từng thư mục thành quả bóng to nhỏ theo dung lượng thật, nên hai thư mục Media Cache và Camera Raw lộ ra ngay nếu chúng đang phình, và trang <b>Gỡ app</b> liệt kê bản Adobe cũ cùng phần sót lại. Mọi thứ chỉ chuyển vào Thùng rác và có Hoàn tác.</p>
{CTA}
""",
  faq=[
    ("Xoá bộ nhớ đệm Adobe có mất ảnh hay dự án không?", "Không. Media Cache, bộ nhớ đệm Camera Raw và file tạm là bản dựng sẵn từ file gốc; file gốc và dự án nằm ở chỗ bạn lưu. Xoá xong app dựng lại, chỉ chậm hơn lúc mở."),
    ("Sao xoá cache rồi mà Adobe vẫn chiếm 10 GB?", "Đó là phần cài đặt: app, thư viện dùng chung, Camera Raw, plug-in. Chỉ giảm khi gỡ app hoặc gỡ bản cũ."),
    ("Thư mục CameraRaw 2 GB trong /Library/Application Support có xoá được không?", "Không nên. Đó là hồ sơ ống kính và model AI của Camera Raw, không phải bộ nhớ đệm. Xoá thì Photoshop tải lại hoặc lỗi khi mở ảnh RAW."),
    ("Xoá Media Cache bằng Finder hay trong Premiere?", "Trong Premiere an toàn hơn vì app biết file nào dự án đang mở còn dùng. Xoá bằng Finder chỉ nên làm khi đã thoát mọi app Adobe."),
    ("Tidymint có dọn Adobe tự động không?", "Chưa có luật riêng cho Adobe. Bản đồ ổ đĩa và Gỡ app giúp tìm và gỡ bản cũ; phần bộ nhớ đệm bạn dọn theo bài này."),
  ],
  sources=[
    ("Adobe: Xoá media cache bằng Settings trong Premiere", "https://helpx.adobe.com/premiere/desktop/troubleshooting/media-issues/clear-media-cache-using-preferences.html"),
    ("Adobe: Xoá file media cache thủ công (đường dẫn trên macOS)", "https://helpx.adobe.com/premiere/desktop/troubleshooting/media-issues/delete-media-cache-files-manually.html"),
    ("Adobe: Tự động quản lý file Media Cache", "https://helpx.adobe.com/premiere/desktop/troubleshooting/media-issues/automatically-manage-your-media-cache-files.html"),
    ("Adobe: Tối ưu hiệu năng Lightroom Classic (Camera Raw cache mặc định 5 GB)", "https://helpx.adobe.com/lightroom-classic/desktop/technical-support/performance-guidelines/optimize-performance-lightroom.html"),
    ("Adobe: Lỗi scratch disk đầy trong Photoshop", "https://helpx.adobe.com/photoshop/desktop/troubleshoot/performance-stability-issues/troubleshoot-scratch-disk-full-errors-in-photoshop.html"),
    ("Adobe: Lỗi Unable to allocate memory trong After Effects (Empty Disk Cache)", "https://helpx.adobe.com/after-effects/desktop/troubleshooting/fixed-and-known-issues/allocate-memory-error.html"),
    ("Adobe: Nâng cấp mượt lên bản Creative Cloud mới (Remove Old Versions)", "https://helpx.adobe.com/x-productkb/global/ensure_smooth_update_creative_cloud.html"),
    ("Adobe Community: Adobe cache chiếm quá nhiều Dữ liệu hệ thống (350 GB)", "https://community.adobe.com/questions-712/adobe-cache-takes-up-too-much-space-in-my-macbook-s-system-data-1177582"),
  ],
  related=[("Vì sao Mac tự đầy ổ dù không tải gì", "{HOME}mac-tu-day-o/"), ("Xóa ứng dụng trên MacBook sạch hoàn toàn", "{HOME}xoa-ung-dung-macbook/"), ("Trang chủ Tidymint", "{HOME}")],
  alt="adobe-storage-mac",
),
dict(
  lang="en", slug="adobe-storage-mac", date="2026-10-27", read="6 min read",
  title="Adobe Taking Up Space on Mac? What You Can Delete | Tidymint",
  desc="Photoshop, Premiere and Lightroom eat tens of GB on a Mac. Which part is the apps, which is cache you can clear (Media Cache, Camera Raw), and how to cap it.",
  crumb="Adobe storage",
  h1="How much space Adobe takes on a Mac, and what you can actually delete",
  tldr="Adobe on a Mac is two very different things: the <b>installation</b> (apps, shared libraries, Camera Raw, plug-ins) at 10–15 GB that you cannot trim, and the <b>caches</b> (Premiere and After Effects Media Cache, the Camera Raw cache used by Lightroom and Photoshop, Photoshop scratch files) that can grow to hundreds of GB but are safe to clear because the apps rebuild them. This guide points at each one, with real numbers from a Mac that only has Photoshop installed.",
  toc=[("two-parts","The two parts of Adobe on your disk"),("measured","Real numbers from a Photoshop-only Mac"),("media-cache","Premiere and After Effects Media Cache"),("camera-raw","Camera Raw cache"),("scratch","Photoshop scratch files"),("old","Old versions and installers"),("caps","Set limits so you never clean again"),("tidymint","Find it fast with Tidymint")],
  body="""
<h2 id="two-parts">The two parts of Adobe on your disk</h2>
<p>People open Storage settings, see Adobe at tens of GB, clear a cache, and the number barely moves. The reason: most of Adobe's footprint is the <b>installation</b>, not junk.</p>
<ul>
<li><b>Installation:</b> the apps themselves (Photoshop about 6 GB, Premiere and After Effects similar), the shared libraries in <code>/Library/Application Support/Adobe</code> (Camera Raw, plug-ins, CEP, Creative Cloud), and the Creative Cloud app. This only shrinks when you uninstall an app or an old version.</li>
<li><b>Caches:</b> Premiere and After Effects Media Cache, the Camera Raw cache, Photoshop scratch files, Creative Cloud downloads. The apps rebuild these, they are safe to clear, and they are what makes "System Data" balloon.</li>
</ul>
<p>On Adobe's own forum a user measured <code>~/Library/Caches/Adobe</code> at 350 GB on a 1 TB drive; after clearing it and setting a 30 GB cap, free space rose by more than 500 GB. That is the second part.</p>

<h2 id="measured">Real numbers from a Photoshop-only Mac</h2>
<p>Machine: a Mac mini with Photoshop 2026 and Creative Cloud only, no Premiere, no Lightroom. Measured 27 Oct 2026.</p>
<table>
<tr><th>Where</th><th>Size</th><th>Can it go?</th></tr>
<tr><td><code>/Applications/Adobe Photoshop 2026</code></td><td>6.2 GB</td><td>No, it is the app</td></tr>
<tr><td><code>/Library/Application Support/Adobe/CameraRaw</code> (lens profiles, Camera Raw AI models)</td><td>2.2 GB</td><td>Better not, Photoshop needs it for RAW files</td></tr>
<tr><td>Rest of <code>/Library/Application Support/Adobe</code> (Desktop Common, Plug-Ins, CEP, CC Libraries)</td><td>2.4 GB</td><td>No, shared libraries</td></tr>
<tr><td><code>/Applications/Utilities/Adobe Creative Cloud</code> plus Adobe Sync and Experience</td><td>0.6 GB</td><td>No</td></tr>
<tr><td><code>~/Library/Application Support/Adobe</code> (your settings, CoreSync)</td><td>126 MB</td><td>Small</td></tr>
<tr><td><code>~/Library/Application Support/Adobe/Adobe Photoshop 2021</code></td><td>3 MB</td><td>Leftover from an old version, yes</td></tr>
<tr><td>Camera Raw cache, Media Cache</td><td>0</td><td>Yes, when present</td></tr>
</table>
<p>11.5 GB in total, of which only a few MB can go. This Mac has no Premiere and never opens RAW files, so the two big caches have not appeared yet. A Mac that edits video or RAW photos every day will have the items below on top.</p>

<h2 id="media-cache">Premiere and After Effects Media Cache</h2>
<ul>
<li><b>What it is:</b> for every clip you import, Premiere and After Effects build audio and index files (.cfa, .pek, .ims) so scrubbing stays smooth. According to Adobe, on macOS they live in <code>~/Library/Application Support/Adobe/Common</code> (the Media Cache Files and Media Cache folders). By default Premiere <b>does not delete them</b> ("Do not delete cache files automatically" is the default), so finished projects leave their cache behind.</li>
<li><b>How to spot it:</b> those folders are several GB, or System Data jumps after every video project.</li>
<li><b>Fix:</b> in Premiere open <b>Premiere › Settings › Media Cache</b>, click <b>Delete</b> next to "Remove Media Cache Files", then choose <b>Delete unused media cache files</b> (only clips that can no longer be found) or <b>Delete all media cache files from the system</b> (close all projects first; files are recreated automatically when a project needs them). In the same pane turn on <b>Automatically delete cache files older than</b> (Adobe's default once enabled is 90 days) or <b>Automatically delete oldest cache files when cache exceeds</b> (default 10% of the volume). After Effects: <b>After Effects › Preferences › Media &amp; Disk Cache</b>, then <b>Empty Disk Cache</b> and <b>Clean Database &amp; Cache</b>. Deleting by hand in Finder also works once the apps are closed: Adobe's own guide says to delete the contents of the Common folder and empty the Trash; the next project open waits while the cache rebuilds.</li>
</ul>

<h2 id="camera-raw">Camera Raw cache</h2>
<ul>
<li><b>What it is:</b> Lightroom Classic and Camera Raw in Photoshop keep the original image data of every RAW file you opened so previews build faster next time. According to Adobe, Lightroom Classic caps this at <b>5 GB</b> by default, and Adobe itself suggests raising it to 10–20 GB for a faster Develop module, so many Macs run it high. The folder is usually called <code>Adobe Camera Raw 2</code> inside <code>~/Library/Caches</code> (or wherever you pointed it).</li>
<li><b>How to spot it:</b> that folder is big, or in Lightroom Classic <b>Preferences › File Handling › Camera Raw Cache Settings</b> shows a high Maximum Size.</li>
<li><b>Fix:</b> in the same place click <b>Purge Cache</b>, then lower Maximum Size; in Photoshop the equivalent sits under Camera Raw Preferences › Performance. Purging does not touch your originals or your edits (those live in the catalog and XMP files); reopening an image is just a beat slower.</li>
</ul>

<h2 id="scratch">Photoshop scratch files</h2>
<ul>
<li><b>What it is:</b> when RAM runs out, Photoshop writes to disk (the scratch disk), potentially tens of GB with large files and many History steps. A normal quit gives the space back; Adobe recommends keeping at least 100 GB free on the scratch drive.</li>
<li><b>How to spot it:</b> the disk fills up or Photoshop reports "Scratch disk full" during a session, growing as you work.</li>
<li><b>Fix:</b> quit Photoshop (if it hung, restart the Mac; macOS clears its temp folder). Lower History States in <b>Photoshop › Settings › Performance</b> (default 50) to write less, and pick a drive with room under <b>Settings › Scratch Disks</b>. On Windows Adobe tells you to delete "Photoshop Temp" files by hand on the C: drive; on the Mac Adobe gives no manual deletion step, quitting and restarting is enough.</li>
</ul>

<h2 id="old">Old versions and installers</h2>
<ul>
<li><b>What it is:</b> Adobe ships a new version every year (Photoshop 2025, 2026), 5–6 GB each. The Creative Cloud update dialog has <b>Remove old versions</b> ticked by default; anyone who unticked it (to keep old plug-ins, say) now has both versions installed.</li>
<li><b>How to spot it:</b> two folders with the same app name and different years in <code>/Applications</code>.</li>
<li><b>Fix:</b> uninstall the old version through the Creative Cloud app (Installed, three-dot menu, Uninstall), not by dragging to the Trash, which leaves the Library parts behind. Next update, leave Remove old versions ticked.</li>
</ul>

<h2 id="caps">Set limits so you never clean again</h2>
<ol class="steps">
<li>Premiere: turn on one of the two automatic Media Cache options (by age or by size); on a 256–512 GB Mac, 30 days or 20–30 GB is plenty. Adobe notes the setting takes effect after a restart of the app and then runs weekly.</li>
<li>Camera Raw: keep Maximum Size at 5–10 GB unless you edit RAW daily.</li>
<li>Creative Cloud: leave Remove old versions ticked when updating.</li>
<li>Heavy video work: move the Media Cache to an external SSD (same Media Cache pane, Browse; Adobe recommends a dedicated SSD too) so the internal drive only holds the apps.</li>
</ol>

<h2 id="tidymint">Find it fast with Tidymint</h2>
<p>Tidymint's <b>Space Lens</b> draws every folder as a bubble sized by its real footprint, so a swollen Media Cache or Camera Raw folder stands out at once, and <b>Uninstaller</b> lists old Adobe versions with their leftovers. Everything goes to the Trash and can be undone.</p>
{CTA}
""",
  faq=[
    ("Does clearing Adobe caches lose photos or projects?", "No. Media Cache, the Camera Raw cache and scratch files are built from your originals; the originals and projects stay where you saved them. The apps rebuild the caches, just slower on the next open."),
    ("I cleared the cache and Adobe still takes 10 GB. Why?", "That is the installation: apps, shared libraries, Camera Raw, plug-ins. It only shrinks when you uninstall an app or an old version."),
    ("Can I delete the 2 GB CameraRaw folder in /Library/Application Support?", "Better not. Those are lens profiles and Camera Raw AI models, not a cache. Remove them and Photoshop re-downloads them or fails on RAW files."),
    ("Delete Media Cache in Finder or inside Premiere?", "Inside Premiere is safer because the app knows which files open projects still use. Finder only once every Adobe app is closed."),
    ("Does Tidymint clean Adobe automatically?", "There is no dedicated Adobe rule yet. Space Lens and Uninstaller help you find and remove old versions; clear the caches as described here."),
  ],
  sources=[
    ("Adobe: Clear media cache using preferences in Premiere", "https://helpx.adobe.com/premiere/desktop/troubleshooting/media-issues/clear-media-cache-using-preferences.html"),
    ("Adobe: Delete media cache files manually (macOS path)", "https://helpx.adobe.com/premiere/desktop/troubleshooting/media-issues/delete-media-cache-files-manually.html"),
    ("Adobe: Automatically manage your Media Cache files", "https://helpx.adobe.com/premiere/desktop/troubleshooting/media-issues/automatically-manage-your-media-cache-files.html"),
    ("Adobe: Optimize Lightroom Classic performance (Camera Raw cache defaults to 5 GB)", "https://helpx.adobe.com/lightroom-classic/desktop/technical-support/performance-guidelines/optimize-performance-lightroom.html"),
    ("Adobe: Troubleshoot scratch disk full errors in Photoshop", "https://helpx.adobe.com/photoshop/desktop/troubleshoot/performance-stability-issues/troubleshoot-scratch-disk-full-errors-in-photoshop.html"),
    ("Adobe: Unable to allocate memory error in After Effects (Empty Disk Cache)", "https://helpx.adobe.com/after-effects/desktop/troubleshooting/fixed-and-known-issues/allocate-memory-error.html"),
    ("Adobe: Ensure a smooth upgrade to the next Creative Cloud version (Remove Old Versions)", "https://helpx.adobe.com/x-productkb/global/ensure_smooth_update_creative_cloud.html"),
    ("Adobe Community: Adobe cache takes up too much space in System Data (350 GB)", "https://community.adobe.com/questions-712/adobe-cache-takes-up-too-much-space-in-my-macbook-s-system-data-1177582"),
  ],
  related=[("Why a Mac keeps filling up by itself", "{HOME}mac-storage-keeps-filling-up/"), ("How to clear System Data on a Mac", "{HOME}clear-system-data-mac/"), ("Tidymint home", "{HOME}")],
  alt="adobe-chiem-dung-luong-mac",
),



dict(
  lang="en", slug="clear-system-data-mac", date="2026-10-26", read="8 min read",
  title="How to Clear System Data on Mac (Safely) | Tidymint",
  desc="System Data taking 50 GB or more? What it actually contains and 7 safe ways to shrink it: caches, Time Machine snapshots, Xcode, Docker.",
  crumb="Clear System Data on Mac",
  h1="How to clear System Data on Mac, safely",
  tldr="System Data is macOS's catch-all bucket for files that don't fit another category: caches, logs, local Time Machine snapshots, old iPhone backups, developer tools and more. You can shrink it safely by <b>restarting</b>, <b>emptying the Trash</b>, <b>deleting local snapshots</b>, <b>clearing user caches</b>, <b>removing old device backups</b> and cleaning <b>Xcode, Docker or AI model caches</b>. Never delete anything inside <code>/System</code> or <code>/private/var</code>.",
  toc=[("what","What is System Data?"),("check","Check how big it is"),("steps","7 safe ways to shrink System Data"),
       ("dont","What you should never delete"),("faster","The faster way: let an app find it"),("faq","FAQ")],
  body="""
<h2 id="what">What is System Data?</h2>
<p>Apple describes System Data (called "Other" on older macOS) as a general category that measures storage used by Apple and third-party files that don't fit a more specific category. In practice, it usually includes:</p>
<ul>
<li>App and browser <b>caches</b>, logs and temporary files</li>
<li><b>Local Time Machine snapshots</b> stored on your internal drive</li>
<li>Old <b>iPhone and iPad backups</b></li>
<li><b>Developer files</b>: Xcode build data, simulators, Docker disk images</li>
<li>For AI work: downloaded <b>model files</b> and package caches</li>
<li>Files macOS needs to run, like virtual memory and the sleep image (leave these alone)</li>
</ul>
<p>On a Mac that has been in use for a year or two, System Data can grow to 50 GB or more, and macOS gives you no button to clear it.</p>

<h2 id="check">Check how big it is</h2>
<p>Open <b>Apple menu › System Settings › General › Storage</b> (macOS 13 Ventura or later). Wait for the bar to finish calculating, then hover over the gray segment to see the System Data size. Note the number so you can see what each step frees.</p>

<h2 id="steps">7 safe ways to shrink System Data</h2>
<h3>1. Restart your Mac</h3>
<p>A restart clears temporary files and swap. It is free, safe, and sometimes frees several gigabytes on its own.</p>
<h3>2. Empty the Trash and your Downloads folder</h3>
<p>Files in the Trash still take space until you empty it. Old installers (<code>.dmg</code>, <code>.pkg</code>, <code>.zip</code>) in Downloads are a common hidden cost.</p>
<h3>3. Delete local Time Machine snapshots</h3>
<p>If you use Time Machine, macOS keeps snapshots on your internal drive. macOS removes them when it needs space, but the Storage screen often counts them as System Data. To list and remove them, open Terminal:</p>
<pre>tmutil listlocalsnapshots /
sudo tmutil deletelocalsnapshots 2026-10-20-101500</pre>
<p>Replace the date with one from the list. Your backups on the external Time Machine drive are not affected.</p>
<h3>4. Clear user caches</h3>
<p>Quit your apps, then in Finder press <b>Shift+Cmd+G</b> and go to <code>~/Library/Caches</code>. Move the folders of apps you recognize to the Trash. Apps rebuild what they need, so the first launch afterward may be a little slower.</p>
<div class="warn"><p>Use <code>~/Library/Caches</code> (with the tilde, your own folder), not <code>/Library/Caches</code> or <code>/System/Library/Caches</code>.</p></div>
<h3>5. Remove old iPhone and iPad backups</h3>
<p>Open <b>System Settings › General › Storage</b> and click the info button next to <b>iOS Files</b>. Delete backups of devices you no longer own or no longer need.</p>
<h3>6. Clean developer leftovers</h3>
<ul>
<li><b>Xcode build data</b>: move <code>~/Library/Developer/Xcode/DerivedData</code> to the Trash. Xcode recreates it.</li>
<li><b>Old simulators</b>: run <code>xcrun simctl delete unavailable</code>.</li>
<li><b>Docker</b>: run <code>docker system prune</code> to remove unused images and containers.</li>
<li><b>node_modules</b> in old projects you no longer work on.</li>
</ul>
<h3>7. Clean AI model caches</h3>
<ul>
<li><b>Ollama</b>: run <code>ollama list</code>, then <code>ollama rm model-name</code> for models you don't use.</li>
<li><b>Hugging Face</b>: downloaded models live in <code>~/.cache/huggingface</code>.</li>
</ul>
<p>A single local model can be several gigabytes, so this is often the biggest win on an AI workstation.</p>

<h2 id="dont">What you should never delete</h2>
<ul>
<li>Anything inside <code>/System</code>, <code>/private/var/vm</code> (virtual memory) or <code>/private/var/db</code></li>
<li>The whole <code>~/Library</code> folder, or your Photos and Mail libraries</li>
<li>Files you don't recognize. If you are not sure, leave it.</li>
</ul>
<p>Also be careful with "one click" cleaners that delete permanently. If something goes wrong, there is no undo.</p>

<h2 id="faster">The faster way: let an app find it</h2>
<p>Steps 2 to 7 mean digging through hidden folders. <a href="{HOME}">Tidymint</a> is a free, open-source Mac cleaner that does the looking for you: Clean Now finds user and app caches, logs, npm cache, old downloads and project drafts and shows them by group before you press Clean; Clean by App lists what Chrome, Edge, Zalo and CapCut keep; Space Lens draws a bubble map of what fills your disk, with plain-language notes for folders like <code>.ollama</code>. Everything you select <b>goes to the Trash first</b>, so you can check before you empty it.</p>
{CTA}
""",
  faq=[
    ("Is it safe to delete System Data on Mac?", "Parts of it, yes: caches, old downloads, local Time Machine snapshots, old device backups and developer build data are safe to remove. Files macOS needs to run, such as virtual memory, are not. Never delete anything inside /System or /private/var."),
    ("Why is my System Data so large?", "The usual causes are local Time Machine snapshots, app and browser caches, old iPhone backups, Xcode and Docker data, and downloaded AI models. On developer and AI machines it can pass 100 GB."),
    ("Will System Data shrink on its own?", "Partly. macOS removes local snapshots and some caches when space runs low, and a restart clears temporary files. It will not remove developer files, models or old backups for you."),
    ("Does restarting clear System Data?", "It clears temporary files and swap, which can free a few gigabytes. Larger items like snapshots and caches need the other steps."),
    ("Can Tidymint delete System Data?", "Tidymint finds the safe parts, such as caches, logs and old downloads, explains each folder, and moves only what you select to the Trash. It never touches Apple system folders."),
  ],
  sources=[
    ("Apple: Free up storage space on Mac", "https://support.apple.com/ht206996"),
    ("Macworld: How to delete Time Machine snapshots", "https://www.macworld.com/article/231067/how-to-delete-time-machine-snapshots-on-your-mac.html"),
  ],
  related=[("How to free up space on Mac", "{HOME}free-up-space-mac/"), ("Free CleanMyMac alternative", "{HOME}cleanmymac-alternative/")],
),

dict(
  lang="en", slug="free-up-space-mac", date="2026-10-26", read="7 min read",
  title="How to Free Up Space on Mac: 10 Safe Ways | Tidymint",
  desc="Mac storage almost full? 10 safe ways to free up space on macOS: clear cache, find large and duplicate files, remove unused apps and leftovers.",
  crumb="Free up space on Mac",
  h1="How to free up space on Mac: 10 safe ways",
  tldr="Start with <b>System Settings › General › Storage</b> to see what is using space. Then work down this list: empty the Trash, clear Downloads, turn on <b>Optimize Storage</b>, <b>clear browser and app caches</b>, remove <b>large and duplicate files</b>, <b>uninstall apps</b> together with their leftovers, and delete old device backups. A free app like Tidymint can do most of this in one scan.",
  toc=[("look","First, see what is using space"),("ways","10 safe ways"),("cache","How to clear cache on Mac"),("faster","Do it in one scan"),("faq","FAQ")],
  body="""
<h2 id="look">First, see what is using space</h2>
<p>Open <b>Apple menu › System Settings › General › Storage</b>. The colored bar shows your biggest categories, and the list below lets you open Applications, Documents, Messages and more. If <b>System Data</b> is the largest, read our guide to <a href="{HOME}clear-system-data-mac/">clearing System Data</a>.</p>

<h2 id="ways">10 safe ways</h2>
<ol class="steps">
<li><b>Empty the Trash.</b> Deleted files keep using space until you do. In Storage you can also turn on <b>Empty Trash Automatically</b> after 30 days.</li>
<li><b>Clear Downloads.</b> Sort by size and remove old installers (<code>.dmg</code>, <code>.pkg</code>) and archives you have already opened.</li>
<li><b>Turn on Optimize Storage.</b> If you pay for iCloud, macOS can keep only recent files on your Mac and download the rest on demand.</li>
<li><b>Clear browser and app caches.</b> See the steps below.</li>
<li><b>Find large files.</b> In Storage, open <b>Documents</b> and sort by size. Videos and old project exports are usually at the top.</li>
<li><b>Remove duplicate files.</b> Photos and downloads often exist two or three times under different names.</li>
<li><b>Uninstall apps you don't use</b>, together with their caches and settings. Dragging an app to the Trash leaves those behind.</li>
<li><b>Delete old iPhone and iPad backups</b> under Storage › iOS Files.</li>
<li><b>Clean Messages attachments.</b> Storage › Messages lists large photos and videos from old chats.</li>
<li><b>Move big libraries to an external drive.</b> Apple supports moving your Photos library and iMovie projects.</li>
</ol>

<h2 id="cache">How to clear cache on Mac</h2>
<h3>Safari</h3>
<p>Open <b>Safari › Settings › Advanced</b> and turn on <b>Show features for web developers</b>. Then choose <b>Develop › Empty Caches</b>.</p>
<h3>Chrome</h3>
<p>Open <b>Chrome › Settings › Privacy and security › Delete browsing data</b>, tick <b>Cached images and files</b> only (leave passwords and cookies), and click <b>Delete data</b>.</p>
<h3>App caches</h3>
<p>Quit your apps, press <b>Shift+Cmd+G</b> in Finder and go to <code>~/Library/Caches</code>. Move folders of apps you recognize to the Trash. Chat and design apps like Slack, Notion and VS Code often keep gigabytes here.</p>
<div class="warn"><p>Clearing caches frees space for a while, but apps rebuild them as you use them. It is maintenance, not a permanent fix. Large files, duplicates and unused apps give longer-lasting results.</p></div>

<h2 id="faster">Do it in one scan</h2>
<p><a href="{HOME}">Tidymint</a> is a free, open-source Mac cleaner that covers most of this list: Clean Now for caches, logs and old downloads (shown by group before you press Clean); Clean by App for Chrome, Edge, Zalo and CapCut; Large Files (never pre-selected); Duplicates that keeps the best copy; an Uninstaller that finds leftovers, even from apps you removed long ago; and Space Lens to see where the space went. Everything goes to the Trash first.</p>
{CTA}
""",
  faq=[
    ("What takes up the most space on a Mac?", "Usually videos and photos, apps and their data, iPhone backups, and System Data such as caches and Time Machine snapshots. System Settings › General › Storage shows the breakdown for your Mac."),
    ("Is it safe to clear cache on Mac?", "Yes, for your user caches in ~/Library/Caches and browser caches. Apps rebuild them as needed. Avoid system cache folders under /System or /Library."),
    ("How much free space should a Mac have?", "There is no official number, but keeping at least 10 to 15 percent of the drive free gives macOS room for updates, swap and snapshots."),
    ("Does Optimize Storage delete my files?", "No. Files stay in iCloud and download again when you open them. You need enough iCloud storage for this to work."),
    ("Is Tidymint free?", "Yes. It is open source under the MIT licence, with no account, no subscription and no paid tier."),
  ],
  sources=[
    ("Apple: Free up storage space on Mac", "https://support.apple.com/ht206996"),
    ("Apple: Uninstall apps on your Mac", "https://support.apple.com/en-lamr/102610"),
  ],
  related=[("How to clear System Data on Mac", "{HOME}clear-system-data-mac/"), ("Free CleanMyMac alternative", "{HOME}cleanmymac-alternative/")],
),

dict(
  lang="en", slug="cleanmymac-alternative", date="2026-10-26", read="6 min read",
  title="Free CleanMyMac Alternative (Open Source) | Tidymint",
  desc="Free CleanMyMac alternative? Compare Tidymint, AppCleaner, Pearcleaner, OnyX and the tools built into macOS, including what each one can't do.",
  crumb="Free CleanMyMac alternative",
  h1="The best free CleanMyMac alternatives",
  tldr="CleanMyMac has no free tier, only a <b>7-day trial</b>, then about <b>$40 a year</b> for one Mac. If you mainly need to <b>clear caches, uninstall apps cleanly and get disk space back</b>, free options cover it: <b>Tidymint</b> (free, open source, all-in-one cleaner), <b>AppCleaner</b> and <b>Pearcleaner</b> (uninstallers), <b>OnyX</b> (maintenance for power users) and macOS's own Storage settings. None of them replace CleanMyMac's malware scanner.",
  toc=[("price","What CleanMyMac costs"),("need","What do you actually need?"),("options","5 free alternatives"),("compare","Tidymint vs CleanMyMac"),("faq","FAQ")],
  body="""
<h2 id="price">What CleanMyMac costs</h2>
<p>CleanMyMac by MacPaw offers a <b>7-day free trial</b> with full features. After that, pricing seen in August 2026 was:</p>
<div class="tbl"><table>
<tr><th>Plan</th><th>Billed yearly</th><th>Billed monthly</th></tr>
<tr><td>1 Mac</td><td>about $40/year ($3.33/mo)</td><td>$9.95/mo</td></tr>
<tr><td>2 Macs</td><td>about $64/year</td><td>$15.95/mo</td></tr>
<tr><td>5 Macs</td><td>about $128/year</td><td>$32.95/mo</td></tr>
</table></div>
<p>A one-time purchase is also sold, but it does not include the next major version. Prices vary by country and tax.</p>
<div class="warn"><p>Skip "free" cracked copies. A cleaner asks for Full Disk Access and your admin password, and Jamf Threat Labs has documented pirated Mac apps carrying backdoors.</p></div>

<h2 id="need">What do you actually need?</h2>
<div class="tbl"><table>
<tr><th>Task</th><th>macOS built-in</th><th>Tidymint</th><th>CleanMyMac</th></tr>
<tr><td>Clear caches, logs, temp files</td><td class="n">Manual</td><td class="y">Yes</td><td class="y">Yes</td></tr>
<tr><td>Explain what System Data contains</td><td class="n">No</td><td class="y">Yes (Space Lens)</td><td class="y">Yes</td></tr>
<tr><td>Uninstall apps with leftovers</td><td class="n">Leaves leftovers</td><td class="y">Yes</td><td class="y">Yes</td></tr>
<tr><td>Find duplicates and large files</td><td class="n">Large files only</td><td class="y">Yes</td><td class="y">Yes</td></tr>
<tr><td>Malware protection</td><td class="y">Built in: XProtect, Gatekeeper</td><td>Relies on macOS's built-in layers, no scanner of its own</td><td class="y">Own scanner</td></tr>
<tr><td>Performance tools, app updates</td><td class="n">No</td><td class="n">No</td><td class="y">Yes</td></tr>
<tr><td>Undo after cleaning</td><td class="n">No</td><td class="y">Yes, everything goes to the Trash first</td><td>Some items</td></tr>
</table></div>

<h2 id="options">5 free alternatives</h2>
<h3>1. Tidymint: free, open-source all-in-one cleaner</h3>
<p><a href="{HOME}">Tidymint</a> covers cleanup, clean-by-app pages for browsers and messengers, duplicates, large files, an uninstaller with undo, a bubble map of your disk and a menu bar indicator. Its defining rule: <b>everything goes to the Trash</b>, nothing is deleted permanently until you empty it. It is MIT-licensed, works offline and is available in English and Vietnamese. Built with AI and developer workflows in mind, it also knows folders like <code>.ollama</code> and project drafts.</p>
<h3>2. AppCleaner: the classic uninstaller</h3>
<p>Free. Drag an app onto its window and it lists the related files to remove. Does one thing well.</p>
<h3>3. Pearcleaner: open-source uninstaller</h3>
<p>Free and open source. A modern uninstaller that also finds orphaned files from apps you already removed.</p>
<h3>4. OnyX: maintenance for power users</h3>
<p>Free and long-running. Many cleaning and system options, but the interface assumes you know macOS well.</p>
<h3>5. macOS Storage settings</h3>
<p><b>System Settings › General › Storage</b> offers Optimize Storage, Empty Trash Automatically and lists of large documents. Completely safe, but it doesn't touch caches or explain System Data.</p>
{CTA}

<h2 id="compare">Tidymint vs CleanMyMac</h2>
<p>To be clear: Tidymint does not replace all of CleanMyMac. It focuses on cleaning and disk space.</p>
<div class="tbl"><table>
<tr><th></th><th>Tidymint</th><th>CleanMyMac</th></tr>
<tr><td>Price</td><td class="y">Free, no account</td><td>About $40/year per Mac</td></tr>
<tr><td>Source code</td><td class="y">Open (MIT)</td><td>Closed</td></tr>
<tr><td>When cleaning</td><td class="y">Moves to Trash, you empty it</td><td>Follows the app's own settings</td></tr>
<tr><td>Malware protection</td><td>Relies on XProtect and Gatekeeper built into macOS</td><td class="y">Own scanner</td></tr>
<tr><td>Performance tools, app updates</td><td class="n">No</td><td class="y">Yes</td></tr>
<tr><td>Usage data collection</td><td class="y">None, no account needed</td><td>Yes (device info, usage statistics, cleanup logs), per MacPaw's privacy policy</td></tr>
<tr><td>Languages</td><td>English, Vietnamese</td><td>12 languages</td></tr>
<tr><td>Apple notarization</td><td class="n">Not yet, needs "Open Anyway" once</td><td class="y">Yes</td></tr>
<tr><td>Support</td><td>Email and GitHub</td><td class="y">Dedicated support team</td></tr>
</table></div>
<p><b>Pick CleanMyMac</b> if you want an all-in-one suite with malware protection and are happy to pay. <b>Pick Tidymint</b> if you want a clean Mac, free disk space and to see exactly what gets removed.</p>
""",
  faq=[
    ("Is there a free version of CleanMyMac?", "No. There is a 7-day free trial with full features, available from the MacPaw Store, the App Store and Setapp. After that you need a subscription or a one-time purchase."),
    ("Is CleanMyMac worth it?", "It is a polished suite with a malware scanner and support. If you only need cleanup and uninstalling, free tools do those jobs."),
    ("Is Tidymint safe?", "Tidymint only moves items to the Trash, so anything can be put back. It never touches Photos, Mail, keychains, cloud storage roots or Apple system caches, and its source code is public."),
    ("Why does macOS block Tidymint the first time?", "It is not notarized by Apple yet, which requires a paid developer account. Open it once via System Settings › Privacy & Security › Open Anyway, as Apple describes."),
    ("Does Tidymint work on Intel Macs?", "Yes. It runs on macOS 14 or later on both Apple silicon and Intel."),
  ],
  sources=[
    ("MacPaw: CleanMyMac editions and trial", "https://macpaw.com/support/cleanmymac/knowledgebase/editions"),
    ("MacPaw: languages CleanMyMac supports", "https://macpaw.com/support/cleanmymac/knowledgebase/languages"),
    ("MacPaw: CleanMyMac privacy policy", "https://macpaw.com/legal/cleanmymac-privacy-policy"),
    ("PricingSaaS: CleanMyMac pricing (seen Aug 2026)", "https://pricingsaas.com/companies/cleanmymac"),
    ("Jamf Threat Labs: malware in pirated macOS apps", "https://www.jamf.com/blog/jtl-malware-pirated-applications/"),
    ("Apple: Safely open apps on your Mac", "https://support.apple.com/102445"),
  ],
  related=[("How to clear System Data on Mac", "{HOME}clear-system-data-mac/"), ("How to free up space on Mac", "{HOME}free-up-space-mac/")],
  alt="cleanmymac-mien-phi",
),
]
