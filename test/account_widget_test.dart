import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vstudy/core/app_exception.dart';
import 'package:vstudy/data/preview_repository.dart';
import 'package:vstudy/domain/entities.dart';
import 'package:vstudy/domain/repositories.dart';
import 'package:vstudy/domain/use_cases.dart';
import 'package:vstudy/presentation/account_editor_page.dart';
import 'package:vstudy/presentation/account_page.dart';
import 'package:vstudy/presentation/app.dart';
import 'package:vstudy/presentation/app_footer.dart';

class _AccountPreview extends PreviewRepository {
  int saves = 0;
  int failures = 0;
  int preferenceFailures = 0;
  Completer<void>? saveGate;
  @override
  Future<void> saveAccount(AccountDraft draft) async {
    saves++;
    if (saveGate != null) {
      await saveGate!.future;
    }
    if (failures > 0) {
      failures--;
      throw const AppException('Không lưu được hồ sơ kiểm thử.');
    }
    await super.saveAccount(draft);
  }

  @override
  Future<void> saveAccountPreferences(AccountPreferences preferences) async {
    if (preferenceFailures > 0) {
      preferenceFailures--;
      throw const AppException('Không lưu được cài đặt kiểm thử.');
    }
    await super.saveAccountPreferences(preferences);
  }
}

class _AccountAuth implements AuthRepository {
  AppUser? user = const AppUser(id: 'preview-user', email: 'an@example.com');
  final users = StreamController<AppUser?>.broadcast();
  int signOuts = 0;
  bool fail = false;
  @override
  AppUser? get currentUser => user;
  @override
  Stream<AppUser?> get userChanges => users.stream;
  @override
  Stream<bool> get passwordRecovery => const Stream.empty();
  @override
  Future<void> signOut() async {
    signOuts++;
    if (fail) {
      throw const AppException('Không đăng xuất được.');
    }
    user = null;
    users.add(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late _AccountPreview repository;
  setUp(() => repository = _AccountPreview());
  void size(WidgetTester tester, {double width = 402}) {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        260,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 20,
      );
    }
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester, {
    bool edit = false,
    double width = 402,
  }) async {
    size(tester, width: width);
    await tester.pumpWidget(
      VstudyApp(useCases: repository.useCases, preview: true),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'home-account');
    if (edit) {
      await tap(tester, 'account-edit');
    }
  }

  testWidgets(
    'home avatar opens account and nested editor with footer and AI intact',
    (tester) async {
      await open(tester, edit: true, width: 320);
      expect(find.byType(AccountEditorPage), findsOneWidget);
      for (final tab in [
        'calendar',
        'quiz',
        'home',
        'statistics',
        'documents',
      ]) {
        expect(find.byKey(ValueKey('footer-$tab')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('open-ai')), findsOneWidget);
      final email = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('account-email')),
          matching: find.byType(TextField),
        ),
      );
      expect(email.readOnly, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'save updates details/avatar, shows success, then refreshes account and home',
    (tester) async {
      await open(tester, edit: true);
      await tester.enterText(
        find.byKey(const ValueKey('account-name')),
        'Nguyễn An',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-class')),
        'UXUI01',
      );
      await tap(tester, 'account-change-avatar');
      await tap(tester, 'account-avatar-book');
      await tap(tester, 'account-save');
      expect(repository.saves, 1);
      expect(
        find.byKey(const ValueKey('account-save-success')),
        findsOneWidget,
      );
      expect((await repository.getProfile()).avatarKey, 'book');
      await tap(tester, 'account-success-done');
      expect(find.byType(AccountEditorPage), findsNothing);
      expect(find.text('Nguyễn An'), findsOneWidget);
      expect(find.textContaining('UXUI01'), findsOneWidget);
      await tap(tester, 'account-back');
      expect(find.text('Xin chào, Nguyễn An!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'blank name is rejected and a failed save keeps the draft for retry',
    (tester) async {
      repository.failures = 1;
      await open(tester, edit: true);
      await tester.enterText(find.byKey(const ValueKey('account-name')), ' ');
      await tap(tester, 'account-save');
      expect(repository.saves, 0);
      await tester.enterText(
        find.byKey(const ValueKey('account-name')),
        'Tên chưa lưu',
      );
      await tap(tester, 'account-save');
      expect(find.text('Không lưu được hồ sơ kiểm thử.'), findsOneWidget);
      expect(find.text('Tên chưa lưu'), findsOneWidget);
      expect(find.byKey(const ValueKey('account-save-success')), findsNothing);
      await tap(tester, 'account-save');
      expect(repository.saves, 2);
      expect(
        find.byKey(const ValueKey('account-save-success')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'footer switching asks before discarding edits; cancel retains input',
    (tester) async {
      await open(tester, edit: true);
      await tester.enterText(
        find.byKey(const ValueKey('account-name')),
        'Chưa lưu',
      );
      await tap(tester, 'footer-calendar');
      await tap(tester, 'account-dialog-cancel');
      expect(find.text('Chưa lưu'), findsOneWidget);
      await tap(tester, 'footer-calendar');
      await tap(tester, 'account-dialog-confirm');
      expect(find.byType(AccountEditorPage), findsNothing);
      expect(repository.saves, 0);
      expect((await repository.getProfile()).displayName, 'Tom');
    },
  );

  testWidgets(
    'pending save blocks duplicate submit and Back until completion',
    (tester) async {
      repository.saveGate = Completer<void>();
      await open(tester, edit: true);
      await tester.enterText(
        find.byKey(const ValueKey('account-name')),
        'Đang lưu',
      );
      await tester.tap(find.byKey(const ValueKey('account-save')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(repository.saves, 1);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('account-save')))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AccountEditorPage), findsOneWidget);
      repository.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('account-save-success')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'preference failure keeps previous value and dark profile can be saved',
    (tester) async {
      repository.preferenceFailures = 1;
      await open(tester);
      await tap(tester, 'account-dark-mode');
      expect((await repository.getProfile()).preferences.darkProfile, isFalse);
      expect(find.text('Không lưu được cài đặt kiểm thử.'), findsOneWidget);
      await tap(tester, 'account-dark-mode');
      expect((await repository.getProfile()).preferences.darkProfile, isTrue);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('account-dark-mode')),
            )
            .value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preview logout can be cancelled then exits to a resumable preview screen',
    (tester) async {
      await open(tester);
      await tap(tester, 'account-logout');
      await tap(tester, 'account-dialog-cancel');
      expect(find.byType(AccountPage), findsOneWidget);
      await tap(tester, 'account-logout');
      await tap(tester, 'account-dialog-confirm');
      expect(find.byType(AccountPage), findsNothing);
      expect(find.byType(VstudyFooter), findsNothing);
      expect(find.text('Đã thoát bản xem thử'), findsOneWidget);
      await tap(tester, 'account-preview-continue');
      expect(find.byType(VstudyFooter), findsOneWidget);
      expect(find.text('Xin chào, Tom!'), findsOneWidget);
    },
  );

  testWidgets(
    'live logout failure retains account; success removes private feature routes',
    (tester) async {
      size(tester);
      final auth = _AccountAuth()..fail = true;
      addTearDown(auth.users.close);
      final useCases = VstudyUseCases(
        auth: auth,
        study: repository,
        documents: repository,
        quizzes: repository,
        assistant: repository,
        analytics: repository,
        account: repository,
      );
      await tester.pumpWidget(VstudyApp(useCases: useCases));
      await tester.pumpAndSettle();
      await tap(tester, 'home-account');
      expect(find.text('an@example.com'), findsOneWidget);
      await tap(tester, 'account-logout');
      await tap(tester, 'account-dialog-confirm');
      expect(auth.signOuts, 1);
      expect(find.byType(AccountPage), findsOneWidget);
      expect(find.text('Không đăng xuất được.'), findsOneWidget);
      auth.fail = false;
      await tap(tester, 'account-logout');
      await tap(tester, 'account-dialog-confirm');
      expect(auth.signOuts, 2);
      expect(find.byType(AccountPage), findsNothing);
      expect(find.byType(AccountEditorPage), findsNothing);
      expect(find.byType(VstudyFooter), findsNothing);
      expect(find.text('Đăng nhập'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
