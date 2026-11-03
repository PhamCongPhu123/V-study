# Quiz redesign contract

Target branch android-working; reference is user's six screenshot frames. Footer indices: calendar0, quiz1, home2, statistics3, documents4. AI is a shell floating gold sparkle button, available across root/child pages. Shell hosts a separate sixth navigator for AI overlay destination (not a footer item), so footer still works. Root owns shell/footer/home link remapping and quiz play/detail screens.

## Domain additions (data agent owns)

- Quiz existing fields preserved, add subjectId?, chapterId?, durationMinutes=30, difficulty='medium'.
- QuizChapter {id,subjectId,title,position,questionCount} (questionCount optional default0).
- WrongQuizAnswer {quizId,quizTitle,subjectId?,chapterId?,question:QuizQuestion,selectedOption:int (-1 unanswered),correctOption:int,explanation:String,answeredAt:DateTime}.
- AnswerReview unchanged; selectedOption=-1 means unanswered in completed timed exam.
- QuizRepository additional methods: listChapters(String subjectId), listWrongAnswers({String? subjectId}), checkPracticeAnswer({required String quizId,required String questionId,required int selectedOption}) -> Future<AnswerReview>, getAttempt(String attemptId) -> Future<QuizAttempt>.
- QuizRepository.generate existing required title/topic/questionCount/documentId? plus optional subjectId?,chapterId?,durationMinutes=30,difficulty='medium'.
- QuizAttempt includes mode='practice' by default (legacy compatible). QuizRepository.submit existing params plus allowUnanswered=false and mode='practice'; supported modes practice/exam. Retry rejects a changed mode.
- VstudyUseCases.generateQuiz matches optional additions with range/time/difficulty checks; submitQuiz matches allowUnanswered false and mode; new checkPracticeAnswer(...) validates option0..3 and delegates. createChapter/createQuizChapter creates owned chapter via create_quiz_chapter RPC.
- Subject remains course entity (id/name/color). UI loads useCases.study.listSubjects(), quizzes.listQuizzes(), listAttempts(), then listChapters per subject. Preview seeded courses Philosophy/Law/Math/ProjectManagement, chapters and quizzes, mistakes+sample histories. Preview must use correct keys per sample question (rotate options to avoid all A) and derive wrong bank from latest completed attempts/practice answer. Non-quiz preview data preserved.

## Database / edge (SQL agent owns)

Add NEW migration after existing 202611030001_vstudy.sql. quiz_chapters(id,owner_id,subject_id,title,position), composite ownership FKs. quizzes add subject_id,chapter_id,duration_minutes,difficulty with backward compatible defaults.

Protected RPC get_quiz_attempt(p_attempt_id uuid) returns same attempt JSON/review only for auth.uid owner. list_wrong_quiz_answers(p_subject_id uuid default null) returns JSON rows {quiz_id,quiz_title,subject_id,chapter_id,question:{id,position,question,options},selected_option,correct_option,explanation,answered_at}; latest answer per question from submitted attempts + practice history. Keys can be returned only for previously answered question. Correct latest answer clears wrong bank, unanswered=-1 counts wrong. list_quiz_chapters(p_subject_id uuid) returns rows id,subject_id,title,position,question_count.

check_practice_answer(p_quiz_id,p_question_id,p_selected_option) authenticates ownership and option, stores answer in protected quiz_practice_answers and returns {question_id,selected_option,correct_option,explanation}. It is deliberately educational practice feedback; client never gets bulk private answer keys.

Extend submit_quiz_attempt with OPTIONAL p_allow_unanswered boolean default false; avoid ambiguous overloads by drop old function signature/recreate, with existing explicit grants restored. Default keeps existing complete-submission behavior. When true, accept only keys for own quiz and options0..3, count missing as incorrect, store canonical answers including -1 for unanswered, return review selected_option=-1. Retry same attempt id and canonical answers idempotent, reject different owner/quiz/payload. Preserve server-only grading/keys and all original security tests.

Extend create_generated_quiz with OPTIONAL p_subject_id,p_chapter_id,p_duration_minutes=30,p_difficulty='medium' after existing five params; remove obsolete overload, preserve service-only execution. Extend generate-quiz handler validation, pass metadata to atomic RPC. Chapter must match subject and both owned. Existing tests without optional fields still work.

## UI ownership

Quiz overview/course agent owns quiz_page.dart + quiz_catalog_widgets.dart: screenshot dashboard navy progress card, five daily goal chips, filters all/practice/completed/wrong, course grid + recent results; course screen shared header/navy course card and tabs Bộ đề/Chương/Câu sai, real counts/scores, actionable wrong cards, retry all/card, Ask AI button. Keep generate dialog accessible.

Root owns quiz_player.dart: public QuizChapterPage(useCases,subject,chapter,quizzes), QuizPlayerPage(useCases,quiz,mode,questionIds?), QuizResultPage(useCases,quiz,attempt). enum QuizPlayMode {practice,exam,reviewWrong}. Player one question at a time, progressbar, 4 A-D options, timed exam countdown and auto-submit allowing unanswered, practice confirms and shows explanation via practice RPC, wrong retry uses practice checks and no forged full quiz attempt if subset. Full practice/exam submit authoritative full quiz. Retake creates new attempt UUID. Retry freezes answers and same attemptId. Chapter detail offers metrics and practice/exam selection. Course UI invokes these screens (no backend queries inline SQL). All pushed routes use nearest Navigator so footer persists.

Ask-AI callback uses shared InheritedWidget QuizAiLauncher.open(context,{String? prompt}); root implements in quiz_ai_launcher.dart and shell. UI can ask about wrong question with explicit question+selected+correct+explanation context. No direct imports from private shell state.

## Validation

SQL disposable database via tools/test-database.mjs runs all migrations then security.sql; SQL agent adds new quiz_security.sql and updates test runner to execute it. Edge Deno tests run actual typed handlers with mock fetch. Flutter SDK unavailable currently; add meaningful widget/domain tests but mark unrun. Root formats/parses Dart. No keys/real deployment. Push only android-working.
