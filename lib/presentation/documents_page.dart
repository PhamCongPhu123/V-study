import 'package:flutter/material.dart';
import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'widgets.dart';
import 'document_upload.dart';

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
      final document = await pickAndUploadStudyDocument(widget.useCases);
      if (!mounted || document == null) {
        return;
      }
      _refresh();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã tải tài liệu lên.')));
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
