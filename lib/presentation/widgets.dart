import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_exception.dart';
import '../domain/entities.dart';

String errorMessage(Object error) => error is AppException
    ? error.message
    : 'Không thể hoàn thành thao tác. Vui lòng thử lại.';

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(errorMessage(error))));
}

String shortDate(DateTime value) =>
    DateFormat('dd/MM/yyyy').format(value.toLocal());
String shortTime(DateTime value) => DateFormat('HH:mm').format(value.toLocal());
String eventKindLabel(EventKind kind) => switch (kind) {
  EventKind.classSession => 'Trên lớp',
  EventKind.selfStudy => 'Tự học',
  EventKind.deadline => 'Deadline',
};
String aiModeLabel(AiMode mode) => switch (mode) {
  AiMode.qa => 'Hỏi đáp',
  AiMode.summary => 'Tóm tắt',
  AiMode.plan => 'Lộ trình',
  AiMode.flashcards => 'Flashcard',
};

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: CircularProgressIndicator(),
    ),
  );
}

class FailureView extends StatelessWidget {
  const FailureView({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(errorMessage(error), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text(message, textAlign: TextAlign.center),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null) action!,
      ],
    ),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860),
      child: ListView(padding: const EdgeInsets.all(20), children: children),
    ),
  );
}

class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    super.key,
    required this.future,
    required this.onRetry,
    required this.builder,
  });
  final Future<T> future;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LoadingView();
      }
      if (snapshot.hasError) {
        return FailureView(error: snapshot.error!, onRetry: onRetry);
      }
      return builder(snapshot.data as T);
    },
  );
}
