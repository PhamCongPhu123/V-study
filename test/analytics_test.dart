import 'package:flutter_test/flutter_test.dart';
import 'package:vstudy/core/app_exception.dart';
import 'package:vstudy/domain/analytics.dart';
import 'package:vstudy/domain/analytics_repository.dart';
import 'package:vstudy/domain/entities.dart';
import 'package:vstudy/domain/repositories.dart';
import 'package:vstudy/domain/use_cases.dart';

final _now = DateTime(2026, 11, 4, 12);

LearningGoals _goals({
  int weeklyMinutes = 900,
  int studyDays = 5,
  int flashcards = 20,
  DateTime? start,
  DateTime? end,
}) => LearningGoals(
  weeklyMinutes: weeklyMinutes,
  studyDaysPerWeek: studyDays,
  flashcardsPerDay: flashcards,
  semesterStart: start ?? DateTime(2026, 8),
  semesterEnd: end ?? DateTime(2027, 2),
);

AnalyticsSnapshot _snapshot({
  DateTime? now,
  LearningGoals? goals,
  List<StudySession> sessions = const [],
  List<QuizAttempt> attempts = const [],
  List<Quiz> quizzes = const [],
  List<FocusSession> focus = const [],
  List<FlashcardSession> flashcards = const [],
  List<LearningTask> tasks = const [],
  List<ChapterMastery> mastery = const [],
}) => AnalyticsSnapshot(
  now: now ?? _now,
  profile: const Profile(id: 'owner', displayName: 'Student'),
  goals: goals ?? _goals(),
  studySessions: sessions,
  quizAttempts: attempts,
  quizzes: quizzes,
  focusSessions: focus,
  flashcardSessions: flashcards,
  tasks: tasks,
  chapterMastery: mastery,
);

StudySession _session(DateTime start, int minutes, {String? subject = 'a'}) =>
    StudySession(
      id: '$start-$minutes-$subject',
      startedAt: start,
      durationMinutes: minutes,
      subjectId: subject,
    );

QuizAttempt _attempt(
  DateTime submittedAt,
  int correct,
  int total, {
  String quiz = 'quiz-a',
  String mode = 'practice',
}) => QuizAttempt(
  id: '$submittedAt-$quiz-$mode',
  quizId: quiz,
  correctCount: correct,
  totalQuestions: total,
  submittedAt: submittedAt,
  mode: mode,
);

Quiz _quiz(String id, String subject) => Quiz(
  id: id,
  title: id,
  topic: 'Topic',
  subjectId: subject,
  createdAt: _now,
);

class _Unused
    implements
        AuthRepository,
        StudyRepository,
        DocumentRepository,
        QuizRepository,
        AssistantRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _RecordingAnalytics implements AnalyticsRepository {
  LearningGoals? savedGoals;
  FocusSession? focus;
  FlashcardSession? flashcard;

  @override
  Future<void> saveGoals(LearningGoals goals) async {
    savedGoals = goals;
  }

  @override
  Future<void> logFocusSession({
    required DateTime startedAt,
    required int plannedMinutes,
    required int focusedMinutes,
    required int interruptions,
    String? subjectId,
  }) async {
    focus = FocusSession(
      id: 'new',
      startedAt: startedAt,
      plannedMinutes: plannedMinutes,
      focusedMinutes: focusedMinutes,
      interruptions: interruptions,
      subjectId: subjectId,
    );
  }

  @override
  Future<void> logFlashcardSession({
    required DateTime reviewedAt,
    required int reviewedCards,
    required int rememberedCards,
    String? subjectId,
  }) async {
    flashcard = FlashcardSession(
      id: 'new',
      reviewedAt: reviewedAt,
      reviewedCards: reviewedCards,
      rememberedCards: rememberedCards,
      subjectId: subjectId,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

VstudyUseCases _useCases([AnalyticsRepository? analytics]) {
  final unused = _Unused();
  return VstudyUseCases(
    auth: unused,
    study: unused,
    documents: unused,
    quizzes: unused,
    assistant: unused,
    analytics: analytics,
  );
}

void main() {
  test(
    'week begins Monday and excludes next Monday, including a Sunday anchor',
    () {
      final window = analyticsWindow(
        AnalyticsPeriod.week,
        DateTime(2026, 11, 8, 23, 59),
        _goals(),
      );
      expect(window.from, DateTime(2026, 11, 2));
      expect(window.to, DateTime(2026, 11, 9));
      expect(window.previousFrom, DateTime(2026, 10, 26));
      expect(window.previousTo, window.from);
    },
  );

  test('month windows respect leap February and the prior calendar month', () {
    final feb = analyticsWindow(
      AnalyticsPeriod.month,
      DateTime(2024, 2, 29),
      _goals(),
    );
    expect(feb.from, DateTime(2024, 2));
    expect(feb.to, DateTime(2024, 3));
    expect(feb.previousFrom, DateTime(2024, 1));
    final march = analyticsWindow(
      AnalyticsPeriod.month,
      DateTime(2024, 3, 15),
      _goals(),
    );
    expect(march.previousFrom, DateTime(2024, 2));
    expect(march.previousTo, DateTime(2024, 3));
  });

  test(
    'configured semester is authoritative and prior term has equal days',
    () {
      final goals = _goals(
        start: DateTime(2026, 8, 15),
        end: DateTime(2026, 12, 15),
      );
      final window = analyticsWindow(
        AnalyticsPeriod.semester,
        DateTime(2030),
        goals,
      );
      expect(window.from, DateTime(2026, 8, 15));
      expect(window.to, DateTime(2026, 12, 15));
      expect(window.previousFrom, DateTime(2026, 4, 15));
      expect(window.previousTo, window.from);
      expect(
        () => analyticsWindow(
          AnalyticsPeriod.semester,
          _now,
          _goals(start: _now, end: _now),
        ),
        throwsArgumentError,
      );
    },
  );

  test('January academic defaults continue the prior August semester', () {
    final january = LearningGoals.defaults(DateTime(2027, 1, 31));
    expect(january.semesterStart, DateTime(2026, 8));
    expect(january.semesterEnd, DateTime(2027, 2));
    expect(
      LearningGoals.defaults(DateTime(2027, 2, 1)).semesterEnd,
      DateTime(2027, 8),
    );
  });

  test('empty measurements keep missing ratios null and days explicit', () {
    final report = buildAnalyticsReport(_snapshot(), AnalyticsPeriod.week);
    expect(report.study.totalMinutes, 0);
    expect(report.study.dailyMinutes, hasLength(7));
    expect(report.changePercent, isNull);
    expect(report.focusPercent, isNull);
    expect(report.rememberPercent, isNull);
    expect(report.bestDay, isNull);
    expect(
      report.quizDailyScores.every((point) => point.percent == null),
      isTrue,
    );
    expect(report.dailyFlashcards.every((point) => point.count == 0), isTrue);
    expect(report.longestStreak, 0);
  });

  test(
    'study intervals split at midnight and clip to exclusive window bounds',
    () {
      final report = buildAnalyticsReport(
        _snapshot(
          now: DateTime(2026, 11, 10),
          sessions: [
            _session(DateTime(2026, 11, 1, 23, 30), 90),
            _session(DateTime(2026, 11, 8, 23, 30), 90),
            _session(DateTime(2026, 11, 9, 1), 60),
          ],
        ),
        AnalyticsPeriod.week,
        anchor: DateTime(2026, 11, 4),
      );
      expect(report.study.totalMinutes, 90);
      expect(report.study.dailyMinutes.first.minutes, 60);
      expect(report.study.dailyMinutes.last.minutes, 30);
      expect(report.previousStudyMinutes, 30);
      expect(report.changePercent, 200);
    },
  );

  test(
    'UTC wire timestamps retain their device-local day after conversion',
    () {
      final local = DateTime(2026, 11, 3, 23, 30);
      final wire = local.toUtc();
      final report = buildAnalyticsReport(
        _snapshot(
          sessions: [_session(wire, 60)],
          attempts: [_attempt(wire, 8, 10)],
          flashcards: [
            FlashcardSession(
              id: 'wire',
              reviewedAt: wire,
              reviewedCards: 20,
              rememberedCards: 10,
            ),
          ],
        ),
        AnalyticsPeriod.week,
        anchor: _now.toUtc(),
      );
      expect(report.window.from, DateTime(2026, 11, 2));
      expect(report.study.dailyMinutes[1].minutes, 30);
      expect(report.study.dailyMinutes[2].minutes, 30);
      expect(report.quizDailyScores[1].percent, 80);
      expect(report.dailyFlashcards[1].count, 20);
    },
  );

  test(
    'timestamped events include the first boundary and exclude the next',
    () {
      final monday = DateTime(2026, 11, 2);
      final nextMonday = DateTime(2026, 11, 9);
      final report = buildAnalyticsReport(
        _snapshot(
          now: DateTime(2026, 11, 10),
          attempts: [
            _attempt(monday, 8, 10),
            _attempt(monday.subtract(const Duration(microseconds: 1)), 0, 10),
            _attempt(nextMonday, 0, 10),
          ],
          flashcards: [
            FlashcardSession(
              id: 'start',
              reviewedAt: monday,
              reviewedCards: 10,
              rememberedCards: 5,
            ),
            FlashcardSession(
              id: 'end',
              reviewedAt: nextMonday,
              reviewedCards: 100,
              rememberedCards: 100,
            ),
          ],
          tasks: [
            LearningTask(date: monday, completed: true),
            LearningTask(date: nextMonday, completed: false),
          ],
        ),
        AnalyticsPeriod.week,
        anchor: _now,
      );
      expect(report.quizAttempts, hasLength(1));
      expect(report.quizCorrect, 8);
      expect(report.flashcardReviewed, 10);
      expect(report.tasksCompleted, 1);
      expect(report.tasksTotal, 1);
    },
  );

  test(
    'partially elapsed study clips at now but unfinished focus is excluded',
    () {
      final report = buildAnalyticsReport(
        _snapshot(
          sessions: [
            _session(DateTime(2026, 11, 4, 11, 30), 90),
            _session(DateTime(2026, 11, 5, 8), 60),
          ],
          focus: [
            FocusSession(
              id: 'unfinished',
              startedAt: DateTime(2026, 11, 4, 11, 30),
              plannedMinutes: 90,
              focusedMinutes: 60,
            ),
          ],
        ),
        AnalyticsPeriod.week,
      );
      expect(report.study.totalMinutes, 30);
      expect(report.study.dailyMinutes[2].minutes, 30);
      expect(report.study.dailyMinutes[3].minutes, 0);
      expect(report.focusSessions, isEmpty);
      expect(report.focusPercent, isNull);
    },
  );

  test(
    'future attempts, flashcard reviews and checklist tasks do not count',
    () {
      final future = _now.add(const Duration(minutes: 1));
      final report = buildAnalyticsReport(
        _snapshot(
          attempts: [_attempt(future, 10, 10)],
          flashcards: [
            FlashcardSession(
              id: 'future',
              reviewedAt: future,
              reviewedCards: 10,
              rememberedCards: 10,
            ),
          ],
          tasks: [LearningTask(date: future, completed: true)],
        ),
        AnalyticsPeriod.week,
      );
      expect(report.quizAttempts, isEmpty);
      expect(report.study.quizAttempts, 0);
      expect(report.flashcardReviewed, 0);
      expect(report.tasksTotal, 0);
    },
  );

  test(
    'subject filtering applies to every metric and resolves quiz ownership',
    () {
      final at = DateTime(2026, 11, 3, 8);
      final report = buildAnalyticsReport(
        _snapshot(
          sessions: [
            _session(at, 40),
            _session(at, 100, subject: 'b'),
            _session(at, 80, subject: null),
          ],
          quizzes: [_quiz('quiz-a', 'a'), _quiz('quiz-b', 'b')],
          attempts: [
            _attempt(at, 8, 10),
            _attempt(at, 0, 10, quiz: 'quiz-b'),
            _attempt(at, 0, 10, quiz: 'deleted-quiz'),
          ],
          focus: [
            for (final subject in ['a', 'b'])
              FocusSession(
                id: subject,
                startedAt: at,
                plannedMinutes: 60,
                focusedMinutes: subject == 'a' ? 30 : 0,
                subjectId: subject,
              ),
          ],
          flashcards: [
            for (final subject in ['a', 'b'])
              FlashcardSession(
                id: subject,
                reviewedAt: at,
                reviewedCards: 20,
                rememberedCards: 10,
                subjectId: subject,
              ),
          ],
          tasks: [
            LearningTask(date: at, completed: true, subjectId: 'a'),
            LearningTask(date: at, completed: false, subjectId: 'b'),
          ],
          mastery: [
            for (final subject in ['a', 'b'])
              ChapterMastery(
                id: subject,
                subjectId: subject,
                title: subject,
                position: 0,
                totalQuestions: 10,
                answeredQuestions: 5,
                correctQuestions: 4,
              ),
          ],
        ),
        AnalyticsPeriod.week,
        subjectId: 'a',
      );
      expect(report.study.totalMinutes, 40);
      expect(report.study.averageQuizPercent, 80);
      expect(report.quizAttempts.single.quizId, 'quiz-a');
      expect(report.quizCorrect, 8);
      expect(report.quizWrong, 2);
      expect(report.focusPercent, 50);
      expect(report.flashcardReviewed, 20);
      expect(report.tasksCompleted, 1);
      expect(report.tasksTotal, 1);
      expect(report.chapterMastery.single.subjectId, 'a');
    },
  );

  test(
    'current and longest streak use full history while totals use chart window',
    () {
      final report = buildAnalyticsReport(
        _snapshot(
          sessions: [
            for (var day = 20; day <= 23; day++)
              _session(DateTime(2026, 10, day, 8), 10),
            _session(DateTime(2026, 11, 1, 8), 15),
            _session(DateTime(2026, 11, 2, 8), 20),
            _session(DateTime(2026, 11, 3, 8), 40),
            _session(DateTime(2026, 11, 5, 8), 100),
          ],
        ),
        AnalyticsPeriod.week,
      );
      expect(report.study.totalMinutes, 60);
      expect(report.study.currentStreakDays, 3);
      expect(report.longestStreak, 4);
      expect(report.activeDays, 2);
      expect(report.bestDay!.date, DateTime(2026, 11, 3));
      expect(report.bestDay!.minutes, 40);
    },
  );

  test(
    'focus percentage is weighted by planned minutes and ignores invalid logs',
    () {
      final at = DateTime(2026, 11, 3, 8);
      final report = buildAnalyticsReport(
        _snapshot(
          focus: [
            FocusSession(
              id: 'short',
              startedAt: at,
              plannedMinutes: 10,
              focusedMinutes: 10,
            ),
            FocusSession(
              id: 'long',
              startedAt: at,
              plannedMinutes: 90,
              focusedMinutes: 0,
            ),
            FocusSession(
              id: 'invalid',
              startedAt: at,
              plannedMinutes: 10,
              focusedMinutes: 11,
            ),
            FocusSession(
              id: 'invalid-zero',
              startedAt: at,
              plannedMinutes: 0,
              focusedMinutes: 0,
            ),
            FocusSession(
              id: 'invalid-interruptions',
              startedAt: at,
              plannedMinutes: 30,
              focusedMinutes: 30,
              interruptions: -1,
            ),
          ],
        ),
        AnalyticsPeriod.week,
      );
      expect(report.focusPercent, 10);
      expect(report.focusSessions, hasLength(2));
      expect(
        report.study.totalMinutes,
        0,
      ); // Focus does not duplicate study logs.
    },
  );

  test(
    'flashcard counts sum review events per day with weighted remembered ratio',
    () {
      final at = DateTime(2026, 11, 3, 8);
      final report = buildAnalyticsReport(
        _snapshot(
          flashcards: [
            FlashcardSession(
              id: 'first',
              reviewedAt: at,
              reviewedCards: 10,
              rememberedCards: 10,
            ),
            FlashcardSession(
              id: 'again',
              reviewedAt: at.add(const Duration(hours: 1)),
              reviewedCards: 30,
              rememberedCards: 10,
            ),
            FlashcardSession(
              id: 'invalid',
              reviewedAt: at,
              reviewedCards: 5,
              rememberedCards: 6,
            ),
          ],
        ),
        AnalyticsPeriod.week,
      );
      expect(report.flashcardReviewed, 40);
      expect(report.flashcardRemembered, 20);
      expect(report.rememberPercent, 50);
      expect(report.dailyFlashcards[1].count, 40);
      expect(report.flashcardSessions, hasLength(2));
    },
  );

  test(
    'quiz practice and exam attempts both count; empty days remain missing',
    () {
      final at = DateTime(2026, 11, 3, 8);
      final source = [
        _attempt(at.add(const Duration(hours: 1)), 10, 10, mode: 'exam'),
        _attempt(at, 0, 2),
        _attempt(at, 5, 2, quiz: 'invalid'),
      ];
      final originalFirst = source.first;
      final report = buildAnalyticsReport(
        _snapshot(attempts: source),
        AnalyticsPeriod.week,
      );
      expect(report.quizAttempts.map((a) => a.mode), ['practice', 'exam']);
      expect(report.quizCorrect, 10);
      expect(report.quizWrong, 2);
      expect(
        report.study.averageQuizPercent,
        50,
      ); // Mean attempt score, not question-weighted.
      expect(report.quizDailyScores[1].percent, 50);
      expect(report.quizDailyScores[0].percent, isNull);
      expect(
        identical(source.first, originalFirst),
        isTrue,
      ); // Input order is preserved.
    },
  );

  test(
    'semester weekly buckets include only study inside configured boundaries',
    () {
      final report = buildAnalyticsReport(
        _snapshot(
          now: DateTime(2026, 11, 20),
          goals: _goals(
            start: DateTime(2026, 11, 4),
            end: DateTime(2026, 11, 11),
          ),
          sessions: [
            _session(DateTime(2026, 11, 3, 23, 30), 90),
            _session(DateTime(2026, 11, 9, 8), 40),
            _session(DateTime(2026, 11, 11, 8), 90),
          ],
        ),
        AnalyticsPeriod.semester,
      );
      expect(report.study.totalMinutes, 100);
      expect(report.weeklyMinutes.map((d) => d.date), [
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 9),
      ]);
      expect(report.weeklyMinutes.map((d) => d.minutes), [60, 40]);
    },
  );

  test(
    'goal bounds and semester dates reject invalid input before writing',
    () async {
      final repository = _RecordingAnalytics();
      final useCases = _useCases(repository);
      final invalid = [
        _goals(weeklyMinutes: 59),
        _goals(weeklyMinutes: 10081),
        _goals(studyDays: 0),
        _goals(studyDays: 8),
        _goals(flashcards: 0),
        _goals(flashcards: 1001),
        _goals(start: DateTime(2026, 8), end: DateTime(2026, 8, 7)),
        _goals(start: DateTime(2026, 8), end: DateTime(2027, 8, 3)),
        _goals(start: DateTime(2026, 8, 1, 1)),
        _goals(end: DateTime(2026, 7)),
      ];
      for (final goals in invalid) {
        expect(
          () => useCases.saveLearningGoals(goals),
          throwsA(isA<AppException>()),
        );
      }
      expect(repository.savedGoals, isNull);
      await useCases.saveLearningGoals(
        _goals(
          weeklyMinutes: 60,
          studyDays: 1,
          flashcards: 1,
          start: DateTime.utc(2026, 8),
          end: DateTime.utc(2026, 8, 8),
        ),
      );
      expect(repository.savedGoals!.semesterStart, DateTime(2026, 8));
      expect(repository.savedGoals!.semesterEnd, DateTime(2026, 8, 8));
      expect(repository.savedGoals!.weeklyMinutes, 60);
    },
  );

  test(
    'goal validation accepts upper limits and a 366-day academic range',
    () async {
      final repository = _RecordingAnalytics();
      await _useCases(repository).saveLearningGoals(
        _goals(
          weeklyMinutes: 10080,
          studyDays: 7,
          flashcards: 1000,
          start: DateTime(2024, 1),
          end: DateTime(2025, 1, 1),
        ),
      );
      expect(repository.savedGoals!.flashcardsPerDay, 1000);
    },
  );

  test(
    'focus validates counts and completion time independently of repository',
    () async {
      final repository = _RecordingAnalytics();
      final useCases = _useCases(repository);
      final yesterday = DateTime.now().subtract(const Duration(days: 2));
      for (final values in [
        [0, 0, 0],
        [1441, 0, 0],
        [30, -1, 0],
        [30, 31, 0],
        [30, 20, -1],
        [30, 20, 1001],
      ]) {
        expect(
          () => useCases.logFocusSession(
            startedAt: yesterday,
            plannedMinutes: values[0],
            focusedMinutes: values[1],
            interruptions: values[2],
          ),
          throwsA(isA<AppException>()),
        );
      }
      expect(
        () => useCases.logFocusSession(
          startedAt: DateTime.now(),
          plannedMinutes: 30,
          focusedMinutes: 20,
          interruptions: 0,
        ),
        throwsA(isA<AppException>()),
      );
      expect(repository.focus, isNull);
      await useCases.logFocusSession(
        startedAt: yesterday,
        plannedMinutes: 1440,
        focusedMinutes: 1440,
        interruptions: 1000,
        subjectId: 'a',
      );
      expect(repository.focus!.subjectId, 'a');
      expect(repository.focus!.focusedMinutes, 1440);
    },
  );

  test(
    'flashcard validation rejects future and impossible reviews before writing',
    () async {
      final repository = _RecordingAnalytics();
      final useCases = _useCases(repository);
      final past = DateTime.now().subtract(const Duration(hours: 1));
      for (final values in [
        [0, 0],
        [10001, 0],
        [10, -1],
        [10, 11],
      ]) {
        expect(
          () => useCases.logFlashcardSession(
            reviewedAt: past,
            reviewedCards: values[0],
            rememberedCards: values[1],
          ),
          throwsA(isA<AppException>()),
        );
      }
      expect(
        () => useCases.logFlashcardSession(
          reviewedAt: DateTime.now().add(const Duration(days: 1)),
          reviewedCards: 10,
          rememberedCards: 10,
        ),
        throwsA(isA<AppException>()),
      );
      expect(repository.flashcard, isNull);
      await useCases.logFlashcardSession(
        reviewedAt: past,
        reviewedCards: 10000,
        rememberedCards: 0,
        subjectId: 'a',
      );
      expect(repository.flashcard!.reviewedCards, 10000);
      expect(repository.flashcard!.rememberedCards, 0);
      expect(repository.flashcard!.subjectId, 'a');
    },
  );

  test(
    'optional analytics gives a user-facing error for unsupported saves',
    () {
      final useCases = _useCases();
      expect(
        () => useCases.saveLearningGoals(_goals()),
        throwsA(isA<AppException>()),
      );
      final past = DateTime.now().subtract(const Duration(hours: 2));
      expect(
        () => useCases.logFocusSession(
          startedAt: past,
          plannedMinutes: 30,
          focusedMinutes: 20,
          interruptions: 0,
        ),
        throwsA(isA<AppException>()),
      );
      expect(
        () => useCases.logFlashcardSession(
          reviewedAt: past,
          reviewedCards: 20,
          rememberedCards: 10,
        ),
        throwsA(isA<AppException>()),
      );
    },
  );
}
