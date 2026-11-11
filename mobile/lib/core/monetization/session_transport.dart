import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../api/api_client.dart';

/// Cookie jar dedicated to commerce, never attached to educational ApiClient.
class SessionTransport {
  final http.Client client;
  final Uri base;
  final Map<String, String> _cookies = {};
  String _csrf = '';
  int _generation = 0;
  SessionTransport({required this.base, http.Client? client})
    : client = client ?? http.Client() {
    if (base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        (base.scheme != 'https' &&
            !(kDebugMode &&
                ['localhost', '127.0.0.1', '10.0.2.2'].contains(base.host)))) {
      throw ArgumentError('HTTPS required; loopback HTTP is debug-only');
    }
  }
  Map<String, String> get headers => {
    'Cookie': _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
    'X-CSRFToken': _csrf,
    'Origin': base.origin,
  };
  Map<String, dynamic> snapshot() => {
    'cookies': Map<String, String>.from(_cookies),
    'csrf': _csrf,
  };
  void restore(Map<String, dynamic> value) {
    clear();
    final cookies = Map<String, dynamic>.from(value['cookies']);
    for (final name in ['sessionid', 'csrftoken']) {
      final entry = cookies[name];
      if (entry is String && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(entry)) {
        _cookies[name] = entry;
      }
    }
    _csrf = value['csrf'] as String;
  }

  void clear() {
    _generation++;
    _cookies.clear();
    _csrf = '';
  }

  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (!path.startsWith('/monetization/v1/')) {
      throw ArgumentError('Commerce-only path');
    }
    final generation = _generation;
    final uri = Uri.parse(
      '${base.toString().replaceFirst(RegExp(r'/$'), '')}$path',
    );
    final request = http.Request(body == null ? 'GET' : 'POST', uri)
      ..followRedirects = false;
    request.headers.addAll({
      ...headers,
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await client.send(request).timeout(const Duration(seconds: 8)),
    );
    if (generation != _generation) throw StateError('Stale session response');
    final cookieHeader = response.headers['set-cookie'] ?? '';
    for (final match in RegExp(
      r'(?:^|,\s*)(sessionid|csrftoken)=([^;,\s]*)',
    ).allMatches(cookieHeader)) {
      if (match[2]!.isEmpty) {
        _cookies.remove(match[1]);
      } else {
        _cookies[match[1]!] = match[2]!;
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiRequestException(response.statusCode, 'Session unavailable');
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (data['csrf_token'] is String) _csrf = data['csrf_token'];
    return data;
  }
}
