# Kiểm tra phần Thống kê

## Trạng thái xác minh

Bộ kiểm thử widget nằm ở `test/statistics_widget_test.dart`. Các ca này dùng kho thống kê trong bộ nhớ độc lập để kiểm tra thao tác lưu rồi tải lại, không cần Supabase hoặc Gemini.

Môi trường đám mây hiện chưa có Flutter/Dart SDK; truy cập nguồn tải SDK chính thức bị chính sách mạng chặn. Vì vậy **chưa chạy `flutter analyze` hoặc `flutter test`** cho thay đổi này. Parser đã đọc được cú pháp của 41/41 tệp trong `lib/` và `test/`; các import nội bộ đều trỏ tới tệp tồn tại. Các kiểm tra này không thay thế phân tích kiểu, biên dịch hay chạy ứng dụng.

Chạy các lệnh sau ở thư mục chứa `pubspec.yaml`, trên máy đã cài Flutter:

```powershell
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d <ma-thiet-bi-Android>
```

Chế độ xem trước mặc định không yêu cầu đăng nhập hoặc khóa Supabase. Có thể dùng điện thoại Android thật qua USB thay cho máy ảo.

## Phạm vi kiểm thử widget

| Luồng | Điều được kiểm tra |
| --- | --- |
| Menu Thống kê | Cả bảy mục mở đúng trang; nút quay lại trở về menu. |
| Footer và AI | Năm biểu tượng vẫn hiện trên các trang chi tiết; nút AI màu vàng mở AI và quay lại đúng trang đang xem. |
| Thời gian học | Chuyển Tuần/Tháng/Học kỳ; chuyển sang tháng trước; chạm ngày có bản ghi 37 phút và đọc số phút của đúng ngày đó. |
| Mục tiêu | Giá trị ngoài giới hạn không được lưu; lưu 600 phút/tuần, 6 ngày học, 30 lượt ôn/ngày và sửa cả hai ngày học kỳ bằng bộ chọn ngày; mở lại biểu mẫu vẫn giữ giá trị. |
| Quiz | “Luyện câu sai” mở trình luyện với các câu sai thực tế; khi không còn câu sai, giữ trang thống kê và hiện thông báo. Chọn môn khác rồi mở khóa học phải giữ đúng môn đã chọn. |
| Tập trung | Không có dữ liệu hiển thị trạng thái chưa ghi nhận; từ chối số phút tập trung vượt dự kiến; lưu 15/25 phút rồi tải lại cho tỷ lệ 60%. Không tạo thêm buổi học. |
| Flashcard | Không có dữ liệu hiển thị trạng thái chưa ghi nhận; lưu 15/20 lượt nhớ đúng cho tỷ lệ 75% và 20 lượt ôn. |
| Báo cáo tuần | Sao chép báo cáo chứa dữ liệu thực và diễn đạt “Chưa có bài nộp” khi không có quiz. |
| Màn hình hẹp | Mở đủ bảy trang với dữ liệu trống ở chiều rộng 320 px; kiểm tra lỗi bố cục và footer. |

Các quy tắc tính toán, ngày tháng và xác thực đầu vào được kiểm thử riêng trong `test/analytics_test.dart`. Các kiểm thử điều hướng và quiz hiện có vẫn cần chạy cùng bộ kiểm thử mới để phát hiện hồi quy.

## Đối chiếu trực tiếp trên điện thoại

1. Chạm biểu tượng biểu đồ ở vị trí thứ tư của footer. Đối chiếu nền vàng nhạt chuyển xanh, thẻ trắng, điểm nhấn xanh đậm/vàng và thứ tự bảy mục với thiết kế.
2. Mở Thống kê học tập. Kiểm tra bảy cột trong tuần, lịch tháng bắt đầu từ thứ Hai và biểu đồ tuần trong học kỳ. Chạm hai ngày khác nhau trên lịch và kiểm tra số phút bên dưới thay đổi theo ngày. Ngày tương lai không được hiển thị hoạt động đã học.
3. Mở Mục tiêu và chuỗi học. Thay cả ba mục tiêu, ngày bắt đầu và ngày kết thúc học kỳ; lưu rồi mở lại. Kiểm tra thông báo khi thời lượng học kỳ nhỏ hơn 7 hoặc lớn hơn 366 ngày. Biểu mẫu bao gồm ngày kết thúc đã chọn; hệ thống lưu mốc loại trừ vào ngày kế tiếp để tính toán nhất quán.
4. Mở Thống kê quiz và Theo môn học. Chọn môn có dữ liệu rồi môn chưa có dữ liệu; kiểm tra số liệu và chương đổi theo môn. Thử các nút luyện câu sai và xem kiến thức để chắc chắn chúng mở trang quiz dùng được.
5. Ghi nhận một phiên tập trung và một lượt ôn flashcard. Kiểm tra danh sách, tổng và tỷ lệ cập nhật ngay. Quay về menu rồi mở lại; dữ liệu phải còn trong cùng phiên xem trước. Bản xem trước giữ dữ liệu trong bộ nhớ, nên dữ liệu mẫu và chỉnh sửa sẽ đặt lại khi khởi động lại ứng dụng.
6. Thử sao chép báo cáo tuần và dán vào ứng dụng ghi chú. Mở AI bằng nút tròn màu vàng từ một trang thống kê; quay lại phải trở về đúng trang đó.
7. Với chế độ Supabase, áp dụng migration thống kê mới trước khi kiểm tra. Đăng nhập hai tài khoản thử nghiệm để xác minh mục tiêu và lịch sử riêng biệt; mở lại ứng dụng để kiểm tra dữ liệu đã lưu qua các phiên đăng nhập.

## Cách đọc số liệu

- Thời gian học lấy từ các buổi học đã ghi nhận. Phiên vượt qua nửa đêm được chia theo ngày địa phương; phần thời gian sau hiện tại bị loại trừ. Lịch dự kiến không tự trở thành thời gian đã học.
- Tuần bắt đầu vào thứ Hai; tháng dùng ngày lịch thực; học kỳ dùng khoảng ngày đã lưu trong mục tiêu. So sánh dùng toàn bộ kỳ trước tương ứng. Kỳ hiện tại chưa kết thúc có thể thấp hơn kỳ trước dù thói quen học không giảm.
- Tỷ lệ tập trung bằng tổng phút tập trung chia tổng phút dự kiến của các phiên đã hoàn thành. Không có phiên thì hiển thị chưa ghi nhận, không suy ra tỷ lệ từ điểm quiz.
- Điểm quiz trung bình là trung bình phần trăm của các bài đã nộp trong kỳ. Không có bài nộp khác với điểm 0%. Độ nắm vững theo chương lấy câu trả lời mới nhất của từng câu tính đến hiện tại và được ghi nhãn là dữ liệu tích lũy.
- Flashcard đếm lượt ôn, không phải số thẻ duy nhất. Tỷ lệ ghi nhớ bằng tổng lượt nhớ đúng chia tổng lượt ôn. Chỉ các lượt đã ghi nhận mới được tính.
- Chuỗi học dựa trên lịch sử buổi học thực tế. Dữ liệu mẫu trong chế độ xem trước chỉ minh họa cách biểu đồ hoạt động.
