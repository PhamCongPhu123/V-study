# Vstudy

Ứng dụng Flutter hỗ trợ học tập, tổ chức theo **Clean Architecture**, dùng **Supabase** (Auth, PostgreSQL, Storage, Edge Functions) và **Gemini API** ở phía máy chủ.

## Xem bản mẫu UX/UI không cần đăng nhập

Mặc định ứng dụng mở thẳng trang chủ và các tab Lịch, Quiz, AI, Thống kê với dữ liệu minh họa. Không cần Supabase, Gemini API key hay tài khoản. Thay đổi chỉ giữ trong phiên chạy, khởi động lại sẽ khôi phục dữ liệu mẫu. Chat/quiz dùng nội dung minh họa được ghi rõ, không gọi AI thật hoặc phân tích tài liệu.

Để xem nhanh trên Chrome (đã có thư mục `web/`):

```sh
flutter pub get
flutter run -d chrome
```

Trên thiết bị Android đã được cấu hình, chạy `flutter run -d ID_THIET_BI`. Không cần `config/dev.json` ở chế độ bản mẫu.

Để dùng backend thật và luồng xác thực cũ, thêm `--dart-define=LIVE_BACKEND=true` cùng cấu hình Supabase như hướng dẫn bên dưới. Bản mẫu không thay đổi RLS hoặc cấp quyền truy cập dữ liệu thật khi chưa đăng nhập.

**Thiết kế Figma mới:** file `GK-test-2` đã được cung cấp nhưng chưa đọc được trong phiên triển khai này. Phần hiện tại chỉ chuẩn bị chế độ xem không đăng nhập; chưa xác nhận màu sắc/bố cục khớp template mới.

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

Cần Flutter stable **>=3.35**, Dart **>=3.9**, Android SDK để chạy Android; iOS cần macOS/Xcode. Backend có thể dùng Supabase hosted hoặc Supabase CLI + Docker để chạy cục bộ.

Với dự án Supabase **mới dành cho Vstudy**, chạy từ thư mục repository:

```sh
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

Lệnh `db push` áp dụng migration thật. Đọc migration trước khi chạy trên database đã có dữ liệu. Không chạy `supabase/tests/bootstrap.sql` trên Supabase; đó là schema giả lập chỉ dùng cho kiểm thử PostgreSQL trống.

Trong Supabase Dashboard:

- Bật Email Auth, yêu cầu xác nhận email và mật khẩu tối thiểu 8 ký tự. Cấu hình SMTP để gửi email thật.
- Thêm `io.vstudy.app://login-callback/` vào Auth → URL Configuration → Redirect URLs.
- Nếu dùng Google: cấu hình Google provider và client ID/secret trong Supabase. Google OAuth cần callback `https://YOUR_PROJECT.supabase.co/auth/v1/callback`; ứng dụng nhận kết quả qua URI ở trên.
- Bật Gemini API cho khóa của bạn. Không đưa khóa Gemini hoặc Supabase service role vào Flutter.

Tạo `supabase/functions/.env` từ `.env.example`, nhập khóa Gemini **trên máy của bạn** hoặc dùng Supabase Dashboard → Edge Function Secrets. File `.env` đã được gitignore.

```sh
supabase secrets set --env-file supabase/functions/.env
supabase functions deploy ai-chat
supabase functions deploy generate-quiz
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` được Supabase cấp cho Edge runtime. Hai function tự xác thực access token bằng Auth API; cấu hình `verify_jwt = false` không bỏ bước xác thực này. Mô hình mặc định `gemini-2.5-flash`; đổi `GEMINI_MODEL` trong secrets nếu tài khoản của bạn dùng mô hình khác.

## Chạy Flutter

Repository ban đầu trống và chỉ nhận các file thiết kế Dart, nên chưa có runner Android/iOS. Script tạo **chỉ các thư mục runner còn thiếu**, giữ nguyên mã ứng dụng và thêm callback auth/Internet permission:

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
