import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vstudy/domain/entities.dart';
import 'package:vstudy/domain/repositories.dart';
import 'package:vstudy/domain/use_cases.dart';
import 'package:vstudy/presentation/app.dart';
import 'package:vstudy/presentation/app_footer.dart';

class _Auth implements AuthRepository {
  final users = StreamController<AppUser?>.broadcast();
  final recovery = StreamController<bool>.broadcast();
  List<String>? registration;
  AppUser? user;
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
    registration = [name, email, password];
    return const SignUpResult(needsEmailConfirmation: true);
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

  testWidgets(
    'signup waits for email confirmation and does not show an authenticated dashboard',
    (tester) async {
      await tester.pumpWidget(VstudyApp(useCases: useCases));
      final switchButton = find.text('Chưa có tài khoản? Đăng ký');
      await tester.ensureVisible(switchButton);
      await tester.tap(switchButton);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Nguyễn An');
      await tester.enterText(find.byType(TextField).at(1), 'an@example.com');
      await tester.enterText(find.byType(TextField).at(2), 'password123');
      await tester.enterText(find.byType(TextField).at(3), 'password123');
      final consent = find.byType(CheckboxListTile);
      await tester.ensureVisible(consent);
      await tester.tap(consent);
      await tester.pump();
      final submit = find.widgetWithText(FilledButton, 'Đăng ký');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(auth.registration, ['Nguyễn An', 'an@example.com', 'password123']);
      expect(find.textContaining('kiểm tra email'), findsOneWidget);
      expect(find.byType(VstudyFooter), findsNothing);
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
    auth.recovery.add(true);
    await tester.pumpAndSettle();
    expect(find.text('Previous conversation route'), findsNothing);
    expect(find.text('Đặt lại mật khẩu'), findsOneWidget);
    expect(find.byType(VstudyFooter), findsNothing);
  });
}
