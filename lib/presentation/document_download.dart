import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../domain/entities.dart';
import 'design_system.dart';
import 'document_widgets.dart';
import 'document_export_stub.dart'
    if (dart.library.io) 'document_export_io.dart'
    as platform;

class DocumentDownloadOptions {
  const DocumentDownloadOptions({
    required this.summary,
    required this.offline,
    required this.favorite,
  });
  final bool summary;
  final bool offline;
  final bool favorite;
}

Future<DocumentDownloadOptions?> chooseDocumentDownload(
  BuildContext context, {
  required StudyDocument document,
  required bool summaryAvailable,
  required bool supportsOffline,
}) {
  var summary = false;
  var offline = supportsOffline;
  var favorite = document.isFavorite;
  return showModalBottomSheet<DocumentDownloadOptions>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VstudyColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (context) => StatefulBuilder(
      builder: (context, change) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  DocumentCover(document: document),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tải tài liệu về máy',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          document.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          documentSize(document.sizeBytes),
                          style: const TextStyle(
                            color: VstudyColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Định dạng & dung lượng',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  !summary
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: VstudyColors.gold,
                ),
                title: Text(
                  document.mimeType == 'application/pdf'
                      ? 'Bản PDF gốc'
                      : 'Bản TXT gốc',
                ),
                subtitle: Text(
                  'Giữ nguyên nội dung · ${documentSize(document.sizeBytes)}',
                ),
                onTap: () => change(() => summary = false),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: summaryAvailable,
                leading: Icon(
                  summary ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: summaryAvailable
                      ? VstudyColors.gold
                      : VstudyColors.muted,
                ),
                title: const Text('Bản tóm tắt Vstudy Ai · TXT'),
                subtitle: Text(
                  summaryAvailable
                      ? 'Nội dung tóm tắt đã tạo từ tài liệu'
                      : 'Tạo tóm tắt trong trang xem tài liệu trước',
                ),
                onTap: summaryAvailable
                    ? () => change(() => summary = true)
                    : null,
              ),
              const Divider(),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Lưu vào Thư viện yêu thích',
                  style: TextStyle(fontSize: 13),
                ),
                value: favorite,
                onChanged: (value) => change(() => favorite = value ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Lưu bản gốc để đọc ngoại tuyến',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  summary
                      ? 'Bản tóm tắt được xuất riêng thành tệp TXT.'
                      : 'Bản lưu nằm trong ứng dụng trên thiết bị này.',
                  style: const TextStyle(fontSize: 11),
                ),
                value: !summary && offline,
                onChanged: supportsOffline && !summary
                    ? (value) => change(() => offline = value ?? false)
                    : null,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const ValueKey('document-confirm-download'),
                style: FilledButton.styleFrom(
                  backgroundColor: VstudyColors.gold,
                  foregroundColor: VstudyColors.navy,
                ),
                onPressed: () => Navigator.pop(
                  context,
                  DocumentDownloadOptions(
                    summary: summary,
                    offline: !summary && offline,
                    favorite: favorite,
                  ),
                ),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Xác nhận tải về'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy bỏ'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Web initiates a browser download but cannot confirm the user saved the file.
Future<bool> exportDocumentFile(String filename, Uint8List bytes) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Lưu tài liệu Vstudy',
    fileName: filename,
    bytes: bytes,
    type: FileType.custom,
    allowedExtensions: [filename.split('.').last],
  );
  if (kIsWeb || path == null) {
    return false;
  }
  await platform.writeExportIfNeeded(path, bytes);
  return true;
}

Future<void> showDocumentDownloaded(
  BuildContext context, {
  required String filename,
  required int bytes,
  required bool offline,
  String? note,
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: const BorderSide(color: VstudyColors.gold),
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF159522), size: 64),
          const SizedBox(height: 18),
          const Text(
            'Tải xuống thành công',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            offline
                ? 'Đã lưu tệp và bản đọc ngoại tuyến trong ứng dụng.'
                : 'Tệp đã được lưu ở vị trí bạn chọn.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          DocumentPanel(
            color: VstudyColors.cream,
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$filename\n${documentSize(bytes)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                note,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: VstudyColors.red),
              ),
            ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Xem tài liệu ngay'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    ),
  ),
);
