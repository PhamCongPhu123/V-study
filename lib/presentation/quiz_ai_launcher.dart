import 'package:flutter/material.dart';

class QuizAiLauncher extends InheritedWidget {
  const QuizAiLauncher({super.key, required this.onOpen, required super.child});
  final ValueChanged<String?> onOpen;
  static void open(BuildContext context, {String? prompt}) {
    final scope = context.getInheritedWidgetOfExactType<QuizAiLauncher>();
    if (scope != null) {
      scope.onOpen(prompt);
    }
  }

  @override
  bool updateShouldNotify(QuizAiLauncher oldWidget) =>
      onOpen != oldWidget.onOpen;
}
