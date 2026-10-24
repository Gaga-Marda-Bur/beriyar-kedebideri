import 'package:mobile/core/api/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('A13 — validation de la configuration release', () {
    List<String> issues(String flavor, [String url = '']) =>
        ApiConfig.validateReleaseConfiguration(
          flavorValue: flavor,
          customBaseUrl: url,
        );

    test('production et staging explicites sont acceptés', () {
      expect(issues('production'), isEmpty);
      expect(issues('staging'), isEmpty);
      expect(
        issues('production', 'https://api.beriyarkedebideri.com'),
        isEmpty,
      );
    });

    test('flavor absent, local ou inconnu est refusé', () {
      expect(issues(''), isNotEmpty);
      expect(issues('local'), isNotEmpty);
      expect(issues('prod'), isNotEmpty);
      // Le repli historique sur l'émulateur HTTP est aussi signalé.
      expect(issues('').join(' '), contains('10.0.2.2'));
    });

    test('URL personnalisée HTTP, locale ou privée est refusée', () {
      for (final url in [
        'http://api.beriyarkedebideri.com',
        'https://localhost:8000',
        'https://127.0.0.1/api',
        'https://10.0.2.2:8000',
        'https://192.168.1.20',
        'https://172.20.0.5',
        'https://[::1]:8000',
        'https://backend.local',
        'https://localhost.',
        'https://backend',
        'https://127.1',
        'https://2130706433',
        'https://0177.0.0.1',
        'https://[::ffff:127.0.0.1]',
        'https://[0:0:0:0:0:0:0:1]',
        'https://[febf::1]',
        'https://api.example.org?token=private',
        'https://api.example.org#fragment',
        'https://user:pass@api.beriyarkedebideri.com',
        'pas une url',
      ]) {
        expect(issues('production', url), isNotEmpty, reason: url);
      }
      expect(
        issues(
          'production',
          'https://user:private-password@example.org',
        ).join(' '),
        isNot(contains('private-password')),
      );
    });

    test('hôtes publics proches des plages privées restent acceptés', () {
      expect(ApiConfig.isLocalOrPrivateHost('172.32.0.1'), isFalse);
      expect(ApiConfig.isLocalOrPrivateHost('11.0.0.1'), isFalse);
      expect(ApiConfig.isLocalOrPrivateHost('localhost.example.com'), isFalse);
    });

    test('le développement local reste possible hors release', () {
      expect(
        ApiConfig.resolveBaseUrl(flavorValue: '', customBaseUrl: ''),
        'http://10.0.2.2:8000/api',
      );
      expect(
        ApiConfig.resolveBaseUrl(
          flavorValue: 'local',
          customBaseUrl: '',
          isWeb: true,
        ),
        'http://127.0.0.1:8000/api',
      );
      // Les tests ne tournent pas en mode release : aucun blocage.
      expect(ApiConfig.releaseConfigurationIssues(), isEmpty);
    });

    test("l'URL personnalisée est normalisée vers /api", () {
      expect(
        ApiConfig.resolveBaseUrl(
          flavorValue: 'production',
          customBaseUrl: 'https://api.example.org/',
        ),
        'https://api.example.org/api',
      );
    });
  });
}
