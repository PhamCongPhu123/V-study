import 'entities.dart';
import 'study_metrics.dart';

enum AnalyticsPeriod { week, month, semester }

class LearningGoals {
  const LearningGoals({
    this.weeklyMinutes = 900,
    this.studyDaysPerWeek = 5,
    this.flashcardsPerDay = 20,
    required this.semesterStart,
    required this.semesterEnd,
  });
  final int weeklyMinutes;
  final int studyDaysPerWeek;
  final int flashcardsPerDay;
  final DateTime semesterStart;

  /// Exclusive local calendar date.
  final DateTime semesterEnd;

  factory LearningGoals.defaults(DateTime now) {
    final local = now.toLocal();
    final start = local.month >= 8
        ? DateTime(local.year, 8)
        : local.month >= 2
        ? DateTime(local.year, 2)
        : DateTime(local.year - 1, 8);
    return LearningGoals(
      semesterStart: start,
      semesterEnd: DateTime(start.year, start.month + 6),
    );
  }
}

class FocusSession {
  const FocusSession({
    required this.id,
    required this.startedAt,
    required this.plannedMinutes,
    required this.focusedMinutes,
    this.interruptions = 0,
    this.subjectId,
  });
  final String id;
  final DateTime startedAt;
  final int plannedMinutes;
  final int focusedMinutes;
  final int interruptions;
  final String? subjectId;
}

class FlashcardSession {
  const FlashcardSession({
    required this.id,
    required this.reviewedAt,
    required this.reviewedCards,
    required this.rememberedCards,
    this.subjectId,
  });
  final String id;
  final DateTime reviewedAt;
  final int reviewedCards;
  final int rememberedCards;
  final String? subjectId;
}

class LearningTask {
  const LearningTask({
    required this.date,
    required this.completed,
    this.subjectId,
  });
  final DateTime date;
  final bool completed;
  final String? subjectId;
}

class ChapterMastery {
  const ChapterMastery({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.position,
    required this.totalQuestions,
    required this.answeredQuestions,
    required this.correctQuestions,
  });
  final String id;
  final String subjectId;
  final String title;
  final int position;
  final int totalQuestions;
  final int answeredQuestions;
  final int correctQuestions;
  double get percent =>
      totalQuestions == 0 ? 0 : correctQuestions * 100 / totalQuestions;
}

class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.now,
    required this.profile,
    required this.goals,
    this.subjects = const [],
    this.studySessions = const [],
    this.quizAttempts = const [],
    this.quizzes = const [],
    this.focusSessions = const [],
    this.flashcardSessions = const [],
    this.tasks = const [],
    this.chapterMastery = const [],
  });
  final DateTime now;
  final Profile profile;
  final LearningGoals goals;
  final List<Subject> subjects;
  final List<StudySession> studySessions;
  final List<QuizAttempt> quizAttempts;
  final List<Quiz> quizzes;
  final List<FocusSession> focusSessions;
  final List<FlashcardSession> flashcardSessions;
  final List<LearningTask> tasks;
  final List<ChapterMastery> chapterMastery;
}

class AnalyticsWindow {
  const AnalyticsWindow({
    required this.from,
    required this.to,
    required this.previousFrom,
    required this.previousTo,
  });
  final DateTime from;
  final DateTime to;
  final DateTime previousFrom;
  final DateTime previousTo;
}

class ScorePoint {
  const ScorePoint({required this.date, required this.percent});
  final DateTime date;
  final double? percent;
}

class DailyCount {
  const DailyCount({required this.date, required this.count});
  final DateTime date;
  final int count;
}

class AnalyticsReport {
  const AnalyticsReport({
    required this.window,
    required this.study,
    required this.previousStudyMinutes,
    required this.changePercent,
    required this.focusPercent,
    required this.bestDay,
    required this.activeDays,
    required this.longestStreak,
    required this.quizAttempts,
    required this.quizCorrect,
    required this.quizWrong,
    required this.quizDailyScores,
    required this.weeklyMinutes,
    required this.chapterMastery,
    required this.flashcardReviewed,
    required this.flashcardRemembered,
    required this.dailyFlashcards,
    required this.tasksCompleted,
    required this.tasksTotal,
    required this.focusSessions,
    required this.flashcardSessions,
  });
  final AnalyticsWindow window;
  final StudyStatistics study;
  final int previousStudyMinutes;
  final double? changePercent;
  final double? focusPercent;
  final DailyMinutes? bestDay;
  final int activeDays;
  final int longestStreak;
  final List<QuizAttempt> quizAttempts;
  final int quizCorrect;
  final int quizWrong;
  final List<ScorePoint> quizDailyScores;
  final List<DailyMinutes> weeklyMinutes;
  final List<ChapterMastery> chapterMastery;
  final int flashcardReviewed;
  final int flashcardRemembered;
  final List<DailyCount> dailyFlashcards;
  final int tasksCompleted;
  final int tasksTotal;
  final List<FocusSession> focusSessions;
  final List<FlashcardSession> flashcardSessions;
  double? get rememberPercent => flashcardReviewed == 0
      ? null
      : flashcardRemembered * 100 / flashcardReviewed;
}

int _calendarDays(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

AnalyticsWindow analyticsWindow(
  AnalyticsPeriod period,
  DateTime anchor,
  LearningGoals goals,
) {
  final day = localDay(anchor);
  late DateTime from;
  late DateTime to;
  late DateTime previous;
  switch (period) {
    case AnalyticsPeriod.week:
      from = DateTime(day.year, day.month, day.day - day.weekday + 1);
      to = DateTime(from.year, from.month, from.day + 7);
      previous = DateTime(from.year, from.month, from.day - 7);
    case AnalyticsPeriod.month:
      from = DateTime(day.year, day.month);
      to = DateTime(day.year, day.month + 1);
      previous = DateTime(day.year, day.month - 1);
    case AnalyticsPeriod.semester:
      // The configured academic term is authoritative; changing a chart anchor
      // must not silently rewrite the student's semester boundaries.
      // A semester is stored as SQL dates; preserve their calendar components
      // even when a caller represents a date with a UTC DateTime.
      from = DateTime(
        goals.semesterStart.year,
        goals.semesterStart.month,
        goals.semesterStart.day,
      );
      to = DateTime(
        goals.semesterEnd.year,
        goals.semesterEnd.month,
        goals.semesterEnd.day,
      );
      previous = DateTime(
        from.year,
        from.month,
        from.day - _calendarDays(from, to),
      );
  }
  if (!to.isAfter(from)) {
    throw ArgumentError('Invalid analytics date window');
  }
  return AnalyticsWindow(
    from: from,
    to: to,
    previousFrom: previous,
    previousTo: from,
  );
}

/// Aggregates actual logged history. Missing measurements remain null, not zero
/// accuracy. All display-day keys use device-local calendar dates.
AnalyticsReport buildAnalyticsReport(
  AnalyticsSnapshot snapshot,
  AnalyticsPeriod period, {
  DateTime? anchor,
  String? subjectId,
}) {
  final window = analyticsWindow(
    period,
    anchor ?? snapshot.now,
    snapshot.goals,
  );
  final now = snapshot.now;
  final sessions = snapshot.studySessions
      .where((s) => subjectId == null || s.subjectId == subjectId)
      .toList();
  final allowedQuizIds = snapshot.quizzes
      .where((q) => subjectId == null || q.subjectId == subjectId)
      .map((q) => q.id)
      .toSet();
  final attempts = snapshot.quizAttempts
      .where(
        (a) =>
            (subjectId == null || allowedQuizIds.contains(a.quizId)) &&
            a.totalQuestions > 0 &&
            a.correctCount >= 0 &&
            a.correctCount <= a.totalQuestions,
      )
      .toList();
  final study = calculateStudyStatistics(
    sessions: sessions,
    attempts: attempts,
    from: window.from,
    to: window.to,
    now: now,
  );
  final previous = calculateStudyStatistics(
    sessions: sessions,
    attempts: attempts,
    from: window.previousFrom,
    to: window.previousTo,
    now: now,
  );
  bool inWindow(DateTime time) =>
      !time.isBefore(window.from) &&
      time.isBefore(window.to) &&
      !time.isAfter(now);
  final completed = attempts.where((a) => inWindow(a.submittedAt)).toList()
    ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
  final focus = snapshot.focusSessions
      .where(
        (s) =>
            (subjectId == null || s.subjectId == subjectId) &&
            inWindow(s.startedAt) &&
            s.plannedMinutes > 0 &&
            s.plannedMinutes <= 1440 &&
            s.focusedMinutes >= 0 &&
            s.focusedMinutes <= s.plannedMinutes &&
            s.interruptions >= 0 &&
            s.interruptions <= 1000 &&
            !s.startedAt.add(Duration(minutes: s.plannedMinutes)).isAfter(now),
      )
      .toList();
  final flashcards = snapshot.flashcardSessions
      .where(
        (s) =>
            (subjectId == null || s.subjectId == subjectId) &&
            inWindow(s.reviewedAt) &&
            s.reviewedCards > 0 &&
            s.reviewedCards <= 10000 &&
            s.rememberedCards >= 0 &&
            s.rememberedCards <= s.reviewedCards,
      )
      .toList();
  final tasks = snapshot.tasks
      .where(
        (t) =>
            (subjectId == null || t.subjectId == subjectId) && inWindow(t.date),
      )
      .toList();
  final scoreMap = <DateTime, List<double>>{};
  for (final attempt in completed) {
    (scoreMap[localDay(attempt.submittedAt)] ??= []).add(attempt.percent);
  }
  final flashMap = <DateTime, int>{};
  for (final session in flashcards) {
    flashMap.update(
      localDay(session.reviewedAt),
      (v) => v + session.reviewedCards,
      ifAbsent: () => session.reviewedCards,
    );
  }
  final scorePoints = <ScorePoint>[];
  final dailyFlashcards = <DailyCount>[];
  for (
    var day = window.from;
    day.isBefore(window.to);
    day = nextLocalDay(day)
  ) {
    final scores = scoreMap[day];
    scorePoints.add(
      ScorePoint(
        date: day,
        percent: scores == null
            ? null
            : scores.fold<double>(0, (sum, score) => sum + score) /
                  scores.length,
      ),
    );
    dailyFlashcards.add(DailyCount(date: day, count: flashMap[day] ?? 0));
  }
  DailyMinutes? best;
  for (final day in study.dailyMinutes) {
    if (day.minutes > 0 && (best == null || day.minutes > best.minutes)) {
      best = day;
    }
  }
  final weekly = <DateTime, int>{};
  for (final day in study.dailyMinutes) {
    final monday = DateTime(
      day.date.year,
      day.date.month,
      day.date.day - day.date.weekday + 1,
    );
    weekly.update(monday, (v) => v + day.minutes, ifAbsent: () => day.minutes);
  }
  final activeDays = <DateTime>{};
  for (final session in sessions) {
    if (session.durationMinutes <= 0) {
      continue;
    }
    final start = session.startedAt.toLocal();
    final recordedEnd = start.add(Duration(minutes: session.durationMinutes));
    final end = recordedEnd.isAfter(now) ? now.toLocal() : recordedEnd;
    for (
      var cursor = start;
      cursor.isBefore(end);
      cursor = nextLocalDay(cursor)
    ) {
      activeDays.add(localDay(cursor));
    }
  }
  final sortedDays = activeDays.toList()..sort();
  var longest = 0;
  var running = 0;
  DateTime? last;
  for (final day in sortedDays) {
    running = last != null && _calendarDays(last, day) == 1 ? running + 1 : 1;
    if (running > longest) {
      longest = running;
    }
    last = day;
  }
  final planned = focus.fold<int>(0, (sum, s) => sum + s.plannedMinutes);
  final focused = focus.fold<int>(0, (sum, s) => sum + s.focusedMinutes);
  return AnalyticsReport(
    window: window,
    study: study,
    previousStudyMinutes: previous.totalMinutes,
    changePercent: previous.totalMinutes == 0
        ? null
        : (study.totalMinutes - previous.totalMinutes) *
              100 /
              previous.totalMinutes,
    focusPercent: planned == 0 ? null : focused * 100 / planned,
    bestDay: best,
    activeDays: study.dailyMinutes.where((d) => d.minutes > 0).length,
    longestStreak: longest,
    quizAttempts: List.unmodifiable(completed),
    quizCorrect: completed.fold<int>(0, (sum, a) => sum + a.correctCount),
    quizWrong: completed.fold<int>(
      0,
      (sum, a) => sum + a.totalQuestions - a.correctCount,
    ),
    quizDailyScores: List.unmodifiable(scorePoints),
    weeklyMinutes: weekly.entries
        .map((e) => DailyMinutes(date: e.key, minutes: e.value))
        .toList(),
    chapterMastery: snapshot.chapterMastery
        .where((c) => subjectId == null || c.subjectId == subjectId)
        .toList(),
    flashcardReviewed: flashcards.fold<int>(
      0,
      (sum, s) => sum + s.reviewedCards,
    ),
    flashcardRemembered: flashcards.fold<int>(
      0,
      (sum, s) => sum + s.rememberedCards,
    ),
    dailyFlashcards: List.unmodifiable(dailyFlashcards),
    tasksCompleted: tasks.where((t) => t.completed).length,
    tasksTotal: tasks.length,
    focusSessions: List.unmodifiable(focus),
    flashcardSessions: List.unmodifiable(flashcards),
  );
}
