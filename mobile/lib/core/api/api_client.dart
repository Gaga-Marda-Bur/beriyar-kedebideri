import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class ApiRequestException implements Exception {
  final int statusCode;
  final String detail;
  final int? retryAfterSeconds;
  const ApiRequestException(
    this.statusCode,
    this.detail, {
    this.retryAfterSeconds,
  });
  @override
  String toString() => 'HTTP $statusCode: $detail';
}

class IncompleteListException implements Exception {
  final List<dynamic> items;
  final String? next;
  final Object reason;
  IncompleteListException(List<dynamic> items, this.next, this.reason)
    : items = List.unmodifiable(items);
  @override
  String toString() => 'Collection incomplete (${items.length} items): $reason';
}

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Uri _resolveUri(String pathOrUrl, [Map<String, String>? query]) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      final parsed = Uri.parse(pathOrUrl);
      final base = Uri.parse(ApiConfig.baseUrl);
      if (parsed.scheme != base.scheme ||
          parsed.authority != base.authority ||
          parsed.userInfo.isNotEmpty) {
        throw ArgumentError(
          'Unauthorized authority in URL: ${parsed.authority}',
        );
      }
      return parsed;
    }

    final normalizedPath = pathOrUrl.startsWith('/')
        ? pathOrUrl
        : '/$pathOrUrl';
    return Uri.parse(
      '${ApiConfig.baseUrl}$normalizedPath',
    ).replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> getMap(
    String pathOrUrl, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    final requestHeaders = {'Accept': 'application/json', ...?headers};

    final uri = _resolveUri(pathOrUrl, query);

    final response = await _client
        .get(uri, headers: requestHeaders)
        .timeout(const Duration(seconds: 4));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'GET $pathOrUrl failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {'results': decoded};
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    bool followPagination = true,
    int maxPages = 50,
  }) async {
    final firstPageData = await getMap(path, query: query, headers: headers);
    final firstResults = firstPageData['results'];

    if (firstResults is! List) {
      throw const FormatException('Expected a results list');
    }

    final allItems = <dynamic>[...firstResults];
    final seenIds = <dynamic>{};

    for (final item in allItems) {
      if (item is Map && item.containsKey('id')) {
        seenIds.add(item['id']);
      }
    }

    if (!followPagination) {
      return allItems;
    }

    var nextUrl = firstPageData['next'] as String?;
    var pageCount = 1;
    var pageUri = _resolveUri(path, query);

    while (nextUrl != null && nextUrl.isNotEmpty && pageCount < maxPages) {
      pageCount++;
      try {
        final nextUri = pageUri.resolve(nextUrl);
        final nextData = await getMap(nextUri.toString(), headers: headers);

        final pageResults = nextData['results'];
        if (pageResults is! List) {
          throw const FormatException('Expected a results list');
        }
        {
          for (final item in pageResults) {
            if (item is Map && item.containsKey('id')) {
              final id = item['id'];
              if (seenIds.add(id)) {
                allItems.add(item);
              }
            } else {
              allItems.add(item);
            }
          }
        }

        nextUrl = nextData['next'] as String?;
        pageUri = nextUri;
      } catch (e) {
        // A partial collection must never overwrite a complete persistent cache.
        throw IncompleteListException(allItems, nextUrl, e);
      }
    }

    if (nextUrl != null && nextUrl.isNotEmpty) {
      throw IncompleteListException(
        allItems,
        nextUrl,
        StateError('Pagination limit reached'),
      );
    }

    return allItems;
  }

  Future<Map<String, dynamic>> postMap(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    final requestHeaders = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...?headers,
    };

    final response = await _client
        .post(
          _resolveUri(path, query),
          headers: requestHeaders,
          body: jsonEncode(body ?? {}),
        )
        .timeout(const Duration(seconds: 4));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var detail = 'Request failed';
      try {
        final payload = jsonDecode(utf8.decode(response.bodyBytes));
        if (payload is Map && payload['detail'] is String) {
          detail = payload['detail'] as String;
        }
      } catch (_) {}
      throw ApiRequestException(
        response.statusCode,
        detail,
        retryAfterSeconds: int.tryParse(response.headers['retry-after'] ?? ''),
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {'data': decoded};
  }
}
