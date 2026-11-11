import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as hashes;
import '../api/api_client.dart';
import '../api/api_config.dart';
import 'commerce_client.dart';
import 'offline_entitlements.dart';
import 'session_transport.dart';

class PremiumController extends ChangeNotifier {
  final CommerceVault vault;
  final SessionTransport transport;
  final OfflineEntitlements rights;
  final Future<void> Function() eraseCommerce;
  final bool enabled;
  late final CommerceClient _commerce;
  bool busy = false;
  String? subject;
  String sync = 'guest';
  CommerceAccess access = const CommerceAccess(CommerceStatus.free);
  List<Map<String, dynamic>> offers = [];
  List<Map<String, dynamic>> history = [];
  Map<String, dynamic>? _binding;
  int _generation = 0;
  Timer? _timer;
  bool _disposed = false;
  Future<void> _storageTail = Future.value();
  Future<void> _store(int generation, String value) {
    final task = _storageTail.then((_) async {
      if (generation == _generation) await vault.write(_slot, value);
    });
    _storageTail = task.catchError((_) {});
    return task;
  }

  PremiumController({
    required this.vault,
    required this.transport,
    required this.rights,
    required this.eraseCommerce,
    this.enabled = true,
    ApiClient? api,
  }) {
    _commerce = CommerceClient(
      api: api ?? ApiClient(),
      rights: rights,
      authenticatedHeaders: () async => transport.headers,
    );
  }
  static PremiumController create() {
    final vault = AndroidCommerceVault();
    const flag = bool.fromEnvironment('BK_PREMIUM_SIMULATION');
    const encoded = String.fromEnvironment(
      'BK_SIMULATION_PUBLIC_KEYS',
      defaultValue: '{}',
    );
    Map<String, List<int>> keys = {};
    try {
      keys = (jsonDecode(encoded) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, base64.decode(v as String)),
      );
    } catch (_) {}
    final environment = ApiConfig.flavor == ApiFlavor.staging
        ? 'staging'
        : 'test';
    return PremiumController(
      vault: vault,
      transport: SessionTransport(base: Uri.parse(ApiConfig.baseUrl)),
      rights: OfflineEntitlements(
        vault: vault,
        environment: environment,
        trustedKeys: keys,
      ),
      eraseCommerce: vault.resetSession,
      enabled:
          flag && !kReleaseMode && ApiConfig.flavor != ApiFlavor.production,
    );
  }

  String get _slot =>
      'session-v1:${hashes.sha256.convert(utf8.encode(transport.base.toString()))}';
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (!enabled) {
      sync = 'disabled';
      _emit();
      return;
    }
    final generation = ++_generation;
    try {
      final raw = await vault.read(_slot);
      if (generation != _generation) return;
      if (raw != null) {
        final saved = jsonDecode(raw) as Map<String, dynamic>;
        transport.restore(Map<String, dynamic>.from(saved['transport']));
        subject = saved['subject'] as String;
        _binding = Map<String, dynamic>.from(saved['binding']);
        rights.bindAccount(
          subject: subject!,
          deviceId: _binding!['device_id'],
          thumbprint: _binding!['thumbprint'],
        );
        final checked = await rights.access();
        if (generation != _generation) return;
        access = checked;
        sync = 'offline';
      }
    } catch (_) {
      if (generation != _generation) return;
      await _forget();
      sync = 'verification_required';
    }
    _timer ??= Timer.periodic(const Duration(seconds: 15), (_) => checkLocal());
    _emit();
  }

  Future<void> _forget() async {
    subject = null;
    _binding = null;
    access = const CommerceAccess(CommerceStatus.free);
    offers = [];
    history = [];
    transport.clear();
    try { await _commerce.logout(); } catch (_) { /* Key erasure below is authoritative. */ }
    // Key erasure makes any old persisted session/lease unreadable after restart.
    final task = _storageTail.then((_) => eraseCommerce());
    _storageTail = task.catchError((_) {});
    await task;
  }

  Future<void> logout() async {
    final generation = ++_generation;
    final credentials = Map<String, String>.from(transport.headers);
    busy = true;
    subject = null;
    access = const CommerceAccess(CommerceStatus.free);
    offers = [];
    history = [];
    sync = 'guest';
    _emit();
    // Snapshot of the OLD cookie only; never log out a subsequently logged-in B.
    final pending = _commerce.api
        .postMap('/monetization/v1/session/logout/', headers: credentials)
        .then<void>((_) {})
        .catchError((_) {});
    try {
      await _forget();
    } finally {
      if (generation == _generation) {
        busy = false;
        _emit();
      }
    }
    unawaited(pending);
  }

  Future<void> login(String username, String password) async {
    if (!enabled || busy) return;
    busy = true;
    final generation = ++_generation;
    try {
      await _forget();
      if (generation != _generation) return;
      sync = 'connecting';
      _emit();
      await transport.request('/monetization/v1/session/csrf/');
      final identity = await transport.request(
        '/monetization/v1/session/login/',
        body: {'username': username, 'password': password},
      );
      if (generation != _generation) return;
      subject = identity['subject'] as String;
      await _refresh(generation);
    } catch (error) {
      if (generation == _generation) {
        await _forget();
        sync = 'login_failed';
      }
    } finally {
      if (generation == _generation) {
        busy = false;
        _emit();
      }
    }
  }

  Future<void> refresh() async {
    if (!enabled || subject == null || busy) return;
    busy = true;
    final generation = _generation;
    _emit();
    try {
      await _refresh(generation);
    } catch (error) {
      if (generation != _generation) return;
      if (error is ApiRequestException &&
          (error.statusCode == 401 || error.statusCode == 403)) {
        await _forget();
        sync = 'authentication_required';
      } else {
        final checked = await rights.access();
        if (generation != _generation) return;
        access = checked;
        sync = 'offline';
      }
    } finally {
      if (generation == _generation) {
        busy = false;
        _emit();
      }
    }
  }

  Future<void> _refresh(int generation) async {
    final identity = await transport.request('/monetization/v1/session/');
    if (generation != _generation) return;
    if (identity['subject'] != subject) {
      await _forget();
      throw StateError('Subject mismatch');
    }
    final device = await _commerce.enrollAndRefresh();
    if (generation != _generation) return;
    if (device['subject'] != subject) {
      await _forget();
      throw StateError('Device subject mismatch');
    }
    final checked = await rights.access();
    if (generation != _generation) return;
    _binding = device;
    access = checked;
    await _store(
      generation,
      jsonEncode({
        'transport': transport.snapshot(),
        'subject': subject,
        'binding': _binding,
      }),
    );
    if (generation != _generation) return;
    final catalog = await transport.request('/monetization/v1/catalog/');
    final requests = await transport.request('/monetization/v1/me/requests/');
    if (generation != _generation) return;
    offers = (catalog['offers'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    history = (requests['requests'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    sync = 'verified';
  }

  Future<void> checkLocal() async {
    if (subject == null || busy) return;
    final generation = _generation;
    final value = await rights.access();
    if (generation != _generation) return;
    access = value;
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
