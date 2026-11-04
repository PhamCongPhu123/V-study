import 'dart:typed_data';
import 'entities.dart';

class SavedDocument {
  const SavedDocument({
    required this.document,
    required this.savedAt,
    required this.offline,
  });
  final StudyDocument document;
  final DateTime savedAt;
  final bool offline;
}

/// Local copies are scoped by the account that requested the download.
abstract interface class DocumentFiles {
  bool get supportsOffline;
  Future<List<SavedDocument>> list(String owner);
  Future<Uint8List?> read(String owner, String id);
  Future<void> record(String owner, StudyDocument document, {Uint8List? bytes});
  Future<void> remove(String owner, String id);
}
