import 'package:flutter_test/flutter_test.dart';
import 'package:vstudy/domain/entities.dart';
import 'package:vstudy/domain/study_metrics.dart';

void main() {
  StudySession session(
    String id,
    DateTime start,
    int minutes, [
    String? subject,
  ]) => StudySession(
    id: id,
    startedAt: start,
    durationMinutes: minutes,
    subjectId: subject,
  );

  QuizAttempt attempt(String id, DateTime date, int correct, int total) =>
      QuizAttempt(
        id: id,
        quizId: 'quiz-$id',
        correctCount: correct,
        totalQuestions: total,
        submittedAt: date,
      );

  test('splits an actual session across midnight and clips to [from,to)', () {
    final metrics = calculateStudyStatistics(
      sessions: [
        session('cross-midnight', DateTime(2026, 11, 2, 23, 30), 90, 'math'),
      ],
      attempts: const [],
      from: DateTime(2026, 11, 3),
      to: DateTime(2026, 11, 4),
      now: DateTime(2026, 11, 4, 12),
    );
    expect(metrics.totalMinutes, 60);
    expect(metrics.dailyMinutes.single.minutes, 60);
    expect(metrics.minutesBySubject, {'math': 60});
    expect(metrics.currentStreakDays, 2);
  });

  test(
    'keeps yesterday streak, includes pre-window history and stops at a gap',
    () {
      final metrics = calculateStudyStatistics(
        sessions: [
          session('old', DateTime(2026, 10, 30, 9), 15),
          session('nov1', DateTime(2026, 11, 1, 9), 20),
          session('nov2', DateTime(2026, 11, 2, 9), 20),
          session('nov3', DateTime(2026, 11, 3, 9), 30),
        ],
        attempts: const [],
        from: DateTime(2026, 11, 3),
        to: DateTime(2026, 11, 5),
        now: DateTime(2026, 11, 4, 8),
      );
      expect(metrics.totalMinutes, 30);
      expect(metrics.currentStreakDays, 3);
      expect(metrics.dailyMinutes.map((day) => day.minutes), [30, 0]);
    },
  );

  test('does not count future logged intervals or future quiz submissions', () {
    final metrics = calculateStudyStatistics(
      sessions: [
        session('past', DateTime(2026, 11, 3, 9), 45),
        session('future', DateTime(2026, 11, 3, 15), 60),
      ],
      attempts: [attempt('later', DateTime(2026, 11, 3, 16), 10, 10)],
      from: DateTime(2026, 11, 3),
      to: DateTime(2026, 11, 4),
      now: DateTime(2026, 11, 3, 12),
    );
    expect(metrics.totalMinutes, 45);
    expect(metrics.quizAttempts, 0);
    expect(metrics.averageQuizPercent, 0);
    expect(metrics.minutesBySubject, {'unassigned': 45});
  });

  test(
    'clips unfinished sessions at now instead of claiming future study time',
    () {
      final metrics = calculateStudyStatistics(
        sessions: [session('ongoing', DateTime(2026, 11, 3, 11, 45), 60)],
        attempts: const [],
        from: DateTime(2026, 11, 3),
        to: DateTime(2026, 11, 4),
        now: DateTime(2026, 11, 3, 12),
      );
      expect(metrics.totalMinutes, 15);
    },
  );

  test('counts submitted attempts in range and averages quiz percentages', () {
    final metrics = calculateStudyStatistics(
      sessions: const [],
      attempts: [
        attempt('before', DateTime(2026, 11, 2, 23, 59), 10, 10),
        attempt('start', DateTime(2026, 11, 3), 9, 10),
        attempt('second', DateTime(2026, 11, 3, 10), 2, 5),
        attempt('end', DateTime(2026, 11, 4), 10, 10),
      ],
      from: DateTime(2026, 11, 3),
      to: DateTime(2026, 11, 4),
      now: DateTime(2026, 11, 5),
    );
    expect(metrics.quizAttempts, 2);
    expect(metrics.averageQuizPercent, 65);
    expect(metrics.currentStreakDays, 0);
    expect(metrics.totalMinutes, 0);
  });

  test('preserves sub-minute overlaps until aggregation', () {
    final metrics = calculateStudyStatistics(
      sessions: [
        session('a', DateTime(2026, 11, 3, 10, 0, 30), 1),
        session('b', DateTime(2026, 11, 3, 10, 0, 30), 1),
      ],
      attempts: const [],
      from: DateTime(2026, 11, 3, 10, 1),
      to: DateTime(2026, 11, 3, 10, 2),
      now: DateTime(2026, 11, 4),
    );
    expect(metrics.totalMinutes, 1);
    expect(metrics.dailyMinutes.single.minutes, 1);
  });

  test('rejects inverted date windows', () {
    expect(
      () => calculateStudyStatistics(
        sessions: const [],
        attempts: const [],
        from: DateTime(2026, 11, 4),
        to: DateTime(2026, 11, 3),
        now: DateTime(2026, 11, 4),
      ),
      throwsArgumentError,
    );
  });
}
