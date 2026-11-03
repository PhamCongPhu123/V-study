import 'dart:typed_data';
import '../core/app_exception.dart';
import 'entities.dart';
import 'repositories.dart';

/// Domain operations depend on repository contracts, never on Flutter/Supabase.
class VstudyUseCases {
  const VstudyUseCases({
    required this.auth,
    required this.study,
    required this.documents,
    required this.quizzes,
    required this.assistant,
  });
  final AuthRepository auth;
  final StudyRepository study;
  final DocumentRepository documents;
  final QuizRepository quizzes;
  final AssistantRepository assistant;

  String _email(String email) {
    final value = email.trim();
    if (value.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      throw const AppException('Vui lòng nhập email hợp lệ.');
    }
    return value;
  }

  void _password(String password) {
    if (password.length < 8 || password.length > 128) {
      throw const AppException('Mật khẩu cần từ 8 đến 128 ký tự.');
    }
  }

  String _text(String value, String label, int max) {
    final clean = value.trim();
    if (clean.isEmpty || clean.length > max) {
      throw AppException('$label cần từ 1 đến $max ký tự.');
    }
    return clean;
  }

  Future<void> signIn(String email, String password) {
    if (password.isEmpty) {
      throw const AppException('Vui lòng nhập mật khẩu.');
    }
    return auth.signIn(_email(email), password);
  }

  Future<SignUpResult> signUp(
    String name,
    String email,
    String password,
    String confirmPassword,
    bool acceptedTerms,
  ) {
    final displayName = _text(name, 'Họ và tên', 100);
    final validEmail = _email(email);
    _password(password);
    if (password != confirmPassword) {
      throw const AppException('Mật khẩu nhập lại chưa khớp.');
    }
    if (!acceptedTerms) {
      throw const AppException(
        'Bạn cần đồng ý với Điều khoản và Chính sách bảo mật.',
      );
    }
    return auth.signUp(displayName, validEmail, password);
  }

  Future<void> resetPassword(String email) =>
      auth.requestPasswordReset(_email(email));

  Future<void> updatePassword(String password, String confirm) {
    _password(password);
    if (password != confirm) {
      throw const AppException('Mật khẩu nhập lại chưa khớp.');
    }
    return auth.updatePassword(password);
  }

  void _event(EventDraft draft) {
    _text(draft.title, 'Tên lịch học', 200);
    if (!draft.endsAt.isAfter(draft.startsAt)) {
      throw const AppException('Giờ kết thúc phải sau giờ bắt đầu.');
    }
    if (draft.endsAt.difference(draft.startsAt) > const Duration(days: 7)) {
      throw const AppException('Một lịch học không được kéo dài quá 7 ngày.');
    }
    if (draft.repeatWeeks < 0 || draft.repeatWeeks > 52) {
      throw const AppException('Chỉ lặp lại tối đa 52 tuần.');
    }
    if (draft.location.length > 300 || draft.notes.length > 5000) {
      throw const AppException('Địa điểm hoặc ghi chú quá dài.');
    }
    if (draft.reminderMinutes != null &&
        (draft.reminderMinutes! < 0 || draft.reminderMinutes! > 10080)) {
      throw const AppException('Thời gian nhắc trước cần từ 0 đến 10080 phút.');
    }
    if (draft.taskTitles.length > 30) {
      throw const AppException('Tối đa 30 việc cần chuẩn bị.');
    }
    for (final title in draft.taskTitles) {
      _text(title, 'Việc cần chuẩn bị', 300);
    }
  }

  Future<List<StudyEvent>> createEvent(EventDraft draft) {
    _event(draft);
    return study.createEvent(draft);
  }

  Future<void> updateEvent(String id, EventDraft draft) {
    _event(draft);
    if (draft.repeatWeeks != 0) {
      throw const AppException(
        'Khi sửa chỉ thay đổi một buổi; lặp lại áp dụng khi tạo mới.',
      );
    }
    return study.updateEvent(id, draft);
  }

  Future<void> logSession({
    required DateTime startedAt,
    required int durationMinutes,
    String? subjectId,
  }) {
    if (durationMinutes < 1 || durationMinutes > 1440) {
      throw const AppException('Thời gian học cần từ 1 đến 1440 phút.');
    }
    // Completed sessions must not invent future study activity.
    if (startedAt
        .add(Duration(minutes: durationMinutes))
        .isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      throw const AppException('Chỉ ghi nhận buổi học đã hoàn thành.');
    }
    return study.logSession(
      startedAt: startedAt,
      durationMinutes: durationMinutes,
      subjectId: subjectId,
    );
  }

  Future<void> updateProfile({
    required String displayName,
    required int dailyGoalMinutes,
  }) {
    final name = _text(displayName, 'Họ và tên', 100);
    if (dailyGoalMinutes < 1 || dailyGoalMinutes > 1440) {
      throw const AppException('Mục tiêu cần từ 1 đến 1440 phút/ngày.');
    }
    return study.updateProfile(
      displayName: name,
      dailyGoalMinutes: dailyGoalMinutes,
    );
  }

  Future<Subject> createSubject(String name) =>
      study.createSubject(_text(name, 'Tên môn học', 100));

  Future<String> generateQuiz({
    required String title,
    required String topic,
    required int questionCount,
    String? documentId,
    String? subjectId,
    String? chapterId,
    int durationMinutes = 30,
    String difficulty = 'medium',
  }) {
    final validTitle = _text(title, 'Tên quiz', 200);
    final validTopic = _text(topic, 'Chủ đề', 2000);
    if (questionCount < 1 || questionCount > 30) {
      throw const AppException('Mỗi quiz cần từ 1 đến 30 câu.');
    }
    if (durationMinutes < 1 || durationMinutes > 180) {
      throw const AppException('Thời gian làm bài cần từ 1 đến 180 phút.');
    }
    if (!['easy', 'medium', 'hard'].contains(difficulty)) {
      throw const AppException('Độ khó chưa hợp lệ.');
    }
    if (chapterId != null && subjectId == null) {
      throw const AppException('Vui lòng chọn môn học cho chương.');
    }
    return quizzes.generate(
      title: validTitle,
      topic: validTopic,
      questionCount: questionCount,
      documentId: documentId,
      subjectId: subjectId,
      chapterId: chapterId,
      durationMinutes: durationMinutes,
      difficulty: difficulty,
    );
  }

  Future<QuizAttempt> submitQuiz({
    required String quizId,
    required String attemptId,
    required Map<String, int> answers,
    bool allowUnanswered = false,
    String mode = 'practice',
  }) {
    if (!['practice', 'exam'].contains(mode)) {
      throw const AppException('Chế độ làm bài chưa hợp lệ.');
    }
    if ((!allowUnanswered && answers.isEmpty) ||
        answers.values.any((v) => v < 0 || v > 3)) {
      throw const AppException('Vui lòng chọn đáp án cho tất cả câu hỏi.');
    }
    // The database independently enforces completeness and grades private keys.
    return quizzes.submit(
      quizId: quizId,
      attemptId: attemptId,
      answers: Map.unmodifiable(answers),
      allowUnanswered: allowUnanswered,
      mode: mode,
    );
  }

  Future<AnswerReview> checkPracticeAnswer({
    required String quizId,
    required String questionId,
    required int selectedOption,
  }) {
    if (selectedOption < 0 || selectedOption > 3) {
      throw const AppException('Vui lòng chọn một đáp án hợp lệ.');
    }
    return quizzes.checkPracticeAnswer(
      quizId: quizId,
      questionId: questionId,
      selectedOption: selectedOption,
    );
  }

  Future<QuizChapter> createQuizChapter({
    required String subjectId,
    required String title,
  }) {
    return quizzes.createChapter(
      subjectId: subjectId,
      title: _text(title, 'Tên chương', 200),
    );
  }

  Future<ChatTurn> sendMessage({
    required String message,
    required AiMode mode,
    String? threadId,
    String? documentId,
  }) {
    return assistant.send(
      message: _text(message, 'Tin nhắn', 8000),
      mode: mode,
      threadId: threadId,
      documentId: documentId,
    );
  }

  Future<StudyDocument> uploadDocument({
    required String title,
    required String filename,
    required String mimeType,
    required Uint8List bytes,
  }) {
    final validTitle = _text(title, 'Tên tài liệu', 200);
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw const AppException('Tài liệu cần có nội dung và tối đa 10 MiB.');
    }
    if (mimeType != 'application/pdf' && mimeType != 'text/plain') {
      throw const AppException('Chỉ hỗ trợ tài liệu PDF hoặc TXT.');
    }
    return documents.upload(
      title: validTitle,
      filename: filename,
      mimeType: mimeType,
      bytes: bytes,
    );
  }
}
