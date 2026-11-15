import 'package:flutter/services.dart';

/// Encrypted secret storage abstraction for learner authentication.
/// Never backed by SharedPreferences.
abstract class LearnerAuthVault {
  Future<String?> read(String scope);
  Future<void> write(String scope, String value);
  Future<void> remove(String scope);
  Future<void> clear();
}

class AndroidLearnerAuthVault implements LearnerAuthVault {
  static const MethodChannel _channel = MethodChannel('bk/learner_auth_v1');

  @override
  Future<String?> read(String scope) async {
    try {
      return await _channel.invokeMethod<String>('read', {'scope': scope});
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> write(String scope, String value) async {
    try {
      await _channel.invokeMethod<void>('write', {
        'scope': scope,
        'value': value,
      });
    } on MissingPluginException {
      // Non-Android host fallback (e.g. desktop widget tests)
    }
  }

  @override
  Future<void> remove(String scope) async {
    try {
      await _channel.invokeMethod<void>('remove', {'scope': scope});
    } on MissingPluginException {
      // ignore
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      // ignore
    }
  }
}

class InMemoryLearnerAuthVault implements LearnerAuthVault {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String scope) async => _store[scope];

  @override
  Future<void> write(String scope, String value) async {
    _store[scope] = value;
  }

  @override
  Future<void> remove(String scope) async {
    _store.remove(scope);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }
}
