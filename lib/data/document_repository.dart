import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/app_exception.dart';
import '../domain/entities.dart';
import '../domain/repositories.dart';
import 'data_support.dart';

class SupabaseDocumentRepository extends SupabaseAccess
    implements DocumentRepository {
  const SupabaseDocumentRepository(super.client);
  static const _bucket = 'study-documents';
  static const maxBytes = 10 * 1024 * 1024;

  @override
  Future<Uint8List> readDocument(StudyDocument document) => protect(() async {
    final row = await client
        .from('documents')
        .select()
        .eq('id', document.id)
        .eq('owner_id', ownerId)
        .single();
    final current = documentFromJson(row);
    final path = current.storagePath;
    if (!path.startsWith('$ownerId/${current.id}/') ||
        path.split('/').length != 3 ||
        current.sizeBytes > maxBytes) {
      throw const AppException('Tài liệu không có đường dẫn hợp lệ.');
    }
    final bytes = await client.storage.from(_bucket).download(path);
    if (bytes.isEmpty ||
        bytes.length > maxBytes ||
        bytes.length != current.sizeBytes) {
      throw const AppException(
        'Nội dung tài liệu không khớp hoặc vượt quá 10 MiB.',
      );
    }
    return bytes;
  });

  @override
  Future<StudyDocument> updateLibraryDetails(
    String id, {
    String? subjectId,
    required bool isFavorite,
  }) => protect(() async {
    final row = await client
        .from('documents')
        .update({'subject_id': subjectId, 'is_favorite': isFavorite})
        .eq('id', id)
        .eq('owner_id', ownerId)
        .select()
        .single();
    return documentFromJson(row);
  });

  @override
  Future<List<StudyDocument>> listDocuments() => protect(() async {
    final owner = ownerId;
    final rows = await loadPages(
      (from, to) => client
          .from('documents')
          .select()
          .eq('owner_id', owner)
          .order('created_at', ascending: false)
          .order('id')
          .range(from, to),
    );
    return rows.map(documentFromJson).toList(growable: false);
  });

  @override
  Future<StudyDocument> upload({
    required String title,
    required String filename,
    required String mimeType,
    required Uint8List bytes,
  }) => protect(() async {
    final owner = ownerId;
    if (title.trim().isEmpty || title.trim().length > 200) {
      throw const AppException('Tên tài liệu cần có từ 1 đến 200 ký tự.');
    }
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const AppException('Chọn tài liệu không rỗng, tối đa 10 MiB.');
    }
    if (mimeType != 'application/pdf' && mimeType != 'text/plain') {
      throw const AppException('Chỉ hỗ trợ tài liệu PDF hoặc TXT (UTF-8).');
    }
    if (mimeType == 'application/pdf') {
      if (bytes.length < 5 ||
          ascii.decode(bytes.sublist(0, 5), allowInvalid: true) != '%PDF-') {
        throw const AppException('Nội dung tệp không phải là tài liệu PDF.');
      }
    } else {
      try {
        utf8.decode(bytes);
      } on FormatException {
        throw const AppException('Tài liệu TXT phải sử dụng mã hóa UTF-8.');
      }
    }
    final id = const Uuid().v4();
    final basename = filename.split(RegExp(r'[/\\]')).last;
    var safeName = basename
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceFirst(RegExp(r'^\.+'), '');
    if (safeName.length > 120) {
      safeName = safeName.substring(safeName.length - 120);
    }
    if (safeName.isEmpty) {
      safeName = mimeType == 'application/pdf'
          ? 'document.pdf'
          : 'document.txt';
    }
    final path = '$owner/$id/$safeName';
    final storage = client.storage.from(_bucket);
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: false),
    );
    try {
      final row = await client
          .from('documents')
          .insert({
            'id': id,
            'owner_id': owner,
            'title': title.trim(),
            'storage_path': path,
            'mime_type': mimeType,
            'size_bytes': bytes.length,
          })
          .select()
          .single();
      return documentFromJson(row);
    } on Exception {
      // Never leave an advertised document whose metadata insert failed.
      // Storage and Postgres cannot share a transaction: compensate the upload.
      try {
        await storage.remove([path]);
      } on Exception {
        throw const AppException(
          'Tải tài liệu chưa hoàn tất. Có một tệp chưa gắn dữ liệu cần được dọn trong Storage.',
        );
      }
      rethrow;
    }
  });

  @override
  Future<void> deleteDocument(StudyDocument document) => protect(() async {
    final owner = ownerId;
    // Re-read the authoritative path; never trust a path supplied by a caller.
    final row = await client
        .from('documents')
        .select()
        .eq('id', document.id)
        .eq('owner_id', owner)
        .maybeSingle();
    if (row == null) {
      return;
    }
    final path = row['storage_path'] as String;
    // Delete metadata first: a failed FK/permission check must not erase bytes.
    final deleted = await client
        .from('documents')
        .delete()
        .eq('id', document.id)
        .eq('owner_id', owner)
        .select('id');
    if (deleted.isEmpty) {
      return;
    }
    try {
      await client.storage.from(_bucket).remove([path]);
    } on Exception {
      throw const AppException(
        'Thông tin tài liệu đã được xóa. Tệp còn lại cần được dọn trong Storage.',
      );
    }
  });
}
