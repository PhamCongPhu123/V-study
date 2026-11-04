import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vstudy/core/app_exception.dart';
import 'package:vstudy/data/preview_repository.dart';
import 'package:vstudy/domain/entities.dart';
import 'package:vstudy/presentation/app.dart';
import 'package:vstudy/presentation/design_system.dart';
import 'package:vstudy/presentation/schedule_editor_page.dart';

class _RecordingPreview extends PreviewRepository {
  _RecordingPreview() : super(now: DateTime(2026, 11, 12, 12));
  int creates = 0;
  int updates = 0;
  int deletes = 0;
  int failures = 0;
  EventDraft? lastDraft;
  String? lastUpdatedId;
  String? lastDeletedId;
  Completer<void>? createGate;

  @override
  Future<List<StudyEvent>> createEvent(EventDraft draft) async {
    creates++;
    lastDraft = draft;
    if (createGate != null) await createGate!.future;
    if (failures > 0) {
      failures--;
      throw const AppException('Không lưu được lịch kiểm thử.');
    }
    return super.createEvent(draft);
  }

  @override
  Future<void> updateEvent(String id, EventDraft draft) async {
    updates++;
    lastUpdatedId = id;
    lastDraft = draft;
    await super.updateEvent(id, draft);
  }

  @override
  Future<void> deleteEvent(String id) async {
    deletes++;
    lastDeletedId = id;
    await super.deleteEvent(id);
  }

  void resetCalls() {
    creates = 0;
    updates = 0;
    deletes = 0;
    lastDraft = null;
  }
}

void main() {
  late _RecordingPreview preview;
  final day = DateTime(2026, 11, 12);
  setUp(() => preview = _RecordingPreview());

  void setSize(WidgetTester tester, {double width = 402}) {
    tester.view.physicalSize = Size(width, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> openEditor(
    WidgetTester tester, {
    StudyEvent? existing,
    double width = 402,
  }) async {
    setSize(tester, width: width);
    final subjects = await preview.listSubjects();
    await tester.pumpWidget(
      MaterialApp(
        theme: vstudyTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const ValueKey('open-editor'),
                onPressed: () => Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => ScheduleEditorPage(
                      useCases: preview.useCases,
                      subjects: subjects,
                      selectedDay: day,
                      existing: existing,
                    ),
                  ),
                ),
                child: const Text('Mở lịch'),
              ),
            ),
          ),
        ),
      ),
    );
    await tap(tester, 'open-editor');
    expect(find.byType(ScheduleEditorPage), findsOneWidget);
  }

  Future<List<StudyEvent>> series() async {
    final created = await preview.createEvent(
      EventDraft(
        title: 'Lịch lặp gốc',
        kind: EventKind.classSession,
        startsAt: DateTime(2026, 11, 12, 8),
        endsAt: DateTime(2026, 11, 12, 9),
        repeatWeeks: 1,
        reminderMinutes: 60,
        subjectId: 'math',
        taskTitles: ['Đọc trước', 'Làm bài'],
      ),
    );
    await preview.setTaskCompleted(created.first.tasks.first.id, true);
    preview.resetCalls();
    return preview.listEvents(day, DateTime(2026, 11, 20));
  }

  testWidgets(
    'calendar opens a full editor while all five footer buttons remain usable',
    (tester) async {
      setSize(tester);
      await tester.pumpWidget(
        VstudyApp(useCases: preview.useCases, preview: true),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'footer-calendar');
      await tap(tester, 'calendar-add-event');
      expect(find.byType(ScheduleEditorPage), findsOneWidget);
      for (final id in [
        'calendar',
        'quiz',
        'home',
        'statistics',
        'documents',
      ]) {
        expect(find.byKey(ValueKey('footer-$id')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('open-ai')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty title fails validation before any confirmation or write', (
    tester,
  ) async {
    await openEditor(tester, width: 320);
    await tap(tester, 'schedule-confirm');
    expect(preview.creates, 0);
    expect(preview.updates, 0);
    expect(find.byKey(const ValueKey('schedule-dialog-confirm')), findsNothing);
    expect(find.byType(ScheduleEditorPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancelling create confirmation preserves draft; confirming writes exactly once',
    (tester) async {
      await openEditor(tester);
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        'Nộp bài UX/UI',
      );
      await tap(tester, 'schedule-type-deadline');
      await tester.enterText(
        find.byKey(const ValueKey('schedule-location')),
        'Phòng K.P206',
      );
      await tap(tester, 'schedule-confirm');
      expect(preview.creates, 0);
      expect(
        find.byKey(const ValueKey('schedule-dialog-confirm')),
        findsOneWidget,
      );
      await tap(tester, 'schedule-dialog-cancel');
      expect(find.text('Nộp bài UX/UI'), findsOneWidget);
      expect(preview.creates, 0);
      await tap(tester, 'schedule-confirm');
      await tap(tester, 'schedule-dialog-confirm');
      expect(preview.creates, 1);
      expect(preview.lastDraft!.kind, EventKind.deadline);
      expect(preview.lastDraft!.title, 'Nộp bài UX/UI');
      expect(preview.lastDraft!.location, 'Phòng K.P206');
      expect(preview.lastDraft!.startsAt.year, day.year);
      expect(preview.lastDraft!.startsAt.month, day.month);
      expect(preview.lastDraft!.startsAt.day, day.day);
      expect(
        preview.lastDraft!.endsAt.isAfter(preview.lastDraft!.startsAt),
        isTrue,
      );
      expect(find.byType(ScheduleEditorPage), findsNothing);
    },
  );

  testWidgets(
    'close keeps a dirty draft on cancel and discards it without deleting stored events',
    (tester) async {
      await openEditor(tester);
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        'Nội dung chưa lưu',
      );
      await tap(tester, 'schedule-close');
      await tap(tester, 'schedule-dialog-cancel');
      expect(find.text('Nội dung chưa lưu'), findsOneWidget);
      await tap(tester, 'schedule-close');
      await tap(tester, 'schedule-dialog-confirm');
      expect(find.byType(ScheduleEditorPage), findsNothing);
      expect(preview.creates, 0);
      expect(preview.deletes, 0);
    },
  );

  testWidgets(
    'rapid confirmation taps write once and keep the parent route open',
    (tester) async {
      await openEditor(tester);
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        'Chỉ thêm một lần',
      );
      await tap(tester, 'schedule-confirm');
      final confirm = find.byKey(const ValueKey('schedule-dialog-confirm'));
      await tester.tap(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(preview.creates, 1);
      expect(find.byType(ScheduleEditorPage), findsNothing);
      expect(find.byKey(const ValueKey('open-editor')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'weekly self-study validates repeat count and creates one series with separate tasks',
    (tester) async {
      await openEditor(tester);
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        'Ôn chương 2',
      );
      await tap(tester, 'schedule-subtype-self-study');
      await tap(tester, 'schedule-type-deadline');
      await tap(tester, 'schedule-type-course');
      await tap(tester, 'schedule-repeat');
      await tester.tap(find.text('Hằng tuần').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('schedule-repeat-weeks')),
        '53',
      );
      await tap(tester, 'schedule-confirm');
      expect(preview.creates, 0);
      expect(
        find.byKey(const ValueKey('schedule-dialog-confirm')),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('schedule-repeat-weeks')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('schedule-repeat-weeks')),
        '2',
      );
      await tap(tester, 'schedule-extra');
      await tester.ensureVisible(find.byKey(const ValueKey('schedule-tasks')));
      await tester.enterText(
        find.byKey(const ValueKey('schedule-tasks')),
        'Đọc tài liệu\nLàm bài',
      );
      await tap(tester, 'schedule-confirm');
      await tap(tester, 'schedule-dialog-confirm');
      expect(preview.creates, 1);
      expect(preview.lastDraft!.kind, EventKind.selfStudy);
      expect(preview.lastDraft!.repeatWeeks, 2);
      final created = (await preview.listEvents(
        day,
        DateTime(2026, 11, 29),
      )).where((event) => event.title == 'Ôn chương 2').toList();
      expect(created, hasLength(3));
      expect(created.map((event) => event.seriesId).toSet(), hasLength(1));
      expect(created.first.seriesId, isNotNull);
      expect(
        created.expand((event) => event.tasks).map((task) => task.id).toSet(),
        hasLength(6),
      );
    },
  );

  testWidgets(
    'system back cancels create confirmation without losing the draft or saving',
    (tester) async {
      await openEditor(tester);
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        'Giữ bản nháp',
      );
      await tap(tester, 'schedule-confirm');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('schedule-dialog-confirm')),
        findsNothing,
      );
      expect(find.byType(ScheduleEditorPage), findsOneWidget);
      expect(find.text('Giữ bản nháp'), findsOneWidget);
      expect(preview.creates, 0);
    },
  );

  testWidgets(
    'unchanged new editor closes immediately without discard modal or write',
    (tester) async {
      await openEditor(tester);
      await tap(tester, 'schedule-close');
      expect(find.byType(ScheduleEditorPage), findsNothing);
      expect(
        find.byKey(const ValueKey('schedule-dialog-confirm')),
        findsNothing,
      );
      expect(preview.creates, 0);
      expect(preview.deletes, 0);
    },
  );

  testWidgets(
    'pending save disables duplicate submission and blocks system back until completion',
    (tester) async {
      preview.createGate = Completer<void>();
      await openEditor(tester);
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        'Một lần ghi',
      );
      await tap(tester, 'schedule-confirm');
      await tester.tap(find.byKey(const ValueKey('schedule-dialog-confirm')));
      await tester.pump(const Duration(milliseconds: 350));
      expect(preview.creates, 1);
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('schedule-confirm')),
      );
      expect(button.onPressed, isNull);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ScheduleEditorPage), findsOneWidget);
      expect(preview.creates, 1);
      preview.createGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleEditorPage), findsNothing);
    },
  );

  testWidgets(
    'failed save retains form and supports a deliberate confirmed retry',
    (tester) async {
      preview.failures = 1;
      await openEditor(tester);
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        'Giữ lại khi lỗi',
      );
      await tap(tester, 'schedule-confirm');
      await tap(tester, 'schedule-dialog-confirm');
      expect(find.byType(ScheduleEditorPage), findsOneWidget);
      expect(find.text('Giữ lại khi lỗi'), findsOneWidget);
      expect(find.text('Không lưu được lịch kiểm thử.'), findsOneWidget);
      expect(preview.creates, 1);
      await tap(tester, 'schedule-confirm');
      await tap(tester, 'schedule-dialog-confirm');
      expect(preview.creates, 2);
      expect(find.byType(ScheduleEditorPage), findsNothing);
      final matches = (await preview.listEvents(
        day,
        DateTime(2026, 11, 13),
      )).where((event) => event.title == 'Giữ lại khi lỗi');
      expect(matches.length, 1);
    },
  );

  testWidgets(
    'editing changes one occurrence while preserving checklist IDs, completion and reminder',
    (tester) async {
      final original = (await series())
          .where((event) => event.title == 'Lịch lặp gốc')
          .toList();
      final first = original.first;
      await openEditor(tester, existing: first);
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        'Buổi này đã sửa',
      );
      await tap(tester, 'schedule-confirm');
      await tap(tester, 'schedule-dialog-confirm');
      expect(preview.updates, 1);
      expect(preview.lastUpdatedId, first.id);
      expect(preview.lastDraft!.repeatWeeks, 0);
      expect(preview.lastDraft!.reminderMinutes, 60);
      final records = await preview.listEvents(day, DateTime(2026, 11, 20));
      final changed = records.singleWhere((event) => event.id == first.id);
      expect(
        changed.tasks.map((task) => task.id),
        first.tasks.map((task) => task.id),
      );
      expect(changed.tasks.first.isCompleted, isTrue);
      expect(changed.seriesId, first.seriesId);
      expect(
        records.singleWhere((event) => event.id == original.last.id).title,
        'Lịch lặp gốc',
      );
    },
  );

  testWidgets(
    'delete cancel preserves occurrence; confirmed delete removes only selected occurrence',
    (tester) async {
      final original = (await series())
          .where((event) => event.title == 'Lịch lặp gốc')
          .toList();
      final first = original.first;
      await openEditor(tester, existing: first);
      await tap(tester, 'schedule-delete');
      await tap(tester, 'schedule-dialog-cancel');
      expect(preview.deletes, 0);
      expect(find.byType(ScheduleEditorPage), findsOneWidget);
      await tap(tester, 'schedule-delete');
      await tap(tester, 'schedule-dialog-confirm');
      expect(preview.deletes, 1);
      expect(preview.lastDeletedId, first.id);
      final remaining = await preview.listEvents(day, DateTime(2026, 11, 20));
      expect(remaining.where((event) => event.id == first.id), isEmpty);
      expect(
        remaining.where((event) => event.id == original.last.id),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'footer navigation asks before discarding a draft and cancel stays on the editor',
    (tester) async {
      setSize(tester);
      await tester.pumpWidget(
        VstudyApp(useCases: preview.useCases, preview: true),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'footer-calendar');
      await tap(tester, 'calendar-add-event');
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        'Đang nhập lịch',
      );
      await tap(tester, 'footer-home');
      await tap(tester, 'schedule-dialog-cancel');
      expect(find.byType(ScheduleEditorPage), findsOneWidget);
      expect(find.text('Đang nhập lịch'), findsOneWidget);
      await tap(tester, 'footer-home');
      await tap(tester, 'schedule-dialog-confirm');
      expect(find.byType(ScheduleEditorPage), findsNothing);
      expect(preview.creates, 0);
      expect(preview.deletes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AI opens and returns to the same unsaved schedule without a write',
    (tester) async {
      setSize(tester);
      await tester.pumpWidget(
        VstudyApp(useCases: preview.useCases, preview: true),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'footer-calendar');
      await tap(tester, 'calendar-add-event');
      await tester.enterText(
        find.byKey(const ValueKey('schedule-title')),
        'Hỏi AI trước khi lưu',
      );
      await tap(tester, 'open-ai');
      expect(find.byType(ScheduleEditorPage), findsNothing);
      expect(find.text('Trợ lý V-study'), findsOneWidget);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleEditorPage), findsOneWidget);
      expect(find.text('Hỏi AI trước khi lưu'), findsOneWidget);
      expect(preview.creates, 0);
      expect(preview.deletes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
