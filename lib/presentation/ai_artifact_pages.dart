import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_exception.dart';
import '../domain/ai_workspace.dart';
import '../domain/use_cases.dart';
import 'ai_widgets.dart';
import 'design_system.dart';
import 'quiz_player.dart';
import 'widgets.dart';

Future<void> openAiArtifact(
  BuildContext context,
  VstudyUseCases useCases,
  AiArtifact artifact, {
  bool preview = false,
}) async {
  if (artifact.kind == AiArtifactKind.quiz) {
    final quizzes = await useCases.quizzes.listQuizzes();
    final quiz = quizzes.where((q) => q.id == artifact.quizId).firstOrNull;
    if (quiz == null) {
      throw const AppException(
        'Bộ quiz không còn tồn tại. Vui lòng tải lại danh sách.',
      );
    }
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => QuizPlayerPage(
          useCases: useCases,
          quiz: quiz,
          mode: QuizPlayMode.exam,
          assistantStyle: true,
        ),
      ),
    );
  } else {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => artifact.kind == AiArtifactKind.summary
            ? AiSummaryPage(
                useCases: useCases,
                artifact: artifact,
                preview: preview,
              )
            : AiWorksheetPage(artifact: artifact, preview: preview),
      ),
    );
  }
}

class AiSummaryPage extends StatefulWidget {
  const AiSummaryPage({
    super.key,
    required this.useCases,
    required this.artifact,
    this.preview = false,
  });
  final VstudyUseCases useCases;
  final AiArtifact artifact;
  final bool preview;
  @override
  State<AiSummaryPage> createState() => _AiSummaryPageState();
}

class _AiSummaryPageState extends State<AiSummaryPage> {
  int _tab = 0;
  int? _feedback;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _feedback = widget.artifact.feedback;
  }

  Future<void> _rate(int value) async {
    if (_busy || widget.useCases.aiWorkspace == null) {
      return;
    }
    setState(() => _busy = true);
    final next = _feedback == value ? null : value;
    try {
      await widget.useCases.aiWorkspace!.setFeedback(widget.artifact.id, next);
      if (mounted) {
        setState(() => _feedback = next);
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

  Widget _points(List<String> points) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: points
        .map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(
                    color: VstudyColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    p,
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );
  @override
  Widget build(BuildContext context) {
    final summary = widget.artifact.summary;
    return AiFrame(
      title: 'Tóm tắt tài liệu',
      subtitle: 'Ôn tập ngắn gọn, nhớ lâu hơn',
      body: summary == null
          ? const Center(child: Text('Nội dung tóm tắt chưa có.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              children: [
                if (widget.preview) const AiPreviewNote(),
                AiPanel(
                  padding: 12,
                  child: Row(
                    children: [
                      const Icon(Icons.description, color: VstudyColors.navy),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.artifact.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${widget.artifact.sourceTitles.length} tài liệu · ${shortDate(widget.artifact.createdAt)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: VstudyColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('ai-summary-copy'),
                        tooltip: 'Sao chép bản tóm tắt',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(
                              text:
                                  '${widget.artifact.title}\n\n${summary.text}',
                            ),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã sao chép bản tóm tắt.'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_outlined, size: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ChoiceChip(
                            key: ValueKey('ai-summary-tab-$i'),
                            label: Text(
                              ['Ngắn gọn', 'Chi tiết', 'Sơ đồ'][i],
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: _tab == i,
                            selectedColor: VstudyColors.navy,
                            labelStyle: TextStyle(
                              color: _tab == i
                                  ? Colors.white
                                  : VstudyColors.navy,
                            ),
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _tab = i),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_tab == 0)
                  AiPanel(
                    key: const ValueKey('ai-summary-brief'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Ý chính',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        _points(summary.brief),
                      ],
                    ),
                  )
                else if (_tab == 1)
                  AiPanel(
                    key: const ValueKey('ai-summary-details'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final section in summary.sections) ...[
                          Text(
                            section.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          _points(section.points),
                        ],
                      ],
                    ),
                  )
                else
                  AiPanel(
                    key: const ValueKey('ai-summary-mind-map'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: VstudyColors.navy,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.artifact.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        for (final branch in summary.mindMap)
                          Padding(
                            padding: const EdgeInsets.only(top: 12, left: 12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: VstudyColors.gold,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    branch.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _points(branch.points),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                AiPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Quan trọng',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: summary.keywords
                            .map(
                              (word) => Chip(
                                label: Text(
                                  word,
                                  style: const TextStyle(fontSize: 10),
                                ),
                                side: BorderSide.none,
                                backgroundColor: VstudyColors.paleGold,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AiPanel(
                  padding: 12,
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tóm tắt này hữu ích?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('ai-feedback-up'),
                        tooltip: 'Hữu ích',
                        onPressed: _busy ? null : () => _rate(1),
                        color: _feedback == 1
                            ? VstudyColors.gold
                            : VstudyColors.navy,
                        icon: Icon(
                          _feedback == 1
                              ? Icons.thumb_up
                              : Icons.thumb_up_outlined,
                          size: 20,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('ai-feedback-down'),
                        tooltip: 'Cần cải thiện',
                        onPressed: _busy ? null : () => _rate(-1),
                        color: _feedback == -1
                            ? VstudyColors.red
                            : VstudyColors.navy,
                        icon: Icon(
                          _feedback == -1
                              ? Icons.thumb_down
                              : Icons.thumb_down_outlined,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Nguồn khi tạo: ${widget.artifact.sourceTitles.join(' · ')}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: VstudyColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Đối chiếu kiến thức với tài liệu gốc khi cần.',
                  style: TextStyle(fontSize: 10, color: VstudyColors.muted),
                ),
              ],
            ),
    );
  }
}

class AiWorksheetPage extends StatefulWidget {
  const AiWorksheetPage({
    super.key,
    required this.artifact,
    this.preview = false,
  });
  final AiArtifact artifact;
  final bool preview;
  @override
  State<AiWorksheetPage> createState() => _AiWorksheetPageState();
}

class _AiWorksheetPageState extends State<AiWorksheetPage> {
  int _index = 0;
  final _answers = <int, int>{};
  final _essays = <int, String>{};
  final _revealed = <int>{};
  final _hints = <int>{};
  bool _finished = false;
  bool _closing = false;
  Future<void> _close() async {
    if (_closing) {
      return;
    }
    _closing = true;
    if (!_finished &&
        (_answers.isNotEmpty ||
            _essays.values.any((v) => v.trim().isNotEmpty))) {
      final leave = await confirmAiAction(
        context,
        title: 'Rời đề tự luyện?',
        message:
            'Đề và lời giải đã được lưu. Câu trả lời trong lượt tự luyện này sẽ không được giữ.',
        confirm: 'Rời đề',
      );
      if (!mounted) {
        return;
      }
      if (!leave) {
        _closing = false;
        return;
      }
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.artifact.exercises;
    if (questions.isEmpty) {
      return const Scaffold(body: Center(child: Text('Đề chưa có câu hỏi.')));
    }
    final q = questions[_index];
    final revealed = _revealed.contains(_index);
    final answered = q.kind == ExerciseKind.essay
        ? (_essays[_index]?.trim().isNotEmpty ?? false)
        : _answers.containsKey(_index);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _close();
        }
      },
      child: AiFrame(
        title: widget.artifact.title,
        subtitle: 'Đề tự luyện · Không cộng vào điểm quiz',
        onBack: _close,
        onSparkle: _close,
        body: _finished
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AiPanel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.task_alt,
                          size: 54,
                          color: VstudyColors.green,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Đã hoàn tất lượt tự luyện',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Đã xem lời giải ${_revealed.length}/${questions.length} câu.',
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Đối chiếu tự luận với đáp án mẫu. Kết quả này không phải bài thi được chấm điểm.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _close,
                          child: const Text('Về công cụ AI'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
                children: [
                  if (widget.preview) const AiPreviewNote(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Câu ${_index + 1}/${questions.length}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(q.kind.label, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: (_index + 1) / questions.length,
                    color: VstudyColors.navy,
                    backgroundColor: VstudyColors.blue,
                  ),
                  const SizedBox(height: 22),
                  AiPanel(
                    child: Text(
                      q.question,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (q.kind == ExerciseKind.essay)
                    TextFormField(
                      key: ValueKey('ai-essay-$_index'),
                      initialValue: _essays[_index],
                      readOnly: revealed,
                      minLines: 4,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        hintText: 'Viết cách hiểu và ví dụ của bạn…',
                      ),
                      onChanged: (value) =>
                          setState(() => _essays[_index] = value),
                    )
                  else
                    for (var i = 0; i < q.options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: revealed && q.correctOption == i
                              ? const Color(0xFFE5F3E9)
                              : _answers[_index] == i
                              ? VstudyColors.paleGold
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            key: ValueKey('ai-exercise-choice-$i'),
                            leading: CircleAvatar(
                              radius: 13,
                              backgroundColor: VstudyColors.paleGold,
                              child: Text(
                                String.fromCharCode(65 + i),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            title: Text(
                              q.options[i],
                              style: const TextStyle(fontSize: 13),
                            ),
                            onTap: revealed
                                ? null
                                : () => setState(() => _answers[_index] = i),
                          ),
                        ),
                      ),
                  const SizedBox(height: 8),
                  AiPanel(
                    color: VstudyColors.paleGold,
                    padding: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextButton.icon(
                          key: const ValueKey('ai-exercise-hint'),
                          onPressed: () => setState(() => _hints.add(_index)),
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('Gợi ý'),
                        ),
                        if (_hints.contains(_index))
                          Text(
                            q.hint,
                            style: const TextStyle(fontSize: 12, height: 1.5),
                          ),
                      ],
                    ),
                  ),
                  if (revealed)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: AiPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              q.kind == ExerciseKind.essay
                                  ? 'Đáp án mẫu để tự đối chiếu'
                                  : _answers[_index] == q.correctOption
                                  ? 'Chính xác!'
                                  : 'Cùng xem lại đáp án',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (q.kind == ExerciseKind.essay)
                              SelectableText(q.sampleAnswer),
                            SelectableText(
                              q.explanation,
                              style: const TextStyle(fontSize: 13, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      TextButton(
                        key: const ValueKey('ai-exercise-previous'),
                        onPressed: _index == 0
                            ? null
                            : () => setState(() => _index--),
                        child: const Text('Câu trước'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const ValueKey('ai-exercise-next'),
                          onPressed: !answered
                              ? null
                              : () => setState(() {
                                  if (!revealed) {
                                    _revealed.add(_index);
                                  } else if (_index + 1 < questions.length) {
                                    _index++;
                                  } else {
                                    _finished = true;
                                  }
                                }),
                          child: Text(
                            !revealed
                                ? q.kind == ExerciseKind.essay
                                      ? 'Xem đáp án mẫu'
                                      : 'Kiểm tra'
                                : _index + 1 == questions.length
                                ? 'Hoàn tất'
                                : 'Câu tiếp theo →',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
