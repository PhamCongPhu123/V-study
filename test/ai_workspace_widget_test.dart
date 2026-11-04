import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vstudy/core/app_exception.dart';
import 'package:vstudy/data/preview_repository.dart';
import 'package:vstudy/domain/entities.dart';
import 'package:vstudy/presentation/ai_artifact_pages.dart';
import 'package:vstudy/presentation/ai_conversation_page.dart';
import 'package:vstudy/presentation/ai_document_library.dart';
import 'package:vstudy/presentation/ai_page.dart';
import 'package:vstudy/presentation/app.dart';
import 'package:vstudy/presentation/quiz_ai_launcher.dart';
import 'package:vstudy/presentation/quiz_player.dart';

class _AiPreview extends PreviewRepository {
  int sends = 0;
  int sendFailures = 0;
  Completer<void>? sendGate;
  @override
  Future<ChatTurn> send({
    required String message,
    required AiMode mode,
    String? threadId,
    String? documentId,
  }) async {
    sends++;
    if (sendGate != null) {
      await sendGate!.future;
    }
    if (sendFailures > 0) {
      sendFailures--;
      throw const AppException('AI tạm thời chưa phản hồi.');
    }
    return super.send(
      message: message,
      mode: mode,
      threadId: threadId,
      documentId: documentId,
    );
  }
}

void main() {
  late _AiPreview repo;
  setUp(() => repo = _AiPreview());
  Future<void> tap(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    if (target.evaluate().isEmpty) {
      final list = find.byType(ListView).first;
      await tester.scrollUntilVisible(
        target,
        240,
        scrollable: find
            .descendant(of: list, matching: find.byType(Scrollable))
            .first,
        maxScrolls: 20,
      );
    }
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, {double width = 402}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(VstudyApp(useCases: repo.useCases, preview: true));
    await tester.pumpAndSettle();
    await tap(tester, 'open-ai');
  }

  testWidgets(
    'AI tools and source library retain all footer destinations on a narrow screen',
    (tester) async {
      await open(tester, width: 320);
      await tap(tester, 'ai-tool-summary');
      expect(find.byType(AiDocumentLibraryPage), findsOneWidget);
      for (final tab in [
        'calendar',
        'quiz',
        'home',
        'statistics',
        'documents',
      ]) {
        expect(find.byKey(ValueKey('footer-$tab')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'two source summary supports every tab and saves a helpful rating',
    (tester) async {
      await open(tester);
      await tap(tester, 'ai-tool-summary');
      await tap(tester, 'ai-document-demo-calculus-3');
      await tap(tester, 'ai-document-demo-calculus-4');
      await tap(tester, 'ai-library-confirm');
      expect(find.byType(AiSummaryPage), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-summary-brief')), findsOneWidget);
      await tap(tester, 'ai-summary-tab-1');
      expect(find.byKey(const ValueKey('ai-summary-details')), findsOneWidget);
      await tap(tester, 'ai-summary-tab-2');
      expect(find.byKey(const ValueKey('ai-summary-mind-map')), findsOneWidget);
      await tap(tester, 'ai-feedback-up');
      expect((await repo.listArtifacts()).single.feedback, 1);
      expect((await repo.listArtifacts()).single.documentIds, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'AI quiz generator opens a timed official 40 question quiz with hints',
    (tester) async {
      await open(tester);
      await tap(tester, 'ai-tool-quiz');
      await tester.enterText(
        find.byKey(const ValueKey('ai-quiz-topic')),
        'Đạo hàm',
      );
      await tap(tester, 'ai-quiz-count-40');
      await tap(tester, 'ai-quiz-create');
      expect(find.byType(QuizPlayerPage), findsOneWidget);
      expect(find.text('Câu hỏi 1/40'), findsOneWidget);
      expect(find.byKey(const ValueKey('quiz-timer')), findsOneWidget);
      await tap(tester, 'quiz-hint');
      expect(
        find.text(
          'Xác định khái niệm chính rồi loại trừ những phương án không phù hợp.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'mixed question settings open self-study with answer feedback and next question',
    (tester) async {
      await open(tester);
      await tap(tester, 'ai-tool-quiz');
      await tester.enterText(
        find.byKey(const ValueKey('ai-quiz-topic')),
        'Toán',
      );
      await tap(tester, 'ai-quiz-kind-true_false');
      await tap(tester, 'ai-quiz-kind-essay');
      await tap(tester, 'ai-quiz-create');
      expect(find.byType(AiWorksheetPage), findsOneWidget);
      await tap(tester, 'ai-exercise-choice-0');
      await tap(tester, 'ai-exercise-next');
      expect(find.text('Chính xác!'), findsOneWidget);
      await tap(tester, 'ai-exercise-next');
      expect(find.text('Đúng / Sai'), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-exercise-choice-2')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'explicit home send runs once, failure preserves input and retry succeeds',
    (tester) async {
      repo.sendFailures = 1;
      await open(tester);
      await tester.enterText(
        find.byKey(const ValueKey('ai-home-input')),
        'Giải thích giới hạn',
      );
      await tap(tester, 'ai-home-send');
      expect(repo.sends, 1);
      expect(find.text('AI tạm thời chưa phản hồi.'), findsOneWidget);
      expect(find.text('Giải thích giới hạn'), findsOneWidget);
      await tap(tester, 'ai-chat-send');
      expect(repo.sends, 2);
      expect(find.text('Giải thích giới hạn'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('ai-chat-attach')))
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'incoming prompt also preserves an unsent question in the AI home composer',
    (tester) async {
      await open(tester);
      await tester.enterText(
        find.byKey(const ValueKey('ai-home-input')),
        'Bản nháp ở trang công cụ',
      );
      QuizAiLauncher.open(
        tester.element(find.byType(AiPage)),
        prompt: 'Một câu hỏi mới',
      );
      await tester.pumpAndSettle();
      expect(repo.sends, 0);
      await tap(tester, 'ai-back');
      await tap(tester, 'ai-dialog-confirm');
      expect(find.text('Bản nháp ở trang công cụ'), findsOneWidget);
      expect(repo.sends, 0);
    },
  );

  testWidgets(
    'pending chat disables duplicate send and Back until the response arrives',
    (tester) async {
      repo.sendGate = Completer<void>();
      await open(tester);
      await tester.enterText(
        find.byKey(const ValueKey('ai-home-input')),
        'Một câu hỏi',
      );
      await tester.tap(find.byKey(const ValueKey('ai-home-send')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 16));
      expect(repo.sends, 1);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('ai-chat-send')))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(AiConversationPage), findsOneWidget);
      repo.sendGate!.complete();
      await tester.pumpAndSettle();
      expect(repo.sends, 1);
      expect(find.text('Một câu hỏi'), findsOneWidget);
    },
  );

  testWidgets(
    'a prompt from another feature preserves the existing chat draft and is not sent automatically',
    (tester) async {
      await open(tester);
      await tap(tester, 'ai-tool-qa');
      await tap(tester, 'ai-library-confirm');
      await tester.enterText(
        find.byKey(const ValueKey('ai-chat-input')),
        'Bản nháp đang viết',
      );
      final context = tester.element(find.byType(AiConversationPage));
      QuizAiLauncher.open(context, prompt: 'Giải thích câu hỏi mới');
      await tester.pumpAndSettle();
      expect(find.text('Giải thích câu hỏi mới'), findsOneWidget);
      expect(repo.sends, 0);
      await tap(tester, 'ai-back');
      await tap(tester, 'ai-dialog-confirm');
      expect(find.text('Bản nháp đang viết'), findsOneWidget);
      expect(repo.sends, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
