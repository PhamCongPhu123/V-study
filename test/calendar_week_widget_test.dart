import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:vstudy/data/preview_repository.dart';
import 'package:vstudy/domain/entities.dart';
import 'package:vstudy/presentation/app.dart';

class _CalendarPreview extends PreviewRepository {
  _CalendarPreview(this.events);
  final List<StudyEvent> events;

  @override
  Future<List<StudyEvent>> listEvents(DateTime from, DateTime to) async =>
      events
          .where(
            (event) =>
                event.startsAt.isBefore(to) && event.endsAt.isAfter(from),
          )
          .toList();
}

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dateKey = DateFormat('yyyy-MM-dd').format(today);
  final event = StudyEvent(
    id: 'math',
    title: 'Toán ứng dụng',
    kind: EventKind.classSession,
    startsAt: today.add(const Duration(hours: 8, minutes: 30)),
    endsAt: today.add(const Duration(hours: 10, minutes: 30)),
    location: 'Phòng A.101',
  );

  Future<void> openWeek(WidgetTester tester, _CalendarPreview preview) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      VstudyApp(useCases: preview.useCases, preview: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('footer-calendar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-view-week')));
    await tester.pumpAndSettle();
  }

  testWidgets('week event shows its name and time below the correct day', (
    tester,
  ) async {
    await openWeek(tester, _CalendarPreview([event]));
    final day = find.byKey(ValueKey('calendar-day-$dateKey'));
    final block = find.byKey(ValueKey('calendar-block-math-$dateKey'));
    expect(day, findsOneWidget);
    expect(block, findsOneWidget);
    expect(tester.getCenter(block).dx, closeTo(tester.getCenter(day).dx, 1));
    expect(
      find.descendant(of: block, matching: find.text('Toán ứng dụng')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: block, matching: find.text('08:30\n10:30')),
      findsOneWidget,
    );
    expect(find.text('08:30 – 10:30 · Toán ứng dụng'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('calendar-week-event-math')));
    await tester.pumpAndSettle();
    expect(find.text('Địa điểm: Phòng A.101'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'overlapping short events remain accessible for the selected day',
    (tester) async {
      final overlap = StudyEvent(
        id: 'short',
        title: 'Họp nhóm',
        kind: EventKind.selfStudy,
        startsAt: today.add(const Duration(hours: 8, minutes: 40)),
        endsAt: today.add(const Duration(hours: 8, minutes: 50)),
      );
      await openWeek(tester, _CalendarPreview([event, overlap]));
      expect(
        find.byKey(const ValueKey('calendar-week-event-math')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('calendar-week-event-short')),
        findsOneWidget,
      );
      expect(find.text('08:40 – 08:50 · Họp nhóm'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('calendar-week-event-short')),
      );
      await tester.tap(find.byKey(const ValueKey('calendar-week-event-short')));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết buổi học'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
