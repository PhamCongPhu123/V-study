import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_exception.dart';
import '../domain/entities.dart';
import '../domain/repositories.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this.client, {required this.redirectUrl});
  final SupabaseClient client;
  final String redirectUrl;

  AppUser? _user(User? value) =>
      value == null ? null : AppUser(id: value.id, email: value.email ?? '');
  @override
  AppUser? get currentUser => _user(client.auth.currentUser);
  @override
  Stream<AppUser?> get userChanges =>
      client.auth.onAuthStateChange.map((event) => _user(event.session?.user));
  @override
  Stream<bool> get passwordRecovery => client.auth.onAuthStateChange
      .where((event) => event.event == AuthChangeEvent.passwordRecovery)
      .map((_) => true);

  Future<T> _call<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AuthException catch (error) {
      final message = switch (error.code) {
        'invalid_credentials' => 'Email hoặc mật khẩu không đúng.',
        'email_not_confirmed' => 'Vui lòng xác nhận email trước khi đăng nhập.',
        'user_already_exists' || 'email_exists' => 'Email này đã được đăng ký.',
        'over_email_send_rate_limit' || 'over_request_rate_limit' =>
          'Bạn thao tác quá nhanh. Vui lòng thử lại sau.',
        'weak_password' =>
          'Mật khẩu chưa đủ mạnh theo chính sách của hệ thống.',
        _ =>
          'Không thể xác thực. Vui lòng kiểm tra thông tin hoặc thử lại sau.',
      };
      throw AppException(message);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        'Không kết nối được dịch vụ tài khoản. Vui lòng thử lại.',
      );
    }
  }

  @override
  Future<void> signIn(String email, String password) => _call(() async {
    await client.auth.signInWithPassword(email: email, password: password);
  });
  @override
  Future<SignUpResult> signUp(String name, String email, String password) =>
      _call(() async {
        final result = await client.auth.signUp(
          email: email,
          password: password,
          data: {'display_name': name},
          emailRedirectTo: redirectUrl,
        );
        return SignUpResult(needsEmailConfirmation: result.session == null);
      });
  @override
  Future<void> signOut() => _call(() async {
    await client.auth.signOut();
  });
  @override
  Future<void> signInWithGoogle() => _call(() async {
    final opened = await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectUrl,
    );
    if (!opened) {
      throw const AppException('Không mở được màn hình đăng nhập Google.');
    }
  });
  @override
  Future<void> requestPasswordReset(String email) => _call(() async {
    await client.auth.resetPasswordForEmail(email, redirectTo: redirectUrl);
  });
  @override
  Future<void> updatePassword(String password) => _call(() async {
    await client.auth.updateUser(UserAttributes(password: password));
  });
}
