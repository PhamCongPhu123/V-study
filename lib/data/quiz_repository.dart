import '../domain/entities.dart';
import '../domain/repositories.dart';
import 'data_support.dart';

class SupabaseQuizRepository extends SupabaseAccess implements QuizRepository {
  const SupabaseQuizRepository(super.client);

  @override
  Future<List<Quiz>> listQuizzes() => protect(() async {
    final owner = ownerId;
    final rows = await loadPages(
      (from, to) => client
          .from('quizzes')
          .select()
          .eq('owner_id', owner)
          .order('created_at', ascending: false)
          .order('id')
          .range(from, to),
    );
    return rows.map(quizFromJson).toList(growable: false);
  });

  @override
  Future<List<QuizQuestion>> getQuestions(String quizId) => protect(() async {
    final owner = ownerId;
    final rows = await loadPages(
      (from, to) => client
          .from('quiz_questions')
          .select('id,position,question,options')
          .eq('owner_id', owner)
          .eq('quiz_id', quizId)
          .order('position')
          .order('id')
          .range(from, to),
    );
    return rows.map(questionFromJson).toList(growable: false);
  });

  @override
  Future<String> generate({
    required String title,
    required String topic,
    required int questionCount,
    String? documentId,
  }) => protect(() async {
    ownerId;
    final response = await client.functions.invoke(
      'generate-quiz',
      body: {
        'title': title.trim(),
        'topic': topic.trim(),
        'question_count': questionCount,
        if (documentId != null) 'document_id': documentId,
      },
    );
    return jsonObject(response.data)['quiz_id'] as String;
  });

  @override
  Future<QuizAttempt> submit({
    required String quizId,
    required String attemptId,
    required Map<String, int> answers,
  }) => protect(() async {
    ownerId;
    final response = await client.rpc(
      'submit_quiz_attempt',
      params: {
        'p_quiz_id': quizId,
        'p_attempt_id': attemptId,
        'p_answers': answers,
      },
    );
    return attemptFromJson(jsonObject(response));
  });

  @override
  Future<List<QuizAttempt>> listAttempts() => protect(() async {
    final owner = ownerId;
    final rows = await loadPages(
      (from, to) => client
          .from('quiz_attempts')
          .select()
          .eq('owner_id', owner)
          .order('submitted_at', ascending: false)
          .order('id')
          .range(from, to),
    );
    return rows.map(attemptFromJson).toList(growable: false);
  });
}
