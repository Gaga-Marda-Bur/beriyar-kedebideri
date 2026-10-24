import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../../core/cache/content_source.dart';
import '../../../core/cache/memory_content_cache.dart';
import '../../../core/storage/app_directories.dart';
import '../models/lesson_pack_model.dart';
import 'local_pack_reader_service.dart';

class OfflinePackDownloadService {
  final http.Client _client;
  final LocalPackReaderService _readerService;

  static const int maxFileCount = 5000;
  static const int maxTotalBytes = 500 * 1024 * 1024; // 500 Mo max décompressé

  OfflinePackDownloadService({
    http.Client? client,
    LocalPackReaderService? readerService,
  })  : _client = client ?? http.Client(),
        _readerService = readerService ?? LocalPackReaderService();

  Future<void> downloadAndExtract(LessonPackModel pack) async {
    if (!pack.isDownloadable || pack.fileUrl.isEmpty) {
      throw Exception('Pack is not downloadable.');
    }

    final zipFile = await AppDirectories.getDownloadedZipFile(
      slug: pack.slug,
      version: pack.version,
    );

    // Téléchargement sécurisé avec délai
    final response = await _client
        .get(Uri.parse(pack.fileUrl))
        .timeout(const Duration(minutes: 5));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Download failed with status: ${response.statusCode}');
    }

    final bytes = response.bodyBytes;

    // 1. Validation de la somme de contrôle SHA-256 (A05)
    if (pack.checksum.isNotEmpty) {
      final actualSha256 = sha256.convert(bytes).toString();
      if (actualSha256.toLowerCase() != pack.checksum.toLowerCase()) {
        throw Exception(
          'Checksum mismatch. Expected ${pack.checksum}, got $actualSha256.',
        );
      }
    }

    await zipFile.writeAsBytes(bytes, flush: true);

    // 2. Extraction sécurisée dans un répertoire de staging temporaire (A05)
    final stagingDir = Directory('${zipFile.parent.path}/${pack.slug}_v${pack.version}_staging_${DateTime.now().millisecondsSinceEpoch}');
    if (await stagingDir.exists()) {
      await stagingDir.delete(recursive: true);
    }
    await stagingDir.create(recursive: true);

    final inputStream = InputFileStream(zipFile.path);
    try {
      final archive = ZipDecoder().decodeBuffer(inputStream);

      if (archive.files.length > maxFileCount) {
        throw Exception('Archive contains too many files (${archive.files.length} > $maxFileCount).');
      }

      int totalExtractedBytes = 0;
      final canonicalStagingPath = p.canonicalize(stagingDir.path);

      for (final file in archive.files) {
        // Validation anti-ZipSlip : normaliser et vérifier que le chemin ne sort pas du staging
        final relativeNormalized = p.normalize(file.name);
        if (p.isAbsolute(relativeNormalized) ||
            relativeNormalized.startsWith('..') ||
            relativeNormalized.contains('/../') ||
            relativeNormalized.contains(r'\..\')) {
          throw Exception('Hostile file path detected in ZIP archive: ${file.name}');
        }

        final destinationPath = p.normalize(p.join(stagingDir.path, relativeNormalized));
        final canonicalDest = p.canonicalize(destinationPath);

        if (!p.isWithin(canonicalStagingPath, canonicalDest) && canonicalDest != canonicalStagingPath) {
          throw Exception('Path traversal attempt outside target folder: ${file.name}');
        }

        if (file.isFile) {
          totalExtractedBytes += file.size;
          if (totalExtractedBytes > maxTotalBytes) {
            throw Exception('Extracted archive size exceeds safety limit of $maxTotalBytes bytes.');
          }

          final outputFile = File(destinationPath);
          await outputFile.parent.create(recursive: true);
          await outputFile.writeAsBytes(
            file.content as List<int>,
            flush: true,
          );
        } else {
          await Directory(destinationPath).create(recursive: true);
        }
      }

      // 3. Validation de structure dans le dossier staging avant bascule atomique
      // Le manifeste ou metadata.json peut se trouver à la racine du ZIP ou dans un sous-dossier slug/
      File? manifestFile = File('${stagingDir.path}/metadata.json');
      if (!await manifestFile.exists()) {
        manifestFile = File('${stagingDir.path}/${pack.slug}/metadata.json');
      }

      if (!await manifestFile.exists()) {
        throw Exception('Invalid pack structure: metadata.json missing in archive.');
      }

      // Si le contenu est niché dans slug/, on promeut son contenu à la racine du staging
      final nestedSlugDir = Directory('${stagingDir.path}/${pack.slug}');
      if (await nestedSlugDir.exists() && File('${nestedSlugDir.path}/metadata.json').existsSync()) {
        for (final entity in nestedSlugDir.listSync()) {
          final targetPath = p.join(stagingDir.path, p.basename(entity.path));
          if (entity is File) {
            await entity.copy(targetPath);
          } else if (entity is Directory) {
            // Copier récursivement
            await _copyDirectory(entity, Directory(targetPath));
          }
        }
      }

      // Marquer le staging comme validé avec local_metadata.json
      final localMetadataFile = File('${stagingDir.path}/local_metadata.json');
      await localMetadataFile.writeAsString(
        jsonEncode({
          'downloaded_at': DateTime.now().toIso8601String(),
          'size_bytes': bytes.length,
          'zip_path': zipFile.path,
          'verified_checksum': pack.checksum,
          'status': 'validated',
        }),
        flush: true,
      );

      // 4. Bascule atomique : remplacer le dossier cible actif uniquement après succès complet
      final targetDir = await AppDirectories.getExtractedPackDirectory(
        slug: pack.slug,
        version: pack.version,
      );

      final backupDir = Directory('${targetDir.parent.path}/${pack.slug}_v${pack.version}_bak_${DateTime.now().millisecondsSinceEpoch}');

      // Si une version existait déjà, on la conserve temporairement en backup
      if (await targetDir.exists()) {
        await targetDir.rename(backupDir.path);
      }

      try {
        await stagingDir.rename(targetDir.path);
        // Succès de la bascule : supprimer le backup
        if (await backupDir.exists()) {
          await backupDir.delete(recursive: true);
        }
      } catch (renameErr) {
        // En cas d'erreur lors du renommage, restaurer l'ancienne version
        if (await backupDir.exists()) {
          await backupDir.rename(targetDir.path);
        }
        rethrow;
      }
    } finally {
      await inputStream.close();
      if (await stagingDir.exists()) {
        try {
          await stagingDir.delete(recursive: true);
        } catch (_) {}
      }
    }

    MemoryContentCache.instance.clear();
    ContentSourceState.instance.clear();

    await _readerService.readPack(
      slug: pack.slug,
      version: pack.version,
    );
  }

  static Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    for (final entity in source.listSync(recursive: false)) {
      final destPath = p.join(destination.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(destPath));
      } else if (entity is File) {
        await entity.copy(destPath);
      }
    }
  }

  Future<bool> isInstalled(LessonPackModel pack) async {
    final dir = await AppDirectories.getExtractedPackDirectory(
      slug: pack.slug,
      version: pack.version,
    );

    final metadataFile = File('${dir.path}/metadata.json');
    final localMetadataFile = File('${dir.path}/local_metadata.json');

    // Vérifie à la fois la présence des métadonnées du pack et de la validation locale (A05)
    if (!await metadataFile.exists() || !await localMetadataFile.exists()) {
      return false;
    }

    try {
      final localJson = jsonDecode(await localMetadataFile.readAsString());
      return localJson is Map && localJson['status'] == 'validated';
    } catch (_) {
      return false;
    }
  }
}
