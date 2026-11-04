# Thông tin tài khoản

Luồng giao diện theo các frame mới: **Trang chủ → avatar → Thông tin tài khoản → Chỉnh sửa → Cập nhật thành công** và **Thông tin tài khoản → Đăng xuất → Hủy/Đăng xuất**. Footer cùng nút AI vẫn hiện trên các route con. Form tài khoản và form lịch dùng chung `DraftExitScope` để kiểm tra nội dung chưa lưu khi chuyển tab.

## Chạy bản mẫu

Trong thư mục có `pubspec.yaml`, cập nhật `android-working`, chạy `flutter pub get`, dừng app cũ và Run lại `lib/main.dart` trên thiết bị Android. Chạm avatar ở phía trên bên phải Trang chủ. Mặc định không cần Supabase hoặc đăng nhập.

Hồ sơ Tom, email `tom@vstudy.demo` và lịch sử học đều là minh họa. Thay đổi chỉ giữ trong phiên. Đăng xuất mẫu đóng shell và các route con; có thể tiếp tục xem giao diện bằng nút trên màn hình kết thúc. Thao tác này không gọi dịch vụ Auth và không xóa dữ liệu mẫu trong repository của phiên.

## Nâng cấp Supabase thật

Nếu đã có ba migration `202611030001_vstudy.sql`, `202611030002_quiz_learning.sql`, `202611030003_statistics.sql`, chạy **chỉ** migration mới `supabase/migrations/202611040001_account_profile.sql` trong SQL Editor, hoặc dùng `supabase db push` từ checkout đã link đúng project. Dự án mới áp dụng cả bốn migration theo thứ tự. Không chạy lại migration cũ hoặc file trong `supabase/tests/` trên dự án thật.

Migration bổ sung các cột vào bảng `profiles`, giữ dữ liệu hiện có và các policy RLS theo chủ sở hữu:

| Cột | Nội dung / giới hạn |
| --- | --- |
| `class_name` | Tên lớp, tối đa 80 ký tự, có thể để trống |
| `major` | Ngành học, tối đa 120 ký tự, có thể để trống |
| `birth_date` | Ngày lịch, có thể xóa; từ 1900 đến ngày hiện tại của database; không chấp nhận vô hạn |
| `avatar_key` | `student`, `book`, `rocket`, `flower` |
| `dark_profile` | Giao diện tối cho các trang tài khoản, mặc định tắt |
| `study_reminders` | Lựa chọn nhắc học, mặc định bật; chưa kích hoạt thông báo thiết bị |

Client chỉ cập nhật các cột hồ sơ được cấp quyền; không được đổi `id`/`created_at`. Avatar là biểu tượng có sẵn, không dùng URL tùy ý hay bucket công khai. Email và phiên đăng nhập thuộc Supabase Auth, không được sao chép vào các cột hồ sơ mới.

`AccountRepository` tách thao tác lưu chi tiết với lưu cài đặt để các công tắc không ghi đè tên/lớp/ngành/mục tiêu. `StudyRepository.updateProfile` vẫn dùng cho mục tiêu học; bản mẫu giữ toàn bộ trường hồ sơ bổ sung khi cập nhật mục tiêu. Adapter cập nhật kiểm tra bản ghi trả về, không báo thành công khi không có hồ sơ phù hợp hoặc không có quyền.

Khởi động chế độ thật với cấu hình có sẵn:

```sh
flutter run --dart-define=LIVE_BACKEND=true --dart-define-from-file=config/dev.json
```

Không cần khóa Gemini hoặc deploy lại Edge Function cho phần tài khoản. Khi lưu hồ sơ lỗi, form giữ nội dung; khi đăng xuất lỗi, màn hình giữ tài khoản nếu Auth vẫn giữ phiên. Đăng xuất thành công bỏ shell/navigator cũ qua Auth gate; không xóa hồ sơ hoặc dữ liệu học trên server.

## Kiểm chứng

Đã chạy toàn bộ migration và **192 SQL assertions thành công**, gồm 20 kiểm tra tài khoản mới, trên PostgreSQL tạm với Auth/Storage giả lập. Các kiểm tra mới bao gồm RLS giữa hai người dùng, quyền anonymous, giới hạn dữ liệu, xóa ngày sinh, cột bất biến và giữ thông tin khi lưu cài đặt/mục tiêu. Đây không phải kiểm thử Supabase hosted hoặc dịch vụ Auth thật.

Đã định dạng ổn định bằng dart_style WASM, parse cú pháp **53/53 file Dart** trong `lib/` và `test/`, và kiểm tra khoảng trắng bằng `git diff --check`. Môi trường hiện tại chưa có Flutter SDK; chưa chạy `flutter analyze`, widget test hay build Android và chưa đối chiếu bố cục trên thiết bị.

Đã viết `test/account_test.dart` (8 test domain/adapter, bao gồm nhiều dữ liệu đầu vào không hợp lệ) và `test/account_widget_test.dart` (8 widget test): mở avatar/giữ footer, lưu/avatar/thông báo thành công và cập nhật Trang chủ, dữ liệu không hợp lệ/lỗi lưu, rời draft bằng footer, khóa gửi/Back khi đang lưu, lỗi cài đặt, thoát bản mẫu và đăng xuất thật thành công/thất bại với Auth giả lập. **Các Dart/Flutter test này chưa được chạy.**

Trên máy có Flutter SDK:

```sh
flutter pub get
flutter analyze
flutter test test/account_test.dart test/account_widget_test.dart
flutter test test/schedule_editor_widget_test.dart test/auth_widget_test.dart
flutter test
flutter build apk --debug
```

Kiểm tra thêm trên Android: chọn/xóa ngày sinh, chọn avatar, bàn phím và cỡ chữ lớn ở màn hình hẹp, bật/tắt giao diện tối, lưu lỗi mạng và đăng xuất khi dùng Supabase thật. Chế độ tối chỉ áp dụng trang tài khoản/chỉnh sửa/trợ giúp; các trang học tập tiếp tục dùng bảng màu hiện tại.
