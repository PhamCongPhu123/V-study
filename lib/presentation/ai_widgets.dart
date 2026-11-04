import 'package:flutter/material.dart';
import '../domain/entities.dart';
import 'design_system.dart';

class AiFrame extends StatelessWidget {
  const AiFrame({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.onBack,
    this.onSparkle,
    this.busy = false,
  });
  final String title;
  final String? subtitle;
  final Widget body;
  final VoidCallback? onBack;
  final VoidCallback? onSparkle;
  final bool busy;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF0D8AA), Color(0xFFF8F6ED), Color(0xFFCFDAF1)],
        stops: [0, .38, 1],
      ),
    ),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 10,
        title: Row(
          children: [
            IconButton(
              key: const ValueKey('ai-back'),
              tooltip: 'Quay lại',
              onPressed: busy
                  ? null
                  : onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: VstudyColors.gold,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 10,
                        color: VstudyColors.muted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filled(
              key: const ValueKey('ai-sparkle'),
              tooltip: 'Công cụ AI',
              style: IconButton.styleFrom(
                backgroundColor: VstudyColors.gold,
                foregroundColor: VstudyColors.navy,
              ),
              onPressed: busy
                  ? null
                  : onSparkle ??
                        onBack ??
                        () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.auto_awesome, size: 20),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: body,
        ),
      ),
    ),
  );
}

class AiPanel extends StatelessWidget {
  const AiPanel({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = 16,
  });
  final Widget child;
  final Color color;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
}

class AiPreviewNote extends StatelessWidget {
  const AiPreviewNote({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    child: Text(
      'Bản mẫu minh họa · Chưa gọi Gemini hoặc phân tích tài liệu.',
      style: TextStyle(fontSize: 10, color: VstudyColors.muted),
      textAlign: TextAlign.center,
    ),
  );
}

class AiDocumentTile extends StatelessWidget {
  const AiDocumentTile({
    super.key,
    required this.document,
    this.selected,
    this.onTap,
  });
  final StudyDocument document;
  final bool? selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        key: ValueKey('ai-document-${document.id}'),
        onTap: onTap,
        leading: Container(
          width: 35,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: VstudyColors.navy,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            document.mimeType == 'application/pdf' ? 'PDF' : 'TXT',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(
          document.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${(document.sizeBytes / 1024).toStringAsFixed(0)} KiB',
          style: const TextStyle(fontSize: 10),
        ),
        trailing: selected == null
            ? null
            : Icon(
                selected! ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: selected! ? VstudyColors.gold : VstudyColors.divider,
              ),
      ),
    ),
  );
}

Future<bool> confirmAiAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Xóa',
}) async {
  var closed = false;
  void close(BuildContext ctx, bool value) {
    if (closed || ModalRoute.of(ctx)?.isCurrent != true) {
      return;
    }
    closed = true;
    Navigator.pop(ctx, value);
  }

  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              key: const ValueKey('ai-dialog-cancel'),
              onPressed: () => close(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              key: const ValueKey('ai-dialog-confirm'),
              onPressed: () => close(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: VstudyColors.red),
              child: Text(confirm),
            ),
          ],
        ),
      ) ==
      true;
}
