import 'dart:typed_data';
import '../domain/document_files.dart';
import '../domain/entities.dart';

DocumentFiles createDocumentFiles() => MemoryDocumentFiles();

class MemoryDocumentFiles implements DocumentFiles {
  final _records = <String, Map<String, SavedDocument>>{};
  final _bytes = <String, Map<String, Uint8List>>{};
  @override
  bool get supportsOffline => false;
  @override
  Future<List<SavedDocument>> list(String owner) async =>
      (_records[owner]?.values.toList() ?? <SavedDocument>[])
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  @override
  Future<Uint8List?> read(String owner, String id) async => _bytes[owner]?[id];
  @override
  Future<void> record(
    String owner,
    StudyDocument document, {
    Uint8List? bytes,
  }) async {
    if (bytes != null) {
      (_bytes[owner] ??= {})[document.id] = Uint8List.fromList(bytes);
    }
    (_records[owner] ??= {})[document.id] = SavedDocument(
      document: document,
      savedAt: DateTime.now(),
      offline: false,
    );
  }

  @override
  Future<void> remove(String owner, String id) async {
    _records[owner]?.remove(id);
    _bytes[owner]?.remove(id);
  }
}
