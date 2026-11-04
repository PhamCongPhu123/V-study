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
          .select('id,position,question,options,hint')
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
    String? subjectId,
    String? chapterId,
    int durationMinutes = 30,
    String difficulty = 'medium',
  }) => protect(() async {
    ownerId;
    final response = await client.functions.invoke(
      'generate-quiz',
      body: {
        'title': title.trim(),
        'topic': topic.trim(),
        'question_count': questionCount,
        if (documentId != null) 'document_id': documentId,
        if (subjectId != null) 'subject_id': subjectId,
        if (chapterId != null) 'chapter_id': chapterId,
        'duration_minutes': durationMinutes,
        'difficulty': difficulty,
      },
    );
    return jsonObject(response.data)['quiz_id'] as String;
  });

  @override
  Future<QuizAttempt> submit({
    required String quizId,
    required String attemptId,
    required Map<String, int> answers,
    bool allowUnanswered = false,
    String mode = 'practice',
  }) => protect(() async {
    ownerId;
    final response = await client.rpc(
      'submit_quiz_attempt',
      params: {
        'p_quiz_id': quizId,
        'p_attempt_id': attemptId,
        'p_answers': answers,
        'p_allow_unanswered': allowUnanswered,
        'p_mode': mode,
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

  @override
  Future<List<QuizChapter>> listChapters(String subjectId) => protect(() async {
    ownerId;
    final rows = await loadPages((from, to) async {
      final response = await client
          .rpc('list_quiz_chapters', params: {'p_subject_id': subjectId})
          .range(from, to);
      return (response as List).map(jsonObject).toList(growable: false);
    });
    return rows.map(chapterFromJson).toList(growable: false);
  });

  @override
  Future<QuizChapter> createChapter({
    required String subjectId,
    required String title,
  }) => protect(() async {
    ownerId;
    final response = await client.rpc(
      'create_quiz_chapter',
      params: {'p_subject_id': subjectId, 'p_title': title.trim()},
    );
    return chapterFromJson(jsonObject(response));
  });

  @override
  Future<List<WrongQuizAnswer>> listWrongAnswers({String? subjectId}) =>
      protect(() async {
        ownerId;
        final rows = await loadPages((from, to) async {
          final response = await client
              .rpc(
                'list_wrong_quiz_answers',
                params: {'p_subject_id': subjectId},
              )
              .range(from, to);
          return (response as List).map(jsonObject).toList(growable: false);
        });
        return rows.map(wrongAnswerFromJson).toList(growable: false);
      });

  @override
  Future<AnswerReview> checkPracticeAnswer({
    required String quizId,
    required String questionId,
    required int selectedOption,
  }) => protect(() async {
    ownerId;
    final response = await client.rpc(
      'check_practice_answer',
      params: {
        'p_quiz_id': quizId,
        'p_question_id': questionId,
        'p_selected_option': selectedOption,
      },
    );
    return answerReviewFromJson(jsonObject(response));
  });

  @override
  Future<QuizAttempt> getAttempt(String attemptId) => protect(() async {
    ownerId;
    final response = await client.rpc(
      'get_quiz_attempt',
      params: {'p_attempt_id': attemptId},
    );
    return attemptFromJson(jsonObject(response));
  });
}
