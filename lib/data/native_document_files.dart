import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../core/app_exception.dart';
import '../domain/document_files.dart';
import '../domain/entities.dart';
import 'data_support.dart';

DocumentFiles createDocumentFiles() => NativeDocumentFiles();

class NativeDocumentFiles implements DocumentFiles {
  NativeDocumentFiles({Future<Directory> Function()? supportDirectory})
    : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _supportDirectory;
  @override
  bool get supportsOffline => true;
  String _safe(String value) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(value)) {
      throw const AppException('Không xác định được tài khoản hoặc tài liệu.');
    }
    return value;
  }

  Future<Directory> _directory(String owner) async {
    final root = await _supportDirectory();
    return Directory(
      '${root.path}/vstudy_documents/${_safe(owner)}',
    ).create(recursive: true);
  }

  Future<File> _file(String owner, String id, String extension) async =>
      File('${(await _directory(owner)).path}/${_safe(id)}.$extension');
  @override
  Future<List<SavedDocument>> list(String owner) async {
    final directory = await _directory(owner);
    final result = <SavedDocument>[];
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File || !entry.path.endsWith('.json')) {
        continue;
      }
      try {
        final row =
            jsonDecode(await entry.readAsString()) as Map<String, dynamic>;
        final doc = documentFromJson(row);
        final expected = await _file(owner, doc.id, 'json');
        if (expected.path != entry.path) {
          continue;
        }
        result.add(
          SavedDocument(
            document: doc,
            savedAt: DateTime.parse(row['saved_at'] as String).toLocal(),
            offline: await (await _file(owner, doc.id, 'bin')).exists(),
          ),
        );
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      } on AppException {
        continue;
      }
    }
    return result..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  @override
  Future<Uint8List?> read(String owner, String id) async {
    final file = await _file(owner, id, 'bin');
    if (!await file.exists()) {
      return null;
    }
    if (await file.length() > 10 * 1024 * 1024) {
      throw const AppException('Bản lưu vượt quá 10 MiB. Vui lòng tải lại.');
    }
    return file.readAsBytes();
  }

  @override
  Future<void> record(
    String owner,
    StudyDocument document, {
    Uint8List? bytes,
  }) async {
    if (bytes != null) {
      if (bytes.isEmpty ||
          bytes.length > 10 * 1024 * 1024 ||
          bytes.length != document.sizeBytes) {
        throw const AppException('Tài liệu tối đa 10 MiB.');
      }
      final target = await _file(owner, document.id, 'bin');
      final temp = File('${target.path}.part');
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(target.path);
    }
    final metadata = await _file(owner, document.id, 'json');
    final temp = File('${metadata.path}.part');
    await temp.writeAsString(
      jsonEncode({
        'id': document.id,
        'title': document.title,
        'storage_path': document.storagePath,
        'mime_type': document.mimeType,
        'size_bytes': document.sizeBytes,
        'created_at': document.createdAt.toUtc().toIso8601String(),
        'subject_id': document.subjectId,
        'is_favorite': document.isFavorite,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      }),
      flush: true,
    );
    await temp.rename(metadata.path);
  }

  @override
  Future<void> remove(String owner, String id) async {
    for (final extension in ['json', 'bin']) {
      final file = await _file(owner, id, extension);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
