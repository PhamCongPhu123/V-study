import 'package:flutter/material.dart';
import '../domain/document_files.dart';
import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'design_system.dart';
import 'document_upload.dart';
import 'document_viewer_page.dart';
import 'document_widgets.dart';
import 'widgets.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({
    super.key,
    required this.useCases,
    this.preview = false,
  });
  final VstudyUseCases useCases;
  final bool preview;
  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _LibraryData {
  const _LibraryData(
    this.documents,
    this.subjects,
    this.saved,
    this.warning,
    this.online,
  );
  final List<StudyDocument> documents;
  final List<Subject> subjects;
  final List<SavedDocument> saved;
  final String? warning;
  final bool online;
}

class _DocumentsPageState extends State<DocumentsPage> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  late Future<_LibraryData> _future;
  late final String _owner;
  bool _busy = false;
  bool _downloadedOnly = false;
  bool _favoritesOnly = false;
  String? _subject;
  String _sort = 'recent';
  @override
  void initState() {
    super.initState();
    _owner = widget.useCases.auth.currentUser?.id ?? 'preview';
    _future = _load();
    _search.addListener(_changed);
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<_LibraryData> _load() async {
    var saved = <SavedDocument>[];
    String? warning;
    try {
      saved = await widget.useCases.documentFiles?.list(_owner) ?? [];
    } catch (_) {
      warning = 'Chưa đọc được danh sách tải xuống trên thiết bị.';
    }
    List<StudyDocument> docs;
    var online = true;
    try {
      docs = await widget.useCases.documents.listDocuments().timeout(
        const Duration(seconds: 12),
      );
    } catch (_) {
      if (saved.isEmpty) {
        rethrow;
      }
      docs = saved.map((entry) => entry.document).toList();
      online = false;
      warning =
          'Chưa kết nối được thư viện. Đang hiển thị tài liệu đã tải trên thiết bị này.';
    }
    var subjects = <Subject>[];
    try {
      if (online) {
        subjects = await widget.useCases.study.listSubjects().timeout(
          const Duration(seconds: 12),
        );
      }
    } catch (_) {
      warning ??=
          'Chưa tải được danh sách môn học. Bạn vẫn có thể xem tài liệu.';
    }
    return _LibraryData(docs, subjects, saved, warning, online);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
  }

  Future<void> _upload() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final doc = await pickAndUploadStudyDocument(widget.useCases);
      if (!mounted || doc == null) {
        return;
      }
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tải tài liệu lên thư viện riêng của bạn.'),
          ),
        );
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

  Future<void> _open(StudyDocument document, {bool download = false}) async {
    if (_busy) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DocumentViewerPage(
          useCases: widget.useCases,
          document: document,
          preview: widget.preview,
          downloadOnOpen: download,
        ),
      ),
    );
    if (mounted) {
      await _refresh();
    }
  }

  Future<void> _favorite(StudyDocument doc) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.useCases.documents.updateLibraryDetails(
        doc.id,
        subjectId: doc.subjectId,
        isFavorite: !doc.isFavorite,
      );
      if (mounted) {
        await _refresh();
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

  Future<void> _changeSubject(StudyDocument doc, List<Subject> subjects) async {
    final id = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Chọn môn học'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Chưa phân môn'),
          ),
          ...subjects.map(
            (s) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, s.id),
              child: Text(s.name),
            ),
          ),
        ],
      ),
    );
    if (id == null || !mounted || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.useCases.documents.updateLibraryDetails(
        doc.id,
        subjectId: id.isEmpty ? null : id,
        isFavorite: doc.isFavorite,
      );
      if (mounted) {
        await _refresh();
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

  Future<void> _delete(StudyDocument doc, {bool localOnly = false}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          localOnly
              ? 'Xóa bản tải trên thiết bị?'
              : 'Xóa tài liệu khỏi thư viện?',
        ),
        content: Text(
          '${doc.title}\n\n${localOnly ? 'Bản trên Supabase vẫn được giữ.' : 'Bản lưu trong ứng dụng cũng được xóa.'} Tệp đã xuất ra thư mục khác không bị xóa.',
        ),
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
    if (confirm != true || !mounted || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (!localOnly) {
        await widget.useCases.documents.deleteDocument(doc);
      }
      await widget.useCases.documentFiles?.remove(_owner, doc.id);
      if (mounted) {
        await _refresh();
      }
    } catch (error) {
      if (mounted) {
        showError(context, error);
        await _refresh();
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _subjectName(StudyDocument doc, List<Subject> subjects) =>
      subjects.where((s) => s.id == doc.subjectId).firstOrNull?.name ??
      (doc.subjectId == null ? 'Chưa phân môn' : 'Môn học');

  List<StudyDocument> _visible(_LibraryData data) {
    final byId = {for (final d in data.documents) d.id: d};
    final source = _downloadedOnly
        ? data.saved.map((entry) => byId[entry.document.id] ?? entry.document)
        : data.documents;
    final query = _search.text.trim().toLowerCase();
    final result = source
        .where(
          (doc) =>
              (!_favoritesOnly || doc.isFavorite) &&
              (_subject == null ||
                  (_subject == ''
                      ? doc.subjectId == null
                      : doc.subjectId == _subject)) &&
              (query.isEmpty ||
                  '${doc.title} ${_subjectName(doc, data.subjects)}'
                      .toLowerCase()
                      .contains(query)),
        )
        .toList();
    result.sort(
      (a, b) => switch (_sort) {
        'title' => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        'size' => a.sizeBytes.compareTo(b.sizeBytes),
        _ => b.createdAt.compareTo(a.createdAt),
      },
    );
    return result;
  }

  Widget _filter(String title, String? value) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: ChoiceChip(
      selected: _subject == value,
      showCheckmark: false,
      selectedColor: VstudyColors.gold,
      backgroundColor: Colors.white,
      side: BorderSide.none,
      label: Text(title, style: const TextStyle(fontSize: 11)),
      onSelected: (_) => setState(() => _subject = value),
    ),
  );

  Widget _tile(StudyDocument doc, _LibraryData data) {
    final saved = data.saved
        .where((entry) => entry.document.id == doc.id)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DocumentPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DocumentCover(document: doc),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _open(doc),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _subjectName(doc, data.subjects),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: VstudyColors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          doc.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${documentSize(doc.sizeBytes)} · ${shortDate(doc.createdAt)}${saved?.offline == true ? ' · Ngoại tuyến' : ''}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: VstudyColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey('document-bookmark-${doc.id}'),
                  tooltip: 'Yêu thích',
                  onPressed: _busy || !data.online
                      ? null
                      : () => _favorite(doc),
                  icon: Icon(
                    doc.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                    color: VstudyColors.gold,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Tùy chọn tài liệu',
                  enabled: !_busy,
                  onSelected: (action) {
                    switch (action) {
                      case 'subject':
                        _changeSubject(doc, data.subjects);
                      case 'delete':
                        _delete(doc);
                      case 'local':
                        _delete(doc, localOnly: true);
                    }
                  },
                  itemBuilder: (_) => [
                    if (data.online)
                      const PopupMenuItem(
                        value: 'subject',
                        child: Text('Phân môn học'),
                      ),
                    if (saved != null)
                      const PopupMenuItem(
                        value: 'local',
                        child: Text('Xóa bản tải trên thiết bị'),
                      ),
                    if (data.online)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Xóa tài liệu'),
                      ),
                  ],
                  icon: const Icon(Icons.more_horiz, size: 20),
                ),
                const Spacer(),
                OutlinedButton(
                  key: ValueKey('document-view-${doc.id}'),
                  onPressed: _busy ? null : () => _open(doc),
                  child: const Text('Xem ngay', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: ValueKey('document-save-${doc.id}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: VstudyColors.gold,
                    foregroundColor: VstudyColors.navy,
                  ),
                  onPressed: _busy ? null : () => _open(doc, download: true),
                  child: const Text('Tải về', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(_LibraryData data) {
    final docs = _visible(data);
    final featured = data.documents.where((d) => d.isFavorite).toList();
    if (featured.isEmpty) {
      featured.addAll(data.documents.take(3));
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 100),
        children: [
          Row(
            children: [
              if (Navigator.of(context).canPop())
                IconButton(
                  tooltip: 'Quay lại',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                ),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tài liệu học tập',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Kho giáo trình & đề thi của bạn',
                      style: TextStyle(fontSize: 11, color: VstudyColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const ValueKey('documents-favorites'),
                tooltip: 'Lọc yêu thích',
                onPressed: () =>
                    setState(() => _favoritesOnly = !_favoritesOnly),
                icon: Icon(
                  _favoritesOnly ? Icons.bookmark : Icons.bookmark_outline,
                  color: VstudyColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('documents-search'),
            controller: _search,
            focusNode: _searchFocus,
            decoration: const InputDecoration(
              hintText: 'Tìm giáo trình, slide, tài liệu…',
              prefixIcon: Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          DocumentPanel(
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
                      const SizedBox(height: 7),
                      const Text(
                        'Chọn tài liệu để đọc, hỏi đáp và tóm tắt cùng Vstudy Ai.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _searchFocus.requestFocus(),
                        style: TextButton.styleFrom(
                          foregroundColor: VstudyColors.gold,
                        ),
                        child: const Text('Chọn tài liệu'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.auto_awesome,
                  color: VstudyColors.gold,
                  size: 36,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  key: const ValueKey('documents-all'),
                  label: const Text(
                    'Tài liệu môn học',
                    style: TextStyle(fontSize: 11),
                  ),
                  selected: !_downloadedOnly,
                  onSelected: (_) => setState(() => _downloadedOnly = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  key: const ValueKey('documents-downloaded'),
                  label: Text(
                    'Đã tải (${data.saved.length})',
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: _downloadedOnly,
                  onSelected: (_) => setState(() => _downloadedOnly = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filter('Tất cả', null),
                ...data.subjects.map((s) => _filter(s.name, s.id)),
                _filter('Chưa phân môn', ''),
              ],
            ),
          ),
          if (widget.preview)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Thư viện minh họa · PDF mẫu không phải giáo trình gốc.',
                style: TextStyle(fontSize: 10, color: VstudyColors.muted),
              ),
            ),
          if (data.warning != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                data.warning!,
                style: const TextStyle(fontSize: 12, color: VstudyColors.red),
              ),
            ),
          if (!_downloadedOnly &&
              !_favoritesOnly &&
              _search.text.isEmpty &&
              _subject == null &&
              featured.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Gợi ý ôn tập',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 164,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: featured.take(4).length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => SizedBox(
                  width: 148,
                  child: InkWell(
                    onTap: () => _open(featured[index]),
                    child: DocumentPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DocumentCover(document: featured[index], large: true),
                          const SizedBox(height: 7),
                          Text(
                            documentSize(featured[index].sizeBytes),
                            style: const TextStyle(
                              fontSize: 10,
                              color: VstudyColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_downloadedOnly ? 'Tài liệu đã tải' : 'Danh mục tài liệu'} (${docs.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Sắp xếp',
                onSelected: (value) => setState(() => _sort = value),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'recent', child: Text('Mới nhất')),
                  PopupMenuItem(value: 'title', child: Text('Tên A–Z')),
                  PopupMenuItem(
                    value: 'size',
                    child: Text('Dung lượng tăng dần'),
                  ),
                ],
                icon: const Icon(Icons.sort, size: 20),
              ),
            ],
          ),
          if (docs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Chưa có tài liệu phù hợp. Thử đổi bộ lọc hoặc tải tệp lên.',
                textAlign: TextAlign.center,
                style: TextStyle(color: VstudyColors.muted),
              ),
            ),
          ...docs.map((doc) => _tile(doc, data)),
          DocumentPanel(
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_upload_outlined,
                  color: VstudyColors.gold,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Thêm tài liệu của bạn\nPDF/TXT tối đa 10 MiB · Thư viện riêng tư',
                    style: TextStyle(fontSize: 11, height: 1.5),
                  ),
                ),
                TextButton(
                  key: const ValueKey('documents-upload'),
                  onPressed: _busy ? null : _upload,
                  child: Text(_busy ? 'Đang tải…' : 'Tải lên'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: AsyncContent<_LibraryData>(
          future: _future,
          onRetry: _refresh,
          builder: _content,
        ),
      ),
    ),
  );
}
