import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'playback/player_handler.dart';
import 'ui/music_app.dart';

late final PlayerHandler playerHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  playerHandler = await AudioService.init<PlayerHandler>(
    builder: PlayerHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.musica.player',
      androidNotificationChannelName: 'Reproducción de música',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  runApp(const MusicaApp());
}
