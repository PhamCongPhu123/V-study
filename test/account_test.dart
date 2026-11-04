import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vstudy/core/app_exception.dart';
import 'package:vstudy/data/account_repository.dart';
import 'package:vstudy/data/data_support.dart';
import 'package:vstudy/data/preview_repository.dart';
import 'package:vstudy/domain/entities.dart';

class _RecordingAccount extends PreviewRepository {
  int calls = 0;
  @override
  Future<void> saveAccount(AccountDraft draft) async {
    calls++;
    await super.saveAccount(draft);
  }
}

class _OwnerAccount extends SupabaseAccountRepository {
  const _OwnerAccount(super.client);
  @override
  String get ownerId => 'owner';
}

void main() {
  test(
    'account saves normalized details and goal edits preserve extra profile fields',
    () async {
      final repository = _RecordingAccount();
      await repository.useCases.saveAccountPreferences(
        const AccountPreferences(darkProfile: true, studyReminders: false),
      );
      await repository.useCases.saveAccount(
        AccountDraft(
          displayName: '  Nguyễn An  ',
          dailyGoalMinutes: 120,
          className: '  CNTT1 ',
          major: '  Thiết kế  ',
          birthDate: DateTime(2004, 6, 15),
          avatarKey: 'book',
        ),
      );
      await repository.useCases.updateProfile(
        displayName: 'An mới',
        dailyGoalMinutes: 150,
      );
      final profile = await repository.getProfile();
      expect(profile.id, 'preview-user');
      expect(profile.displayName, 'An mới');
      expect(profile.className, 'CNTT1');
      expect(profile.major, 'Thiết kế');
      expect(profile.birthDate, DateTime(2004, 6, 15));
      expect(profile.avatarKey, 'book');
      expect(profile.dailyGoalMinutes, 150);
      expect(profile.preferences.darkProfile, isTrue);
      expect(profile.preferences.studyReminders, isFalse);
      expect(repository.calls, 1);
    },
  );

  test(
    'account validation rejects invalid data before the repository is called',
    () async {
      final repository = _RecordingAccount();
      final drafts = [
        const AccountDraft(displayName: '   ', dailyGoalMinutes: 120),
        AccountDraft(
          displayName: List.filled(101, 'x').join(),
          dailyGoalMinutes: 120,
        ),
        AccountDraft(
          displayName: 'An',
          dailyGoalMinutes: 120,
          className: List.filled(81, 'x').join(),
        ),
        AccountDraft(
          displayName: 'An',
          dailyGoalMinutes: 120,
          major: List.filled(121, 'x').join(),
        ),
        const AccountDraft(displayName: 'An', dailyGoalMinutes: 0),
        const AccountDraft(displayName: 'An', dailyGoalMinutes: 1441),
        const AccountDraft(
          displayName: 'An',
          dailyGoalMinutes: 120,
          avatarKey: 'https://photo.example/1',
        ),
        AccountDraft(
          displayName: 'An',
          dailyGoalMinutes: 120,
          birthDate: DateTime(2026, 11, 5),
        ),
        AccountDraft(
          displayName: 'An',
          dailyGoalMinutes: 120,
          birthDate: DateTime(1899, 12, 31),
        ),
        AccountDraft(
          displayName: 'An',
          dailyGoalMinutes: 120,
          birthDate: DateTime(2004, 6, 15, 1),
        ),
      ];
      for (final draft in drafts) {
        expect(
          () => repository.useCases.saveAccount(
            draft,
            now: DateTime(2026, 11, 4, 12),
          ),
          throwsA(isA<AppException>()),
        );
      }
      expect(repository.calls, 0);
    },
  );

  test('birth date is a calendar value and can be cleared', () async {
    final repository = _RecordingAccount();
    await repository.useCases.saveAccount(
      AccountDraft(
        displayName: 'An',
        dailyGoalMinutes: 120,
        birthDate: DateTime.utc(2026, 11, 4),
      ),
      now: DateTime(2026, 11, 4, 12),
    );
    expect((await repository.getProfile()).birthDate?.day, 4);
    await repository.useCases.saveAccount(
      const AccountDraft(displayName: 'An', dailyGoalMinutes: 120),
    );
    expect((await repository.getProfile()).birthDate, isNull);
  });

  test('profile mapper supports profiles created before account migration', () {
    final profile = profileFromJson({
      'id': 'owner',
      'display_name': 'An',
      'daily_goal_minutes': 90,
      'timezone': 'Asia/Ho_Chi_Minh',
    });
    expect(profile.avatarKey, 'student');
    expect(profile.className, isEmpty);
    expect(profile.birthDate, isNull);
    expect(profile.preferences.darkProfile, isFalse);
    expect(profile.preferences.studyReminders, isTrue);
  });

  group('account adapter HTTP contract', () {
    late HttpServer server;
    late SupabaseClient client;
    late _OwnerAccount repository;
    late List<({Uri uri, Map<String, dynamic> body})> requests;
    var missing = false;
    setUp(() async {
      requests = [];
      missing = false;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        requests.add((
          uri: request.uri,
          body:
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>,
        ));
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            missing
                ? []
                : [
                    {'id': 'owner'},
                  ],
          ),
        );
        await request.response.close();
      });
      client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      repository = _OwnerAccount(client);
    });
    tearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    test(
      'details use owner filter, return affected row and exclude Auth/preferences',
      () async {
        await repository.saveAccount(
          AccountDraft(
            displayName: ' An ',
            dailyGoalMinutes: 90,
            className: ' CNTT1 ',
            major: ' Thiết kế ',
            birthDate: DateTime(2004, 6, 15),
            avatarKey: 'flower',
          ),
        );
        expect(requests.single.uri.queryParameters['id'], 'eq.owner');
        expect(requests.single.uri.queryParameters['select'], 'id');
        expect(requests.single.body, {
          'display_name': 'An',
          'daily_goal_minutes': 90,
          'class_name': 'CNTT1',
          'major': 'Thiết kế',
          'birth_date': '2004-06-15',
          'avatar_key': 'flower',
        });
      },
    );
    test('preferences update only the two preference columns', () async {
      await repository.saveAccountPreferences(
        const AccountPreferences(darkProfile: true, studyReminders: false),
      );
      expect(requests.single.body, {
        'dark_profile': true,
        'study_reminders': false,
      });
      expect(requests.single.uri.queryParameters['id'], 'eq.owner');
    });
    test('missing or invisible account does not report success', () async {
      missing = true;
      await expectLater(
        repository.saveAccountPreferences(const AccountPreferences()),
        throwsA(isA<AppException>()),
      );
    });
    test('signed-out account changes never issue an HTTP request', () async {
      final signedOut = SupabaseAccountRepository(client);
      await expectLater(
        signedOut.saveAccountPreferences(const AccountPreferences()),
        throwsA(isA<AppException>()),
      );
      expect(requests, isEmpty);
    });
  });
}
