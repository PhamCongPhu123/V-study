# AI backend

Hai Edge Functions chạy trên Supabase, xác thực access token của tài khoản bằng Auth API trước khi
truy vấn dữ liệu. Không gọi Gemini từ Flutter.

## Cấu hình và triển khai

Áp dụng migration trước. Supabase tự cung cấp `SUPABASE_URL`, `SUPABASE_ANON_KEY` và
`SUPABASE_SERVICE_ROLE_KEY` trong Edge Runtime. Cấu hình riêng `GEMINI_API_KEY` bằng Supabase
Dashboard → Edge Functions → Secrets; không ghi khóa vào repository. `GEMINI_MODEL` không bắt buộc,
mặc định `gemini-2.5-flash`.

```sh
supabase functions deploy ai-chat
supabase functions deploy generate-quiz
```

Theo config.toml, gateway bỏ xác minh JWT kiểu cũ; **bên trong mỗi function vẫn bắt buộc gọi Auth
getUser**. Điều này hỗ trợ access token ký bất đối xứng của Supabase. Không thay bằng việc decode
JWT mà không xác minh.

## Request/response

Header: `Authorization: Bearer <access token của người dùng>`, `Content-Type: application/json`.
Không truyền service role từ ứng dụng.

`POST /functions/v1/ai-chat`:

```json
{ "message": "Giải thích đạo hàm bằng ví dụ", "mode": "qa", "document_id": null, "thread_id": null }
```

Chế độ: `qa`, `summary`, `plan`, `flashcards`. Response gồm `thread_id`, `user_message` và
`assistant_message` là các hàng dữ liệu đã lưu. Khi tiếp tục hội thoại, gửi `thread_id`; tài liệu và
chế độ cố định theo hội thoại. Tạo hội thoại mới khi đổi chúng. Lộ trình học là gợi ý bằng văn bản,
chưa tự ghi vào lịch. Không cam kết số trang AI trích dẫn đã được kiểm chứng.

`POST /functions/v1/generate-quiz`:

```json
{
  "title": "Ôn tập đạo hàm",
  "topic": "Đạo hàm hàm đa thức",
  "question_count": 5,
  "document_id": null
}
```

Response: `{"quiz_id":"UUID"}`. Đọc câu hỏi từ `quiz_questions`; đáp án đúng được giữ trong bảng
riêng không có quyền truy cập từ client. Nộp đầy đủ câu trả lời qua RPC `submit_quiz_attempt` để
được chấm điểm và xem giải thích.

## Giới hạn

- Request JSON tối đa 16 KiB; tin nhắn tối đa 8.000 ký tự; chủ đề quiz tối đa 2.000 ký tự.
- Mỗi quiz có 1–30 câu; cấu trúc, lựa chọn, đáp án và số lượng được kiểm tra trước khi lưu.
- Tối đa 30 yêu cầu AI/phút/tài khoản, kiểm soát bằng PostgreSQL để áp dụng qua nhiều Edge isolate.
  Mỗi hội thoại/tài liệu chỉ xử lý một yêu cầu cùng scope tại một thời điểm; yêu cầu mới không có
  resource cũng được tuần tự hóa theo tài khoản và scope.
- Lease hết hạn sau 120 giây để phục hồi khi function bị dừng. Gemini timeout 60 giây.
- Lịch sử tối đa 20 tin nhắn và 40.000 ký tự. Tài liệu private PDF/TXT tối đa 10 MiB; TXT phải UTF-8
  và không quá 60.000 ký tự. PDF gửi trực tiếp dưới dạng inline data; chưa có pipeline OCR hoặc lập
  chỉ mục tìm kiếm.
- HTTP 401: phiên hết hạn; 404: tài liệu/hội thoại không thuộc tài khoản; 409: yêu cầu đang xử lý
  hoặc đổi context; 429: hạn mức; 502/504: lỗi/timeout AI; 503: cấu hình/database.
- Rate limit theo tài khoản không thay thế hạn mức chi phí của nhà cung cấp. Thiết lập hạn mức và
  cảnh báo Gemini trong Google AI Studio trước khi mở ứng dụng công khai.

## Kiểm thử

```sh
deno task check
deno task test
deno lint supabase/functions
```

Tests chạy 22 tình huống với fetch được tiêm phụ thuộc: xác thực, ownership, lỗi AI,
quota/concurrency, giới hạn payload/tài liệu, chặn traversal, schema quiz, giữ kín đáp án, thứ tự
lịch sử, và không lưu nửa lượt chat. Các tests này không gọi Supabase/Gemini thật; kiểm thử tích hợp
live cần project và khóa riêng của bạn.
