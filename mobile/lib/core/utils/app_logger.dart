import 'package:flutter/foundation.dart';

import '../config/app_environment.dart';

class AppLogger {
  static void debug(String message) {
    if (!AppEnvironment.showDebugLogs) return;
    debugPrint(message);
  }

  static void info(String message) {
    if (!AppEnvironment.showDebugLogs) return;
    debugPrint(message);
  }

  static void warning(String message) {
    if (!AppEnvironment.showDebugLogs) return;
    debugPrint('WARNING: $message');
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!AppEnvironment.showDebugLogs) return;

    debugPrint('ERROR: $message');

    if (error != null) {
      debugPrint('DETAIL: $error');
    }

    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}