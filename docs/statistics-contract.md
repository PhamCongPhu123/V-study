# Statistics upgrade contract

Branch android-working, screenshot frames: landing menu7 destinations; studytime week/month/semester; goals/streak; quizstats; bysubjectstats. Root keeps footer+goldAI unchanged and removes duplicate shell stats header. No new login requirement, preview remains default. Focus/flashcard/report menu destinations must be usable, not dead buttons; root implements these with honest recorded-data and logging forms, no fabricated real-user metrics.

## Ownership

Domain agent owns lib/domain/analytics.dart (all models+pure calculations), lib/domain/analytics_repository.dart, use_cases.dart optional analytics and validated log/save methods, test/analytics_test.dart. Write model contracts first.
Data agent owns lib/data/analytics_repository.dart and edits PreviewRepository analytics implementation/seeding only; main.dart composition root will wire live analytics. No mutation of existing quiz behavior.
SQL agent owns new0003migration/tests and test runner extra SQL test; security filters all owners; no original migration edits.
UI A owns statistics_page.dart (landing, StudyTimeStatisticsPage) + statistics_widgets.dart charts/cards shared.
UI B owns statistics_detail_pages.dart (QuizStatisticsPage, SubjectStatisticsPage, GoalsStatisticsPage) and uses sharedwidgets optional.
Root owns statistics_extra_pages.dart (FocusStatisticsPage,FlashcardStatisticsPage,WeeklyReportPage), shell/main wiring, README.
Validation agent owns widget tests + verification doc, sends concrete findings.

## Domain exact API

enum AnalyticsPeriod {week,month,semester}
LearningGoals {weeklyMinutes=900,studyDaysPerWeek=5,flashcardsPerDay=20,required semesterStart:DateTime,required semesterEnd:DateTime}. End exclusive. factory LearningGoals.defaults(DateTime now) returns local academic halfyear Aug1..Feb1 / Feb1..Aug1 inclusiveJanpriorAug. Values ranges weekly60..10080,days1..7,flashcards1..1000,semester duration7..366days. Profile.dailyGoalMinutes remains daily studygoal (no duplicate dailygoal field).
FocusSession {id,startedAt,plannedMinutes,focusedMinutes,interruptions=0,subjectId?}. Its percentages focused/planned, not inferred from quiz. Separate from study_sessions; logging does NOT add studytime automatically to avoid doublecounts.
FlashcardSession {id,reviewedAt,reviewedCards,rememberedCards,subjectId?}. Counts are review events, not unique cards/decks. No claim AI text proves flashcardreview.
LearningTask {date,completed,subjectId?} mapped from study_event.checklist actualtasks (label Việc học, not fake exercise marks).
ChapterMastery {id,subjectId,title,position,totalQuestions,answeredQuestions,correctQuestions}; alltime latestanswers through snapshot.now, no rawkeys.
AnalyticsSnapshot {now,profile,goals,subjects:List<Subject>,studySessions:List<StudySession>,quizAttempts:List<QuizAttempt>,quizzes:List<Quiz>,focusSessions:List<FocusSession>,flashcardSessions:List<FlashcardSession>,tasks:List<LearningTask>,chapterMastery:List<ChapterMastery>}.
AnalyticsWindow {from,to,previousFrom,previousTo}; function analyticsWindow(AnalyticsPeriod period,DateTime anchor,LearningGoals goals). Week Mondaycalendar, month truecalendar, semester configured dates. Previousweek previous7days/month previousactualmonth/semester equallylong previouswindow. Windows endexclusive and no futuredata.
ScorePoint {date,percent:double?} null if noattempts.
DailyCount {date,count}.
AnalyticsReport {window,study:StudyStatistics,previousStudyMinutes:int,changePercent:double?,focusPercent:double?,bestDay:DailyMinutes?,activeDays:int,longestStreak:int,quizAttempts:List<QuizAttempt>,quizCorrect:int,quizWrong:int,quizDailyScores:List<ScorePoint>,weeklyMinutes:List<DailyMinutes>,chapterMastery:List<ChapterMastery>,flashcardReviewed:int,flashcardRemembered:int,dailyFlashcards:List<DailyCount>,tasksCompleted:int,tasksTotal:int,focusSessions:List<FocusSession>,flashcardSessions:List<FlashcardSession>}. Getter rememberPercent double? optional helpful. quizaverage via report.study.averageQuizPercent, attemptscount checks empty. changePercent null ifprevious0, show 'Chưa có kỳ so sánh', not fake +100%. Emptyfocus => null/show 'Chưa ghi nhận'. Bestday null if all0. Longeststreak allhistorythroughnow; currentstreak reuse study_metrics.
function buildAnalyticsReport(AnalyticsSnapshot snapshot,AnalyticsPeriod period,{DateTime? anchor,String? subjectId}) pure. Subjectfilter quizzes byQuiz.subjectId; dates localUTCroundtrip. Split midnight studyintervals via existing metrics; flashcard/focusrecords assigned localstartdate. No future logs counted. Data throughnow clipped. Quizcorrect/wrong sumcompletedattemptcounts only. Mastery alltime (displaylabel) selectedsubject. weeklyMinutes buckets beginMonday intersectselectedwindow. dailyFlashcards actualreviewcount to calculate7daygoal completion.

AnalyticsRepository.loadSnapshot({required DateTime now}) -> Future<AnalyticsSnapshot> loads paginated fullhistory throughnow (for streak), goals defaultifno row.
saveGoals(LearningGoals goals) -> Future<void>
logFocusSession({required DateTime startedAt,required int plannedMinutes,required int focusedMinutes,required int interruptions,String? subjectId}) -> Future<void>
logFlashcardSession({required DateTime reviewedAt,required int reviewedCards,required int rememberedCards,String? subjectId}) -> Future<void>
UseCases adds final AnalyticsRepository? analytics defaultnull; saveLearningGoals,logFocusSession,logFlashcardSession validate and delegate (AppException if notconfigured). Focus completedrecord start+planned<=now(+1minute),planned1..1440,focused0..planned,interruptions0..1000. Flashcardreviewed1..10000,remembered0..reviewed, reviewedAt<=now. Never invent credentials/values.

## Database/data API

study_goals: owner_id PK auth.users,weekly_minutes,study_days_per_week,flashcards_per_day,semester_start date,semester_end date,updated_at; samechecks. focus_sessions:id,owner_id,subject_id nullable,started_at timestamptz,planned_minutes,focused_minutes,interruptions. flashcard_sessions:id,owner_id,subject_id nullable,reviewed_at timestamptz,reviewed_cards,remembered_cards. OwnRLS select/insert/update/delete (goals upsert); revokeTRUNCATE/public/anon, composite ownership FKs subject. Backend completedtimevalidation supported trigger/RPC torejectfuturelive (clientchecks independent). Private history no servicekeys in app.

get_chapter_mastery(p_until timestamptz) -> rows {id,subject_id,title,position,total_questions,answered_questions,correct_questions} for ownchapters only; latest completedattempt/practiceanswer perquestion <=until, compare privatekeys insideSQL; no rawanswers. SQL authenticated grant only. Tests ownership+latestcorrect+no leakage+constraints and original92pass.

Dataadapter reads profiles/subjects/sessions/quizzes/attempts paginated plus newtables, event_tasks via study_events select subject_id,starts_at,event_tasks(is_completed) flatten tasks. Timestamps .toLocal, wireUTC. Goal datesYYYY-MM-DD only and clientdefaults ifrowmissing. get_chapter_mastery paginatedRPC. Preview derives mastery from real seededattempt/practicehistory latest, richer 6month sample studylogs/focus/flashcards validcompleteddate for charts but all markedpreviewbyapp mode/docs; no arbitrary fakeavg constants. Newwrites immediately affect snapshot.

## UI contracts

All detail pages constructor ({super.key,required VstudyUseCases useCases}); statistics landing noScaffold/footer header ownedpage. Statistics detailpages use Scaffold appbar; nested Navigator keepsfooter. Landing links7: Thống kê học tập,Thống kê tập trung,Thống kê quiz,Theo môn học,Mục tiêu và chuỗi học,Báo cáo tuần,Thống kê flashcard.

Shared widgets API (UI A owns): StatsCard({required Widget child,EdgeInsetsGeometry? padding}), StatsHeader({required String title,String? subtitle}), StatsPeriodSelector({required AnalyticsPeriod selected,required ValueChanged<AnalyticsPeriod> onChanged}), StatsBarChart({required List<double> values,required List<String> labels,int? highlightIndex}), StatsLineChart({required List<double> values}), StatsMetric({required String label,required String value,String? subtitle}). Widgets must handleempty/zero/missing safely and have accessible values. Colors use VstudyColors. No chart dependencies.

StudyTimeStatisticsPage: weekbarseven days, monthMondayfirstcalendarheatmap actual minutes with selection, semesterweeklyline actual data; totals formattedh/min, previousperiodbadge correctlyderived, bestday,focusratio,streak,weeklygoal. Month daytap shows actualminutes. Date previous/next anchor buttons and goal semesterbounds respected; no futureactivity invented. Keys stats-period-week/month/semester; stats-month-day-YYYY-MM-DD.
QuizStatisticsPage: last7daysavgbar, trend fromprior7days actualattempts, chapterprogress bars alltime, correct/wrong counts; 'Luyện câu sai' opens QuizPage or coursewrongtab via nestednavigator, no deadbutton.
SubjectStatisticsPage: subjectchips fromsnapshot, thisweektotals/quizavg/flashcardreviewevents/taskcounts, chaptermasterybars +knowledge note emptydata. Button opens QuizCoursePage(useCases,subject) for selectedcourse.
GoalsStatisticsPage: weekgoalring, current+longeststreak+seven datedaychips, studydaygoalanddailyflashcardgoalprogress, edit dialog allLearningGoals includingsemesterdatefields; reload actualsnapshot aftersave. Keys stats-edit-goals,stats-save-goals. Goal never inferredquizquality.

No exact Figma avatar/fontassets supplied; use Fluttericons. NewSQL requiredONLYlive; preview works noSQL/auth. FlutterSDK stillunavailable in thishost; tests notpassedunlessactualrun. Push android-working only.
