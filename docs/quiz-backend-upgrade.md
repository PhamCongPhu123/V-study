# Nâng cấp backend Quiz

Bản mẫu UX/UI không cần Supabase: các môn, chương, câu hỏi và lịch sử minh họa nằm trong bộ nhớ và khôi phục khi chạy lại app. Các bước dưới đây dành cho chế độ backend thật (`LIVE_BACKEND=true`).

## Database đã cài migration ban đầu

Chạy **chỉ** file mới `supabase/migrations/202611030002_quiz_learning.sql` trong SQL Editor của dự án Supabase, hoặc dùng `supabase db push` từ checkout đã link đúng project. Không chạy lại migration `202611030001_vstudy.sql` trên database đã cài.

Migration mới thêm:

- Chương học theo môn, với RLS và khóa ngoại tổng hợp kiểm tra chủ sở hữu.
- Liên kết môn/chương, thời lượng và độ khó cho quiz. Bài nộp có `mode` là `practice` hoặc `exam`, mặc định lịch sử cũ là `practice`. Quiz cũ vẫn giữ nguyên, nhận thời lượng mặc định 30 phút, độ khó trung bình và không gắn môn/chương.
- RPC tạo chương, xem số câu theo chương, phản hồi từng câu luyện tập và xem lại bài đã nộp.
- Ngân hàng câu sai dựa trên đáp án mới nhất của từng câu. Luyện lại đúng loại câu khỏi danh sách; nộp sai lần sau sẽ đưa câu trở lại.
- Nộp bài có thể đánh dấu câu chưa trả lời là sai khi kết thúc bài thi. Chế độ nộp bình thường vẫn yêu cầu trả lời đầy đủ.

Các bảng điểm, đáp án riêng và lịch sử luyện tập không được client ghi trực tiếp. Phản hồi đáp án chỉ trả qua RPC đã kiểm tra quyền của tài khoản. Không có quy trình xóa hoặc viết lại quiz/bài nộp cũ.

## Edge Function

Sau khi migration chạy thành công, deploy lại `generate-quiz`:

```sh
supabase functions deploy generate-quiz
```

Function mới chấp nhận thêm `subject_id`, `chapter_id`, `duration_minutes` (1–180) và `difficulty` (`easy`, `medium`, `hard`). Nó kiểm tra môn/chương thuộc tài khoản trước khi gọi Gemini; chương phải thuộc môn đã chọn. Metadata và câu hỏi được lưu cùng transaction. Function cũ không gửi metadata vẫn dùng được với các giá trị mặc định của migration mới.

## RPC

| RPC | Đầu vào | Kết quả |
|---|---|---|
| `create_quiz_chapter` | `p_subject_id`, `p_title` | Chương mới, vị trí tiếp theo và số câu 0 |
| `list_quiz_chapters` | `p_subject_id` | Các chương và số câu thực tế |
| `check_practice_answer` | `p_quiz_id`, `p_question_id`, `p_selected_option` | Lựa chọn, đáp án đúng và giải thích cho câu đã trả lời |
| `list_wrong_quiz_answers` | `p_subject_id` tùy chọn | Các câu có đáp án mới nhất sai/chưa trả lời |
| `get_quiz_attempt` | `p_attempt_id` | Điểm và toàn bộ review của bài nộp thuộc tài khoản |
| `submit_quiz_attempt` | Tham số cũ, thêm `p_allow_unanswered=false`, `p_mode='practice'` | Chấm phía database, cùng mã bài nộp + cùng đáp án không tạo kết quả trùng |

Câu chưa trả lời được biểu diễn bằng `selected_option=-1` **trong kết quả**. Client gửi object đáp án chỉ với các lựa chọn 0–3, bỏ các câu chưa trả lời; database tự chuẩn hóa khi `p_allow_unanswered=true`. Bộ đếm thời gian trong ứng dụng là công cụ luyện tập phía client, không phải cơ chế giám sát thi độc lập phía server.

## Xác minh đã thực hiện

- `npm test --prefix tools`: **92 SQL assertions đạt**, gồm 52 kiểm tra cũ và 40 kiểm tra mới trên PostgreSQL tạm.
- `deno task check`, `deno task test`: **25 tests đạt** với các dịch vụ HTTP giả lập.
- `deno lint supabase/functions` đạt.

PostgreSQL bootstrap chỉ giả lập schema Auth/Storage; chưa chạy migration hoặc function trên dự án Supabase thật. Không có API key hoặc giá trị bí mật trong các file này.
