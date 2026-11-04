import 'dart:typed_data';

import '../core/app_exception.dart';
import '../domain/analytics.dart';
import '../domain/analytics_repository.dart';
import '../domain/account_repository.dart';
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
        AssistantRepository,
        AnalyticsRepository,
        AccountRepository {
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
        id: 'network-class',
        title: 'Lập Trình Mạng',
        kind: EventKind.classSession,
        startsAt: today.add(const Duration(hours: 13)),
        endsAt: today.add(const Duration(hours: 16, minutes: 30)),
        subjectId: 'network',
        location: 'Phòng V.P306',
        tasks: const [
          EventTask(id: 'network-prepare', title: 'Chuẩn bị bài mới'),
        ],
      ),
      StudyEvent(
        id: 'study',
        title: 'Ôn tập Đại Số Tuyến Tính',
        kind: EventKind.selfStudy,
        startsAt: today.add(const Duration(hours: 19)),
        endsAt: today.add(const Duration(hours: 21, minutes: 30)),
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
    final monday = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    for (var i = 0; i < 7; i++) {
      final date = DateTime(monday.year, monday.month, monday.day + i);
      if (date == today) {
        continue;
      }
      _events.add(
        StudyEvent(
          id: 'week-class-$i',
          title: i.isEven ? 'Giải tích 1' : 'Lập Trình Mạng',
          kind: EventKind.classSession,
          subjectId: i.isEven ? 'math' : 'network',
          startsAt: date.add(Duration(hours: i.isEven ? 8 : 13)),
          endsAt: date.add(Duration(hours: i.isEven ? 10 : 16)),
          location: i.isEven ? 'Phòng K.P206' : 'Phòng V.P306',
        ),
      );
      if (i % 3 != 0) {
        _events.add(
          StudyEvent(
            id: 'week-study-$i',
            title: 'Ôn tập kiến thức',
            kind: EventKind.selfStudy,
            subjectId: 'math',
            startsAt: date.add(const Duration(hours: 19)),
            endsAt: date.add(const Duration(hours: 21)),
          ),
        );
      }
    }
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
    _seedLearningQuizzes();
    _seedAnalyticsHistory();
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
  DateTime? _lastAnsweredAt;
  DateTime _answeredNow() {
    final now = DateTime.now();
    final baseline = _lastAnsweredAt ?? _now;
    final next = now.isAfter(baseline)
        ? now
        : baseline.add(const Duration(microseconds: 1));
    _lastAnsweredAt = next;
    return next;
  }

  String _id() => 'preview-${++_sequence}';
  Profile _profile = Profile(
    id: 'preview-user',
    displayName: 'Tom',
    className: 'D22CNTT1',
    major: 'Công nghệ thông tin',
    birthDate: DateTime(2004, 6, 15),
  );
  final _subjects = <Subject>[
    const Subject(
      id: 'philosophy',
      name: 'Triết học Mác-Lênin',
      color: '#D5AD1C',
    ),
    const Subject(id: 'law', name: 'Pháp luật đại cương', color: '#9278D4'),
    const Subject(id: 'math', name: 'Toán cao cấp'),
    const Subject(
      id: 'project-management',
      name: 'Quản trị dự án phần mềm',
      color: '#3B9B70',
    ),
    const Subject(id: 'network', name: 'Lập trình mạng', color: '#CAD2E4'),
    const Subject(id: 'design', name: 'Thiết kế UX/UI', color: '#C9A227'),
  ];
  final _events = <StudyEvent>[];
  final _sessions = <StudySession>[];
  final _documents = <StudyDocument>[];
  final _quizzes = <Quiz>[];
  final _questions = <String, List<QuizQuestion>>{};
  final _chapters = <QuizChapter>[];
  final _keys = <String, (int, String)>{};
  final _practice = <String, (String, AnswerReview, DateTime)>{};
  final _analyticsPracticeHistory = <(String, AnswerReview, DateTime)>[];
  final _attempts = <QuizAttempt>[];
  final _submitted = <String, Map<String, int>>{};
  final _threads = <ChatThread>[];
  final _messages = <String, List<ChatMessage>>{};
  LearningGoals? _learningGoals;
  final _focusSessions = <FocusSession>[];
  final _flashcardSessions = <FlashcardSession>[];

  VstudyUseCases get useCases => VstudyUseCases(
    auth: const _PreviewAuth(),
    study: this,
    documents: this,
    quizzes: this,
    assistant: this,
    analytics: this,
    account: this,
  );

  // Seed once, rather than on refresh, so edits and newly logged activity remain
  // visible. These are explicitly prototype records, not real learner metrics.
  void _seedAnalyticsHistory() {
    _learningGoals = LearningGoals.defaults(_now);
    final today = localDay(_now);
    const subjects = ['philosophy', 'math', 'law', 'design', 'network'];
    for (var daysAgo = 0; daysAgo <= 183; daysAgo++) {
      final date = DateTime(today.year, today.month, today.day - daysAgo);
      final active =
          daysAgo < 7 || (date.weekday != DateTime.sunday && daysAgo % 11 != 0);
      if (!active) {
        continue;
      }
      final subject = subjects[daysAgo % subjects.length];
      if (daysAgo >= 7) {
        // Preserve the existing seven daily sessions used by the home preview.
        _sessions.add(
          StudySession(
            id: 'analytics-study-$daysAgo',
            startedAt: DateTime(date.year, date.month, date.day, 18, 10),
            durationMinutes: 55 + (daysAgo * 17) % 91,
            subjectId: subject,
          ),
        );
      }
      final planned = [25, 40, 50][daysAgo % 3];
      _focusSessions.add(
        FocusSession(
          id: 'analytics-focus-$daysAgo',
          startedAt: daysAgo == 0
              ? _now.subtract(const Duration(hours: 2))
              : DateTime(date.year, date.month, date.day, 18, 10),
          plannedMinutes: planned,
          focusedMinutes: planned - 2 - daysAgo % 7,
          interruptions: daysAgo % 4,
          subjectId: subject,
        ),
      );
      final reviewed = 15 + (daysAgo * 7) % 26;
      _flashcardSessions.add(
        FlashcardSession(
          id: 'analytics-flashcards-$daysAgo',
          reviewedAt: daysAgo == 0
              ? _now.subtract(const Duration(minutes: 45))
              : DateTime(date.year, date.month, date.day, 20, 30),
          reviewedCards: reviewed,
          rememberedCards: reviewed - 2 - daysAgo % 6,
          subjectId: subject,
        ),
      );
    }
  }

  @override
  Future<AnalyticsSnapshot> loadSnapshot({required DateTime now}) async =>
      AnalyticsSnapshot(
        now: now.toLocal(),
        profile: _profile,
        goals: _learningGoals ?? LearningGoals.defaults(now),
        subjects: List.unmodifiable(_subjects),
        studySessions: List.unmodifiable(
          _sessions.where((session) => !session.startedAt.isAfter(now)),
        ),
        quizzes: List.unmodifiable(_quizzes),
        quizAttempts: List.unmodifiable(
          _attempts.where((attempt) => !attempt.submittedAt.isAfter(now)),
        ),
        focusSessions: List.unmodifiable(
          _focusSessions.where((session) => !session.startedAt.isAfter(now)),
        ),
        flashcardSessions: List.unmodifiable(
          _flashcardSessions.where(
            (session) => !session.reviewedAt.isAfter(now),
          ),
        ),
        tasks: [
          for (final event in _events)
            if (!event.startsAt.isAfter(now))
              for (final task in event.tasks)
                LearningTask(
                  date: event.startsAt.toLocal(),
                  completed: task.isCompleted,
                  subjectId: event.subjectId,
                ),
        ],
        chapterMastery: _chapterMasteryThrough(now),
      );

  List<ChapterMastery> _chapterMasteryThrough(DateTime until) {
    final latest = <String, (AnswerReview, DateTime)>{};
    void include(AnswerReview answer, DateTime answeredAt) {
      if (answeredAt.isAfter(until)) {
        return;
      }
      final previous = latest[answer.questionId];
      if (previous == null || !answeredAt.isBefore(previous.$2)) {
        latest[answer.questionId] = (answer, answeredAt);
      }
    }

    for (final attempt in _attempts) {
      for (final answer in attempt.review) {
        include(answer, attempt.submittedAt);
      }
    }
    for (final practice in _analyticsPracticeHistory) {
      include(practice.$2, practice.$3);
    }
    return [
      for (final chapter in _chapters)
        (() {
          final ids = {
            for (final quiz in _quizzes)
              if (quiz.chapterId == chapter.id)
                for (final question in _questions[quiz.id] ?? <QuizQuestion>[])
                  question.id,
          };
          final answers = ids
              .map((id) => latest[id]?.$1)
              .whereType<AnswerReview>();
          return ChapterMastery(
            id: chapter.id,
            subjectId: chapter.subjectId,
            title: chapter.title,
            position: chapter.position,
            totalQuestions: ids.length,
            answeredQuestions: answers
                .where((a) => a.selectedOption >= 0)
                .length,
            correctQuestions: answers
                .where((a) => a.selectedOption == a.correctOption)
                .length,
          );
        })(),
    ];
  }

  @override
  Future<void> saveGoals(LearningGoals goals) async {
    final start = goals.semesterStart;
    final end = goals.semesterEnd;
    final days = DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    if (goals.weeklyMinutes < 60 ||
        goals.weeklyMinutes > 10080 ||
        goals.studyDaysPerWeek < 1 ||
        goals.studyDaysPerWeek > 7 ||
        goals.flashcardsPerDay < 1 ||
        goals.flashcardsPerDay > 1000 ||
        days < 7 ||
        days > 366) {
      throw const AppException('Mục tiêu học tập chưa hợp lệ.');
    }
    _learningGoals = LearningGoals(
      weeklyMinutes: goals.weeklyMinutes,
      studyDaysPerWeek: goals.studyDaysPerWeek,
      flashcardsPerDay: goals.flashcardsPerDay,
      semesterStart: DateTime(start.year, start.month, start.day),
      semesterEnd: DateTime(end.year, end.month, end.day),
    );
  }

  void _requireAnalyticsSubject(String? subjectId) {
    if (subjectId != null &&
        !_subjects.any((subject) => subject.id == subjectId)) {
      throw const AppException('Không tìm thấy môn học.');
    }
  }

  @override
  Future<void> logFocusSession({
    required DateTime startedAt,
    required int plannedMinutes,
    required int focusedMinutes,
    required int interruptions,
    String? subjectId,
  }) async {
    _requireAnalyticsSubject(subjectId);
    final now = DateTime.now();
    if (plannedMinutes < 1 ||
        plannedMinutes > 1440 ||
        focusedMinutes < 0 ||
        focusedMinutes > plannedMinutes ||
        interruptions < 0 ||
        interruptions > 1000 ||
        startedAt.isAfter(now) ||
        startedAt
            .add(Duration(minutes: plannedMinutes))
            .isAfter(now.add(const Duration(minutes: 1)))) {
      throw const AppException('Phiên tập trung đã hoàn tất chưa hợp lệ.');
    }
    _focusSessions.add(
      FocusSession(
        id: _id(),
        startedAt: startedAt.toLocal(),
        plannedMinutes: plannedMinutes,
        focusedMinutes: focusedMinutes,
        interruptions: interruptions,
        subjectId: subjectId,
      ),
    );
  }

  @override
  Future<void> logFlashcardSession({
    required DateTime reviewedAt,
    required int reviewedCards,
    required int rememberedCards,
    String? subjectId,
  }) async {
    _requireAnalyticsSubject(subjectId);
    if (reviewedCards < 1 ||
        reviewedCards > 10000 ||
        rememberedCards < 0 ||
        rememberedCards > reviewedCards ||
        reviewedAt.isAfter(DateTime.now())) {
      throw const AppException('Lượt ôn flashcard chưa hợp lệ.');
    }
    _flashcardSessions.add(
      FlashcardSession(
        id: _id(),
        reviewedAt: reviewedAt.toLocal(),
        reviewedCards: reviewedCards,
        rememberedCards: rememberedCards,
        subjectId: subjectId,
      ),
    );
  }

  @override
  Future<Profile> getProfile() async => _profile;
  @override
  Future<void> updateProfile({
    required String displayName,
    required int dailyGoalMinutes,
  }) async {
    _profile = _profile.copyWith(
      displayName: displayName,
      dailyGoalMinutes: dailyGoalMinutes,
    );
  }

  @override
  Future<void> saveAccount(AccountDraft draft) async {
    _profile = _profile.copyWith(
      displayName: draft.displayName,
      dailyGoalMinutes: draft.dailyGoalMinutes,
      className: draft.className,
      major: draft.major,
      birthDate: draft.birthDate,
      clearBirthDate: draft.birthDate == null,
      avatarKey: draft.avatarKey,
    );
  }

  @override
  Future<void> saveAccountPreferences(AccountPreferences preferences) async {
    _profile = _profile.copyWith(preferences: preferences);
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
  static const _philosophyQuestions = [
    (
      'Vấn đề cơ bản của mọi triết học là mối quan hệ giữa yếu tố nào?',
      [
        'Vật chất và ý thức',
        'Con người và tự nhiên',
        'Lý luận và thực tiễn',
        'Cá nhân và cộng đồng',
      ],
      'Vấn đề cơ bản của triết học là quan hệ giữa vật chất và ý thức, gồm mặt bản thể luận và mặt nhận thức luận.',
    ),
    (
      'Theo chủ nghĩa duy vật biện chứng, vật chất có đặc điểm nào?',
      [
        'Tồn tại khách quan, độc lập với ý thức',
        'Chỉ tồn tại khi được cảm nhận',
        'Do ý niệm tuyệt đối tạo ra',
        'Đồng nhất với một vật thể cụ thể',
      ],
      'Phạm trù vật chất chỉ thực tại khách quan được đem lại cho con người trong cảm giác, tồn tại không lệ thuộc vào cảm giác.',
    ),
    (
      'Nguồn gốc xã hội của ý thức gồm những yếu tố nào?',
      [
        'Lao động và ngôn ngữ',
        'Bản năng và giấc mơ',
        'Khí hậu và địa hình',
        'Vận động cơ học và nhiệt',
      ],
      'Lao động và ngôn ngữ là những nguồn gốc xã hội trực tiếp, quan trọng của sự hình thành ý thức.',
    ),
    (
      'Thực tiễn có vai trò nào đối với nhận thức?',
      [
        'Là cơ sở, động lực, mục đích và tiêu chuẩn kiểm tra chân lý',
        'Thay thế hoàn toàn tư duy',
        'Chỉ là kết quả thụ động của ý thức',
        'Không liên quan đến chân lý',
      ],
      'Nhận thức xuất phát từ thực tiễn, phục vụ thực tiễn và được kiểm tra bằng thực tiễn.',
    ),
    (
      'Quy luật lượng - chất nói về điều gì?',
      [
        'Sự thay đổi về lượng dẫn đến thay đổi về chất và ngược lại',
        'Mọi thay đổi lượng đều lập tức đổi chất',
        'Chất không bao giờ thay đổi',
        'Lượng và chất tồn tại tách biệt',
      ],
      'Biến đổi về lượng tích lũy đến điểm nút có thể tạo bước nhảy làm thay đổi chất; chất mới tác động trở lại lượng.',
    ),
    (
      'Theo chủ nghĩa duy vật lịch sử, tồn tại xã hội có quan hệ nào với ý thức xã hội?',
      [
        'Tồn tại xã hội quyết định ý thức xã hội',
        'Ý thức xã hội luôn có trước tồn tại xã hội',
        'Hai yếu tố không liên hệ',
        'Ý thức xã hội không có tính độc lập tương đối',
      ],
      'Tồn tại xã hội quyết định ý thức xã hội; ý thức xã hội có tính độc lập tương đối và tác động trở lại tồn tại xã hội.',
    ),
    (
      'Phủ định biện chứng có tính chất nào?',
      [
        'Khách quan và kế thừa',
        'Xóa sạch toàn bộ cái cũ',
        'Chỉ do ý muốn cá nhân',
        'Chấm dứt mọi sự phát triển',
      ],
      'Phủ định biện chứng do mâu thuẫn bên trong sự vật và kế thừa những yếu tố phù hợp của cái cũ.',
    ),
    (
      'Theo quan điểm biện chứng, mối liên hệ có đặc điểm nào?',
      [
        'Khách quan, phổ biến và đa dạng',
        'Chỉ tồn tại trong suy nghĩ',
        'Luôn giống nhau ở mọi sự vật',
        'Không phụ thuộc điều kiện cụ thể',
      ],
      'Quan điểm toàn diện cần xem xét các mối liên hệ trong điều kiện lịch sử cụ thể, tránh cách nhìn phiến diện.',
    ),
  ];
  static const _lawQuestions = [
    (
      'Dấu hiệu đặc trưng của quy phạm pháp luật là gì?',
      [
        'Có tính bắt buộc chung và được Nhà nước bảo đảm thực hiện',
        'Chỉ là lời khuyên tự nguyện',
        'Chỉ áp dụng cho người lập ra nó',
        'Không được thể hiện bằng hình thức xác định',
      ],
      'Quy phạm pháp luật là quy tắc xử sự chung do Nhà nước ban hành hoặc thừa nhận, bảo đảm thực hiện.',
    ),
    (
      'Một văn bản quy phạm pháp luật phải được ban hành như thế nào?',
      [
        'Đúng thẩm quyền, hình thức và trình tự luật định',
        'Theo ý kiến cá nhân bất kỳ',
        'Chỉ cần đăng mạng xã hội',
        'Không cần căn cứ pháp lý',
      ],
      'Thẩm quyền, hình thức và trình tự là các yêu cầu đối với việc ban hành văn bản quy phạm pháp luật.',
    ),
    (
      'Năng lực hành vi của cá nhân thể hiện khả năng nào?',
      [
        'Bằng hành vi của mình xác lập, thực hiện quyền và nghĩa vụ',
        'Biết đọc mọi văn bản',
        'Luôn được miễn trách nhiệm',
        'Có quyền thay đổi mọi luật',
      ],
      'Năng lực hành vi liên quan khả năng tự mình xác lập và thực hiện quyền, nghĩa vụ theo pháp luật.',
    ),
    (
      'Quan hệ pháp luật gồm những thành phần cơ bản nào?',
      [
        'Chủ thể, khách thể và nội dung',
        'Tên gọi, màu sắc và hình dáng',
        'Tiêu đề và phần kết',
        'Chỉ quyền của một bên',
      ],
      'Chủ thể tham gia quan hệ, khách thể hướng tới, nội dung gồm quyền và nghĩa vụ pháp lý.',
    ),
    (
      'Trách nhiệm pháp lý thường phát sinh trên cơ sở nào?',
      [
        'Vi phạm pháp luật theo các điều kiện luật định',
        'Mọi ý kiến khác biệt',
        'Mọi thiệt hại không cần xét điều kiện',
        'Sở thích của người xử lý',
      ],
      'Việc xác định trách nhiệm phải dựa trên căn cứ và điều kiện do pháp luật quy định.',
    ),
  ];
  static const _mathQuestions = [
    (
      'Đạo hàm của f(x) = x² là gì?',
      ['2x', 'x', 'x³', '2'],
      'Áp dụng quy tắc đạo hàm lũy thừa: (xⁿ)′ = nxⁿ⁻¹.',
    ),
    (
      'Giới hạn của sin(x)/x khi x tiến tới 0 là bao nhiêu?',
      ['1', '0', 'Không tồn tại', 'Vô cùng'],
      'Đây là giới hạn lượng giác cơ bản, với góc tính bằng radian.',
    ),
    (
      'Nguyên hàm của 2x có dạng nào?',
      ['x² + C', '2 + C', '2x² + C', 'x + C'],
      'Đạo hàm của x² + C bằng 2x.',
    ),
    (
      'Định thức của ma trận đơn vị cấp 2 bằng bao nhiêu?',
      ['1', '0', '2', '-1'],
      'Định thức ma trận đơn vị bằng tích các phần tử đường chéo, bằng 1.',
    ),
    (
      'Một hệ tuyến tính thuần nhất luôn có nghiệm nào?',
      [
        'Nghiệm không',
        'Duy nhất nghiệm khác không',
        'Không có nghiệm',
        'Mọi vector đều là nghiệm',
      ],
      'Vector không luôn thỏa hệ Ax = 0.',
    ),
  ];
  static const _projectQuestions = [
    (
      'Mục đích của quản lý phạm vi dự án là gì?',
      [
        'Xác định và kiểm soát công việc thuộc dự án',
        'Thay đổi yêu cầu không kiểm soát',
        'Chỉ chọn màu giao diện',
        'Bỏ qua sản phẩm bàn giao',
      ],
      'Quản lý phạm vi giúp bảo đảm dự án bao gồm công việc cần thiết để đạt mục tiêu.',
    ),
    (
      'Rủi ro dự án nên được xử lý như thế nào?',
      [
        'Nhận diện, phân tích và lập phương án ứng phó',
        'Chờ xảy ra rồi bỏ qua',
        'Giấu với các bên liên quan',
        'Xem mọi rủi ro là chắc chắn',
      ],
      'Rủi ro là sự kiện không chắc chắn; cần được theo dõi và ứng phó có kế hoạch.',
    ),
    (
      'Trong Scrum, Product Backlog thể hiện điều gì?',
      [
        'Danh sách công việc được sắp xếp thứ tự cho sản phẩm',
        'Bảng chấm công bắt buộc',
        'Chỉ các lỗi đã đóng',
        'Danh sách thiết bị văn phòng',
      ],
      'Product Backlog là danh sách được sắp thứ tự về những gì cần cho sản phẩm.',
    ),
    (
      'WBS được dùng để làm gì?',
      [
        'Phân rã phạm vi thành các phần công việc quản lý được',
        'Tăng số yêu cầu tùy ý',
        'Thay thế mọi kế hoạch',
        'Chỉ lưu mã nguồn',
      ],
      'Cấu trúc phân rã công việc giúp tổ chức phạm vi theo các thành phần có thể quản lý.',
    ),
    (
      'Một thay đổi yêu cầu nên được đánh giá theo yếu tố nào?',
      [
        'Tác động đến phạm vi, thời gian, chi phí và chất lượng',
        'Chỉ cảm tính cá nhân',
        'Chỉ tên người yêu cầu',
        'Không cần đánh giá',
      ],
      'Đánh giá tác động hỗ trợ quyết định thay đổi và cập nhật kế hoạch phù hợp.',
    ),
  ];

  void _seedLearningQuizzes() {
    const titles = {
      'philosophy': [
        'Lịch sử hình thành và phát triển',
        'Duy vật biện chứng',
        'Duy vật lịch sử',
        'Chủ nghĩa duy tâm',
        'Sự phát triển của triết học Mác-Lênin',
        'Lý luận nhận thức',
      ],
      'law': [
        'Những vấn đề cơ bản về pháp luật',
        'Quy phạm và quan hệ pháp luật',
        'Vi phạm và trách nhiệm pháp lý',
      ],
      'math': [
        'Giới hạn và liên tục',
        'Đạo hàm và tích phân',
        'Đại số tuyến tính',
      ],
      'project-management': [
        'Tổng quan quản lý dự án',
        'Lập kế hoạch và rủi ro',
        'Phương pháp Agile và Scrum',
      ],
    };
    for (final course in titles.entries) {
      for (var index = 0; index < course.value.length; index++) {
        final chapterId = '${course.key}-chapter-${index + 1}';
        _chapters.add(
          QuizChapter(
            id: chapterId,
            subjectId: course.key,
            title: course.value[index],
            position: index,
          ),
        );
        final sets = course.key == 'philosophy' ? 2 : 1;
        for (var variant = 0; variant < sets; variant++) {
          final id = '${course.key}-${index + 1}-${variant + 1}';
          _addQuiz(
            id,
            'Đề ${variant + 1} · Chương ${index + 1}',
            'Câu hỏi nền tảng minh họa — ${course.value[index]}',
            5,
            subjectId: course.key,
            chapterId: chapterId,
            difficulty: ['easy', 'medium', 'hard'][(index + variant) % 3],
            durationMinutes: 15 + variant * 15,
            questionOffset: index + variant,
          );
        }
      }
    }
    _addQuiz(
      'ux-quiz',
      'Nguyên lý UX/UI',
      'Thiết kế lấy người dùng làm trung tâm',
      5,
      subjectId: 'design',
    );
    // Coherent sample history: these reviews use the same keys as the player.
    final historyIds = [
      'philosophy-1-1',
      'philosophy-2-1',
      'law-1-1',
      'math-1-1',
    ];
    for (var i = 0; i < historyIds.length; i++) {
      final questions = _questions[historyIds[i]]!;
      final answers = <String, int>{};
      for (final question in questions) {
        final correct = _keys[question.id]!.$1;
        answers[question.id] = question.position % (i + 2) == 0
            ? (correct + 1) % 4
            : correct;
      }
      _recordAttempt(
        historyIds[i],
        'sample-attempt-$i',
        answers,
        _now.subtract(Duration(days: i, hours: 1)),
        i.isEven ? 'exam' : 'practice',
      );
    }
    _quizzes.sort((a, b) {
      final aSubject = a.subjectId == 'philosophy' ? 0 : 1;
      final bSubject = b.subjectId == 'philosophy' ? 0 : 1;
      return aSubject.compareTo(bSubject);
    });
  }

  void _addQuiz(
    String id,
    String title,
    String topic,
    int count, {
    String? documentId,
    String? subjectId,
    String? chapterId,
    int durationMinutes = 30,
    String difficulty = 'medium',
    int questionOffset = 0,
  }) {
    _quizzes.add(
      Quiz(
        id: id,
        title: title,
        topic: topic,
        createdAt: _now,
        sourceDocumentId: documentId,
        subjectId: subjectId,
        chapterId: chapterId,
        durationMinutes: durationMinutes,
        difficulty: difficulty,
      ),
    );
    final bank = switch (subjectId) {
      'philosophy' => _philosophyQuestions,
      'law' => _lawQuestions,
      'math' => _mathQuestions,
      'project-management' => _projectQuestions,
      _ => _sampleQuestions,
    };
    _questions[id] = List.generate(count, (i) {
      final sample = bank[(i + questionOffset) % bank.length];
      final rotation = (i + questionOffset) % 4;
      final options = List<String>.generate(
        4,
        (index) => sample.$2[(index - rotation + 4) % 4],
      );
      final question = QuizQuestion(
        id: '$id-q$i',
        position: i,
        question: sample.$1,
        options: List.unmodifiable(options),
      );
      _keys[question.id] = (rotation, sample.$3);
      return question;
    });
  }

  Quiz _quiz(String id) => _quizzes.firstWhere(
    (q) => q.id == id,
    orElse: () => throw const AppException('Không tìm thấy quiz.'),
  );

  List<QuizQuestion> _quizQuestions(String id) {
    _quiz(id);
    return _questions[id]!;
  }

  @override
  Future<List<Quiz>> listQuizzes() async => List.unmodifiable(_quizzes);
  @override
  Future<List<QuizQuestion>> getQuestions(String quizId) async =>
      List.unmodifiable(_quizQuestions(quizId));
  @override
  Future<List<QuizChapter>> listChapters(String subjectId) async => _chapters
      .where((chapter) => chapter.subjectId == subjectId)
      .map(
        (chapter) => QuizChapter(
          id: chapter.id,
          subjectId: chapter.subjectId,
          title: chapter.title,
          position: chapter.position,
          questionCount: _quizzes
              .where((q) => q.chapterId == chapter.id)
              .fold<int>(0, (sum, q) => sum + _quizQuestions(q.id).length),
        ),
      )
      .toList(growable: false);

  @override
  Future<QuizChapter> createChapter({
    required String subjectId,
    required String title,
  }) async {
    if (!_subjects.any((s) => s.id == subjectId) ||
        title.trim().isEmpty ||
        title.trim().length > 200) {
      throw const AppException('Tên chương hoặc môn học chưa hợp lệ.');
    }
    final positions = _chapters
        .where((c) => c.subjectId == subjectId)
        .map((c) => c.position);
    final position = positions.fold<int>(-1, (a, b) => a > b ? a : b) + 1;
    final chapter = QuizChapter(
      id: _id(),
      subjectId: subjectId,
      title: title.trim(),
      position: position,
    );
    _chapters.add(chapter);
    return chapter;
  }

  @override
  Future<String> generate({
    required String title,
    required String topic,
    required int questionCount,
    String? documentId,
    String? subjectId,
    String? chapterId,
    int durationMinutes = 30,
    String difficulty = 'medium',
  }) async {
    if (questionCount < 1 ||
        questionCount > 30 ||
        durationMinutes < 1 ||
        durationMinutes > 180 ||
        !['easy', 'medium', 'hard'].contains(difficulty)) {
      throw const AppException('Thông số quiz chưa hợp lệ.');
    }
    if (subjectId != null && !_subjects.any((s) => s.id == subjectId)) {
      throw const AppException('Không tìm thấy môn học.');
    }
    if (chapterId != null &&
        !_chapters.any((c) => c.id == chapterId && c.subjectId == subjectId)) {
      throw const AppException('Chương không thuộc môn học đã chọn.');
    }
    if (documentId != null && !_documents.any((d) => d.id == documentId)) {
      throw const AppException('Không tìm thấy tài liệu.');
    }
    final id = _id();
    _addQuiz(
      id,
      '$title (minh họa)',
      topic,
      questionCount,
      documentId: documentId,
      subjectId: subjectId,
      chapterId: chapterId,
      durationMinutes: durationMinutes,
      difficulty: difficulty,
    );
    return id;
  }

  QuizAttempt _recordAttempt(
    String quizId,
    String attemptId,
    Map<String, int> normalized,
    DateTime timestamp, [
    String mode = 'practice',
  ]) {
    final questions = _quizQuestions(quizId);
    final result = QuizAttempt(
      id: attemptId,
      quizId: quizId,
      correctCount: questions
          .where((q) => normalized[q.id] == _keys[q.id]!.$1)
          .length,
      totalQuestions: questions.length,
      submittedAt: timestamp,
      mode: mode,
      review: questions
          .map(
            (q) => AnswerReview(
              questionId: q.id,
              selectedOption: normalized[q.id]!,
              correctOption: _keys[q.id]!.$1,
              explanation: _keys[q.id]!.$2,
            ),
          )
          .toList(growable: false),
    );
    _attempts.insert(0, result);
    _submitted[attemptId] = Map.unmodifiable(normalized);
    return result;
  }

  @override
  Future<QuizAttempt> submit({
    required String quizId,
    required String attemptId,
    required Map<String, int> answers,
    bool allowUnanswered = false,
    String mode = 'practice',
  }) async {
    if (!['practice', 'exam'].contains(mode)) {
      throw const AppException('Chế độ làm bài chưa hợp lệ.');
    }
    final questions = _quizQuestions(quizId);
    final ids = questions.map((q) => q.id).toSet();
    if (answers.keys.any((id) => !ids.contains(id)) ||
        answers.values.any((v) => v < 0 || v > 3) ||
        (!allowUnanswered && answers.length != questions.length)) {
      throw const AppException('Vui lòng trả lời đầy đủ câu hỏi hợp lệ.');
    }
    final normalized = {for (final q in questions) q.id: answers[q.id] ?? -1};
    final previous = _attempts.where((a) => a.id == attemptId);
    if (previous.isNotEmpty) {
      final old = _submitted[attemptId]!;
      if (previous.first.quizId != quizId ||
          previous.first.mode != mode ||
          old.length != normalized.length ||
          normalized.entries.any((e) => old[e.key] != e.value)) {
        throw const AppException('Mã bài nộp đã dùng với đáp án khác.');
      }
      return previous.first;
    }
    return _recordAttempt(quizId, attemptId, normalized, _answeredNow(), mode);
  }

  @override
  Future<List<QuizAttempt>> listAttempts() async => List.unmodifiable(
    _attempts.toList()..sort((a, b) => b.submittedAt.compareTo(a.submittedAt)),
  );
  @override
  Future<QuizAttempt> getAttempt(String attemptId) async =>
      _attempts.firstWhere(
        (a) => a.id == attemptId,
        orElse: () => throw const AppException('Không tìm thấy kết quả.'),
      );

  @override
  Future<AnswerReview> checkPracticeAnswer({
    required String quizId,
    required String questionId,
    required int selectedOption,
  }) async {
    final questions = _quizQuestions(quizId);
    if (selectedOption < 0 ||
        selectedOption > 3 ||
        !questions.any((q) => q.id == questionId)) {
      throw const AppException('Câu hỏi hoặc đáp án chưa hợp lệ.');
    }
    final key = _keys[questionId]!;
    final review = AnswerReview(
      questionId: questionId,
      selectedOption: selectedOption,
      correctOption: key.$1,
      explanation: key.$2,
    );
    final recorded = (quizId, review, _answeredNow());
    _practice[questionId] = recorded;
    _analyticsPracticeHistory.add(recorded);
    return review;
  }

  @override
  Future<List<WrongQuizAnswer>> listWrongAnswers({String? subjectId}) async {
    final latest = <String, (String, AnswerReview, DateTime)>{};
    for (final attempt in _attempts) {
      for (final answer in attempt.review) {
        final previous = latest[answer.questionId];
        if (previous == null || !attempt.submittedAt.isBefore(previous.$3)) {
          latest[answer.questionId] = (
            attempt.quizId,
            answer,
            attempt.submittedAt,
          );
        }
      }
    }
    for (final entry in _practice.entries) {
      final previous = latest[entry.key];
      if (previous == null || !entry.value.$3.isBefore(previous.$3)) {
        latest[entry.key] = entry.value;
      }
    }
    final result = <WrongQuizAnswer>[];
    for (final value in latest.values) {
      final quiz = _quiz(value.$1);
      final answer = value.$2;
      if ((subjectId == null || quiz.subjectId == subjectId) &&
          answer.selectedOption != answer.correctOption) {
        result.add(
          WrongQuizAnswer(
            quizId: quiz.id,
            quizTitle: quiz.title,
            subjectId: quiz.subjectId,
            chapterId: quiz.chapterId,
            question: _quizQuestions(
              quiz.id,
            ).firstWhere((q) => q.id == answer.questionId),
            selectedOption: answer.selectedOption,
            correctOption: answer.correctOption,
            explanation: answer.explanation,
            answeredAt: value.$3,
          ),
        );
      }
    }
    result.sort((a, b) => b.answeredAt.compareTo(a.answeredAt));
    return result;
  }

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
