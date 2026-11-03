import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_exception.dart';
import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'widgets.dart';

class AiPage extends StatefulWidget {
  const AiPage({super.key, required this.useCases});
  final VstudyUseCases useCases;
  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiOverview {
  const _AiOverview(this.threads, this.documents);
  final List<ChatThread> threads;
  final List<StudyDocument> documents;
}

class _AiPageState extends State<AiPage> {
  late Future<_AiOverview> _future;
  AiMode _mode = AiMode.qa;
  String? _documentId;
  bool _mutating = false;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AiOverview> _load() async {
    final results = await Future.wait<Object>([
      widget.useCases.assistant.listThreads(),
      widget.useCases.documents.listDocuments(),
    ]);
    return _AiOverview(
      results[0] as List<ChatThread>,
      results[1] as List<StudyDocument>,
    );
  }

  void _refresh() => setState(() => _future = _load());
  Future<void> _open([ChatThread? thread]) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _ConversationPage(
          useCases: widget.useCases,
          thread: thread,
          mode: thread?.mode ?? _mode,
          documentId: thread == null ? _documentId : thread.documentId,
        ),
      ),
    );
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _documents() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentsPage(useCases: widget.useCases),
      ),
    );
    if (mounted) {
      setState(() => _documentId = null);
      _refresh();
    }
  }

  Future<void> _delete(ChatThread thread) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa cuộc trò chuyện?'),
        content: Text(thread.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) {
      return;
    }
    setState(() => _mutating = true);
    try {
      await widget.useCases.assistant.deleteThread(thread.id);
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

  @override
  Widget build(BuildContext context) => AsyncContent<_AiOverview>(
    future: _future,
    onRetry: _refresh,
    builder: (data) => PageBody(
      children: [
        Text(
          'Hôm nay ôn gì nào?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Hỏi đáp, tóm tắt, tạo flashcard hoặc xây dựng lộ trình ôn tập.',
        ),
        SectionTitle(
          'Công cụ AI',
          action: IconButton(
            onPressed: _refresh,
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AiMode.values
              .map(
                (mode) => ChoiceChip(
                  label: Text(aiModeLabel(mode)),
                  selected: _mode == mode,
                  onSelected: (_) => setState(() => _mode = mode),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _documentId,
          key: ValueKey(_documentId),
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Tài liệu cho cuộc trò chuyện mới',
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Không dùng tài liệu'),
            ),
            ...data.documents.map(
              (d) => DropdownMenuItem(
                value: d.id,
                child: Text(d.title, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _documentId = value),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _documents,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Quản lý tài liệu PDF/TXT'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => _open(),
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Bắt đầu cuộc trò chuyện'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Câu trả lời AI cần được kiểm tra lại. Nội dung tài liệu được gửi đến Gemini khi bạn dùng AI với tài liệu đó.',
        ),
        const SectionTitle('Gần đây'),
        if (data.threads.isEmpty) const EmptyView('Chưa có cuộc trò chuyện.'),
        ...data.threads.map(
          (thread) => Card(
            child: ListTile(
              title: Text(thread.title),
              subtitle: Text(
                '${aiModeLabel(thread.mode)} · ${shortDate(thread.updatedAt)}',
              ),
              onTap: () => _open(thread),
              trailing: IconButton(
                tooltip: 'Xóa cuộc trò chuyện',
                onPressed: _mutating ? null : () => _delete(thread),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ConversationPage extends StatefulWidget {
  const _ConversationPage({
    required this.useCases,
    required this.mode,
    this.thread,
    this.documentId,
  });
  final VstudyUseCases useCases;
  final ChatThread? thread;
  final AiMode mode;
  final String? documentId;
  @override
  State<_ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<_ConversationPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late Future<List<ChatMessage>> _future;
  String? _threadId;
  List<ChatMessage> _messages = [];
  bool _sending = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _threadId = widget.thread?.id;
    _future = _load();
    if (widget.thread == null) {
      _input.text = switch (widget.mode) {
        AiMode.summary => 'Tóm tắt các ý chính và kiến thức cần ghi nhớ.',
        AiMode.plan => 'Giúp mình lập lộ trình ôn tập phù hợp trong tuần này.',
        AiMode.flashcards => 'Tạo flashcard hỏi–đáp để mình ôn tập.',
        AiMode.qa => '',
      };
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<List<ChatMessage>> _load() async {
    final data = _threadId == null
        ? <ChatMessage>[]
        : await widget.useCases.assistant.listMessages(_threadId!);
    _messages = List.of(data);
    return data;
  }

  void _refresh() => setState(() => _future = _load());
  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  });
  Future<void> _send() async {
    if (_sending) {
      return;
    }
    final text = _input.text;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final turn = await widget.useCases.sendMessage(
        message: text,
        mode: widget.mode,
        threadId: _threadId,
        documentId: widget.documentId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _threadId = turn.threadId;
        _messages = [..._messages, turn.userMessage, turn.assistantMessage];
        _input.clear();
      });
      _scrollDown();
    } catch (error) {
      if (mounted) {
        setState(() => _error = errorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.thread?.title ?? '${aiModeLabel(widget.mode)} cùng Vstudy',
        ),
      ),
      body: SafeArea(
        child: AsyncContent<List<ChatMessage>>(
          future: _future,
          onRetry: _refresh,
          builder: (_) => Column(
            children: [
              if (widget.documentId != null)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Đang sử dụng tài liệu đã chọn làm ngữ cảnh.'),
                ),
              Expanded(
                child: _messages.isEmpty
                    ? const Center(
                        child: EmptyView(
                          'Hỏi AI bất cứ điều gì về việc học của bạn.',
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isUser = message.role == 'user';
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: Card(
                                color: isUser ? const Color(0xFFF6EBC4) : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isUser ? 'Bạn' : 'Vstudy AI',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      SelectableText(message.content),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (_sending) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Semantics(liveRegion: true, child: Text(_error!)),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        enabled: !_sending,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 8000,
                        decoration: const InputDecoration(
                          labelText: 'Hỏi AI bất cứ điều gì…',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      tooltip: 'Gửi tin nhắn',
                      icon: const Icon(Icons.send_outlined),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key, required this.useCases});
  final VstudyUseCases useCases;
  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  late Future<List<StudyDocument>> _future;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _future = widget.useCases.documents.listDocuments();
  }

  void _refresh() =>
      setState(() => _future = widget.useCases.documents.listDocuments());
  Future<void> _upload() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
        withData: false,
        withReadStream: true,
      );
      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }
      final file = result.files.single;
      const maximumBytes = 10 * 1024 * 1024;
      if (file.size > maximumBytes) {
        throw const AppException('Tài liệu tối đa 10 MiB.');
      }
      final extension = file.extension?.toLowerCase();
      if (extension != 'pdf' && extension != 'txt') {
        throw const AppException('Chỉ hỗ trợ PDF và TXT.');
      }
      final stream = file.readStream;
      final Uint8List bytes;
      if (stream != null) {
        final builder = BytesBuilder(copy: false);
        var received = 0;
        await for (final chunk in stream) {
          if (!mounted) {
            return;
          }
          received += chunk.length;
          if (received > maximumBytes) {
            throw const AppException('Tài liệu tối đa 10 MiB.');
          }
          builder.add(chunk);
        }
        bytes = builder.takeBytes();
      } else {
        final suppliedBytes = file.bytes;
        if (suppliedBytes == null) {
          throw const AppException('Không đọc được tài liệu đã chọn.');
        }
        if (suppliedBytes.length > maximumBytes) {
          throw const AppException('Tài liệu tối đa 10 MiB.');
        }
        bytes = suppliedBytes;
      }
      if (!mounted) {
        return;
      }
      await widget.useCases.uploadDocument(
        title: file.name,
        filename: file.name,
        mimeType: extension == 'pdf' ? 'application/pdf' : 'text/plain',
        bytes: bytes,
      );
      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã tải tài liệu lên.')));
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

  Future<void> _delete(StudyDocument document) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa tài liệu?'),
        content: Text(document.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.useCases.documents.deleteDocument(document);
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
    appBar: AppBar(title: const Text('Tài liệu của bạn')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Tài liệu PDF/TXT tối đa 10 MiB. Tài liệu được lưu riêng theo tài khoản.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _upload,
                icon: const Icon(Icons.upload_file),
                label: Text(_busy ? 'Đang xử lý…' : 'Chọn và tải tài liệu'),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncContent<List<StudyDocument>>(
            future: _future,
            onRetry: _refresh,
            builder: (documents) => PageBody(
              children: [
                if (documents.isEmpty) const EmptyView('Chưa có tài liệu.'),
                ...documents.map(
                  (document) => Card(
                    child: ListTile(
                      leading: Icon(
                        document.mimeType == 'application/pdf'
                            ? Icons.picture_as_pdf_outlined
                            : Icons.description_outlined,
                      ),
                      title: Text(document.title),
                      subtitle: Text(
                        '${(document.sizeBytes / 1024).toStringAsFixed(1)} KiB · ${shortDate(document.createdAt)}',
                      ),
                      trailing: IconButton(
                        onPressed: _busy ? null : () => _delete(document),
                        tooltip: 'Xóa tài liệu',
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
