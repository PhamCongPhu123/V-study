# Đăng nhập và đăng ký Vstudy

## Xem giao diện trong Android Studio

Mở đúng thư mục có `pubspec.yaml` và `lib/main.dart`, cập nhật nhánh `android-working`, chạy `flutter pub get`, **Stop app cũ rồi Run lại**. Hot reload không chạy lại `main()` và không cập nhật cấu hình native hoặc `dart-define`.

```powershell
git switch android-working
git pull --ff-only origin android-working
flutter pub get
flutter run -d ID_THIET_BI --dart-define=LIVE_BACKEND=false
```

Ứng dụng mặc định dùng Supabase thật. Lệnh trên chủ động bật bản xem thử và hiển thị form Đăng nhập. Chọn **Đăng ký** để xem form Tạo tài khoản, mở Điều khoản/Chính sách bảo mật hoặc thử kiểm tra nhập liệu và nút hiện mật khẩu. Bản xem thử hiển thị nhãn riêng, không gửi thông tin đến Supabase, không đăng ký hay xác minh tài khoản. Nút **Xem thử ứng dụng** mở dữ liệu mẫu. Để vào thẳng Trang chủ minh họa, thêm `--dart-define=SKIP_AUTH_PREVIEW=true`.

## Kết nối Supabase thật

Thay đổi Auth không cần SQL hoặc Edge Function mới. Dự án Supabase vẫn cần schema Vstudy hiện có để tải Trang chủ sau đăng nhập; trigger tạo `profiles` nằm trong migration ban đầu. Với database đã cài các migration trước, không chạy lại SQL tạo toàn bộ schema.

Tạo `config/dev.json` từ `config/dev.example.json`. Trong PowerShell:

```powershell
Copy-Item config/dev.example.json config/dev.json
```

Điền URL và publishable/anon key của dự án. Ví dụ với dự án đã cung cấp:

```json
{
  "SUPABASE_URL": "https://rigusszvjmlsgdgydjfm.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR_PUBLISHABLE_OR_ANON_KEY",
  "AUTH_REDIRECT_URL": "io.vstudy.app://login-callback/"
}
```

Lấy key trong Supabase Dashboard → **Settings → API Keys**, không dùng ID ở trang JWT Signing Keys. Không điền secret/service role hoặc khóa Gemini vào ứng dụng. `config/dev.json` bị gitignore.

Trong Supabase Dashboard:

1. Vào **Authentication → Sign In / Providers → Email** (một số giao diện đặt là Providers). Bật Email provider, cho phép đăng ký và tắt **Confirm email** để đăng ký không cần xác nhận email. Đặt độ dài mật khẩu tối thiểu 8 ký tự, phù hợp validation hiện tại.
2. Vào **Authentication → URL Configuration → Redirect URLs**, thêm chính xác `io.vstudy.app://login-callback/`. Site URL là địa chỉ web mặc định khi không có redirect; không thay thế danh sách Redirect URLs.
3. Cấu hình SMTP trong mục Email/SMTP nếu cần gửi đến người dùng thật. Dịch vụ gửi email mặc định của Supabase có hạn mức và giới hạn địa chỉ nhận; đăng ký không gửi được có thể do cấu hình này. Kiểm tra Auth Logs và SMTP khi gặp lỗi gửi.
4. Nếu đã tùy chỉnh email template, giữ đường dẫn xác thực theo `{{ .ConfirmationURL }}` cho luồng PKCE này. Template tự chế chỉ gửi token hoặc chỉ chuyển thẳng tới app sẽ cần luồng xử lý khác.

## Kiểm tra khi không đăng ký hoặc đăng nhập được

Supabase Auth tự quản lý tài khoản trong `auth.users`; xem danh sách tại **Authentication → Users**. Bảng `public.profiles` chỉ chứa hồ sơ học tập liên kết theo ID tài khoản. Không tự tạo thêm bảng `users` trong schema `public` để sửa lỗi đăng nhập.

1. Trong Authentication → Users, tìm email đã dùng. Nếu chưa có tài khoản, chọn **Đăng ký** trong app; một địa chỉ email có sẵn không tự trở thành tài khoản Vstudy. Nếu có nhưng chưa xác nhận, mở email xác nhận hoặc dùng nút gửi lại trong app.
2. Kiểm tra Email provider và cho phép đăng ký trong Authentication. Nếu đăng ký báo không gửi được email, kiểm tra SMTP và giới hạn người nhận của dịch vụ email mặc định Supabase.
3. Mở **Logs → Auth** trong Supabase, thử lại một lần và xem lỗi tại thời điểm đó. `invalid_credentials` liên quan thông tin đăng nhập; `email_not_confirmed` yêu cầu xác nhận; lỗi gửi email hoặc `Database error saving new user` cần kiểm tra cấu hình SMTP hoặc trigger hồ sơ. Không đăng nhập trực tiếp vào database bằng mật khẩu ứng dụng.
4. Nếu cần kiểm tra schema, chạy query **chỉ đọc** sau trong SQL Editor. `true` cho biết bảng hoặc trigger tương ứng hiện có; query không tạo hay sửa dữ liệu:

```sql
select
  to_regclass('auth.users') is not null as auth_users_exists,
  to_regclass('public.profiles') is not null as profiles_exists,
  exists (
    select 1
    from pg_trigger t
    where t.tgrelid = to_regclass('auth.users')
      and t.tgname = 'on_auth_user_created'
      and t.tgfoid = to_regprocedure('public.handle_new_user()')
      and not t.tgisinternal
      and t.tgenabled in ('O', 'A')
  ) as profile_trigger_enabled;
```

Nếu `profiles_exists` hoặc `profile_trigger_enabled` là `false`, hãy kiểm tra lịch sử cài schema trước khi sửa; migration ban đầu không được thiết kế chạy lặp trên database đã có dữ liệu. Nếu cần hỗ trợ, chia sẻ kết quả ba cột và **mã lỗi** trong Auth Logs; xóa email, mật khẩu, khóa, token và đường dẫn xác nhận khỏi thông tin gửi đi.

Chạy:

```powershell
flutter run -d ID_THIET_BI --dart-define=LIVE_BACKEND=true --dart-define-from-file=config/dev.json
```

Trong Android Studio → Run → Edit Configurations → cấu hình **Flutter**, Dart entrypoint `lib/main.dart`, đặt **Additional run args**:

```text
--dart-define=LIVE_BACKEND=true --dart-define-from-file=config/dev.json
```

Chọn thiết bị Android rồi Run. Nếu đã có phiên Supabase được lưu, ứng dụng vào thẳng Trang chủ; đăng xuất từ tài khoản để xem lại form đăng nhập.

Android đã có Internet permission và intent filter `io.vstudy.app` / `login-callback`. iOS đã thêm URL scheme `io.vstudy.app` trong `Info.plist`. Cả hai tắt Flutter deep linking mặc định để bộ xử lý Auth nhận liên kết. Build/chạy iPhone native vẫn cần macOS/Xcode và ký ứng dụng; Windows không build iOS trực tiếp.

## Hành vi của các luồng

- **Đăng nhập:** kiểm tra email và mật khẩu, giữ nguyên khoảng trắng trong mật khẩu. Form khóa khi đang gửi. Chỉ Auth event có phiên hợp lệ mới mở ứng dụng; lỗi giữ nội dung và hiển thị thông báo tiếng Việt.
- **Đăng ký:** yêu cầu tên, email, mật khẩu 8–128 ký tự, nhập lại khớp và đồng ý điều khoản. Tên được gửi trong `display_name` để trigger tạo hồ sơ. Khi bật Confirm email, mở màn hình **Kiểm tra email của bạn**; không mở Trang chủ chỉ vì Supabase trả user ID. Khi tắt Confirm email, app đóng phiên tạm do Supabase cấp lúc đăng ký, báo tạo tài khoản thành công và quay về form Đăng nhập với email đã điền. Người dùng đăng nhập bằng mật khẩu để vào Trang chủ.
- **Gửi lại xác nhận:** từ màn hình kiểm tra email hoặc lỗi email chưa xác nhận; sau khi gửi có đếm ngược 60 giây. Server tiếp tục áp dụng hạn mức riêng. Thông báo gửi không khẳng định địa chỉ có tài khoản hoặc thư đã được nhận.
- **Quên mật khẩu:** dùng email đang nhập, gửi liên kết PKCE và phản hồi chung. Mở liên kết hợp lệ vào màn hình đặt mật khẩu mới; đổi thành công có xác nhận trước khi tiếp tục học. Hủy luồng đóng phiên recovery và quay về đăng nhập. Lưu lỗi giữ form để sửa/thử lại.
- **Phiên và callback:** nhận liên kết lúc app đang mở hoặc được khởi động từ email/Google. Chỉ URI đã cấu hình được xử lý; cùng callback ban đầu/foreground chỉ đổi mã một lần. Liên kết lỗi/hết hạn cho thông báo an toàn, không đưa mã xác thực hoặc chi tiết provider lên giao diện. Khi đổi tài khoản/đăng xuất, các route dữ liệu tài khoản trước bị đóng.

PKCE gắn với verifier được lưu trên **thiết bị đã yêu cầu liên kết**. Hãy mở email trên cùng thiết bị và dùng liên kết mới nhất; gửi yêu cầu khác có thể thay verifier trước đó. Nếu xác nhận email ở thiết bị khác, email có thể đã được xác nhận trên server nhưng app không đổi được mã: quay lại đăng nhập bằng mật khẩu. Với đặt lại mật khẩu, yêu cầu liên kết mới trên thiết bị muốn dùng. Không chia sẻ liên kết hoặc dán URL có code/token vào issue.

`detectSessionInUri: false` là chủ ý: `AuthCallbackCoordinator` đảm nhiệm cả initial link và foreground link. Không bật song song bộ xử lý URI của SDK. Custom scheme dùng được cho phát triển; khi phát hành, cấu hình App Links/Universal Links theo domain và đồng bộ `AUTH_REDIRECT_URL`, allowlist Supabase và runner.

## Google

Nút Google đã gọi OAuth qua Supabase và chờ callback; việc mở trình duyệt chưa được coi là đăng nhập thành công. Để dùng thật:

1. Tạo OAuth client loại Web application trong Google Cloud, cấu hình consent screen và test users nếu ứng dụng đang ở chế độ thử nghiệm.
2. Trong Google client, thêm Authorized redirect URI `https://rigusszvjmlsgdgydjfm.supabase.co/auth/v1/callback` (hoặc URL callback đúng của dự án khác).
3. Bật Google provider trong Supabase Authentication, điền client ID/secret tại Dashboard. Giữ app callback `io.vstudy.app://login-callback/` trong Redirect URLs của Supabase.
4. Khởi động lại app với `LIVE_BACKEND=true`, chọn **Tiếp tục với Google**, hoàn tất ở trình duyệt và quay về Vstudy.

Google callback tới Supabase và callback từ Supabase về app là hai URL khác nhau. Không đặt client secret vào Flutter hoặc commit lên GitHub.

## Kiểm chứng

Đã chạy trong môi trường đám mây:

- 4 kiểm thử Python cấu hình Android/iOS: callback runner thực tế trùng config, Flutter deep linking bị tắt, script cấu hình chạy lặp không phá khóa khác.
- Formatter dart_style qua WASM và parser cú pháp cho 73 file Dart; `git diff --check` sạch. Đây không phải kiểm tra kiểu của Dart analyzer.

Đã bổ sung test cho validation dùng chung, Auth adapter với HTTP giả lập, PKCE recovery trước khi UI lắng nghe, thông báo lỗi an toàn, lọc/chống xử lý lặp callback; widget test cho form, consent, liên kết pháp lý, gửi lại email, reset, Google, chống gửi lặp, recovery và preview.

Môi trường đám mây không có Flutter SDK; chưa chạy `flutter analyze`, Dart/widget test, build Android/iOS hoặc so ảnh trên thiết bị. Chưa kiểm tra gửi email/Google thật vì không có cấu hình dịch vụ. Trên máy có Flutter, chạy:

```powershell
flutter pub get
flutter analyze
flutter test test/auth_repository_test.dart test/auth_widget_test.dart
flutter test
```

Kiểm tra thủ công bằng tài khoản thử: đăng ký → mở email trên cùng thiết bị → xác nhận → đăng nhập → đăng xuất → quên mật khẩu → mở email khi app đã đóng → lưu mật khẩu mới → đăng nhập lại. Thử mật khẩu sai, email chưa xác nhận, gửi lặp, mất mạng và liên kết hết hạn. Kiểm tra Google sau khi bật provider; kiểm tra form trên màn hình nhỏ khi bàn phím mở.

Nội dung Điều khoản/Chính sách bảo mật trong app là thông tin cho bản học tập; cần bổ sung thông tin nhà phát hành/kênh hỗ trợ trước khi phát hành. Checkbox hiện kiểm tra luồng đăng ký phía client, chưa là nhật ký đồng ý điều khoản có phiên bản trên server.

## Đăng ký không cần xác nhận email

Trong Supabase Dashboard → Authentication → Sign In / Providers → Email, tắt **Confirm email** và lưu. `supabase/config.toml` đã tắt xác nhận cho môi trường local; sửa file này không tự thay đổi cấu hình dự án hosted. Không cần chạy SQL hoặc deploy Edge Functions cho thay đổi này. Tài khoản cũ chưa xác nhận cần được quản trị viên xác nhận trong Authentication → Users, hoặc dùng tài khoản mới để kiểm tra. Quên mật khẩu vẫn cần email/SMTP để gửi liên kết khôi phục.
