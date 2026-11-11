import 'dart:convert';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/monetization/offline_entitlements.dart';

// Synthetic harness only, installed as a distinct .qa64b package. No account,
// provider or private server key exists in the shipped application.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('BK_QA_PHASE', defaultValue: 'initial');
  const qa = bool.fromEnvironment('BK_COMMERCE_QA');
  testWidgets('native Keystore, encrypted cache and monotonic boot — $phase', (
    tester,
  ) async {
    expect(
      qa,
      isTrue,
      reason: 'The QA harness must use its separate debug package',
    );
    final vault = AndroidCommerceVault();
    final clock = await vault.clock();
    expect(clock['elapsed_ms'], isNonNegative);
    expect(clock['boot'], isNotNull);
    const subject = '11111111-1111-4111-8111-111111111111';
    const device = '33333333-3333-4333-8333-333333333333';
    Map<String, dynamic> metadata;
    Map<String, dynamic>? envelope;
    if (phase == 'initial') {
      final key = await Ed25519().newKeyPair();
      final public = await key.extractPublicKey();
      final nativeKey = await vault.publicKey();
      final thumb = hashes.sha256.convert(base64.decode(nativeKey)).toString();
      metadata = {'key': base64.encode(public.bytes), 'thumb': thumb};
      await vault.write('native-qa-metadata', jsonEncode(metadata));
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final payload = <String, dynamic>{
        'audience': 'bk-android-simulation',
        'device_id': device,
        'device_key_thumbprint': thumb,
        'entitlement_epoch': 1,
        'environment': 'test',
        'expires_at': now + 7 * 86400,
        'features': ['simulation.badge'],
        'grant_ids': ['44444444-4444-4444-8444-444444444444'],
        'issued_at': now,
        'issuer': 'bk',
        'lease_id': '22222222-2222-4222-8222-222222222222',
        'nonce': 'native-qa',
        'offline_valid_until': now + 7 * 86400,
        'policy_version': 1,
        'server_now': now,
        'starts_at': now,
        'subject': subject,
        'version': 1,
      };
      final bytes = base64Url
          .encode(utf8.encode(jsonEncode(payload)))
          .replaceAll('=', '');
      final signature = await Ed25519().sign(
        utf8.encode('BK-OFFLINE-GRANT/v1\nsim-native-qa\n$bytes'),
        keyPair: key,
      );
      envelope = {
        'version': 1,
        'kid': 'sim-native-qa',
        'payload_b64url': bytes,
        'signature_b64url': base64Url
            .encode(signature.bytes)
            .replaceAll('=', ''),
      };
      final message =
          'BK-DEVICE/v1\nenroll\n00000000-0000-4000-8000-000000000000\nsynthetic-native-nonce';
      final proof = await vault.signProof(message);
      // Only public key/proof emitted for independent Python verification.
      // ignore: avoid_print
      print(
        'BK_NATIVE_PROOF:${jsonEncode({'public_key': nativeKey, 'message': message, 'signature': proof})}',
      );
    } else {
      metadata =
          jsonDecode((await vault.read('native-qa-metadata'))!)
              as Map<String, dynamic>;
    }
    final rights = OfflineEntitlements(
      vault: vault,
      environment: 'test',
      trustedKeys: {'sim-native-qa': base64.decode(metadata['key'] as String)},
    );
    rights.bindAccount(
      subject: subject,
      deviceId: device,
      thumbprint: metadata['thumb'] as String,
    );
    if (envelope != null) {
      await rights.accept(envelope, nonce: 'native-qa', requestClock: clock);
    }
    final access = await rights.access();
    expect(
      access.status,
      phase == 'reboot'
          ? CommerceStatus.verificationRequired
          : CommerceStatus.active,
    );
    expect(access.canUse('audio'), isTrue);
    expect(access.adsAllowed, isFalse);
    if (phase == 'reboot') {
      await rights.logout();
      await vault.remove('native-qa-metadata');
    }
  });
}
