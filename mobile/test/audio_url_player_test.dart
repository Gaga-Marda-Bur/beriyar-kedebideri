import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/audio_url_player.dart';

class FakeAudioPlayer implements AudioPlayer {
  final events = StreamController<PlayerState>.broadcast(sync: true);
  bool fail = false;
  int stops = 0;
  Source? lastSource;
  @override
  Stream<PlayerState> get onPlayerStateChanged => events.stream;
  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    if (fail) throw StateError('unavailable');
    lastSource = source;
    events.add(PlayerState.playing);
  }

  @override
  Future<void> stop() async {
    stops++;
    events.add(PlayerState.stopped);
  }

  @override
  Future<void> pause() async {
    events.add(PlayerState.paused);
  }

  @override
  Future<void> dispose() async {
    await events.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('play, pause and completion expose usable playback states', () async {
    final fake = FakeAudioPlayer();
    final player = AudioUrlPlayer(player: fake);
    final seen = <AudioPlaybackStatus>[];
    player.status.addListener(() => seen.add(player.status.value));
    await player.playUrl('https://media.example/voice.mp3');
    expect(fake.lastSource, isA<UrlSource>());
    expect(
      seen,
      containsAllInOrder([
        AudioPlaybackStatus.loading,
        AudioPlaybackStatus.playing,
      ]),
    );
    await player.pause();
    expect(player.status.value, AudioPlaybackStatus.paused);
    fake.events.add(PlayerState.completed);
    expect(player.status.value, AudioPlaybackStatus.idle);
    await player.dispose();
  });
  test(
    'failed playback can be retried and missing local media is explicit',
    () async {
      final fake = FakeAudioPlayer()..fail = true;
      final player = AudioUrlPlayer(player: fake);
      await player.playUrl('https://media.example/voice.mp3');
      expect(player.status.value, AudioPlaybackStatus.failed);
      fake.fail = false;
      await player.playUrl('https://media.example/voice.mp3');
      expect(player.status.value, AudioPlaybackStatus.playing);
      await player.playLocalPath('nonexistent-audit-audio.mp3');
      expect(player.status.value, AudioPlaybackStatus.failed);
      await player.dispose();
    },
  );
  test('starting another screen player stops the previous player', () async {
    final firstFake = FakeAudioPlayer();
    final first = AudioUrlPlayer(player: firstFake);
    final second = AudioUrlPlayer(player: FakeAudioPlayer());
    await first.playUrl('https://media.example/first.mp3');
    final stopsBefore = firstFake.stops;
    await second.playUrl('https://media.example/second.mp3');
    expect(firstFake.stops, greaterThan(stopsBefore));
    expect(first.status.value, AudioPlaybackStatus.idle);
    expect(second.status.value, AudioPlaybackStatus.playing);
    await first.dispose();
    await second.dispose();
  });
}
