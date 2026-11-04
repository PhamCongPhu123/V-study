# Thư viện tài liệu

## Giao diện và chức năng

Tab thứ năm mở **Tài liệu học tập**, dùng nền chung của Thống kê, thẻ trắng, banner navy và điểm nhấn vàng theo mẫu. Có tìm kiếm theo tên/môn, bộ lọc môn/chưa phân môn, bộ lọc yêu thích, sắp xếp tên/ngày/dung lượng và nhóm tài liệu đã tải trên thiết bị. Gợi ý ôn tập lấy tài liệu yêu thích hoặc mới nhất; không hiển thị số lượt tải, đánh giá hay tác giả giả.

Tệp vẫn thuộc thư viện riêng của từng tài khoản. Chọn **Tải lên** để thêm PDF hoặc TXT UTF-8 tối đa 10 MiB. Menu từng tài liệu cho phép phân môn, xóa tài liệu trên Supabase hoặc chỉ xóa bản tải trong ứng dụng. Phân môn không đổi nội dung hay đường dẫn tệp. Xóa môn đưa tài liệu về chưa phân môn.

**Xem ngay** đọc bytes từ Storage có xác thực hoặc bản đã lưu ngoại tuyến. PDF có trình đọc native Android/iOS với vuốt, zoom và chuyển trang; TXT hiển thị văn bản có thể chọn/sao chép. PDF web/desktop có nút tải bản gốc để mở bằng trình đọc của thiết bị. Không tạo URL công khai cho tài liệu riêng tư.

Trang xem có nút yêu thích, **Tóm tắt** và hỏi đáp về đúng tài liệu. Tóm tắt gọi `study-assistant` khi người dùng yêu cầu, lưu artifact theo luồng AI hiện có và cho mở trang tóm tắt đầy đủ. Bản xem thử dùng nội dung minh họa, PDF một trang thực sự và ghi chú TXT; không phải giáo trình trong ảnh Figma và không gọi AI thật.

## Tải xuống

Chọn **Tải về** để mở bảng định dạng và tùy chọn. Bản gốc giữ nguyên PDF/TXT; sau khi tạo tóm tắt, có thể xuất nội dung tóm tắt thành TXT riêng. Chưa có nén PDF hoặc tạo bản PDF tóm tắt, không quảng cáo kích thước tệp chưa được tạo.

Hộp lưu tệp hệ thống cho phép chọn nơi lưu. Chỉ sau khi lưu thành công mới mở thông báo tải thành công và ghi bản gốc vào **Đã tải**. Hủy hộp lưu không ghi lịch sử hoặc yêu thích. Web chỉ báo đã gửi yêu cầu đến trình duyệt vì không thể xác nhận việc người dùng lưu tệp.

Tùy chọn **Lưu bản gốc để đọc ngoại tuyến** tạo thêm bản trong thư mục riêng của ứng dụng trên Android/iOS/desktop. Danh sách và nội dung chia theo ID tài khoản, khôi phục sau khi mở lại app. Khi thư viện không kết nối được, các bản đã tải vẫn xuất hiện; chỉ tài liệu có badge Ngoại tuyến mới có bytes để đọc không mạng. Không chọn ngoại tuyến thì lịch sử xuất tệp vẫn được lưu nhưng app cần mạng để đọc lại.

Bản tóm tắt TXT được xuất riêng; nhóm Đã tải theo dõi bản gốc. Nếu xuất tệp thành công nhưng lưu ngoại tuyến hoặc yêu thích lỗi, hộp kết quả nói rõ phần chưa hoàn tất. Đăng xuất không xóa bản tải; tài khoản khác dùng vùng dữ liệu riêng. Xóa trong app không xóa các tệp người dùng đã xuất sang thư mục khác. Gỡ ứng dụng có thể xóa các bản ngoại tuyến trong thư mục riêng.

## Cập nhật Supabase

Sau các migration hiện có, chạy **chỉ** `supabase/migrations/202611040003_document_library.sql` một lần trong SQL Editor (New query → dán toàn bộ → Run). File thêm `subject_id`, `is_favorite`, khóa ngoại kiểm tra chủ sở hữu và chỉ cấp UPDATE hai cột này. RLS và chính sách Storage hiện có được giữ. Không chạy lại schema ban đầu trên database đã có dữ liệu.

Không cần Edge Function mới cho đọc/tải/yêu thích/phân môn. Tóm tắt và hỏi đáp cần `study-assistant`, `ai-chat` cùng Secrets đã cấu hình ở lần nâng cấp AI.

## Chạy ứng dụng

```powershell
git switch android-working
git pull --ff-only origin android-working
flutter pub get
flutter run --dart-define=LIVE_BACKEND=true --dart-define-from-file=config/dev.json
```

Chọn thiết bị Android khi được hỏi. Stop rồi Run lại để đăng ký plugin mới; hot reload không cài plugin. Để xuất APK dùng thật:

```powershell
flutter build apk --release --dart-define=LIVE_BACKEND=true --dart-define-from-file=config/dev.json
```

Dùng `flutter_pdfview` cho PDF Android/iOS và `path_provider` cho bản lưu riêng. Android SDK của plugin PDF dùng API 36/Java 17. Windows không build iOS; iOS cần macOS/Xcode như trước. Bản xem thử không cần SQL, nhưng vẫn cần build native để thấy PDF trong app.

## Kiểm chứng

- Đã chạy 233 assertions SQL trên PostgreSQL tạm; 12 kiểm tra mới cho yêu thích/phân môn, chống gắn môn người khác, bảo vệ đường dẫn/kích thước/owner, RLS và xóa môn không mất tài liệu.
- Đã đọc API của các package phát hành chính thức để xác nhận cách truyền PDF bytes và lưu tệp: Android/iOS tự ghi bytes, desktop cần ghi sau khi lấy đường dẫn, web không xác nhận lưu thành công.
- Đã bổ sung unit tests cho bản lưu native tồn tại sau khi tạo lại repository, tách tài khoản, xóa bản tải, chống đường dẫn không hợp lệ và dữ liệu không khớp; widget test tìm kiếm, đọc TXT và yêu thích.
- Môi trường đám mây chưa có Flutter SDK: chưa chạy pub get, Dart analyzer, widget tests hoặc build/native PDF trên Android/iOS. Cần xác minh trên thiết bị bằng các bước dưới.

```powershell
flutter analyze
flutter test test/document_library_test.dart test/document_library_widget_test.dart
```

Thử tải PDF/TXT thật lên, phân môn, lọc/tìm, yêu thích, đọc trang PDF, hủy tải, tải thành công, bật chế độ máy bay rồi đọc bản có badge Ngoại tuyến, xóa bản tải và đăng nhập tài khoản khác. Thử tóm tắt/hỏi đáp sau khi có cấu hình AI; xác nhận tệp TXT tóm tắt đúng nội dung đã tạo. Kiểm tra quyền bộ nhớ và hộp lưu hệ thống trên điện thoại thật.
