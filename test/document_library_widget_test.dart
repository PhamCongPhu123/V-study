import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vstudy/data/preview_repository.dart';
import 'package:vstudy/presentation/app.dart';
import 'package:vstudy/presentation/document_viewer_page.dart';

void main() {
  testWidgets('library search opens actual text and favorite updates persist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preview = PreviewRepository();
    await tester.pumpWidget(
      VstudyApp(useCases: preview.useCases, preview: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('footer-documents')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('documents-search')),
      'UX/UI',
    );
    await tester.pumpAndSettle();
    final view = find.byKey(const ValueKey('document-view-reference'));
    if (view.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        view,
        180,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(view);
    await tester.tap(view);
    await tester.pumpAndSettle();
    expect(find.byType(DocumentViewerPage), findsOneWidget);
    expect(
      find.textContaining('Wireframe mô tả cấu trúc màn hình.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('document-favorite')));
    await tester.pumpAndSettle();
    expect(
      (await preview.listDocuments())
          .firstWhere((d) => d.id == 'reference')
          .isFavorite,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
