import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/station.dart';
import '../services/radio_service.dart';
import '../services/storage_service.dart';

class PlayerState {
  final Station? station;
  final bool playing;
  final bool loading;
  final String? error;
  final Duration? sleepRemaining;

  const PlayerState({
    this.station,
    this.playing = false,
    this.loading = false,
    this.error,
    this.sleepRemaining,
  });

  PlayerState copyWith({
    Station? station,
    bool? playing,
    bool? loading,
    String? error,
    Duration? sleepRemaining,
    bool clearError = false,
    bool clearSleep = false,
    bool clearStation = false,
  }) =>
      PlayerState(
        station: clearStation ? null : (station ?? this.station),
        playing: playing ?? this.playing,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        sleepRemaining:
            clearSleep ? null : (sleepRemaining ?? this.sleepRemaining),
      );
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  final AudioPlayer _player = AudioPlayer();
  final Ref _ref;
  Timer? _sleepTimer;

  PlayerNotifier(this._ref) : super(const PlayerState()) {
    _player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.ready) {
        state = state.copyWith(
            loading: false, playing: ps.playing, clearError: true);
      } else if (ps.processingState == ProcessingState.loading ||
          ps.processingState == ProcessingState.buffering) {
        state = state.copyWith(loading: true);
      } else if (ps.processingState == ProcessingState.completed ||
          ps.processingState == ProcessingState.idle) {
        state = state.copyWith(playing: false, loading: false);
      }
    });
  }

  Future<void> play(Station station) async {
    state = state.copyWith(station: station, loading: true, clearError: true);
    _ref.read(storageServiceProvider).addRecent(station);

    for (final url in station.streamUrls) {
      try {
        await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
        // Wait for ready or error; just_audio play() doesn't throw on stream failure
        final ready = await _player.playerStateStream
            .firstWhere((ps) =>
                ps.processingState == ProcessingState.ready ||
                ps.processingState == ProcessingState.idle)
            .timeout(const Duration(seconds: 15));
        if (ready.processingState == ProcessingState.ready) {
          await _player.play();
          if (station.uuid != null) {
            _ref.read(radioServiceProvider).reportClick(station.uuid!);
          }
          return;
        }
      } catch (_) {}
    }
    state = state.copyWith(
        loading: false, error: 'تعذّر تشغيل المحطة', clearStation: false);
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
      state = state.copyWith(playing: false);
    } else {
      await _player.play();
      state = state.copyWith(playing: true);
    }
  }

  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    state = state.copyWith(sleepRemaining: duration);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final remaining = state.sleepRemaining;
      if (remaining == null || remaining.inSeconds <= 0) {
        t.cancel();
        _player.pause();
        state = state.copyWith(playing: false, clearSleep: true);
        return;
      }
      state = state.copyWith(
          sleepRemaining: remaining - const Duration(seconds: 1));
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    state = state.copyWith(clearSleep: true);
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}

final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>(
  (ref) => PlayerNotifier(ref),
);
