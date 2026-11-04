import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/app_exception.dart';
import '../domain/ai_workspace.dart';
import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'ai_artifact_pages.dart';
import 'ai_widgets.dart';
import 'design_system.dart';
import 'document_upload.dart';
import 'documents_page.dart';
import 'widgets.dart';

class AiDocumentLibraryPage extends StatefulWidget {
  const AiDocumentLibraryPage({
    super.key,
    required this.useCases,
    this.preview = false,
    this.createSummary = false,
    this.maximum = 3,
    this.allowEmpty = false,
    this.initialSelected = const [],
  });
  final VstudyUseCases useCases;
  final bool preview;
  final bool createSummary;
  final int maximum;
  final bool allowEmpty;
  final List<String> initialSelected;
  @override
  State<AiDocumentLibraryPage> createState() => _AiDocumentLibraryPageState();
}

class _AiDocumentLibraryPageState extends State<AiDocumentLibraryPage> {
  final _search = TextEditingController();
  late Future<List<StudyDocument>> _future;
  late Set<String> _selected;
  List<StudyDocument> _documents = [];
  int _filter = 0;
  bool _busy = false;
  String? _error;
  String? _requestId;
  String? _requestSignature;
  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected.toSet();
    _future = _load();
    _search.addListener(_searchChanged);
  }

  void _searchChanged() => setState(() {});
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<StudyDocument>> _load() async {
    final docs = await widget.useCases.documents.listDocuments();
    if (mounted) {
      setState(() {
        _documents = docs;
        _selected.removeWhere((id) => !docs.any((d) => d.id == id));
      });
    }
    return docs;
  }

  List<StudyDocument> get _chosen =>
      _documents.where((d) => _selected.contains(d.id)).toList();
  void _toggle(StudyDocument doc) {
    if (_busy) {
      return;
    }
    if (_selected.contains(doc.id)) {
      setState(() => _selected.remove(doc.id));
      return;
    }
    if (widget.maximum == 1) {
      setState(() => _selected = {doc.id});
      return;
    }
    if (_selected.length >= widget.maximum) {
      showError(
        context,
        AppException('Chọn tối đa ${widget.maximum} tài liệu.'),
      );
      return;
    }
    if (_chosen.fold<int>(doc.sizeBytes, (sum, d) => sum + d.sizeBytes) >
        10 * 1024 * 1024) {
      showError(context, const AppException('Tổng tài liệu tối đa 10 MiB.'));
      return;
    }
    setState(() => _selected.add(doc.id));
  }

  Future<void> _upload() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final doc = await pickAndUploadStudyDocument(widget.useCases);
      if (!mounted || doc == null) {
        return;
      }
      final docs = await _load();
      if (!mounted) {
        return;
      }
      setState(() {
        _future = Future.value(docs);
        if (widget.maximum == 1) {
          _selected = {doc.id};
        } else if (_selected.length < widget.maximum &&
            _chosen.fold<int>(doc.sizeBytes, (sum, d) => sum + d.sizeBytes) <=
                10 * 1024 * 1024) {
          _selected.add(doc.id);
        }
      });
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

  Future<void> _confirm() async {
    if (_busy) {
      return;
    }
    final docs = _chosen;
    if (docs.isEmpty && !widget.allowEmpty) {
      return;
    }
    if (!widget.createSummary) {
      Navigator.of(context).pop(docs);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ids = docs.map((d) => d.id).toList()..sort();
    final signature = ids.join('|');
    if (_requestSignature != signature) {
      _requestSignature = signature;
      _requestId = const Uuid().v4();
    }
    try {
      final result = await widget.useCases.createAiMaterial(
        AiMaterialRequest(
          requestId: _requestId!,
          kind: AiArtifactKind.summary,
          title: docs.length == 1
              ? docs.single.title
              : 'Tóm tắt ${docs.length} tài liệu',
          documentIds: ids,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      await openAiArtifact(
        context,
        widget.useCases,
        result,
        preview: widget.preview,
      );
      _requestId = null;
      _requestSignature = null;
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
      title: widget.createSummary ? 'Tóm tắt tài liệu' : 'Chọn tài liệu',
      subtitle: 'Chọn tối đa ${widget.maximum} tài liệu · PDF hoặc TXT',
      busy: _busy,
      body: Column(
        children: [
          if (widget.preview) const AiPreviewNote(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: TextField(
              key: const ValueKey('ai-library-search'),
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Tìm tài liệu…',
                prefixIcon: Icon(Icons.search, size: 19),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (var i = 0; i < 3; i++)
                        ChoiceChip(
                          key: ValueKey('ai-library-filter-$i'),
                          label: Text(
                            ['Tất cả', 'PDF', 'TXT'][i],
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: _filter == i,
                          onSelected: (_) => setState(() => _filter = i),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Quản lý tài liệu',
                  onPressed: _busy
                      ? null
                      : () async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  DocumentsPage(useCases: widget.useCases),
                            ),
                          );
                          if (mounted) {
                            setState(() => _future = _load());
                          }
                        },
                  icon: const Icon(Icons.folder_open_outlined, size: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncContent<List<StudyDocument>>(
              future: _future,
              onRetry: () => setState(() => _future = _load()),
              builder: (docs) {
                final query = _search.text.trim().toLowerCase();
                final filtered = docs
                    .where(
                      (d) =>
                          d.title.toLowerCase().contains(query) &&
                          (_filter == 0 ||
                              d.mimeType ==
                                  (_filter == 1
                                      ? 'application/pdf'
                                      : 'text/plain')),
                    )
                    .toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  children: [
                    if (filtered.isEmpty)
                      const EmptyView(
                        'Chưa có tài liệu phù hợp. Thêm PDF/TXT để bắt đầu.',
                      ),
                    for (final doc in filtered)
                      AiDocumentTile(
                        document: doc,
                        selected: _selected.contains(doc.id),
                        onTap: _busy ? null : () => _toggle(doc),
                      ),
                    OutlinedButton.icon(
                      key: const ValueKey('ai-library-upload'),
                      onPressed: _busy ? null : _upload,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Tải tài liệu mới · PDF / TXT'),
                    ),
                  ],
                );
              },
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
                  key: const ValueKey('ai-library-error'),
                  style: const TextStyle(color: VstudyColors.red),
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Đã chọn ${_selected.length} tài liệu · ${(_chosen.fold<int>(0, (sum, d) => sum + d.sizeBytes) / 1024).toStringAsFixed(0)} KiB',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: VstudyColors.muted,
                    ),
                  ),
                  if (!widget.preview)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Tài liệu đã chọn sẽ được gửi đến Gemini khi tạo nội dung.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: VstudyColors.muted,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  FilledButton(
                    key: const ValueKey('ai-library-confirm'),
                    onPressed:
                        _busy || (_selected.isEmpty && !widget.allowEmpty)
                        ? null
                        : _confirm,
                    child: Text(
                      _busy
                          ? 'Đang xử lý…'
                          : widget.createSummary
                          ? 'Tóm tắt tài liệu'
                          : _selected.isEmpty
                          ? 'Hỏi đáp không dùng tài liệu'
                          : 'Dùng tài liệu đã chọn',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
