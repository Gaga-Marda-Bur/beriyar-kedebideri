import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

class AudioUrlPlayer {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playUrl(String? url) async {
    if (url == null || url.isEmpty) return;

    await _player.stop();

    if (url.startsWith('http://') || url.startsWith('https://')) {
      await _player.play(UrlSource(url));
      return;
    }

    await _player.play(DeviceFileSource(url));
  }

  Future<void> playLocalPath(String? path) async {
    if (path == null || path.isEmpty) return;

    final file = File(path);
    if (!await file.exists()) return;

    await _player.stop();
    await _player.play(DeviceFileSource(file.path));
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}