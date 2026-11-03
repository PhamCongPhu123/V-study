import 'package:flutter_test/flutter_test.dart';
import 'package:vstudy/core/app_exception.dart';
import 'package:vstudy/data/data_support.dart';
import 'package:vstudy/data/preview_repository.dart';
import 'package:vstudy/domain/entities.dart';

void main() {
  late PreviewRepository repository;
  setUp(() => repository = PreviewRepository());

  test(
    'learning catalogue groups quizzes under owned subjects and chapters',
    () async {
      final subjects = await repository.listSubjects();
      for (final id in ['philosophy', 'law', 'math', 'project-management']) {
        expect(subjects.any((s) => s.id == id), isTrue);
        final chapters = await repository.listChapters(id);
        final quizzes = (await repository.listQuizzes()).where(
          (q) => q.subjectId == id,
        );
        expect(chapters.length, id == 'philosophy' ? 6 : 3);
        expect(
          chapters.every((c) => c.subjectId == id && c.questionCount > 0),
          isTrue,
        );
        expect(
          quizzes.every((q) => chapters.any((c) => c.id == q.chapterId)),
          isTrue,
        );
        final total = chapters.fold<int>(0, (sum, c) => sum + c.questionCount);
        var actual = 0;
        for (final quiz in quizzes) {
          actual += (await repository.getQuestions(quiz.id)).length;
        }
        expect(total, actual);
      }
    },
  );

  test(
    'seeded answer keys rotate positions and explain the actual chosen option',
    () async {
      final questions = await repository.getQuestions('philosophy-1-1');
      final positions = <int>{};
      for (final question in questions) {
        final review = await repository.checkPracticeAnswer(
          quizId: 'philosophy-1-1',
          questionId: question.id,
          selectedOption: 0,
        );
        positions.add(review.correctOption);
        expect(question.options.length, 4);
        expect(review.explanation, isNotEmpty);
        expect(review.selectedOption, 0);
      }
      expect(positions.length, greaterThan(1));
    },
  );

  test(
    'latest practice answer resolves and can reintroduce an actual wrong answer',
    () async {
      final wrong = (await repository.listWrongAnswers(
        subjectId: 'philosophy',
      )).first;
      await repository.checkPracticeAnswer(
        quizId: wrong.quizId,
        questionId: wrong.question.id,
        selectedOption: wrong.correctOption,
      );
      expect(
        (await repository.listWrongAnswers()).any(
          (w) => w.question.id == wrong.question.id,
        ),
        isFalse,
      );
      final selected = (wrong.correctOption + 1) % 4;
      await repository.checkPracticeAnswer(
        quizId: wrong.quizId,
        questionId: wrong.question.id,
        selectedOption: selected,
      );
      final reintroduced = (await repository.listWrongAnswers(
        subjectId: 'philosophy',
      )).singleWhere((w) => w.question.id == wrong.question.id);
      expect(reintroduced.selectedOption, selected);
      expect(
        (await repository.listWrongAnswers(
          subjectId: 'law',
        )).any((w) => w.question.id == wrong.question.id),
        isFalse,
      );
    },
  );

  test(
    'exam timeout counts missing answers wrong and preserves retry identity',
    () async {
      final questions = await repository.getQuestions('philosophy-1-2');
      final known = await repository.checkPracticeAnswer(
        quizId: 'philosophy-1-2',
        questionId: questions.first.id,
        selectedOption: 0,
      );
      final answers = {questions.first.id: known.correctOption};
      final before = (await repository.listAttempts()).length;
      await expectLater(
        repository.submit(
          quizId: 'philosophy-1-2',
          attemptId: 'incomplete',
          answers: answers,
        ),
        throwsA(isA<AppException>()),
      );
      final result = await repository.submit(
        quizId: 'philosophy-1-2',
        attemptId: 'exam-timeout',
        answers: answers,
        allowUnanswered: true,
      );
      expect(result.totalQuestions, questions.length);
      expect(result.correctCount, 1);
      expect(
        result.review.where((r) => r.selectedOption == -1).length,
        questions.length - 1,
      );
      final retry = await repository.submit(
        quizId: 'philosophy-1-2',
        attemptId: 'exam-timeout',
        answers: answers,
        allowUnanswered: true,
      );
      expect(retry.id, result.id);
      expect((await repository.listAttempts()).length, before + 1);
      await expectLater(
        repository.submit(
          quizId: 'philosophy-1-2',
          attemptId: 'exam-timeout',
          answers: {questions.first.id: (known.correctOption + 1) % 4},
          allowUnanswered: true,
        ),
        throwsA(isA<AppException>()),
      );
    },
  );

  test(
    'completed attempt review can be reopened without taking the quiz again',
    () async {
      final before = await repository.listAttempts();
      final history = await repository.getAttempt(before.first.id);
      final quiz = (await repository.listQuizzes()).singleWhere(
        (q) => q.id == history.quizId,
      );
      expect(
        history.review.length,
        (await repository.getQuestions(quiz.id)).length,
      );
      expect(
        history.correctCount,
        history.review.where((r) => r.selectedOption == r.correctOption).length,
      );
      expect((await repository.listAttempts()).length, before.length);
    },
  );

  test(
    'practice rejects questions from another set and options outside A-D',
    () async {
      final question = (await repository.getQuestions('law-1-1')).first;
      await expectLater(
        repository.checkPracticeAnswer(
          quizId: 'philosophy-1-1',
          questionId: question.id,
          selectedOption: 0,
        ),
        throwsA(isA<AppException>()),
      );
      expect(
        () => repository.useCases.checkPracticeAnswer(
          quizId: 'law-1-1',
          questionId: question.id,
          selectedOption: -1,
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repository.submit(
          quizId: 'law-1-1',
          attemptId: 'foreign',
          answers: {'foreign-question': 0},
          allowUnanswered: true,
        ),
        throwsA(isA<AppException>()),
      );
    },
  );

  test(
    'new chapters and generated sample quizzes retain validated placement metadata',
    () async {
      final chapter = await repository.useCases.createQuizChapter(
        subjectId: 'law',
        title: '  Ôn tập bổ sung  ',
      );
      expect(chapter.title, 'Ôn tập bổ sung');
      expect(chapter.position, 3);
      final id = await repository.useCases.generateQuiz(
        title: 'Bộ đề mới',
        topic: 'Pháp luật',
        questionCount: 4,
        subjectId: 'law',
        chapterId: chapter.id,
        durationMinutes: 20,
        difficulty: 'hard',
      );
      final quiz = (await repository.listQuizzes()).singleWhere(
        (q) => q.id == id,
      );
      expect(quiz.subjectId, 'law');
      expect(quiz.chapterId, chapter.id);
      expect(quiz.durationMinutes, 20);
      expect(quiz.difficulty, 'hard');
      expect(quiz.title, contains('minh họa'));
      expect(
        (await repository.listChapters(
          'law',
        )).singleWhere((c) => c.id == chapter.id).questionCount,
        4,
      );
      await expectLater(
        repository.generate(
          title: 'X',
          topic: 'Y',
          questionCount: 4,
          subjectId: 'math',
          chapterId: chapter.id,
        ),
        throwsA(isA<AppException>()),
      );
    },
  );

  test('mapping accepts legacy quiz rows and unanswered completed review', () {
    final quiz = quizFromJson({
      'id': 'legacy',
      'title': 'Cũ',
      'topic': 'Toán',
      'created_at': '2026-11-03T00:00:00Z',
      'source_document_id': null,
    });
    expect(quiz.durationMinutes, 30);
    expect(quiz.difficulty, 'medium');
    expect(quiz.chapterId, isNull);
    expect(quiz.subjectId, isNull);
    final review = answerReviewFromJson({
      'question_id': 'q',
      'selected_option': -1,
      'correct_option': 2,
      'explanation': 'Không trả lời được tính sai.',
    });
    expect(review.selectedOption, -1);
    expect(review.correctOption, 2);
    final legacyAttempt = attemptFromJson({
      'id': 'old',
      'quiz_id': 'legacy',
      'correct_count': 1,
      'total_questions': 2,
      'submitted_at': '2026-11-03T00:00:00Z',
    });
    expect(legacyAttempt.mode, 'practice');
  });

  test('attempt mode is stored and cannot change on retry', () async {
    final question = (await repository.getQuestions('law-1-1')).first;
    final answers = {question.id: 0};
    final attempt = await repository.useCases.submitQuiz(
      quizId: 'law-1-1',
      attemptId: 'mode-test',
      answers: answers,
      allowUnanswered: true,
      mode: 'exam',
    );
    expect(attempt.mode, 'exam');
    expect((await repository.getAttempt(attempt.id)).mode, 'exam');
    await expectLater(
      repository.submit(
        quizId: 'law-1-1',
        attemptId: 'mode-test',
        answers: answers,
        allowUnanswered: true,
        mode: 'practice',
      ),
      throwsA(isA<AppException>()),
    );
    expect(
      (await repository.listAttempts()).any((a) => a.mode == 'exam'),
      isTrue,
    );
    expect(
      (await repository.listAttempts()).any((a) => a.mode == 'practice'),
      isTrue,
    );
  });
}
