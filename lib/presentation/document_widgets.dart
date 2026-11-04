import 'package:flutter/material.dart';
import '../domain/entities.dart';
import 'design_system.dart';

String documentSize(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).toStringAsFixed(1)} KB';

class DocumentPanel extends StatelessWidget {
  const DocumentPanel({
    super.key,
    required this.child,
    this.color = Colors.white,
  });
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
}

class DocumentCover extends StatelessWidget {
  const DocumentCover({super.key, required this.document, this.large = false});
  final StudyDocument document;
  final bool large;
  @override
  Widget build(BuildContext context) => Container(
    width: large ? double.infinity : 46,
    height: large ? 108 : 52,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: document.mimeType == 'application/pdf'
          ? VstudyColors.paleGold
          : const Color(0xFFE3EAF7),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: VstudyColors.gold.withValues(alpha: .25)),
    ),
    child: large
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                document.mimeType == 'application/pdf'
                    ? Icons.picture_as_pdf_outlined
                    : Icons.description_outlined,
                size: 24,
              ),
              const Spacer(),
              Text(
                document.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          )
        : Center(
            child: Text(
              document.mimeType == 'application/pdf' ? 'PDF' : 'TXT',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
  );
}
