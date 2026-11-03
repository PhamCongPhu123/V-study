import 'dart:typed_data';
import 'entities.dart';

abstract interface class AuthRepository {
  AppUser? get currentUser;
  Stream<AppUser?> get userChanges;
  Future<void> signIn(String email, String password);
  Future<SignUpResult> signUp(String name, String email, String password);
  Future<void> signOut();
  Future<void> signInWithGoogle();
  Future<void> requestPasswordReset(String email);
  Future<void> updatePassword(String password);
  Stream<bool> get passwordRecovery;
}

abstract interface class StudyRepository {
  Future<Profile> getProfile();
  Future<void> updateProfile({
    required String displayName,
    required int dailyGoalMinutes,
  });
  Future<List<Subject>> listSubjects();
  Future<Subject> createSubject(String name);
  Future<List<StudyEvent>> listEvents(DateTime from, DateTime to);
  Future<List<StudyEvent>> createEvent(EventDraft draft);
  Future<void> updateEvent(String id, EventDraft draft);
  Future<void> deleteEvent(String id);
  Future<void> setTaskCompleted(String id, bool completed);
  Future<void> logSession({
    required DateTime startedAt,
    required int durationMinutes,
    String? subjectId,
  });
  Future<HomeDashboard> getDashboard(DateTime now);
  Future<StudyStatistics> getStatistics(
    DateTime from,
    DateTime to,
    DateTime now,
  );
}

abstract interface class DocumentRepository {
  Future<List<StudyDocument>> listDocuments();
  Future<StudyDocument> upload({
    required String title,
    required String filename,
    required String mimeType,
    required Uint8List bytes,
  });
  Future<void> deleteDocument(StudyDocument document);
}

abstract interface class QuizRepository {
  Future<List<Quiz>> listQuizzes();
  Future<List<QuizQuestion>> getQuestions(String quizId);
  Future<String> generate({
    required String title,
    required String topic,
    required int questionCount,
    String? documentId,
  });
  Future<QuizAttempt> submit({
    required String quizId,
    required String attemptId,
    required Map<String, int> answers,
  });
  Future<List<QuizAttempt>> listAttempts();
}

abstract interface class AssistantRepository {
  Future<List<ChatThread>> listThreads();
  Future<List<ChatMessage>> listMessages(String threadId);
  Future<ChatTurn> send({
    required String message,
    required AiMode mode,
    String? threadId,
    String? documentId,
  });
  Future<void> deleteThread(String threadId);
}
