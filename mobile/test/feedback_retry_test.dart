import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/features/feedback/services/feedback_api_service.dart';
import 'package:mobile/features/feedback/screens/feedback_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';

void main() {
  test(
    'POST 429 retains its retry delay and does not expose the full response body',
    () async {
      final api = ApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'detail': 'Try again', 'internal': 'not-for-display'}),
            429,
            headers: {'retry-after': '25'},
          ),
        ),
      );
      await expectLater(
        api.postMap('/feedback/create/'),
        throwsA(
          isA<ApiRequestException>()
              .having((e) => e.statusCode, 'status', 429)
              .having((e) => e.retryAfterSeconds, 'delay', 25)
              .having(
                (e) => e.toString(),
                'safe detail',
                isNot(contains('not-for-display')),
              ),
        ),
      );
    },
  );

  testWidgets(
    'feedback text survives rate limiting and remains editable for retry',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = FeedbackApiService(
        apiClient: ApiClient(
          client: MockClient((request) async {
            expect(request.headers['Accept-Language'], 'fr');
            return http.Response(
              jsonEncode({'detail': 'Trop d’envois'}),
              429,
              headers: {'retry-after': '25', 'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FeedbackScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Message 𖺡𖺣 à conserver',
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Message 𖺡𖺣 à conserver'), findsOneWidget);
      expect(find.textContaining('25 s'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    },
  );
}
