import 'dart:collection';
import 'package:flutter/material.dart';
import '../domain/ai_workspace.dart';
import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'ai_artifact_pages.dart';
import 'ai_conversation_page.dart';
import 'ai_document_library.dart';
import 'ai_quiz_builder.dart';
import 'ai_widgets.dart';
import 'design_system.dart';
import 'documents_page.dart';
import 'widgets.dart';

class AiPage extends StatefulWidget {
  const AiPage({
    super.key,
    required this.useCases,
    this.initialPrompt,
    this.preview = false,
    this.onClose,
    this.promptVersion = 0,
  });
  final VstudyUseCases useCases;
  final String? initialPrompt;
  final bool preview;
  final VoidCallback? onClose;
  final int promptVersion;
  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiOverview {
  const _AiOverview(
    this.threads,
    this.documents,
    this.artifacts,
    this.artifactError,
  );
  final List<ChatThread> threads;
  final List<StudyDocument> documents;
  final List<AiArtifact> artifacts;
  final bool artifactError;
}

class _AiPageState extends State<AiPage> {
  final _input = TextEditingController();
  late Future<_AiOverview> _future;
  bool _opening = false;
  bool _mutating = false;
  bool _showAllThreads = false;
  bool get _locked => _opening || _mutating;
  @override
  void initState() {
    super.initState();
    _future = _load();
    _input.addListener(_changed);
    if (widget.initialPrompt != null) {
      final prompt = widget.initialPrompt!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _incomingPrompt(prompt);
        }
      });
    }
  }

  @override
  void didUpdateWidget(AiPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPrompt != null &&
        (widget.promptVersion != oldWidget.promptVersion ||
            widget.initialPrompt != oldWidget.initialPrompt)) {
      final prompt = widget.initialPrompt!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _incomingPrompt(prompt);
        }
      });
    }
  }

  Future<void> _incomingPrompt(String prompt) async {
    // Incoming questions stack above existing AI routes. They do not overwrite
    // the home composer or an earlier conversation's unsent draft.
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AiConversationPage(
          useCases: widget.useCases,
          initialPrompt: prompt,
          preview: widget.preview,
        ),
      ),
    );
    if (mounted) {
      _refresh();
    }
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<(List<AiArtifact>, bool)> _artifacts() async {
    try {
      return (
        await widget.useCases.aiWorkspace?.listArtifacts() ?? <AiArtifact>[],
        false,
      );
    } catch (_) {
      return (<AiArtifact>[], true);
    }
  }

  Future<_AiOverview> _load() async {
    final values = await Future.wait<Object>([
      widget.useCases.assistant.listThreads(),
      widget.useCases.documents.listDocuments(),
      _artifacts(),
    ]);
    final artifacts = values[2] as (List<AiArtifact>, bool);
    return _AiOverview(
      values[0] as List<ChatThread>,
      values[1] as List<StudyDocument>,
      artifacts.$1,
      artifacts.$2,
    );
  }

  void _refresh() => setState(() => _future = _load());
  Future<T?> _route<T>(Widget Function() builder) async {
    if (_locked) {
      return null;
    }
    setState(() => _opening = true);
    try {
      return await Navigator.of(
        context,
      ).push<T>(MaterialPageRoute(builder: (_) => builder()));
    } finally {
      if (mounted) {
        setState(() => _opening = false);
        _refresh();
      }
    }
  }

  Future<void> _chat({
    ChatThread? thread,
    StudyDocument? document,
    String? prompt,
    AiMode mode = AiMode.qa,
    bool autoSend = false,
  }) async {
    await _route<void>(
      () => AiConversationPage(
        useCases: widget.useCases,
        mode: thread?.mode ?? mode,
        thread: thread,
        document: document,
        initialPrompt: prompt,
        preview: widget.preview,
        sendImmediately: autoSend,
      ),
    );
  }

  Future<void> _qa() async {
    final docs = await _route<List<StudyDocument>>(
      () => AiDocumentLibraryPage(
        useCases: widget.useCases,
        preview: widget.preview,
        maximum: 1,
        allowEmpty: true,
      ),
    );
    if (mounted && docs != null) {
      await _chat(document: docs.firstOrNull);
    }
  }

  Future<void> _artifact(AiArtifact artifact) async {
    if (_locked) {
      return;
    }
    setState(() => _opening = true);
    try {
      await openAiArtifact(
        context,
        widget.useCases,
        artifact,
        preview: widget.preview,
      );
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
        _refresh();
      }
    }
  }

  Future<void> _delete({ChatThread? thread, AiArtifact? artifact}) async {
    if (_locked) {
      return;
    }
    final yes = await confirmAiAction(
      context,
      title: thread != null ? 'Xóa hội thoại?' : 'Xóa nội dung đã tạo?',
      message: thread != null
          ? thread.title
          : '${artifact!.title}\nBộ quiz đã tạo vẫn được giữ ở tab Quiz.',
    );
    if (!yes || !mounted) {
      return;
    }
    setState(() => _mutating = true);
    try {
      if (thread != null) {
        await widget.useCases.assistant.deleteThread(thread.id);
      } else {
        await widget.useCases.aiWorkspace!.deleteArtifact(artifact!.id);
      }
      if (mounted) {
        _refresh();
      }
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _mutating = false);
      }
    }
  }

  Widget _tool(
    String keyName,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          key: ValueKey(keyName),
          onTap: _locked ? null : onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 15),
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                CircleAvatar(
                  radius: 19,
                  backgroundColor: VstudyColors.paleGold,
                  child: Icon(icon, color: VstudyColors.navy, size: 21),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => AiFrame(
    title: 'Trợ lý V-study',
    subtitle: 'Học sâu hơn, ôn tập hiệu quả hơn',
    busy: _locked,
    onBack: widget.onClose,
    onSparkle: _locked ? null : _refresh,
    body: Column(
      children: [
        if (widget.preview) const AiPreviewNote(),
        Expanded(
          child: AsyncContent<_AiOverview>(
            future: _future,
            onRetry: _refresh,
            builder: (data) => ListView(
              key: const ValueKey('ai-home-list'),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              children: [
                AiPanel(
                  color: VstudyColors.navy,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hôm nay ôn gì nào?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Chọn tài liệu và để AI đồng hành cùng bạn.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              key: const ValueKey('ai-choose-document'),
                              onPressed: _locked ? null : _qa,
                              style: FilledButton.styleFrom(
                                backgroundColor: VstudyColors.gold,
                                foregroundColor: VstudyColors.navy,
                              ),
                              child: const Text(
                                'Chọn tài liệu',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.auto_awesome,
                        color: VstudyColors.gold,
                        size: 44,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Công cụ AI',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _tool(
                      'ai-tool-summary',
                      'Tóm tắt',
                      Icons.summarize_outlined,
                      () => _route<void>(
                        () => AiDocumentLibraryPage(
                          useCases: widget.useCases,
                          preview: widget.preview,
                          createSummary: true,
                        ),
                      ),
                    ),
                    _tool(
                      'ai-tool-qa',
                      'Hỏi đáp',
                      Icons.question_answer_outlined,
                      _qa,
                    ),
                    _tool(
                      'ai-tool-quiz',
                      'Tạo đề ôn',
                      Icons.quiz_outlined,
                      () => _route<void>(
                        () => AiQuizBuilderPage(
                          useCases: widget.useCases,
                          preview: widget.preview,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text(
                        'Lộ trình học',
                        style: TextStyle(fontSize: 11),
                      ),
                      onPressed: _locked
                          ? null
                          : () => _chat(mode: AiMode.plan),
                    ),
                    ActionChip(
                      label: const Text(
                        'Flashcard',
                        style: TextStyle(fontSize: 11),
                      ),
                      onPressed: _locked
                          ? null
                          : () => _chat(mode: AiMode.flashcards),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: _locked
                      ? null
                      : () => _route<void>(
                          () => DocumentsPage(useCases: widget.useCases),
                        ),
                  icon: const Icon(Icons.folder_open_outlined, size: 16),
                  label: const Text(
                    'Quản lý tài liệu PDF/TXT',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Hội thoại gần đây',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                if (data.threads.isEmpty)
                  const EmptyView(
                    'Chưa có hội thoại. Hãy bắt đầu bằng một câu hỏi.',
                  ),
                for (final thread in data.threads.take(
                  _showAllThreads ? data.threads.length : 5,
                ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        key: ValueKey('ai-thread-${thread.id}'),
                        leading: const CircleAvatar(
                          radius: 15,
                          backgroundColor: VstudyColors.paleGold,
                          child: Icon(Icons.chat_bubble_outline, size: 15),
                        ),
                        title: Text(
                          thread.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${aiModeLabel(thread.mode)} · ${shortDate(thread.updatedAt)}',
                          style: const TextStyle(fontSize: 10),
                        ),
                        onTap: _locked
                            ? null
                            : () => _chat(
                                thread: thread,
                                document: data.documents
                                    .where((d) => d.id == thread.documentId)
                                    .firstOrNull,
                              ),
                        trailing: IconButton(
                          tooltip: 'Xóa hội thoại',
                          onPressed: _locked
                              ? null
                              : () => _delete(thread: thread),
                          icon: const Icon(Icons.more_horiz, size: 18),
                        ),
                      ),
                    ),
                  ),
                if (data.threads.length > 5)
                  TextButton(
                    onPressed: () =>
                        setState(() => _showAllThreads = !_showAllThreads),
                    child: Text(
                      _showAllThreads
                          ? 'Thu gọn hội thoại'
                          : 'Xem tất cả hội thoại',
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Nội dung đã tạo',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                if (data.artifactError)
                  const Text(
                    'Chưa tải được nội dung AI đã tạo. Bấm nút sao để tải lại.',
                    style: TextStyle(fontSize: 11, color: VstudyColors.muted),
                  )
                else if (data.artifacts.isEmpty)
                  const EmptyView(
                    'Bản tóm tắt và đề ôn của bạn sẽ xuất hiện ở đây.',
                  ),
                for (final artifact in data.artifacts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        key: ValueKey('ai-artifact-${artifact.id}'),
                        leading: Icon(
                          artifact.kind == AiArtifactKind.summary
                              ? Icons.summarize_outlined
                              : Icons.quiz_outlined,
                          color: VstudyColors.gold,
                        ),
                        title: Text(
                          artifact.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${artifact.kind == AiArtifactKind.summary
                              ? 'Tóm tắt'
                              : artifact.kind == AiArtifactKind.quiz
                              ? 'Quiz'
                              : 'Đề tự luyện'} · ${shortDate(artifact.createdAt)}',
                          style: const TextStyle(fontSize: 10),
                        ),
                        onTap: _locked ? null : () => _artifact(artifact),
                        trailing: IconButton(
                          tooltip: 'Xóa nội dung AI',
                          onPressed: _locked
                              ? null
                              : () => _delete(artifact: artifact),
                          icon: const Icon(Icons.more_horiz, size: 18),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'AI có thể nhầm lẫn; hãy đối chiếu kiến thức với tài liệu gốc.',
                  style: TextStyle(fontSize: 10, color: VstudyColors.muted),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('ai-home-attach'),
                  tooltip: 'Chọn tài liệu để hỏi đáp',
                  onPressed: _locked ? null : _qa,
                  icon: const Icon(Icons.add_circle_outline, size: 23),
                ),
                Expanded(
                  child: TextField(
                    key: const ValueKey('ai-home-input'),
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Hỏi AI bất cứ điều gì…',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const ValueKey('ai-home-send'),
                  tooltip: 'Gửi câu hỏi',
                  style: IconButton.styleFrom(
                    backgroundColor: VstudyColors.gold,
                    foregroundColor: VstudyColors.navy,
                  ),
                  onPressed: _locked || _input.text.trim().isEmpty
                      ? null
                      : () {
                          final text = _input.text.trim();
                          _input.clear();
                          _chat(prompt: text, autoSend: true);
                        },
                  icon: const Icon(Icons.arrow_upward, size: 21),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
