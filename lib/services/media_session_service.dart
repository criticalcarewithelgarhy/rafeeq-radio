import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MediaSessionService {
  static const _channel = MethodChannel('com.rafeeq.radio/media_session');

  void Function()? onToggle;

  MediaSessionService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onToggle') onToggle?.call();
    });
  }

  Future<void> updateMetadata(String title) async {
    try {
      await _channel.invokeMethod('updateMetadata', {'title': title});
    } catch (_) {}
  }

  Future<void> updateState(bool playing) async {
    try {
      await _channel.invokeMethod('updateState', {'playing': playing});
    } catch (_) {}
  }
}

final mediaSessionServiceProvider =
    Provider((ref) => MediaSessionService());
