import '../core/app_exception.dart';
import '../domain/ai_workspace.dart';
import 'data_support.dart';

AiArtifact artifactFromJson(Map<String, dynamic> row) {
  final kind = AiArtifactKind.values.byName(row['kind'] as String);
  final content = jsonObject(row['content']);
  List<String> strings(dynamic value) => (value as List).cast<String>();
  List<AiSection> sections(dynamic value) => (value as List).map((item) {
    final section = jsonObject(item);
    return AiSection(
      title: section['title'] as String,
      points: strings(section['points']),
    );
  }).toList();
  return AiArtifact(
    id: row['id'] as String,
    kind: kind,
    title: row['title'] as String,
    createdAt: localTimestamp(row['created_at']),
    documentIds: strings(row['document_ids'] ?? []),
    sourceTitles: strings(row['source_titles'] ?? []),
    quizId: row['quiz_id'] as String?,
    feedback: row['feedback'] as int?,
    summary: kind == AiArtifactKind.summary
        ? AiSummary(
            brief: strings(content['brief']),
            sections: sections(content['sections']),
            keywords: strings(content['keywords']),
            mindMap: sections(content['mind_map']),
          )
        : null,
    exercises: kind == AiArtifactKind.worksheet
        ? (content['questions'] as List).map((item) {
            final q = jsonObject(item);
            final type = ExerciseKind.values.singleWhere(
              (kind) => kind.wire == q['kind'],
            );
            return AiExercise(
              kind: type,
              question: q['question'] as String,
              options: strings(q['options']),
              correctOption: type == ExerciseKind.essay
                  ? null
                  : q['correct_option'] as int,
              explanation: q['explanation'] as String,
              sampleAnswer: q['sample_answer'] as String,
              hint: q['hint'] as String,
            );
          }).toList()
        : const [],
  );
}

class SupabaseAiWorkspaceRepository extends SupabaseAccess
    implements AiWorkspaceRepository {
  const SupabaseAiWorkspaceRepository(super.client);
  @override
  Future<List<AiArtifact>> listArtifacts() => protect(() async {
    final owner = ownerId;
    final rows = await loadPages(
      (from, to) => client
          .from('ai_artifacts')
          .select()
          .eq('owner_id', owner)
          .order('created_at', ascending: false)
          .order('id')
          .range(from, to),
    );
    return rows.map(artifactFromJson).toList(growable: false);
  });
  @override
  Future<AiArtifact> createMaterial(AiMaterialRequest request) =>
      protect(() async {
        ownerId;
        final result = await client.functions.invoke(
          'study-assistant',
          body: {
            'request_id': request.requestId,
            'kind': request.kind.name,
            'title': request.title,
            'topic': request.topic,
            'document_ids': request.documentIds,
            'question_count': request.questionCount,
            'difficulty': request.difficulty,
            'question_kinds': request.exerciseKinds.map((k) => k.wire).toList(),
          },
        );
        return artifactFromJson(jsonObject(result.data));
      });
  Future<void> _changed(dynamic rows) async {
    if ((rows as List).isEmpty) {
      throw const AppException(
        'Không tìm thấy nội dung AI hoặc bạn không có quyền cập nhật.',
      );
    }
  }

  @override
  Future<void> setFeedback(String artifactId, int? feedback) =>
      protect(() async {
        if (feedback != null && feedback != -1 && feedback != 1) {
          throw const AppException('Đánh giá chưa hợp lệ.');
        }
        await _changed(
          await client
              .from('ai_artifacts')
              .update({'feedback': feedback})
              .eq('id', artifactId)
              .eq('owner_id', ownerId)
              .select('id'),
        );
      });
  @override
  Future<void> deleteArtifact(String artifactId) => protect(() async {
    await _changed(
      await client
          .from('ai_artifacts')
          .delete()
          .eq('id', artifactId)
          .eq('owner_id', ownerId)
          .select('id'),
    );
  });
}
