# Xác minh giao diện trên nhánh android-working

Phần chỉnh sửa dựa trên ảnh thiết kế trang chủ và ba chế độ lịch do người dùng gửi. Footer chung theo thứ tự Lịch → Hỏi đáp → Trang chủ → Thống kê → Tài liệu. Màn hình Quiz và hội thoại mở trong navigator của tab, để footer vẫn tồn tại khi chuyển trang con.

## Đã kiểm tra trong môi trường hiện tại

- Đã đọc nhánh `android-working`, bao gồm runner Android/iOS/web do người dùng tạo, thay vì thay bằng nhánh `main` có lịch sử khác.
- Đã rà soát luồng điều hướng: mở ở Trang chủ, từng tab có navigator riêng, nhấn biểu tượng nhà quay về root Trang chủ, các trang con dùng navigator gần nhất.
- Đã rà soát các API Flutter dùng trong footer/shell so với yêu cầu Flutter tối thiểu 3.35 của project. Footer không phụ thuộc vào package ngoài.
- Parser Dart 3 có sẵn trong môi trường đã đọc source mới, không phát hiện lỗi cú pháp tại lần kiểm tra. Đây là kiểm tra cú pháp, không phải Dart analyzer hoặc kiểm thử hiển thị.

## Kiểm thử được bổ sung, chưa thực thi

`test/navigation_widget_test.dart` kiểm tra:

1. Entrypoint mặc định mở bản mẫu khi chưa cấu hình Supabase hoặc đăng nhập.
2. Thứ tự năm biểu tượng và điều hướng đến đúng loại trang.
3. Footer tồn tại qua trang danh sách quiz/làm quiz; nhấn nhà sau khi chuyển tab quay về Trang chủ thật.
4. Chuyển lịch ngày/tuần/tháng vẫn giữ footer.
5. Footer tồn tại qua hội thoại AI và trang tài liệu mở từ AI; nút Back hệ thống đóng route con trước khi về Trang chủ.
6. Mỗi tab ở chiều rộng 320 px không phát sinh exception bố cục khi chạy widget test.

Flutter/Dart SDK chưa được cài trong máy đám mây này. Live network policy vẫn chưa áp dụng domain tải SDK đã lưu trong draft trước đó, nên không lặp lại yêu cầu tải đã bị chặn và không thử đường đi khác để vượt policy. Vì vậy các widget test, `flutter analyze`, build APK và đối chiếu ảnh chụp runtime **chưa được chạy**; không tính các bài kiểm thử này là đã đạt.

## Kiểm tra trên máy phát triển có Flutter

```sh
flutter pub get
flutter analyze
flutter test test/navigation_widget_test.dart
flutter test
flutter build apk --debug
```

Để kiểm tra trực quan trên Android thật hoặc máy giả lập, chạy `flutter run -d ID_THIET_BI`. Bản mẫu không yêu cầu khóa Supabase. Kiểm tra thêm các kích thước màn hình 320, 402 và 430 px, thao tác thêm/sửa/xóa lịch, chuyển tháng qua giao năm, lịch có sự kiện qua nửa đêm và mục checklist. Chỉ khi chạy các bước này mới có thể xác nhận độ chính xác hiển thị so với ảnh mẫu trên thiết bị.
