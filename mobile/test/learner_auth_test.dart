import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/api_config.dart';
import 'package:mobile/core/auth/learner_auth_service.dart';
import 'package:mobile/core/auth/learner_auth_vault.dart';
import 'package:mobile/features/auth/screens/learner_login_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('login stores session in vault (not SharedPreferences) and ApiClient sends auth headers', () async {
    final vault = InMemoryLearnerAuthVault();
    var cleanupCount = 0;

    final client = MockClient((request) async {
      if (request.url.path.endsWith('/core/auth/csrf/')) {
        return http.Response(
          jsonEncode({'csrf_token': 'csrf-1'}),
          200,
          headers: {'set-cookie': 'csrftoken=csrf-1; Path=/'},
        );
      }
      if (request.url.path.endsWith('/core/auth/login/')) {
        expect(request.headers['X-CSRFToken'], 'csrf-1');
        expect(request.headers['Cookie'], contains('csrftoken=csrf-1'));
        return http.Response(
          jsonEncode({
            'authenticated': true,
            'user_id': 42,
            'username': 'pilot_qa_1',
            'is_pilot': true,
            'is_staff': false,
            'csrf_token': 'csrf-2',
          }),
          200,
          headers: {
            'set-cookie': 'sessionid=sess-abc; HttpOnly; Path=/, csrftoken=csrf-2; Path=/',
          },
        );
      }
      if (request.url.path.endsWith('/learning/units/')) {
        expect(request.headers['Cookie'], contains('sessionid=sess-abc'));
        return http.Response(jsonEncode({'results': [{'slug': 'bk-preprod-erf-01'}]}), 200);
      }
      if (request.url.path.endsWith('/progress/unit-progress/sync/')) {
        expect(request.headers['Cookie'], contains('sessionid=sess-abc'));
        expect(request.headers['X-CSRFToken'], 'csrf-2');
        expect(request.headers['Origin'], Uri.parse(ApiConfig.baseUrl).origin);
        return http.Response(jsonEncode({'synced_count': 1, 'error_count': 0}), 200);
      }
      return http.Response('{}', 404);
    });

    final auth = LearnerAuthService(
      vault: vault,
      client: client,
      cleanupUserData: () async {
        cleanupCount++;
      },
    );

    await auth.login('pilot_qa_1', 'PilotQa2026!');
    expect(auth.isAuthenticated, isTrue);
    expect(auth.username, 'pilot_qa_1');
    expect(auth.isPilot, isTrue);
    expect(cleanupCount, 0);

    // Secrets must be in encrypted vault, never in SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
    expect(await vault.read('learner_session_v1'), contains('sess-abc'));

    final api = ApiClient(client: client, authService: auth);
    final units = await api.getMap('/learning/units/');
    expect((units['results'] as List).first['slug'], 'bk-preprod-erf-01');

    final sync = await api.postMap('/progress/unit-progress/sync/', body: {'items': []});
    expect(sync['synced_count'], 1);

    // Restore from vault in a fresh service instance (offline restart simulation).
    final restored = LearnerAuthService(
      vault: vault,
      client: client,
      cleanupUserData: () async {
        cleanupCount++;
      },
    );
    await restored.restore();
    expect(restored.isAuthenticated, isTrue);
    expect(restored.userId, 42);
    expect(restored.username, 'pilot_qa_1');
  });

  test('offline network error on refreshSession preserves session; 401 expires; 403 does not log out', () async {
    final vault = InMemoryLearnerAuthVault();
    await vault.write(
      'learner_session_v1',
      jsonEncode({
        'user_id': 42,
        'username': 'pilot_qa_1',
        'is_pilot': true,
        'is_staff': false,
        'csrf': 'csrf-2',
        'cookies': {'sessionid': 'sess-abc', 'csrftoken': 'csrf-2'},
      }),
    );

    final offlineClient = MockClient((_) async {
      throw const SocketException('Offline');
    });
    final auth = LearnerAuthService(
      vault: vault,
      client: offlineClient,
      cleanupUserData: () async {},
    );
    await auth.restore();
    await auth.refreshSession();
    expect(auth.isAuthenticated, isTrue);
    expect(auth.isExpired, isFalse);

    // 403 must throw ApiRequestException(403) without logging out.
    final forbiddenClient = MockClient((_) async => http.Response('{"detail":"Forbidden"}', 403));
    final apiForbidden = ApiClient(client: forbiddenClient, authService: auth);
    await expectLater(
      apiForbidden.getMap('/learning/units/999/'),
      throwsA(isA<ApiRequestException>().having((e) => e.statusCode, 'statusCode', 403)),
    );
    expect(auth.isAuthenticated, isTrue);

    // 401 must transition to expired and clear vault.
    final unauthClient = MockClient((_) async => http.Response('{"detail":"Unauthorized"}', 401));
    final apiUnauth = ApiClient(client: unauthClient, authService: auth);
    await expectLater(
      apiUnauth.getMap('/learning/units/'),
      throwsA(isA<ApiRequestException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
    expect(auth.isAuthenticated, isFalse);
    expect(auth.isExpired, isTrue);
    expect(await vault.read('learner_session_v1'), isNull);
  });

  test('logout and account switch trigger local data cleanup', () async {
    final vault = InMemoryLearnerAuthVault();
    var cleanupCount = 0;
    var activeUserId = 42;

    final client = MockClient((request) async {
      if (request.url.path.endsWith('/core/auth/csrf/')) {
        return http.Response(
          jsonEncode({'csrf_token': 'csrf-1'}),
          200,
          headers: {'set-cookie': 'csrftoken=csrf-1; Path=/'},
        );
      }
      if (request.url.path.endsWith('/core/auth/login/')) {
        return http.Response(
          jsonEncode({
            'authenticated': true,
            'user_id': activeUserId,
            'username': activeUserId == 42 ? 'pilot_qa_1' : 'ordinary_qa_2',
            'is_pilot': activeUserId == 42,
            'is_staff': false,
            'csrf_token': 'csrf-2',
          }),
          200,
          headers: {'set-cookie': 'sessionid=sess-$activeUserId; Path=/, csrftoken=csrf-2; Path=/'},
        );
      }
      if (request.url.path.endsWith('/core/auth/logout/')) {
        return http.Response(jsonEncode({'signed_out': true}), 200);
      }
      return http.Response('{}', 404);
    });

    final auth = LearnerAuthService(
      vault: vault,
      client: client,
      cleanupUserData: () async {
        cleanupCount++;
      },
    );

    await auth.login('pilot_qa_1', 'pass1');
    expect(cleanupCount, 0);

    activeUserId = 99;
    await auth.login('ordinary_qa_2', 'pass2');
    expect(cleanupCount, 1);

    await auth.logout();
    expect(cleanupCount, 2);
    expect(auth.isAuthenticated, isFalse);
    expect(await vault.read('learner_session_v1'), isNull);
  });

  testWidgets('LearnerLoginScreen validates input, shows 401 error, and pops on success', (tester) async {
    final vault = InMemoryLearnerAuthVault();
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/core/auth/csrf/')) {
        return http.Response(
          jsonEncode({'csrf_token': 'csrf-1'}),
          200,
          headers: {'set-cookie': 'csrftoken=csrf-1; Path=/'},
        );
      }
      if (request.url.path.endsWith('/core/auth/login/')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['password'] != 'PilotQa2026!') {
          return http.Response(jsonEncode({'detail': 'Invalid credentials'}), 401);
        }
        return http.Response(
          jsonEncode({
            'authenticated': true,
            'user_id': 42,
            'username': 'pilot_qa_1',
            'is_pilot': true,
            'is_staff': false,
            'csrf_token': 'csrf-2',
          }),
          200,
          headers: {'set-cookie': 'sessionid=sess-42; Path=/, csrftoken=csrf-2; Path=/'},
        );
      }
      return http.Response('{}', 404);
    });

    final auth = LearnerAuthService(
      vault: vault,
      client: client,
      cleanupUserData: () async {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LearnerLoginScreen(
                      authService: auth,
                      refreshContentOnLogin: false,
                    ),
                  ),
                );
              },
              child: const Text('Open Login'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Login'));
    await tester.pumpAndSettle();

    // Empty submit shows validation error
    await tester.tap(find.byKey(const Key('learner-login-submit')));
    await tester.pump();
    expect(find.byKey(const Key('learner-login-error')), findsOneWidget);

    // Wrong password shows 401 error
    await tester.enterText(find.byKey(const Key('learner-username')), 'pilot_qa_1');
    await tester.enterText(find.byKey(const Key('learner-password')), 'wrong');
    await tester.tap(find.byKey(const Key('learner-login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Identifiant ou mot de passe incorrect.'), findsOneWidget);

    // Correct password succeeds and pops back
    await tester.enterText(find.byKey(const Key('learner-password')), 'PilotQa2026!');
    await tester.tap(find.byKey(const Key('learner-login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Open Login'), findsOneWidget);
    expect(auth.isAuthenticated, isTrue);
  });
}
