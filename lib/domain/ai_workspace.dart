import 'dart:convert';

enum AiArtifactKind { summary, worksheet, quiz }

enum ExerciseKind { multipleChoice, trueFalse, essay }

extension ExerciseKindDescription on ExerciseKind {
  String get wire => switch (this) {
    ExerciseKind.multipleChoice => 'multiple_choice',
    ExerciseKind.trueFalse => 'true_false',
    ExerciseKind.essay => 'essay',
  };
  String get label => switch (this) {
    ExerciseKind.multipleChoice => 'Trắc nghiệm',
    ExerciseKind.trueFalse => 'Đúng / Sai',
    ExerciseKind.essay => 'Tự luận',
  };
}

class AiSection {
  const AiSection({required this.title, required this.points});
  final String title;
  final List<String> points;
}

class AiSummary {
  const AiSummary({
    required this.brief,
    required this.sections,
    required this.keywords,
    required this.mindMap,
  });
  final List<String> brief;
  final List<AiSection> sections;
  final List<String> keywords;
  final List<AiSection> mindMap;
  String get text => [
    brief.map((p) => '• $p').join('\n'),
    ...sections.map(
      (s) => '${s.title}\n${s.points.map((p) => '• $p').join('\n')}',
    ),
    'Từ khóa: ${keywords.join(', ')}',
    'Sơ đồ\n${mindMap.map((s) => '${s.title}\n${s.points.map((p) => '  • $p').join('\n')}').join('\n')}',
  ].join('\n\n');
}

class AiExercise {
  const AiExercise({
    required this.kind,
    required this.question,
    this.options = const [],
    this.correctOption,
    required this.explanation,
    this.sampleAnswer = '',
    required this.hint,
  });
  final ExerciseKind kind;
  final String question;
  final List<String> options;
  final int? correctOption;
  final String explanation;
  final String sampleAnswer;
  final String hint;
}

class AiArtifact {
  const AiArtifact({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.documentIds = const [],
    this.sourceTitles = const [],
    this.summary,
    this.exercises = const [],
    this.quizId,
    this.feedback,
  });
  final String id;
  final AiArtifactKind kind;
  final String title;
  final DateTime createdAt;
  final List<String> documentIds;
  final List<String> sourceTitles;
  final AiSummary? summary;
  final List<AiExercise> exercises;
  final String? quizId;
  final int? feedback;
  AiArtifact withFeedback(int? value) => AiArtifact(
    id: id,
    kind: kind,
    title: title,
    createdAt: createdAt,
    documentIds: documentIds,
    sourceTitles: sourceTitles,
    summary: summary,
    exercises: exercises,
    quizId: quizId,
    feedback: value,
  );
}

class AiMaterialRequest {
  const AiMaterialRequest({
    required this.requestId,
    required this.kind,
    required this.title,
    this.topic = '',
    this.documentIds = const [],
    this.questionCount = 20,
    this.difficulty = 'medium',
    this.exerciseKinds = const [ExerciseKind.multipleChoice],
  });
  final String requestId;
  final AiArtifactKind kind;
  final String title;
  final String topic;
  final List<String> documentIds;
  final int questionCount;
  final String difficulty;
  final List<ExerciseKind> exerciseKinds;
  String get signature => jsonEncode([
    kind.name,
    title,
    topic,
    documentIds,
    questionCount,
    difficulty,
    exerciseKinds.map((k) => k.wire).toList(),
  ]);
}

abstract interface class AiWorkspaceRepository {
  Future<List<AiArtifact>> listArtifacts();
  Future<AiArtifact> createMaterial(AiMaterialRequest request);
  Future<void> setFeedback(String artifactId, int? feedback);
  Future<void> deleteArtifact(String artifactId);
}
