// Non-régression A02 : aucune préférence réelle de l'utilisateur n'est utilisée.
// Depuis mobile : flutter test --no-pub ../docs/audit_cache_probe.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/cache/online_content_cache_service.dart';

void main() {
  test('Audit du cycle écriture / lecture du cache', () async {
    SharedPreferences.setMockInitialValues({});
    final service = OnlineContentCacheService();
    await service.saveList(
      key: 'audit',
      items: [
        {'id': 1, 'title': 'Contenu isolé'},
      ],
    );
    final read = await service.readList(key: 'audit');
    expect(
      read,
      equals([
        {'id': 1, 'title': 'Contenu isolé'},
      ]),
    );
  });
}
