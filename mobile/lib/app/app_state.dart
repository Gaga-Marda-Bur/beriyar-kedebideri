import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/backend_health_service.dart';

class AppState extends ChangeNotifier {
  static const String _localeKey = 'bk_locale';

  final BackendHealthService _backendHealthService;

  Locale _locale = const Locale('fr');
  bool _isBackendConnected = false;
  bool _isCheckingBackend = false;

  AppState({
    BackendHealthService? backendHealthService,
  }) : _backendHealthService = backendHealthService ?? BackendHealthService();

  Locale get locale => _locale;
  bool get isBackendConnected => _isBackendConnected;
  bool get isCheckingBackend => _isCheckingBackend;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey) ?? 'fr';

    _locale = Locale(code);
    notifyListeners();

    await checkBackend();
  }

  Future<void> setLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, code);

    _locale = Locale(code);
    notifyListeners();
  }

  Future<void> checkBackend() async {
    _isCheckingBackend = true;
    notifyListeners();

    _isBackendConnected = await _backendHealthService.checkConnection();

    _isCheckingBackend = false;
    notifyListeners();
  }
}