import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/monetization/commerce_client.dart';
import 'package:mobile/core/monetization/offline_entitlements.dart';
import 'commerce_offline_test.dart' show FakeVault;

void main() {
  for (final status in [401, 403, 503]) {
    test(
      'HTTP $status does not discard a provable offline lease or local learning',
      () async {
        final vector = jsonDecode(
          File(
            'test/fixtures/commerce_lease_test_vector.json',
          ).readAsStringSync(),
        );
        final claims = vector['claims'];
        final vault = FakeVault()..key = vector['device_public_key_b64'];
        final rights = OfflineEntitlements(
          vault: vault,
          environment: 'test',
          trustedKeys: {
            'sim-rfc8032-test': base64.decode(vector['public_key_b64']),
          },
        );
        rights.bindAccount(
          subject: claims['subject'],
          deviceId: claims['device_id'],
          thumbprint: claims['device_key_thumbprint'],
        );
        await rights.accept(
          Map<String, dynamic>.from(vector['envelope']),
          nonce: claims['nonce'],
          requestClock: await vault.clock(),
        );
        var calls = 0;
        final api = ApiClient(
          client: MockClient((request) async {
            calls++;
            expect(
              request.url.path,
              endsWith('/monetization/v1/me/device-keys/challenge/'),
            );
            expect(request.headers['Cookie'], 'sessionid=synthetic');
            return http.Response(
              '{"detail":"simulated refusal"}',
              status,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        final client = CommerceClient(
          api: api,
          rights: rights,
          authenticatedHeaders: () async => {
            'Cookie': 'sessionid=synthetic',
            'X-CSRFToken': 'synthetic',
          },
        );
        await expectLater(
          client.enrollAndRefresh(),
          throwsA(isA<ApiRequestException>()),
        );
        expect(calls, 1);
        expect((await rights.access()).status, CommerceStatus.active);
        expect((await rights.access()).canUse('srs'), isTrue);
        await client.logout();
        expect((await rights.access()).status, CommerceStatus.free);
      },
    );
  }
}
