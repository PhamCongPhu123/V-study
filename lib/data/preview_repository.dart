import 'dart:typed_data';

import '../core/app_exception.dart';
import '../domain/entities.dart';
import '../domain/repositories.dart';
import '../domain/study_metrics.dart';
import '../domain/use_cases.dart';

/// In-memory prototype data. Never initializes Supabase or calls Gemini.
class PreviewRepository
    implements
        StudyRepository,
        DocumentRepository,
        QuizRepository,
        AssistantRepository {
  PreviewRepository({DateTime? now}) : _now = now ?? DateTime.now() {
    final today = localDay(_now);
    _events.addAll([
      StudyEvent(
        id: 'calculus',
        title: 'Giải tích 1',
        kind: EventKind.classSession,
        startsAt: today.add(const Duration(hours: 7, minutes: 30)),
        endsAt: today.add(const Duration(hours: 9, minutes: 30)),
        subjectId: 'math',
        location: 'Phòng K.P206',
        reminderMinutes: 60,
        tasks: const [
          EventTask(id: 'read', title: 'Đọc trước chương 3'),
          EventTask(
            id: 'prepare',
            title: 'Chuẩn bị bài mới',
            isCompleted: true,
          ),
        ],
      ),
      StudyEvent(
        id: 'study',
        title: 'Ôn tập Đại số tuyến tính',
        kind: EventKind.selfStudy,
        startsAt: today.add(const Duration(hours: 19)),
        endsAt: today.add(const Duration(hours: 21)),
        subjectId: 'math',
        tasks: const [EventTask(id: 'exercise', title: 'Làm bài tập ma trận')],
      ),
      StudyEvent(
        id: 'deadline',
        title: 'Nộp bài thiết kế UX/UI',
        kind: EventKind.deadline,
        startsAt: today.add(const Duration(days: 1, hours: 20)),
        endsAt: today.add(const Duration(days: 1, hours: 21)),
        subjectId: 'design',
      ),
    ]);
    for (var i = 0; i < 7; i++) {
      _sessions.add(
        StudySession(
          id: 'session-$i',
          startedAt: _now.subtract(Duration(days: i, hours: 3)),
          durationMinutes: [100, 75, 120, 45, 90, 60, 150][i],
          subjectId: i.isEven ? 'math' : 'design',
        ),
      );
    }
    _documents.add(
      StudyDocument(
        id: 'reference',
        title: 'Ghi chú nguyên lý UX/UI',
        storagePath: 'preview/ux-notes.txt',
        mimeType: 'text/plain',
        sizeBytes: 2048,
        createdAt: _now.subtract(const Duration(days: 1)),
      ),
    );
    _addQuiz(
      'ux-quiz',
      'Nguyên lý UX/UI',
      'Thiết kế lấy người dùng làm trung tâm',
      5,
    );
    _attempts.add(
      QuizAttempt(
        id: 'recent',
        quizId: 'ux-quiz',
        correctCount: 4,
        totalQuestions: 5,
        submittedAt: _now.subtract(const Duration(days: 1)),
      ),
    );
    _threads.add(
      ChatThread(
        id: 'intro-chat',
        title: 'Cách ôn tập hiệu quả',
        mode: AiMode.qa,
        updatedAt: _now.subtract(const Duration(minutes: 10)),
      ),
    );
    _messages['intro-chat'] = [
      ChatMessage(
        id: 'hello-user',
        threadId: 'intro-chat',
        role: 'user',
        content: 'Làm sao để ôn tập hiệu quả hơn?',
        createdAt: _now.subtract(const Duration(minutes: 11)),
      ),
      ChatMessage(
        id: 'hello-assistant',
        threadId: 'intro-chat',
        role: 'assistant',
        content:
            'Bạn có thể chia nội dung thành các phần nhỏ, tự kiểm tra bằng quiz và ôn lại theo lịch cách quãng. Đây là câu trả lời minh họa cho bản mẫu.',
        createdAt: _now.subtract(const Duration(minutes: 10)),
      ),
    ];
  }

  final DateTime _now;
  var _sequence = 0;
  String _id() => 'preview-${++_sequence}';
  Profile _profile = const Profile(id: 'preview-user', displayName: 'Phú');
  final _subjects = <Subject>[
    const Subject(id: 'math', name: 'Toán cao cấp'),
    const Subject(id: 'design', name: 'Thiết kế UX/UI', color: '#C9A227'),
  ];
  final _events = <StudyEvent>[];
  final _sessions = <StudySession>[];
  final _documents = <StudyDocument>[];
  final _quizzes = <Quiz>[];
  final _questions = <String, List<QuizQuestion>>{};
  final _attempts = <QuizAttempt>[];
  final _submitted = <String, Map<String, int>>{};
  final _threads = <ChatThread>[];
  final _messages = <String, List<ChatMessage>>{};

  VstudyUseCases get useCases => VstudyUseCases(
    auth: const _PreviewAuth(),
    study: this,
    documents: this,
    quizzes: this,
    assistant: this,
  );

  @override
  Future<Profile> getProfile() async => _profile;
  @override
  Future<void> updateProfile({
    required String displayName,
    required int dailyGoalMinutes,
  }) async {
    _profile = Profile(
      id: _profile.id,
      displayName: displayName,
      dailyGoalMinutes: dailyGoalMinutes,
    );
  }

  @override
  Future<List<Subject>> listSubjects() async => List.unmodifiable(_subjects);
  @override
  Future<Subject> createSubject(String name) async {
    final subject = Subject(id: _id(), name: name);
    _subjects.add(subject);
    return subject;
  }

  @override
  Future<List<StudyEvent>> listEvents(DateTime from, DateTime to) async =>
      _events
          .where((e) => e.startsAt.isBefore(to) && e.endsAt.isAfter(from))
          .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  @override
  Future<List<StudyEvent>> createEvent(EventDraft draft) async {
    final created = <StudyEvent>[];
    final series = draft.repeatWeeks > 0 ? _id() : null;
    for (var i = 0; i <= draft.repeatWeeks; i++) {
      final event = StudyEvent(
        id: _id(),
        title: draft.title,
        kind: draft.kind,
        startsAt: draft.startsAt.add(Duration(days: i * 7)),
        endsAt: draft.endsAt.add(Duration(days: i * 7)),
        subjectId: draft.subjectId,
        location: draft.location,
        notes: draft.notes,
        reminderMinutes: draft.reminderMinutes,
        seriesId: series,
        tasks: draft.taskTitles
            .map((title) => EventTask(id: _id(), title: title))
            .toList(),
      );
      _events.add(event);
      created.add(event);
    }
    return created;
  }

  @override
  Future<void> updateEvent(String id, EventDraft draft) async {
    final index = _events.indexWhere((e) => e.id == id);
    if (index < 0) {
      throw const AppException('Không tìm thấy buổi học.');
    }
    final previous = _events[index];
    _events[index] = StudyEvent(
      id: id,
      title: draft.title,
      kind: draft.kind,
      startsAt: draft.startsAt,
      endsAt: draft.endsAt,
      subjectId: draft.subjectId,
      location: draft.location,
      notes: draft.notes,
      reminderMinutes: draft.reminderMinutes,
      seriesId: previous.seriesId,
      tasks: previous.tasks,
    );
  }

  @override
  Future<void> deleteEvent(String id) async =>
      _events.removeWhere((e) => e.id == id);
  @override
  Future<void> setTaskCompleted(String id, bool completed) async {
    for (var i = 0; i < _events.length; i++) {
      final e = _events[i];
      if (!e.tasks.any((t) => t.id == id)) {
        continue;
      }
      _events[i] = StudyEvent(
        id: e.id,
        title: e.title,
        kind: e.kind,
        startsAt: e.startsAt,
        endsAt: e.endsAt,
        subjectId: e.subjectId,
        location: e.location,
        notes: e.notes,
        reminderMinutes: e.reminderMinutes,
        seriesId: e.seriesId,
        tasks: e.tasks
            .map(
              (t) => t.id == id
                  ? EventTask(id: t.id, title: t.title, isCompleted: completed)
                  : t,
            )
            .toList(),
      );
    }
  }

  @override
  Future<void> logSession({
    required DateTime startedAt,
    required int durationMinutes,
    String? subjectId,
  }) async {
    _sessions.add(
      StudySession(
        id: _id(),
        startedAt: startedAt,
        durationMinutes: durationMinutes,
        subjectId: subjectId,
      ),
    );
  }

  @override
  Future<StudyStatistics> getStatistics(
    DateTime from,
    DateTime to,
    DateTime now,
  ) async => calculateStudyStatistics(
    sessions: _sessions,
    attempts: _attempts,
    from: from,
    to: to,
    now: now,
  );
  @override
  Future<HomeDashboard> getDashboard(DateTime now) async {
    final today = localDay(now);
    final weekStart = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    final metrics = await getStatistics(
      weekStart,
      DateTime(weekStart.year, weekStart.month, weekStart.day + 7),
      now,
    );
    return HomeDashboard(
      profile: _profile,
      todayMinutes: metrics.dailyMinutes
          .where((d) => d.date == today)
          .fold<int>(0, (sum, d) => sum + d.minutes),
      upcomingEvents: (await listEvents(
        now,
        now.add(const Duration(days: 7)),
      )).take(5).toList(),
      week: metrics.dailyMinutes,
      recentQuizzes: _quizzes.take(3).toList(),
      recentThreads: _threads.take(3).toList(),
    );
  }

  @override
  Future<List<StudyDocument>> listDocuments() async =>
      List.unmodifiable(_documents);
  @override
  Future<StudyDocument> upload({
    required String title,
    required String filename,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final doc = StudyDocument(
      id: _id(),
      title: title,
      storagePath: 'preview/$filename',
      mimeType: mimeType,
      sizeBytes: bytes.length,
      createdAt: DateTime.now(),
    );
    _documents.insert(0, doc);
    return doc;
  }

  @override
  Future<void> deleteDocument(StudyDocument document) async {
    if (_threads.any((t) => t.documentId == document.id) ||
        _quizzes.any((q) => q.sourceDocumentId == document.id)) {
      throw const AppException('Tài liệu đang được dùng trong bản mẫu.');
    }
    _documents.removeWhere((d) => d.id == document.id);
  }

  static const _sampleQuestions = [
    (
      'Wireframe được dùng để làm gì?',
      [
        'Xác định bố cục và cấu trúc',
        'Thay database',
        'Ký ứng dụng',
        'Nén hình ảnh',
      ],
      'Wireframe mô tả cấu trúc trước khi hoàn thiện chi tiết thị giác.',
    ),
    (
      'Phản hồi sau khi nhấn nút giúp người dùng điều gì?',
      [
        'Biết hệ thống đã nhận thao tác',
        'Ghi nhớ mật khẩu',
        'Tăng dung lượng máy',
        'Tự thay đổi thiết bị',
      ],
      'Phản hồi rõ ràng giúp người dùng hiểu trạng thái hệ thống.',
    ),
    (
      'Thiết kế lấy người dùng làm trung tâm bắt đầu từ đâu?',
      [
        'Tìm hiểu nhu cầu người dùng',
        'Chọn hiệu ứng',
        'Viết quảng cáo',
        'Chọn tên file',
      ],
      'Nghiên cứu nhu cầu và bối cảnh là cơ sở cho quyết định thiết kế.',
    ),
    (
      'Tính nhất quán trong UI giúp gì?',
      [
        'Giảm việc phải học lại cách thao tác',
        'Tăng số màu',
        'Ẩn điều hướng',
        'Thay font mỗi trang',
      ],
      'Thành phần nhất quán tận dụng kiến thức người dùng đã có.',
    ),
    (
      'Kiểm thử usability nhằm mục đích gì?',
      [
        'Tìm khó khăn khi thực hiện tác vụ',
        'Đếm số dòng code',
        'Thay hệ điều hành',
        'Tăng kích thước ảnh',
      ],
      'Quan sát tác vụ giúp phát hiện và cải thiện trở ngại thực tế.',
    ),
  ];
  void _addQuiz(
    String id,
    String title,
    String topic,
    int count, [
    String? documentId,
  ]) {
    _quizzes.insert(
      0,
      Quiz(
        id: id,
        title: title,
        topic: topic,
        createdAt: _now,
        sourceDocumentId: documentId,
      ),
    );
    _questions[id] = List.generate(count, (i) {
      final sample = _sampleQuestions[i % _sampleQuestions.length];
      return QuizQuestion(
        id: '$id-q$i',
        position: i,
        question: sample.$1,
        options: sample.$2,
      );
    });
  }

  @override
  Future<List<Quiz>> listQuizzes() async => List.unmodifiable(_quizzes);
  @override
  Future<List<QuizQuestion>> getQuestions(String quizId) async =>
      List.unmodifiable(_questions[quizId] ?? []);
  @override
  Future<String> generate({
    required String title,
    required String topic,
    required int questionCount,
    String? documentId,
  }) async {
    final id = _id();
    _addQuiz(id, '$title (minh họa UX/UI)', topic, questionCount, documentId);
    return id;
  }

  @override
  Future<QuizAttempt> submit({
    required String quizId,
    required String attemptId,
    required Map<String, int> answers,
  }) async {
    final questions = _questions[quizId];
    if (questions == null ||
        questions.length != answers.length ||
        questions.any((q) => !answers.containsKey(q.id)) ||
        answers.values.any((v) => v < 0 || v > 3)) {
      throw const AppException('Vui lòng trả lời đầy đủ câu hỏi.');
    }
    final previous = _attempts.where((a) => a.id == attemptId);
    if (previous.isNotEmpty) {
      final old = _submitted[attemptId]!;
      if (previous.first.quizId != quizId ||
          old.length != answers.length ||
          answers.entries.any((e) => old[e.key] != e.value)) {
        throw const AppException('Mã bài nộp đã dùng với đáp án khác.');
      }
      return previous.first;
    }
    final result = QuizAttempt(
      id: attemptId,
      quizId: quizId,
      correctCount: answers.values.where((v) => v == 0).length,
      totalQuestions: questions.length,
      submittedAt: DateTime.now(),
      review: questions
          .map(
            (q) => AnswerReview(
              questionId: q.id,
              selectedOption: answers[q.id]!,
              correctOption: 0,
              explanation:
                  _sampleQuestions[q.position % _sampleQuestions.length].$3,
            ),
          )
          .toList(),
    );
    _attempts.insert(0, result);
    _submitted[attemptId] = Map.of(answers);
    return result;
  }

  @override
  Future<List<QuizAttempt>> listAttempts() async =>
      List.unmodifiable(_attempts);
  @override
  Future<List<ChatThread>> listThreads() async => List.unmodifiable(_threads);
  @override
  Future<List<ChatMessage>> listMessages(String threadId) async =>
      List.unmodifiable(_messages[threadId] ?? []);
  @override
  Future<ChatTurn> send({
    required String message,
    required AiMode mode,
    String? threadId,
    String? documentId,
  }) async {
    final id = threadId ?? _id();
    final now = DateTime.now();
    final index = _threads.indexWhere((t) => t.id == id);
    if (threadId != null && index < 0) {
      throw const AppException('Không tìm thấy hội thoại.');
    }
    if (index >= 0 &&
        (_threads[index].mode != mode ||
            _threads[index].documentId != documentId)) {
      throw const AppException(
        'Hãy tạo hội thoại mới để đổi chế độ hoặc tài liệu.',
      );
    }
    final title = message.length > 60 ? message.substring(0, 60) : message;
    final thread = ChatThread(
      id: id,
      title: index >= 0 ? _threads[index].title : title,
      mode: mode,
      documentId: documentId,
      updatedAt: now,
    );
    if (index >= 0) {
      _threads.removeAt(index);
    }
    _threads.insert(0, thread);
    final response = switch (mode) {
      AiMode.qa =>
        'Bạn có thể bắt đầu bằng việc xác định mục tiêu, chia nhỏ kiến thức và tự kiểm tra sau mỗi phần.',
      AiMode.summary =>
        'Ý chính minh họa:\n• Xác định nhu cầu người học.\n• Sắp xếp nội dung có thứ bậc.\n• Ôn tập và kiểm tra định kỳ.',
      AiMode.plan =>
        'Lộ trình minh họa:\n1. Ôn lý thuyết trong 25 phút.\n2. Nghỉ 5 phút.\n3. Làm quiz và xem lại câu sai.\nLộ trình này chưa được thêm vào lịch.',
      AiMode.flashcards =>
        'Thẻ minh họa:\nHỏi: Wireframe là gì?\nĐáp: Bản phác cấu trúc và bố cục giao diện.',
    };
    final user = ChatMessage(
      id: _id(),
      threadId: id,
      role: 'user',
      content: message,
      createdAt: now,
    );
    final assistant = ChatMessage(
      id: _id(),
      threadId: id,
      role: 'assistant',
      content:
          'Bản mẫu UX/UI — không gọi Gemini và không phân tích tài liệu.\n\n$response',
      createdAt: now.add(const Duration(microseconds: 1)),
    );
    (_messages[id] ??= []).addAll([user, assistant]);
    return ChatTurn(
      threadId: id,
      userMessage: user,
      assistantMessage: assistant,
    );
  }

  @override
  Future<void> deleteThread(String threadId) async {
    _threads.removeWhere((t) => t.id == threadId);
    _messages.remove(threadId);
  }
}

class _PreviewAuth implements AuthRepository {
  const _PreviewAuth();
  Never _unsupported() =>
      throw const AppException('Bản mẫu UX/UI không sử dụng đăng nhập.');
  @override
  AppUser? get currentUser => null;
  @override
  Stream<AppUser?> get userChanges => const Stream.empty();
  @override
  Stream<bool> get passwordRecovery => const Stream.empty();
  @override
  Future<void> signIn(String email, String password) async => _unsupported();
  @override
  Future<SignUpResult> signUp(
    String name,
    String email,
    String password,
  ) async => _unsupported();
  @override
  Future<void> signOut() async => _unsupported();
  @override
  Future<void> signInWithGoogle() async => _unsupported();
  @override
  Future<void> requestPasswordReset(String email) async => _unsupported();
  @override
  Future<void> updatePassword(String password) async => _unsupported();
}
