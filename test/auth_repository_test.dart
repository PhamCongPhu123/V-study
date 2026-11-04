import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vstudy/core/app_exception.dart';
import 'package:vstudy/data/auth_repository.dart';
import 'package:vstudy/data/auth_callback_coordinator.dart';
import 'package:vstudy/domain/auth_failure.dart';
import 'package:vstudy/domain/auth_validation.dart';

class _Storage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

class _CallbackAuth extends SupabaseAuthRepository {
  _CallbackAuth(SupabaseClient client)
    : super(client, redirectUrl: 'io.vstudy.app://login-callback/');
  final received = <Uri>[];
  int errors = 0;
  @override
  Future<void> handleCallback(Uri uri) async {
    received.add(uri);
  }

  @override
  void reportCallbackFailure() {
    errors++;
  }
}

void main() {
  const callback = 'io.vstudy.app://login-callback/';
  const owner = '11111111-1111-4111-8111-111111111111';
  Map<String, dynamic> user() => {
    'id': owner,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'an@example.com',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'created_at': '2026-01-01T00:00:00Z',
  };
  String jwt() {
    String part(Map<String, dynamic> value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': owner, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.test-signature';
  }

  Map<String, dynamic> session() => {
    'access_token': jwt(),
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'test-refresh-token',
    'user': user(),
  };

  test(
    'shared validation preserves password spaces while rejecting malformed input',
    () {
      expect(AuthValidation.email(' an@example.com '), isNull);
      expect(AuthValidation.email('wrong'), isNotNull);
      expect(AuthValidation.password('old', newPassword: false), isNull);
      expect(AuthValidation.password('short', newPassword: true), isNotNull);
      expect(AuthValidation.password('        ', newPassword: true), isNotNull);
      expect(
        AuthValidation.password(' secure password ', newPassword: true),
        isNull,
      );
      expect(
        AuthValidation.confirmation('different', 'password123'),
        isNotNull,
      );
    },
  );

  test('known legacy auth responses produce useful safe messages', () {
    expect(
      authErrorMessage(const AuthException('Invalid login credentials')),
      contains('Email hoặc mật khẩu không đúng'),
    );
    expect(
      authErrorMessage(const AuthException('Invalid API key')),
      contains('cấu hình Supabase'),
    );
    expect(
      authErrorMessage(
        AuthRetryableFetchException(
          message: '{"msg":"Error sending confirmation email"}',
          statusCode: '500',
        ),
      ),
      contains('Không gửi được email xác nhận'),
    );
    expect(
      authErrorMessage(const AuthException('private provider detail')),
      isNot(contains('private provider detail')),
    );
  });

  group('Supabase auth transport', () {
    late HttpServer server;
    late SupabaseClient client;
    late SupabaseAuthRepository repository;
    late _Storage storage;
    late List<({String method, Uri uri, Map<String, dynamic>? body})> calls;
    String? failure;
    String? legacyMessage;
    var signupIssuesSession = false;
    var failureStatus = HttpStatus.badRequest;
    setUp(() async {
      failure = null;
      legacyMessage = null;
      signupIssuesSession = false;
      failureStatus = HttpStatus.badRequest;
      calls = [];
      storage = _Storage();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final text = await utf8.decoder.bind(request).join();
        final body = text.isEmpty
            ? null
            : jsonDecode(text) as Map<String, dynamic>;
        calls.add((method: request.method, uri: request.uri, body: body));
        request.response.headers.contentType = ContentType.json;
        if (legacyMessage != null) {
          request.response.statusCode = failureStatus;
          request.response.write(jsonEncode({'msg': legacyMessage}));
        } else if (failure != null) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write(
            jsonEncode({
              'code': failure,
              'error_code': failure,
              'msg': 'private provider detail',
            }),
          );
        } else if (request.uri.pathSegments.last == 'token') {
          request.response.write(jsonEncode(session()));
        } else if (request.uri.pathSegments.last == 'signup' &&
            signupIssuesSession) {
          request.response.write(jsonEncode(session()));
        } else if (request.uri.pathSegments.last == 'signup' ||
            request.uri.pathSegments.last == 'user') {
          request.response.write(jsonEncode(user()));
        } else {
          request.response.write('{}');
        }
        await request.response.close();
      });
      client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test-public-key',
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.pkce,
          pkceAsyncStorage: storage,
        ),
      );
      repository = SupabaseAuthRepository(client, redirectUrl: callback);
    });
    tearDown(() async {
      await repository.dispose();
      await client.dispose();
      await server.close(force: true);
    });

    test(
      'email signup sends name and redirect but waits when no session is issued',
      () async {
        final result = await repository.signUp(
          'Nguyễn An',
          'an@example.com',
          ' secure password ',
        );
        expect(result.needsEmailConfirmation, isTrue);
        expect(repository.currentUser, isNull);
        final call = calls.single;
        expect(call.uri.pathSegments.last, 'signup');
        expect(call.uri.queryParameters['redirect_to'], callback);
        expect(call.body!['data'], {'display_name': 'Nguyễn An'});
        expect(call.body!['password'], ' secure password ');
        expect(call.body!['code_challenge_method'], 's256');
      },
    );
    test(
      'password login keeps the exact password and obtains a real SDK session',
      () async {
        await repository.signIn('an@example.com', ' secure password ');
        expect(repository.currentUser!.id, owner);
        expect(calls.single.uri.queryParameters['grant_type'], 'password');
        expect(calls.single.body!['password'], ' secure password ');
      },
    );
    test(
      'signup without email confirmation waits for explicit password login',
      () async {
        signupIssuesSession = true;
        final users = <Object?>[];
        final subscription = repository.userChanges.listen(users.add);
        addTearDown(subscription.cancel);
        final result = await repository.signUp(
          'An',
          'an@example.com',
          'password123',
        );
        await Future<void>.delayed(Duration.zero);
        expect(result.needsEmailConfirmation, isFalse);
        expect(repository.currentUser, isNull);
        expect(users.where((user) => user != null), isEmpty);
        await repository.signIn('an@example.com', 'password123');
        expect(repository.currentUser!.id, owner);
      },
    );
    test('unconfirmed email becomes a typed, safe domain failure', () async {
      failure = 'email_not_confirmed';
      await expectLater(
        repository.signIn('an@example.com', 'password123'),
        throwsA(
          isA<AuthFailure>()
              .having(
                (error) => error.reason,
                'reason',
                AuthFailureReason.unconfirmedEmail,
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('private provider detail')),
              ),
        ),
      );
      expect(repository.currentUser, isNull);
    });
    test(
      'legacy unconfirmed-email response still allows confirmation resend',
      () async {
        legacyMessage = 'Email not confirmed';
        await expectLater(
          repository.signIn('an@example.com', 'password123'),
          throwsA(
            isA<AuthFailure>().having(
              (error) => error.reason,
              'reason',
              AuthFailureReason.unconfirmedEmail,
            ),
          ),
        );
        expect(repository.currentUser, isNull);
      },
    );
    test(
      'signup database failure is reported safely without a session',
      () async {
        legacyMessage = 'Database error saving new user';
        failureStatus = HttpStatus.internalServerError;
        await expectLater(
          repository.signUp('An', 'an@example.com', 'password123'),
          throwsA(
            isA<AuthFailure>()
                .having(
                  (error) => error.reason,
                  'reason',
                  AuthFailureReason.unavailable,
                )
                .having(
                  (error) => error.message,
                  'message',
                  contains('Không thể tạo tài khoản'),
                ),
          ),
        );
        expect(repository.currentUser, isNull);
      },
    );
    test(
      'confirmation resend uses signup OTP and the configured callback',
      () async {
        await repository.resendConfirmation('an@example.com');
        expect(calls.single.uri.pathSegments.last, 'resend');
        expect(calls.single.body!['type'], 'signup');
        expect(calls.single.uri.queryParameters['redirect_to'], callback);
      },
    );
    test(
      'reset email establishes PKCE but does not create an authenticated session',
      () async {
        await repository.requestPasswordReset('an@example.com');
        expect(calls.single.uri.pathSegments.last, 'recover');
        expect(calls.single.body!['email'], 'an@example.com');
        expect(calls.single.body!['code_challenge_method'], 's256');
        expect(repository.currentUser, isNull);
        expect(repository.isPasswordRecovery, isFalse);
      },
    );
    test(
      'recovery received before UI listeners is retained and clears after password completion',
      () async {
        await repository.requestPasswordReset('an@example.com');
        await repository.handleCallback(
          Uri.parse('${callback}?code=test-recovery-code'),
        );
        await Future<void>.delayed(Duration.zero);
        expect(repository.isPasswordRecovery, isTrue);
        expect(repository.currentUser!.id, owner);
        await repository.updatePassword('new password123');
        final update = calls.singleWhere((call) => call.method == 'PUT');
        expect(update.body!['password'], 'new password123');
        expect(repository.isPasswordRecovery, isTrue);
        repository.completePasswordRecovery();
        expect(repository.isPasswordRecovery, isFalse);
      },
    );
    test(
      'a broken callback becomes a one-time safe notice without exposing its URI',
      () async {
        await repository.handleCallback(
          Uri.parse(
            '${callback}?error=access_denied&error_description=private-sensitive-value',
          ),
        );
        final notice = repository.takePendingAuthNotice();
        expect(notice, isNotNull);
        expect(notice, isNot(contains('private-sensitive-value')));
        expect(repository.takePendingAuthNotice(), isNull);
      },
    );
    test('unknown provider failures never expose SDK error details', () async {
      failure = 'unexpected_provider_error';
      await expectLater(
        repository.signIn('an@example.com', 'password123'),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'message',
            isNot(contains('private provider detail')),
          ),
        ),
      );
    });
  });

  group('callback coordination', () {
    late SupabaseClient client;
    late _CallbackAuth auth;
    late StreamController<Uri> links;
    late AuthCallbackCoordinator coordinator;
    setUp(() {
      client = SupabaseClient(
        'https://unused.example',
        'test-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      auth = _CallbackAuth(client);
      links = StreamController<Uri>.broadcast();
      coordinator = AuthCallbackCoordinator(
        auth: auth,
        redirectUrl: callback,
        links: links.stream,
        initialLink: () async => Uri.parse('${callback}?code=initial'),
      );
    });
    tearDown(() async {
      await coordinator.dispose();
      await links.close();
      await auth.dispose();
      await client.dispose();
    });
    test(
      'only configured origin/path and authentication parameters are accepted',
      () {
        expect(coordinator.accepts(Uri.parse('${callback}?code=a')), isTrue);
        for (final uri in [
          'https://evil.example/?code=a',
          'io.vstudy.app://other/?code=a',
          '${callback}other?code=a',
          '${callback}?page=home',
          'io.vstudy.app://user@login-callback/?code=a',
        ]) {
          expect(coordinator.accepts(Uri.parse(uri)), isFalse);
        }
      },
    );
    test(
      'initial and stream copies of the same callback are exchanged only once',
      () async {
        await coordinator.start();
        links.add(Uri.parse('${callback}?code=initial'));
        links.add(Uri.parse('https://evil.example/?code=foreign'));
        links.add(Uri.parse('${callback}?code=second'));
        await Future<void>.delayed(Duration.zero);
        expect(auth.received.map((uri) => uri.queryParameters['code']), [
          'initial',
          'second',
        ]);
      },
    );
    test(
      'stream errors are sanitized and disposal stops future callbacks',
      () async {
        await coordinator.start();
        links.addError(StateError('private platform details'));
        await Future<void>.delayed(Duration.zero);
        expect(auth.errors, 1);
        await coordinator.dispose();
        final count = auth.received.length;
        links.add(Uri.parse('${callback}?code=after-dispose'));
        await Future<void>.delayed(Duration.zero);
        expect(auth.received.length, count);
      },
    );
  });
}
