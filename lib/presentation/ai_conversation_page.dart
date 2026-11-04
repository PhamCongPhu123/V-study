import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'ai_document_library.dart';
import 'ai_widgets.dart';
import 'design_system.dart';
import 'widgets.dart';

class AiConversationPage extends StatefulWidget {
  const AiConversationPage({
    super.key,
    required this.useCases,
    this.mode = AiMode.qa,
    this.thread,
    this.document,
    this.initialPrompt,
    this.preview = false,
    this.sendImmediately = false,
  });
  final VstudyUseCases useCases;
  final AiMode mode;
  final ChatThread? thread;
  final StudyDocument? document;
  final String? initialPrompt;
  final bool preview;
  final bool sendImmediately;
  @override
  State<AiConversationPage> createState() => _AiConversationPageState();
}

class _AiConversationPageState extends State<AiConversationPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late Future<List<ChatMessage>> _future;
  List<ChatMessage> _messages = [];
  String? _threadId;
  String? _documentId;
  StudyDocument? _document;
  bool _sending = false;
  bool _closing = false;
  bool _autoSent = false;
  bool _positioned = false;
  String? _pendingText;
  String? _error;
  @override
  void initState() {
    super.initState();
    _threadId = widget.thread?.id;
    _document = widget.document;
    _documentId = widget.thread?.documentId ?? widget.document?.id;
    _input.text =
        widget.initialPrompt ??
        switch (widget.mode) {
          AiMode.plan =>
            'Giúp mình lập lộ trình ôn tập phù hợp trong tuần này.',
          AiMode.flashcards => 'Tạo flashcard hỏi–đáp để mình ôn tập.',
          AiMode.summary => 'Tóm tắt những ý chính và kiến thức cần nhớ.',
          AiMode.qa => '',
        };
    if (widget.thread != null) {
      _input.clear();
    }
    _input.addListener(_changed);
    _future = _load();
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<List<ChatMessage>> _load() async {
    final messages = _threadId == null
        ? <ChatMessage>[]
        : await widget.useCases.assistant.listMessages(_threadId!);
    if (mounted) {
      _messages = List.of(messages);
    }
    return messages;
  }

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
    if (_sending || _input.text.trim().isEmpty) {
      return;
    }
    final message = _input.text.trim();
    setState(() {
      _sending = true;
      _error = null;
      _pendingText = message;
    });
    _scrollDown();
    try {
      final turn = await widget.useCases.sendMessage(
        message: message,
        mode: widget.mode,
        threadId: _threadId,
        documentId: _documentId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _threadId = turn.threadId;
        _messages.addAll([turn.userMessage, turn.assistantMessage]);
        _input.clear();
      });
      _scrollDown();
    } catch (error) {
      if (mounted) {
        setState(() => _error = errorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _pendingText = null;
        });
      }
    }
  }

  Future<void> _attach() async {
    if (_sending || _threadId != null) {
      return;
    }
    final docs = await Navigator.of(context).push<List<StudyDocument>>(
      MaterialPageRoute(
        builder: (_) => AiDocumentLibraryPage(
          useCases: widget.useCases,
          preview: widget.preview,
          maximum: 1,
          allowEmpty: true,
          initialSelected: _documentId == null ? [] : [_documentId!],
        ),
      ),
    );
    if (!mounted || docs == null) {
      return;
    }
    setState(() {
      _document = docs.isEmpty ? null : docs.single;
      _documentId = _document?.id;
    });
  }

  Future<void> _close() async {
    if (_sending || _closing) {
      return;
    }
    _closing = true;
    if (_input.text.trim().isNotEmpty) {
      final leave = await confirmAiAction(
        context,
        title: 'Rời hội thoại?',
        message: 'Tin nhắn bạn đang soạn chưa được gửi.',
        confirm: 'Bỏ bản nháp',
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

  void _prompt(String value) {
    if (_sending) {
      return;
    }
    final current = _input.text.trim();
    _input.text = current.isEmpty ? value : '$current\n\n$value';
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
  }

  Widget _bubble(String content, bool user, {DateTime? time}) => Align(
    alignment: user ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 14, left: 2, right: 2),
      padding: const EdgeInsets.all(14),
      constraints: const BoxConstraints(maxWidth: 620),
      decoration: BoxDecoration(
        color: user ? VstudyColors.navy : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(user ? 16 : 3),
          bottomRight: Radius.circular(user ? 3 : 16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            content,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: user ? Colors.white : VstudyColors.navy,
            ),
          ),
          if (time != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shortTime(time),
                  style: TextStyle(
                    fontSize: 9,
                    color: user ? Colors.white70 : VstudyColors.muted,
                  ),
                ),
                if (!user)
                  IconButton(
                    tooltip: 'Sao chép câu trả lời',
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: content));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép câu trả lời.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_outlined, size: 13),
                  ),
              ],
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        _close();
      }
    },
    child: AiFrame(
      title: _documentId != null
          ? 'Hỏi đáp tài liệu'
          : '${aiModeLabel(widget.mode)} cùng V-study',
      subtitle: 'Hỏi từng ý, hiểu sâu hơn',
      busy: _sending,
      onBack: _close,
      onSparkle: _close,
      body: AsyncContent<List<ChatMessage>>(
        future: _future,
        onRetry: () => setState(() {
          _future = _load();
          _positioned = false;
        }),
        builder: (_) {
          if (!_positioned) {
            _positioned = true;
            _scrollDown();
          }
          if (widget.sendImmediately && !_autoSent) {
            _autoSent = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _send();
              }
            });
          }
          return Column(
            children: [
              if (widget.preview) const AiPreviewNote(),
              if (_document != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AiDocumentTile(document: _document!),
                )
              else if (_documentId != null)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    'Tài liệu gốc không còn trong thư viện.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  children: [
                    if (_messages.isEmpty && !_sending)
                      const AiPanel(
                        child: Text(
                          'Bạn muốn tìm hiểu điều gì? Đặt câu hỏi hoặc chọn một gợi ý ở bên dưới.',
                          style: TextStyle(fontSize: 13, height: 1.6),
                        ),
                      ),
                    for (final message in _messages)
                      _bubble(
                        message.content,
                        message.role == 'user',
                        time: message.createdAt,
                      ),
                    if (_pendingText != null) _bubble(_pendingText!, true),
                    if (_sending)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: AiPanel(
                          padding: 12,
                          child: Text(
                            'V-study đang suy nghĩ…',
                            style: TextStyle(
                              fontSize: 12,
                              color: VstudyColors.muted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      key: const ValueKey('ai-chat-error'),
                      style: const TextStyle(color: VstudyColors.red),
                    ),
                  ),
                ),
              if (_sending) const LinearProgressIndicator(minHeight: 2),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    for (final pair in [
                      ('Cho ví dụ', 'Cho mình một ví dụ cụ thể.'),
                      ('Tạo 5 câu hỏi', 'Tạo 5 câu hỏi để mình tự kiểm tra.'),
                      ('Tóm tắt chương', 'Tóm tắt những ý chính cần nhớ.'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(
                            pair.$1,
                            style: const TextStyle(fontSize: 10),
                          ),
                          onPressed: _sending ? null : () => _prompt(pair.$2),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        key: const ValueKey('ai-chat-attach'),
                        tooltip: _threadId == null
                            ? 'Đính kèm tài liệu'
                            : 'Tạo hội thoại mới để đổi tài liệu',
                        onPressed: _sending || _threadId != null
                            ? null
                            : _attach,
                        icon: const Icon(Icons.add_circle_outline, size: 24),
                      ),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('ai-chat-input'),
                          controller: _input,
                          enabled: !_sending,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: 8000,
                          decoration: const InputDecoration(
                            hintText: 'Hỏi AI bất cứ điều gì…',
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        key: const ValueKey('ai-chat-send'),
                        tooltip: 'Gửi tin nhắn',
                        style: IconButton.styleFrom(
                          backgroundColor: VstudyColors.gold,
                          foregroundColor: VstudyColors.navy,
                        ),
                        onPressed: _sending || _input.text.trim().isEmpty
                            ? null
                            : _send,
                        icon: const Icon(Icons.arrow_upward, size: 21),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
