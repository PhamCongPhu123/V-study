# Nâng cấp backend Thống kê

Chế độ xem giao diện mặc định dùng dữ liệu minh họa trong bộ nhớ, không cần Supabase hay đăng nhập. Dữ liệu minh họa khôi phục khi khởi động lại ứng dụng. Các bước dưới đây dành cho chế độ backend thật (`LIVE_BACKEND=true`).

## Cài migration mới

Nếu dự án Supabase đã cài hai migration trước, chạy **chỉ** file `supabase/migrations/202611030003_statistics.sql` trong SQL Editor. Có thể dùng `supabase db push` từ checkout đã link đúng project. Với database mới, cài lần lượt `0001`, `0002`, rồi `0003`.

Migration `0003` bổ sung bảng, index, trigger và RPC; không xóa hoặc viết lại dữ liệu học tập/quiz hiện có. Không chạy lại các migration đã cài. Không chạy `supabase/tests/bootstrap.sql` hoặc các file kiểm thử trên dự án Supabase thật: chúng dành riêng cho database tạm.

Không cần deploy lại Edge Function để dùng phần thống kê. Sau khi cài migration, khởi động ứng dụng bằng cấu hình Supabase của bạn:

```sh
flutter run --dart-define=LIVE_BACKEND=true --dart-define-from-file=config/dev.json
```

Chế độ backend thật sử dụng tài khoản đăng nhập để tách dữ liệu từng người. Không đưa `service_role` hoặc Gemini API key vào ứng dụng Flutter.

## Dữ liệu được lưu

| Bảng | Nội dung | Quy tắc chính |
|---|---|---|
| `study_goals` | Một bộ mục tiêu cho mỗi tài khoản | 60–10080 phút/tuần, 1–7 ngày/tuần, 1–1000 lượt ôn flashcard/ngày |
| `focus_sessions` | Phiên tập trung đã hoàn thành | 1–1440 phút dự kiến, phút tập trung từ 0 đến thời lượng dự kiến, 0–1000 lần gián đoạn |
| `flashcard_sessions` | Các lượt ôn và số lượt nhớ được | 1–10000 lượt ôn, số nhớ từ 0 đến số lượt ôn |

Mục tiêu học kỳ lưu bằng ngày (`semester_start`, `semester_end`), với ngày kết thúc không thuộc kỳ. Một kỳ dài 7–366 ngày. `updated_at` do database cập nhật. Khi chưa có bản ghi mục tiêu, ứng dụng dùng mục tiêu mặc định; migration không tự tạo dữ liệu thống kê cho người dùng cũ.

Phiên tập trung và ôn flashcard có thể gắn môn học hoặc để trống. Khóa ngoại tổng hợp ngăn gắn môn của tài khoản khác; xóa môn giữ lại lịch sử và bỏ liên kết môn. Mọi timestamp truyền lên server dùng UTC; ứng dụng hiển thị theo giờ địa phương.

Database kiểm tra độc lập cả thao tác thêm và sửa: thời điểm bắt đầu tập trung không ở tương lai, kết thúc dự kiến không quá giờ server cộng một phút dung sai, và thời điểm ôn flashcard không ở tương lai. Các ngày/thời điểm vô hạn bị từ chối. Những quy tắc này vẫn có hiệu lực khi gọi REST trực tiếp.

Ghi phiên tập trung không tạo thêm `study_sessions`, giúp thời gian học không bị cộng hai lần. Số flashcard là tổng lượt ôn đã ghi nhận, không phải số thẻ duy nhất. Hoàn thành việc học lấy từ checklist lịch học (`event_tasks`), không suy ra từ điểm quiz. Chỉ số chưa có dữ liệu được hiển thị là chưa ghi nhận.

## Quyền truy cập và tiến độ chương

Cả ba bảng mới bật Row Level Security. Tài khoản đăng nhập chỉ đọc, thêm, sửa, xóa dữ liệu có `owner_id` của mình; thay chủ sở hữu hoặc gắn môn khác bị từ chối. Migration thu hồi quyền mặc định trước khi cấp CRUD cụ thể, bao gồm thu hồi `TRUNCATE` vì thao tác này bỏ qua RLS. Vai trò `anon` không được truy cập các bảng này.

RPC `get_chapter_mastery(p_until timestamptz)` trả các trường sau và hỗ trợ phân trang:

| Trường | Ý nghĩa |
|---|---|
| `id`, `subject_id`, `title`, `position` | Chương thuộc tài khoản hiện tại |
| `total_questions` | Số câu hỏi trong các quiz của chương |
| `answered_questions` | Số câu có lựa chọn mới nhất hợp lệ trước hoặc đúng thời điểm chốt |
| `correct_questions` | Số lựa chọn mới nhất đúng, được so sánh bên trong database |

Tiến độ chương dùng lịch sử tích lũy đến `p_until`, khác với điểm trung bình các bài nộp trong một tuần/tháng. Với mỗi câu, sự kiện mới nhất giữa bài nộp và lần luyện tập quyết định tiến độ. Đáp án chưa trả lời (`-1`) trong bài thi không cộng vào số đã trả lời. Nếu hai sự kiện có cùng timestamp, lần luyện tập được ưu tiên; UUID phân xử các sự kiện cùng loại. Chương chưa có câu hoặc chưa được luyện vẫn xuất hiện với số đếm 0.

RPC yêu cầu tài khoản đăng nhập và thời điểm chốt hữu hạn. Thời điểm chốt ở tương lai được giới hạn về giờ server. Nó chỉ trả bảy trường tổng hợp, không trả đáp án, lời giải hay dữ liệu của người khác. Quyền trực tiếp vào `quiz_answer_keys` và `quiz_practice_answers` vẫn bị chặn.

## Kiểm tra đã thực hiện

```sh
npm ci --prefix tools
npm test --prefix tools
```

Kết quả chạy thật: **172 SQL assertions đạt**, gồm 92 kiểm tra Auth/Quiz trước đó và 80 kiểm tra thống kê mới. Bộ kiểm tra tạo PostgreSQL tạm, áp dụng cả ba migration, rồi kiểm tra chủ sở hữu, CRUD/RLS, quyền `TRUNCATE`, giới hạn dữ liệu, thời gian tương lai, thời điểm chốt, đáp án mới nhất và việc không rò rỉ khóa đáp án.

Auth/Storage trong PostgreSQL tạm là test doubles. Chưa áp dụng migration này lên dự án Supabase thật và chưa kiểm tra ứng dụng Flutter bằng kết nối Supabase thật trong môi trường này.
