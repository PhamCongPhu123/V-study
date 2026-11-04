import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vstudy/data/preview_repository.dart';
import 'package:vstudy/domain/analytics.dart';
import 'package:vstudy/domain/analytics_repository.dart';
import 'package:vstudy/domain/entities.dart';
import 'package:vstudy/domain/use_cases.dart';
import 'package:vstudy/presentation/ai_page.dart';
import 'package:vstudy/presentation/app.dart';
import 'package:vstudy/presentation/quiz_page.dart';
import 'package:vstudy/presentation/quiz_player.dart';
import 'package:vstudy/presentation/statistics_detail_pages.dart';
import 'package:vstudy/presentation/statistics_extra_pages.dart';
import 'package:vstudy/presentation/statistics_page.dart';
import 'package:vstudy/presentation/statistics_widgets.dart';

/// An independent, mutable analytics store keeps UI tests offline and lets them
/// distinguish a successful save/reload from a dialog that merely closes.
class _MemoryAnalytics implements AnalyticsRepository {
  _MemoryAnalytics({this.withActivity = true}) {
    final now = DateTime.now();
    goals = LearningGoals.defaults(now);
    previousMonthDay = DateTime(now.year, now.month - 1, 15, 12);
    if (withActivity) {
      sessions.addAll([
        StudySession(
          id: 'selected-month-record',
          startedAt: previousMonthDay,
          durationMinutes: 37,
          subjectId: 'philosophy',
        ),
        StudySession(
          id: 'recent-record',
          startedAt: now.subtract(const Duration(hours: 3)),
          durationMinutes: 60,
          subjectId: 'philosophy',
        ),
      ]);
    }
  }

  final bool withActivity;
  late LearningGoals goals;
  late DateTime previousMonthDay;
  final sessions = <StudySession>[];
  final focus = <FocusSession>[];
  final flashcards = <FlashcardSession>[];
  int saves = 0;
  int loads = 0;

  static const subjects = [
    Subject(id: 'philosophy', name: 'Triết học Mác-Lênin'),
    Subject(id: 'law', name: 'Pháp luật đại cương'),
  ];

  @override
  Future<AnalyticsSnapshot> loadSnapshot({required DateTime now}) async {
    loads++;
    final submittedAt = now.subtract(const Duration(minutes: 5));
    return AnalyticsSnapshot(
      now: now,
      profile: const Profile(id: 'statistics-test', displayName: 'Test'),
      goals: goals,
      subjects: subjects,
      studySessions: List.of(sessions),
      focusSessions: List.of(focus),
      flashcardSessions: List.of(flashcards),
      quizzes: withActivity
          ? [
              Quiz(
                id: 'statistics-quiz',
                title: 'Chương 1',
                topic: 'Triết học',
                subjectId: 'philosophy',
                createdAt: submittedAt,
              ),
            ]
          : const [],
      quizAttempts: withActivity
          ? [
              QuizAttempt(
                id: 'statistics-attempt',
                quizId: 'statistics-quiz',
                correctCount: 3,
                totalQuestions: 4,
                submittedAt: submittedAt,
              ),
            ]
          : const [],
      chapterMastery: withActivity
          ? const [
              ChapterMastery(
                id: 'philosophy-chapter-1',
                subjectId: 'philosophy',
                title: 'Chương 1',
                position: 1,
                totalQuestions: 4,
                answeredQuestions: 4,
                correctQuestions: 3,
              ),
            ]
          : const [],
    );
  }

  @override
  Future<void> saveGoals(LearningGoals value) async {
    saves++;
    goals = value;
  }

  @override
  Future<void> logFocusSession({
    required DateTime startedAt,
    required int plannedMinutes,
    required int focusedMinutes,
    required int interruptions,
    String? subjectId,
  }) async {
    focus.add(
      FocusSession(
        id: 'focus-${focus.length}',
        startedAt: startedAt,
        plannedMinutes: plannedMinutes,
        focusedMinutes: focusedMinutes,
        interruptions: interruptions,
        subjectId: subjectId,
      ),
    );
  }

  @override
  Future<void> logFlashcardSession({
    required DateTime reviewedAt,
    required int reviewedCards,
    required int rememberedCards,
    String? subjectId,
  }) async {
    flashcards.add(
      FlashcardSession(
        id: 'flashcards-${flashcards.length}',
        reviewedAt: reviewedAt,
        reviewedCards: reviewedCards,
        rememberedCards: rememberedCards,
        subjectId: subjectId,
      ),
    );
  }
}

class _NoWrongPreview extends PreviewRepository {
  @override
  Future<List<WrongQuizAnswer>> listWrongAnswers({String? subjectId}) async =>
      [];
}

VstudyUseCases _useCases(
  _MemoryAnalytics analytics, {
  PreviewRepository? preview,
}) {
  final base = (preview ?? PreviewRepository()).useCases;
  return VstudyUseCases(
    auth: base.auth,
    study: base.study,
    documents: base.documents,
    quizzes: base.quizzes,
    assistant: base.assistant,
    analytics: analytics,
  );
}

const _footerKeys = [
  'footer-calendar',
  'footer-quiz',
  'footer-home',
  'footer-statistics',
  'footer-documents',
];

void _expectNavigation(
  WidgetTester tester,
  double height, {
  bool includeAi = true,
}) {
  for (final key in [..._footerKeys, if (includeAi) 'open-ai']) {
    final finder = find.byKey(ValueKey(key));
    expect(finder, findsOneWidget);
    expect(tester.getRect(finder).bottom, lessThanOrEqualTo(height));
    expect(tester.getRect(finder).top, greaterThanOrEqualTo(0));
  }
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) {
    final scrollable = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              (widget.axisDirection == AxisDirection.down ||
                  widget.axisDirection == AxisDirection.up),
        )
        .last;
    await tester.scrollUntilVisible(finder, 180, scrollable: scrollable);
  }
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

Future<void> _chooseGoalDate(
  WidgetTester tester,
  String key,
  DateTime date,
) async {
  await _tapKey(tester, key);
  await tester.tap(find.byTooltip('Switch to input'));
  await tester.pumpAndSettle();
  final input = find.descendant(
    of: find.byType(DatePickerDialog),
    matching: find.byType(EditableText),
  );
  // VstudyApp uses the default Material English locale. The picker parses
  // its displayed month/day/year format, while storage remains date-only.
  await tester.enterText(input, '${date.month}/${date.day}/${date.year}');
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> _openStatistics(
  WidgetTester tester,
  _MemoryAnalytics analytics, {
  double width = 430,
  double height = 950,
  PreviewRepository? preview,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    VstudyApp(useCases: _useCases(analytics, preview: preview), preview: true),
  );
  await tester.pumpAndSettle();
  await _tapKey(tester, 'footer-statistics');
}

void main() {
  testWidgets('statistics action buttons are centered on the screen', (
    tester,
  ) async {
    await _openStatistics(tester, _MemoryAnalytics());
    for (final entry in <(String, String)>[
      ('stats-quiz', 'stats-practice-wrong'),
      ('stats-subjects', 'stats-subject-course'),
      ('stats-goals', 'stats-edit-goals'),
      ('stats-weekly-report', 'stats-copy-report'),
    ]) {
      await _tapKey(tester, entry.$1);
      final button = find.byKey(ValueKey(entry.$2));
      if (button.evaluate().isEmpty) {
        final scrollable = find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  (widget.axisDirection == AxisDirection.down ||
                      widget.axisDirection == AxisDirection.up),
            )
            .last;
        await tester.scrollUntilVisible(button, 180, scrollable: scrollable);
      }
      await tester.ensureVisible(button);
      expect(tester.getCenter(button).dx, closeTo(215, 1));
      expect(tester.takeException(), isNull);
      await _back(tester);
    }
  });

  testWidgets('all seven statistics destinations retain footer and AI', (
    tester,
  ) async {
    await _openStatistics(tester, _MemoryAnalytics());
    for (final destination in <(String, Type)>[
      ('stats-learning', StudyTimeStatisticsPage),
      ('stats-focus', FocusStatisticsPage),
      ('stats-quiz', QuizStatisticsPage),
      ('stats-subjects', SubjectStatisticsPage),
      ('stats-goals', GoalsStatisticsPage),
      ('stats-weekly-report', WeeklyReportPage),
      ('stats-flashcards', FlashcardStatisticsPage),
    ]) {
      await _tapKey(tester, destination.$1);
      expect(find.byType(destination.$2), findsOneWidget);
      _expectNavigation(tester, 950);
      expect(tester.takeException(), isNull);
      await _back(tester);
      expect(find.byType(StatisticsPage), findsOneWidget);
    }
  });

  testWidgets(
    'study charts switch periods and selected calendar day shows its recorded minutes',
    (tester) async {
      final analytics = _MemoryAnalytics();
      await _openStatistics(tester, analytics);
      await _tapKey(tester, 'stats-learning');
      expect(find.byType(StatsBarChart), findsOneWidget);
      await _tapKey(tester, 'stats-period-month');
      await _tapKey(tester, 'stats-previous-period');
      final day = analytics.previousMonthDay;
      final date =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final selectedDay = find.byKey(
        const ValueKey('stats-selected-day-minutes'),
      );
      final emptyDate =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-16';
      await _tapKey(tester, 'stats-month-day-$emptyDate');
      expect(tester.widget<Text>(selectedDay).data, contains('0 phút'));
      await _tapKey(tester, 'stats-month-day-$date');
      expect(selectedDay, findsOneWidget);
      expect(tester.widget<Text>(selectedDay).data, contains('37 phút'));
      await _tapKey(tester, 'stats-period-semester');
      expect(find.byType(StatsLineChart), findsOneWidget);
      await _tapKey(tester, 'stats-period-week');
      expect(find.byType(StatsBarChart), findsOneWidget);
      _expectNavigation(tester, 950);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'goal validation blocks invalid save and valid values persist after reopening',
    (tester) async {
      final analytics = _MemoryAnalytics();
      await _openStatistics(tester, analytics);
      await _tapKey(tester, 'stats-goals');
      await _tapKey(tester, 'stats-edit-goals');
      expect(
        find.byKey(const ValueKey('stats-goal-semester-start')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('stats-goal-semester-end')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('stats-goal-weekly-minutes')),
        '0',
      );
      await _tapKey(tester, 'stats-save-goals');
      expect(analytics.saves, 0);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('stats-goal-weekly-minutes')),
        '600',
      );
      await tester.enterText(
        find.byKey(const ValueKey('stats-goal-study-days')),
        '6',
      );
      await tester.enterText(
        find.byKey(const ValueKey('stats-goal-flashcards')),
        '30',
      );
      final semesterStart = DateTime(DateTime.now().year, 8, 15);
      final semesterLastDay = DateTime(semesterStart.year + 1, 1, 20);
      await _chooseGoalDate(tester, 'stats-goal-semester-start', semesterStart);
      await _chooseGoalDate(tester, 'stats-goal-semester-end', semesterLastDay);
      await _tapKey(tester, 'stats-save-goals');
      expect(analytics.saves, 1);
      expect(analytics.goals.weeklyMinutes, 600);
      expect(analytics.goals.studyDaysPerWeek, 6);
      expect(analytics.goals.flashcardsPerDay, 30);
      expect(analytics.goals.semesterStart, semesterStart);
      expect(
        analytics.goals.semesterEnd,
        DateTime(semesterLastDay.year, 1, 21),
      );
      await _back(tester);
      await _tapKey(tester, 'stats-goals');
      await _tapKey(tester, 'stats-edit-goals');
      for (final field in <(String, String)>[
        ('stats-goal-weekly-minutes', '600'),
        ('stats-goal-study-days', '6'),
        ('stats-goal-flashcards', '30'),
      ]) {
        final textField = find.descendant(
          of: find.byKey(ValueKey(field.$1)),
          matching: find.byType(EditableText),
        );
        expect(
          tester.widget<EditableText>(textField).controller.text,
          field.$2,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'quiz practice opens wrong answers and subject course follows selected subject',
    (tester) async {
      await _openStatistics(tester, _MemoryAnalytics());
      await _tapKey(tester, 'stats-quiz');
      await _tapKey(tester, 'stats-practice-wrong');
      final wrongReview = tester.widget<QuizWrongReviewPage>(
        find.byType(QuizWrongReviewPage),
      );
      expect(wrongReview.answers, isNotEmpty);
      final player = tester.widget<QuizPlayerPage>(find.byType(QuizPlayerPage));
      expect(player.mode, QuizPlayMode.reviewWrong);
      _expectNavigation(tester, 950);
      await _back(tester);
      await _back(tester);
      await _tapKey(tester, 'stats-subjects');
      await _tapKey(tester, 'stats-subject-law');
      await _tapKey(tester, 'stats-subject-course');
      final selectedCourse = tester.widget<QuizCoursePage>(
        find.byType(QuizCoursePage),
      );
      expect(selectedCourse.subject.id, 'law');
      expect(selectedCourse.initialTab, 1);
      _expectNavigation(tester, 950);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('practice button explains when no actual wrong answers remain', (
    tester,
  ) async {
    await _openStatistics(
      tester,
      _MemoryAnalytics(),
      preview: _NoWrongPreview(),
    );
    await _tapKey(tester, 'stats-quiz');
    await _tapKey(tester, 'stats-practice-wrong');
    expect(find.byType(QuizStatisticsPage), findsOneWidget);
    expect(find.byType(QuizWrongReviewPage), findsNothing);
    expect(find.text('Bạn chưa có câu sai cần luyện lại.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'statistics detail opens AI separately and returns to the same detail',
    (tester) async {
      await _openStatistics(tester, _MemoryAnalytics());
      await _tapKey(tester, 'stats-goals');
      await _tapKey(tester, 'open-ai');
      expect(find.byType(AiPage), findsOneWidget);
      _expectNavigation(tester, 950, includeAi: false);
      await _back(tester);
      expect(find.byType(GoalsStatisticsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty focus and flashcard measurements become real records after a validated save',
    (tester) async {
      final analytics = _MemoryAnalytics(withActivity: false);
      await _openStatistics(tester, analytics);
      await _tapKey(tester, 'stats-focus');
      expect(find.text('Chưa ghi nhận phiên tập trung'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
      await _tapKey(tester, 'stats-log-focus');
      await tester.enterText(
        find.byKey(const ValueKey('stats-log-first')),
        '25',
      );
      await tester.enterText(
        find.byKey(const ValueKey('stats-log-second')),
        '26',
      );
      await _tapKey(tester, 'stats-save-focus');
      expect(analytics.focus, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('stats-log-second')),
        '15',
      );
      final loadsBeforeSave = analytics.loads;
      await _tapKey(tester, 'stats-save-focus');
      expect(analytics.focus.single.focusedMinutes, 15);
      expect(analytics.focus.single.plannedMinutes, 25);
      expect(analytics.loads, greaterThan(loadsBeforeSave));
      // Just after midnight on a Monday the dialog's completed session belongs
      // to last week. Inspect that week rather than relying on the test clock.
      final now = DateTime.now();
      final currentMonday = DateTime(
        now.year,
        now.month,
        now.day - now.weekday + 1,
      );
      if (analytics.focus.single.startedAt.isBefore(currentMonday)) {
        await tester.tap(find.byTooltip('Kỳ trước'));
        await tester.pumpAndSettle();
      }
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('Chưa ghi nhận phiên tập trung'), findsNothing);
      expect(
        analytics.sessions,
        isEmpty,
      ); // Logging focus never doubles study time.
      await _back(tester);
      await _tapKey(tester, 'stats-flashcards');
      expect(find.text('Chưa ghi nhận lượt ôn flashcard'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
      await _tapKey(tester, 'stats-log-flashcards');
      await tester.enterText(
        find.byKey(const ValueKey('stats-log-first')),
        '20',
      );
      await tester.enterText(
        find.byKey(const ValueKey('stats-log-second')),
        '15',
      );
      await _tapKey(tester, 'stats-save-flashcards');
      expect(analytics.flashcards.single.reviewedCards, 20);
      expect(analytics.flashcards.single.rememberedCards, 15);
      if (analytics.flashcards.single.reviewedAt.isBefore(currentMonday)) {
        await tester.tap(find.byTooltip('Kỳ trước'));
        await tester.pumpAndSettle();
      }
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('20 lượt ôn thẻ'), findsOneWidget);
      expect(find.text('Chưa ghi nhận lượt ôn flashcard'), findsNothing);
      _expectNavigation(tester, 950);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('weekly report copies actual report data', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _openStatistics(tester, _MemoryAnalytics(withActivity: false));
    await _tapKey(tester, 'stats-weekly-report');
    await _tapKey(tester, 'stats-copy-report');
    expect(copied, contains('BÁO CÁO TUẦN VSTUDY'));
    expect(copied, contains('Thời gian học: 0 phút'));
    expect(copied, contains('Quiz đã nộp: 0'));
    expect(copied, contains('Điểm quiz trung bình: Chưa có bài nộp'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty statistics remain usable at a narrow phone width', (
    tester,
  ) async {
    await _openStatistics(
      tester,
      _MemoryAnalytics(withActivity: false),
      width: 320,
    );
    for (final key in [
      'stats-learning',
      'stats-focus',
      'stats-quiz',
      'stats-subjects',
      'stats-goals',
      'stats-weekly-report',
      'stats-flashcards',
    ]) {
      await _tapKey(tester, key);
      _expectNavigation(tester, 950);
      expect(tester.takeException(), isNull);
      await _back(tester);
    }
  });
}
