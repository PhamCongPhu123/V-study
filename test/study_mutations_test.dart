import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vstudy/core/app_exception.dart';
import 'package:vstudy/data/study_repository.dart';
import 'package:vstudy/domain/entities.dart';

void main() {
  group('Supabase calendar mutations', () {
    late HttpServer server;
    late SupabaseClient client;
    late SupabaseStudyRepository repository;
    late List<({String method, Uri uri, dynamic body, String? prefer})>
    requests;
    late bool missing;
    late bool forbidden;
    late bool failRead;

    final createdRows = [
      {
        'id': 'event',
        'title': 'Ôn Triết học',
        'kind': 'self_study',
        'starts_at': '2026-11-04T06:00:00Z',
        'ends_at': '2026-11-04T08:00:00Z',
        'subject_id': 'subject',
        'series_id': 'series',
      },
      {
        'id': 'event-next',
        'title': 'Ôn Triết học',
        'kind': 'self_study',
        'starts_at': '2026-11-11T06:00:00Z',
        'ends_at': '2026-11-11T08:00:00Z',
        'subject_id': 'subject',
        'series_id': 'series',
      },
    ];

    final draft = EventDraft(
      title: '  Ôn Triết học  ',
      kind: EventKind.selfStudy,
      startsAt: DateTime.parse('2026-11-04T13:00:00+07:00'),
      endsAt: DateTime.parse('2026-11-04T15:00:00+07:00'),
      subjectId: 'subject',
      location: '  Thư viện  ',
      notes: '  Chương 2  ',
      reminderMinutes: 15,
      taskTitles: const ['Preserve existing checklist'],
    );

    setUp(() async {
      requests = [];
      missing = false;
      forbidden = false;
      failRead = false;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        requests.add((
          method: request.method,
          uri: request.uri,
          body: body.isEmpty ? null : jsonDecode(body),
          prefer: request.headers.value('prefer'),
        ));
        request.response.headers.contentType = ContentType.json;
        if (forbidden) {
          request.response.statusCode = HttpStatus.forbidden;
          request.response.write(
            jsonEncode({'code': '42501', 'message': 'private server detail'}),
          );
        } else if (request.method == 'POST' &&
            request.uri.pathSegments.last == 'create_study_event') {
          request.response.write(jsonEncode(createdRows));
        } else if (request.method == 'GET') {
          if (failRead) {
            request.response.statusCode = HttpStatus.serviceUnavailable;
            request.response.write(
              jsonEncode({'code': '503', 'message': 'temporary read failure'}),
            );
          } else {
            request.response.write(
              jsonEncode([
                for (final row in createdRows)
                  {
                    ...row,
                    'event_tasks': [
                      {
                        'id': 'task-${row['id']}',
                        'title': 'Đọc chương 2',
                        'is_completed': false,
                      },
                    ],
                  },
              ]),
            );
          }
        } else {
          final id = request.uri.queryParameters['id']?.replaceFirst('eq.', '');
          request.response.write(
            jsonEncode(
              missing
                  ? []
                  : [
                      {'id': id},
                    ],
            ),
          );
        }
        await request.response.close();
      });
      client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'public-test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      repository = _OwnerStudyRepository(client);
    });

    tearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    EventDraft recurringDraft() => EventDraft(
      title: draft.title,
      kind: draft.kind,
      startsAt: draft.startsAt,
      endsAt: draft.endsAt,
      subjectId: draft.subjectId,
      taskTitles: const ['  Đọc chương 2  '],
      repeatWeeks: 1,
    );

    test(
      'recurrence creation sends one atomic RPC then loads real checklist IDs',
      () async {
        final events = await repository.createEvent(recurringDraft());
        expect(events.map((event) => event.id), ['event', 'event-next']);
        expect(events.map((event) => event.seriesId), ['series', 'series']);
        expect(events.first.tasks.single.id, 'task-event');
        expect(events.last.tasks.single.id, 'task-event-next');
        expect(
          events.last.startsAt.difference(events.first.startsAt).inDays,
          7,
        );
        final rpc = requests.first;
        expect(rpc.method, 'POST');
        expect(rpc.uri.pathSegments.last, 'create_study_event');
        expect(rpc.body['p_tasks'], ['Đọc chương 2']);
        expect(rpc.body['p_repeat_weeks'], 1);
        expect(rpc.body['p_event']['starts_at'], '2026-11-04T06:00:00.000Z');
        expect(requests.last.uri.queryParameters['owner_id'], 'eq.owner');
        expect(requests.length, 2);
      },
    );

    test(
      'committed creation succeeds when subsequent checklist read fails',
      () async {
        failRead = true;
        final events = await repository.createEvent(recurringDraft());
        expect(events.map((event) => event.id), ['event', 'event-next']);
        expect(events.every((event) => event.tasks.isEmpty), isTrue);
        expect(events.first.startsAt, DateTime.utc(2026, 11, 4, 6).toLocal());
        expect(requests.where((request) => request.method == 'POST').length, 1);
        expect(requests.any((request) => request.method == 'GET'), isTrue);
      },
    );

    test(
      'RPC failure stays a failure rather than returning an invented event',
      () async {
        forbidden = true;
        await expectLater(
          repository.createEvent(recurringDraft()),
          throwsA(isA<AppException>()),
        );
        expect(requests.length, 1);
        expect(requests.single.method, 'POST');
      },
    );

    test(
      'single-occurrence update scopes owner and returns affected row',
      () async {
        await repository.updateEvent('event', draft);
        final request = requests.single;
        expect(request.method, 'PATCH');
        expect(request.uri.pathSegments.last, 'study_events');
        expect(request.uri.queryParameters['id'], 'eq.event');
        expect(request.uri.queryParameters['owner_id'], 'eq.owner');
        expect(request.uri.queryParameters['select'], 'id');
        expect(request.prefer, contains('return=representation'));
        expect(request.body, {
          'title': 'Ôn Triết học',
          'kind': 'self_study',
          'subject_id': 'subject',
          'starts_at': '2026-11-04T06:00:00.000Z',
          'ends_at': '2026-11-04T08:00:00.000Z',
          'location': 'Thư viện',
          'notes': 'Chương 2',
          'reminder_minutes': 15,
        });
        // No task deletion/recreation or series-wide update is sent.
      },
    );

    test(
      'missing or invisible event update fails instead of succeeding',
      () async {
        missing = true;
        await expectLater(
          repository.updateEvent('event', draft),
          throwsA(
            isA<AppException>().having(
              (e) => e.message,
              'message',
              contains('không còn tồn tại'),
            ),
          ),
        );
      },
    );

    test(
      'delete checks the affected occurrence and does not claim a second deletion',
      () async {
        await repository.deleteEvent('event');
        final request = requests.single;
        expect(request.method, 'DELETE');
        expect(request.uri.pathSegments.last, 'study_events');
        expect(request.uri.queryParameters['id'], 'eq.event');
        expect(request.uri.queryParameters['owner_id'], 'eq.owner');
        expect(request.uri.queryParameters['select'], 'id');
        expect(request.prefer, contains('return=representation'));

        missing = true;
        await expectLater(
          repository.deleteEvent('event'),
          throwsA(isA<AppException>()),
        );
        expect(requests.length, 2);
      },
    );

    test(
      'checklist changes preserve task identity and reject missing tasks',
      () async {
        await repository.setTaskCompleted('task', true);
        final request = requests.single;
        expect(request.method, 'PATCH');
        expect(request.uri.pathSegments.last, 'event_tasks');
        expect(request.uri.queryParameters['id'], 'eq.task');
        expect(request.uri.queryParameters['owner_id'], 'eq.owner');
        expect(request.uri.queryParameters['select'], 'id');
        expect(request.body, {'is_completed': true});

        missing = true;
        await expectLater(
          repository.setTaskCompleted('task', false),
          throwsA(isA<AppException>()),
        );
      },
    );

    test(
      'database permission failures stay failures with safe UI text',
      () async {
        forbidden = true;
        await expectLater(
          repository.deleteEvent('event'),
          throwsA(
            isA<AppException>().having(
              (e) => e.message,
              'message',
              'Bạn không có quyền thực hiện thao tác này.',
            ),
          ),
        );
      },
    );

    test('signed-out mutations fail before making a network request', () async {
      final signedOut = SupabaseStudyRepository(client);
      await expectLater(
        signedOut.updateEvent('event', draft),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        signedOut.deleteEvent('event'),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        signedOut.setTaskCompleted('task', true),
        throwsA(isA<AppException>()),
      );
      expect(requests, isEmpty);
    });
  });
}

class _OwnerStudyRepository extends SupabaseStudyRepository {
  const _OwnerStudyRepository(super.client);
  @override
  String get ownerId => 'owner';
}
