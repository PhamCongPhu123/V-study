# Xác minh Quiz và điều hướng

Thay đổi trên nhánh `android-working` dựa trên sáu frame Quiz người dùng gửi: tổng quan môn học, danh sách chương, bộ đề, câu sai, chi tiết chương và một câu hỏi/lượt làm bài.

## Ranh giới chức năng

- Footer có thứ tự Lịch → Quiz → Trang chủ → Thống kê → Tài liệu. Chat AI mở từ nút tròn vàng có biểu tượng lấp lánh; có navigator riêng và quay lại tab đã mở trước đó.
- Chương và bộ đề đọc từ repository/domain, không có truy vấn Supabase trực tiếp trong widget. Số câu, điểm, tiến độ, bộ đã làm và câu sai tính từ dữ liệu hiện có.
- Chế độ luyện tập gọi RPC kiểm tra từng câu sau khi người dùng chọn và xác nhận đáp án. Thi thử chỉ nhận lời giải sau nộp bài. Hết giờ gửi bài một lần; câu chưa trả lời tính sai.
- Mỗi lượt nộp có UUID ổn định và payload cố định khi retry. Trang kết quả gần đây đọc lại lượt làm cũ, không tự tạo lượt làm mới. Làm lại câu sai dùng feedback luyện tập từng câu, không giả mạo một bài nộp đủ bộ đề.
- Câu sai được tính theo câu trả lời mới nhất. Trả lời đúng khi ôn lại loại câu đó khỏi danh sách cần ôn; sai tiếp vẫn giữ lại.
- Bản mẫu mặc định không gọi Gemini/Supabase; các câu hỏi và kết quả chỉ là dữ liệu minh họa trong bộ nhớ. Backend thật dùng migration mới và Edge Function đã cập nhật.

## Kiểm thử Flutter đã viết, chưa chạy

`test/quiz_flow_widget_test.dart` có sáu trường hợp:

1. Quiz là tab thứ hai; nút AI mở chat độc lập và Back quay lại Quiz.
2. Mở môn/chương, chọn luyện tập, xác nhận từng câu, nhận điểm/lời giải rồi làm lại.
3. Làm lại một câu sai với đáp án đúng loại câu đó khỏi bank nhưng không sinh bài nộp toàn bộ giả.
4. Mở kết quả cũ giữ nguyên số lượt làm.
5. Hết giờ thi thử nộp các câu trống thành sai, đúng một lần.
6. Hết giờ trong khi hộp thoại nộp sớm đang mở sẽ đóng hộp thoại và chấm một lần, không để hộp thoại cũ che kết quả.

`test/navigation_widget_test.dart` được cập nhật theo footer mới và AI ở nút vàng. Fixture `test/use_cases_test.dart` cũng được cập nhật để khớp chữ ký repository mới.

Tổng phần Flutter mới/cập nhật gồm 6 widget test Quiz, 6 widget test điều hướng và 9 unit test nghiệp vụ/mapping trong `test/quiz_learning_test.dart`. Các con số này là số test đã viết, **không phải số test đã chạy đạt**.

Đồng hồ trong kiểm thử được inject qua `QuizPlayerPage.now`; không dùng `tester.pump` để giả định `DateTime.now` sẽ tự tăng. Các kiểm thử widget/domain vẫn cần Flutter SDK để thực thi. Parser cú pháp hoặc đọc source không xác minh kiểu dữ liệu và không thay thế kiểm thử chạy thật.

## Rà soát độc lập

- Phát hiện và sửa fixture override còn chữ ký cũ sau khi thêm metadata Quiz.
- Phát hiện trường hợp deadline xảy ra khi hộp thoại nộp sớm đang mở; player đã được điều chỉnh để không gửi song song/để sót hộp thoại và có test hồi quy.
- Đối chiếu source chính thức Dart 3.9: `firstOrNull` là extension trong `dart:collection`; các file dùng getter này cần import rõ ràng.
- Rà soát private answer keys, lọc owner và ràng buộc sở hữu của chương/quiz/practice trong migration mới. Grading và feedback do RPC xử lý, không lấy khóa đáp án hàng loạt vào client.

Kiểm tra cú pháp bằng parser Dart 3 hiện đọc được 32/32 file `lib/` và `test/`, không phát hiện token thiếu/lỗi cú pháp. Root đã thực thi thành công bộ SQL trên PostgreSQL tạm với 92 assertion và Deno với 25 test (mock fetch), kèm type check/lint/format check. Những kiểm tra này không chạy widget Flutter hoặc Supabase/Gemini thật.

## Chạy trên máy đã có Flutter

```sh
flutter pub get
flutter analyze
flutter test test/quiz_flow_widget_test.dart test/navigation_widget_test.dart
flutter test
flutter build apk --debug
```

Flutter SDK chưa có trong môi trường đám mây này và policy tải SDK chưa được áp dụng. Chưa chạy các lệnh Flutter ở trên, chưa có APK mới hoặc ảnh runtime để khẳng định khớp thiết kế từng pixel. Các kết quả SQL/Deno thực thi được ghi trong báo cáo hoàn tất và log của lệnh tương ứng; không quy đổi chúng thành kết quả widget test.

Với Supabase thật, áp dụng `supabase/migrations/202611030002_quiz_learning.sql` sau migration đầu tiên, rồi deploy lại `generate-quiz`. Không chạy SQL bootstrap kiểm thử lên database Supabase thật.
