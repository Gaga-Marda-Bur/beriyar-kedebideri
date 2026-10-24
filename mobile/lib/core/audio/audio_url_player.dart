import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../utils/app_logger.dart';

enum AudioPlaybackStatus { idle, loading, playing, paused, failed }

class AudioUrlPlayer {
  static AudioUrlPlayer? _active;
  final AudioPlayer _player;
  final status = ValueNotifier(AudioPlaybackStatus.idle);
  late final StreamSubscription<PlayerState> _subscription;
  int _request = 0;
  bool _disposed = false;

  AudioUrlPlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _subscription = _player.onPlayerStateChanged.listen(
      (state) {
        if (_disposed || status.value == AudioPlaybackStatus.loading) return;
        status.value = switch (state) {
          PlayerState.playing => AudioPlaybackStatus.playing,
          PlayerState.paused => AudioPlaybackStatus.paused,
          _ => AudioPlaybackStatus.idle,
        };
      },
      onError: (Object error) {
        if (!_disposed) status.value = AudioPlaybackStatus.failed;
      },
    );
  }

  Future<void> playUrl(String? url) async {
    if (_disposed) return;
    if (url == null || url.trim().isEmpty) {
      status.value = AudioPlaybackStatus.failed;
      return;
    }
    final request = ++_request;
    final trimmed = url.trim();
    status.value = AudioPlaybackStatus.loading;
    try {
      if (_active != null && _active != this) await _active!.stop();
      _active = this;
      await _player.stop();
      if (_disposed || request != _request) return;
      Source source;
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        source = UrlSource(trimmed);
      } else if (trimmed.startsWith('assets/')) {
        source = AssetSource(trimmed.substring(7));
      } else {
        final file = File(trimmed);
        if (!await file.exists()) {
          throw const FileSystemException('Audio file unavailable');
        }
        source = DeviceFileSource(file.path);
      }
      if (_disposed || request != _request) return;
      await _player.play(source);
      if (!_disposed && request == _request) {
        status.value = AudioPlaybackStatus.playing;
      }
    } catch (error, stack) {
      if (!_disposed && request == _request) {
        status.value = AudioPlaybackStatus.failed;
      }
      AppLogger.error('Audio playback failed', error: error, stackTrace: stack);
    }
  }

  Future<void> playLocalPath(String? path) => playUrl(path);

  Future<void> pause() async {
    ++_request;
    if (_disposed) return;
    try {
      await _player.pause();
      if (!_disposed) status.value = AudioPlaybackStatus.paused;
    } catch (_) {
      if (!_disposed) status.value = AudioPlaybackStatus.failed;
    }
  }

  Future<void> stop() async {
    ++_request;
    if (_disposed) return;
    try {
      await _player.stop();
    } catch (_) {}
    if (!_disposed) status.value = AudioPlaybackStatus.idle;
    if (_active == this) _active = null;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_request;
    if (_active == this) _active = null;
    await _subscription.cancel();
    try {
      await _player.dispose();
    } catch (_) {}
    status.dispose();
  }
}
