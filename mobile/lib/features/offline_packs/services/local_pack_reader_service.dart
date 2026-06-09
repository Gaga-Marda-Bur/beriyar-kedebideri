import 'dart:convert';
import 'dart:io';

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
        .where((dir) => File('${dir.path}/metadata.json').existsSync())
        .toList();

    final packs = <LocalPackModel>[];

    for (final dir in dirs) {
      packs.add(await _readFromDirectory(dir));
    }

    packs.sort((a, b) => a.slug.compareTo(b.slug));

    return packs;
  }

  Future<LocalPackModel> _readFromDirectory(Directory dir) async {
    final metadata = await _readJsonMap('${dir.path}/metadata.json');

    return LocalPackModel(
      metadata: metadata,
      themes: await _readJsonList('${dir.path}/themes.json'),
      units: await _readJsonList('${dir.path}/units.json'),
      characters: await _readJsonList('${dir.path}/characters.json'),
      words: await _readJsonList('${dir.path}/words.json'),
      lessons: await _readJsonList('${dir.path}/lessons.json'),
      quizzes: await _readJsonList('${dir.path}/quizzes.json'),
      localPath: dir.path,
    );
  }

  Future<Map<String, dynamic>> _readJsonMap(String path) async {
    final file = File(path);

    if (!await file.exists()) {
      return {};
    }

    final content = await file.readAsString();
    final decoded = jsonDecode(content);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {};
  }

  Future<List<dynamic>> _readJsonList(String path) async {
    final file = File(path);

    if (!await file.exists()) {
      return [];
    }

    final content = await file.readAsString();
    final decoded = jsonDecode(content);

    if (decoded is List) {
      return decoded;
    }

    return [];
  }
}