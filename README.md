# Vstudy

Ứng dụng Flutter hỗ trợ học tập, tổ chức theo **Clean Architecture**, dùng **Supabase** (Auth, PostgreSQL, Storage, Edge Functions) và **Gemini API** ở phía máy chủ.

## Giao diện trên nhánh android-working

Trang chủ và lịch được chỉnh theo ảnh mẫu mới: nền kem/vàng nhạt, thẻ mục tiêu navy với vòng tiến độ vàng, các thẻ Quiz/Tài liệu, biểu đồ tuần và lịch ngày/tuần/tháng.

Các trang dùng chung nền kem chuyển xanh nhạt của Thống kê, gồm cả các trang con, tài khoản, đăng nhập và công cụ AI. Mục **Thống kê học tập** có thẻ trắng cùng kiểu với các mục bên dưới. Nút **Kiểm tra đáp án / Câu tiếp theo / Nộp bài** trong Quiz được căn giữa, rộng bằng vùng câu hỏi.

Footer chung có thứ tự **Lịch → Quiz → Trang chủ → Thống kê → Tài liệu**; biểu tượng ngôi nhà nằm giữa và mở Trang chủ. AI mở bằng nút tròn vàng hình lấp lánh bên phải, tách khỏi footer. Footer giữ nguyên khi mở quiz, hội thoại hay tài liệu trong từng tab. Chạm lại biểu tượng tab sẽ trở về trang đầu của tab đó. Nút Back Android đóng trang con trước; từ AI trở về tab đã mở trước đó.

## Đăng nhập và đăng ký theo thiết kế mới

Lần chạy mặc định mở giao diện **Đăng nhập** với nền kem chuyển xanh, thẻ trắng, email/mật khẩu, nút hiện/ẩn mật khẩu, quên mật khẩu và Google. Chọn **Đăng ký** để mở form họ tên, email, mật khẩu, nhập lại mật khẩu và đồng ý Điều khoản/Chính sách bảo mật. Nút gửi chỉ bật khi dữ liệu hợp lệ; lỗi giữ lại nội dung để sửa, thao tác đang gửi được khóa chống gửi lặp.

Ứng dụng mặc định dùng Supabase thật; cần cấu hình URL và publishable/anon key qua `--dart-define-from-file=config/dev.json`. Chỉ khi chủ động đặt `--dart-define=LIVE_BACKEND=false` mới mở bản xem thử. Trong bản xem thử, các nút xác thực thật được tắt. Nhấn **Xem thử ứng dụng** để vào Trang chủ với dữ liệu minh họa. Để vào thẳng Trang chủ mẫu, dùng cả `--dart-define=LIVE_BACKEND=false --dart-define=SKIP_AUTH_PREVIEW=true`.

Khi bật `LIVE_BACKEND=true`, Supabase xử lý đăng nhập, đăng ký, Google OAuth và đặt lại mật khẩu. Với Confirm email đã tắt, đăng ký thành công quay về Đăng nhập, không tự mở Trang chủ. Nếu server vẫn bật Confirm email, ứng dụng tiếp tục hỗ trợ xác nhận/gửi lại email. Chỉ phiên đăng nhập hợp lệ mới mở Trang chủ; đăng ký đang chờ xác nhận email không mở dữ liệu cá nhân. Callback PKCE được xử lý chung lúc khởi động và khi ứng dụng đang mở; Android/iOS đã có cấu hình URI. Không cần migration hoặc Edge Function mới cho thay đổi xác thực này. Xem [cấu hình Email Auth, Google và cách kiểm tra](docs/auth-upgrade.md).

## Thư viện tài liệu theo thiết kế mới

Tab **Tài liệu** có tìm kiếm, lọc môn/yêu thích, danh sách đã tải trên thiết bị, xem PDF/TXT, phân môn và tải lên/xóa. PDF đọc ngay trong app Android/iOS; tải xuống dùng hộp lưu tệp thật, có tùy chọn bản đọc ngoại tuyến. Từ trang xem có thể hỏi đáp Vstudy Ai, tạo tóm tắt và xuất bản tóm tắt TXT.

Backend thật cần chạy thêm `supabase/migrations/202611040003_document_library.sql` sau các migration trước. Chạy `flutter pub get`, Stop rồi Run lại để cài plugin đọc PDF/lưu ngoại tuyến. Không cần deploy Edge Function mới cho thư viện. Xem [hướng dẫn nâng cấp Tài liệu và kiểm chứng](docs/document-library-upgrade.md).

## Trợ lý AI theo các frame mới

Nhấn nút vàng lấp lánh để mở trang công cụ AI với nền kem chuyển xanh, thẻ giới thiệu navy, **Tóm tắt / Hỏi đáp / Tạo đề ôn**, hội thoại gần đây và nội dung đã tạo. Lộ trình và flashcard vẫn có ở các lối tắt bên dưới. Có thể gửi câu hỏi ngay từ ô nhập ở trang công cụ.

- **Hỏi đáp:** chọn một tài liệu PDF/TXT hoặc hỏi đáp chung; bong bóng tin nhắn, trạng thái chờ, gợi ý câu hỏi, sao chép câu trả lời và lịch sử hội thoại. Tài liệu/chế độ được cố định sau khi bắt đầu hội thoại. Câu hỏi mở từ Quiz chỉ được điền sẵn, không tự gửi; các bản nháp AI đang có được giữ lại.
- **Tóm tắt:** thư viện có tìm kiếm, lọc PDF/TXT, tải tệp mới và chọn tối đa 3 tài liệu với tổng dung lượng tối đa 10 MiB. Kết quả có ba tab **Ngắn gọn / Chi tiết / Sơ đồ**, từ khóa, sao chép và đánh giá hữu ích; lưu lại để mở từ trang công cụ.
- **Tạo đề ôn:** 10/20/30/40 câu, độ khó Dễ/Vừa/Khó, chọn tài liệu hoặc nhập chủ đề. Nếu chỉ chọn trắc nghiệm, tạo quiz có đáp án riêng phía server, đồng hồ 30 phút và kết quả vào thống kê. Có gợi ý cho câu mới được tạo. Khi chọn đúng/sai hoặc tự luận, tạo đề tự luyện với phản hồi, gợi ý và đáp án mẫu; không tự chấm tự luận hoặc cộng điểm vào thống kê quiz.

Bản mẫu không gọi Gemini hoặc đọc nội dung tài liệu, các màn hình hiển thị rõ dữ liệu minh họa. Với backend thật, cài migration `202611040002_ai_workspace.sql`, deploy function mới `study-assistant` và cập nhật `generate-quiz` để có gợi ý. Xem [hướng dẫn backend và kiểm chứng AI](docs/ai-workspace-upgrade.md).

## Tài khoản từ ảnh đại diện

Chạm avatar ở góc trên bên phải Trang chủ để mở **Thông tin tài khoản**: avatar/tên/email, lớp/ngành, số giờ học và kết quả quiz trong 30 ngày, môn học, lối tắt chức năng và cài đặt. Số liệu lấy từ lịch sử học đã ghi nhận; chưa có quiz thì điểm hiển thị dấu gạch.

**Chỉnh sửa thông tin** cho phép đổi tên, lớp, ngành, ngày sinh, chọn một trong bốn avatar có sẵn và sửa mục tiêu học mỗi ngày. Email chỉ đọc từ Supabase Auth; sửa hồ sơ không đổi email đăng nhập. Sau khi lưu thành công xuất hiện hộp xác nhận dấu tích xanh; thông tin ở Trang chủ được tải lại khi quay về. Rời form chưa lưu cần xác nhận; lỗi lưu giữ nguyên nội dung để thử lại.

**Cài đặt** lưu lựa chọn chế độ tối cho các trang tài khoản và lựa chọn nhắc học. Nhắc học chưa phát thông báo thiết bị. Ngôn ngữ hiện là tiếng Việt. **Đăng xuất** cần xác nhận; tài khoản thật đóng phiên Auth và bỏ các trang dữ liệu cá nhân. Bản mẫu thoát sang màn hình có nút **Tiếp tục xem giao diện**, không yêu cầu đăng nhập. Avatar hiện là biểu tượng có sẵn, chưa hỗ trợ tải ảnh cá nhân lên.

Bản mẫu không cần SQL. Với backend thật, áp dụng thêm `supabase/migrations/202611040001_account_profile.sql` sau ba migration trước; không cần deploy Edge Function. Xem [nâng cấp và kiểm chứng tài khoản](docs/account-profile-upgrade.md).

## Thêm lịch trình theo các frame mới

Trong tab **Lịch**, chọn **+ Thêm** để mở form toàn trang có nền kem chuyển xanh. Nhập tên lịch, chọn **Môn học / Deadline**, **Trên lớp / Tự học**, ngày, giờ bắt đầu/kết thúc, địa điểm, ghi chú, lặp hằng tuần và thời gian nhắc. Mục mở rộng cho phép liên kết môn học và thêm checklist. Có thể chọn ngày kết thúc riêng cho lịch qua nửa đêm.

- **Xác nhận → Thêm** mới tạo lịch; **Hủy** trong hộp thoại giữ nguyên nội dung. Lưu thành công quay về ngày của lịch vừa tạo.
- Đóng form hoặc chuyển tab khi có nội dung chưa lưu sẽ hỏi trước khi bỏ nội dung. Nút AI vẫn mở hội thoại; quay lại sẽ tiếp tục form đang nhập.
- Mở một lịch đã có và chọn **Sửa** để cập nhật hoặc **Xóa lịch trình** để mở hộp xác nhận xóa màu đỏ. Sửa/xóa chỉ tác động buổi được chọn, giữ các buổi khác trong chuỗi và giữ ID/trạng thái checklist khi sửa.
- Tên trống, khoảng giờ không hợp lệ và số tuần lặp ngoài 1–52 bị chặn trước khi lưu. Khi đang lưu, nút gửi được khóa; nếu lưu lỗi, form giữ nội dung và hiển thị thông báo.

Không cần migration hay Edge Function mới cho thay đổi này. Nhắc trước hiện được lưu cùng lịch, chưa gửi thông báo thiết bị. Bản mẫu không cần đăng nhập và chỉ giữ thay đổi trong phiên; dữ liệu thật dùng Supabase khi bật `LIVE_BACKEND`. Xem [phạm vi kiểm chứng luồng lịch](docs/schedule-editor-verification.md).

## Quiz theo các frame mới

- Dashboard có tiến độ, mục tiêu theo ngày, bộ lọc Tất cả/Luyện tập/Đã thi/Câu sai, các môn và kết quả gần đây.
- Mỗi môn có ba tab **Bộ đề / Chương / Câu sai**. Có thể thêm môn/chương, tạo bộ đề theo chủ đề hoặc tài liệu, chọn thời lượng và độ khó. Quiz cũ chưa phân môn vẫn xuất hiện ở nhóm riêng.
- Chi tiết chương hiển thị số câu, thời gian, điểm tốt nhất và chọn **Luyện tập** hoặc **Thi thử**. Luyện tập phản hồi từng câu; thi thử có đồng hồ, tự nộp khi hết giờ và tính câu bỏ trống là sai. Đồng hồ là công cụ phía client, không phải hệ thống giám sát thi.
- Màn hình câu hỏi hiển thị từng câu với bốn lựa chọn A–D, tiến độ và nút tiếp theo. Kết quả cho phép xem lời giải và làm lại; mở lịch sử sẽ xem đúng bài đã nộp, không tự bắt đầu bài mới.
- Ngân hàng câu sai dùng câu trả lời gần nhất. Luyện lại từng câu/toàn bộ; trả lời đúng gỡ câu khỏi bank. Nút **Giải thích AI** điền câu hỏi và đáp án vào hội thoại để người dùng gửi khi muốn, không tự gọi Gemini.
- **Đã thi** lọc bài nộp chế độ thi thử; luyện tập có lịch sử riêng. Bản mẫu có Triết học Mác–Lênin, Pháp luật, Toán và Quản trị dự án cùng các chương/bộ đề minh họa. Thay đổi mẫu được khôi phục khi khởi động lại.

Để xem giao diện: cập nhật nhánh `android-working`, chạy `flutter pub get`, dừng app cũ và Run lại `lib/main.dart`. Không cần đăng nhập hay chạy SQL để xem bản mẫu.

**Backend thật:** sau migration ban đầu, áp dụng file mới `supabase/migrations/202611030002_quiz_learning.sql`, rồi deploy lại `generate-quiz`. Không chạy lại migration đầu tiên. Xem [hướng dẫn nâng cấp Quiz](docs/quiz-backend-upgrade.md) và [kết quả xác minh](docs/quiz-verification.md).

## Thống kê theo các frame mới

Tab biểu đồ mở menu gồm **Thống kê học tập, Tập trung, Quiz, Theo môn học, Mục tiêu và chuỗi học, Báo cáo tuần, Flashcard**. Các trang dùng nền kem chuyển xanh nhạt, thẻ trắng/navy, điểm nhấn vàng; footer và nút AI vàng vẫn hiện khi điều hướng.

- **Học tập:** biểu đồ tuần, lịch nhiệt tháng có thể chọn ngày, đường xu hướng học kỳ, ngày/tuần học nhiều nhất, so sánh với kỳ trước và tiến độ mục tiêu. Tuần bắt đầu thứ Hai, tháng theo lịch thật, ngày học kỳ có thể chỉnh. Biểu đồ không vẽ hoạt động chưa xảy ra.
- **Quiz:** điểm trung bình và số câu đúng/sai trong 7 ngày, so sánh 7 ngày trước; mức nắm vững chương lấy đáp án mới nhất tích lũy. Nút luyện câu sai mở đúng các câu đang sai, không suy đoán từ tỷ lệ tiến độ.
- **Theo môn:** lọc thời gian học, kết quả quiz, lượt ôn thẻ và việc học đã hoàn thành; tiến độ từng chương và nút mở lộ trình quiz của môn.
- **Mục tiêu:** sửa phút học/tuần, số ngày học, mục tiêu ôn flashcard và ngày học kỳ; xem chuỗi hiện tại, kỷ lục và từng ngày. Mục tiêu học theo ngày dùng chung hồ sơ ở Trang chủ.
- **Tập trung / Flashcard:** xem lịch sử và ghi nhận phiên thực tế. Tỷ lệ tập trung là phút tập trung/phút dự kiến; mức ghi nhớ là lượt nhớ đúng/lượt ôn. Chưa ghi nhận thì hiển thị thiếu dữ liệu, không tự tạo tỷ lệ. Flashcard đếm lượt ôn, không phải số thẻ duy nhất; focus được lưu riêng, không tự cộng hai lần vào giờ học.
- **Báo cáo tuần:** tổng hợp kết quả thực tế và sao chép nội dung để sử dụng khi cần.

Bản mẫu mặc định có lịch sử minh họa sáu tháng để xem đủ biểu đồ, không cần SQL hoặc đăng nhập. Các thay đổi mẫu chỉ giữ trong phiên. Với backend thật, áp dụng thêm `supabase/migrations/202611030003_statistics.sql` **sau** hai migration trước; không cần deploy lại Edge Function cho phần thống kê. Xem [nâng cấp backend Thống kê](docs/statistics-backend-upgrade.md) và [phạm vi kiểm chứng](docs/statistics-verification.md).

Mặc định mở đăng nhập Supabase thật. Thiếu cấu hình thì hiển thị thông báo cấu hình, không tự chuyển sang dữ liệu mẫu. Muốn xem thử, chủ động chạy với `--dart-define=LIVE_BACKEND=false` rồi nhấn **Xem thử ứng dụng**. Dữ liệu minh họa chỉ lưu trong phiên chạy; phần chat/quiz mô phỏng được ghi rõ là minh họa.

Để chạy trong Android Studio: chọn `lib/main.dart`, chọn thiết bị Android và bấm Run. Hoặc dùng Terminal:

```sh
flutter pub get
flutter run -d ID_THIET_BI --dart-define-from-file=config/dev.json
```

Nhánh này đã có runner Android/iOS/web do người dùng thêm, không cần tạo lại. Muốn dùng backend thật và xác thực, chạy với `--dart-define=LIVE_BACKEND=true --dart-define-from-file=config/dev.json`.

Chi tiết xác minh: [giao diện và điều hướng](docs/ui-redesign-verification.md). Flutter SDK chưa chạy được trong máy đám mây; chưa xác nhận widget test/build hoặc so ảnh trên thiết bị. Avatar và biểu tượng dùng icon Flutter vì ảnh gốc/font Figma chưa được cung cấp.

Sáu file Figma gốc được giữ nguyên trong `design_reference/`. Các file xuất từ Figma đều chứa `main()` riêng và dữ liệu minh họa; chúng không được import vào ứng dụng. `lib/presentation/` là các màn hình tích hợp nghiệp vụ, bố cục linh hoạt; chưa phải bản dựng khớp từng pixel của Figma.

## Các chức năng theo thứ tự triển khai

1. **Đăng nhập, đăng ký:** email/mật khẩu, kiểm tra nhập lại mật khẩu và đồng ý điều khoản, xác nhận email, Google OAuth, quên/đổi mật khẩu, lưu phiên và đăng xuất.
2. **Trang chủ:** hồ sơ, mục tiêu phút học/ngày, tiến độ hôm nay, biểu đồ tuần, lịch sắp tới, quiz và hội thoại gần đây. Ghi nhận phiên học đã hoàn thành và tạo môn học.
3. **Lịch:** xem ngày/tuần/tháng, thêm/sửa/xóa từng buổi, lớp học/tự học/deadline, địa điểm, ghi chú, checklist, tạo lịch lặp theo tuần. Thời gian nhắc được lưu; chưa gửi thông báo thiết bị.
4. **Quiz:** Gemini tạo 1–30 câu từ chủ đề hoặc tài liệu, làm bài, chấm điểm ở database, xem đáp án/giải thích sau khi nộp, lịch sử kết quả. Retry cùng mã bài nộp không cộng thêm kết quả.
5. **AI:** hội thoại lưu lịch sử, hỏi đáp, tóm tắt, lộ trình và flashcard. Chọn/tải/xóa PDF hoặc TXT riêng tư; backend gửi tài liệu đã chọn đến Gemini. Lộ trình chỉ là gợi ý, chưa tự sửa lịch.
6. **Thống kê:** khoảng 7/30/90 ngày, phút học theo ngày/môn, số bài quiz, điểm quiz trung bình và chuỗi ngày học. Dựa trên phiên học thực tế, không cộng lịch học dự kiến.

## Cấu trúc

```text
lib/
  domain/          # Entity, repository interface, use case, thống kê thuần Dart
  data/            # Supabase adapter, mapping, xử lý lỗi
  presentation/    # Flutter UI; chỉ gọi domain/interface
  core/            # Lỗi nghiệp vụ
  main.dart        # Khởi tạo Supabase và dependency injection
supabase/
  migrations/     # Schema, RLS, Storage policies, RPC, quota AI
  functions/      # ai-chat, generate-quiz và kiểm thử
  tests/          # Kiểm thử SQL và bootstrap database giả lập Auth/Storage
test/             # Unit/widget tests Flutter, kiểm thử cấu hình mobile
scripts/          # Khởi tạo runner Android/iOS khi có Flutter SDK
tools/            # Runner kiểm thử PostgreSQL dùng database tạm
```

Chi tiết: [kiến trúc và ranh giới bảo mật](docs/architecture.md), [API Edge Functions](supabase/functions/README.md), [schema và hợp đồng dữ liệu](docs/implementation_contract.md).

## Chuẩn bị Supabase

Muốn tài khoản mới có nhiều nội dung như bản xem thử, dùng [bộ dữ liệu khởi tạo đầy đủ](sample_data/README.md): 5 môn, 30 Quiz mới, lịch 8 tuần và lịch sử học 180 ngày. Chạy file SQL theo email tài khoản; lịch sử khởi tạo sẽ được tính vào thống kê. Có gói 5 tài liệu TXT thật để tải lên thư viện.

Cần Flutter stable **>=3.35**, Dart **>=3.9**, Android SDK để chạy Android; iOS cần macOS/Xcode. Backend có thể dùng Supabase hosted hoặc Supabase CLI + Docker để chạy cục bộ.

Với dự án Supabase **mới dành cho Vstudy**, chạy từ thư mục repository:

```sh
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

Lệnh `db push` áp dụng migration thật. Đọc migration trước khi chạy trên database đã có dữ liệu. Không chạy `supabase/tests/bootstrap.sql` trên Supabase; đó là schema giả lập chỉ dùng cho kiểm thử PostgreSQL trống.

Trong Supabase Dashboard:

- Bật Email Auth, tắt Confirm email để đăng ký không cần xác nhận email và đặt mật khẩu tối thiểu 8 ký tự. Cấu hình SMTP để gửi email thật.
- Thêm `io.vstudy.app://login-callback/` vào Auth → URL Configuration → Redirect URLs.
- Nếu dùng Google: cấu hình Google provider và client ID/secret trong Supabase. Google OAuth cần callback `https://YOUR_PROJECT.supabase.co/auth/v1/callback`; ứng dụng nhận kết quả qua URI ở trên.
- Bật Gemini API cho khóa của bạn. Không đưa khóa Gemini hoặc Supabase service role vào Flutter.

Tạo `supabase/functions/.env` từ `.env.example`, nhập khóa Gemini **trên máy của bạn** hoặc dùng Supabase Dashboard → Edge Function Secrets. File `.env` đã được gitignore.

```sh
supabase secrets set --env-file supabase/functions/.env
supabase functions deploy ai-chat
supabase functions deploy generate-quiz
supabase functions deploy study-assistant
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` được Supabase cấp cho Edge runtime. Hai function tự xác thực access token bằng Auth API; cấu hình `verify_jwt = false` không bỏ bước xác thực này. Mô hình mặc định `gemini-2.5-flash`; đổi `GEMINI_MODEL` trong secrets nếu tài khoản của bạn dùng mô hình khác.

## Chạy Flutter

Nhánh `android-working` đã có runner Android/iOS/web. Script bên dưới chỉ cần dùng khi thiếu runner hoặc muốn đồng bộ cấu hình callback; giữ nguyên mã ứng dụng và các thư mục runner đang có:

```sh
bash scripts/bootstrap_flutter.sh
cp config/dev.example.json config/dev.json
```

Điền URL dự án và **publishable/anon key** trong `config/dev.json` (file bị gitignore). Đây là thông tin phía client; RLS và JWT bảo vệ dữ liệu. Không điền service role key vào đây.

```sh
flutter run --dart-define=LIVE_BACKEND=true --dart-define-from-file=config/dev.json
```

Nếu dùng Android emulator với Supabase local, URL API thường là `http://10.0.2.2:54321`; thiết bị thật dùng địa chỉ LAN thích hợp. Chỉ khi phát triển với HTTP cục bộ, cần cấu hình Android debug network security cho cleartext; bản production dùng HTTPS. Callback trong config và Dashboard phải trùng nhau. Khi đổi URI scheme, cũng sửa manifest Android và Info.plist iOS tương ứng. Custom scheme phù hợp phát triển; production nên cấu hình App Links/Universal Links theo domain của ứng dụng.

## Kiểm thử

```sh
# SQL: tự tạo, kiểm tra, dừng và xóa cluster PostgreSQL tạm; không dùng DB thật.
npm ci --prefix tools
npm test --prefix tools

# TypeScript và Edge Functions với fetch giả lập (không cần khóa thật).
deno task check
deno task test
deno lint supabase/functions

# Cấu hình callback Android/iOS.
python3 -m unittest discover -s test -p '*_test.py' -v

# Khi đã có Flutter SDK.
flutter analyze
flutter test
```

`tools` cần Node.js >=20 và user thường để chạy PostgreSQL; PostgreSQL không chạy dưới root. Các kiểm thử SQL giả lập phần auth/storage của Supabase, không thay thế kiểm thử end-to-end dịch vụ thật. Xem [kết quả xác minh trong môi trường hiện tại](docs/verification.md).

## Giới hạn hiện tại

- Cần cấu hình Supabase và Gemini của bạn trước khi đăng nhập/chat thật; chưa deploy đến một dự án bên ngoài.
- Chưa có notification scheduler/FCM, streaming AI, push chat, trích dẫn số trang đã kiểm chứng hay tự tạo lịch bằng AI. Không hiển thị thông tin minh họa của Figma như dữ liệu thật.
- Tài liệu tối đa 10 MiB; TXT UTF-8 tối đa 60.000 ký tự khi dùng AI. PDF được gửi trực tiếp tới Gemini, chưa có pipeline OCR/index/RAG riêng. Gemini có thể từ chối PDF hoặc trả lời sai; đối chiếu kiến thức với tài liệu.
- Ngày/tuần thống kê theo múi giờ thiết bị; timestamp gửi API là UTC. `profiles.timezone` được lưu để mở rộng sau, chưa điều khiển quy đổi ngày của UI. Điểm trung bình là trung bình phần trăm từng bài nộp; streak dựa trên ngày có thời gian học, không dựa trên việc mở app.
- Việc sửa/xóa lịch chỉ ảnh hưởng một buổi; checklist tạo lúc thêm lịch và có thể đánh dấu hoàn tất. Chưa có sửa cả chuỗi lịch hoặc thêm/bớt mục checklist sau khi tạo.
- Xóa metadata và object Storage không có transaction chung. Nếu dọn object thất bại, ứng dụng báo rõ cần dọn tệp còn lại; không âm thầm xác nhận xóa hoàn toàn.
- Nội dung Điều khoản/Chính sách bảo mật và cấu hình nhà phát hành cần được bổ sung trước khi phát hành; checkbox đồng ý hiện chỉ là validation của luồng đăng ký.
