import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/local/record_local_ds.dart';
import 'data/local/settings_local_ds.dart';
import 'data/providers.dart';
import 'features/player/audio_handler.dart';
import 'features/player/player_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 本地存储
  await Hive.initFlutter();
  await Hive.openBox<String>(HiveBoxes.favorites);
  await Hive.openBox<String>(HiveBoxes.history);
  await Hive.openBox<String>(HiveBoxes.browseCache);
  final settingsDs = SettingsLocalDs(SharedPreferencesAsync());

  // 音频会话：iOS 后台播放/锁屏控制必需；Android 侧等价设置 usage/contentType
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  // 后台播放服务（通知栏/线控/音频焦点）
  final handler = await AudioService.init(
    builder: () => RadioAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.uunas.uuradio.playback',
      androidNotificationChannelName: 'UURadio',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(handler),
        settingsDsProvider.overrideWithValue(settingsDs),
      ],
      child: const IradioApp(),
    ),
  );
}
