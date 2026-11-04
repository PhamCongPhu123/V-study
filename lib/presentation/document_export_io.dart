import 'dart:io';
import 'dart:typed_data';

Future<void> writeExportIfNeeded(String path, Uint8List bytes) async {
  // Mobile save dialogs write the bytes themselves; desktop dialogs return
  // only the selected path and require the application to write it.
  if (!Platform.isAndroid && !Platform.isIOS) {
    await File(path).writeAsBytes(bytes, flush: true);
  }
}
