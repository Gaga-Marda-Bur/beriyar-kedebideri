import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AppDirectories {
  static Future<Directory> getAppRootDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir;
  }

  static Future<Directory> getPacksDirectory() async {
    final root = await getAppRootDirectory();
    final packsDir = Directory('${root.path}/offline_packs');

    if (!await packsDir.exists()) {
      await packsDir.create(recursive: true);
    }

    return packsDir;
  }

  static Future<Directory> getExtractedPackDirectory({
    required String slug,
    required int version,
  }) async {
    final packsDir = await getPacksDirectory();
    final dir = Directory('${packsDir.path}/${slug}_v$version');

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  static Future<File> getDownloadedZipFile({
    required String slug,
    required int version,
  }) async {
    final packsDir = await getPacksDirectory();
    return File('${packsDir.path}/${slug}_v$version.zip');
  }
}