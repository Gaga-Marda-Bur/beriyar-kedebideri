import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../../../core/cache/content_source.dart';
import '../../../core/cache/memory_content_cache.dart';
import '../../../core/storage/app_directories.dart';
import '../models/local_pack_model.dart';

class LocalPackReaderService {
  Future<LocalPackModel> readPack({
    required String slug,
    required int version,
  }) async {
    final packDir = await AppDirectories.getExtractedPackDirectory(
      slug: slug,
      version: version,
    );

    return _readFromDirectory(packDir);
  }

  Future<List<LocalPackModel>> listInstalledPacks() async {
    final packsDir = await AppDirectories.getPacksDirectory();

    if (!await packsDir.exists()) return [];

    final dirs = packsDir
        .listSync()
        .whereType<Directory>()
        .where((dir) {
          final name = p.basename(dir.path);
          if (name.contains('_staging_') || name.contains('_bak_')) {
            return false;
          }
          return File('${dir.path}/metadata.json').existsSync();
        })
        .toList();

    final bySlug = <String, LocalPackModel>{};

    for (final dir in dirs) {
      final localMetadata = await _readJsonMap('${dir.path}/local_metadata.json');
      if (localMetadata.containsKey('status') &&
          localMetadata['status'] != 'validated') {
        continue;
      }

      final pack = await _readFromDirectory(dir);
      final key = pack.slug.isNotEmpty ? pack.slug : p.basename(dir.path);
      final existing = bySlug[key];
      if (existing == null || pack.version >= existing.version) {
        bySlug[key] = pack;
      }
    }

    final packs = bySlug.values.toList();
    packs.sort((a, b) => a.slug.compareTo(b.slug));

    return packs;
  }

  Future<LocalPackModel> _readFromDirectory(Directory dir) async {
    final metadata = await _readJsonMap('${dir.path}/metadata.json');
    final localMetadata = await _readJsonMap('${dir.path}/local_metadata.json');

    var sizeBytes = int.tryParse(
          localMetadata['size_bytes']?.toString() ?? '',
        ) ??
        0;

    if (sizeBytes <= 0) {
      sizeBytes = await _directorySize(dir);
    }

    final downloadedAtRaw = localMetadata['downloaded_at']?.toString();

    var downloadedAt = downloadedAtRaw == null || downloadedAtRaw.isEmpty
        ? null
        : DateTime.tryParse(downloadedAtRaw);

    if (downloadedAt == null) {
      try {
        final stat = await dir.stat();
        downloadedAt = stat.modified;
      } catch (_) {
        downloadedAt = null;
      }
    }

    return LocalPackModel(
      metadata: metadata,
      themes: await _readJsonList('${dir.path}/themes.json'),
      units: await _readJsonList('${dir.path}/units.json'),
      characters: await _readJsonList('${dir.path}/characters.json'),
      words: await _readJsonList('${dir.path}/words.json'),
      lessons: await _readJsonList('${dir.path}/lessons.json'),
      quizzes: await _readJsonList('${dir.path}/quizzes.json'),
      localPath: dir.path,
      sizeBytes: sizeBytes,
      downloadedAt: downloadedAt,
    );
  }

  Future<Map<String, dynamic>> _readJsonMap(String path) async {
    final file = File(path);

    if (!await file.exists()) {
      return {};
    }

    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return {};
    } catch (_) {
      return {};
    }
  }

  Future<List<dynamic>> _readJsonList(String path) async {
    final file = File(path);

    if (!await file.exists()) {
      return [];
    }

    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);

      if (decoded is List) {
        return decoded;
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  Future<int> _directorySize(Directory dir) async {
    if (!await dir.exists()) return 0;

    int total = 0;

    await for (final entity in dir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {
          // ignore unreadable files
        }
      }
    }

    return total;
  }

  Future<void> deletePack({
    required String slug,
    required int version,
  }) async {
    final packDir = await AppDirectories.getExtractedPackDirectory(
      slug: slug,
      version: version,
    );

    if (await packDir.exists()) {
      await packDir.delete(recursive: true);
    }

    final zipFile = await AppDirectories.getDownloadedZipFile(
      slug: slug,
      version: version,
    );

    if (await zipFile.exists()) {
      await zipFile.delete();
    }

    MemoryContentCache.instance.clear();
    ContentSourceState.instance.clear();
  }
}
