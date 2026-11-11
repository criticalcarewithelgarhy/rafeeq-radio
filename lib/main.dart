import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    return true; // prevent crash, keep app alive
  };
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'uk.elgarhy.rafeeq.radio.channel.audio',
      androidNotificationChannelName: 'رفيق راديو',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
    );
  } catch (_) {}
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0d1220),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const ProviderScope(child: RafeeqApp()));
}
