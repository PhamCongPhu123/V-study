# Xác minh luồng thêm/sửa/xóa lịch

Phần giao diện dựa trên ba frame người dùng gửi: form lịch trình, hộp xác nhận xóa và hộp xác nhận tạo lịch. Form là route nằm trong navigator của tab Lịch; footer và nút AI vàng thuộc shell nên vẫn hiện.

## Kiểm thử được viết

`test/schedule_editor_widget_test.dart` sử dụng repository bộ nhớ có ghi nhận số lần gọi, dữ liệu draft và một cổng Future có thể trì hoãn. Các test kiểm tra hành vi quan sát được, không chỉ sự tồn tại của widget:

1. Mở form từ lịch vẫn giữ đủ năm nút footer và nút AI.
2. Tên rỗng bị chặn trước modal xác nhận và trước mọi lệnh ghi.
3. Hủy xác nhận tạo giữ nguyên draft; xác nhận tạo gửi đúng dữ liệu deadline, địa điểm và ngày, đúng một lần.
4. Đóng draft đã sửa cần xác nhận; hủy tiếp tục nhập; xác nhận bỏ draft không xóa bản ghi đã lưu nào.
5. Form mới chưa sửa đóng ngay, không xuất hiện modal hoặc gọi API.
6. Khi đang chờ lưu, nút lưu bị vô hiệu hóa và nút Back hệ thống không đóng route; hoàn tất mới quay lại.
7. Lưu lỗi giữ nội dung và cho phép người dùng xác nhận thử lại; không tạo hai bản ghi khi lần đầu thất bại.
8. Sửa một occurrence không tạo lại chuỗi, không thay ID/trạng thái checklist và giữ reminder.
9. Hủy xóa không thay đổi dữ liệu; xác nhận chỉ xóa occurrence được chọn, giữ các occurrence khác.
10. Chuyển tab bằng footer khi có draft chưa lưu cần xác nhận; hủy vẫn giữ draft trong editor.
11. Lịch tự học lặp hằng tuần chặn số tuần không hợp lệ, tạo một chuỗi với checklist riêng cho từng buổi; đổi qua Deadline rồi về Môn học vẫn giữ lựa chọn Tự học.
12. Back hệ thống ở hộp xác nhận tạo chỉ đóng hộp thoại, giữ draft và không lưu.
13. Mở AI rồi quay lại giữ nguyên form chưa lưu, không gửi lệnh ghi lịch.
14. Bấm nhanh hai lần nút xác nhận chỉ lưu một lần và không đóng nhầm trang bên dưới.

`test/study_mutations_test.dart` kiểm tra adapter bằng HTTP giả lập: RPC tạo chuỗi, timestamp UTC, lọc chủ sở hữu, ID checklist, bản ghi không tồn tại/không có quyền và lỗi đọc checklist sau khi RPC đã xác nhận tạo thành công. Nếu lần đọc tiếp theo thất bại, adapter trả các lịch đã được RPC xác nhận để tránh mời người dùng tạo trùng. Test này không thay thế tích hợp Supabase thật.

## Phạm vi xác minh

Flutter/Dart SDK chưa có trong máy đám mây hiện tại. Các widget test trên **chưa được chạy**. Kiểm tra cú pháp bằng parser hoặc định dạng bằng dart_style không xác minh kiểu Flutter, bố cục thực tế, bàn phím, date/time picker hoặc tích hợp API. Không xem chúng là kết quả Flutter test đạt.

Đã định dạng ổn định bằng dart_style qua WASM, parse cú pháp 46/46 file Dart trong `lib/` và `test/`, và kiểm tra `git diff --check` không có lỗi khoảng trắng. 14 widget test và 9 test adapter mới đều cần chạy bằng Flutter SDK trên máy phát triển.

Trên máy đã cài Flutter, chạy từ thư mục chứa `pubspec.yaml`:

```sh
flutter pub get
flutter analyze
flutter test test/schedule_editor_widget_test.dart
flutter test test/study_mutations_test.dart
flutter test
flutter build apk --debug
```

Kiểm tra thêm trực tiếp trên Android: chọn ngày/giờ, lịch qua nửa đêm, deadline và lịch tự học; chuyển tab hoặc mở AI khi có draft; thử bàn phím ở màn hình hẹp và tăng cỡ chữ. Với backend thật, kiểm tra RLS/khóa ngoại và lỗi mạng khi lưu. Bản mẫu trong bộ nhớ không chứng minh endpoint Supabase đã hoạt động.

Hủy nội dung của form mới là thao tác bỏ draft, không phải xóa lịch đã lưu. Lịch lặp khi chỉnh sửa/xóa chỉ tác động một occurrence. Reminder được lưu cùng lịch, chưa chứng minh thông báo hệ điều hành đã được hẹn.

Không có migration mới trong thay đổi này. Nếu kết nối bị mất trước khi client nhận phản hồi của RPC tạo, trạng thái commit có thể chưa rõ; hiện chưa có mã idempotency cho lịch. Người dùng nên tải lại lịch để kiểm tra trước khi tạo lại. Việc khóa nút gửi ngăn thao tác lặp trong form, không bảo đảm chống trùng cho mọi tình huống mất mạng.
