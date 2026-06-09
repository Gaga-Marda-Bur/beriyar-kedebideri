import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;

import '../../../core/storage/app_directories.dart';
import '../models/lesson_pack_model.dart';
import 'local_pack_reader_service.dart';

class OfflinePackDownloadService {
  final http.Client _client;
  final LocalPackReaderService _readerService;

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

    final response = await _client.get(Uri.parse(pack.fileUrl));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Download failed: ${response.statusCode}');
    }

    await zipFile.writeAsBytes(response.bodyBytes, flush: true);

    final extractedDir = await AppDirectories.getExtractedPackDirectory(
      slug: pack.slug,
      version: pack.version,
    );

    if (await extractedDir.exists()) {
      await extractedDir.delete(recursive: true);
    }

    await extractedDir.create(recursive: true);

    final inputStream = InputFileStream(zipFile.path);
    final archive = ZipDecoder().decodeBuffer(inputStream);

    for (final file in archive.files) {
      final outputPath = '${extractedDir.path}/${file.name}';

      if (file.isFile) {
        final outputFile = File(outputPath);
        await outputFile.parent.create(recursive: true);
        await outputFile.writeAsBytes(file.content as List<int>, flush: true);
      } else {
        await Directory(outputPath).create(recursive: true);
      }
    }

    await inputStream.close();

    await _readerService.readPack(
      slug: pack.slug,
      version: pack.version,
    );
  }

  Future<bool> isInstalled(LessonPackModel pack) async {
    final dir = await AppDirectories.getExtractedPackDirectory(
      slug: pack.slug,
      version: pack.version,
    );

    final metadataFile = File('${dir.path}/metadata.json');
    return metadataFile.exists();
  }
}