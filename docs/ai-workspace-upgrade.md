# Nâng cấp trợ lý AI

Luồng mới dùng chung footer của shell và mở từ nút AI vàng:

1. Trang công cụ → hỏi đáp tài liệu hoặc hỏi đáp chung → hội thoại, gợi ý câu hỏi, sao chép và lịch sử.
2. Trang công cụ → thư viện tóm tắt → chọn 1–3 tài liệu → Ngắn gọn / Chi tiết / Sơ đồ, từ khóa, đánh giá.
3. Trang công cụ → tạo đề ôn → nguồn tài liệu/chủ đề, 10/20/30/40 câu, độ khó và dạng câu → quiz có chấm điểm hoặc đề tự luyện.

## Xem bản mẫu

Cập nhật nhánh `android-working`, chạy `flutter pub get`, dừng app cũ và Run lại `lib/main.dart`. Không cần SQL, tài khoản hoặc khóa API để xem giao diện. Nút vàng mở trợ lý AI từ bất kỳ tab nào; footer vẫn hiện trên thư viện, bản tóm tắt, trang câu hỏi và hội thoại.

Các tệp Giải tích và kết quả trong bản mẫu là minh họa. Chọn/tải tệp trong bản mẫu chỉ tạo metadata trong bộ nhớ, không gửi nội dung cho Gemini. Bản tóm tắt mẫu không được suy ra từ tệp tải lên. Dữ liệu thay đổi mất khi khởi động lại ứng dụng.

## Backend thật

Áp dụng bốn migration trước (`202611030001_vstudy.sql`, `202611030002_quiz_learning.sql`, `202611030003_statistics.sql`, `202611040001_account_profile.sql`), sau đó chạy **chỉ** migration mới `supabase/migrations/202611040002_ai_workspace.sql` trong SQL Editor. Nếu dùng Supabase CLI với lịch sử migration đã đồng bộ, có thể chạy `supabase db push` từ checkout đã link đúng project. Không chạy lại các migration đã cài hoặc file kiểm thử trên dự án thật.

Migration mới thêm `ai_artifacts`, gợi ý `quiz_questions.hint`, RPC lưu kết quả AI nguyên tử và mở giới hạn database lên 40 câu/vị trí 0–39. Ràng buộc cũ về số lượng/vị trí câu hỏi được thay bằng giới hạn mới; dữ liệu hiện có được giữ. Quyền chấm quiz và quyền đọc đáp án gốc tiếp tục tách khỏi client.

Từ thư mục đã link đúng dự án Supabase:

```sh
supabase functions deploy study-assistant
supabase functions deploy generate-quiz
```

Function mới dùng lại các secrets `GEMINI_API_KEY` và tùy chọn `GEMINI_MODEL` có sẵn; Supabase cấp URL/anon/service-role cho Edge runtime. Không thêm khóa Gemini hoặc service role vào Flutter. Nếu cần cấu hình secrets lần đầu, dùng quy trình ở README hoặc Dashboard Edge Function Secrets. Không cần đổi hợp đồng `ai-chat` để dùng UI hỏi đáp mới; có thể deploy lại function đó để đồng bộ code backend trong nhánh.

Chạy ứng dụng với cấu hình thật đã chuẩn bị:

```sh
flutter run --dart-define=LIVE_BACKEND=true --dart-define-from-file=config/dev.json
```

## Hợp đồng chức năng

`AiWorkspaceRepository` ở domain có adapter Supabase và bản mẫu trong bộ nhớ. Use case chuẩn hóa tiêu đề/chủ đề, kiểm tra số câu, dạng câu và số tài liệu. UI không giữ service key và không tự ghi điểm.

`study-assistant` xác thực JWT thật qua Auth API, chỉ đọc tài liệu theo **ID + chủ sở hữu**, kiểm tra đường dẫn Storage, MIME, kích thước thực tế và UTF-8/PDF trước khi gọi Gemini. Một yêu cầu chọn tối đa 3 PDF/TXT và tổng nội dung tối đa 10 MiB; DOCX/PPTX chưa được hỗ trợ. Không tạo số trang minh họa hoặc trích dẫn đã kiểm chứng. Bộ lọc trong thư viện dùng MIME thực tế thay cho môn học chưa được gắn với tài liệu.

| Loại | Nội dung lưu | Hành vi |
| --- | --- | --- |
| `summary` | Ý chính, nhóm kiến thức, từ khóa, các nhánh sơ đồ | Cả ba tab được tạo từ một phản hồi JSON đã kiểm tra; đổi tab không gọi lại AI |
| `worksheet` | Trắc nghiệm/đúng-sai/tự luận với gợi ý, lời giải, đáp án mẫu | Tự luyện, câu trả lời chỉ giữ trong route hiện tại; không ghi điểm hoặc giả vờ đã chấm tự luận |
| `quiz` | Liên kết tới quiz chính thức; `content` rỗng | Đáp án nằm trong bảng khóa riêng; bài thi dùng RPC chấm điểm và lịch sử/thống kê hiện có |

Sơ đồ tóm tắt là cây các nhánh kiến thức, không phải ảnh hoặc bản đồ có kéo thả. Ngôn ngữ là tiếng Việt. Gợi ý AI dành cho học tập và cần được đối chiếu như các nội dung AI khác. Tài liệu được gửi tới Gemini khi người dùng gửi câu hỏi hoặc tạo nội dung với nguồn đã chọn.

Nguồn của kết quả đã tạo được lưu bằng ID và tên tại thời điểm tạo. Xóa tài liệu gốc không tự xóa bản tóm tắt đã lưu. Xóa một mục lịch sử AI không xóa quiz của nó; xóa quiz ở phía quản trị sẽ xóa mục lịch sử AI liên kết qua khóa ngoại.

## Retry, quyền truy cập và dữ liệu chưa gửi

Mỗi lần tạo nội dung mới có UUID `request_id` và fingerprint do server tính từ đầu vào chuẩn hóa. Client giữ cùng UUID khi thử lại yêu cầu chưa xác nhận; đổi đầu vào tạo UUID mới. Server kiểm tra kết quả đã lưu trước khi gọi mô hình. RPC khóa theo UUID, kiểm tra owner/fingerprint và lưu quiz + mục lịch sử trong cùng transaction. Retry sau một lần lưu thành công trả kết quả cũ, không thêm quiz mới. Quy tắc này áp dụng cho công cụ tạo nội dung mới; không phải hợp đồng idempotency mới của chat thông thường.

Các function dùng chung quota/lease AI hiện có. Phản hồi sai schema, thiếu câu, trùng câu, lựa chọn/đáp án không hợp lệ hoặc thiếu một dạng câu đã chọn bị từ chối trước khi lưu. Khi Gemini hoặc mạng lỗi, form giữ dữ liệu và nút thử lại dùng mã yêu cầu đã giữ. Trường hợp mô hình phản hồi quá chậm/truncated vẫn có thể phải thử lại.

`ai_artifacts` bật RLS; người dùng chỉ đọc/xóa bản ghi của mình, chỉ cập nhật cột `feedback` với giá trị 1/-1/null. Không có quyền client để thêm nội dung AI, đổi owner, sửa nội dung, đổi quiz hoặc TRUNCATE. RPC tạo nội dung chỉ cấp cho service role; danh tính owner lấy từ JWT đã xác thực, không lấy từ body. Fingerprint không cấp quyền truy cập kết quả của người khác.

Khi đang gửi chat/tạo nội dung, nút gửi và Back trong route đó bị khóa. Chuyển footer giữ route AI trong shell để có thể quay lại. Câu hỏi từ Quiz mở thêm một hội thoại với nội dung điền sẵn, giữ bản nháp trước đó và không tự gọi Gemini. Đóng bản nháp chat hoặc lượt tự luyện đang trả lời có hộp xác nhận. Chat tiếp tục dùng lưu hai tin nhắn nguyên tử của `ai-chat`; nếu mất phản hồi sau khi server đã lưu, nên tải lại lịch sử trước khi gửi lại thủ công.

## Kết quả kiểm chứng

- **221 SQL assertions thành công** trên PostgreSQL tạm, gồm 29 kiểm tra AI mới: RLS/grants, nguồn khác owner, tổng kích thước, idempotency, câu hỏi 40 vị trí, chấm 40 câu, giữ khóa đáp án riêng, hint và xóa lịch sử/nguồn. Auth/Storage ở bộ này là test double, không phải Supabase hosted.
- **37 Edge Function tests thành công** với fetch giả lập; TypeScript check và Deno lint đều thành công. Có 12 test mới cho endpoint/schema AI, hai nguồn tài liệu, retry không gọi mô hình lần nữa, JSON lỗi, hạn mức và quiz 40 câu.
- Đã định dạng ổn định bằng dart_style WASM, parse cú pháp **65/65 file Dart** trong `lib/` và `test/`, và chạy `git diff --check`.
- Đã viết 6 test domain và 8 widget test mới trong `test/ai_workspace_test.dart` và `test/ai_workspace_widget_test.dart`; cập nhật test điều hướng cho màn hình công cụ mới. **Chưa chạy Dart/Flutter tests, analyzer, build Android hoặc đối chiếu ảnh trên thiết bị**, do môi trường đám mây chưa có Flutter SDK.

Trên máy có Flutter SDK, chạy từ thư mục chứa `pubspec.yaml`:

```sh
flutter pub get
flutter analyze
flutter test test/ai_workspace_test.dart test/ai_workspace_widget_test.dart
flutter test test/navigation_widget_test.dart test/schedule_editor_widget_test.dart test/quiz_flow_widget_test.dart
flutter test
flutter build apk --debug
```

Kiểm tra thêm trên Android với backend thật: chọn/tải PDF/TXT, mở lại kết quả đã tạo, tìm kiếm và lọc, bàn phím ở màn hình hẹp/cỡ chữ lớn, mạng chậm, thử lại sau mất phản hồi, chấm quiz đủ 40 câu và mở câu hỏi từ Quiz khi AI đang có bản nháp.
