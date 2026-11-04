import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vstudy/core/app_exception.dart';
import 'package:vstudy/domain/entities.dart';
import 'package:vstudy/domain/repositories.dart';
import 'package:vstudy/domain/use_cases.dart';
import 'package:vstudy/domain/auth_failure.dart';
import 'package:vstudy/presentation/app.dart';
import 'package:vstudy/presentation/app_footer.dart';
import 'package:vstudy/presentation/auth_widgets.dart';
import 'package:vstudy/data/preview_repository.dart';

class _Auth implements AuthRepository, AuthFlowRepository {
  final users = StreamController<AppUser?>.broadcast();
  final recovery = StreamController<bool>.broadcast();
  List<String>? registration;
  AppUser? user;
  int signIns = 0;
  int signUps = 0;
  bool confirmSignup = true;
  int googleOpens = 0;
  int resends = 0;
  String? resetEmail;
  String? savedPassword;
  AppException? signInFailure;
  Completer<void>? signInGate;
  bool pendingRecovery = false;
  String? pendingNotice;
  void startRecovery() {
    pendingRecovery = true;
    recovery.add(true);
  }

  @override
  bool get isPasswordRecovery => pendingRecovery;
  @override
  void completePasswordRecovery() => pendingRecovery = false;
  @override
  String? takePendingAuthNotice() {
    final value = pendingNotice;
    pendingNotice = null;
    return value;
  }

  @override
  Future<void> signIn(String email, String password) async {
    signIns++;
    if (signInGate != null) {
      await signInGate!.future;
    }
    if (signInFailure != null) {
      throw signInFailure!;
    }
    user = AppUser(id: 'old-user', email: email);
    users.add(user);
  }

  @override
  Future<void> signInWithGoogle() async {
    googleOpens++;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    resetEmail = email;
  }

  @override
  Future<void> resendConfirmation(String email) async {
    resends++;
  }

  @override
  Future<void> updatePassword(String password) async {
    savedPassword = password;
    users.add(user);
  }

  @override
  Future<void> signOut() async {
    pendingRecovery = false;
    user = null;
    users.add(null);
  }

  @override
  AppUser? get currentUser => user;
  @override
  Stream<AppUser?> get userChanges => users.stream;
  @override
  Stream<bool> get passwordRecovery => recovery.stream;
  @override
  Future<SignUpResult> signUp(
    String name,
    String email,
    String password,
  ) async {
    signUps++;
    registration = [name, email, password];
    return SignUpResult(needsEmailConfirmation: confirmSignup);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Study implements StudyRepository {
  @override
  Future<HomeDashboard> getDashboard(DateTime now) async => const HomeDashboard(
    profile: Profile(id: 'old-user', displayName: 'Bạn học'),
    todayMinutes: 0,
    upcomingEvents: [],
    week: [],
    recentQuizzes: [],
    recentThreads: [],
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Documents implements DocumentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Quizzes implements QuizRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Assistant implements AssistantRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late _Auth auth;
  late VstudyUseCases useCases;
  setUp(() {
    auth = _Auth();
    useCases = VstudyUseCases(
      auth: auth,
      study: _Study(),
      documents: _Documents(),
      quizzes: _Quizzes(),
      assistant: _Assistant(),
    );
  });
  tearDown(() async {
    await auth.users.close();
    await auth.recovery.close();
  });
  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> signInFields(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'an@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'password123',
    );
    await tester.pump();
  }

  testWidgets(
    'signup waits for email confirmation and does not show an authenticated dashboard',
    (tester) async {
      await tester.pumpWidget(VstudyApp(useCases: useCases));
      final switchButton = find.byKey(const ValueKey('auth-switch-signup'));
      await tester.ensureVisible(switchButton);
      await tester.tap(switchButton);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Nguyễn An');
      await tester.enterText(find.byType(TextField).at(1), 'an@example.com');
      await tester.enterText(find.byType(TextField).at(2), 'password123');
      await tester.enterText(find.byType(TextField).at(3), 'password123');
      final consent = find.byKey(const ValueKey('auth-consent'));
      await tester.ensureVisible(consent);
      await tester.tap(consent);
      await tester.pump();
      final submit = find.byKey(const ValueKey('auth-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(auth.registration, ['Nguyễn An', 'an@example.com', 'password123']);
      expect(find.text('Kiểm tra email của bạn'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(
        tester
            .widget<AuthSubmitButton>(find.byKey(const ValueKey('auth-resend')))
            .onPressed,
        isNull,
      );
      expect(find.byType(VstudyFooter), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'signup without confirmation returns to login with email retained',
    (tester) async {
      auth.confirmSignup = false;
      await tester.pumpWidget(VstudyApp(useCases: useCases));
      await tap(tester, 'auth-switch-signup');
      await tester.enterText(find.byKey(const ValueKey('auth-name')), 'An');
      await signInFields(tester);
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirm-password')),
        'password123',
      );
      await tap(tester, 'auth-consent');
      await tap(tester, 'auth-submit');
      expect(auth.signUps, 1);
      expect(find.textContaining('Tạo tài khoản thành công'), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-confirm-password')), findsNothing);
      expect(find.text('an@example.com'), findsOneWidget);
      expect(find.byType(VstudyFooter), findsNothing);
      expect(auth.signIns, 0);
    },
  );

  testWidgets(
    'auth stream errors show a safe notice without exposing the exception',
    (tester) async {
      await tester.pumpWidget(VstudyApp(useCases: useCases));
      auth.recovery.addError(StateError('private provider details'));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Không thể cập nhật phiên đăng nhập'),
        findsOneWidget,
      );
      expect(find.textContaining('private provider details'), findsNothing);
    },
  );

  testWidgets(
    'signout removes pushed pages containing the previous account data',
    (tester) async {
      auth.user = const AppUser(id: 'old-user', email: 'old@example.com');
      await tester.pumpWidget(VstudyApp(useCases: useCases));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(VstudyFooter));
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Text('Previous account private conversation'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Previous account private conversation'),
        findsOneWidget,
      );
      auth.user = null;
      auth.users.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Previous account private conversation'), findsNothing);
      expect(find.byType(VstudyFooter), findsNothing);
      expect(find.text('Đăng nhập'), findsWidgets);
    },
  );

  testWidgets('password recovery replaces an already pushed conversation', (
    tester,
  ) async {
    auth.user = const AppUser(id: 'old-user', email: 'old@example.com');
    await tester.pumpWidget(VstudyApp(useCases: useCases));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(VstudyFooter));
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            const Scaffold(body: Text('Previous conversation route')),
      ),
    );
    await tester.pumpAndSettle();
    auth.startRecovery();
    await tester.pumpAndSettle();
    expect(find.text('Previous conversation route'), findsNothing);
    expect(find.text('Đặt lại mật khẩu'), findsOneWidget);
    expect(find.byType(VstudyFooter), findsNothing);
  });

  testWidgets(
    'invalid login stays disabled and password visibility preserves its value',
    (tester) async {
      await tester.pumpWidget(VstudyApp(useCases: useCases));
      expect(
        tester
            .widget<AuthSubmitButton>(find.byKey(const ValueKey('auth-submit')))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        'invalid-email',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        ' password123 ',
      );
      await tester.pump();
      expect(auth.signIns, 0);
      expect(
        tester
            .widget<AuthSubmitButton>(find.byKey(const ValueKey('auth-submit')))
            .onPressed,
        isNull,
      );
      await tap(tester, 'auth-toggle-password');
      final password = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('auth-password')),
          matching: find.byType(TextField),
        ),
      );
      expect(password.obscureText, isFalse);
      expect(password.controller!.text, ' password123 ');
    },
  );

  testWidgets(
    'valid login reaches the shell only after the authenticated event',
    (tester) async {
      await tester.pumpWidget(VstudyApp(useCases: useCases));
      await signInFields(tester);
      await tap(tester, 'auth-submit');
      expect(auth.signIns, 1);
      expect(find.byType(VstudyFooter), findsOneWidget);
      expect(find.byType(AuthPage), findsNothing);
    },
  );

  testWidgets(
    'failed login retains input and unconfirmed email can request another link',
    (tester) async {
      auth.signInFailure = const AuthFailure(
        'Vui lòng xác nhận email trước khi đăng nhập.',
        AuthFailureReason.unconfirmedEmail,
      );
      await tester.pumpWidget(VstudyApp(useCases: useCases));
      await signInFields(tester);
      await tap(tester, 'auth-submit');
      expect(find.text('an@example.com'), findsOneWidget);
      expect(find.byType(VstudyFooter), findsNothing);
      await tap(tester, 'auth-resend-link');
      await tap(tester, 'auth-resend');
      expect(auth.resends, 1);
      expect(
        tester
            .widget<AuthSubmitButton>(find.byKey(const ValueKey('auth-resend')))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'registration checks confirmation and consent and legal text keeps the draft',
    (tester) async {
      await tester.pumpWidget(VstudyApp(useCases: useCases));
      await tap(tester, 'auth-switch-signup');
      await tester.enterText(find.byKey(const ValueKey('auth-name')), 'An');
      await signInFields(tester);
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirm-password')),
        'different',
      );
      await tester.pump();
      expect(
        tester
            .widget<AuthSubmitButton>(find.byKey(const ValueKey('auth-submit')))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirm-password')),
        'password123',
      );
      await tester.pump();
      expect(
        tester
            .widget<AuthSubmitButton>(find.byKey(const ValueKey('auth-submit')))
            .onPressed,
        isNull,
      );
      await tap(tester, 'auth-privacy');
      expect(find.text('Chính sách bảo mật'), findsOneWidget);
      await tap(tester, 'auth-back');
      expect(find.text('An'), findsOneWidget);
      await tap(tester, 'auth-consent');
      expect(
        tester
            .widget<AuthSubmitButton>(find.byKey(const ValueKey('auth-submit')))
            .onPressed,
        isNotNull,
      );
      expect(auth.signUps, 0);
    },
  );

  testWidgets(
    'reset request uses the typed email and shows an account-neutral response',
    (tester) async {
      await tester.pumpWidget(VstudyApp(useCases: useCases));
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        ' an@example.com ',
      );
      await tap(tester, 'auth-forgot');
      await tap(tester, 'auth-send-reset');
      expect(auth.resetEmail, 'an@example.com');
      expect(find.textContaining('Nếu email đã được đăng ký'), findsOneWidget);
      expect(
        tester
            .widget<AuthSubmitButton>(
              find.byKey(const ValueKey('auth-send-reset')),
            )
            .onPressed,
        isNull,
      );
      expect(find.byType(VstudyFooter), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('opening Google is not treated as a signed-in session', (
    tester,
  ) async {
    await tester.pumpWidget(VstudyApp(useCases: useCases));
    await tap(tester, 'auth-google');
    expect(auth.googleOpens, 1);
    expect(find.byType(VstudyFooter), findsNothing);
    expect(find.textContaining('Hoàn tất đăng nhập Google'), findsOneWidget);
  });

  testWidgets(
    'pending login blocks repeated submissions until the provider resolves',
    (tester) async {
      auth.signInGate = Completer<void>();
      await tester.pumpWidget(VstudyApp(useCases: useCases));
      await signInFields(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(auth.signIns, 1);
      expect(
        tester
            .widget<AuthSubmitButton>(find.byKey(const ValueKey('auth-submit')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('auth-google')))
            .onPressed,
        isNull,
      );
      auth.signInGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(VstudyFooter), findsOneWidget);
    },
  );

  testWidgets(
    'cold recovery is visible before any stream event and completes after password save',
    (tester) async {
      auth.user = const AppUser(id: 'old-user', email: 'an@example.com');
      auth.pendingRecovery = true;
      await tester.pumpWidget(VstudyApp(useCases: useCases));
      await tester.pumpAndSettle();
      expect(find.text('Đặt lại mật khẩu'), findsOneWidget);
      expect(find.byType(VstudyFooter), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('recovery-password')),
        'new password123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('recovery-confirm')),
        'new password123',
      );
      await tap(tester, 'recovery-save');
      expect(auth.savedPassword, 'new password123');
      expect(find.text('Mật khẩu đã cập nhật'), findsOneWidget);
      expect(find.byType(VstudyFooter), findsNothing);
      await tap(tester, 'recovery-done');
      expect(auth.pendingRecovery, isFalse);
      expect(find.byType(VstudyFooter), findsOneWidget);
    },
  );

  testWidgets('cancelling recovery closes its session and returns to sign in', (
    tester,
  ) async {
    auth.user = const AppUser(id: 'old-user', email: 'an@example.com');
    auth.pendingRecovery = true;
    await tester.pumpWidget(VstudyApp(useCases: useCases));
    await tester.pumpAndSettle();
    await tap(tester, 'recovery-cancel');
    expect(auth.user, isNull);
    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.byType(VstudyFooter), findsNothing);
  });

  testWidgets(
    'auth preview never validates credentials and has an explicit sample entry',
    (tester) async {
      final preview = PreviewRepository();
      await tester.pumpWidget(
        VstudyApp(
          useCases: preview.useCases,
          preview: true,
          showAuthPreview: true,
        ),
      );
      await tester.pumpAndSettle();
      await signInFields(tester);
      expect(
        tester
            .widget<AuthSubmitButton>(find.byKey(const ValueKey('auth-submit')))
            .onPressed,
        isNull,
      );
      await tap(tester, 'auth-preview-enter');
      expect(find.byType(VstudyFooter), findsOneWidget);
      expect(find.byType(AuthPage), findsNothing);
    },
  );
}
