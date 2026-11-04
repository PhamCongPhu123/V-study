import 'package:flutter/material.dart';

typedef ScheduleLeaveHandler = Future<bool> Function();

/// Registers a draft-exit check with the persistent navigation shell.
class ScheduleExitScope extends InheritedWidget {
  const ScheduleExitScope({
    super.key,
    required this.attach,
    required super.child,
  });
  final VoidCallback Function(ScheduleLeaveHandler) attach;
  static ScheduleExitScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ScheduleExitScope>();
  @override
  bool updateShouldNotify(ScheduleExitScope oldWidget) =>
      attach != oldWidget.attach;
}
