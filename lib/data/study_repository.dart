import '../core/app_exception.dart';
import '../domain/entities.dart';
import '../domain/repositories.dart';
import '../domain/study_metrics.dart';
import 'data_support.dart';

class SupabaseStudyRepository extends SupabaseAccess
    implements StudyRepository {
  const SupabaseStudyRepository(super.client);

  @override
  Future<Profile> getProfile() => protect(() async {
    final row = await client
        .from('profiles')
        .select()
        .eq('id', ownerId)
        .single();
    return profileFromJson(row);
  });

  @override
  Future<void> updateProfile({
    required String displayName,
    required int dailyGoalMinutes,
  }) => protect(() async {
    await client
        .from('profiles')
        .update({
          'display_name': displayName.trim(),
          'daily_goal_minutes': dailyGoalMinutes,
        })
        .eq('id', ownerId);
  });

  @override
  Future<List<Subject>> listSubjects() => protect(() async {
    final owner = ownerId;
    final rows = await loadPages(
      (from, to) => client
          .from('subjects')
          .select()
          .eq('owner_id', owner)
          .order('name')
          .order('id')
          .range(from, to),
    );
    return rows.map(subjectFromJson).toList(growable: false);
  });

  @override
  Future<Subject> createSubject(String name) => protect(() async {
    final row = await client
        .from('subjects')
        .insert({'owner_id': ownerId, 'name': name.trim()})
        .select()
        .single();
    return subjectFromJson(row);
  });

  @override
  Future<List<StudyEvent>> listEvents(DateTime from, DateTime to) =>
      protect(() async {
        final owner = ownerId;
        final rows = await loadPages(
          (offset, end) => client
              .from('study_events')
              .select('*,event_tasks(*)')
              .eq('owner_id', owner)
              .lt('starts_at', to.toUtc().toIso8601String())
              .gt('ends_at', from.toUtc().toIso8601String())
              .order('starts_at')
              .order('id')
              .range(offset, end),
        );
        return rows.map(eventFromJson).toList(growable: false);
      });

  @override
  Future<List<StudyEvent>> createEvent(EventDraft draft) => protect(() async {
    final owner = ownerId;
    final created = await client.rpc(
      'create_study_event',
      params: {
        'p_event': eventToJson(draft),
        'p_tasks': draft.taskTitles.map((value) => value.trim()).toList(),
        'p_repeat_weeks': draft.repeatWeeks,
      },
    );
    final baseRows = (created as List).map(jsonObject).toList();
    if (baseRows.isEmpty) {
      throw const AppException('Chưa tạo được buổi học. Vui lòng thử lại.');
    }
    final createdEvents = baseRows.map(eventFromJson).toList(growable: false);
    final ids = createdEvents.map((event) => event.id).toList();
    try {
      final rows = await client
          .from('study_events')
          .select('*,event_tasks(*)')
          .eq('owner_id', owner)
          .inFilter('id', ids)
          .order('starts_at')
          .order('id');
      return rows.length == ids.length
          ? rows.map(eventFromJson).toList(growable: false)
          : createdEvents;
    } on Exception {
      // The RPC already confirmed an atomic commit. A failed checklist read
      // must not encourage a duplicate creation retry. Reload obtains task IDs.
      return createdEvents;
    }
  });

  @override
  Future<void> updateEvent(String id, EventDraft draft) => protect(() async {
    // Editing affects one occurrence and preserves task IDs/completion states.
    // Recurrence and taskTitles are creation-only parameters.
    final changed = await client
        .from('study_events')
        .update(eventToJson(draft))
        .eq('id', id)
        .eq('owner_id', ownerId)
        .select('id');
    if (changed.isEmpty) {
      throw const AppException(
        'Lịch trình không còn tồn tại hoặc bạn không có quyền sửa. Vui lòng tải lại lịch.',
      );
    }
  });

  @override
  Future<void> deleteEvent(String id) => protect(() async {
    final deleted = await client
        .from('study_events')
        .delete()
        .eq('id', id)
        .eq('owner_id', ownerId)
        .select('id');
    if (deleted.isEmpty) {
      throw const AppException(
        'Lịch trình không còn tồn tại hoặc bạn không có quyền xóa. Vui lòng tải lại lịch.',
      );
    }
  });

  @override
  Future<void> setTaskCompleted(String id, bool completed) => protect(() async {
    final changed = await client
        .from('event_tasks')
        .update({'is_completed': completed})
        .eq('id', id)
        .eq('owner_id', ownerId)
        .select('id');
    if (changed.isEmpty) {
      throw const AppException(
        'Nhiệm vụ không còn tồn tại hoặc bạn không có quyền sửa. Vui lòng tải lại lịch.',
      );
    }
  });

  @override
  Future<void> logSession({
    required DateTime startedAt,
    required int durationMinutes,
    String? subjectId,
  }) => protect(() async {
    await client.from('study_sessions').insert({
      'owner_id': ownerId,
      'started_at': startedAt.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes,
      'subject_id': subjectId,
    });
  });

  Future<List<StudySession>> _sessionsThrough(DateTime to) async {
    final owner = ownerId;
    final rows = await loadPages(
      (from, end) => client
          .from('study_sessions')
          .select()
          .eq('owner_id', owner)
          .lt('started_at', to.toUtc().toIso8601String())
          .order('started_at')
          .order('id')
          .range(from, end),
    );
    return rows.map(sessionFromJson).toList(growable: false);
  }

  Future<List<QuizAttempt>> _attemptsIn(DateTime from, DateTime to) async {
    final owner = ownerId;
    final rows = await loadPages(
      (offset, end) => client
          .from('quiz_attempts')
          .select()
          .eq('owner_id', owner)
          .gte('submitted_at', from.toUtc().toIso8601String())
          .lt('submitted_at', to.toUtc().toIso8601String())
          .order('submitted_at')
          .order('id')
          .range(offset, end),
    );
    return rows.map(attemptFromJson).toList(growable: false);
  }

  @override
  Future<StudyStatistics> getStatistics(
    DateTime from,
    DateTime to,
    DateTime now,
  ) => protect(() async {
    // Include history before the window to avoid truncating an existing streak.
    final latest = to.isAfter(now) ? to : now;
    final results = await Future.wait<Object>([
      _sessionsThrough(latest),
      _attemptsIn(from, to),
    ]);
    return calculateStudyStatistics(
      sessions: results[0] as List<StudySession>,
      attempts: results[1] as List<QuizAttempt>,
      from: from,
      to: to,
      now: now,
    );
  });

  @override
  Future<HomeDashboard> getDashboard(DateTime now) => protect(() async {
    final owner = ownerId;
    final today = localDay(now);
    final weekStart = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 7,
    );
    final results = await Future.wait<Object>([
      getProfile(),
      _sessionsThrough(weekEnd),
      listEvents(now, DateTime(today.year, today.month, today.day + 8)),
      client
          .from('quizzes')
          .select()
          .eq('owner_id', owner)
          .order('created_at', ascending: false)
          .order('id')
          .limit(3),
      client
          .from('chat_threads')
          .select()
          .eq('owner_id', owner)
          .order('updated_at', ascending: false)
          .order('id')
          .limit(3),
    ]);
    final metrics = calculateStudyStatistics(
      sessions: results[1] as List<StudySession>,
      attempts: const [],
      from: weekStart,
      to: weekEnd,
      now: now,
    );
    final todayMinutes = metrics.dailyMinutes
        .where((day) => day.date == today)
        .fold<int>(0, (sum, day) => sum + day.minutes);
    return HomeDashboard(
      profile: results[0] as Profile,
      todayMinutes: todayMinutes,
      upcomingEvents: (results[2] as List<StudyEvent>)
          .take(5)
          .toList(growable: false),
      week: metrics.dailyMinutes,
      recentQuizzes: (results[3] as List<Map<String, dynamic>>)
          .map(quizFromJson)
          .toList(growable: false),
      recentThreads: (results[4] as List<Map<String, dynamic>>)
          .map(threadFromJson)
          .toList(growable: false),
    );
  });
}
