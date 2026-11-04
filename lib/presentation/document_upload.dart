import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../core/app_exception.dart';
import '../domain/entities.dart';
import '../domain/use_cases.dart';

/// The picker is shared by the document library and AI tools. Bytes are bounded
/// while reading, before passing them to the repository.
Future<StudyDocument?> pickAndUploadStudyDocument(
  VstudyUseCases useCases,
) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'txt'],
    withData: false,
    withReadStream: true,
  );
  if (result == null || result.files.isEmpty) {
    return null;
  }
  final file = result.files.single;
  const max = 10 * 1024 * 1024;
  if (file.size > max) {
    throw const AppException('Tài liệu tối đa 10 MiB.');
  }
  final extension = file.extension?.toLowerCase();
  if (extension != 'pdf' && extension != 'txt') {
    throw const AppException('Chỉ hỗ trợ PDF và TXT.');
  }
  final builder = BytesBuilder(copy: false);
  var received = 0;
  if (file.readStream != null) {
    await for (final chunk in file.readStream!) {
      received += chunk.length;
      if (received > max) {
        throw const AppException('Tài liệu tối đa 10 MiB.');
      }
      builder.add(chunk);
    }
  } else {
    final bytes = file.bytes;
    if (bytes == null) {
      throw const AppException('Không đọc được tài liệu đã chọn.');
    }
    if (bytes.length > max) {
      throw const AppException('Tài liệu tối đa 10 MiB.');
    }
    builder.add(bytes);
  }
  return useCases.uploadDocument(
    title: file.name,
    filename: file.name,
    mimeType: extension == 'pdf' ? 'application/pdf' : 'text/plain',
    bytes: builder.takeBytes(),
  );
}
