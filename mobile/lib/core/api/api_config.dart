class ApiConfig {
  static const String androidEmulatorBaseUrl = 'http://10.0.2.2:8000/api';
  static const String localWebBaseUrl = 'http://127.0.0.1:8000/api';

  static String get baseUrl {
    return androidEmulatorBaseUrl;
  }
}