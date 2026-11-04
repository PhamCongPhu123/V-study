/// Shared by the forms and use cases. Passwords are validated without trimming
/// or otherwise changing the value sent to Auth.
abstract final class AuthValidation {
  static String? email(String? input) {
    final value = input?.trim() ?? '';
    if (value.isEmpty) {
      return 'Vui lòng nhập email.';
    }
    if (value.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      return 'Vui lòng nhập email hợp lệ.';
    }
    return null;
  }

  static String? name(String? input) {
    final value = input?.trim() ?? '';
    if (value.isEmpty) {
      return 'Vui lòng nhập họ và tên.';
    }
    if (value.length > 100) {
      return 'Họ và tên tối đa 100 ký tự.';
    }
    return null;
  }

  static String? password(String? value, {bool newPassword = false}) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu.';
    }
    if (value.length > 128 || (newPassword && value.length < 8)) {
      return 'Mật khẩu cần từ 8 đến 128 ký tự.';
    }
    if (newPassword && value.trim().isEmpty) {
      return 'Mật khẩu không được chỉ gồm khoảng trắng.';
    }
    return null;
  }

  static String? confirmation(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập lại mật khẩu.';
    }
    return value != password ? 'Mật khẩu nhập lại chưa khớp.' : null;
  }
}
