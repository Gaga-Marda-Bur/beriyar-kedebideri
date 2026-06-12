import 'package:flutter/foundation.dart';

enum AppFlavor {
  development,
  production,
}

class AppEnvironment {
  static const AppFlavor flavor = bool.fromEnvironment(
    'dart.vm.product',
  )
      ? AppFlavor.production
      : AppFlavor.development;

  static bool get isDev => flavor == AppFlavor.development;

  static bool get isProd => flavor == AppFlavor.production;

  static bool get showDebugLogs => isDev && kDebugMode;

  static bool get showDevTools => isDev && kDebugMode;

  static Duration get backendCheckTimeout {
    if (isProd) {
      return const Duration(milliseconds: 900);
    }

    return const Duration(milliseconds: 1200);
  }

  static Duration get backendStatusCacheDuration {
    if (isProd) {
      return const Duration(seconds: 20);
    }

    return const Duration(seconds: 8);
  }
}