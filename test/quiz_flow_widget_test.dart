import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vstudy/data/preview_repository.dart';
import 'package:vstudy/domain/entities.dart';
import 'package:vstudy/presentation/ai_page.dart';
import 'package:vstudy/presentation/app.dart';
import 'package:vstudy/presentation/design_system.dart';
import 'package:vstudy/presentation/quiz_page.dart';
import 'package:vstudy/presentation/quiz_player.dart';

class _RecordingPreview extends PreviewRepository {
  int submissions = 0;
  int practiceChecks = 0;
  bool? lastAllowUnanswered;
  String? lastMode;
  Map<String, int>? lastAnswers;
  AnswerReview? lastFeedback;

  @override
  Future<AnswerReview> checkPracticeAnswer({
    required String quizId,
    required String questionId,
    required int selectedOption,
  }) async {
    practiceChecks++;
    return lastFeedback = await super.checkPracticeAnswer(
      quizId: quizId,
      questionId: questionId,
      selectedOption: selectedOption,
    );
  }

  @override
  Future<QuizAttempt> submit({
    required String quizId,
    required String attemptId,
    required Map<String, int> answers,
    bool allowUnanswered = false,
    String mode = 'practice',
  }) {
    submissions++;
    lastAllowUnanswered = allowUnanswered;
    lastMode = mode;
    lastAnswers = Map.of(answers);
    return super.submit(
      quizId: quizId,
      attemptId: attemptId,
      answers: answers,
      allowUnanswered: allowUnanswered,
      mode: mode,
    );
  }
}

void main() {
  late _RecordingPreview preview;
  setUp(() => preview = _RecordingPreview());

  void size(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    if (finder.evaluate().isEmpty) {
      final scrollable = find.byType(Scrollable).first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(finder, 180, scrollable: scrollable);
    }
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openQuiz(WidgetTester tester) async {
    size(tester);
    await tester.pumpWidget(
      VstudyApp(useCases: preview.useCases, preview: true),
    );
    await tester.pumpAndSettle();
    await tapKey(tester, 'footer-quiz');
  }

  Future<Subject> openPhilosophy(WidgetTester tester) async {
    final subject = (await preview.listSubjects()).firstWhere(
      (s) => s.name.contains('Triết'),
    );
    await tapKey(tester, 'quiz-course-${subject.id}');
    expect(find.byType(QuizCoursePage), findsOneWidget);
    return subject;
  }

  testWidgets(
    'second footer destination opens Quiz and gold sparkle opens AI separately',
    (tester) async {
      await openQuiz(tester);
      expect(find.byType(QuizPage), findsOneWidget);
      expect(find.byKey(const ValueKey('footer-qa')), findsNothing);
      for (final filter in ['all', 'practice', 'completed', 'wrong']) {
        await tapKey(tester, 'quiz-filter-$filter');
        expect(tester.takeException(), isNull);
      }
      await tapKey(tester, 'quiz-filter-all');
      await tapKey(tester, 'open-ai');
      expect(find.byType(AiPage), findsOneWidget);
      expect(find.byKey(const ValueKey('footer-quiz')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(QuizPage), findsOneWidget);
    },
  );

  testWidgets(
    'chapter practice gives per-question feedback then authoritative score and review',
    (tester) async {
      await openQuiz(tester);
      final subject = await openPhilosophy(tester);
      final chapter = (await preview.listChapters(subject.id)).first;
      final quiz = (await preview.listQuizzes()).firstWhere(
        (q) => q.chapterId == chapter.id,
      );
      final questions = await preview.getQuestions(quiz.id);
      await tapKey(tester, 'quiz-tab-chapters');
      await tapKey(tester, 'quiz-chapter-${chapter.id}');
      expect(find.byType(QuizChapterPage), findsOneWidget);
      await tapKey(tester, 'mode-practice');
      await tapKey(tester, 'start-chapter-quiz');
      expect(find.byType(QuizPlayerPage), findsOneWidget);
      for (var index = 0; index < questions.length; index++) {
        await tapKey(tester, 'quiz-choice-0');
        await tapKey(tester, 'quiz-confirm');
        expect(preview.practiceChecks, index + 1);
        expect(
          find.textContaining(preview.lastFeedback!.explanation),
          findsWidgets,
        );
        await tapKey(
          tester,
          index == questions.length - 1 ? 'quiz-submit' : 'quiz-next',
        );
      }
      expect(find.byType(QuizResultPage), findsOneWidget);
      expect(preview.submissions, 1);
      expect(preview.lastAllowUnanswered, isFalse);
      expect(preview.lastAnswers!.length, questions.length);
      final attempt = (await preview.listAttempts()).first;
      expect(
        find.text('${attempt.correctCount}/${attempt.totalQuestions}'),
        findsOneWidget,
      );
      await tapKey(tester, 'result-review');
      expect(
        find.textContaining(attempt.review.first.explanation),
        findsWidgets,
      );
      await tapKey(tester, 'result-retry');
      expect(find.byType(QuizPlayerPage), findsOneWidget);
      expect(find.text('Câu hỏi 1/${questions.length}'), findsOneWidget);
      expect(preview.submissions, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a corrected wrong-question retry clears only that latest mistake and creates no full attempt',
    (tester) async {
      await openQuiz(tester);
      final subject = await openPhilosophy(tester);
      final wrong = (await preview.listWrongAnswers(
        subjectId: subject.id,
      )).first;
      final before = (await preview.listAttempts()).length;
      await tapKey(tester, 'quiz-tab-wrong');
      await tapKey(tester, 'quiz-retry-${wrong.question.id}');
      await tapKey(tester, 'quiz-choice-${wrong.correctOption}');
      await tapKey(tester, 'quiz-confirm');
      expect(
        (await preview.listWrongAnswers(
          subjectId: subject.id,
        )).where((a) => a.question.id == wrong.question.id),
        isEmpty,
      );
      await tapKey(tester, 'quiz-next');
      expect(find.text('Đã ôn 1 câu'), findsOneWidget);
      expect((await preview.listAttempts()).length, before);
      expect(preview.submissions, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recent result opens original attempt without silently starting another quiz',
    (tester) async {
      await openQuiz(tester);
      final previous = (await preview.listAttempts()).first;
      final count = (await preview.listAttempts()).length;
      await tapKey(tester, 'quiz-result-${previous.id}');
      expect(find.byType(QuizResultPage), findsOneWidget);
      expect(
        find.text('${previous.correctCount}/${previous.totalQuestions}'),
        findsOneWidget,
      );
      expect((await preview.listAttempts()).length, count);
      expect(preview.submissions, 0);
    },
  );

  testWidgets('expired timed exam submits unanswered as wrong exactly once', (
    tester,
  ) async {
    size(tester);
    final original = (await preview.listQuizzes()).first;
    final quiz = Quiz(
      id: original.id,
      title: original.title,
      topic: original.topic,
      createdAt: original.createdAt,
      durationMinutes: 1,
    );
    var now = DateTime(2026, 11, 3, 10);
    await tester.pumpWidget(
      MaterialApp(
        theme: vstudyTheme(),
        home: QuizPlayerPage(
          useCases: preview.useCases,
          quiz: quiz,
          mode: QuizPlayMode.exam,
          now: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quiz-timer')), findsOneWidget);
    now = now.add(const Duration(minutes: 2));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(QuizResultPage), findsOneWidget);
    expect(preview.submissions, 1);
    expect(preview.lastAllowUnanswered, isTrue);
    expect(preview.lastMode, 'exam');
    expect(preview.lastAnswers, isEmpty);
    final attempt = (await preview.listAttempts()).first;
    expect(attempt.correctCount, 0);
    expect(attempt.review.every((r) => r.selectedOption == -1), isTrue);
    await tester.pump(const Duration(seconds: 10));
    expect(preview.submissions, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'expiry during early-submit confirmation closes the dialog and grades once',
    (tester) async {
      size(tester);
      final original = (await preview.listQuizzes()).first;
      final quiz = Quiz(
        id: original.id,
        title: original.title,
        topic: original.topic,
        createdAt: original.createdAt,
        durationMinutes: 1,
      );
      var now = DateTime(2026, 11, 3, 10);
      await tester.pumpWidget(
        MaterialApp(
          theme: vstudyTheme(),
          home: QuizPlayerPage(
            useCases: preview.useCases,
            quiz: quiz,
            mode: QuizPlayMode.exam,
            now: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final earlySubmit = find.text('Nộp bài ngay');
      await tester.scrollUntilVisible(
        earlySubmit,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(earlySubmit);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(preview.submissions, 0);
      now = now.add(const Duration(minutes: 2));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(QuizResultPage), findsOneWidget);
      expect(preview.submissions, 1);
      expect(preview.lastAllowUnanswered, isTrue);
      expect(preview.lastMode, 'exam');
      expect(tester.takeException(), isNull);
    },
  );
}
