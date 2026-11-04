import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vstudy/data/preview_repository.dart';
import 'package:vstudy/main.dart' as entrypoint;
import 'package:vstudy/presentation/ai_page.dart';
import 'package:vstudy/presentation/app.dart';
import 'package:vstudy/presentation/calendar_page.dart';
import 'package:vstudy/presentation/home_page.dart';
import 'package:vstudy/presentation/quiz_page.dart';
import 'package:vstudy/presentation/statistics_page.dart';

const _footerKeys = [
  'footer-calendar',
  'footer-quiz',
  'footer-home',
  'footer-statistics',
  'footer-documents',
];

void main() {
  Future<void> openPrototype(WidgetTester tester, {double width = 402}) async {
    tester.view.physicalSize = Size(width, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      VstudyApp(useCases: PreviewRepository().useCases, preview: true),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectFooter(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  void expectFooterVisible(WidgetTester tester) {
    for (final key in _footerKeys) {
      final finder = find.byKey(ValueKey(key));
      expect(finder, findsOneWidget);
      expect(tester.getRect(finder).bottom, lessThanOrEqualTo(874));
    }
  }

  testWidgets('default app entrypoint requires live backend configuration', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await entrypoint.main();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsNothing);
    expect(find.textContaining('Thiếu cấu hình Supabase'), findsOneWidget);
    expect(find.byKey(const ValueKey('footer-home')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'footer starts at home and routes all five destinations in visual order',
    (tester) async {
      await openPrototype(tester);
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Đăng nhập'), findsNothing);
      final positions = _footerKeys
          .map((key) => tester.getCenter(find.byKey(ValueKey(key))).dx)
          .toList();
      for (var i = 1; i < positions.length; i++) {
        expect(positions[i], greaterThan(positions[i - 1]));
      }
      for (final destination in <(String, Type)>[
        ('footer-calendar', CalendarPage),
        ('footer-quiz', QuizPage),
        ('footer-home', HomePage),
        ('footer-statistics', StatisticsPage),
        ('footer-documents', DocumentsPage),
      ]) {
        await selectFooter(tester, destination.$1);
        expect(find.byType(destination.$2), findsOneWidget);
        expectFooterVisible(tester);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'footer remains outside nested quiz routes and house resets navigation',
    (tester) async {
      await openPrototype(tester);
      await selectFooter(tester, 'footer-quiz');
      final context = tester.element(find.byType(QuizPage));
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Nested quiz detail')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nested quiz detail'), findsOneWidget);
      expectFooterVisible(tester);
      await selectFooter(tester, 'footer-documents');
      expect(find.byType(DocumentsPage), findsOneWidget);
      await selectFooter(tester, 'footer-home');
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Nested quiz detail'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('calendar changes day week month without losing footer', (
    tester,
  ) async {
    await openPrototype(tester);
    await selectFooter(tester, 'footer-calendar');
    for (final label in ['Tuần', 'Tháng', 'Ngày']) {
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(find.byType(CalendarPage), findsOneWidget);
      expectFooterVisible(tester);
      expect(tester.takeException(), isNull);
    }
    await selectFooter(tester, 'footer-home');
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets(
    'AI conversation and document routes retain footer and system back pops inner routes',
    (tester) async {
      await openPrototype(tester);
      await selectFooter(tester, 'footer-quiz');
      await tester.tap(find.byKey(const ValueKey('open-ai')));
      await tester.pumpAndSettle();
      expect(find.byType(AiPage), findsOneWidget);
      final conversation = find.text('Cách ôn tập hiệu quả');
      final aiList = find
          .descendant(
            of: find.byKey(const ValueKey('ai-home-list')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(conversation, 180, scrollable: aiList);
      await tester.tap(conversation);
      await tester.pumpAndSettle();
      expect(find.text('Làm sao để ôn tập hiệu quả hơn?'), findsOneWidget);
      expectFooterVisible(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AiPage), findsOneWidget);
      expect(find.text('Làm sao để ôn tập hiệu quả hơn?'), findsNothing);

      final documents = find.text('Quản lý tài liệu PDF/TXT');
      await tester.scrollUntilVisible(documents, -180, scrollable: aiList);
      await tester.tap(documents);
      await tester.pumpAndSettle();
      expect(find.byType(DocumentsPage), findsOneWidget);
      expectFooterVisible(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AiPage), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(QuizPage), findsOneWidget);
      expectFooterVisible(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow screen keeps footer usable on every destination', (
    tester,
  ) async {
    await openPrototype(tester, width: 320);
    for (final key in _footerKeys) {
      await selectFooter(tester, key);
      expectFooterVisible(tester);
      expect(tester.takeException(), isNull);
    }
  });
}
