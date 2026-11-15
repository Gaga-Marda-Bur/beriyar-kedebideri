import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api/api_config.dart';
import 'learner_auth_vault.dart';
import 'learner_session_cleanup.dart';

enum LearnerAuthStatus { anonymous, authenticated, expired }

class LearnerAuthException implements Exception {
  final String message;
  final int? statusCode;

  const LearnerAuthException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class LearnerAuthService extends ChangeNotifier {
  static final LearnerAuthService instance = LearnerAuthService();
  static const String _vaultScope = 'learner_session_v1';

  final LearnerAuthVault _vault;
  final http.Client _client;
  final Uri _base;
  final Future<void> Function() _cleanupUserData;

  LearnerAuthStatus _status = LearnerAuthStatus.anonymous;
  bool _busy = false;
  int? _userId;
  String? _username;
  bool _isPilot = false;
  bool _isStaff = false;
  String _csrfToken = '';
  final Map<String, String> _cookies = {};

  LearnerAuthService({
    LearnerAuthVault? vault,
    http.Client? client,
    Uri? base,
    Future<void> Function()? cleanupUserData,
  }) : _vault = vault ?? AndroidLearnerAuthVault(),
       _client = client ?? http.Client(),
       _base = base ?? Uri.parse(ApiConfig.baseUrl),
       _cleanupUserData =
           cleanupUserData ?? LearnerSessionCleanup.clearUserSessionData {
    _validateBaseUri(_base);
  }

  static void _validateBaseUri(Uri uri) {
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      throw ArgumentError('Invalid API base URI');
    }
    final isDebugLoopback =
        kDebugMode &&
        ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host);
    if (uri.scheme != 'https' && !isDebugLoopback) {
      throw ArgumentError('HTTPS required; loopback HTTP is debug-only');
    }
  }

  LearnerAuthStatus get status => _status;
  bool get isAuthenticated =>
      _status == LearnerAuthStatus.authenticated &&
      _cookies.containsKey('sessionid');
  bool get isExpired => _status == LearnerAuthStatus.expired;
  bool get busy => _busy;
  int? get userId => _userId;
  String? get username => _username;
  bool get isPilot => _isPilot;
  bool get isStaff => _isStaff;

  /// Headers attached to authenticated GET requests on ApiClient.
  Map<String, String> authHeadersForGet() {
    if (!isAuthenticated) return const {};
    return {'Cookie': _cookieHeaderValue()};
  }

  /// Headers attached to authenticated POST/unsafe requests on ApiClient.
  Map<String, String> authHeadersForPost() {
    if (!isAuthenticated) return const {};
    return {
      'Cookie': _cookieHeaderValue(),
      if (_csrfToken.isNotEmpty) 'X-CSRFToken': _csrfToken,
      'Origin': _base.origin,
    };
  }

  String _cookieHeaderValue() =>
      _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  Uri _uri(String path) {
    final normalizedBase = _base.toString().replaceFirst(RegExp(r'/$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  void _applySetCookie(String? cookieHeader) {
    if (cookieHeader == null || cookieHeader.isEmpty) return;
    for (final match in RegExp(
      r'(?:^|,\s*)(sessionid|csrftoken)=([^;,\s]*)',
    ).allMatches(cookieHeader)) {
      final name = match[1]!;
      final value = match[2]!;
      if (value.isEmpty) {
        _cookies.remove(name);
      } else {
        _cookies[name] = value;
      }
    }
    if (_cookies['csrftoken'] != null && _cookies['csrftoken']!.isNotEmpty) {
      _csrfToken = _cookies['csrftoken']!;
    }
  }

  Future<void> _persistSnapshot() async {
    if (!isAuthenticated || _userId == null || _username == null) return;
    final payload = jsonEncode({
      'user_id': _userId,
      'username': _username,
      'is_pilot': _isPilot,
      'is_staff': _isStaff,
      'csrf': _csrfToken,
      'cookies': Map<String, String>.from(_cookies),
    });
    await _vault.write(_vaultScope, payload);
  }

  Future<void> restore() async {
    try {
      final raw = await _vault.read(_vaultScope);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final cookies = decoded['cookies'];
      if (cookies is! Map) return;

      _cookies.clear();
      for (final name in ['sessionid', 'csrftoken']) {
        final value = cookies[name];
        if (value is String &&
            value.isNotEmpty &&
            !value.contains(';') &&
            !value.contains('\n')) {
          _cookies[name] = value;
        }
      }

      final sessionId = _cookies['sessionid'];
      final uid = decoded['user_id'];
      final uname = decoded['username'];
      if (sessionId == null ||
          sessionId.isEmpty ||
          uid is! int ||
          uname is! String ||
          uname.isEmpty) {
        _cookies.clear();
        return;
      }

      _userId = uid;
      _username = uname;
      _isPilot = decoded['is_pilot'] == true;
      _isStaff = decoded['is_staff'] == true;
      _csrfToken = decoded['csrf'] is String ? decoded['csrf'] as String : '';
      _status = LearnerAuthStatus.authenticated;
      notifyListeners();
    } catch (_) {
      // Corrupt vault snapshot: fail closed to anonymous without throwing on startup.
      _resetInMemory(LearnerAuthStatus.anonymous);
    }
  }

  Future<void> login(String username, String password) async {
    final trimmedUser = username.trim();
    if (trimmedUser.isEmpty || password.isEmpty) {
      throw const LearnerAuthException(
        'Identifiant et mot de passe requis.',
        statusCode: 400,
      );
    }

    _busy = true;
    notifyListeners();

    try {
      final previousUserId = _userId;

      final csrfResponse = await _client
          .get(
            _uri('/core/auth/csrf/'),
            headers: {
              'Accept': 'application/json',
              if (_cookies.isNotEmpty) 'Cookie': _cookieHeaderValue(),
            },
          )
          .timeout(const Duration(seconds: 8));

      _applySetCookie(csrfResponse.headers['set-cookie']);
      if (csrfResponse.statusCode >= 200 && csrfResponse.statusCode < 300) {
        final csrfBody = jsonDecode(utf8.decode(csrfResponse.bodyBytes));
        if (csrfBody is Map && csrfBody['csrf_token'] is String) {
          _csrfToken = csrfBody['csrf_token'] as String;
        }
      }

      final loginResponse = await _client
          .post(
            _uri('/core/auth/login/'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Origin': _base.origin,
              if (_cookies.isNotEmpty) 'Cookie': _cookieHeaderValue(),
              if (_csrfToken.isNotEmpty) 'X-CSRFToken': _csrfToken,
            },
            body: jsonEncode({'username': trimmedUser, 'password': password}),
          )
          .timeout(const Duration(seconds: 8));

      if (loginResponse.statusCode == 429) {
        throw const LearnerAuthException(
          'Trop de tentatives. Réessayez dans une minute.',
          statusCode: 429,
        );
      }
      if (loginResponse.statusCode == 400 || loginResponse.statusCode == 401) {
        throw const LearnerAuthException(
          'Identifiant ou mot de passe incorrect.',
          statusCode: 401,
        );
      }
      if (loginResponse.statusCode == 403) {
        throw const LearnerAuthException(
          'Vérification de sécurité refusée (CSRF).',
          statusCode: 403,
        );
      }
      if (loginResponse.statusCode < 200 || loginResponse.statusCode >= 300) {
        throw LearnerAuthException(
          'Connexion impossible (${loginResponse.statusCode}).',
          statusCode: loginResponse.statusCode,
        );
      }

      _applySetCookie(loginResponse.headers['set-cookie']);
      final data = jsonDecode(utf8.decode(loginResponse.bodyBytes));
      if (data is! Map<String, dynamic> ||
          data['authenticated'] != true ||
          !_cookies.containsKey('sessionid')) {
        throw const LearnerAuthException('Réponse de session invalide.');
      }

      final newUserId = data['user_id'] as int?;
      if (previousUserId != null &&
          newUserId != null &&
          previousUserId != newUserId) {
        await _cleanupUserData();
      }

      _userId = newUserId;
      _username = data['username']?.toString() ?? trimmedUser;
      _isPilot = data['is_pilot'] == true;
      _isStaff = data['is_staff'] == true;
      if (data['csrf_token'] is String) {
        _csrfToken = data['csrf_token'] as String;
      }
      _status = LearnerAuthStatus.authenticated;
      await _persistSnapshot();
    } on LearnerAuthException {
      rethrow;
    } on TimeoutException {
      throw const LearnerAuthException(
        'Délai dépassé. Vérifiez votre connexion.',
      );
    } on SocketException {
      throw const LearnerAuthException(
        'Réseau indisponible. Connexion impossible.',
      );
    } on http.ClientException {
      throw const LearnerAuthException(
        'Réseau indisponible. Connexion impossible.',
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Checks current session against Django when online.
  /// Network errors NEVER log out the user (preserves offline continuity).
  Future<void> refreshSession() async {
    if (!isAuthenticated) return;
    try {
      final response = await _client
          .get(
            _uri('/core/auth/me/'),
            headers: {
              'Accept': 'application/json',
              'Cookie': _cookieHeaderValue(),
            },
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 401) {
        await handleUnauthorized();
        return;
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _applySetCookie(response.headers['set-cookie']);
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is Map<String, dynamic>) {
          _isPilot = data['is_pilot'] == true;
          _isStaff = data['is_staff'] == true;
          if (data['csrf_token'] is String) {
            _csrfToken = data['csrf_token'] as String;
          }
          await _persistSnapshot();
          notifyListeners();
        }
      }
    } catch (_) {
      // Offline / network error: keep authenticated local session intact.
    }
  }

  Future<void> handleUnauthorized() async {
    if (_status != LearnerAuthStatus.authenticated) return;
    _resetInMemory(LearnerAuthStatus.expired);
    await _vault.clear();
    notifyListeners();
  }

  Future<void> logout() async {
    if (isAuthenticated) {
      try {
        await _client
            .post(
              _uri('/core/auth/logout/'),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                ...authHeadersForPost(),
              },
              body: '{}',
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Offline logout must still clear local secrets and cached protected content.
      }
    }
    _resetInMemory(LearnerAuthStatus.anonymous);
    await _vault.clear();
    await _cleanupUserData();
    notifyListeners();
  }

  void _resetInMemory(LearnerAuthStatus nextStatus) {
    _status = nextStatus;
    _userId = null;
    _username = null;
    _isPilot = false;
    _isStaff = false;
    _csrfToken = '';
    _cookies.clear();
  }
}
