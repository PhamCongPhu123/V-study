enum EventKind { classSession, selfStudy, deadline }

enum AiMode { qa, summary, plan, flashcards }

class AppUser {
  const AppUser({required this.id, required this.email});
  final String id;
  final String email;
}

class SignUpResult {
  const SignUpResult({required this.needsEmailConfirmation});
  final bool needsEmailConfirmation;
}

class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    this.dailyGoalMinutes = 180,
    this.timezone = 'Asia/Ho_Chi_Minh',
  });
  final String id;
  final String displayName;
  final int dailyGoalMinutes;
  final String timezone;
}

class Subject {
  const Subject({required this.id, required this.name, this.color = '#6C63FF'});
  final String id;
  final String name;
  final String color;
}

class EventTask {
  const EventTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });
  final String id;
  final String title;
  final bool isCompleted;
}

class StudyEvent {
  const StudyEvent({
    required this.id,
    required this.title,
    required this.kind,
    required this.startsAt,
    required this.endsAt,
    this.subjectId,
    this.location = '',
    this.notes = '',
    this.reminderMinutes,
    this.seriesId,
    this.tasks = const [],
  });
  final String id;
  final String title;
  final EventKind kind;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? subjectId;
  final String location;
  final String notes;
  final int? reminderMinutes;
  final String? seriesId;
  final List<EventTask> tasks;
}

class EventDraft {
  const EventDraft({
    required this.title,
    required this.kind,
    required this.startsAt,
    required this.endsAt,
    this.subjectId,
    this.location = '',
    this.notes = '',
    this.reminderMinutes,
    this.taskTitles = const [],
    this.repeatWeeks = 0,
  });
  final String title;
  final EventKind kind;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? subjectId;
  final String location;
  final String notes;
  final int? reminderMinutes;
  final List<String> taskTitles;
  final int repeatWeeks;
}

class StudySession {
  const StudySession({
    required this.id,
    required this.startedAt,
    required this.durationMinutes,
    this.subjectId,
  });
  final String id;
  final DateTime startedAt;
  final int durationMinutes;
  final String? subjectId;
}

class StudyDocument {
  const StudyDocument({
    required this.id,
    required this.title,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });
  final String id;
  final String title;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;
}

class Quiz {
  const Quiz({
    required this.id,
    required this.title,
    required this.topic,
    required this.createdAt,
    this.sourceDocumentId,
    this.subjectId,
    this.chapterId,
    this.durationMinutes = 30,
    this.difficulty = 'medium',
  });
  final String id;
  final String title;
  final String topic;
  final DateTime createdAt;
  final String? sourceDocumentId;
  final String? subjectId;
  final String? chapterId;
  final int durationMinutes;
  final String difficulty;
}

class QuizChapter {
  const QuizChapter({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.position,
    this.questionCount = 0,
  });
  final String id;
  final String subjectId;
  final String title;
  final int position;
  final int questionCount;
}

class WrongQuizAnswer {
  const WrongQuizAnswer({
    required this.quizId,
    required this.quizTitle,
    required this.question,
    required this.selectedOption,
    required this.correctOption,
    required this.explanation,
    required this.answeredAt,
    this.subjectId,
    this.chapterId,
  });
  final String quizId;
  final String quizTitle;
  final String? subjectId;
  final String? chapterId;
  final QuizQuestion question;
  final int selectedOption;
  final int correctOption;
  final String explanation;
  final DateTime answeredAt;
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.position,
    required this.question,
    required this.options,
  });
  final String id;
  final int position;
  final String question;
  final List<String> options;
}

class AnswerReview {
  const AnswerReview({
    required this.questionId,
    required this.selectedOption,
    required this.correctOption,
    required this.explanation,
  });
  final String questionId;
  final int selectedOption;
  final int correctOption;
  final String explanation;
}

class QuizAttempt {
  const QuizAttempt({
    required this.id,
    required this.quizId,
    required this.correctCount,
    required this.totalQuestions,
    required this.submittedAt,
    this.review = const [],
    this.mode = 'practice',
  });
  final String id;
  final String quizId;
  final int correctCount;
  final int totalQuestions;
  final DateTime submittedAt;
  final List<AnswerReview> review;
  final String mode;
  double get percent =>
      totalQuestions == 0 ? 0 : correctCount * 100 / totalQuestions;
}

class ChatThread {
  const ChatThread({
    required this.id,
    required this.title,
    required this.mode,
    required this.updatedAt,
    this.documentId,
  });
  final String id;
  final String title;
  final AiMode mode;
  final String? documentId;
  final DateTime updatedAt;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.role,
    required this.content,
    required this.createdAt,
  });
  final String id;
  final String threadId;
  final String role;
  final String content;
  final DateTime createdAt;
}

class ChatTurn {
  const ChatTurn({
    required this.threadId,
    required this.userMessage,
    required this.assistantMessage,
  });
  final String threadId;
  final ChatMessage userMessage;
  final ChatMessage assistantMessage;
}

class DailyMinutes {
  const DailyMinutes({required this.date, required this.minutes});
  final DateTime date;
  final int minutes;
}

class StudyStatistics {
  const StudyStatistics({
    required this.totalMinutes,
    required this.dailyMinutes,
    required this.quizAttempts,
    required this.averageQuizPercent,
    required this.currentStreakDays,
    required this.minutesBySubject,
  });
  final int totalMinutes;
  final List<DailyMinutes> dailyMinutes;
  final int quizAttempts;
  final double averageQuizPercent;
  final int currentStreakDays;
  final Map<String, int> minutesBySubject;
}

class HomeDashboard {
  const HomeDashboard({
    required this.profile,
    required this.todayMinutes,
    required this.upcomingEvents,
    required this.week,
    required this.recentQuizzes,
    required this.recentThreads,
  });
  final Profile profile;
  final int todayMinutes;
  final List<StudyEvent> upcomingEvents;
  final List<DailyMinutes> week;
  final List<Quiz> recentQuizzes;
  final List<ChatThread> recentThreads;
}
