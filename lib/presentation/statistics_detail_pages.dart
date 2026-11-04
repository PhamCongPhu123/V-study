import 'package:flutter/material.dart';

import '../core/app_exception.dart';
import '../domain/analytics.dart';
import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'design_system.dart';
import 'quiz_page.dart';
import 'quiz_player.dart';
import 'statistics_widgets.dart';
import 'widgets.dart';

Future<AnalyticsSnapshot> _loadStatistics(VstudyUseCases useCases) async {
  final repository = useCases.analytics;
  if (repository == null) {
    throw const AppException('Thống kê chưa được cấu hình.');
  }
  return repository.loadSnapshot(now: DateTime.now());
}

DateTime _day(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime _addDays(DateTime value, int days) =>
    DateTime(value.year, value.month, value.day + days);

String _weekday(DateTime date) =>
    date.weekday == 7 ? 'CN' : 'T${date.weekday + 1}';

String _weekLabel(AnalyticsReport report) =>
    '${statsDateLabel(report.window.from)} – ${statsDateLabel(_addDays(report.window.to, -1))}';

class _StatisticsDetail extends StatelessWidget {
  const _StatisticsDetail({
    required this.title,
    required this.future,
    required this.onRetry,
    required this.builder,
  });
  final String title;
  final Future<AnalyticsSnapshot> future;
  final VoidCallback onRetry;
  final Widget Function(BuildContext, AnalyticsSnapshot) builder;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      title: Text(title, style: const TextStyle(fontSize: 18)),
    ),
    body: AsyncContent<AnalyticsSnapshot>(
      future: future,
      onRetry: onRetry,
      builder: (snapshot) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: builder(context, snapshot),
        ),
      ),
    ),
  );
}

class QuizStatisticsPage extends StatefulWidget {
  const QuizStatisticsPage({super.key, required this.useCases});
  final VstudyUseCases useCases;

  @override
  State<QuizStatisticsPage> createState() => _QuizStatisticsPageState();
}

class _QuizStatisticsPageState extends State<QuizStatisticsPage> {
  late Future<AnalyticsSnapshot> _future;
  bool _openingPractice = false;

  @override
  void initState() {
    super.initState();
    _future = _loadStatistics(widget.useCases);
  }

  void _reload() => setState(() => _future = _loadStatistics(widget.useCases));

  Future<void> _practice() async {
    if (_openingPractice) {
      return;
    }
    setState(() => _openingPractice = true);
    try {
      final answers = await widget.useCases.quizzes.listWrongAnswers();
      if (!mounted) {
        return;
      }
      if (answers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn chưa có câu sai cần luyện lại.')),
        );
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              QuizWrongReviewPage(useCases: widget.useCases, answers: answers),
        ),
      );
      if (mounted) {
        _reload();
      }
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _openingPractice = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => _StatisticsDetail(
    title: 'Thống kê quiz',
    future: _future,
    onRetry: _reload,
    builder: (context, snapshot) {
      final today = _day(snapshot.now);
      final from = _addDays(today, -6);
      final to = _addDays(today, 1);
      List<QuizAttempt> attemptsIn(DateTime start, DateTime end) => snapshot
          .quizAttempts
          .where(
            (attempt) =>
                attempt.totalQuestions > 0 &&
                !attempt.submittedAt.isBefore(start) &&
                attempt.submittedAt.isBefore(end) &&
                !attempt.submittedAt.isAfter(snapshot.now),
          )
          .toList();
      double? average(List<QuizAttempt> attempts) => attempts.isEmpty
          ? null
          : attempts.fold<double>(0, (sum, item) => sum + item.percent) /
                attempts.length;
      final attempts = attemptsIn(from, to);
      final previous = attemptsIn(_addDays(from, -7), from);
      final score = average(attempts);
      final priorScore = average(previous);
      final difference = score == null || priorScore == null
          ? null
          : score - priorScore;
      final days = List.generate(7, (index) => _addDays(from, index));
      final scores = days
          .map((date) => average(attemptsIn(date, _addDays(date, 1))))
          .toList();
      final correct = attempts.fold<int>(
        0,
        (sum, item) => sum + item.correctCount,
      );
      final wrong = attempts.fold<int>(
        0,
        (sum, item) => sum + (item.totalQuestions - item.correctCount),
      );
      final chapters = [...snapshot.chapterMastery]
        ..sort((a, b) => a.percent.compareTo(b.percent));
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        children: [
          Text(
            '7 ngày gần đây · ${statsDateLabel(from)} – ${statsDateLabel(today)}',
            style: const TextStyle(color: VstudyColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          StatsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      score == null ? '—' : '${score.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    _TrendBadge(
                      label: difference == null
                          ? 'Chưa có kỳ so sánh'
                          : '${difference >= 0 ? 'Tăng' : 'Giảm'} ${difference.abs().toStringAsFixed(1)} điểm',
                      positive: difference == null || difference >= 0,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  attempts.isEmpty
                      ? 'Chưa có bài quiz đã nộp'
                      : 'Điểm trung bình · ${attempts.length} lượt làm',
                  style: const TextStyle(
                    fontSize: 11,
                    color: VstudyColors.muted,
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  label: List.generate(
                    days.length,
                    (index) =>
                        '${statsDateLabel(days[index])}: ${scores[index] == null ? 'chưa làm quiz' : '${scores[index]!.toStringAsFixed(0)} phần trăm'}',
                  ).join(', '),
                  child: ExcludeSemantics(
                    child: Column(
                      children: [
                        Row(
                          children: scores
                              .map(
                                (value) => Expanded(
                                  child: Text(
                                    value == null
                                        ? '—'
                                        : '${value.toStringAsFixed(0)}%',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: VstudyColors.muted,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 6),
                        StatsBarChart(
                          values: scores.map((value) => value ?? 0.0).toList(),
                          labels: days
                              .map((date) => '${date.day}/${date.month}')
                              .toList(),
                          highlightIndex: 6,
                        ),
                      ],
                    ),
                  ),
                ),
                const Text(
                  '—: chưa làm quiz. So sánh với 7 ngày trước.',
                  style: TextStyle(fontSize: 10, color: VstudyColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Chủ đề cần ôn thêm',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          const Text(
            'Mức nắm vững từ đáp án gần nhất · toàn bộ thời gian',
            style: TextStyle(fontSize: 10, color: VstudyColors.muted),
          ),
          const SizedBox(height: 10),
          StatsCard(
            child: _ChapterProgress(
              chapters: chapters,
              subjects: snapshot.subjects,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CountMetric(
                  label: 'Câu đúng',
                  count: correct,
                  color: VstudyColors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CountMetric(
                  label: 'Câu sai',
                  count: wrong,
                  color: VstudyColors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Tổng câu trả lời trong các bài quiz đã nộp ở 7 ngày này.',
            style: TextStyle(fontSize: 10, color: VstudyColors.muted),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('stats-practice-wrong'),
              onPressed: _openingPractice ? null : _practice,
              child: Text(
                _openingPractice ? 'Đang tải câu sai…' : 'Luyện câu sai',
              ),
            ),
          ),
        ],
      );
    },
  );
}

class SubjectStatisticsPage extends StatefulWidget {
  const SubjectStatisticsPage({super.key, required this.useCases});
  final VstudyUseCases useCases;

  @override
  State<SubjectStatisticsPage> createState() => _SubjectStatisticsPageState();
}

class _SubjectStatisticsPageState extends State<SubjectStatisticsPage> {
  late Future<AnalyticsSnapshot> _future;
  String? _subjectId;

  @override
  void initState() {
    super.initState();
    _future = _loadStatistics(widget.useCases);
  }

  void _reload() => setState(() => _future = _loadStatistics(widget.useCases));

  Future<void> _openCourse(Subject subject) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            QuizCoursePage(useCases: widget.useCases, subject: subject),
      ),
    );
    if (mounted) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) => _StatisticsDetail(
    title: 'Theo môn học',
    future: _future,
    onRetry: _reload,
    builder: (context, snapshot) {
      if (snapshot.subjects.isEmpty) {
        return const EmptyView(
          'Chưa có môn học. Thêm môn học để theo dõi tiến độ.',
        );
      }
      final subject = snapshot.subjects.firstWhere(
        (item) => item.id == _subjectId,
        orElse: () => snapshot.subjects.first,
      );
      final report = buildAnalyticsReport(
        snapshot,
        AnalyticsPeriod.week,
        subjectId: subject.id,
      );
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        children: [
          Text(
            'Tuần này · ${_weekLabel(report)}',
            style: const TextStyle(fontSize: 12, color: VstudyColors.muted),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: snapshot.subjects
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: ValueKey('stats-subject-${item.id}'),
                        selected: item.id == subject.id,
                        showCheckmark: false,
                        selectedColor: VstudyColors.navy,
                        backgroundColor: Colors.white,
                        side: BorderSide.none,
                        label: Text(
                          item.name,
                          style: TextStyle(
                            color: item.id == subject.id
                                ? Colors.white
                                : VstudyColors.navy,
                            fontSize: 12,
                          ),
                        ),
                        onSelected: (_) => setState(() => _subjectId = item.id),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          StatsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thời gian học đã ghi nhận',
                  style: TextStyle(fontSize: 11, color: VstudyColors.muted),
                ),
                const SizedBox(height: 5),
                Text(
                  formatStudyMinutes(report.study.totalMinutes),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _SmallMetric(
                        label: 'Điểm quiz',
                        value: report.quizAttempts.isEmpty
                            ? '—'
                            : '${report.study.averageQuizPercent.toStringAsFixed(0)}%',
                        hint: '${report.quizAttempts.length} lượt làm',
                      ),
                    ),
                    Expanded(
                      child: _SmallMetric(
                        label: 'Flashcard',
                        value: '${report.flashcardReviewed}',
                        hint: 'lượt ôn thẻ',
                      ),
                    ),
                    Expanded(
                      child: _SmallMetric(
                        label: 'Việc học',
                        value: '${report.tasksCompleted}/${report.tasksTotal}',
                        hint: 'đã hoàn thành',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Tiến độ từng chương',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          const Text(
            'Đáp án gần nhất trên tổng câu hỏi · toàn bộ thời gian',
            style: TextStyle(fontSize: 10, color: VstudyColors.muted),
          ),
          const SizedBox(height: 12),
          StatsCard(child: _ChapterProgress(chapters: report.chapterMastery)),
          const SizedBox(height: 12),
          const Text(
            'Mỗi lần ôn một thẻ được tính một lượt. Việc học lấy từ các mục trong lịch của môn này.',
            style: TextStyle(
              fontSize: 10,
              height: 1.5,
              color: VstudyColors.muted,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('stats-subject-course'),
              onPressed: () => _openCourse(subject),
              child: const Text('Xem lộ trình ôn thi'),
            ),
          ),
        ],
      );
    },
  );
}

class GoalsStatisticsPage extends StatefulWidget {
  const GoalsStatisticsPage({super.key, required this.useCases});
  final VstudyUseCases useCases;

  @override
  State<GoalsStatisticsPage> createState() => _GoalsStatisticsPageState();
}

class _GoalsStatisticsPageState extends State<GoalsStatisticsPage> {
  late Future<AnalyticsSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadStatistics(widget.useCases);
  }

  void _reload() => setState(() => _future = _loadStatistics(widget.useCases));

  Future<void> _editGoals(LearningGoals goals) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GoalsDialog(useCases: widget.useCases, goals: goals),
    );
    if (saved == true && mounted) {
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật mục tiêu học tập.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => _StatisticsDetail(
    title: 'Mục tiêu và chuỗi học',
    future: _future,
    onRetry: _reload,
    builder: (context, snapshot) {
      final report = buildAnalyticsReport(snapshot, AnalyticsPeriod.week);
      final goals = snapshot.goals;
      final ratio = goals.weeklyMinutes <= 0
          ? 0.0
          : report.study.totalMinutes / goals.weeklyMinutes;
      final days = List.generate(
        7,
        (index) => _addDays(report.window.from, index),
      );
      final studyByDay = {
        for (final value in report.study.dailyMinutes)
          _day(value.date): value.minutes,
      };
      final cardsByDay = {
        for (final value in report.dailyFlashcards)
          _day(value.date): value.count,
      };
      final dailyGoal = snapshot.profile.dailyGoalMinutes;
      final studyDays = days
          .where((day) => dailyGoal > 0 && (studyByDay[day] ?? 0) >= dailyGoal)
          .length;
      final flashcardDays = days
          .where((day) => (cardsByDay[day] ?? 0) >= goals.flashcardsPerDay)
          .length;
      final today = _day(snapshot.now);
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        children: [
          Text(
            'Tuần này · ${_weekLabel(report)}',
            style: const TextStyle(fontSize: 12, color: VstudyColors.muted),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: VstudyColors.navy,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Semantics(
                  label:
                      'Đã đạt ${(ratio * 100).toStringAsFixed(0)} phần trăm mục tiêu tuần',
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: ratio.clamp(0.0, 1.0).toDouble(),
                            backgroundColor: Colors.white24,
                            color: VstudyColors.gold,
                            strokeWidth: 7,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Text(
                          '${(ratio * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 19,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mục tiêu tuần',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${formatStudyMinutes(report.study.totalMinutes)} / ${formatStudyMinutes(goals.weeklyMinutes)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        ratio >= 1
                            ? 'Bạn đã đạt mục tiêu tuần!'
                            : 'Còn ${formatStudyMinutes((goals.weeklyMinutes - report.study.totalMinutes).clamp(0, goals.weeklyMinutes).toInt())} để đạt mục tiêu.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          StatsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Chuỗi ${report.study.currentStreakDays} ngày liên tiếp',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    _TrendBadge(
                      label: 'Kỷ lục ${report.longestStreak} ngày',
                      positive: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: days.map((day) {
                    final active = (studyByDay[day] ?? 0) > 0;
                    final future = day.isAfter(today);
                    return Expanded(
                      child: Semantics(
                        label:
                            '${statsDateLabel(day)}: ${future
                                ? 'chưa đến ngày'
                                : active
                                ? 'đã học ${studyByDay[day]} phút'
                                : 'chưa học'}',
                        child: Column(
                          children: [
                            AspectRatio(
                              aspectRatio: 1,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: active
                                        ? VstudyColors.navy
                                        : VstudyColors.cream,
                                    border: day == today
                                        ? Border.all(
                                            color: VstudyColors.gold,
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      _weekday(day),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: active
                                            ? Colors.white
                                            : VstudyColors.muted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${day.day}/${day.month}',
                              style: const TextStyle(
                                fontSize: 8,
                                color: VstudyColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Chuỗi tính những ngày có thời gian học đã ghi nhận.',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.4,
                    color: VstudyColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          StatsCard(
            child: _GoalProgress(
              title: 'Học ${formatStudyMinutes(dailyGoal)} mỗi ngày',
              count: studyDays,
              target: goals.studyDaysPerWeek,
              subtitle:
                  'Đạt $studyDays/${goals.studyDaysPerWeek} ngày mục tiêu trong tuần',
              color: VstudyColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          StatsCard(
            child: _GoalProgress(
              title: 'Ôn ${goals.flashcardsPerDay} flashcard mỗi ngày',
              count: flashcardDays,
              target: 7,
              subtitle: 'Đạt $flashcardDays/7 ngày · tính theo lượt ôn thẻ',
              color: VstudyColors.green,
            ),
          ),
          const SizedBox(height: 16),
          StatsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Học kỳ đang theo dõi',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 7),
                Text(
                  '${shortDate(goals.semesterStart)} – ${shortDate(_addDays(goals.semesterEnd, -1))}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: VstudyColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('stats-edit-goals'),
              onPressed: () => _editGoals(goals),
              child: const Text('Đặt mục tiêu mới'),
            ),
          ),
        ],
      );
    },
  );
}

class _GoalsDialog extends StatefulWidget {
  const _GoalsDialog({required this.useCases, required this.goals});
  final VstudyUseCases useCases;
  final LearningGoals goals;

  @override
  State<_GoalsDialog> createState() => _GoalsDialogState();
}

class _GoalsDialogState extends State<_GoalsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minutes;
  late final TextEditingController _days;
  late final TextEditingController _cards;
  late DateTime _semesterStart;
  late DateTime _semesterLastDay;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _minutes = TextEditingController(text: '${widget.goals.weeklyMinutes}');
    _days = TextEditingController(text: '${widget.goals.studyDaysPerWeek}');
    _cards = TextEditingController(text: '${widget.goals.flashcardsPerDay}');
    _semesterStart = widget.goals.semesterStart;
    _semesterLastDay = _addDays(widget.goals.semesterEnd, -1);
  }

  @override
  void dispose() {
    _minutes.dispose();
    _days.dispose();
    _cards.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = start ? _semesterStart : _semesterLastDay;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 50),
      lastDate: DateTime(initial.year + 50, 12, 31),
      helpText: start ? 'Ngày bắt đầu học kỳ' : 'Ngày kết thúc học kỳ',
    );
    if (date != null && mounted) {
      setState(() {
        if (start) {
          _semesterStart = date;
        } else {
          _semesterLastDay = date;
        }
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.useCases.saveLearningGoals(
        LearningGoals(
          weeklyMinutes: int.parse(_minutes.text.trim()),
          studyDaysPerWeek: int.parse(_days.text.trim()),
          flashcardsPerDay: int.parse(_cards.text.trim()),
          semesterStart: _semesterStart,
          semesterEnd: _addDays(_semesterLastDay, 1),
        ),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = errorMessage(error);
        });
      }
    }
  }

  Widget _numberField({
    required String keyName,
    required String label,
    required TextEditingController controller,
    required int min,
    required int max,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: ValueKey(keyName),
      controller: controller,
      enabled: !_saving,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, helperText: '$min–$max'),
      validator: (value) {
        final number = int.tryParse(value?.trim() ?? '');
        return number == null || number < min || number > max
            ? 'Nhập số từ $min đến $max.'
            : null;
      },
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Mục tiêu học tập'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _numberField(
                  keyName: 'stats-goal-weekly-minutes',
                  label: 'Số phút học mỗi tuần',
                  controller: _minutes,
                  min: 60,
                  max: 10080,
                ),
                _numberField(
                  keyName: 'stats-goal-study-days',
                  label: 'Số ngày đạt mục tiêu học / tuần',
                  controller: _days,
                  min: 1,
                  max: 7,
                ),
                _numberField(
                  keyName: 'stats-goal-flashcards',
                  label: 'Lượt ôn flashcard mỗi ngày',
                  controller: _cards,
                  min: 1,
                  max: 1000,
                ),
                _DateGoalField(
                  keyName: 'stats-goal-semester-start',
                  label: 'Bắt đầu học kỳ',
                  value: _semesterStart,
                  onTap: _saving ? null : () => _pickDate(start: true),
                ),
                const SizedBox(height: 14),
                _DateGoalField(
                  keyName: 'stats-goal-semester-end',
                  label: 'Kết thúc học kỳ',
                  value: _semesterLastDay,
                  onTap: _saving ? null : () => _pickDate(start: false),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Học kỳ kéo dài từ 7 đến 366 ngày, gồm cả ngày kết thúc.',
                  style: TextStyle(color: VstudyColors.muted, fontSize: 11),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: VstudyColors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: const ValueKey('stats-save-goals'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Đang lưu…' : 'Lưu mục tiêu'),
        ),
      ],
    ),
  );
}

class _DateGoalField extends StatelessWidget {
  const _DateGoalField({
    required this.keyName,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String keyName;
  final String label;
  final DateTime value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey(keyName),
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_month_outlined),
        enabled: onTap != null,
      ),
      child: Text(shortDate(value)),
    ),
  );
}

class _ChapterProgress extends StatelessWidget {
  const _ChapterProgress({required this.chapters, this.subjects = const []});
  final List<ChapterMastery> chapters;
  final List<Subject> subjects;

  @override
  Widget build(BuildContext context) {
    if (chapters.isEmpty) {
      return const Text(
        'Chưa có câu hỏi theo chương. Hoàn thành quiz để theo dõi mức nắm vững.',
        style: TextStyle(color: VstudyColors.muted, fontSize: 12, height: 1.5),
      );
    }
    return Column(
      children: List.generate(chapters.length, (index) {
        final chapter = chapters[index];
        final color = chapter.percent >= 80
            ? VstudyColors.green
            : chapter.percent >= 50
            ? VstudyColors.gold
            : VstudyColors.red;
        final subjectNames = subjects.where(
          (subject) => subject.id == chapter.subjectId,
        );
        final subject = subjectNames.isEmpty ? null : subjectNames.first.name;
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == chapters.length - 1 ? 0 : 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      chapter.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${chapter.percent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (subject != null) ...[
                const SizedBox(height: 3),
                Text(
                  subject,
                  style: const TextStyle(
                    fontSize: 10,
                    color: VstudyColors.muted,
                  ),
                ),
              ],
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: (chapter.percent / 100).clamp(0.0, 1.0).toDouble(),
                  minHeight: 6,
                  backgroundColor: VstudyColors.cream,
                  color: color,
                  semanticsLabel: chapter.title,
                  semanticsValue:
                      '${chapter.correctQuestions} câu đúng trên ${chapter.totalQuestions} câu hỏi',
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${chapter.answeredQuestions}/${chapter.totalQuestions} câu đã làm · ${chapter.correctQuestions} câu đúng gần nhất',
                style: const TextStyle(fontSize: 9, color: VstudyColors.muted),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _GoalProgress extends StatelessWidget {
  const _GoalProgress({
    required this.title,
    required this.count,
    required this.target,
    required this.subtitle,
    required this.color,
  });
  final String title;
  final int count;
  final int target;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count/$target',
            style: const TextStyle(fontSize: 11, color: VstudyColors.muted),
          ),
        ],
      ),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(
          value: target <= 0 ? 0 : (count / target).clamp(0.0, 1.0).toDouble(),
          minHeight: 6,
          color: color,
          backgroundColor: VstudyColors.cream,
          semanticsLabel: title,
          semanticsValue: '$count trên $target ngày',
        ),
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        style: const TextStyle(fontSize: 10, color: VstudyColors.muted),
      ),
    ],
  );
}

class _SmallMetric extends StatelessWidget {
  const _SmallMetric({
    required this.label,
    required this.value,
    required this.hint,
  });
  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: VstudyColors.muted),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          style: const TextStyle(fontSize: 9, color: VstudyColors.muted),
        ),
      ],
    ),
  );
}

class _CountMetric extends StatelessWidget {
  const _CountMetric({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => StatsCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: VstudyColors.muted),
        ),
        const SizedBox(height: 7),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
      ],
    ),
  );
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.label, required this.positive});
  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: positive ? const Color(0xFFECF6EF) : const Color(0xFFFDEDEE),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        color: positive ? VstudyColors.green : VstudyColors.red,
      ),
    ),
  );
}
