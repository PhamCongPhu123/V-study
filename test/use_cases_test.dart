import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vstudy/core/app_exception.dart';
import 'package:vstudy/domain/entities.dart';
import 'package:vstudy/domain/repositories.dart';
import 'package:vstudy/domain/use_cases.dart';

class _Auth implements AuthRepository {
  List<String>? registration;
  @override
  Future<SignUpResult> signUp(
    String name,
    String email,
    String password,
  ) async {
    registration = [name, email, password];
    return const SignUpResult(needsEmailConfirmation: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Study implements StudyRepository {
  EventDraft? created;
  @override
  Future<List<StudyEvent>> createEvent(EventDraft draft) async {
    created = draft;
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Documents implements DocumentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Quizzes implements QuizRepository {
  int? count;
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
    count = questionCount;
    return 'new-quiz';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Assistant implements AssistantRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late _Auth auth;
  late _Study study;
  late _Quizzes quizzes;
  late VstudyUseCases useCases;
  setUp(() {
    auth = _Auth();
    study = _Study();
    quizzes = _Quizzes();
    useCases = VstudyUseCases(
      auth: auth,
      study: study,
      documents: _Documents(),
      quizzes: quizzes,
      assistant: _Assistant(),
    );
  });

  test(
    'signup normalizes name/email and preserves password and confirmation state',
    () async {
      final result = await useCases.signUp(
        '  Phú  ',
        '  student@example.com ',
        ' secure password ',
        ' secure password ',
        true,
      );
      expect(auth.registration, [
        'Phú',
        'student@example.com',
        ' secure password ',
      ]);
      expect(result.needsEmailConfirmation, isTrue);
    },
  );

  test(
    'signup rejects missing consent, mismatched password and invalid email before network',
    () {
      expect(
        () => useCases.signUp(
          'Phú',
          'student@example.com',
          'password123',
          'password123',
          false,
        ),
        throwsA(isA<AppException>()),
      );
      expect(
        () => useCases.signUp(
          'Phú',
          'student@example.com',
          'password123',
          'password124',
          true,
        ),
        throwsA(isA<AppException>()),
      );
      expect(
        () => useCases.signUp(
          'Phú',
          'wrong-email',
          'password123',
          'password123',
          true,
        ),
        throwsA(isA<AppException>()),
      );
      expect(auth.registration, isNull);
    },
  );

  test('event validates duration and recurrence before writing', () async {
    final start = DateTime.utc(2026, 11, 3, 8);
    expect(
      () => useCases.createEvent(
        EventDraft(
          title: 'Giải tích',
          kind: EventKind.selfStudy,
          startsAt: start,
          endsAt: start,
        ),
      ),
      throwsA(isA<AppException>()),
    );
    expect(
      () => useCases.createEvent(
        EventDraft(
          title: 'Giải tích',
          kind: EventKind.selfStudy,
          startsAt: start,
          endsAt: start.add(const Duration(hours: 1)),
          repeatWeeks: 53,
        ),
      ),
      throwsA(isA<AppException>()),
    );
    expect(study.created, isNull);
    await useCases.createEvent(
      EventDraft(
        title: 'Giải tích',
        kind: EventKind.selfStudy,
        startsAt: start,
        endsAt: start.add(const Duration(hours: 1)),
        repeatWeeks: 4,
        taskTitles: ['Đọc chương 3'],
      ),
    );
    expect(study.created!.repeatWeeks, 4);
  });

  test('completed learning session cannot end in the future', () {
    expect(
      () => useCases.logSession(startedAt: DateTime.now(), durationMinutes: 30),
      throwsA(isA<AppException>()),
    );
    expect(
      () => useCases.logSession(
        startedAt: DateTime.utc(2026),
        durationMinutes: 0,
      ),
      throwsA(isA<AppException>()),
    );
  });

  test('quiz generation rejects invalid count without contacting AI', () async {
    expect(
      () => useCases.generateQuiz(
        title: 'Quiz',
        topic: 'Đại số',
        questionCount: 31,
      ),
      throwsA(isA<AppException>()),
    );
    expect(quizzes.count, isNull);
    expect(
      await useCases.generateQuiz(
        title: 'Quiz',
        topic: 'Đại số',
        questionCount: 10,
      ),
      'new-quiz',
    );
    expect(quizzes.count, 10);
  });

  test('upload rejects empty, excessive, or unsupported documents', () {
    expect(
      () => useCases.uploadDocument(
        title: 'Tài liệu',
        filename: 'a.txt',
        mimeType: 'text/plain',
        bytes: Uint8List(0),
      ),
      throwsA(isA<AppException>()),
    );
    expect(
      () => useCases.uploadDocument(
        title: 'Tài liệu',
        filename: 'a.pdf',
        mimeType: 'application/pdf',
        bytes: Uint8List(10 * 1024 * 1024 + 1),
      ),
      throwsA(isA<AppException>()),
    );
    expect(
      () => useCases.uploadDocument(
        title: 'Tài liệu',
        filename: 'a.html',
        mimeType: 'text/html',
        bytes: Uint8List.fromList([1]),
      ),
      throwsA(isA<AppException>()),
    );
  });
}
