# Xác minh ngày 03/11/2026

Đã thực hiện trong môi trường đám mây hiện tại:

- PostgreSQL 18.6: migration chạy trên cluster tạm và **52 assertion SQL đạt**. Gồm tạo profile từ email/Google metadata, RLS giữa hai tài khoản, khóa ngoại ownership, Storage policies, thu hồi quyền rộng mặc định, private quiz answer keys, chống giả mạo điểm/chat, nộp bài đủ câu, retry idempotent, transaction lịch lặp/checklist/chat/quiz và quota/lease AI.
- Deno 2.9.6: type check hai Edge Functions và **22 tests đạt** với fetch giả lập; kiểm tra xác thực, từ chối đầu vào/path, quyền tài liệu, thứ tự hội thoại, timeout, lỗi Gemini, không lưu nửa lượt chat, JSON quiz và không trả khóa đáp án.
- Python 3.12: **2 tests đạt** cho cấu hình callback Android/iOS lặp lại an toàn và giữ cấu hình có sẵn.
- Kiểm tra cú pháp Bash cho `scripts/bootstrap_flutter.sh` đạt.
- Parser cú pháp Dart 3 kiểm tra 22 file trong `lib/` và `test/`: không có lỗi cú pháp hoặc token thiếu. Đây **không phải** Dart analyzer và không xác minh kiểu dữ liệu, liên kết dependency hay hành vi widget.

Chưa thực hiện:

- `flutter pub get`, `flutter analyze`, `flutter test`, chạy app hoặc build APK/iOS. Flutter SDK chưa có; tải chính thức từ `storage.googleapis.com` bị policy mạng chặn. Domain đã được lưu trong bản nháp cấu hình môi trường, chưa có bằng chứng đã áp dụng/publish. Các unit/widget test Dart đã được viết, **chưa được tính là đạt**.
- Chưa sinh runner Android/iOS bằng Flutter SDK; chạy `scripts/bootstrap_flutter.sh` khi đã có SDK.
- Chưa chạy Supabase local hoàn chỉnh, migration trên Supabase hosted, email xác nhận, Google OAuth, Storage HTTP hoặc Gemini thật. Cần cấu hình một dự án Supabase và Gemini API key. Không có khóa bí mật trong repository.

PostgreSQL bootstrap dùng schema auth/storage tối thiểu để kiểm chứng SQL, không mô phỏng toàn bộ dịch vụ Supabase. Kết quả kiểm thử giả lập không đồng nghĩa ứng dụng đã chạy end-to-end trên thiết bị.

Đã lưu bản nháp môi trường gồm `install_script` (cài công cụ kiểm thử), `start_skill` (lệnh kiểm tra và các bước còn thiếu), cùng custom network domains `storage.googleapis.com` và `generativelanguage.googleapis.com`. Lưu bản nháp không chạy script, không áp dụng mạng và không publish. Muốn dùng thay đổi này cho các phiên sau, xem lại và lưu trong Environment Settings rồi Publish. Không có khóa API nào được lưu trong bản nháp này.
