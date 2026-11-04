import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_exception.dart';
import '../domain/entities.dart';
import '../domain/repositories.dart';
import '../domain/auth_failure.dart';

class SupabaseAuthRepository implements AuthRepository, AuthFlowRepository {
  SupabaseAuthRepository(this.client, {required this.redirectUrl}) {
    // Subscribe before the callback coordinator starts, including on cold start.
    _subscription = client.auth.onAuthStateChange.listen(
      _onAuthState,
      onError: (Object error, StackTrace stack) {
        _notice(authErrorMessage(error));
      },
    );
  }
  final SupabaseClient client;
  final String redirectUrl;
  final _users = StreamController<AppUser?>.broadcast();
  final _recoveries = StreamController<bool>.broadcast();
  late final StreamSubscription<AuthState> _subscription;
  bool _recovery = false;
  bool _disposed = false;
  String? _pendingNotice;

  void _onAuthState(AuthState state) {
    if (_disposed) {
      return;
    }
    if (state.event == AuthChangeEvent.passwordRecovery) {
      _recovery = true;
      _pendingNotice = null;
    } else if (state.event == AuthChangeEvent.signedOut ||
        state.event == AuthChangeEvent.signedIn) {
      _recovery = false;
      _pendingNotice = null;
    }
    _users.add(_user(state.session?.user));
    if (state.event == AuthChangeEvent.passwordRecovery) {
      _recoveries.add(true);
    }
  }

  @override
  bool get isPasswordRecovery => _recovery;
  @override
  void completePasswordRecovery() => _recovery = false;
  @override
  String? takePendingAuthNotice() {
    final notice = _pendingNotice;
    _pendingNotice = null;
    return notice;
  }

  void _notice(String message) {
    if (_disposed) {
      return;
    }
    if (_users.hasListener) {
      _users.addError(AppException(message));
    } else {
      _pendingNotice = message;
    }
  }

  void reportCallbackFailure() => _notice(
    'Liên kết xác thực không dùng được hoặc đã hết hạn. Hãy đăng nhập lại hoặc yêu cầu liên kết mới trên thiết bị này.',
  );

  Future<void> handleCallback(Uri uri) async {
    if (_disposed) {
      return;
    }
    try {
      await client.auth.getSessionFromUrl(uri);
    } catch (_) {
      reportCallbackFailure();
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription.cancel();
    await _users.close();
    await _recoveries.close();
  }

  AppUser? _user(User? value) =>
      value == null ? null : AppUser(id: value.id, email: value.email ?? '');
  @override
  AppUser? get currentUser => _user(client.auth.currentUser);
  @override
  Stream<AppUser?> get userChanges => _users.stream;
  @override
  Stream<bool> get passwordRecovery => _recoveries.stream;

  Future<T> _call<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AuthException catch (error) {
      final reason = switch (error.code) {
        'email_not_confirmed' => AuthFailureReason.unconfirmedEmail,
        'over_email_send_rate_limit' ||
        'over_request_rate_limit' => AuthFailureReason.rateLimited,
        'otp_expired' ||
        'flow_state_expired' ||
        'flow_state_not_found' ||
        'bad_code_verifier' => AuthFailureReason.linkExpired,
        _ => AuthFailureReason.authentication,
      };
      throw AuthFailure(authErrorMessage(error), reason);
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
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.session == null) {
      throw const AppException(
        'Chưa nhận được phiên đăng nhập. Vui lòng thử lại.',
      );
    }
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
  Future<void> resendConfirmation(String email) => _call(() async {
    await client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: redirectUrl,
    );
  });
  @override
  Future<void> updatePassword(String password) => _call(() async {
    await client.auth.updateUser(UserAttributes(password: password));
  });
}

String authErrorMessage(Object error) {
  if (error is! AuthException) {
    return 'Không kết nối được dịch vụ tài khoản. Vui lòng thử lại.';
  }
  return switch (error.code) {
    'invalid_credentials' ||
    'invalid_grant' => 'Email hoặc mật khẩu không đúng.',
    'email_not_confirmed' => 'Vui lòng xác nhận email trước khi đăng nhập.',
    'user_already_exists' || 'email_exists' =>
      'Không thể đăng ký email này. Bạn có thể đăng nhập hoặc đặt lại mật khẩu.',
    'over_email_send_rate_limit' || 'over_request_rate_limit' =>
      'Bạn thao tác quá nhanh. Vui lòng đợi một lát rồi thử lại.',
    'weak_password' => 'Mật khẩu chưa đủ mạnh theo chính sách của hệ thống.',
    'same_password' => 'Mật khẩu mới cần khác mật khẩu hiện tại.',
    'signup_disabled' => 'Đăng ký tài khoản hiện chưa được bật.',
    'provider_disabled' || 'oauth_provider_not_supported' =>
      'Đăng nhập Google hiện chưa được cấu hình.',
    'email_address_invalid' => 'Vui lòng nhập email hợp lệ.',
    'email_address_not_authorized' =>
      'Email gửi chưa khả dụng cho địa chỉ này. Vui lòng liên hệ quản trị ứng dụng.',
    'otp_expired' ||
    'flow_state_expired' ||
    'flow_state_not_found' ||
    'bad_code_verifier' =>
      'Liên kết đã hết hạn hoặc không dùng được trên thiết bị này. Vui lòng yêu cầu liên kết mới.',
    'session_not_found' ||
    'refresh_token_not_found' ||
    'refresh_token_already_used' =>
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    'captcha_failed' => 'Chưa xác minh được yêu cầu. Vui lòng thử lại.',
    _ => 'Không thể xác thực. Vui lòng kiểm tra thông tin hoặc thử lại sau.',
  };
}
