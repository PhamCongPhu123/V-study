import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_exception.dart';
import '../domain/entities.dart';

/// Shared transport boundary. Technical responses never become UI error text.
abstract class SupabaseAccess {
  const SupabaseAccess(this.client);
  final SupabaseClient client;

  String get ownerId {
    final id = client.auth.currentUser?.id;
    if (id == null) {
      throw const AppException('Vui lòng đăng nhập để tiếp tục.');
    }
    return id;
  }

  Future<T> protect<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AppException {
      rethrow;
    } on AuthException {
      throw const AppException(
        'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.',
      );
    } on PostgrestException catch (error) {
      if (error.code == '23503') {
        throw const AppException(
          'Dữ liệu đang được sử dụng hoặc không còn tồn tại. Vui lòng tải lại.',
        );
      }
      if (error.code == '23505') {
        throw const AppException('Dữ liệu này đã tồn tại.');
      }
      if (error.code == '42501' || error.code == 'PGRST301') {
        throw const AppException('Bạn không có quyền thực hiện thao tác này.');
      }
      throw const AppException(
        'Không thể lưu hoặc tải dữ liệu. Vui lòng thử lại.',
      );
    } on StorageException {
      throw const AppException('Không thể xử lý tài liệu. Vui lòng thử lại.');
    } on FunctionException catch (error) {
      if (error.status == 429) {
        throw const AppException(
          'Bạn đang gửi yêu cầu quá nhanh. Hãy thử lại sau.',
        );
      }
      if (error.status == 401) {
        throw const AppException(
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        );
      }
      throw const AppException('AI chưa thể trả lời. Vui lòng thử lại sau.');
    } on Exception {
      throw const AppException(
        'Kết nối gặp sự cố. Vui lòng kiểm tra mạng và thử lại.',
      );
    }
  }
}

/// All history reads use deterministic ordering and page through server limits.
Future<List<Map<String, dynamic>>> loadPages(
  Future<List<Map<String, dynamic>>> Function(int from, int to) fetch,
) async {
  const pageSize = 500;
  final result = <Map<String, dynamic>>[];
  var offset = 0;
  while (true) {
    final page = await fetch(offset, offset + pageSize - 1);
    result.addAll(page);
    if (page.length < pageSize) {
      return result;
    }
    offset += pageSize;
  }
}

Map<String, dynamic> jsonObject(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

DateTime localTimestamp(dynamic value) =>
    DateTime.parse(value as String).toLocal();

String wireEventKind(EventKind kind) => switch (kind) {
  EventKind.classSession => 'class',
  EventKind.selfStudy => 'self_study',
  EventKind.deadline => 'deadline',
};

EventKind parseEventKind(String kind) => switch (kind) {
  'class' => EventKind.classSession,
  'self_study' => EventKind.selfStudy,
  'deadline' => EventKind.deadline,
  _ => throw const FormatException('Unknown event kind'),
};

Profile profileFromJson(Map<String, dynamic> row) => Profile(
  id: row['id'] as String,
  displayName: row['display_name'] as String,
  dailyGoalMinutes: row['daily_goal_minutes'] as int,
  timezone: row['timezone'] as String,
  className: row['class_name'] as String? ?? '',
  major: row['major'] as String? ?? '',
  birthDate: row['birth_date'] == null
      ? null
      : DateTime.parse(row['birth_date'] as String),
  avatarKey: row['avatar_key'] as String? ?? 'student',
  preferences: AccountPreferences(
    darkProfile: row['dark_profile'] as bool? ?? false,
    studyReminders: row['study_reminders'] as bool? ?? true,
  ),
);

Subject subjectFromJson(Map<String, dynamic> row) => Subject(
  id: row['id'] as String,
  name: row['name'] as String,
  color: row['color'] as String,
);

StudyEvent eventFromJson(Map<String, dynamic> row) => StudyEvent(
  id: row['id'] as String,
  title: row['title'] as String,
  kind: parseEventKind(row['kind'] as String),
  startsAt: localTimestamp(row['starts_at']),
  endsAt: localTimestamp(row['ends_at']),
  subjectId: row['subject_id'] as String?,
  location: row['location'] as String? ?? '',
  notes: row['notes'] as String? ?? '',
  reminderMinutes: row['reminder_minutes'] as int?,
  seriesId: row['series_id'] as String?,
  tasks: (row['event_tasks'] as List? ?? const [])
      .map((value) {
        final task = jsonObject(value);
        return EventTask(
          id: task['id'] as String,
          title: task['title'] as String,
          isCompleted: task['is_completed'] as bool,
        );
      })
      .toList(growable: false),
);

Map<String, dynamic> eventToJson(EventDraft draft) => {
  'title': draft.title.trim(),
  'kind': wireEventKind(draft.kind),
  'subject_id': draft.subjectId,
  'starts_at': draft.startsAt.toUtc().toIso8601String(),
  'ends_at': draft.endsAt.toUtc().toIso8601String(),
  'location': draft.location.trim(),
  'notes': draft.notes.trim(),
  'reminder_minutes': draft.reminderMinutes,
};

StudySession sessionFromJson(Map<String, dynamic> row) => StudySession(
  id: row['id'] as String,
  subjectId: row['subject_id'] as String?,
  startedAt: localTimestamp(row['started_at']),
  durationMinutes: row['duration_minutes'] as int,
);

StudyDocument documentFromJson(Map<String, dynamic> row) => StudyDocument(
  id: row['id'] as String,
  title: row['title'] as String,
  storagePath: row['storage_path'] as String,
  mimeType: row['mime_type'] as String,
  sizeBytes: row['size_bytes'] as int,
  createdAt: localTimestamp(row['created_at']),
  subjectId: row['subject_id'] as String?,
  isFavorite: row['is_favorite'] as bool? ?? false,
);

Quiz quizFromJson(Map<String, dynamic> row) => Quiz(
  id: row['id'] as String,
  title: row['title'] as String,
  topic: row['topic'] as String,
  sourceDocumentId: row['source_document_id'] as String?,
  subjectId: row['subject_id'] as String?,
  chapterId: row['chapter_id'] as String?,
  durationMinutes: row['duration_minutes'] as int? ?? 30,
  difficulty: row['difficulty'] as String? ?? 'medium',
  createdAt: localTimestamp(row['created_at']),
);

QuizChapter chapterFromJson(Map<String, dynamic> row) => QuizChapter(
  id: row['id'] as String,
  subjectId: row['subject_id'] as String,
  title: row['title'] as String,
  position: row['position'] as int,
  questionCount: (row['question_count'] as num?)?.toInt() ?? 0,
);

AnswerReview answerReviewFromJson(Map<String, dynamic> row) => AnswerReview(
  questionId: row['question_id'] as String,
  selectedOption: row['selected_option'] as int,
  correctOption: row['correct_option'] as int,
  explanation: row['explanation'] as String,
);

WrongQuizAnswer wrongAnswerFromJson(Map<String, dynamic> row) =>
    WrongQuizAnswer(
      quizId: row['quiz_id'] as String,
      quizTitle: row['quiz_title'] as String,
      subjectId: row['subject_id'] as String?,
      chapterId: row['chapter_id'] as String?,
      question: questionFromJson(jsonObject(row['question'])),
      selectedOption: row['selected_option'] as int,
      correctOption: row['correct_option'] as int,
      explanation: row['explanation'] as String,
      answeredAt: localTimestamp(row['answered_at']),
    );

QuizQuestion questionFromJson(Map<String, dynamic> row) => QuizQuestion(
  id: row['id'] as String,
  position: row['position'] as int,
  question: row['question'] as String,
  options: List<String>.from(row['options'] as List),
  hint: row['hint'] as String? ?? '',
);

QuizAttempt attemptFromJson(Map<String, dynamic> row) => QuizAttempt(
  id: row['id'] as String,
  quizId: row['quiz_id'] as String,
  correctCount: row['correct_count'] as int,
  totalQuestions: row['total_questions'] as int,
  submittedAt: localTimestamp(row['submitted_at']),
  mode: row['mode'] as String? ?? 'practice',
  review: (row['review'] as List? ?? const [])
      .map((value) {
        final item = jsonObject(value);
        return AnswerReview(
          questionId: item['question_id'] as String,
          selectedOption: item['selected_option'] as int,
          correctOption: item['correct_option'] as int,
          explanation: item['explanation'] as String,
        );
      })
      .toList(growable: false),
);

ChatThread threadFromJson(Map<String, dynamic> row) => ChatThread(
  id: row['id'] as String,
  title: row['title'] as String,
  mode: AiMode.values.byName(row['mode'] as String),
  documentId: row['document_id'] as String?,
  updatedAt: localTimestamp(row['updated_at']),
);

ChatMessage messageFromJson(Map<String, dynamic> row) => ChatMessage(
  id: row['id'] as String,
  threadId: row['thread_id'] as String,
  role: row['role'] as String,
  content: row['content'] as String,
  createdAt: localTimestamp(row['created_at']),
);
