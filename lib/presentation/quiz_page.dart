import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/app_exception.dart';
import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'widgets.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key, required this.useCases});
  final VstudyUseCases useCases;
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizOverview {
  const _QuizOverview(this.quizzes, this.attempts);
  final List<Quiz> quizzes;
  final List<QuizAttempt> attempts;
}

class _QuizPageState extends State<QuizPage> {
  late Future<_QuizOverview> _future;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_QuizOverview> _load() async {
    final results = await Future.wait<Object>([
      widget.useCases.quizzes.listQuizzes(),
      widget.useCases.quizzes.listAttempts(),
    ]);
    return _QuizOverview(
      results[0] as List<Quiz>,
      results[1] as List<QuizAttempt>,
    );
  }

  void _refresh() => setState(() => _future = _load());
  Future<void> _open(String id) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _TakeQuizPage(useCases: widget.useCases, quizId: id),
      ),
    );
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _generate() async {
    if (_opening) {
      return;
    }
    setState(() => _opening = true);
    try {
      final documents = await widget.useCases.documents.listDocuments();
      if (!mounted) {
        return;
      }
      final id = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _GenerateQuizDialog(
          useCases: widget.useCases,
          documents: documents,
        ),
      );
      if (mounted && id != null) {
        _refresh();
        await _open(id);
      }
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AsyncContent<_QuizOverview>(
    future: _future,
    onRetry: _refresh,
    builder: (data) => PageBody(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _opening ? null : _generate,
                icon: const Icon(Icons.add),
                label: Text(_opening ? 'Đang mở…' : 'Tạo quiz bằng AI'),
              ),
            ),
            IconButton(
              onPressed: _refresh,
              tooltip: 'Tải lại',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SectionTitle('Quiz của bạn'),
        if (data.quizzes.isEmpty)
          const EmptyView(
            'Chưa có quiz. Tạo đề từ chủ đề hoặc tài liệu PDF/TXT đã tải lên.',
          ),
        ...data.quizzes.map(
          (quiz) => Card(
            child: ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: Text(quiz.title),
              subtitle: Text('${quiz.topic}\n${shortDate(quiz.createdAt)}'),
              trailing: const Icon(Icons.play_arrow_outlined),
              onTap: () => _open(quiz.id),
            ),
          ),
        ),
        const SectionTitle('Kết quả gần đây'),
        if (data.attempts.isEmpty)
          const EmptyView(
            'Kết quả xuất hiện sau khi bạn trả lời đủ câu và nộp bài.',
          ),
        ...data.attempts.map((attempt) {
          final matching = data.quizzes.where((q) => q.id == attempt.quizId);
          final title = matching.isEmpty ? 'Quiz' : matching.first.title;
          return Card(
            child: ListTile(
              title: Text(title),
              subtitle: Text(
                '${shortDate(attempt.submittedAt)} ${shortTime(attempt.submittedAt)}',
              ),
              trailing: Text(
                '${attempt.correctCount}/${attempt.totalQuestions}\n${attempt.percent.toStringAsFixed(0)}%',
                textAlign: TextAlign.end,
              ),
              onTap: () => _open(attempt.quizId),
            ),
          );
        }),
      ],
    ),
  );
}

class _GenerateQuizDialog extends StatefulWidget {
  const _GenerateQuizDialog({required this.useCases, required this.documents});
  final VstudyUseCases useCases;
  final List<StudyDocument> documents;
  @override
  State<_GenerateQuizDialog> createState() => _GenerateQuizDialogState();
}

class _GenerateQuizDialogState extends State<_GenerateQuizDialog> {
  final _title = TextEditingController();
  final _topic = TextEditingController();
  final _count = TextEditingController(text: '10');
  String? _documentId;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _topic.dispose();
    _count.dispose();
    super.dispose();
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
              TextField(
                controller: _title,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Tên quiz'),
              ),
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
                    child: Text('Theo chủ đề'),
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
              TextField(
                controller: _count,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Số câu (1–30)'),
              ),
              const SizedBox(height: 12),
              const Text(
                'AI có thể tạo nội dung chưa chính xác. Đối chiếu lời giải với tài liệu học của bạn.',
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!),
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
          onPressed: _busy ? null : _generate,
          child: Text(_busy ? 'Đang tạo…' : 'Tạo quiz'),
        ),
      ],
    ),
  );
}

class _TakeQuizPage extends StatefulWidget {
  const _TakeQuizPage({required this.useCases, required this.quizId});
  final VstudyUseCases useCases;
  final String quizId;
  @override
  State<_TakeQuizPage> createState() => _TakeQuizPageState();
}

class _TakeQuizPageState extends State<_TakeQuizPage> {
  late Future<List<QuizQuestion>> _future;
  final _attemptId = const Uuid().v4();
  final Map<String, int> _answers = {};
  Map<String, int>? _submittedAnswers;
  QuizAttempt? _result;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<QuizQuestion>> _load() =>
      widget.useCases.quizzes.getQuestions(widget.quizId);
  void _refresh() => setState(() => _future = _load());
  Future<void> _submit(List<QuizQuestion> questions) async {
    if (_busy) {
      return;
    }
    if (questions.any((q) => !_answers.containsKey(q.id))) {
      showError(
        context,
        const AppException('Vui lòng trả lời tất cả câu hỏi trước khi nộp.'),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _submittedAnswers ??= Map<String, int>.unmodifiable(_answers);
    });
    try {
      final result = await widget.useCases.submitQuiz(
        quizId: widget.quizId,
        attemptId: _attemptId,
        answers: _submittedAnswers!,
      );
      if (mounted) {
        setState(() => _result = result);
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
    child: Scaffold(
      appBar: AppBar(
        title: Text(_result == null ? 'Làm quiz' : 'Kết quả quiz'),
      ),
      body: AsyncContent<List<QuizQuestion>>(
        future: _future,
        onRetry: _refresh,
        builder: (questions) => PageBody(
          children: [
            if (_result != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.school_outlined, size: 48),
                      Text(
                        '${_result!.correctCount}/${_result!.totalQuestions} câu đúng',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text('${_result!.percent.toStringAsFixed(1)}%'),
                    ],
                  ),
                ),
              )
            else
              Text('Đã trả lời ${_answers.length}/${questions.length} câu.'),
            if (questions.isEmpty) const EmptyView('Quiz này chưa có câu hỏi.'),
            ...questions.map((question) {
              final reviews = _result?.review.where(
                (r) => r.questionId == question.id,
              );
              final review = reviews == null || reviews.isEmpty
                  ? null
                  : reviews.first;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Câu ${question.position + 1}. ${question.question}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_result == null)
                        RadioGroup<int>(
                          groupValue: _answers[question.id],
                          onChanged: (value) {
                            if (!_busy &&
                                _submittedAnswers == null &&
                                value != null) {
                              setState(() => _answers[question.id] = value);
                            }
                          },
                          child: Column(
                            children: [
                              for (var i = 0; i < question.options.length; i++)
                                RadioListTile<int>(
                                  value: i,
                                  enabled: !_busy && _submittedAnswers == null,
                                  title: Text(
                                    '${String.fromCharCode(65 + i)}. ${question.options[i]}',
                                  ),
                                ),
                            ],
                          ),
                        )
                      else ...[
                        for (var i = 0; i < question.options.length; i++)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              review?.correctOption == i
                                  ? Icons.check_circle_outline
                                  : review?.selectedOption == i
                                  ? Icons.cancel_outlined
                                  : Icons.circle_outlined,
                              color: review?.correctOption == i
                                  ? Colors.green
                                  : review?.selectedOption == i
                                  ? Colors.red
                                  : null,
                            ),
                            title: Text(
                              '${String.fromCharCode(65 + i)}. ${question.options[i]}',
                            ),
                          ),
                        if (review != null)
                          Text('Giải thích: ${review.explanation}'),
                      ],
                    ],
                  ),
                ),
              );
            }),
            if (_error != null)
              Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
            if (_result == null && questions.isNotEmpty)
              FilledButton(
                onPressed: _busy ? null : () => _submit(questions),
                child: Text(
                  _busy
                      ? 'Đang chấm…'
                      : _submittedAnswers == null
                      ? 'Nộp bài'
                      : 'Gửi lại bài',
                ),
              ),
            if (_result != null)
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Về danh sách quiz'),
              ),
          ],
        ),
      ),
    ),
  );
}
