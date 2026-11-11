import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/monetization/offline_entitlements.dart';

class FakeVault implements CommerceVault {
  final Map<String, String> files = {};
  String boot = 'boot-one';
  int elapsed = 10000;
  late String key;
  @override
  Future<Map<String, dynamic>> clock() async => {
    'boot': boot,
    'elapsed_ms': elapsed,
  };
  @override
  Future<String?> read(String scope) async => files[scope];
  @override
  Future<void> write(String scope, String value) async {
    files[scope] = value;
  }

  @override
  Future<void> remove(String scope) async {
    files.remove(scope);
  }

  @override
  Future<String> publicKey() async => key;
  @override
  Future<String> signProof(String message) async => throw UnimplementedError();
}

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/commerce_lease_test_vector.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final claims = fixture['claims'] as Map<String, dynamic>;
  final envelope = fixture['envelope'] as Map<String, dynamic>;
  late FakeVault vault;
  late OfflineEntitlements rights;
  OfflineEntitlements make({String environment = 'test'}) {
    final service = OfflineEntitlements(
      vault: vault,
      environment: environment,
      trustedKeys: {
        'sim-rfc8032-test': base64.decode(fixture['public_key_b64'] as String),
      },
    );
    service.bindAccount(
      subject: claims['subject'] as String,
      deviceId: claims['device_id'] as String,
      thumbprint: claims['device_key_thumbprint'] as String,
    );
    return service;
  }

  Future<void> accept([Map<String, dynamic>? value]) async => rights.accept(
    value ?? envelope,
    nonce: claims['nonce'] as String,
    requestClock: await vault.clock(),
  );
  setUp(() {
    vault = FakeVault()..key = fixture['device_public_key_b64'] as String;
    rights = make();
  });

  test(
    'Python signature verifies in Dart; all current learning stays free',
    () async {
      await accept();
      final access = await rights.access();
      expect(access.status, CommerceStatus.active);
      expect(access.canUse('simulation.badge'), isTrue);
      for (final code in freeLearningFeatures) {
        expect(access.canUse(code), isTrue);
      }
      expect(access.adsAllowed, isFalse);
    },
  );
  test(
    'app restart and airplane mode reuse authenticated cache on same boot',
    () async {
      await accept();
      vault.elapsed += 100000;
      rights = make();
      expect((await rights.access()).status, CommerceStatus.active);
    },
  );
  test('expiry at seven days never deletes the local data', () async {
    await accept();
    vault.elapsed += 7 * 86400 * 1000;
    final access = await rights.access();
    expect(access.status, CommerceStatus.expired);
    expect(access.canUse('offline_packs'), isTrue);
    expect(vault.files, isNotEmpty);
  });
  test(
    'civil clock not used; backward monotonic anchor and reboot require network',
    () async {
      await accept();
      vault.elapsed = 1;
      expect(
        (await rights.access()).status,
        CommerceStatus.verificationRequired,
      );
      vault.elapsed = 11000;
      vault.boot = 'new-boot';
      expect(
        (await rights.access()).status,
        CommerceStatus.verificationRequired,
      );
    },
  );
  test('logout and A to B isolation', () async {
    await accept();
    rights.bindAccount(
      subject: 'B',
      deviceId: claims['device_id'],
      thumbprint: claims['device_key_thumbprint'],
    );
    expect((await rights.access()).canUse('simulation.badge'), isFalse);
    rights = make();
    await rights.logout();
    expect((await rights.access()).status, CommerceStatus.free);
    expect(vault.files, isEmpty);
  });
  test(
    'reinstallation/new installation key cannot recover old rights',
    () async {
      await accept();
      vault.key = base64.encode(List.filled(90, 0));
      expect(
        (await rights.access()).status,
        CommerceStatus.verificationRequired,
      );
    },
  );
  test('tampered claims and signatures are refused', () async {
    final changed = {
      ...envelope,
      'payload_b64url': base64Url.encode(utf8.encode('{}')).replaceAll('=', ''),
    };
    await expectLater(accept(changed), throwsFormatException);
    await expectLater(
      accept({...envelope, 'kid': 'untrusted'}),
      throwsFormatException,
    );
    await expectLater(
      accept({...envelope, 'signature_b64url': 'AA'}),
      throwsFormatException,
    );
  });
  test(
    'nonce mismatch, slow network and response replay cannot reanchor expiry',
    () async {
      await expectLater(
        rights.accept(
          envelope,
          nonce: 'stale',
          requestClock: await vault.clock(),
        ),
        throwsFormatException,
      );
      final clock = await vault.clock();
      vault.elapsed += 31000;
      await expectLater(
        rights.accept(envelope, nonce: claims['nonce'], requestClock: clock),
        throwsFormatException,
      );
      await accept();
      await expectLater(accept(), throwsFormatException);
    },
  );
  test('production rejects synthetic keys and leases', () async {
    rights = make(environment: 'production');
    await expectLater(accept(), throwsFormatException);
  });
  test(
    'missing/corrupt commercial cache fails closed, retaining all free features',
    () async {
      expect(
        (await rights.access()).status,
        CommerceStatus.verificationRequired,
      );
      vault.files['test:${claims['subject']}:${claims['device_id']}'] =
          'corrupt';
      final access = await rights.access();
      expect(access.canUse('simulation.badge'), isFalse);
      expect(access.canUse('audio'), isTrue);
    },
  );
  test(
    'server revocation after reconnect removes paid extras, never free data',
    () async {
      await accept();
      final revoked = Map<String, dynamic>.from(fixture['variants']['revoked']);
      await rights.accept(
        revoked,
        nonce: 'revoked-fresh',
        requestClock: await vault.clock(),
      );
      final access = await rights.access();
      expect(access.canUse('simulation.badge'), isFalse);
      expect(access.canUse('progress'), isTrue);
      expect(vault.files, isNotEmpty);
    },
  );
  test(
    'valid signatures cannot bypass maximum TTL, owner, feature allowlist or epoch',
    () async {
      for (final variant in ['too_long', 'unknown_feature', 'wrong_subject']) {
        await expectLater(
          accept(Map<String, dynamic>.from(fixture['variants'][variant])),
          throwsFormatException,
        );
      }
      await accept();
      await expectLater(
        rights.accept(
          Map<String, dynamic>.from(fixture['variants']['stale_epoch']),
          nonce: 'stale-fresh',
          requestClock: await vault.clock(),
        ),
        throwsFormatException,
      );
    },
  );
}
