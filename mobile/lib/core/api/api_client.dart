import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class ApiClient {
  final http.Client _client;

  ApiClient({
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${ApiConfig.baseUrl}$normalizedPath').replace(
      queryParameters: query,
    );
  }

  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _client.get(
      _uri(path, query),
      headers: {
        'Accept': 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'GET $path failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {
      'results': decoded,
    };
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String>? query,
  }) async {
    final data = await getMap(path, query: query);

    final results = data['results'];

    if (results is List) {
      return results;
    }

    return [];
  }
}