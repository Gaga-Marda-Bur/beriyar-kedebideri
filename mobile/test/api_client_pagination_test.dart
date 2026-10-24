import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/api_config.dart';

void main() {
  group('ApiClient Pagination Tests (A10)', () {
    test(
      'getList returns all items across multiple pages when next is present',
      () async {
        final mockClient = MockClient((request) async {
          final uri = request.url;

          if (uri.path.contains('/vocabulary/words/')) {
            final page = uri.queryParameters['page'];
            if (page == null || page == '1') {
              final page1Items = List.generate(
                50,
                (i) => {'id': i + 1, 'beriya_text': 'word_$i'},
              );
              return http.Response(
                jsonEncode({
                  'count': 51,
                  'next': '${ApiConfig.baseUrl}/vocabulary/words/?page=2',
                  'previous': null,
                  'results': page1Items,
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            } else if (page == '2') {
              final page2Items = [
                {'id': 51, 'beriya_text': 'word_50'},
              ];
              return http.Response(
                jsonEncode({
                  'count': 51,
                  'next': null,
                  'previous': '${ApiConfig.baseUrl}/vocabulary/words/?page=1',
                  'results': page2Items,
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
          }

          return http.Response('Not Found', 404);
        });

        final apiClient = ApiClient(client: mockClient);
        final items = await apiClient.getList('/vocabulary/words/');

        expect(items.length, 51);
        expect(items.first['id'], 1);
        expect(items.last['id'], 51);
      },
    );

    test(
      'getList deduplicates items sharing the same ID across pages',
      () async {
        final mockClient = MockClient((request) async {
          final uri = request.url;
          final page = uri.queryParameters['page'];

          if (page == null || page == '1') {
            return http.Response(
              jsonEncode({
                'count': 3,
                'next': '${ApiConfig.baseUrl}/characters/?page=2',
                'results': [
                  {'id': 1, 'symbol': '𖺡'},
                  {'id': 2, 'symbol': '𖺣'},
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else {
            return http.Response(
              jsonEncode({
                'count': 3,
                'next': null,
                'results': [
                  {'id': 2, 'symbol': '𖺣'}, // Doublon
                  {'id': 3, 'symbol': '𖺵'},
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        });

        final apiClient = ApiClient(client: mockClient);
        final items = await apiClient.getList('/characters/');

        expect(items.length, 3);
        expect(items.map((e) => e['id']).toList(), [1, 2, 3]);
      },
    );

    test(
      'getList retains already loaded pages when a subsequent page fails',
      () async {
        final mockClient = MockClient((request) async {
          final uri = request.url;
          final page = uri.queryParameters['page'];

          if (page == null || page == '1') {
            return http.Response(
              jsonEncode({
                'count': 100,
                'next': '${ApiConfig.baseUrl}/items/?page=2',
                'results': [
                  {'id': 1, 'name': 'item_1'},
                  {'id': 2, 'name': 'item_2'},
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else {
            return http.Response('Server Error', 500);
          }
        });

        final apiClient = ApiClient(client: mockClient);
        await expectLater(
          apiClient.getList('/items/'),
          throwsA(
            isA<IncompleteListException>().having(
              (e) => e.items.length,
              'retained items',
              2,
            ),
          ),
        );
      },
    );

    test(
      'getList refuses following next URLs targeting unauthorized foreign domains (SSRF protection)',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'count': 10,
              'next': 'https://evil-attacker.com/steal-data/?page=2',
              'results': [
                {'id': 1, 'name': 'safe_item'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final apiClient = ApiClient(client: mockClient);
        await expectLater(
          apiClient.getList('/safe-items/'),
          throwsA(
            isA<IncompleteListException>().having(
              (e) => e.items.length,
              'retained items',
              1,
            ),
          ),
        );
      },
    );
  });
}
