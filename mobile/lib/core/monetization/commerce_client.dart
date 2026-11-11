import '../api/api_client.dart';
import 'offline_entitlements.dart';

/// Dedicated authenticated transport supplied by caller; never modifies the
/// progress ApiClient, stores a password or adds global authentication headers.
class CommerceClient {
  final ApiClient api;
  final OfflineEntitlements rights;
  final Future<Map<String, String>> Function() authenticatedHeaders;
  static const _base = '/monetization/v1';
  int _generation = 0;
  CommerceClient({
    required this.api,
    required this.rights,
    required this.authenticatedHeaders,
  });

  Future<Map<String, dynamic>> publicConfig() =>
      api.getMap('$_base/public-config/');

  Future<Map<String, dynamic>> enrollAndRefresh() async {
    final generation = ++_generation;
    final headers = await authenticatedHeaders();
    final challenge = await api.postMap(
      '$_base/me/device-keys/challenge/',
      headers: headers,
      body: {'purpose': 'enroll'},
    );
    final key = await rights.vault.publicKey();
    final signature = await rights.vault.signProof(
      challenge['message'] as String,
    );
    final device = await api.postMap(
      '$_base/me/device-keys/',
      headers: headers,
      body: {
        'challenge_id': challenge['id'],
        'public_key': key,
        'signature': signature,
      },
    );
    if (generation != _generation) {
      throw StateError('Commercial account context changed');
    }
    rights.bindAccount(
      subject: device['subject'] as String,
      deviceId: device['device_id'] as String,
      thumbprint: device['thumbprint'] as String,
    );
    final fresh = await api.postMap(
      '$_base/me/device-keys/challenge/',
      headers: headers,
      body: {'purpose': 'lease'},
    );
    final proof = await rights.vault.signProof(fresh['message'] as String);
    final clock = await rights.vault.clock();
    final envelope = await api.postMap(
      '$_base/me/offline-lease/',
      headers: headers,
      body: {
        'challenge_id': fresh['id'],
        'device_id': device['device_id'],
        'signature': proof,
      },
    );
    if (generation != _generation) {
      throw StateError('Commercial account context changed');
    }
    await rights.accept(
      envelope,
      nonce: fresh['nonce'] as String,
      requestClock: clock,
    );
    return device;
  }

  // Logout/account deletion must call this before any new account context.
  // 401/403/503 never delete learning content or reinterpret it as someone else's.
  Future<void> logout() {
    _generation++;
    return rights.logout();
  }
}
