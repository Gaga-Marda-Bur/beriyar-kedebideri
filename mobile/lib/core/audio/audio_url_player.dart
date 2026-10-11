import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import '../utils/app_logger.dart';

class AudioUrlPlayer {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playUrl(String? url) async {
    if (url == null || url.trim().isEmpty) return;

    final trimmed = url.trim();

    try {
      await _player.stop();

      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        await _player.play(UrlSource(trimmed));
        return;
      }

      if (trimmed.startsWith('assets/')) {
        // audioplayers AssetSource expects relative to assets/ directory
        final assetRel = trimmed.substring(7);
        await _player.play(AssetSource(assetRel));
        return;
      }

      final file = File(trimmed);
      if (await file.exists()) {
        await _player.play(DeviceFileSource(file.path));
        return;
      }

      // Fallback
      await _player.play(DeviceFileSource(trimmed));
    } catch (e, st) {
      AppLogger.error('AudioUrlPlayer.playUrl failed for: $trimmed', error: e, stackTrace: st);
    }
  }

  Future<void> playLocalPath(String? path) async {
    if (path == null || path.trim().isEmpty) return;

    try {
      final file = File(path.trim());
      if (!await file.exists()) return;

      await _player.stop();
      await _player.play(DeviceFileSource(file.path));
    } catch (e, st) {
      AppLogger.error('AudioUrlPlayer.playLocalPath failed for: $path', error: e, stackTrace: st);
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }
}