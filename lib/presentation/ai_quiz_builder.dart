import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../domain/ai_workspace.dart';
import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'ai_artifact_pages.dart';
import 'ai_document_library.dart';
import 'ai_widgets.dart';
import 'design_system.dart';
import 'widgets.dart';

class AiQuizBuilderPage extends StatefulWidget {
  const AiQuizBuilderPage({
    super.key,
    required this.useCases,
    this.preview = false,
  });
  final VstudyUseCases useCases;
  final bool preview;
  @override
  State<AiQuizBuilderPage> createState() => _AiQuizBuilderPageState();
}

class _AiQuizBuilderPageState extends State<AiQuizBuilderPage> {
  final _title = TextEditingController(text: 'Đề ôn tập');
  final _topic = TextEditingController();
  List<StudyDocument> _documents = [];
  final _kinds = <ExerciseKind>{ExerciseKind.multipleChoice};
  int _count = 20;
  String _difficulty = 'medium';
  String? _requestId;
  String? _signature;
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _title.dispose();
    _topic.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_busy) {
      return;
    }
    final docs = await Navigator.of(context).push<List<StudyDocument>>(
      MaterialPageRoute(
        builder: (_) => AiDocumentLibraryPage(
          useCases: widget.useCases,
          preview: widget.preview,
          maximum: 3,
          initialSelected: _documents.map((d) => d.id).toList(),
          allowEmpty: true,
        ),
      ),
    );
    if (!mounted || docs == null) {
      return;
    }
    setState(() => _documents = docs);
  }

  Future<void> _create() async {
    if (_busy) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final ids = _documents.map((d) => d.id).toList()..sort();
    final request = AiMaterialRequest(
      requestId: '',
      kind: _kinds.length == 1 && _kinds.contains(ExerciseKind.multipleChoice)
          ? AiArtifactKind.quiz
          : AiArtifactKind.worksheet,
      title: _title.text.trim(),
      topic: _topic.text.trim(),
      documentIds: ids,
      questionCount: _count,
      difficulty: _difficulty,
      exerciseKinds: ExerciseKind.values.where(_kinds.contains).toList(),
    );
    if (_signature != request.signature) {
      _signature = request.signature;
      _requestId = const Uuid().v4();
    }
    try {
      final artifact = await widget.useCases.createAiMaterial(
        AiMaterialRequest(
          requestId: _requestId!,
          kind: request.kind,
          title: request.title,
          topic: request.topic,
          documentIds: request.documentIds,
          questionCount: request.questionCount,
          difficulty: request.difficulty,
          exerciseKinds: request.exerciseKinds,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      await openAiArtifact(
        context,
        widget.useCases,
        artifact,
        preview: widget.preview,
      );
      // A successful result has been opened. A deliberate next creation is a
      // new request; failures before opening keep the same retry identity.
      _requestId = null;
      _signature = null;
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
    child: AiFrame(
      title: 'Tạo đề ôn',
      subtitle: 'Tạo đề từ tài liệu hoặc chủ đề',
      busy: _busy,
      body: Column(
        children: [
          if (widget.preview) const AiPreviewNote(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              children: [
                AiPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Nguồn tài liệu',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final doc in _documents)
                        AiDocumentTile(document: doc),
                      OutlinedButton.icon(
                        key: const ValueKey('ai-quiz-documents'),
                        onPressed: _busy ? null : _pick,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(
                          _documents.isEmpty ? 'Chọn tài liệu' : 'Đổi tài liệu',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('ai-quiz-title'),
                        controller: _title,
                        enabled: !_busy,
                        decoration: const InputDecoration(labelText: 'Tên đề'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('ai-quiz-topic'),
                        controller: _topic,
                        enabled: !_busy,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Chủ đề',
                          hintText: _documents.isEmpty
                              ? 'Ví dụ: Đạo hàm và giới hạn'
                              : 'Để trống để ôn toàn bộ tài liệu đã chọn',
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
                        'Số câu hỏi',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        children: [
                          for (final count in [10, 20, 30, 40])
                            ChoiceChip(
                              key: ValueKey('ai-quiz-count-$count'),
                              label: Text('$count'),
                              selected: _count == count,
                              onSelected: _busy
                                  ? null
                                  : (_) => setState(() => _count = count),
                            ),
                        ],
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
                        'Độ khó',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        children: [
                          for (final pair in [
                            ('easy', 'Dễ'),
                            ('medium', 'Vừa'),
                            ('hard', 'Khó'),
                          ])
                            ChoiceChip(
                              key: ValueKey('ai-quiz-difficulty-${pair.$1}'),
                              label: Text(pair.$2),
                              selected: _difficulty == pair.$1,
                              onSelected: _busy
                                  ? null
                                  : (_) =>
                                        setState(() => _difficulty = pair.$1),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AiPanel(
                  padding: 6,
                  child: Column(
                    children: [
                      for (final kind in ExerciseKind.values)
                        SwitchListTile.adaptive(
                          key: ValueKey('ai-quiz-kind-${kind.wire}'),
                          title: Text(
                            kind.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          activeTrackColor: VstudyColors.gold,
                          value: _kinds.contains(kind),
                          onChanged: _busy
                              ? null
                              : (value) => setState(() {
                                  if (value) {
                                    _kinds.add(kind);
                                  } else {
                                    _kinds.remove(kind);
                                  }
                                }),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _kinds.length == 1 &&
                          _kinds.contains(ExerciseKind.multipleChoice)
                      ? 'Bộ trắc nghiệm được lưu vào Quiz, có chấm điểm và làm bài trong 30 phút.'
                      : 'Đúng/sai và tự luận dùng đề tự luyện có gợi ý, lời giải và đáp án mẫu; không cộng vào thống kê quiz.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: VstudyColors.muted,
                    height: 1.5,
                  ),
                ),
                if (!widget.preview && _documents.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Các tài liệu đã chọn sẽ được gửi đến Gemini.',
                      style: TextStyle(fontSize: 10, color: VstudyColors.muted),
                    ),
                  ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  key: const ValueKey('ai-quiz-error'),
                  style: const TextStyle(color: VstudyColors.red),
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('ai-quiz-create'),
                  onPressed: _busy ? null : _create,
                  child: Text(_busy ? 'Đang tạo đề…' : 'Tạo đề với AI'),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
