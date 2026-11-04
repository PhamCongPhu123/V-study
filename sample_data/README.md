# Dữ liệu khởi tạo đầy đủ cho tài khoản Vstudy

Mở `supabase/scripts/seed_account_full.sql` trên nhánh `android-working`, sao chép toàn bộ vào Supabase SQL Editor (role postgres). Thay `CHANGE_ME@example.com` trong biến `v_email` bằng email tài khoản đã có trong Authentication → Users, rồi Run.

Cần các migration Vstudy hiện có. File không tạo tài khoản, không sửa mật khẩu, không xóa dữ liệu và không mở quyền truy cập của tài khoản khác. Có thể chạy lại mà không tạo trùng. Dữ liệu khởi tạo trước đó được giữ; các nhãn `[MẪU]` của bộ nhỏ được bỏ như yêu cầu trước.

Bộ mở rộng thêm:

- Tổng cộng 5 môn: Toán học, Thiết kế UX/UI, Triết học Mác–Lênin, Pháp luật đại cương, Quản trị dự án. Hai môn Toán/UX của bộ nhỏ được dùng lại.
- 3 chương mỗi môn, 30 bộ Quiz mới, mỗi bộ 5 câu. Ngân hàng gồm 50 câu kiến thức nền tảng; các bộ chọn và sắp xếp lại câu/đáp án, không phải 150 câu độc lập.
- 60 lượt làm bài khởi tạo, có luyện tập/thi thử và câu sai. Điểm được tính bằng RPC chấm bài, không gán điểm bất kỳ.
- 112 lịch cho 8 tuần quanh ngày chạy đầu tiên, có lịch lớp/tự học/deadline và 160 mục cần chuẩn bị.
- 155 phiên học, 90 phiên tập trung và 155 lượt ôn flashcard trong 180 ngày trước khi chạy lần đầu; thêm một hoạt động gần hiện tại cho mỗi loại để Trang chủ có tiến độ.
- 3 hội thoại khởi tạo với nội dung ôn tập. Tin nhắn đầu nói rõ đây là nội dung có sẵn, chưa gọi dịch vụ AI.

Nếu đã chạy bộ nhỏ trước, tổng thường là 5 môn, 15 chương, 31 Quiz, 153 câu, 120 lịch, 163 phiên học, 94 phiên tập trung và 159 lượt ôn flashcard. Dữ liệu bạn đã tự thêm làm tổng số lớn hơn. Chạy lại không dịch chuyển ngày của dữ liệu đã tạo; có thể xem các khoảng thời gian trước trên Lịch và Thống kê.

Lịch sử và kết quả khởi tạo sẽ được tính vào Thống kê. Tên/mục tiêu phút học của hồ sơ hiện có được giữ. Để biểu đồ học kỳ hiện đủ lịch sử, `v_update_semester=true` đặt kỳ theo dõi về 180 ngày gần nhất; đổi thành `false` nếu muốn giữ nguyên ngày học kỳ đang có. Không thay đổi mục tiêu tuần đã lưu.

## Tài liệu thật

Tải `sample_data/vstudy-documents.zip` bằng nút Download raw file trên GitHub rồi giải nén. Có 5 tệp TXT UTF-8 chứa ghi chú học tập cơ bản do dự án chuẩn bị, không phải giáo trình chính thức.

Trong app → Tài liệu → Tải lên, chọn lần lượt các tệp, rồi menu tài liệu → Phân môn học để gắn vào môn tương ứng. Có thể đọc, tải xuống, lưu ngoại tuyến, yêu thích và gửi cho Vstudy Ai để tạo tóm tắt/Quiz thật. SQL không thể thay việc tải bytes lên Supabase Storage, nên không chèn các bản ghi tài liệu không có tệp.

Sau khi chạy SQL, mở lại các tab hoặc đăng xuất/đăng nhập lại. Không cần build lại ứng dụng chỉ để cập nhật dữ liệu Supabase. Không cần deploy lại Edge Functions cho bộ dữ liệu này.

## Kiểm chứng

Đã chạy trên PostgreSQL tạm với toàn bộ migrations, cả bộ nhỏ và bộ lớn, rồi chạy lại bộ lớn: số lượng không tăng trùng; dữ liệu tài khoản khác không đổi; hồ sơ hiện có giữ nguyên; điểm khớp đáp án; ngân hàng câu sai và tổng hợp chương có dữ liệu. Chưa chạy file trên dự án Supabase thật của người dùng.
