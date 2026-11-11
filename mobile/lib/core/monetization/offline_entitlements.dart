import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as digests;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

const freeLearningFeatures = <String>{
  'alphabet',
  'dictionary',
  'initiation',
  'audio',
  'progress',
  'offline_packs',
  'srs',
  'keyboard',
  'transliteration',
  'editor',
  'exports',
};
const simulationFeatures = <String>{'simulation.badge', 'ads_free'};

/// Commercial-only storage. Never reads/migrates/deletes pedagogical preferences.
abstract class CommerceVault {
  Future<Map<String, dynamic>> clock();
  Future<String?> read(String scope);
  Future<void> write(String scope, String value);
  Future<void> remove(String scope);
  Future<String> publicKey();
  Future<String> signProof(String message);
}

class AndroidCommerceVault implements CommerceVault {
  static const channel = MethodChannel('bk/commerce_v1');
  Future<void> resetSession() => channel.invokeMethod<void>('resetSession');
  @override
  Future<Map<String, dynamic>> clock() async => Map<String, dynamic>.from(
    (await channel.invokeMapMethod<String, dynamic>('clock'))!,
  );
  @override
  Future<String?> read(String scope) =>
      channel.invokeMethod<String>('read', {'scope': scope});
  @override
  Future<void> write(String scope, String value) =>
      channel.invokeMethod<void>('write', {'scope': scope, 'value': value});
  @override
  Future<void> remove(String scope) =>
      channel.invokeMethod<void>('remove', {'scope': scope});
  @override
  Future<String> publicKey() async =>
      (await channel.invokeMethod<String>('publicKey'))!;
  @override
  Future<String> signProof(String message) async =>
      (await channel.invokeMethod<String>('sign', {'message': message}))!;
}

enum CommerceStatus { free, active, expired, verificationRequired }

class CommerceAccess {
  final CommerceStatus status;
  final Set<String> features;
  final DateTime? expiresAt;
  const CommerceAccess(this.status, [this.features = const {}, this.expiresAt]);
  bool canUse(String code) =>
      freeLearningFeatures.contains(code) ||
      (status == CommerceStatus.active && features.contains(code));
  // No SDK, tracking or network adapter exists in this lot.
  bool get adsAllowed => false;
}

class OfflineEntitlements {
  final CommerceVault vault;
  final Map<String, List<int>> trustedKeys;
  final String environment;
  String? _subject;
  String? _device;
  String? _thumbprint;
  int _contextGeneration = 0;

  OfflineEntitlements({
    required this.vault,
    required this.environment,
    this.trustedKeys = const {},
  });

  /// Only supply identity returned by the authenticated commerce server.
  /// No installation-token login and no side effects on progress synchronization.
  void bindAccount({
    required String subject,
    required String deviceId,
    required String thumbprint,
  }) {
    _contextGeneration++;
    _subject = subject;
    _device = deviceId;
    _thumbprint = thumbprint;
  }

  String get _scope => '$environment:$_subject:$_device';

  Future<void> logout() async {
    final scope = _subject == null ? null : _scope;
    _contextGeneration++;
    _subject = _device = _thumbprint = null;
    if (scope != null) await vault.remove(scope);
  }

  static String _base64(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static List<int> _decode(String value) {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
      throw const FormatException('base64url');
    }
    final bytes = base64Url.decode(base64Url.normalize(value));
    if (_base64(bytes) != value) {
      throw const FormatException('non-canonical base64url');
    }
    return bytes;
  }

  static dynamic _sorted(dynamic value) {
    if (value is Map<String, dynamic>) {
      return {
        for (final key in value.keys.toList()..sort()) key: _sorted(value[key]),
      };
    }
    if (value is List) return value.map(_sorted).toList();
    return value;
  }

  Future<Map<String, dynamic>> _verify(Map<String, dynamic> envelope) async {
    if (kReleaseMode ||
        environment == 'production' ||
        _subject == null ||
        envelope.length != 4 ||
        envelope['version'] != 1 ||
        envelope['kid'] is! String) {
      throw const FormatException('identity/envelope');
    }
    final localKey = base64.decode(await vault.publicKey());
    if (digests.sha256.convert(localKey).toString() != _thumbprint) {
      throw const FormatException('installation key changed');
    }
    final kid = envelope['kid'] as String;
    final key = trustedKeys[kid];
    if (!kid.startsWith('sim-') || key == null || key.length != 32) {
      throw const FormatException('unknown key');
    }
    final payload = envelope['payload_b64url'] as String;
    final signature = _decode(envelope['signature_b64url'] as String);
    if (payload.length > 16000 || signature.length != 64) {
      throw const FormatException('size');
    }
    final verified = await Ed25519().verify(
      utf8.encode('BK-OFFLINE-GRANT/v1\n$kid\n$payload'),
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(key, type: KeyPairType.ed25519),
      ),
    );
    if (!verified) throw const FormatException('signature');
    final raw = utf8.decode(_decode(payload));
    if (raw.codeUnits.any((n) => n > 127)) {
      throw const FormatException('claim encoding');
    }
    final claims = jsonDecode(raw) as Map<String, dynamic>;
    // Canonical subset rejects duplicate keys, floats, alternate whitespace/order.
    if (jsonEncode(_sorted(claims)) != raw) {
      throw const FormatException('canonical claims');
    }
    for (final name in [
      'issued_at',
      'starts_at',
      'expires_at',
      'offline_valid_until',
      'server_now',
      'entitlement_epoch',
      'policy_version',
    ]) {
      if (claims[name] is! int ||
          claims[name] < 0 ||
          claims[name] > 9007199254740991) {
        throw const FormatException('integer');
      }
    }
    if (claims['version'] != 1 ||
        claims['issuer'] != 'bk' ||
        claims['audience'] != 'bk-android-simulation' ||
        claims['environment'] != environment ||
        claims['subject'] != _subject ||
        claims['device_id'] != _device ||
        claims['device_key_thumbprint'] != _thumbprint ||
        claims['lease_id'] is! String ||
        claims['grant_ids'] is! List ||
        claims['nonce'] is! String ||
        claims['policy_version'] < 1 ||
        claims['starts_at'] != claims['issued_at'] ||
        claims['server_now'] != claims['issued_at'] ||
        claims['offline_valid_until'] != claims['expires_at'] ||
        claims['expires_at'] < claims['issued_at'] ||
        claims['expires_at'] - claims['issued_at'] > 7 * 86400 ||
        claims['features'] is! List ||
        (claims['features'] as List).any(
          (f) => !simulationFeatures.contains(f),
        )) {
      throw const FormatException('claims');
    }
    return claims;
  }

  /// Accept only a fresh challenge response over the authenticated same-origin API.
  /// requestClock is captured BEFORE the lease POST, not rebuilt from a cached file.
  Future<void> accept(
    Map<String, dynamic> envelope, {
    required String nonce,
    required Map<String, dynamic> requestClock,
  }) async {
    final generation = _contextGeneration;
    final scope = _scope;
    final claims = await _verify(envelope);
    final now = await vault.clock();
    final elapsed =
        (now['elapsed_ms'] as int) - (requestClock['elapsed_ms'] as int);
    if (claims['nonce'] != nonce ||
        now['boot'] != requestClock['boot'] ||
        now['boot'] == null ||
        elapsed < 0 ||
        elapsed > 30000) {
      throw const FormatException('freshness/boot');
    }
    final previous = await vault.read(scope);
    if (previous != null) {
      final old = jsonDecode(previous) as Map<String, dynamic>;
      if (claims['entitlement_epoch'] < old['epoch'] ||
          claims['server_now'] < old['server_now']) {
        throw const FormatException('downgrade');
      }
      if (claims['lease_id'] == old['lease_id']) {
        throw const FormatException('replayed lease');
      }
    }
    if (generation != _contextGeneration) {
      throw const FormatException('account changed');
    }
    await vault.write(
      scope,
      jsonEncode({
        'envelope': envelope,
        'boot': requestClock['boot'],
        'elapsed_ms': requestClock['elapsed_ms'],
        'server_now': claims['server_now'],
        'epoch': claims['entitlement_epoch'],
        'lease_id': claims['lease_id'],
      }),
    );
    // A logout racing the platform write must not resurrect the previous lease.
    if (generation != _contextGeneration) await vault.remove(scope);
  }

  Future<CommerceAccess> access() async {
    if (_subject == null) return const CommerceAccess(CommerceStatus.free);
    final generation = _contextGeneration;
    final scope = _scope;
    try {
      final raw = await vault.read(scope);
      if (raw == null) {
        return const CommerceAccess(CommerceStatus.verificationRequired);
      }
      final anchor = jsonDecode(raw) as Map<String, dynamic>;
      final claims = await _verify(
        Map<String, dynamic>.from(anchor['envelope']),
      );
      final now = await vault.clock();
      final elapsed =
          (now['elapsed_ms'] as int) - (anchor['elapsed_ms'] as int);
      if (generation != _contextGeneration ||
          now['boot'] == null ||
          now['boot'] != anchor['boot'] ||
          elapsed < 0 ||
          anchor['epoch'] != claims['entitlement_epoch'] ||
          anchor['server_now'] != claims['server_now']) {
        return const CommerceAccess(CommerceStatus.verificationRequired);
      }
      final serverTime = (anchor['server_now'] as int) + elapsed ~/ 1000;
      if ((claims['features'] as List).isEmpty && (claims['grant_ids'] as List).isEmpty) {
        return const CommerceAccess(CommerceStatus.free);
      }
      if (serverTime >= claims['expires_at']) {
        return CommerceAccess(CommerceStatus.expired,const {},
          DateTime.fromMillisecondsSinceEpoch((claims['expires_at'] as int)*1000,isUtc:true));
      }
      return CommerceAccess(
        CommerceStatus.active,
        Set<String>.from(claims['features']),
        DateTime.fromMillisecondsSinceEpoch(
          (claims['expires_at'] as int) * 1000,
          isUtc: true,
        ),
      );
    } catch (_) {
      return const CommerceAccess(CommerceStatus.verificationRequired);
    }
  }
}
