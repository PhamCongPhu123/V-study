import 'package:flutter_test/flutter_test.dart';
import 'package:vstudy/core/app_exception.dart';
import 'package:vstudy/data/preview_repository.dart';
import 'package:vstudy/data/ai_workspace_repository.dart';
import 'package:vstudy/domain/ai_workspace.dart';

void main() {
  test(
    'material request validates sources, counts and question types before writing',
    () async {
      final repo = PreviewRepository();
      for (final request in [
        const AiMaterialRequest(
          requestId: 'a',
          kind: AiArtifactKind.summary,
          title: 'Summary',
        ),
        const AiMaterialRequest(
          requestId: 'a',
          kind: AiArtifactKind.worksheet,
          title: 'Q',
          topic: 'Toán',
          questionCount: 41,
        ),
        const AiMaterialRequest(
          requestId: 'a',
          kind: AiArtifactKind.worksheet,
          title: 'Q',
          topic: 'Toán',
          exerciseKinds: [],
        ),
        const AiMaterialRequest(
          requestId: 'a',
          kind: AiArtifactKind.quiz,
          title: 'Q',
          topic: 'Toán',
          exerciseKinds: [ExerciseKind.essay],
        ),
        const AiMaterialRequest(
          requestId: 'a',
          kind: AiArtifactKind.summary,
          title: 'Q',
          documentIds: ['x', 'x'],
        ),
      ]) {
        expect(
          () => repo.useCases.createAiMaterial(request),
          throwsA(isA<AppException>()),
        );
      }
      expect(await repo.listArtifacts(), isEmpty);
    },
  );
  test(
    'summary has three views and persists feedback without creating a quiz',
    () async {
      final repo = PreviewRepository();
      final count = (await repo.listQuizzes()).length;
      final artifact = await repo.useCases.createAiMaterial(
        const AiMaterialRequest(
          requestId: 'summary',
          kind: AiArtifactKind.summary,
          title: 'Giải tích',
          documentIds: ['demo-calculus-3', 'demo-calculus-4'],
        ),
      );
      expect(artifact.summary!.brief, isNotEmpty);
      expect(artifact.summary!.sections, isNotEmpty);
      expect(artifact.summary!.mindMap, isNotEmpty);
      expect(artifact.sourceTitles, hasLength(2));
      await repo.setFeedback(artifact.id, 1);
      expect((await repo.listArtifacts()).single.feedback, 1);
      await repo.setFeedback(artifact.id, null);
      expect((await repo.listArtifacts()).single.feedback, isNull);
      expect((await repo.listQuizzes()).length, count);
    },
  );
  test(
    '40 question official quiz reuses its request identity and grades a complete attempt',
    () async {
      final repo = PreviewRepository();
      final count = (await repo.listQuizzes()).length;
      const request = AiMaterialRequest(
        requestId: 'quiz',
        kind: AiArtifactKind.quiz,
        title: 'Toán',
        topic: 'Đạo hàm',
        questionCount: 40,
      );
      final first = await repo.useCases.createAiMaterial(request);
      final second = await repo.useCases.createAiMaterial(request);
      expect(first.quizId, second.quizId);
      expect((await repo.listQuizzes()).length, count + 1);
      final questions = await repo.getQuestions(first.quizId!);
      expect(questions, hasLength(40));
      expect(questions.first.hint, isNotEmpty);
      final result = await repo.useCases.submitQuiz(
        quizId: first.quizId!,
        attemptId: 'attempt',
        answers: {for (final q in questions) q.id: 0},
        mode: 'exam',
      );
      expect(result.totalQuestions, 40);
      await expectLater(
        repo.useCases.createAiMaterial(
          const AiMaterialRequest(
            requestId: 'quiz',
            kind: AiArtifactKind.quiz,
            title: 'Changed',
            topic: 'Toán',
          ),
        ),
        throwsA(isA<AppException>()),
      );
    },
  );
  test(
    'mixed worksheet covers all types and never adds a graded quiz',
    () async {
      final repo = PreviewRepository();
      final count = (await repo.listQuizzes()).length;
      final artifact = await repo.useCases.createAiMaterial(
        const AiMaterialRequest(
          requestId: 'mixed',
          kind: AiArtifactKind.worksheet,
          title: 'Ôn tập',
          topic: 'Toán',
          questionCount: 10,
          exerciseKinds: ExerciseKind.values,
        ),
      );
      expect(artifact.exercises, hasLength(10));
      expect(
        artifact.exercises.map((q) => q.kind).toSet(),
        ExerciseKind.values.toSet(),
      );
      for (final q in artifact.exercises) {
        expect(
          q.options.length,
          q.kind == ExerciseKind.essay
              ? 0
              : q.kind == ExerciseKind.trueFalse
              ? 2
              : 4,
        );
        expect(q.hint, isNotEmpty);
        if (q.kind == ExerciseKind.essay) expect(q.sampleAnswer, isNotEmpty);
      }
      expect((await repo.listQuizzes()).length, count);
    },
  );
  test('deleting AI history keeps the official quiz available', () async {
    final repo = PreviewRepository();
    final artifact = await repo.useCases.createAiMaterial(
      const AiMaterialRequest(
        requestId: 'delete',
        kind: AiArtifactKind.quiz,
        title: 'Quiz',
        topic: 'Toán',
        questionCount: 10,
      ),
    );
    await repo.deleteArtifact(artifact.id);
    expect(await repo.listArtifacts(), isEmpty);
    expect(
      (await repo.listQuizzes()).any((q) => q.id == artifact.quizId),
      isTrue,
    );
  });
  test(
    'structured summary mapping preserves source snapshots and feedback',
    () {
      final artifact = artifactFromJson({
        'id': 'id',
        'kind': 'summary',
        'title': 'Summary',
        'created_at': '2026-11-04T08:00:00Z',
        'document_ids': ['doc'],
        'source_titles': ['PDF'],
        'feedback': -1,
        'content': {
          'brief': ['One'],
          'sections': [
            {
              'title': 'Title',
              'points': ['Point'],
            },
          ],
          'keywords': ['Word'],
          'mind_map': [
            {
              'title': 'Branch',
              'points': ['Leaf'],
            },
          ],
        },
      });
      expect(artifact.summary!.mindMap.single.title, 'Branch');
      expect(artifact.sourceTitles.single, 'PDF');
      expect(artifact.feedback, -1);
    },
  );
}
