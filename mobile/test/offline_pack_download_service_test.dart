import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/offline_packs/models/lesson_pack_model.dart';
import 'package:mobile/features/offline_packs/services/offline_pack_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('offline_pack_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  List<int> createTestZip({
    required String slug,
    bool includeMetadata = true,
    bool includeTraversal = false,
  }) {
    final archive = Archive();

    if (includeMetadata) {
      final meta = jsonEncode({
        'slug': slug,
        'version': 1,
        'title_fr': 'Test Pack',
      });
      archive.addFile(ArchiveFile('metadata.json', meta.length, utf8.encode(meta)));
      archive.addFile(ArchiveFile('manifest.json', meta.length, utf8.encode(meta)));
      archive.addFile(ArchiveFile('units.json', 2, utf8.encode('[]')));
    }

    if (includeTraversal) {
      archive.addFile(ArchiveFile('../../evil.txt', 4, utf8.encode('evil')));
    }

    return ZipEncoder().encode(archive)!;
  }

  group('OfflinePackDownloadService (A05 Security & Validation)', () {
    test('downloadAndExtract verifies SHA-256 and installs valid pack', () async {
      final zipBytes = createTestZip(slug: 'test-pack');
      final validChecksum = sha256.convert(zipBytes).toString();

      final mockClient = MockClient((request) async {
        return http.Response.bytes(zipBytes, 200);
      });

      final service = OfflinePackDownloadService(client: mockClient);

      final pack = LessonPackModel(
        id: 1,
        titleFr: 'Test Pack',
        titleEn: 'Test Pack',
        titleAr: 'حزمة تجريبية',
        slug: 'test-pack',
        descriptionFr: '',
        descriptionEn: '',
        descriptionAr: '',
        level: 'beginner',
        packType: 'normal',
        version: 1,
        fileUrl: 'https://example.com/pack.zip',
        isDownloadable: true,
        manifest: {},
        checksum: validChecksum,
        sizeMb: 0.1,
        itemsCount: 1,
        status: 'published',
        isActive: true,
        isFeatured: false,
        generatedAt: DateTime.now().toIso8601String(),
      );

      await service.downloadAndExtract(pack);

      final isInstalled = await service.isInstalled(pack);
      expect(isInstalled, isTrue);
    });

    test('downloadAndExtract fails when checksum mismatches', () async {
      final zipBytes = createTestZip(slug: 'test-pack');

      final mockClient = MockClient((request) async {
        return http.Response.bytes(zipBytes, 200);
      });

      final service = OfflinePackDownloadService(client: mockClient);

      final pack = LessonPackModel(
        id: 1,
        titleFr: 'Test Pack',
        titleEn: 'Test Pack',
        titleAr: 'حزمة تجريبية',
        slug: 'test-pack',
        descriptionFr: '',
        descriptionEn: '',
        descriptionAr: '',
        level: 'beginner',
        packType: 'normal',
        version: 1,
        fileUrl: 'https://example.com/pack.zip',
        isDownloadable: true,
        manifest: {},
        checksum: 'invalid_sha256_hash_value',
        sizeMb: 0.1,
        itemsCount: 1,
        status: 'published',
        isActive: true,
        isFeatured: false,
        generatedAt: DateTime.now().toIso8601String(),
      );

      expect(
        () async => await service.downloadAndExtract(pack),
        throwsA(isA<Exception>().having((e) => e.toString(), 'error', contains('Checksum mismatch'))),
      );
    });

    test('downloadAndExtract rejects archive with path traversal attempt', () async {
      final zipBytes = createTestZip(slug: 'evil-pack', includeTraversal: true);
      final validChecksum = sha256.convert(zipBytes).toString();

      final mockClient = MockClient((request) async {
        return http.Response.bytes(zipBytes, 200);
      });

      final service = OfflinePackDownloadService(client: mockClient);

      final pack = LessonPackModel(
        id: 2,
        titleFr: 'Evil Pack',
        titleEn: 'Evil Pack',
        titleAr: 'حزمة خبيثة',
        slug: 'evil-pack',
        descriptionFr: '',
        descriptionEn: '',
        descriptionAr: '',
        level: 'beginner',
        packType: 'normal',
        version: 1,
        fileUrl: 'https://example.com/evil.zip',
        isDownloadable: true,
        manifest: {},
        checksum: validChecksum,
        sizeMb: 0.1,
        itemsCount: 1,
        status: 'published',
        isActive: true,
        isFeatured: false,
        generatedAt: DateTime.now().toIso8601String(),
      );

      expect(
        () async => await service.downloadAndExtract(pack),
        throwsA(isA<Exception>().having((e) => e.toString(), 'error', contains('Hostile file path'))),
      );
    });
  });
}
