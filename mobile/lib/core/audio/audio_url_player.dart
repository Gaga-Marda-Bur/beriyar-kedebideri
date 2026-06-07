import 'package:audioplayers/audioplayers.dart';

class AudioUrlPlayer {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playUrl(String? url) async {
    if (url == null || url.isEmpty) return;

    await _player.stop();
    await _player.play(UrlSource(url));
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}