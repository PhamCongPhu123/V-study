import '../core/app_exception.dart';

enum AuthFailureReason {
  unconfirmedEmail,
  rateLimited,
  linkExpired,
  unavailable,
  authentication,
}

class AuthFailure extends AppException {
  const AuthFailure(super.message, this.reason);
  final AuthFailureReason reason;
}
