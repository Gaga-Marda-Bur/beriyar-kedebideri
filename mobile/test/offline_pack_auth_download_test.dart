import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api/api_config.dart';
import 'package:mobile/core/auth/learner_auth_service.dart';
import 'package:mobile/core/auth/learner_auth_vault.dart';
import 'package:mobile/features/offline_packs/models/lesson_pack_model.dart';
import 'package:mobile/features/offline_packs/services/offline_pack_download_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<int> _buildMinimalZip() {
  final archive = Archive()
    ..addFile(ArchiveFile.string('manifest.json', jsonEncode({'units': []})))
    ..addFile(ArchiveFile.string('metadata.json', jsonEncode({'units': []})))
    ..addFile(ArchiveFile.string('themes.json', '[]'))
    ..addFile(ArchiveFile.string('units.json', '[]'))
    ..addFile(ArchiveFile.string('characters.json', '[]'))
    ..addFile(ArchiveFile.string('words.json', '[]'))
    ..addFile(ArchiveFile.string('lessons.json', '[]'))
    ..addFile(ArchiveFile.string('quizzes.json', '[]'));
  return ZipEncoder().encode(archive)!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('bk_pack_dl_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      return tempDir.path;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<LearnerAuthService> buildAuthenticatedService({
    required Future<http.Response> Function(http.Request) onDownload,
    List<Map<String, String>>? capturedHeaders,
  }) async {
    final vault = InMemoryLearnerAuthVault();
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/core/auth/csrf/')) {
        return http.Response(
          jsonEncode({'csrf_token': 'csrf-1'}),
          200,
          headers: {'set-cookie': 'csrftoken=csrf-1; Path=/'},
        );
      }
      if (request.url.path.endsWith('/core/auth/login/')) {
        return http.Response(
          jsonEncode({
            'authenticated': true,
            'user_id': 7,
            'username': 'pilot_1',
            'is_pilot': true,
            'is_staff': false,
            'csrf_token': 'csrf-2',
          }),
          200,
          headers: {'set-cookie': 'sessionid=pilot-sess-123; Path=/'},
        );
      }
      capturedHeaders?.add(Map<String, String>.from(request.headers));
      return onDownload(request);
    });

    final authService = LearnerAuthService(
      vault: vault,
      client: mockClient,
      cleanupUserData: () async {},
    );
    await authService.login('pilot_1', 'Pass123!');
    return authService;
  }

  test('attaches session Cookie only for same-origin API pack downloads', () async {
    final zipBytes = _buildMinimalZip();
    final checksum = sha256.convert(zipBytes).toString();
    final capturedHeaders = <Map<String, String>>[];

    final mockDownloadClient = MockClient((request) async {
      capturedHeaders.add(Map<String, String>.from(request.headers));
      return http.Response.bytes(zipBytes, 200);
    });

    final authService = await buildAuthenticatedService(
      onDownload: (req) async => http.Response.bytes(zipBytes, 200),
    );

    final service = OfflinePackDownloadService(
      client: mockDownloadClient,
      authService: authService,
    );

    final sameOriginUrl = '${ApiConfig.baseUrl}/offline-packs/1/download/';
    final privatePack = LessonPackModel(
      id: 1,
      titleFr: 'Pack Pilote',
      titleEn: '',
      titleAr: '',
      slug: 'pilot-erf-pack',
      descriptionFr: '',
      descriptionEn: '',
      descriptionAr: '',
      level: 'beginner',
      packType: 'normal',
      version: 1,
      fileUrl: sameOriginUrl,
      isDownloadable: true,
      manifest: const {},
      checksum: checksum,
      sizeMb: 0.01,
      itemsCount: 1,
      status: 'validated',
      isActive: true,
      isFeatured: false,
      generatedAt: '',
    );

    await service.downloadAndExtract(privatePack);
    expect(capturedHeaders.single['Cookie'], contains('sessionid=pilot-sess-123'));

    capturedHeaders.clear();
    final externalPack = LessonPackModel(
      id: 2,
      titleFr: 'Pack Public CDN',
      titleEn: '',
      titleAr: '',
      slug: 'public-cdn-pack',
      descriptionFr: '',
      descriptionEn: '',
      descriptionAr: '',
      level: 'beginner',
      packType: 'normal',
      version: 1,
      fileUrl: 'https://media.beriyarkedebideri.com/media/offline_packs/files/public.zip',
      isDownloadable: true,
      manifest: const {},
      checksum: checksum,
      sizeMb: 0.01,
      itemsCount: 1,
      status: 'published',
      isActive: true,
      isFeatured: false,
      generatedAt: '',
    );

    await service.downloadAndExtract(externalPack);
    expect(capturedHeaders.single.containsKey('Cookie'), isFalse);
  });

  test('401 on same-origin private pack download invalidates session', () async {
    final mockDownloadClient = MockClient((request) async {
      return http.Response('Unauthorized', 401);
    });

    final authService = await buildAuthenticatedService(
      onDownload: (req) async => http.Response('Unauthorized', 401),
    );
    expect(authService.isAuthenticated, isTrue);

    final service = OfflinePackDownloadService(
      client: mockDownloadClient,
      authService: authService,
    );

    final pack = LessonPackModel(
      id: 1,
      titleFr: 'Pack Pilote',
      titleEn: '',
      titleAr: '',
      slug: 'pilot-erf-pack',
      descriptionFr: '',
      descriptionEn: '',
      descriptionAr: '',
      level: 'beginner',
      packType: 'normal',
      version: 1,
      fileUrl: '${ApiConfig.baseUrl}/offline-packs/1/download/',
      isDownloadable: true,
      manifest: const {},
      checksum: '',
      sizeMb: 0.01,
      itemsCount: 1,
      status: 'validated',
      isActive: true,
      isFeatured: false,
      generatedAt: '',
    );

    await expectLater(
      service.downloadAndExtract(pack),
      throwsException,
    );
    expect(authService.isAuthenticated, isFalse);
  });

  test('resolves relative URL as same-origin and strips Cookie on cross-origin redirect', () async {
    final zipBytes = _buildMinimalZip();
    final checksum = sha256.convert(zipBytes).toString();
    final requestsLog = <Map<String, dynamic>>[];

    final mockDownloadClient = MockClient((request) async {
      requestsLog.add({
        'url': request.url.toString(),
        'cookie': request.headers['Cookie'],
        'followRedirects': request.followRedirects,
      });
      if (request.url.host == Uri.parse(ApiConfig.baseUrl).host &&
          request.url.path == '/api/offline-packs/9/download/') {
        return http.Response(
          '',
          302,
          headers: {'location': 'https://cdn.other-origin.example/pack.zip'},
        );
      }
      if (request.url.host == 'cdn.other-origin.example') {
        return http.Response.bytes(zipBytes, 200);
      }
      return http.Response.bytes(zipBytes, 200);
    });

    final authService = await buildAuthenticatedService(
      onDownload: (req) async => http.Response.bytes(zipBytes, 200),
    );
    final service = OfflinePackDownloadService(
      client: mockDownloadClient,
      authService: authService,
    );

    LessonPackModel makePack(String url, String slug) => LessonPackModel(
          id: 9,
          titleFr: 'Pack Test',
          titleEn: '',
          titleAr: '',
          slug: slug,
          descriptionFr: '',
          descriptionEn: '',
          descriptionAr: '',
          level: 'beginner',
          packType: 'normal',
          version: 1,
          fileUrl: url,
          isDownloadable: true,
          manifest: const {},
          checksum: checksum,
          sizeMb: 0.01,
          itemsCount: 1,
          status: 'validated',
          isActive: true,
          isFeatured: false,
          generatedAt: '',
        );

    // 1) Relative URL -> resolved against ApiConfig.baseUrl, sends Cookie
    await service.downloadAndExtract(
      makePack('/api/offline-packs/1/download/', 'rel-pack'),
    );
    expect(requestsLog.last['cookie'], contains('sessionid=pilot-sess-123'));

    // 2) Cross-origin redirect -> Cookie sent on hop 1, stripped on hop 2
    requestsLog.clear();
    await service.downloadAndExtract(
      makePack('/api/offline-packs/9/download/', 'redir-pack'),
    );
    expect(requestsLog.length, 2);
    expect(requestsLog[0]['followRedirects'], isFalse);
    expect(requestsLog[0]['cookie'], contains('sessionid=pilot-sess-123'));
    expect(requestsLog[1]['url'], 'https://cdn.other-origin.example/pack.zip');
    expect(requestsLog[1]['cookie'], isNull);
  });

  test('handles HTTP 403, interrupted download, and incomplete ZIP without corrupting local state', () async {
    final authService = await buildAuthenticatedService(
      onDownload: (req) async => http.Response('Forbidden', 403),
    );

    LessonPackModel makePack(String slug, {String checksum = ''}) => LessonPackModel(
          id: 10,
          titleFr: 'Pack Erreur',
          titleEn: '',
          titleAr: '',
          slug: slug,
          descriptionFr: '',
          descriptionEn: '',
          descriptionAr: '',
          level: 'beginner',
          packType: 'normal',
          version: 1,
          fileUrl: '${ApiConfig.baseUrl}/offline-packs/10/download/',
          isDownloadable: true,
          manifest: const {},
          checksum: checksum,
          sizeMb: 0.01,
          itemsCount: 1,
          status: 'validated',
          isActive: true,
          isFeatured: false,
          generatedAt: '',
        );

    // HTTP 403
    final service403 = OfflinePackDownloadService(
      client: MockClient((_) async => http.Response('Forbidden', 403)),
      authService: authService,
    );
    await expectLater(
      service403.downloadAndExtract(makePack('pack-403')),
      throwsException,
    );
    expect(authService.isAuthenticated, isTrue);

    // Interrupted download (network drop)
    final serviceDrop = OfflinePackDownloadService(
      client: MockClient((_) async => throw const SocketException('Connection reset')),
      authService: authService,
    );
    await expectLater(
      serviceDrop.downloadAndExtract(makePack('pack-drop')),
      throwsA(isA<SocketException>()),
    );

    // Incomplete ZIP (truncated bytes, even without checksum)
    final partialZip = _buildMinimalZip().sublist(0, 12);
    final serviceIncompleteZip = OfflinePackDownloadService(
      client: MockClient((_) async => http.Response.bytes(partialZip, 200)),
      authService: authService,
    );
    await expectLater(
      serviceIncompleteZip.downloadAndExtract(makePack('pack-incomplete')),
      throwsException,
    );
    expect(
      File('${tempDir.path}/offline_packs/pack-incomplete/local_metadata.json').existsSync(),
      isFalse,
    );
  });
}
