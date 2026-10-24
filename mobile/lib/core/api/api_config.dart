import 'package:flutter/foundation.dart';

enum ApiFlavor { local, staging, production }

class ApiConfig {
  // A13 : aucune valeur par défaut implicite. En debug/profile, l'absence de
  // flavor conserve le comportement historique (« local ») ; en release, elle
  // est refusée (voir [releaseConfigurationIssues]).
  static const String _flavorValue = String.fromEnvironment(
    'API_FLAVOR',
    defaultValue: '',
  );

  static const String _customBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String productionBaseUrl =
      'https://api.beriyarkedebideri.com/api';
  static const String stagingBaseUrl =
      'https://staging-api.beriyarkedebideri.com/api';

  static ApiFlavor get flavor => parseFlavor(_flavorValue);

  static ApiFlavor parseFlavor(String value) {
    switch (value.trim()) {
      case 'production':
        return ApiFlavor.production;
      case 'staging':
        return ApiFlavor.staging;
      case 'local':
      default:
        return ApiFlavor.local;
    }
  }

  static String get baseUrl => resolveBaseUrl(
    flavorValue: _flavorValue,
    customBaseUrl: _customBaseUrl,
    isWeb: kIsWeb,
  );

  static String resolveBaseUrl({
    required String flavorValue,
    required String customBaseUrl,
    bool isWeb = false,
  }) {
    if (customBaseUrl.trim().isNotEmpty) {
      return _normalize(customBaseUrl);
    }

    switch (parseFlavor(flavorValue)) {
      case ApiFlavor.local:
        return isWeb ? 'http://127.0.0.1:8000/api' : 'http://10.0.2.2:8000/api';
      case ApiFlavor.staging:
        return stagingBaseUrl;
      case ApiFlavor.production:
        return productionBaseUrl;
    }
  }

  /// Problèmes bloquants pour la configuration compilée dans ce binaire,
  /// si c'est une release. Liste vide hors release.
  static List<String> releaseConfigurationIssues() {
    if (!kReleaseMode) return const [];
    return validateReleaseConfiguration(
      flavorValue: _flavorValue,
      customBaseUrl: _customBaseUrl,
    );
  }

  /// Règles A13 pour une release : environnement explicite (production ou
  /// staging) et API joignable uniquement en HTTPS sur un hôte public.
  static List<String> validateReleaseConfiguration({
    required String flavorValue,
    required String customBaseUrl,
  }) {
    final issues = <String>[];
    final flavorName = flavorValue.trim();

    if (flavorName != 'production' && flavorName != 'staging') {
      issues.add(
        flavorName.isEmpty
            ? 'API_FLAVOR absent : une release doit préciser '
                  '--dart-define=API_FLAVOR=production (ou staging).'
            : 'API_FLAVOR="$flavorName" interdit en release '
                  '(valeurs admises : production, staging).',
      );
    }

    final url = resolveBaseUrl(
      flavorValue: flavorName,
      customBaseUrl: customBaseUrl,
    );
    issues.addAll(validatePublicHttpsUrl(url));
    return issues;
  }

  static List<String> validatePublicHttpsUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return ['URL d\'API invalide.'];
    }
    final issues = <String>[];
    if (uri.scheme != 'https') {
      issues.add('URL d\'API non HTTPS interdite en release.');
    }
    if (uri.userInfo.isNotEmpty) {
      issues.add('URL d\'API contenant des identifiants interdite.');
    }
    if (uri.hasQuery || uri.hasFragment) {
      issues.add(
        'Les paramètres et fragments sont interdits dans l’URL de base.',
      );
    }
    if (isLocalOrPrivateHost(uri.host)) {
      issues.add('Hôte local ou privé interdit en release : "${uri.host}".');
    }
    return issues;
  }

  static bool isLocalOrPrivateHost(String rawHost) {
    final host = rawHost
        .toLowerCase()
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceFirst(RegExp(r'\.+$'), '');
    if (host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host == '0.0.0.0' ||
        host == '::1' ||
        host == '::' ||
        host.contains('%') ||
        host.startsWith('::ffff:') ||
        RegExp(r'^fe[89ab][0-9a-f]:').hasMatch(host) ||
        (host.startsWith('fc') && host.contains(':')) ||
        (host.startsWith('fd') && host.contains(':'))) {
      return true;
    }
    if (!host.contains('.') && !host.contains(':')) return true;
    if (host.contains(':')) {
      final words = host.split(':').where((word) => word.isNotEmpty).toList();
      if (words.isNotEmpty &&
          words
              .take(words.length - 1)
              .every((word) => int.tryParse(word, radix: 16) == 0) &&
          (int.tryParse(words.last, radix: 16) ?? 2) <= 1) {
        return true;
      }
    }
    final parts = host.split('.');
    if (parts.every((part) => int.tryParse(part) != null) && parts.length != 4) {
      return true;
    }
    if (parts.any(
      (part) =>
          part.startsWith('0x') ||
          (part.length > 1 &&
              part.startsWith('0') &&
              int.tryParse(part) != null),
    )) {
      return true;
    }
    if (parts.length == 4) {
      final octets = parts.map(int.tryParse).toList();
      if (octets.every((o) => o != null && o >= 0 && o <= 255)) {
        final a = octets[0]!;
        final b = octets[1]!;
        return a == 127 ||
            a == 10 ||
            a == 0 ||
            (a == 169 && b == 254) ||
            (a == 172 && b >= 16 && b <= 31) ||
            (a == 192 && b == 168) ||
            (a == 100 && b >= 64 && b <= 127);
      }
    }
    return false;
  }

  static bool get isLocal => flavor == ApiFlavor.local;

  static bool get isStaging => flavor == ApiFlavor.staging;

  static bool get isProduction => flavor == ApiFlavor.production;

  static String get flavorName => flavor.name;

  static String _normalize(String value) {
    var url = value.trim();

    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    if (!url.endsWith('/api')) {
      url = '$url/api';
    }

    return url;
  }
}
