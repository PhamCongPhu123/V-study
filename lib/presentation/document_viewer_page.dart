import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:uuid/uuid.dart';
import '../core/app_exception.dart';
import '../domain/ai_workspace.dart';
import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'ai_artifact_pages.dart';
import 'ai_conversation_page.dart';
import 'design_system.dart';
import 'document_download.dart';
import 'document_widgets.dart';
import 'widgets.dart';

class DocumentViewerPage extends StatefulWidget {
  const DocumentViewerPage({
    super.key,
    required this.useCases,
    required this.document,
    this.preview = false,
    this.downloadOnOpen = false,
  });
  final VstudyUseCases useCases;
  final StudyDocument document;
  final bool preview;
  final bool downloadOnOpen;
  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  late StudyDocument _document;
  late Future<Uint8List> _future;
  late final String _owner;
  final _summaryRequest = const Uuid().v4();
  AiArtifact? _summary;
  PDFViewController? _controller;
  int _page = 0;
  int _pages = 0;
  bool _busy = false;
  bool _fromOffline = false;
  String? _pdfError;
  @override
  void initState() {
    super.initState();
    _document = widget.document;
    _owner = widget.useCases.auth.currentUser?.id ?? 'preview';
    _future = _load();
    if (widget.downloadOnOpen) {
      _future.then((bytes) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _download(bytes);
          }
        });
      }, onError: (Object _, StackTrace __) {});
    }
  }

  Future<Uint8List> _load() async {
    try {
      final bytes = await widget.useCases.documentFiles?.read(
        _owner,
        _document.id,
      );
      if (bytes != null && bytes.isNotEmpty) {
        _fromOffline = true;
        return bytes;
      }
    } catch (_) {
      // An unavailable local copy should still allow a fresh Storage read.
    }
    _fromOffline = false;
    return widget.useCases.documents
        .readDocument(_document)
        .timeout(const Duration(seconds: 30));
  }

  Future<void> _favorite() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final updated = await widget.useCases.documents.updateLibraryDetails(
        _document.id,
        subjectId: _document.subjectId,
        isFavorite: !_document.isFavorite,
      );
      if (mounted) {
        setState(() => _document = updated);
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

  Future<void> _createSummary() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final title = 'Tóm tắt ${_document.title}';
      final artifact = await widget.useCases.createAiMaterial(
        AiMaterialRequest(
          requestId: _summaryRequest,
          kind: AiArtifactKind.summary,
          title: title.length > 200 ? title.substring(0, 200) : title,
          documentIds: [_document.id],
        ),
      );
      if (artifact.summary == null) {
        throw const AppException('Chưa nhận được nội dung tóm tắt.');
      }
      if (mounted) {
        setState(() => _summary = artifact);
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

  String _filename(bool summary) {
    var name = _document.title
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
        .trim();
    name = name.replaceFirst(RegExp(r'\.(pdf|txt)$', caseSensitive: false), '');
    if (name.runes.length > 60) {
      name = String.fromCharCodes(name.runes.take(60));
    }
    if (name.isEmpty) {
      name = 'Vstudy';
    }
    return summary
        ? '$name-tom-tat.txt'
        : '$name.${_document.mimeType == 'application/pdf' ? 'pdf' : 'txt'}';
  }

  Future<void> _download(Uint8List original) async {
    if (_busy) {
      return;
    }
    final options = await chooseDocumentDownload(
      context,
      document: _document,
      summaryAvailable: _summary?.summary != null,
      supportsOffline: widget.useCases.documentFiles?.supportsOffline ?? false,
    );
    if (options == null || !mounted || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = options.summary
          ? Uint8List.fromList(utf8.encode(_summary!.summary!.text))
          : original;
      final filename = _filename(options.summary);
      final saved = await exportDocumentFile(filename, bytes);
      if (!saved) {
        if (mounted && kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã gửi yêu cầu tải xuống trình duyệt.'),
            ),
          );
        }
        return;
      }
      var offline = false;
      String? note;
      if (mounted && options.favorite != _document.isFavorite) {
        try {
          _document = await widget.useCases.documents.updateLibraryDetails(
            _document.id,
            subjectId: _document.subjectId,
            isFavorite: options.favorite,
          );
        } catch (_) {
          note =
              '${note == null ? '' : '$note\n'}Chưa cập nhật được yêu thích. Bạn có thể thử lại bằng biểu tượng đánh dấu.';
        }
      }
      if (!options.summary) {
        try {
          final files = widget.useCases.documentFiles;
          if (files != null) {
            await files.record(
              _owner,
              _document,
              bytes: options.offline ? original : null,
            );
            offline = options.offline && files.supportsOffline;
          }
        } catch (_) {
          note =
              '${note == null ? '' : '$note\n'}Đã xuất tệp nhưng chưa lưu được bản ngoại tuyến trong ứng dụng.';
        }
      }
      if (mounted) {
        setState(() {});
        await showDocumentDownloaded(
          context,
          filename: filename,
          bytes: bytes.length,
          offline: offline,
          note: note,
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

  Future<void> _goToPage(int page) async {
    try {
      await _controller?.setPage(page);
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  Widget _reader(Uint8List bytes) {
    if (_document.mimeType == 'text/plain') {
      return ColoredBox(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: SelectableText(
            utf8.decode(bytes, allowMalformed: true),
            style: const TextStyle(fontSize: 14, height: 1.7),
          ),
        ),
      );
    }
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      return const DocumentPanel(
        child: Center(
          child: Text(
            'Tải bản PDF gốc để xem bằng trình đọc trên thiết bị. Xem PDF trong ứng dụng hỗ trợ Android và iOS.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_pdfError != null) {
      return DocumentPanel(
        child: Center(child: Text(_pdfError!, textAlign: TextAlign.center)),
      );
    }
    return PDFView(
      pdfData: bytes,
      preventLinkNavigation: true,
      fitPolicy: FitPolicy.WIDTH,
      enableSwipe: true,
      autoSpacing: true,
      pageFling: true,
      onViewCreated: (controller) => _controller = controller,
      onRender: (pages) {
        if (mounted) {
          setState(() => _pages = pages ?? 0);
        }
      },
      onPageChanged: (page, pages) {
        if (mounted) {
          setState(() {
            _page = page ?? 0;
            _pages = pages ?? _pages;
          });
        }
      },
      onError: (_) {
        if (mounted) {
          setState(
            () => _pdfError =
                'Không mở được PDF. Tệp có thể được bảo vệ hoặc không hợp lệ. Bạn vẫn có thể tải bản gốc.',
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      centerTitle: true,
      title: const Column(
        children: [
          Text(
            'Xem tài liệu',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          Text(
            'Kho kiến thức của Vstudy',
            style: TextStyle(fontSize: 10, color: VstudyColors.muted),
          ),
        ],
      ),
      actions: [
        IconButton(
          key: const ValueKey('document-favorite'),
          tooltip: 'Yêu thích',
          onPressed: _busy ? null : _favorite,
          icon: Icon(
            _document.isFavorite ? Icons.bookmark : Icons.bookmark_border,
            color: VstudyColors.gold,
          ),
        ),
      ],
    ),
    body: AsyncContent<Uint8List>(
      future: _future,
      onRetry: () => setState(() {
        _pdfError = null;
        _future = _load();
      }),
      builder: (bytes) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 84),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DocumentPanel(
              color: VstudyColors.paleGold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _document.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${documentSize(bytes.length)}${_fromOffline ? ' · Bản ngoại tuyến' : ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      if (_pages > 0) ...[
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: _page > 0
                              ? () => _goToPage(_page - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          '${_page + 1}/$_pages',
                          style: const TextStyle(fontSize: 11),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: _page + 1 < _pages
                              ? () => _goToPage(_page + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ],
                  ),
                  if (widget.preview)
                    const Text(
                      'Nội dung minh họa',
                      style: TextStyle(fontSize: 10, color: VstudyColors.muted),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _reader(bytes),
              ),
            ),
            const SizedBox(height: 12),
            DocumentPanel(
              color: VstudyColors.navy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: VstudyColors.gold,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Vstudy Ai',
                          style: TextStyle(
                            color: VstudyColors.gold,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('document-summary'),
                        onPressed: _busy
                            ? null
                            : _summary == null
                            ? _createSummary
                            : () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => AiSummaryPage(
                                    useCases: widget.useCases,
                                    artifact: _summary!,
                                    preview: widget.preview,
                                  ),
                                ),
                              ),
                        child: Text(
                          _summary == null ? 'Tóm tắt' : 'Xem tóm tắt',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Hỏi về tài liệu',
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => AiConversationPage(
                                    useCases: widget.useCases,
                                    document: _document,
                                    preview: widget.preview,
                                  ),
                                ),
                              ),
                        icon: const Icon(
                          Icons.question_answer_outlined,
                          size: 18,
                          color: VstudyColors.gold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _busy
                        ? 'Đang xử lý…'
                        : _summary?.summary?.brief.firstOrNull ??
                              'Chọn Tóm tắt để tạo ý chính từ tài liệu. Tài liệu được gửi đến Vstudy Ai khi bạn yêu cầu.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('document-download'),
              style: FilledButton.styleFrom(
                backgroundColor: VstudyColors.gold,
                foregroundColor: VstudyColors.navy,
              ),
              onPressed: _busy ? null : () => _download(bytes),
              icon: const Icon(Icons.download_outlined),
              label: Text(
                _busy
                    ? 'Đang xử lý…'
                    : 'Tải xuống (${documentSize(bytes.length)})',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
