import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import 'design_system.dart';

class LegalInformationPage extends StatelessWidget {
  const LegalInformationPage({super.key, required this.privacy});
  final bool privacy;
  @override
  Widget build(BuildContext context) => AuthFrame(
    onBack: () => Navigator.of(context).pop(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          privacy ? 'Chính sách bảo mật' : 'Điều khoản sử dụng',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        const Text(
          'Thông tin cho bản học tập Vstudy. Thông tin đơn vị phát hành và kênh hỗ trợ sẽ được bổ sung trước khi phát hành chính thức.',
          style: TextStyle(
            fontSize: 12,
            height: 1.6,
            color: VstudyColors.muted,
          ),
        ),
        const SizedBox(height: 20),
        AuthCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children:
                (privacy
                        ? const [
                            'Thông tin tài khoản\nEmail và mật khẩu được xử lý bởi dịch vụ xác thực Supabase. Ứng dụng không lưu mật khẩu trong hồ sơ học tập.',
                            'Dữ liệu học tập\nTên, lớp, ngành, ngày sinh nếu bạn cung cấp, lịch học, tài liệu, kết quả quiz và hội thoại được lưu theo tài khoản của bạn khi sử dụng dịch vụ thật.',
                            'Sử dụng AI\nKhi bạn chọn tài liệu và gửi câu hỏi hoặc tạo nội dung, phần nội dung đã chọn được chuyển đến Vstudy Ai để xử lý. Hãy chỉ dùng tài liệu bạn có quyền sử dụng.',
                            'Bản xem thử\nDữ liệu trong bản mẫu là minh họa và chỉ giữ trong phiên chạy. Bản mẫu không đăng ký tài khoản, không gửi email và không gọi Vstudy Ai.',
                            'Quản lý tài khoản\nBạn có thể sửa hồ sơ, xóa các tài liệu/hội thoại có chức năng xóa và đăng xuất. Đăng xuất không xóa dữ liệu đã lưu trên máy chủ.',
                          ]
                        : const [
                            'Mục đích sử dụng\nVstudy hỗ trợ tổ chức việc học, ôn tập và hỏi đáp kiến thức. Hãy cung cấp email bạn có quyền sử dụng và giữ bí mật thông tin đăng nhập.',
                            'Nội dung của bạn\nChỉ tải lên tài liệu bạn được phép sử dụng. Bạn chịu trách nhiệm về nội dung mình gửi và chia sẻ.',
                            'Kết quả từ AI\nCâu trả lời, tóm tắt và gợi ý AI có thể chưa chính xác. Hãy đối chiếu với tài liệu gốc hoặc người hướng dẫn khi cần.',
                            'Tính năng và dữ liệu\nBản xem thử dùng dữ liệu minh họa. Các dịch vụ thật cần được cấu hình; nhắc học hiện lưu lựa chọn, chưa gửi thông báo trên thiết bị.',
                            'Bảo vệ tài khoản\nKhông chia sẻ mật khẩu hoặc liên kết xác nhận/đặt lại mật khẩu. Khi không sử dụng thiết bị cá nhân, hãy đăng xuất sau khi học.',
                          ])
                    .map(
                      (paragraph) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Text(
                          paragraph,
                          style: const TextStyle(fontSize: 13, height: 1.7),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
      ],
    ),
  );
}
