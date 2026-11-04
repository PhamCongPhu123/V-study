import 'package:flutter/material.dart';

typedef DraftLeaveHandler = Future<bool> Function();

/// A feature route registers its exit check with the persistent footer.
class DraftExitScope extends InheritedWidget {
  const DraftExitScope({super.key, required this.attach, required super.child});
  final VoidCallback Function(DraftLeaveHandler) attach;
  static DraftExitScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DraftExitScope>();
  @override
  bool updateShouldNotify(DraftExitScope oldWidget) =>
      attach != oldWidget.attach;
}
