import 'package:flutter/foundation.dart';

enum ApiFlavor {
  local,
  staging,
  production,
}

class ApiConfig {
  static const String _flavorValue = String.fromEnvironment(
    'API_FLAVOR',
    defaultValue: 'local',
  );

  static const String _customBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static ApiFlavor get flavor {
    switch (_flavorValue) {
      case 'production':
        return ApiFlavor.production;
      case 'staging':
        return ApiFlavor.staging;
      case 'local':
      default:
        return ApiFlavor.local;
    }
  }

  static String get baseUrl {
    if (_customBaseUrl.isNotEmpty) {
      return _normalize(_customBaseUrl);
    }

    switch (flavor) {
      case ApiFlavor.local:
        return _localBaseUrl;

      case ApiFlavor.staging:
        return 'https://staging-api.beriyarkedebideri.com/api';

      case ApiFlavor.production:
        return 'https://api.beriyarkedebideri.com/api';
    }
  }

  static String get _localBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }

    // Android emulator
    return 'http://10.0.2.2:8000/api';
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