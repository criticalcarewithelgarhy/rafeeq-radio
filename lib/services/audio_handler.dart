import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;

class RadioAudioHandler extends BaseAudioHandler {
  final _player = ja.AudioPlayer();

  RadioAudioHandler() {
    _player.playerStateStream.listen((ps) {
      final processingState = switch (ps.processingState) {
        ja.ProcessingState.idle => AudioProcessingState.idle,
        ja.ProcessingState.loading => AudioProcessingState.loading,
        ja.ProcessingState.buffering => AudioProcessingState.buffering,
        ja.ProcessingState.ready => AudioProcessingState.ready,
        ja.ProcessingState.completed => AudioProcessingState.completed,
      };
      playbackState.add(playbackState.value.copyWith(
        controls: [
          ps.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
        ],
        systemActions: const {MediaAction.stop},
        androidCompactActionIndices: const [0],
        processingState: processingState,
        playing: ps.playing,
      ));
    });
  }

  Future<void> playUrl(String url, MediaItem item) async {
    mediaItem.add(item);
    await _player.setAudioSource(ja.AudioSource.uri(Uri.parse(url)));
    await _player.play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
    ));
    await super.stop();
  }

  Stream<ja.PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<ja.PlaybackEvent> get playbackEventStream => _player.playbackEventStream;
  bool get isPlaying => _player.playing;
}

final audioHandlerProvider = Provider<RadioAudioHandler>(
  (ref) => throw UnimplementedError(),
);
