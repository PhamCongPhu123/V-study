import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vstudy/core/app_exception.dart';
import 'package:vstudy/data/preview_repository.dart';
import 'package:vstudy/domain/entities.dart';
import 'package:vstudy/main.dart' as entrypoint;

void main() {
  test(
    'preview schedule mutations update shared state and preserve tasks',
    () async {
      final now = DateTime(2026, 11, 3, 12);
      final preview = PreviewRepository(now: now);
      final created = await preview.useCases.createEvent(
        EventDraft(
          title: 'Ôn UX',
          kind: EventKind.selfStudy,
          startsAt: now,
          endsAt: now.add(const Duration(hours: 1)),
          repeatWeeks: 2,
          taskTitles: ['Đọc tài liệu'],
        ),
      );
      expect(created.length, 3);
      expect(created.map((e) => e.seriesId).toSet().length, 1);
      await preview.setTaskCompleted(created.first.tasks.single.id, true);
      await preview.updateEvent(
        created.first.id,
        EventDraft(
          title: 'Ôn UI',
          kind: EventKind.selfStudy,
          startsAt: now,
          endsAt: now.add(const Duration(hours: 1)),
        ),
      );
      final selected = (await preview.listEvents(
        now,
        now.add(const Duration(hours: 2)),
      )).singleWhere((e) => e.id == created.first.id);
      expect(selected.title, 'Ôn UI');
      expect(selected.tasks.single.isCompleted, isTrue);
      await preview.deleteEvent(selected.id);
      expect(
        (await preview.listEvents(
          now,
          now.add(const Duration(days: 30)),
        )).where((e) => e.id == selected.id),
        isEmpty,
      );
    },
  );

  test(
    'preview grades complete quiz and retries without duplicate attempts',
    () async {
      final preview = PreviewRepository();
      final quiz = (await preview.listQuizzes()).first;
      final questions = await preview.getQuestions(quiz.id);
      final answers = {for (final q in questions) q.id: 0};
      final before = (await preview.listAttempts()).length;
      final result = await preview.submit(
        quizId: quiz.id,
        attemptId: 'retry',
        answers: answers,
      );
      expect(result.correctCount, questions.length);
      expect(result.review.length, questions.length);
      await preview.submit(
        quizId: quiz.id,
        attemptId: 'retry',
        answers: answers,
      );
      expect((await preview.listAttempts()).length, before + 1);
      await expectLater(
        preview.submit(
          quizId: quiz.id,
          attemptId: 'retry',
          answers: {...answers, questions.first.id: 1},
        ),
        throwsA(isA<AppException>()),
      );
    },
  );

  test(
    'preview chat explicitly identifies sample content and retains context',
    () async {
      final preview = PreviewRepository();
      final turn = await preview.send(
        message: 'Ôn tập như thế nào?',
        mode: AiMode.qa,
      );
      expect(turn.assistantMessage.content, contains('không gọi Gemini'));
      expect((await preview.listMessages(turn.threadId)).length, 2);
      await expectLater(
        preview.send(
          message: 'Đổi chế độ',
          mode: AiMode.summary,
          threadId: turn.threadId,
        ),
        throwsA(isA<AppException>()),
      );
      await preview.deleteThread(turn.threadId);
      expect(await preview.listMessages(turn.threadId), isEmpty);
    },
  );

  testWidgets(
    'default entry opens all five tabs without Supabase configuration or login',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await entrypoint.main();
      await tester.pumpAndSettle();
      expect(find.text('Bản mẫu UX/UI'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      for (final icon in [
        Icons.calendar_month_outlined,
        Icons.quiz_outlined,
        Icons.auto_awesome_outlined,
        Icons.bar_chart_outlined,
        Icons.home_outlined,
      ]) {
        final destination = find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(icon),
        );
        await tester.tap(destination);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Đăng nhập'), findsNothing);
      }
    },
  );
}
