import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'design_system.dart';
import 'quiz_ai_launcher.dart';
import 'widgets.dart';

enum QuizPlayMode { practice, exam, reviewWrong }

class QuizChapterPage extends StatefulWidget {
  const QuizChapterPage({
    super.key,
    required this.useCases,
    required this.subject,
    required this.chapter,
    required this.quizzes,
  });
  final VstudyUseCases useCases;
  final Subject subject;
  final QuizChapter chapter;
  final List<Quiz> quizzes;
  @override
  State<QuizChapterPage> createState() => _QuizChapterPageState();
}

class _QuizChapterPageState extends State<QuizChapterPage> {
  QuizPlayMode _mode = QuizPlayMode.practice;
  String? _quizId;
  late Future<List<QuizAttempt>> _attempts;
  @override
  void initState() {
    super.initState();
    _attempts = widget.useCases.quizzes.listAttempts();
  }

  List<Quiz> get _sets =>
      widget.quizzes.where((q) => q.chapterId == widget.chapter.id).toList();
  @override
  Widget build(BuildContext context) {
    final sets = _sets;
    final chosen =
        sets.where((q) => q.id == _quizId).firstOrNull ?? sets.firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subject.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const Text(
              'Quiz · Chi tiết chương',
              style: TextStyle(fontSize: 10, color: VstudyColors.muted),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 90),
        children: [
          _CourseBanner(
            title: widget.subject.name,
            subtitle: widget.chapter.title,
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<QuizAttempt>>(
            future: _attempts,
            builder: (context, snapshot) {
              final ids = sets.map((q) => q.id).toSet();
              final attempts = (snapshot.data ?? []).where(
                (a) => ids.contains(a.quizId),
              );
              final best = attempts.fold<double>(
                0,
                (v, a) => math.max(v, a.percent),
              );
              return Row(
                children: [
                  _Metric(
                    icon: Icons.quiz_outlined,
                    value: '${widget.chapter.questionCount} câu hỏi',
                  ),
                  const SizedBox(width: 8),
                  _Metric(
                    icon: Icons.timer_outlined,
                    value: '${chosen?.durationMinutes ?? 30} phút',
                  ),
                  const SizedBox(width: 8),
                  _Metric(
                    icon: Icons.bar_chart,
                    value: '${best.toStringAsFixed(0)}% tốt nhất',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          const Text(
            'Chế độ làm bài',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _modeCard(
            QuizPlayMode.practice,
            'Luyện tập',
            'Hiện đáp án và giải thích sau mỗi câu',
            Icons.eco_outlined,
          ),
          _modeCard(
            QuizPlayMode.exam,
            'Thi thử',
            'Có giới hạn thời gian; xem kết quả khi nộp',
            Icons.timer_outlined,
          ),
          if (sets.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: DropdownButtonFormField<String>(
                initialValue: chosen?.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Chọn bộ đề'),
                items: sets
                    .map(
                      (q) => DropdownMenuItem(
                        value: q.id,
                        child: Text(q.title, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (id) => setState(() => _quizId = id),
              ),
            ),
          const SizedBox(height: 22),
          const Text('Lưu ý', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'Mỗi câu chỉ có một đáp án đúng. Với thi thử, kết quả và lời giải chỉ hiển thị sau khi nộp. Câu chưa trả lời khi hết giờ được tính là sai.',
            style: TextStyle(
              fontSize: 12,
              color: VstudyColors.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          if (chosen == null)
            const Text(
              'Chương này chưa có bộ đề. Hãy tạo quiz và chọn chương này trước.',
            )
          else
            FilledButton(
              key: const ValueKey('start-chapter-quiz'),
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => QuizPlayerPage(
                      useCases: widget.useCases,
                      quiz: chosen,
                      mode: _mode,
                    ),
                  ),
                );
                if (mounted) {
                  setState(
                    () => _attempts = widget.useCases.quizzes.listAttempts(),
                  );
                }
              },
              child: const Text('Bắt đầu làm bài →'),
            ),
        ],
      ),
    );
  }

  Widget _modeCard(
    QuizPlayMode mode,
    String title,
    String subtitle,
    IconData icon,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey('mode-${mode.name}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _mode = mode),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: mode == QuizPlayMode.practice
                    ? VstudyColors.green
                    : VstudyColors.navy,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: VstudyColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                _mode == mode
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: VstudyColors.navy,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class QuizPlayerPage extends StatefulWidget {
  const QuizPlayerPage({
    super.key,
    required this.useCases,
    required this.quiz,
    this.mode = QuizPlayMode.practice,
    this.questionIds,
    this.wrongAnswers,
    this.now,
    this.assistantStyle = false,
  });
  final VstudyUseCases useCases;
  final Quiz quiz;
  final QuizPlayMode mode;
  final List<String>? questionIds;
  final List<WrongQuizAnswer>? wrongAnswers;
  final DateTime Function()? now;
  final bool assistantStyle;
  @override
  State<QuizPlayerPage> createState() => _QuizPlayerPageState();
}

class _QuizPlayerPageState extends State<QuizPlayerPage>
    with WidgetsBindingObserver {
  late Future<List<QuizQuestion>> _future;
  List<QuizQuestion> _questions = [];
  final Map<String, int> _answers = {};
  final Map<String, AnswerReview> _feedback = {};
  final Set<String> _hints = {};
  final Map<String, String> _questionQuizzes = {};
  final String _attemptId = const Uuid().v4();
  Map<String, int>? _frozenAnswers;
  bool? _frozenAllowUnanswered;
  Timer? _timer;
  DateTime? _deadline;
  int _remaining = 0;
  int _index = 0;
  bool _busy = false;
  bool _expiryTriggered = false;
  bool _confirmingSubmit = false;
  bool _reviewFinished = false;
  String? _error;
  DateTime get _now => widget.now?.call() ?? DateTime.now();
  bool get _isExam => widget.mode == QuizPlayMode.exam;
  bool get _isSubset =>
      widget.mode == QuizPlayMode.reviewWrong ||
      widget.questionIds != null ||
      widget.wrongAnswers != null;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load();
  }

  Future<List<QuizQuestion>> _load() async {
    final wrong = widget.wrongAnswers;
    final questions = wrong != null
        ? wrong.map((a) => a.question).toList()
        : await widget.useCases.quizzes.getQuestions(widget.quiz.id);
    final wanted = widget.questionIds?.toSet();
    _questions = questions
        .where((q) => wanted == null || wanted.contains(q.id))
        .toList();
    for (final q in _questions) {
      _questionQuizzes[q.id] = widget.quiz.id;
    }
    if (wrong != null) {
      for (final item in wrong) {
        _questionQuizzes[item.question.id] = item.quizId;
      }
    }
    if (mounted && _isExam && _questions.isNotEmpty && _deadline == null) {
      _remaining = widget.quiz.durationMinutes * 60;
      _deadline = _now.add(Duration(seconds: _remaining));
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
    return _questions;
  }

  void _tick() {
    if (!mounted || _deadline == null || _frozenAnswers != null) {
      return;
    }
    final seconds = math.max(0, _deadline!.difference(_now).inSeconds);
    setState(() => _remaining = seconds);
    if (seconds == 0 && !_expiryTriggered) {
      _expiryTriggered = true;
      if (_confirmingSubmit) {
        // Finish the existing submission path; do not leave its root dialog
        // orphaned over a result route or issue two submissions on expiry.
        Navigator.of(context, rootNavigator: true).pop(true);
      } else {
        _submit(expired: true);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tick();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy || _questions.isEmpty) {
      return;
    }
    final q = _questions[_index];
    final selected = _answers[q.id];
    if (selected == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.useCases.checkPracticeAnswer(
        quizId: _questionQuizzes[q.id]!,
        questionId: q.id,
        selectedOption: selected,
      );
      if (mounted) {
        setState(() => _feedback[q.id] = result);
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

  Future<void> _next() async {
    if (_index + 1 < _questions.length) {
      setState(() => _index++);
    } else if (_isSubset) {
      setState(() => _reviewFinished = true);
    } else {
      await _submit();
    }
  }

  Future<void> _submit({bool expired = false}) async {
    if (_busy || _confirmingSubmit || _questions.isEmpty || _isSubset) {
      return;
    }
    if (_frozenAnswers == null &&
        !_isExam &&
        _answers.length != _questions.length) {
      setState(() => _error = 'Vui lòng trả lời đầy đủ câu hỏi.');
      return;
    }
    if (_frozenAnswers == null &&
        _isExam &&
        !expired &&
        _answers.length < _questions.length) {
      _confirmingSubmit = true;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nộp bài thi?'),
          content: Text(
            'Còn ${_questions.length - _answers.length} câu chưa trả lời. Các câu này sẽ được tính là sai.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Tiếp tục làm'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Nộp bài'),
            ),
          ],
        ),
      );
      _confirmingSubmit = false;
      if (!mounted || confirm != true || _busy) {
        return;
      }
    }
    if (!mounted) {
      return;
    }
    _timer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
      _frozenAnswers ??= Map.unmodifiable(_answers);
      _frozenAllowUnanswered ??= _isExam;
    });
    try {
      final attempt = await widget.useCases.submitQuiz(
        quizId: widget.quiz.id,
        attemptId: _attemptId,
        answers: _frozenAnswers!,
        allowUnanswered: _frozenAllowUnanswered!,
        mode: _isExam ? 'exam' : 'practice',
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          builder: (_) => QuizResultPage(
            useCases: widget.useCases,
            quiz: widget.quiz,
            attempt: attempt,
            retakeMode: widget.mode,
          ),
        ),
      );
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
    child: Scaffold(
      backgroundColor: widget.assistantStyle ? const Color(0xFFE1E7F6) : null,
      appBar: AppBar(
        backgroundColor: widget.assistantStyle ? const Color(0xFFF1DDB7) : null,
        title: Text(
          widget.quiz.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      body: AsyncContent<List<QuizQuestion>>(
        future: _future,
        onRetry: () {
          setState(() => _future = _load());
        },
        builder: (questions) {
          if (questions.isEmpty) {
            return const Center(child: Text('Bộ đề chưa có câu hỏi.'));
          }
          if (_reviewFinished) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.task_alt,
                      size: 60,
                      color: VstudyColors.green,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Đã ôn ${questions.length} câu',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      '${_feedback.values.where((f) => f.selectedOption == f.correctOption).length} câu trả lời đúng. Câu sai còn lại tiếp tục được lưu để ôn.',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Về danh sách câu sai'),
                    ),
                  ],
                ),
              ),
            );
          }
          final q = questions[_index];
          final selected = _answers[q.id];
          final review = _feedback[q.id];
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 90),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Câu hỏi ${_index + 1}/${questions.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    _isExam ? 'Thi thử' : 'Luyện tập',
                    style: const TextStyle(
                      fontSize: 11,
                      color: VstudyColors.muted,
                    ),
                  ),
                  if (_isExam)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        '${(_remaining ~/ 60).toString().padLeft(2, '0')}:${(_remaining % 60).toString().padLeft(2, '0')}',
                        key: const ValueKey('quiz-timer'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _remaining < 60
                              ? VstudyColors.red
                              : VstudyColors.navy,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: (_index + 1) / questions.length,
                color: VstudyColors.navy,
                backgroundColor: VstudyColors.blue,
                minHeight: 4,
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      switch (widget.quiz.difficulty) {
                        'easy' => '• Nhận biết',
                        'hard' => '• Vận dụng',
                        _ => '• Thông hiểu',
                      },
                      style: const TextStyle(
                        fontSize: 10,
                        color: VstudyColors.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      q.question,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < q.options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: review != null
                        ? (i == review.correctOption
                              ? const Color(0xFFE4F3E8)
                              : i == selected
                              ? const Color(0xFFFFE6E5)
                              : Colors.white)
                        : selected == i
                        ? VstudyColors.paleGold
                        : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      key: ValueKey('quiz-choice-$i'),
                      borderRadius: BorderRadius.circular(15),
                      onTap:
                          _busy ||
                              review != null ||
                              _frozenAnswers != null ||
                              (_isExam && _remaining == 0)
                          ? null
                          : () => setState(() => _answers[q.id] = i),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: VstudyColors.paleGold,
                              child: Text(
                                String.fromCharCode(65 + i),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: VstudyColors.navy,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                q.options[i],
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            if (review != null && i == review.correctOption)
                              const Icon(
                                Icons.check_circle,
                                color: VstudyColors.green,
                                size: 18,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (q.hint.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: VstudyColors.paleGold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextButton.icon(
                          key: const ValueKey('quiz-hint'),
                          onPressed: () => setState(() => _hints.add(q.id)),
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('Gợi ý'),
                        ),
                        if (_hints.contains(q.id))
                          Text(
                            q.hint,
                            style: const TextStyle(fontSize: 12, height: 1.5),
                          ),
                      ],
                    ),
                  ),
                ),
              if (review != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F3E8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected == review.correctOption
                            ? 'Chính xác!'
                            : 'Cùng xem lại đáp án nhé.',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        review.explanation,
                        style: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                      TextButton(
                        onPressed: () => QuizAiLauncher.open(
                          context,
                          prompt:
                              'Giải thích câu hỏi: ${q.question}\nĐáp án đúng: ${q.options[review.correctOption]}\nLời giải: ${review.explanation}',
                        ),
                        child: const Text('Giải thích với AI'),
                      ),
                    ],
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: VstudyColors.red),
                  ),
                ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(right: 52),
                child: _frozenAnswers != null
                    ? FilledButton(
                        key: const ValueKey('quiz-submit'),
                        onPressed: _busy ? null : () => _submit(),
                        child: Text(_busy ? 'Đang chấm…' : 'Gửi lại bài'),
                      )
                    : !_isExam && review == null
                    ? FilledButton(
                        key: const ValueKey('quiz-confirm'),
                        onPressed: _busy || selected == null ? null : _confirm,
                        child: Text(
                          _busy ? 'Đang kiểm tra…' : 'Kiểm tra đáp án',
                        ),
                      )
                    : FilledButton(
                        key: ValueKey(
                          _index + 1 == questions.length && !_isSubset
                              ? 'quiz-submit'
                              : 'quiz-next',
                        ),
                        onPressed: _busy ? null : _next,
                        child: Text(
                          _index + 1 == questions.length
                              ? (_isSubset ? 'Hoàn tất ôn tập' : 'Nộp bài')
                              : 'Câu tiếp theo →',
                        ),
                      ),
              ),
              if (_isExam && _frozenAnswers == null)
                Row(
                  children: [
                    TextButton(
                      onPressed: _busy || _index == 0
                          ? null
                          : () => setState(() => _index--),
                      child: const Text('Câu trước'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _busy ? null : () => _submit(),
                      child: const Text('Nộp bài ngay'),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    ),
  );
}

class QuizWrongReviewPage extends StatelessWidget {
  const QuizWrongReviewPage({
    super.key,
    required this.useCases,
    required this.answers,
  });
  final VstudyUseCases useCases;
  final List<WrongQuizAnswer> answers;
  @override
  Widget build(BuildContext context) => QuizPlayerPage(
    useCases: useCases,
    quiz: Quiz(
      id: 'wrong-review',
      title: 'Luyện lại câu sai',
      topic: 'Ôn tập',
      createdAt: DateTime.now(),
    ),
    mode: QuizPlayMode.reviewWrong,
    wrongAnswers: answers,
  );
}

class QuizResultPage extends StatefulWidget {
  const QuizResultPage({
    super.key,
    required this.useCases,
    required this.quiz,
    required this.attempt,
    this.retakeMode,
  });
  final VstudyUseCases useCases;
  final Quiz quiz;
  final QuizAttempt attempt;
  final QuizPlayMode? retakeMode;
  @override
  State<QuizResultPage> createState() => _QuizResultPageState();
}

class _QuizResultPageState extends State<QuizResultPage> {
  late Future<List<QuizQuestion>> _questions;
  bool _showReview = false;
  @override
  void initState() {
    super.initState();
    _questions = widget.useCases.quizzes.getQuestions(widget.quiz.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kết quả quiz')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 90),
      children: [
        _CourseBanner(
          title: widget.quiz.title,
          subtitle: 'Đã nộp ${shortDate(widget.attempt.submittedAt)}',
        ),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                size: 60,
                color: VstudyColors.gold,
              ),
              Text(
                '${widget.attempt.correctCount}/${widget.attempt.totalQuestions}',
                key: const ValueKey('quiz-result-score'),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${widget.attempt.percent.toStringAsFixed(1)}% · Hoàn thành bài quiz',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('result-review'),
          onPressed: () => setState(() => _showReview = !_showReview),
          child: Text(_showReview ? 'Ẩn lời giải' : 'Xem đáp án và lời giải'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          key: const ValueKey('result-retry'),
          onPressed: () => Navigator.of(context).pushReplacement<void, void>(
            MaterialPageRoute(
              builder: (_) => QuizPlayerPage(
                useCases: widget.useCases,
                quiz: widget.quiz,
                mode:
                    widget.retakeMode ??
                    (widget.attempt.mode == 'exam'
                        ? QuizPlayMode.exam
                        : QuizPlayMode.practice),
              ),
            ),
          ),
          child: const Text('Làm lại bộ đề'),
        ),
        if (_showReview)
          FutureBuilder<List<QuizQuestion>>(
            future: _questions,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return FailureView(
                  error: snapshot.error!,
                  onRetry: () => setState(
                    () => _questions = widget.useCases.quizzes.getQuestions(
                      widget.quiz.id,
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const LoadingView();
              }
              final questions = {for (final q in snapshot.data!) q.id: q};
              return Column(
                children: widget.attempt.review.map((r) {
                  final q = questions[r.questionId];
                  if (q == null) {
                    return const SizedBox.shrink();
                  }
                  final correct = r.selectedOption == r.correctOption;
                  return Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            q.question,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Bạn chọn: ${r.selectedOption < 0 ? 'Chưa trả lời' : q.options[r.selectedOption]}',
                            style: TextStyle(
                              color: correct
                                  ? VstudyColors.green
                                  : VstudyColors.red,
                            ),
                          ),
                          Text(
                            'Đáp án: ${q.options[r.correctOption]}',
                            style: const TextStyle(color: VstudyColors.green),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            r.explanation,
                            style: const TextStyle(fontSize: 12, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    ),
  );
}

class _CourseBanner extends StatelessWidget {
  const _CourseBanner({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: VstudyColors.navy,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33202B48),
          blurRadius: 12,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: VstudyColors.gold,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.menu_book_rounded, color: VstudyColors.navy),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFFCFD5E5), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value});
  final IconData icon;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: VstudyColors.blue),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: VstudyColors.navy),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    ),
  );
}
