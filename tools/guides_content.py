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
    ("MacPaw: ngôn ngữ CleanMyMac hỗ trợ", "https://macpaw.com/support/cleanmymac/knowledgebase/languages"),
    ("MacPaw: chính sách riêng tư CleanMyMac", "https://macpaw.com/legal/cleanmymac-privacy-policy"),
    ("PricingSaaS: bảng giá CleanMyMac (ghi nhận 08/2026)", "https://pricingsaas.com/companies/cleanmymac"),
    ("Jamf Threat Labs: mã độc trong app Mac lậu (01/2024)", "https://www.jamf.com/blog/jtl-malware-pirated-applications/"),
    ("Apple: Mở app an toàn trên máy Mac", "https://support.apple.com/102445"),
  ],
  related=[("Cách xóa ứng dụng trên MacBook sạch hoàn toàn", "{HOME}xoa-ung-dung-macbook/"), ("Trang chủ Tidymint", "{HOME}")],
  alt="cleanmymac-alternative",
),

dict(
  lang="vi", slug="xoa-ung-dung-macbook", date="2026-10-26", read="6 phút đọc",
  title="Cách xóa ứng dụng trên MacBook sạch hoàn toàn (macOS 26) | Tidymint",
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
  lang="en", slug="clear-system-data-mac", date="2026-10-26", read="8 min read",
  title="How to Clear System Data on Mac (Safely) | Tidymint",
  desc="System Data taking up 50 GB or more? Here is what it actually contains and 7 safe ways to shrink it on macOS, from caches and Time Machine snapshots to Xcode and Docker.",
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
  desc="Mac storage almost full? 10 safe ways to free up space on macOS: storage recommendations, clearing cache, large and duplicate files, unused apps and leftovers, and more.",
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
  desc="Looking for a free CleanMyMac alternative? Compare Tidymint, AppCleaner, Pearcleaner, OnyX and the tools built into macOS, with an honest look at what each one can't do.",
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
