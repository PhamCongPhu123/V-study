import '../domain/document_files.dart';
import 'memory_document_files.dart'
    if (dart.library.io) 'native_document_files.dart'
    as platform;

DocumentFiles createDocumentFiles() => platform.createDocumentFiles();
