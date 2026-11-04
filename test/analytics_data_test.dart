import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vstudy/core/app_exception.dart';
import 'package:vstudy/data/analytics_repository.dart';
import 'package:vstudy/data/preview_repository.dart';
import 'package:vstudy/domain/analytics.dart';

void main() {
  group('preview analytics', () {
    test(
      'six-month history is seeded once and snapshots exclude future logs',
      () async {
        final now = DateTime.now();
        final repository = PreviewRepository(now: now);
        final first = await repository.loadSnapshot(now: now);
        final second = await repository.loadSnapshot(now: now);
        expect(first.studySessions.length, greaterThan(100));
        final oldest = first.studySessions
            .map((s) => s.startedAt)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        expect(now.difference(oldest).inDays, greaterThanOrEqualTo(175));
        expect(second.studySessions.length, first.studySessions.length);
        expect(second.focusSessions.length, first.focusSessions.length);
        expect(second.flashcardSessions.length, first.flashcardSessions.length);
        expect(first.quizAttempts.length, 4);
        expect(
          first.focusSessions.every(
            (s) => !s.startedAt
                .add(Duration(minutes: s.plannedMinutes))
                .isAfter(now),
          ),
          isTrue,
        );

        final past = now.subtract(const Duration(days: 30));
        final historical = await repository.loadSnapshot(now: past);
        expect(
          historical.studySessions.every((s) => !s.startedAt.isAfter(past)),
          isTrue,
        );
        expect(
          historical.flashcardSessions.every(
            (s) => !s.reviewedAt.isAfter(past),
          ),
          isTrue,
        );
        expect(
          historical.chapterMastery.every((c) => c.answeredQuestions == 0),
          isTrue,
        );
      },
    );

    test(
      'goals and review logs persist without counting focus as study time',
      () async {
        final now = DateTime.now();
        final repository = PreviewRepository(now: now);
        final before = await repository.loadSnapshot(now: now);
        final beforeReport = buildAnalyticsReport(before, AnalyticsPeriod.week);
        final goals = LearningGoals(
          weeklyMinutes: 720,
          studyDaysPerWeek: 4,
          flashcardsPerDay: 25,
          semesterStart: DateTime(now.year, 8),
          semesterEnd: DateTime(now.year + 1, 2),
        );
        await repository.useCases.saveLearningGoals(goals);
        await repository.useCases.logFocusSession(
          startedAt: now.subtract(const Duration(minutes: 60)),
          plannedMinutes: 30,
          focusedMinutes: 24,
          interruptions: 2,
          subjectId: 'math',
        );
        await repository.useCases.logFlashcardSession(
          reviewedAt: now.subtract(const Duration(minutes: 2)),
          reviewedCards: 11,
          rememberedCards: 8,
          subjectId: 'math',
        );
        final after = await repository.loadSnapshot(now: now);
        final report = buildAnalyticsReport(after, AnalyticsPeriod.week);
        expect(after.goals.weeklyMinutes, 720);
        expect(after.goals.studyDaysPerWeek, 4);
        expect(after.goals.flashcardsPerDay, 25);
        expect(after.studySessions.length, before.studySessions.length);
        expect(report.study.totalMinutes, beforeReport.study.totalMinutes);
        expect(after.focusSessions.length, before.focusSessions.length + 1);
        expect(
          after.flashcardSessions.length,
          before.flashcardSessions.length + 1,
        );
        expect(after.flashcardSessions.last.reviewedCards, 11);
        expect(after.flashcardSessions.last.rememberedCards, 8);
      },
    );

    test(
      'chapter mastery follows latest actual practice answers and timeout responses',
      () async {
        final now = DateTime.now().subtract(const Duration(minutes: 1));
        final repository = PreviewRepository(now: now);
        final wrong = (await repository.listWrongAnswers(
          subjectId: 'philosophy',
        )).first;
        final initial = await repository.loadSnapshot(now: now);
        final chapter = initial.chapterMastery.singleWhere(
          (c) => c.id == wrong.chapterId,
        );
        expect(chapter.totalQuestions, 10);
        await repository.checkPracticeAnswer(
          quizId: wrong.quizId,
          questionId: wrong.question.id,
          selectedOption: wrong.correctOption,
        );
        final corrected = await repository.loadSnapshot(now: DateTime.now());
        expect(
          corrected.chapterMastery
              .singleWhere((c) => c.id == chapter.id)
              .correctQuestions,
          chapter.correctQuestions + 1,
        );
        // Submitting an empty timed-out exam is a later response for each
        // question; unanswered questions are neither answered nor mastered.
        await repository.submit(
          quizId: wrong.quizId,
          attemptId: 'analytics-timeout',
          answers: const {},
          allowUnanswered: true,
          mode: 'exam',
        );
        final timedOut = await repository.loadSnapshot(now: DateTime.now());
        final mastery = timedOut.chapterMastery.singleWhere(
          (c) => c.id == chapter.id,
        );
        expect(mastery.answeredQuestions, 0);
        expect(mastery.correctQuestions, 0);
        final historical = await repository.loadSnapshot(now: initial.now);
        expect(
          historical.chapterMastery
              .singleWhere((c) => c.id == chapter.id)
              .correctQuestions,
          chapter.correctQuestions,
        );
      },
    );

    test(
      'preview rejects unknown subjects and impossible recorded counts',
      () async {
        final repository = PreviewRepository();
        await expectLater(
          repository.logFlashcardSession(
            reviewedAt: DateTime.now(),
            reviewedCards: 10,
            rememberedCards: 11,
          ),
          throwsA(isA<AppException>()),
        );
        await expectLater(
          repository.logFocusSession(
            startedAt: DateTime.now().subtract(const Duration(hours: 1)),
            plannedMinutes: 25,
            focusedMinutes: 20,
            interruptions: 1,
            subjectId: 'another-owner-subject',
          ),
          throwsA(isA<AppException>()),
        );
      },
    );
  });

  group('Supabase analytics transport', () {
    late HttpServer server;
    late SupabaseClient client;
    late _OwnerAnalyticsRepository repository;
    late List<({String method, Uri uri, dynamic body})> requests;
    late bool failGoals;

    setUp(() async {
      requests = [];
      failGoals = false;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final text = await utf8.decoder.bind(request).join();
        requests.add((
          method: request.method,
          uri: request.uri,
          body: text.isEmpty ? null : jsonDecode(text),
        ));
        request.response.headers.contentType = ContentType.json;
        final table = request.uri.pathSegments.last;
        if (request.method != 'GET' && table != 'get_chapter_mastery') {
          request.response.statusCode = HttpStatus.created;
          request.response.write('null');
        } else if (table == 'study_goals' && failGoals) {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write(
            jsonEncode({'code': '42P01', 'message': 'missing table'}),
          );
        } else {
          final offset = int.parse(
            request.uri.queryParameters['offset'] ?? '0',
          );
          final limit = int.parse(
            request.uri.queryParameters['limit'] ?? '500',
          );
          final rows = switch (table) {
            'profiles' => {
              'id': 'owner',
              'display_name': 'Learner',
              'daily_goal_minutes': 180,
              'timezone': 'Asia/Ho_Chi_Minh',
            },
            'study_sessions' => [
              for (var i = offset; i < 501 && i < offset + limit; i++)
                {
                  'id': 'session-$i',
                  'started_at': '2026-11-03T13:00:00Z',
                  'duration_minutes': 25,
                  'subject_id': 'subject',
                },
            ],
            'focus_sessions' => [
              {
                'id': 'focus',
                'subject_id': 'subject',
                'started_at': '2026-11-03T13:00:00Z',
                'planned_minutes': 25,
                'focused_minutes': 20,
                'interruptions': 1,
              },
            ],
            'flashcard_sessions' => [
              {
                'id': 'flash',
                'subject_id': 'subject',
                'reviewed_at': '2026-11-03T13:30:00Z',
                'reviewed_cards': 20,
                'remembered_cards': 16,
              },
            ],
            'study_events' => [
              {
                'id': 'event',
                'subject_id': 'subject',
                'starts_at': '2026-11-03T12:00:00Z',
                'event_tasks': [
                  {'is_completed': true},
                  {'is_completed': false},
                ],
              },
            ],
            'get_chapter_mastery' => [
              for (var i = offset; i < 501 && i < offset + limit; i++)
                {
                  'id': 'chapter-$i',
                  'subject_id': 'subject',
                  'title': 'Chapter $i',
                  'position': i,
                  'total_questions': 10,
                  'answered_questions': 5,
                  'correct_questions': 4,
                },
            ],
            _ => <Map<String, dynamic>>[],
          };
          request.response.write(jsonEncode(rows));
        }
        await request.response.close();
      });
      client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'public-test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      repository = _OwnerAnalyticsRepository(client);
    });

    tearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    test(
      'history and aggregate RPC paginate with owner filters and local timestamps',
      () async {
        final now = DateTime.utc(2026, 11, 4, 12);
        final snapshot = await repository.loadSnapshot(now: now);
        expect(snapshot.studySessions.length, 501);
        expect(snapshot.chapterMastery.length, 501);
        expect(snapshot.studySessions.last.id, 'session-500');
        expect(snapshot.chapterMastery.last.id, 'chapter-500');
        expect(snapshot.focusSessions.single.startedAt.isUtc, isFalse);
        expect(
          snapshot.flashcardSessions.single.reviewedAt,
          DateTime.utc(2026, 11, 3, 13, 30).toLocal(),
        );
        expect(snapshot.tasks.map((task) => task.completed), [true, false]);
        expect(
          snapshot.goals.weeklyMinutes,
          LearningGoals.defaults(now).weeklyMinutes,
        );
        for (final request in requests) {
          final table = request.uri.pathSegments.last;
          if (table == 'profiles') {
            expect(request.uri.queryParameters['id'], 'eq.owner');
          } else if (table == 'get_chapter_mastery') {
            expect((request.body as Map)['p_until'], now.toIso8601String());
          } else {
            expect(request.uri.queryParameters['owner_id'], 'eq.owner');
          }
        }
        final attemptRead = requests.singleWhere(
          (r) => r.uri.pathSegments.last == 'quiz_attempts',
        );
        expect(
          attemptRead.uri.queryParameters['select'],
          isNot(contains('answers')),
        );
        expect(
          attemptRead.uri.queryParameters['submitted_at'],
          'lte.${now.toIso8601String()}',
        );
      },
    );

    test(
      'writes use calendar goal dates and UTC activity without duplicate study writes',
      () async {
        await repository.saveGoals(
          LearningGoals(
            weeklyMinutes: 600,
            studyDaysPerWeek: 4,
            flashcardsPerDay: 30,
            semesterStart: DateTime(2026, 8),
            semesterEnd: DateTime(2027, 2),
          ),
        );
        final started = DateTime(2026, 11, 3, 21);
        await repository.logFocusSession(
          startedAt: started,
          plannedMinutes: 25,
          focusedMinutes: 20,
          interruptions: 1,
          subjectId: 'subject',
        );
        await repository.logFlashcardSession(
          reviewedAt: started,
          reviewedCards: 20,
          rememberedCards: 16,
          subjectId: 'subject',
        );
        expect(requests.length, 3);
        final goals = requests.first.body as Map;
        expect(goals['owner_id'], 'owner');
        expect(goals['semester_start'], '2026-08-01');
        expect(goals['semester_end'], '2027-02-01');
        expect(
          (requests[1].body as Map)['started_at'],
          started.toUtc().toIso8601String(),
        );
        expect(
          (requests[2].body as Map)['reviewed_at'],
          started.toUtc().toIso8601String(),
        );
        expect(
          requests.any((r) => r.uri.pathSegments.last == 'study_sessions'),
          isFalse,
        );
      },
    );

    test(
      'missing migration fails instead of silently showing invented activity',
      () async {
        failGoals = true;
        await expectLater(
          repository.loadSnapshot(now: DateTime.now()),
          throwsA(isA<AppException>()),
        );
      },
    );
  });
}

class _OwnerAnalyticsRepository extends SupabaseAnalyticsRepository {
  const _OwnerAnalyticsRepository(super.client);
  @override
  String get ownerId => 'owner';
}
