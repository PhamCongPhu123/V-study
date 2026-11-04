import 'dart:collection';
import 'package:flutter/material.dart';
import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'design_system.dart';
import 'quiz_ai_launcher.dart';
import 'quiz_catalog_widgets.dart';
import 'quiz_player.dart';
import 'widgets.dart';

const _unassigned = '__unassigned';
bool _belongs(Quiz quiz, Subject subject) => subject.id == _unassigned
    ? quiz.subjectId == null
    : quiz.subjectId == subject.id;

class _QuizCatalog {
  const _QuizCatalog(
    this.subjects,
    this.quizzes,
    this.attempts,
    this.wrong,
    this.chapters,
    this.questionCounts,
  );
  final List<Subject> subjects;
  final List<Quiz> quizzes;
  final List<QuizAttempt> attempts;
  final List<WrongQuizAnswer> wrong;
  final Map<String, List<QuizChapter>> chapters;
  final Map<String, int> questionCounts;
  List<Quiz> quizzesFor(Subject subject) =>
      quizzes.where((q) => _belongs(q, subject)).toList();
  List<QuizAttempt> attemptsFor(Subject subject) {
    final ids = quizzesFor(subject).map((q) => q.id).toSet();
    return attempts.where((a) => ids.contains(a.quizId)).toList();
  }

  List<WrongQuizAnswer> wrongFor(Subject subject) => wrong
      .where(
        (w) => subject.id == _unassigned
            ? w.subjectId == null
            : w.subjectId == subject.id,
      )
      .toList();
  int questionsFor(Subject subject) => quizzesFor(
    subject,
  ).fold<int>(0, (sum, quiz) => sum + (questionCounts[quiz.id] ?? 0));
  double progressFor(Subject subject) {
    final sets = quizzesFor(subject);
    if (sets.isEmpty) {
      return 0;
    }
    final completed = attemptsFor(subject).map((a) => a.quizId).toSet();
    return completed.length / sets.length;
  }
}

Future<_QuizCatalog> _loadCatalog(VstudyUseCases useCases) async {
  final rows = await Future.wait<Object>([
    useCases.study.listSubjects(),
    useCases.quizzes.listQuizzes(),
    useCases.quizzes.listAttempts(),
    useCases.quizzes.listWrongAnswers(),
  ]);
  final allSubjects = rows[0] as List<Subject>;
  final quizzes = rows[1] as List<Quiz>;
  final subjects = allSubjects
      .where((s) => quizzes.any((q) => q.subjectId == s.id))
      .toList();
  if (quizzes.any((q) => q.subjectId == null)) {
    subjects.add(const Subject(id: _unassigned, name: 'Quiz tự do'));
  }
  if (subjects.isEmpty) {
    subjects.addAll(allSubjects);
  }
  final chapters = <String, List<QuizChapter>>{};
  await Future.wait(
    subjects.where((s) => s.id != _unassigned).map((subject) async {
      chapters[subject.id] = await useCases.quizzes.listChapters(subject.id);
    }),
  );
  final questionCounts = <String, int>{};
  await Future.wait(
    quizzes.map((quiz) async {
      questionCounts[quiz.id] = (await useCases.quizzes.getQuestions(
        quiz.id,
      )).length;
    }),
  );
  return _QuizCatalog(
    subjects,
    quizzes,
    rows[2] as List<QuizAttempt>,
    rows[3] as List<WrongQuizAnswer>,
    chapters,
    questionCounts,
  );
}

class QuizPage extends StatefulWidget {
  const QuizPage({super.key, required this.useCases});
  final VstudyUseCases useCases;
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late Future<_QuizCatalog> _future;
  int _filter = 0;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _future = _loadCatalog(widget.useCases);
  }

  void _refresh() => setState(() => _future = _loadCatalog(widget.useCases));
  Future<void> _openCourse(Subject subject) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => QuizCoursePage(
          useCases: widget.useCases,
          subject: subject,
          initialTab: _filter == 3
              ? 2
              : _filter == 2
              ? 0
              : 1,
        ),
      ),
    );
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _openResult(Quiz quiz, QuizAttempt attempt) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final detail = await widget.useCases.quizzes.getAttempt(attempt.id);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => QuizResultPage(
            useCases: widget.useCases,
            quiz: quiz,
            attempt: detail,
          ),
        ),
      );
      if (mounted) {
        _refresh();
      }
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _generate(_QuizCatalog data) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final documents = await widget.useCases.documents.listDocuments();
      if (!mounted) {
        return;
      }
      final quizId = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _GenerateQuizDialog(
          useCases: widget.useCases,
          subjects: data.subjects.where((s) => s.id != _unassigned).toList(),
          documents: documents,
        ),
      );
      if (quizId != null && mounted) {
        final refreshed = await _loadCatalog(widget.useCases);
        if (!mounted) {
          return;
        }
        setState(() => _future = Future.value(refreshed));
        final quiz = refreshed.quizzes.where((q) => q.id == quizId).firstOrNull;
        if (quiz != null) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => QuizPlayerPage(
                useCases: widget.useCases,
                quiz: quiz,
                mode: QuizPlayMode.practice,
              ),
            ),
          );
          if (mounted) {
            _refresh();
          }
        }
      }
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AsyncContent<_QuizCatalog>(
    future: _future,
    onRetry: _refresh,
    builder: (data) {
      final attempted = data.attempts.map((a) => a.quizId).toSet();
      final practiced = data.attempts
          .where((a) => a.mode == 'practice')
          .map((a) => a.quizId)
          .toSet();
      final examined = data.attempts
          .where((a) => a.mode == 'exam')
          .map((a) => a.quizId)
          .toSet();
      final visible = data.subjects.where((subject) {
        final ids = data.quizzesFor(subject).map((q) => q.id).toSet();
        return switch (_filter) {
          1 =>
            ids.isEmpty ||
                ids.any(
                  (id) => !attempted.contains(id) || practiced.contains(id),
                ),
          2 => ids.any(examined.contains),
          3 => data.wrongFor(subject).isNotEmpty,
          _ => true,
        };
      }).toList();
      return RefreshIndicator(
        onRefresh: () async {
          final next = _loadCatalog(widget.useCases);
          setState(() => _future = next);
          await next;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 86),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QUIZZ',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.6,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Luyện tập mỗi ngày, nhớ lâu hơn!',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('quiz-generate'),
                  tooltip: 'Tạo quiz mới',
                  onPressed: _busy ? null : () => _generate(data),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _progressCard(data),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        key: ValueKey(
                          'quiz-filter-${['all', 'practice', 'completed', 'wrong'][i]}',
                        ),
                        label: Text(
                          [
                            'Tất cả',
                            'Luyện tập',
                            'Đã thi',
                            'Câu sai (${data.wrong.length})',
                          ][i],
                          style: TextStyle(
                            fontSize: 11,
                            color: _filter == i
                                ? Colors.white
                                : VstudyColors.navy,
                          ),
                        ),
                        selected: _filter == i,
                        showCheckmark: false,
                        selectedColor: VstudyColors.navy,
                        backgroundColor: Colors.white,
                        side: BorderSide.none,
                        onSelected: (_) => setState(() => _filter = i),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Môn học',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              const QuizEmptyCard(
                'Chưa có môn học trong mục này. Bạn có thể tạo quiz mới hoặc hoàn thành một bài luyện tập.',
              ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visible.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 156,
              ),
              itemBuilder: (context, index) =>
                  _subjectCard(data, visible[index], index),
            ),
            const SizedBox(height: 24),
            const Text(
              'Kết quả gần đây',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (data.attempts.isEmpty)
              const QuizEmptyCard('Nộp bài đầu tiên để xem kết quả tại đây.'),
            ...data.attempts.take(8).map((attempt) {
              final quiz = data.quizzes
                  .where((q) => q.id == attempt.quizId)
                  .firstOrNull;
              if (quiz == null) {
                return const SizedBox.shrink();
              }
              return Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 9),
                child: ListTile(
                  key: ValueKey('quiz-result-${attempt.id}'),
                  dense: true,
                  title: Text(
                    quiz.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${shortDate(attempt.submittedAt)} • ${attempt.mode == 'exam' ? 'Thi thử' : 'Luyện tập'} • ${attempt.totalQuestions} câu',
                    style: const TextStyle(fontSize: 10),
                  ),
                  trailing: QuizPill(
                    '${attempt.correctCount}/${attempt.totalQuestions}',
                    color: attempt.percent >= 50
                        ? VstudyColors.green
                        : VstudyColors.red,
                  ),
                  onTap: _busy ? null : () => _openResult(quiz, attempt),
                ),
              );
            }),
          ],
        ),
      );
    },
  );

  Widget _progressCard(_QuizCatalog data) {
    final ratio = data.quizzes.isEmpty
        ? 0.0
        : data.attempts.map((a) => a.quizId).toSet().length /
              data.quizzes.length;
    final now = DateTime.now();
    final todayCount = data.attempts
        .where(
          (a) =>
              a.submittedAt.year == now.year &&
              a.submittedAt.month == now.month &&
              a.submittedAt.day == now.day,
        )
        .length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VstudyColors.navy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: ratio.clamp(0.0, 1.0).toDouble(),
                        strokeWidth: 14,
                        backgroundColor: Colors.white,
                        color: VstudyColors.gold,
                      ),
                    ),
                    Text(
                      '${(ratio * 100).round()}%',
                      style: const TextStyle(
                        color: VstudyColors.gold,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Icon(
                  Icons.wb_sunny_rounded,
                  size: 74,
                  color: VstudyColors.gold,
                ),
              ),
              IconButton(
                tooltip: 'Tiếp tục luyện tập',
                onPressed: data.subjects.isEmpty
                    ? null
                    : () => _openCourse(data.subjects.first),
                icon: const Icon(
                  Icons.play_arrow_rounded,
                  color: VstudyColors.gold,
                  size: 34,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Bộ đề đã hoàn thành',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
              Text(
                'Hôm nay: $todayCount/5 bài',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: (todayCount / 5).clamp(0.0, 1.0).toDouble(),
              minHeight: 6,
              color: VstudyColors.green,
              backgroundColor: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              5,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 4 ? 0 : 10),
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: todayCount > i
                          ? VstudyColors.gold
                          : const Color(0xFFEAE7DC),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subjectCard(_QuizCatalog data, Subject subject, int index) {
    final accent = [
      VstudyColors.gold,
      const Color(0xFF7965C9),
      VstudyColors.red,
      VstudyColors.green,
    ][index % 4];
    final icons = [
      Icons.psychology_alt_outlined,
      Icons.balance,
      Icons.calculate_outlined,
      Icons.account_tree_outlined,
    ];
    final chapterCount = data.chapters[subject.id]?.length ?? 0;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: ValueKey('quiz-course-${subject.id}'),
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openCourse(subject),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icons[index % 4], color: accent, size: 29),
                  const Spacer(),
                  Icon(Icons.auto_awesome, size: 15, color: accent),
                ],
              ),
              const Spacer(),
              Text(
                subject.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${data.questionsFor(subject)} câu • $chapterCount chương',
                style: const TextStyle(fontSize: 9, color: VstudyColors.muted),
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: data.progressFor(subject),
                  minHeight: 4,
                  color: accent,
                  backgroundColor: accent.withValues(alpha: .15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuizCoursePage extends StatefulWidget {
  const QuizCoursePage({
    super.key,
    required this.useCases,
    required this.subject,
    this.initialTab = 1,
  });
  final VstudyUseCases useCases;
  final Subject subject;
  final int initialTab;
  @override
  State<QuizCoursePage> createState() => _QuizCoursePageState();
}

class _QuizCoursePageState extends State<QuizCoursePage> {
  late Future<_QuizCatalog> _future;
  late int _tab;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _future = _loadCatalog(widget.useCases);
  }

  void _refresh() => setState(() => _future = _loadCatalog(widget.useCases));
  Future<void> _openQuiz(
    Quiz quiz, {
    QuizPlayMode mode = QuizPlayMode.practice,
    List<String>? ids,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => QuizPlayerPage(
          useCases: widget.useCases,
          quiz: quiz,
          mode: mode,
          questionIds: ids,
        ),
      ),
    );
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _openChapter(QuizChapter chapter, List<Quiz> quizzes) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => QuizChapterPage(
          useCases: widget.useCases,
          subject: widget.subject,
          chapter: chapter,
          quizzes: quizzes.where((q) => q.chapterId == chapter.id).toList(),
        ),
      ),
    );
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _result(Quiz quiz, QuizAttempt attempt) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final detailed = await widget.useCases.quizzes.getAttempt(attempt.id);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => QuizResultPage(
            useCases: widget.useCases,
            quiz: quiz,
            attempt: detailed,
          ),
        ),
      );
      if (mounted) {
        _refresh();
      }
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _retryAll(_QuizCatalog data) async {
    final wrong = data.wrongFor(widget.subject);
    if (wrong.isEmpty || _busy) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            QuizWrongReviewPage(useCases: widget.useCases, answers: wrong),
      ),
    );
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _createChapter() async {
    if (_busy || widget.subject.id == _unassigned) {
      return;
    }
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm chương'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên chương'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.useCases.createQuizChapter(
        subjectId: widget.subject.id,
        title: title,
      );
      if (mounted) {
        _refresh();
      }
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      title: Column(
        children: [
          Text(
            widget.subject.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const Text(
            'Quiz',
            style: TextStyle(fontSize: 9, color: VstudyColors.muted),
          ),
        ],
      ),
      centerTitle: true,
    ),
    body: AsyncContent<_QuizCatalog>(
      future: _future,
      onRetry: _refresh,
      builder: (data) {
        final quizzes = data.quizzesFor(widget.subject);
        final attempts = data.attemptsFor(widget.subject);
        final wrong = data.wrongFor(widget.subject);
        final chapters =
            data.chapters[widget.subject.id] ?? const <QuizChapter>[];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: QuizCourseHero(
                subject: widget.subject,
                questionCount: data.questionsFor(widget.subject),
                quizCount: quizzes.length,
                progress: data.progressFor(widget.subject),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: List.generate(
                    3,
                    (i) => Expanded(
                      child: InkWell(
                        key: ValueKey(
                          'quiz-tab-${['sets', 'chapters', 'wrong'][i]}',
                        ),
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => setState(() => _tab = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _tab == i
                                ? VstudyColors.navy
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text(
                            ['Bộ đề', 'Chương', 'Câu sai'][i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _tab == i
                                  ? Colors.white
                                  : VstudyColors.navy,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _tab == 1 ? Colors.transparent : VstudyColors.navy,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 86),
                  children: [
                    if (_tab == 0) ...[
                      if (quizzes.isEmpty)
                        const QuizEmptyCard('Chưa có bộ đề trong môn này.'),
                      ...quizzes.map(
                        (quiz) => _quizSet(
                          quiz,
                          attempts,
                          data.questionCounts[quiz.id] ?? 0,
                        ),
                      ),
                    ],
                    if (_tab == 1) ...[
                      if (widget.subject.id != _unassigned)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: OutlinedButton.icon(
                            key: const ValueKey('quiz-create-chapter'),
                            onPressed: _busy ? null : _createChapter,
                            icon: const Icon(Icons.add, size: 17),
                            label: const Text('Thêm chương'),
                          ),
                        ),
                      if (chapters.isEmpty)
                        const QuizEmptyCard(
                          'Môn này chưa có chương. Thêm chương để sắp xếp bài ôn tập; quiz chưa phân chương nằm trong Bộ đề.',
                        ),
                      ...chapters.map(
                        (chapter) => _chapter(chapter, quizzes, data),
                      ),
                    ],
                    if (_tab == 2) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: VstudyColors.paper,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${wrong.length} câu cần ôn lại',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const QuizPill(
                                  'Cần ôn lại',
                                  color: VstudyColors.red,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Học lại từ câu sai, luyện đúng để ghi nhớ lâu hơn.',
                              style: TextStyle(
                                fontSize: 11,
                                color: VstudyColors.muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              key: const ValueKey('quiz-retry-all'),
                              style: FilledButton.styleFrom(
                                backgroundColor: VstudyColors.gold,
                                foregroundColor: VstudyColors.navy,
                              ),
                              onPressed: wrong.isEmpty || _busy
                                  ? null
                                  : () => _retryAll(data),
                              child: Text(
                                'Luyện lại tất cả câu sai (${wrong.length} câu)',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (wrong.isEmpty)
                        const QuizEmptyCard(
                          'Tuyệt vời! Hiện không còn câu sai cần ôn lại.',
                        ),
                      ...wrong.map((answer) => _wrongCard(answer, data)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _chapter(QuizChapter chapter, List<Quiz> quizzes, _QuizCatalog data) {
    final sets = quizzes.where((q) => q.chapterId == chapter.id).toList();
    final attempts = data.attempts.where(
      (a) => sets.any((q) => q.id == a.quizId),
    );
    final completed = attempts.map((a) => a.quizId).toSet().length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: chapter.position.isEven ? Colors.white : VstudyColors.paleGold,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          key: ValueKey('quiz-chapter-${chapter.id}'),
          onTap: () => _openChapter(chapter, quizzes),
          borderRadius: BorderRadius.circular(17),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: VstudyColors.gold.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu_book_outlined, size: 19),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${chapter.questionCount} câu • $completed/${sets.length} bộ đã làm',
                        style: const TextStyle(
                          fontSize: 10,
                          color: VstudyColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quizSet(Quiz quiz, List<QuizAttempt> attempts, int count) {
    final completed = attempts.where((a) => a.quizId == quiz.id).toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('quiz-set-${quiz.id}'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openQuiz(quiz),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quiz.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 7,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          QuizPill(
                            quizDifficultyLabel(quiz.difficulty),
                            color: quizDifficultyColor(quiz.difficulty),
                          ),
                          Text(
                            '$count câu • ${quiz.durationMinutes} phút',
                            style: const TextStyle(
                              fontSize: 9,
                              color: VstudyColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                if (completed.isEmpty)
                  const Text(
                    'Chưa làm',
                    style: TextStyle(color: VstudyColors.red, fontSize: 10),
                  )
                else
                  Column(
                    children: [
                      Text(
                        (completed.first.percent / 10).toStringAsFixed(1),
                        style: TextStyle(
                          color: completed.first.percent >= 50
                              ? VstudyColors.green
                              : VstudyColors.red,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      InkWell(
                        onTap: _busy
                            ? null
                            : () => _result(quiz, completed.first),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Text('Kết quả', style: TextStyle(fontSize: 9)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _wrongCard(WrongQuizAnswer answer, _QuizCatalog data) {
    final chapter = (data.chapters[widget.subject.id] ?? const <QuizChapter>[])
        .where((c) => c.id == answer.chapterId)
        .firstOrNull;
    final quiz = data.quizzes.where((q) => q.id == answer.quizId).firstOrNull;
    final selected =
        answer.selectedOption >= 0 &&
            answer.selectedOption < answer.question.options.length
        ? answer.question.options[answer.selectedOption]
        : 'Chưa trả lời';
    final correct = answer.question.options[answer.correctOption];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              QuizPill(
                chapter?.title ?? 'Câu ôn tập',
                color: VstudyColors.navy,
              ),
              const QuizPill('Cần ôn lại', color: VstudyColors.red),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            answer.question.question,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _answerBox('BẠN ĐÃ CHỌN', selected, VstudyColors.red),
          const SizedBox(height: 7),
          _answerBox('ĐÁP ÁN CHÍNH XÁC', correct, VstudyColors.green),
          const SizedBox(height: 10),
          Text(
            answer.explanation,
            style: const TextStyle(fontSize: 11, height: 1.45),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 7,
            runSpacing: 4,
            children: [
              TextButton(
                key: ValueKey('quiz-explain-${answer.question.id}'),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F3F8),
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                ),
                onPressed: () => QuizAiLauncher.open(
                  context,
                  prompt:
                      'Giải thích câu hỏi: ${answer.question.question}\nTôi đã chọn: $selected\nĐáp án đúng: $correct\nGiải thích hiện có: ${answer.explanation}',
                ),
                child: const Text(
                  'Giải thích AI',
                  style: TextStyle(fontSize: 10),
                ),
              ),
              TextButton(
                key: ValueKey('quiz-retry-${answer.question.id}'),
                style: TextButton.styleFrom(
                  backgroundColor: VstudyColors.paleGold,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                ),
                onPressed: quiz == null
                    ? null
                    : () => _openQuiz(
                        quiz,
                        mode: QuizPlayMode.reviewWrong,
                        ids: [answer.question.id],
                      ),
                child: const Text('Làm lại', style: TextStyle(fontSize: 10)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _answerBox(String label, String text, Color color) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(text, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );
}

class _GenerateQuizDialog extends StatefulWidget {
  const _GenerateQuizDialog({
    required this.useCases,
    required this.subjects,
    required this.documents,
  });
  final VstudyUseCases useCases;
  final List<Subject> subjects;
  final List<StudyDocument> documents;
  @override
  State<_GenerateQuizDialog> createState() => _GenerateQuizDialogState();
}

class _GenerateQuizDialogState extends State<_GenerateQuizDialog> {
  final _title = TextEditingController();
  final _topic = TextEditingController();
  final _count = TextEditingController(text: '10');
  final _minutes = TextEditingController(text: '30');
  late List<Subject> _subjects;
  List<QuizChapter> _chapters = [];
  String? _subjectId;
  String? _chapterId;
  String? _documentId;
  String _difficulty = 'medium';
  bool _busy = false;
  bool _loadingChapters = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _subjects = List.of(widget.subjects);
  }

  @override
  void dispose() {
    _title.dispose();
    _topic.dispose();
    _count.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _selectSubject(String? id) async {
    setState(() {
      _subjectId = id;
      _chapterId = null;
      _chapters = [];
      _loadingChapters = id != null;
      _error = null;
    });
    if (id == null) {
      return;
    }
    try {
      final chapters = await widget.useCases.quizzes.listChapters(id);
      if (mounted && _subjectId == id) {
        setState(() => _chapters = chapters);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = errorMessage(error));
      }
    } finally {
      if (mounted && _subjectId == id) {
        setState(() => _loadingChapters = false);
      }
    }
  }

  Future<void> _addSubject() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm môn học'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên môn học'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final subject = await widget.useCases.createSubject(name);
      if (!mounted) {
        return;
      }
      setState(() => _subjects.add(subject));
      await _selectSubject(subject.id);
    } catch (error) {
      if (mounted) {
        setState(() => _error = errorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _addChapter() async {
    if (_busy || _loadingChapters || _subjectId == null) {
      return;
    }
    final subjectId = _subjectId!;
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm chương'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên chương'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final chapter = await widget.useCases.createQuizChapter(
        subjectId: subjectId,
        title: title,
      );
      if (mounted && _subjectId == subjectId) {
        setState(() {
          _chapters.add(chapter);
          _chapterId = chapter.id;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = errorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await widget.useCases.generateQuiz(
        title: _title.text,
        topic: _topic.text,
        questionCount: int.tryParse(_count.text) ?? 0,
        documentId: _documentId,
        subjectId: _subjectId,
        chapterId: _chapterId,
        durationMinutes: int.tryParse(_minutes.text) ?? 0,
        difficulty: _difficulty,
      );
      if (mounted) {
        Navigator.pop(context, id);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = errorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Tạo quiz'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tạo đề theo môn/chương và chủ đề hoặc tài liệu. Bản mẫu dùng bộ câu hỏi minh họa.',
                style: TextStyle(fontSize: 12, color: VstudyColors.muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Tên bộ đề'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('subject-$_subjectId'),
                      initialValue: _subjectId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Môn học'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Chưa phân môn'),
                        ),
                        ..._subjects.map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(
                              s.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: _busy ? null : _selectSubject,
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : _addSubject,
                    tooltip: 'Thêm môn học',
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('chapter-$_subjectId-$_chapterId'),
                initialValue: _chapterId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Chương'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Chưa phân chương'),
                  ),
                  ..._chapters.map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.title, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: _busy || _loadingChapters
                    ? null
                    : (value) => setState(() => _chapterId = value),
              ),
              if (_subjectId != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _busy || _loadingChapters ? null : _addChapter,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Thêm chương'),
                  ),
                ),
              if (_loadingChapters) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              TextField(
                controller: _topic,
                enabled: !_busy,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Chủ đề / yêu cầu ôn tập',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _documentId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Tài liệu (tùy chọn)',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Không dùng tài liệu'),
                  ),
                  ...widget.documents.map(
                    (d) => DropdownMenuItem(
                      value: d.id,
                      child: Text(d.title, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (id) => setState(() => _documentId = id),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _count,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Số câu (1–30)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _minutes,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Thời gian (phút)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _difficulty,
                decoration: const InputDecoration(labelText: 'Độ khó'),
                items: ['easy', 'medium', 'hard']
                    .map(
                      (d) => DropdownMenuItem(
                        value: d,
                        child: Text(quizDifficultyLabel(d)),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) =>
                          setState(() => _difficulty = value ?? 'medium'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _busy || _loadingChapters ? null : _generate,
          child: Text(_busy ? 'Đang tạo…' : 'Tạo quiz'),
        ),
      ],
    ),
  );
}
