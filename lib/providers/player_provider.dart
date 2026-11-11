import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
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

void _initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'rafeeq_radio_audio',
      channelName: 'رفيق راديو',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      autoRunOnBoot: false,
    ),
  );
}

Future<void> _startForegroundTask(String stationName) async {
  if (await FlutterForegroundTask.isRunningService) {
    await FlutterForegroundTask.updateService(
      notificationTitle: 'رفيق راديو',
      notificationText: stationName,
    );
  } else {
    await FlutterForegroundTask.startService(
      notificationTitle: 'رفيق راديو',
      notificationText: stationName,
    );
  }
}

Future<void> _stopForegroundTask() async {
  if (await FlutterForegroundTask.isRunningService) {
    await FlutterForegroundTask.stopService();
  }
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  final AudioPlayer _player = AudioPlayer();
  final Ref _ref;
  Timer? _sleepTimer;

  PlayerNotifier(this._ref) : super(const PlayerState()) {
    _initForegroundTask();

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

    _player.playbackEventStream.listen((_) {}, onError: (e) {
      state = state.copyWith(loading: false, error: 'تعذّر تشغيل المحطة');
    });
  }

  Future<void> play(Station station) async {
    state = state.copyWith(station: station, loading: true, clearError: true);
    _ref.read(storageServiceProvider).addRecent(station);

    bool started = false;
    for (final url in station.streamUrls) {
      try {
        await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
        await _player.play();
        started = true;
        if (station.uuid != null) {
          _ref.read(radioServiceProvider).reportClick(station.uuid!);
        }
        await _startForegroundTask(station.name);
        break;
      } catch (_) {}
    }

    if (!started) {
      state = state.copyWith(
          loading: false, error: 'تعذّر تشغيل المحطة', clearStation: false);
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
      state = state.copyWith(playing: false);
      await _stopForegroundTask();
    } else {
      await _player.play();
      state = state.copyWith(playing: true);
      if (state.station != null) {
        await _startForegroundTask(state.station!.name);
      }
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
        _stopForegroundTask();
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
    _stopForegroundTask();
    super.dispose();
  }
}

final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>(
  (ref) => PlayerNotifier(ref),
);
