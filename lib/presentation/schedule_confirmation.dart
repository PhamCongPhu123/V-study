import 'package:flutter/material.dart';
import 'design_system.dart';

enum ScheduleConfirmationKind { create, update, delete, discard }

/// Confirmation only: mutations are performed by the caller after true.
Future<bool> showScheduleConfirmation(
  BuildContext context, {
  required ScheduleConfirmationKind kind,
  String? title,
  String? details,
}) async {
  final destructive =
      kind == ScheduleConfirmationKind.delete ||
      kind == ScheduleConfirmationKind.discard;
  final heading = switch (kind) {
    ScheduleConfirmationKind.create => 'Xác nhận lịch',
    ScheduleConfirmationKind.update => 'Xác nhận thay đổi',
    ScheduleConfirmationKind.delete ||
    ScheduleConfirmationKind.discard => 'Xác nhận xóa',
  };
  final question = switch (kind) {
    ScheduleConfirmationKind.create => 'Bạn có chắc muốn thêm lịch này?',
    ScheduleConfirmationKind.update => 'Bạn có chắc muốn lưu thay đổi?',
    ScheduleConfirmationKind.delete => 'Bạn có chắc muốn xóa lịch này?',
    ScheduleConfirmationKind.discard =>
      'Các nội dung chưa lưu sẽ bị xóa. Bạn có muốn tiếp tục?',
  };
  var decided = false;
  void choose(BuildContext dialogContext, bool value) {
    // The dialog remains painted during its closing animation. A second tap
    // must not pop the route beneath it.
    if (decided || ModalRoute.of(dialogContext)?.isCurrent != true) {
      return;
    }
    decided = true;
    Navigator.pop(dialogContext, value);
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        heading,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: VstudyColors.navy,
        ),
      ),
      content: SizedBox(
        width: 250,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              question,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFAD8517),
                height: 1.5,
              ),
            ),
            if (title != null && title.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: VstudyColors.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (details != null && details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                details,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: VstudyColors.muted,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      actions: [
        OutlinedButton(
          key: const ValueKey('schedule-dialog-cancel'),
          onPressed: () => choose(dialogContext, false),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(86, 36),
            side: const BorderSide(color: VstudyColors.navy),
            shape: const StadiumBorder(),
          ),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: const ValueKey('schedule-dialog-confirm'),
          onPressed: () => choose(dialogContext, true),
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? VstudyColors.red : VstudyColors.navy,
            minimumSize: const Size(86, 36),
            shape: const StadiumBorder(),
          ),
          child: Text(
            destructive
                ? 'Xóa'
                : kind == ScheduleConfirmationKind.create
                ? 'Thêm'
                : 'Lưu',
          ),
        ),
      ],
    ),
  );
  return result == true;
}
