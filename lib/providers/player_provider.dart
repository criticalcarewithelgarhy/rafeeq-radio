import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/station.dart';
import '../services/media_session_service.dart';
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
    _initForegroundTask();
    FlutterForegroundTask.addTaskDataCallback(_onNotificationButton);

    // Wire lock screen / notification media button callbacks
    _ref.read(mediaSessionServiceProvider).onToggle = () => togglePlayPause();

    _player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.ready) {
        state = state.copyWith(
            loading: false, playing: ps.playing, clearError: true);
        _updateNotification();
        _ref.read(mediaSessionServiceProvider).updateState(ps.playing);
      } else if (ps.processingState == ProcessingState.loading ||
          ps.processingState == ProcessingState.buffering) {
        state = state.copyWith(loading: true);
      } else if (ps.processingState == ProcessingState.completed ||
          ps.processingState == ProcessingState.idle) {
        state = state.copyWith(playing: false, loading: false);
        _updateNotification();
        _ref.read(mediaSessionServiceProvider).updateState(false);
      }
    });

    _player.playbackEventStream.listen((_) {}, onError: (e) {
      state = state.copyWith(loading: false, error: 'تعذّر تشغيل المحطة');
    });
  }

  void _onNotificationButton(dynamic data) {
    if (data == 'toggle') togglePlayPause();
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

  Future<void> _startForegroundTask(String stationName, bool playing) async {
    final text = playing ? '▶ يعزف الآن' : '⏸ متوقف';
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: stationName,
        notificationText: text,
      );
    } else {
      await FlutterForegroundTask.startService(
        notificationTitle: stationName,
        notificationText: text,
      );
    }
  }

  Future<void> _updateNotification() async {
    final station = state.station;
    if (station == null) return;
    if (!await FlutterForegroundTask.isRunningService) return;
    final text = state.playing ? '▶ يعزف الآن' : '⏸ متوقف';
    await FlutterForegroundTask.updateService(
      notificationTitle: station.name,
      notificationText: text,
    );
  }

  Future<void> _stopForegroundTask() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
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
        await _startForegroundTask(station.name, true);
        _ref.read(mediaSessionServiceProvider).updateMetadata(station.name);
        _ref.read(mediaSessionServiceProvider).updateState(true);
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
      await _updateNotification();
      _ref.read(mediaSessionServiceProvider).updateState(false);
    } else {
      await _player.play();
      state = state.copyWith(playing: true);
      await _updateNotification();
      _ref.read(mediaSessionServiceProvider).updateState(true);
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
    FlutterForegroundTask.removeTaskDataCallback(_onNotificationButton);
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
