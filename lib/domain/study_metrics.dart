import 'entities.dart';

/// Calendar days follow the device's local timezone. Wire timestamps stay UTC.
DateTime localDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime nextLocalDay(DateTime value) {
  final local = value.toLocal();
  // Calendar construction, rather than +24 hours, also handles DST days.
  return DateTime(local.year, local.month, local.day + 1);
}

/// Aggregates *logged* study intervals and completed quiz attempts.
/// Sessions crossing midnight are split, and windows are [from, to).
/// [sessions] should include history through now to compute a full streak.
StudyStatistics calculateStudyStatistics({
  required List<StudySession> sessions,
  required List<QuizAttempt> attempts,
  required DateTime from,
  required DateTime to,
  required DateTime now,
}) {
  if (!to.isAfter(from)) {
    throw ArgumentError(
      'The end of the statistics window must follow its start.',
    );
  }
  final dailyMicros = <DateTime, int>{};
  final subjectMicros = <String, int>{};
  final activeDays = <DateTime>{};
  var totalMicros = 0;
  for (final session in sessions) {
    if (session.durationMinutes <= 0) {
      continue;
    }
    final start = session.startedAt.toLocal();
    final recordedEnd = start.add(Duration(minutes: session.durationMinutes));
    final end = recordedEnd.isAfter(now) ? now.toLocal() : recordedEnd;
    if (!end.isAfter(start)) {
      continue;
    }
    var cursor = start;
    while (cursor.isBefore(end)) {
      final day = localDay(cursor);
      final boundary = nextLocalDay(cursor);
      final partEnd = boundary.isBefore(end) ? boundary : end;
      activeDays.add(day);
      final clippedStart = cursor.isBefore(from) ? from : cursor;
      final clippedEnd = partEnd.isAfter(to) ? to : partEnd;
      if (clippedEnd.isAfter(clippedStart)) {
        final micros = clippedEnd.difference(clippedStart).inMicroseconds;
        dailyMicros.update(
          day,
          (value) => value + micros,
          ifAbsent: () => micros,
        );
        final key = session.subjectId ?? 'unassigned';
        subjectMicros.update(
          key,
          (value) => value + micros,
          ifAbsent: () => micros,
        );
        totalMicros += micros;
      }
      cursor = partEnd;
    }
  }

  var streakDate = localDay(now);
  // A student does not lose yesterday's streak before studying today.
  if (!activeDays.contains(streakDate)) {
    streakDate = DateTime(
      streakDate.year,
      streakDate.month,
      streakDate.day - 1,
    );
  }
  var streak = 0;
  while (activeDays.contains(streakDate)) {
    streak++;
    streakDate = DateTime(
      streakDate.year,
      streakDate.month,
      streakDate.day - 1,
    );
  }

  final completed = attempts
      .where(
        (attempt) =>
            !attempt.submittedAt.isBefore(from) &&
            attempt.submittedAt.isBefore(to) &&
            !attempt.submittedAt.isAfter(now),
      )
      .toList(growable: false);
  final daily = <DailyMinutes>[];
  for (var day = localDay(from); day.isBefore(to); day = nextLocalDay(day)) {
    daily.add(
      DailyMinutes(
        date: day,
        minutes: (dailyMicros[day] ?? 0) ~/ Duration.microsecondsPerMinute,
      ),
    );
  }
  return StudyStatistics(
    totalMinutes: totalMicros ~/ Duration.microsecondsPerMinute,
    dailyMinutes: daily,
    quizAttempts: completed.length,
    averageQuizPercent: completed.isEmpty
        ? 0
        : completed.fold<double>(0, (sum, attempt) => sum + attempt.percent) /
              completed.length,
    currentStreakDays: streak,
    minutesBySubject: subjectMicros.map(
      (key, value) => MapEntry(key, value ~/ Duration.microsecondsPerMinute),
    ),
  );
}
