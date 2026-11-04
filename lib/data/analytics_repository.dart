import '../domain/analytics.dart';
import '../domain/analytics_repository.dart';
import '../domain/entities.dart';
import 'data_support.dart';

/// Loads recorded learning activity without fetching private quiz answer keys.
class SupabaseAnalyticsRepository extends SupabaseAccess
    implements AnalyticsRepository {
  const SupabaseAnalyticsRepository(super.client);

  @override
  Future<AnalyticsSnapshot> loadSnapshot({required DateTime now}) =>
      protect(() async {
        final owner = ownerId;
        final until = now.toUtc().toIso8601String();
        final results = await Future.wait<Object>([
          client
              .from('profiles')
              .select()
              .eq('id', owner)
              .single()
              .then(profileFromJson),
          client
              .from('study_goals')
              .select()
              .eq('owner_id', owner)
              .maybeSingle()
              .then(
                (row) => row == null
                    ? LearningGoals.defaults(now)
                    : _goalsFromJson(row),
              ),
          loadPages(
            (from, to) => client
                .from('subjects')
                .select()
                .eq('owner_id', owner)
                .order('name')
                .order('id')
                .range(from, to),
          ),
          // Keep all prior sessions, including before the selected semester,
          // so that an existing streak is never truncated by a chart window.
          loadPages(
            (from, to) => client
                .from('study_sessions')
                .select()
                .eq('owner_id', owner)
                .lte('started_at', until)
                .order('started_at')
                .order('id')
                .range(from, to),
          ),
          loadPages(
            (from, to) => client
                .from('quizzes')
                .select()
                .eq('owner_id', owner)
                .order('created_at')
                .order('id')
                .range(from, to),
          ),
          loadPages(
            (from, to) => client
                .from('quiz_attempts')
                .select(
                  'id,quiz_id,correct_count,total_questions,submitted_at,mode',
                )
                .eq('owner_id', owner)
                .lte('submitted_at', until)
                .order('submitted_at')
                .order('id')
                .range(from, to),
          ),
          loadPages(
            (from, to) => client
                .from('focus_sessions')
                .select()
                .eq('owner_id', owner)
                .lte('started_at', until)
                .order('started_at')
                .order('id')
                .range(from, to),
          ),
          loadPages(
            (from, to) => client
                .from('flashcard_sessions')
                .select()
                .eq('owner_id', owner)
                .lte('reviewed_at', until)
                .order('reviewed_at')
                .order('id')
                .range(from, to),
          ),
          loadPages(
            (from, to) => client
                .from('study_events')
                .select('id,subject_id,starts_at,event_tasks(is_completed)')
                .eq('owner_id', owner)
                .lte('starts_at', until)
                .order('starts_at')
                .order('id')
                .range(from, to),
          ),
          loadPages((from, to) async {
            final response = await client
                .rpc('get_chapter_mastery', params: {'p_until': until})
                .order('subject_id')
                .order('position')
                .order('id')
                .range(from, to);
            return (response as List).map(jsonObject).toList(growable: false);
          }),
        ]);
        List<Map<String, dynamic>> rows(int index) =>
            results[index] as List<Map<String, dynamic>>;
        return AnalyticsSnapshot(
          now: now.toLocal(),
          profile: results[0] as Profile,
          goals: results[1] as LearningGoals,
          subjects: rows(2).map(subjectFromJson).toList(growable: false),
          studySessions: rows(3).map(sessionFromJson).toList(growable: false),
          quizzes: rows(4).map(quizFromJson).toList(growable: false),
          quizAttempts: rows(5).map(attemptFromJson).toList(growable: false),
          focusSessions: rows(6).map(_focusFromJson).toList(growable: false),
          flashcardSessions: rows(
            7,
          ).map(_flashcardFromJson).toList(growable: false),
          tasks: [
            for (final event in rows(8))
              for (final value in event['event_tasks'] as List? ?? const [])
                LearningTask(
                  date: localTimestamp(event['starts_at']),
                  completed: jsonObject(value)['is_completed'] as bool,
                  subjectId: event['subject_id'] as String?,
                ),
          ],
          chapterMastery: rows(9).map(_masteryFromJson).toList(growable: false),
        );
      });

  @override
  Future<void> saveGoals(LearningGoals goals) => protect(() async {
    await client.from('study_goals').upsert({
      'owner_id': ownerId,
      'weekly_minutes': goals.weeklyMinutes,
      'study_days_per_week': goals.studyDaysPerWeek,
      'flashcards_per_day': goals.flashcardsPerDay,
      'semester_start': _calendarDate(goals.semesterStart),
      'semester_end': _calendarDate(goals.semesterEnd),
    }, onConflict: 'owner_id');
  });

  @override
  Future<void> logFocusSession({
    required DateTime startedAt,
    required int plannedMinutes,
    required int focusedMinutes,
    required int interruptions,
    String? subjectId,
  }) => protect(() async {
    // Focus is a separate measurement. Do not insert a study session here.
    await client.from('focus_sessions').insert({
      'owner_id': ownerId,
      'started_at': startedAt.toUtc().toIso8601String(),
      'planned_minutes': plannedMinutes,
      'focused_minutes': focusedMinutes,
      'interruptions': interruptions,
      'subject_id': subjectId,
    });
  });

  @override
  Future<void> logFlashcardSession({
    required DateTime reviewedAt,
    required int reviewedCards,
    required int rememberedCards,
    String? subjectId,
  }) => protect(() async {
    await client.from('flashcard_sessions').insert({
      'owner_id': ownerId,
      'reviewed_at': reviewedAt.toUtc().toIso8601String(),
      'reviewed_cards': reviewedCards,
      'remembered_cards': rememberedCards,
      'subject_id': subjectId,
    });
  });
}

// SQL DATE values are calendar dates. Neither side of this conversion changes
// timezone, unlike the timestamptz activity records above.
String _calendarDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

DateTime _dateFromJson(dynamic value) {
  final parts = (value as String).split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

LearningGoals _goalsFromJson(Map<String, dynamic> row) => LearningGoals(
  weeklyMinutes: row['weekly_minutes'] as int,
  studyDaysPerWeek: row['study_days_per_week'] as int,
  flashcardsPerDay: row['flashcards_per_day'] as int,
  semesterStart: _dateFromJson(row['semester_start']),
  semesterEnd: _dateFromJson(row['semester_end']),
);

FocusSession _focusFromJson(Map<String, dynamic> row) => FocusSession(
  id: row['id'] as String,
  subjectId: row['subject_id'] as String?,
  startedAt: localTimestamp(row['started_at']),
  plannedMinutes: row['planned_minutes'] as int,
  focusedMinutes: row['focused_minutes'] as int,
  interruptions: row['interruptions'] as int,
);

FlashcardSession _flashcardFromJson(Map<String, dynamic> row) =>
    FlashcardSession(
      id: row['id'] as String,
      subjectId: row['subject_id'] as String?,
      reviewedAt: localTimestamp(row['reviewed_at']),
      reviewedCards: row['reviewed_cards'] as int,
      rememberedCards: row['remembered_cards'] as int,
    );

ChapterMastery _masteryFromJson(Map<String, dynamic> row) => ChapterMastery(
  id: row['id'] as String,
  subjectId: row['subject_id'] as String,
  title: row['title'] as String,
  position: (row['position'] as num).toInt(),
  totalQuestions: (row['total_questions'] as num).toInt(),
  answeredQuestions: (row['answered_questions'] as num).toInt(),
  correctQuestions: (row['correct_questions'] as num).toInt(),
);
