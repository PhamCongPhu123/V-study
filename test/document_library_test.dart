import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vstudy/core/app_exception.dart';
import 'package:vstudy/data/native_document_files.dart';
import 'package:vstudy/data/preview_repository.dart';
import 'package:vstudy/domain/entities.dart';

void main() {
  late Directory directory;
  late NativeDocumentFiles files;
  final doc = StudyDocument(
    id: 'document-1',
    title: 'Ghi chú',
    storagePath: 'private/notes.txt',
    mimeType: 'text/plain',
    sizeBytes: 3,
    createdAt: DateTime(2026, 11, 4),
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vstudy-documents-');
    files = NativeDocumentFiles(supportDirectory: () async => directory);
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('offline copies persist and are isolated by account', () async {
    await files.record(
      'account-a',
      doc,
      bytes: Uint8List.fromList([65, 66, 67]),
    );
    final reopened = NativeDocumentFiles(
      supportDirectory: () async => directory,
    );
    expect(await reopened.read('account-a', doc.id), [65, 66, 67]);
    expect((await reopened.list('account-a')).single.offline, isTrue);
    expect(await reopened.read('account-b', doc.id), isNull);
    expect(await reopened.list('account-b'), isEmpty);
    await reopened.record(
      'account-a',
      doc.withLibraryDetails(isFavorite: true),
    );
    expect(
      (await reopened.list('account-a')).single.document.isFavorite,
      isTrue,
    );
    expect(await reopened.read('account-a', doc.id), [65, 66, 67]);
    await reopened.remove('account-a', doc.id);
    expect(await reopened.list('account-a'), isEmpty);
    expect(await reopened.read('account-a', doc.id), isNull);
  });

  test(
    'invalid paths and mismatched bytes do not create saved records',
    () async {
      await expectLater(
        files.record('../other-account', doc),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        files.record('account-a', doc, bytes: Uint8List(1)),
        throwsA(isA<AppException>()),
      );
      expect(await files.list('account-a'), isEmpty);
    },
  );

  test('export-only record does not pretend to have an offline copy', () async {
    await files.record('account-a', doc);
    expect((await files.list('account-a')).single.offline, isFalse);
    expect(await files.read('account-a', doc.id), isNull);
  });

  test(
    'prototype PDFs contain real sample bytes and bookmarks retain subject',
    () async {
      final preview = PreviewRepository();
      final pdf = (await preview.listDocuments()).firstWhere(
        (d) => d.mimeType == 'application/pdf',
      );
      final bytes = await preview.readDocument(pdf);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, pdf.sizeBytes);
      final updated = await preview.updateLibraryDetails(
        pdf.id,
        subjectId: pdf.subjectId,
        isFavorite: !pdf.isFavorite,
      );
      expect(updated.subjectId, pdf.subjectId);
      expect(updated.isFavorite, !pdf.isFavorite);
    },
  );
}
