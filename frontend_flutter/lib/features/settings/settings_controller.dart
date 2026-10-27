import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/settings_local_ds.dart';
import '../../data/providers.dart';

/// 应用设置（语言/主题/种子色/码率偏好），启动时异步加载持久化值。
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final ds = ref.watch(settingsDsProvider);
    ds.load().then((loaded) {
      if (ref.mounted) state = loaded;
    }).catchError((_) {});
    return const AppSettings();
  }

  Future<void> setLocale(String? code) async {
    state = state.copyWith(localeCode: code);
    await ref.read(settingsDsProvider).saveLocale(code);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(settingsDsProvider).saveThemeMode(mode);
  }

  Future<void> setSeedColor(int value) async {
    state = state.copyWith(seedColor: value);
    await ref.read(settingsDsProvider).saveSeedColor(value);
  }

  Future<void> setMinBitrate(int value) async {
    state = state.copyWith(minBitrate: value);
    await ref.read(settingsDsProvider).saveMinBitrate(value);
  }

  /// 保存自定义 API 镜像（host 已归一化；空串 = 恢复自动发现）。
  Future<void> setCustomMirror(String host) async {
    state = state.copyWith(customMirror: host);
    await ref.read(settingsDsProvider).saveCustomMirror(host);
    ref.read(apiServerResolverProvider).resetCustomMirror();
  }

  /// 对讲信令服务器地址（ws:// 或 wss://）。
  Future<void> setIntercomServerUrl(String url) async {
    state = state.copyWith(intercomServerUrl: url.trim());
    await ref.read(settingsDsProvider).saveIntercomServerUrl(url.trim());
  }

  Future<void> setIntercomNickname(String nick) async {
    state = state.copyWith(intercomNickname: nick.trim());
    await ref.read(settingsDsProvider).saveIntercomNickname(nick.trim());
  }

  Future<void> setIntercomTurn({
    required String url,
    required String user,
    required String pass,
  }) async {
    state = state.copyWith(
      intercomTurnUrl: url.trim(),
      intercomTurnUser: user.trim(),
      intercomTurnPass: pass,
    );
    await ref
        .read(settingsDsProvider)
        .saveIntercomTurn(url: url.trim(), user: user.trim(), pass: pass);
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
