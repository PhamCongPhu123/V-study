import 'dart:typed_data';
import '../core/app_exception.dart';
import 'analytics.dart';
import 'analytics_repository.dart';
import 'account_repository.dart';
import 'ai_workspace.dart';
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
    this.analytics,
    this.account,
    this.aiWorkspace,
  });
  final AuthRepository auth;
  final StudyRepository study;
  final DocumentRepository documents;
  final QuizRepository quizzes;
  final AssistantRepository assistant;
  final AnalyticsRepository? analytics;
  final AccountRepository? account;
  final AiWorkspaceRepository? aiWorkspace;

  Future<AiArtifact> createAiMaterial(AiMaterialRequest request) {
    final workspace = aiWorkspace;
    if (workspace == null) {
      throw const AppException('Công cụ AI chưa được cấu hình.');
    }
    if (request.requestId.trim().isEmpty) {
      throw const AppException('Yêu cầu AI chưa có mã xác nhận.');
    }
    final title = _text(request.title, 'Tiêu đề', 200);
    final ids = request.documentIds;
    if (ids.length > 3 ||
        ids.toSet().length != ids.length ||
        ids.any((id) => id.trim().isEmpty)) {
      throw const AppException('Chọn tối đa 3 tài liệu khác nhau.');
    }
    if (request.kind == AiArtifactKind.summary && ids.isEmpty) {
      throw const AppException('Chọn ít nhất một tài liệu để tóm tắt.');
    }
    if (request.kind != AiArtifactKind.summary &&
        (request.questionCount < 1 ||
            request.questionCount > 40 ||
            request.exerciseKinds.isEmpty ||
            request.exerciseKinds.toSet().length !=
                request.exerciseKinds.length ||
            request.questionCount < request.exerciseKinds.length ||
            !['easy', 'medium', 'hard'].contains(request.difficulty))) {
      throw const AppException(
        'Chọn 1–40 câu, độ khó và ít nhất một dạng câu hỏi.',
      );
    }
    if (request.kind == AiArtifactKind.quiz &&
        (request.exerciseKinds.length != 1 ||
            request.exerciseKinds.single != ExerciseKind.multipleChoice)) {
      throw const AppException(
        'Quiz có chấm điểm chỉ sử dụng câu trắc nghiệm.',
      );
    }
    final topic = request.kind == AiArtifactKind.summary
        ? ''
        : _text(
            request.topic.trim().isEmpty && ids.isNotEmpty
                ? 'Ôn tập theo tài liệu đã chọn.'
                : request.topic,
            'Chủ đề',
            2000,
          );
    return workspace.createMaterial(
      AiMaterialRequest(
        requestId: request.requestId,
        kind: request.kind,
        title: title,
        topic: topic,
        documentIds: List.unmodifiable(ids),
        questionCount: request.kind == AiArtifactKind.summary
            ? 0
            : request.questionCount,
        difficulty: request.kind == AiArtifactKind.summary
            ? 'medium'
            : request.difficulty,
        exerciseKinds: request.kind == AiArtifactKind.summary
            ? const []
            : ExerciseKind.values
                  .where(request.exerciseKinds.contains)
                  .toList(),
      ),
    );
  }

  AccountRepository get _account =>
      account ??
      (throw const AppException('Thông tin tài khoản chưa được cấu hình.'));

  Future<void> saveAccount(AccountDraft draft, {DateTime? now}) {
    final name = _text(draft.displayName, 'Họ và tên', 100);
    final className = draft.className.trim();
    final major = draft.major.trim();
    if (className.length > 80 || major.length > 120) {
      throw const AppException(
        'Tên lớp tối đa 80 ký tự, ngành học tối đa 120 ký tự.',
      );
    }
    if (draft.dailyGoalMinutes < 1 || draft.dailyGoalMinutes > 1440) {
      throw const AppException('Mục tiêu cần từ 1 đến 1440 phút/ngày.');
    }
    if (!accountAvatarKeys.contains(draft.avatarKey)) {
      throw const AppException('Vui lòng chọn một ảnh đại diện có sẵn.');
    }
    final birth = draft.birthDate;
    final clock = (now ?? DateTime.now()).toLocal();
    if (birth != null &&
        (birth.year < 1900 ||
            DateTime(
              birth.year,
              birth.month,
              birth.day,
            ).isAfter(DateTime(clock.year, clock.month, clock.day)) ||
            birth.hour != 0 ||
            birth.minute != 0 ||
            birth.second != 0 ||
            birth.millisecond != 0 ||
            birth.microsecond != 0)) {
      throw const AppException(
        'Ngày sinh cần từ năm 1900 đến hôm nay và không gồm giờ.',
      );
    }
    return _account.saveAccount(
      AccountDraft(
        displayName: name,
        dailyGoalMinutes: draft.dailyGoalMinutes,
        className: className,
        major: major,
        birthDate: birth == null
            ? null
            : DateTime(birth.year, birth.month, birth.day),
        avatarKey: draft.avatarKey,
      ),
    );
  }

  Future<void> saveAccountPreferences(AccountPreferences preferences) =>
      _account.saveAccountPreferences(preferences);

  AnalyticsRepository get _analytics {
    final repository = analytics;
    if (repository == null) {
      throw const AppException('Thống kê chưa được cấu hình.');
    }
    return repository;
  }

  Future<void> saveLearningGoals(LearningGoals goals) {
    if (goals.weeklyMinutes < 60 || goals.weeklyMinutes > 10080) {
      throw const AppException('Mục tiêu tuần cần từ 60 đến 10080 phút.');
    }
    if (goals.studyDaysPerWeek < 1 || goals.studyDaysPerWeek > 7) {
      throw const AppException('Số ngày học cần từ 1 đến 7 ngày mỗi tuần.');
    }
    if (goals.flashcardsPerDay < 1 || goals.flashcardsPerDay > 1000) {
      throw const AppException(
        'Mục tiêu flashcard cần từ 1 đến 1000 thẻ/ngày.',
      );
    }
    bool isDateOnly(DateTime date) =>
        date.hour == 0 &&
        date.minute == 0 &&
        date.second == 0 &&
        date.millisecond == 0 &&
        date.microsecond == 0;
    if (!isDateOnly(goals.semesterStart) || !isDateOnly(goals.semesterEnd)) {
      throw const AppException('Ngày học kỳ không bao gồm giờ.');
    }
    // Academic dates are calendar values, not instants to shift across zones.
    final start = goals.semesterStart;
    final end = goals.semesterEnd;
    final days = DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    if (days < 7 || days > 366) {
      throw const AppException('Học kỳ cần kéo dài từ 7 đến 366 ngày.');
    }
    return _analytics.saveGoals(
      LearningGoals(
        weeklyMinutes: goals.weeklyMinutes,
        studyDaysPerWeek: goals.studyDaysPerWeek,
        flashcardsPerDay: goals.flashcardsPerDay,
        semesterStart: DateTime(start.year, start.month, start.day),
        semesterEnd: DateTime(end.year, end.month, end.day),
      ),
    );
  }

  Future<void> logFocusSession({
    required DateTime startedAt,
    required int plannedMinutes,
    required int focusedMinutes,
    required int interruptions,
    String? subjectId,
  }) {
    if (plannedMinutes < 1 ||
        plannedMinutes > 1440 ||
        focusedMinutes < 0 ||
        focusedMinutes > plannedMinutes) {
      throw const AppException(
        'Thời gian tập trung cần từ 0 đến thời gian dự kiến (1–1440 phút).',
      );
    }
    if (interruptions < 0 || interruptions > 1000) {
      throw const AppException('Số lần gián đoạn cần từ 0 đến 1000.');
    }
    if (startedAt
        .add(Duration(minutes: plannedMinutes))
        .isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      throw const AppException('Chỉ ghi nhận phiên tập trung đã hoàn thành.');
    }
    return _analytics.logFocusSession(
      startedAt: startedAt,
      plannedMinutes: plannedMinutes,
      focusedMinutes: focusedMinutes,
      interruptions: interruptions,
      subjectId: subjectId,
    );
  }

  Future<void> logFlashcardSession({
    required DateTime reviewedAt,
    required int reviewedCards,
    required int rememberedCards,
    String? subjectId,
  }) {
    if (reviewedCards < 1 ||
        reviewedCards > 10000 ||
        rememberedCards < 0 ||
        rememberedCards > reviewedCards) {
      throw const AppException(
        'Số thẻ ôn cần từ 1 đến 10000; số thẻ nhớ không vượt số thẻ ôn.',
      );
    }
    if (reviewedAt.isAfter(DateTime.now())) {
      throw const AppException(
        'Thời điểm ôn flashcard không được ở tương lai.',
      );
    }
    return _analytics.logFlashcardSession(
      reviewedAt: reviewedAt,
      reviewedCards: reviewedCards,
      rememberedCards: rememberedCards,
      subjectId: subjectId,
    );
  }

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
