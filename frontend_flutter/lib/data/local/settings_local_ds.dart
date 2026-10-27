import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';

/// 主题模式。
enum AppThemeMode { system, light, dark }

/// 应用设置值对象。
class AppSettings {
  const AppSettings({
    this.localeCode,
    this.themeMode = AppThemeMode.system,
    this.seedColor = AppTheme.defaultSeedValue,
    this.minBitrate = 0,
    this.customMirror = '',
    this.intercomServerUrl = '',
    this.intercomNickname = '',
    this.intercomTurnUrl = '',
    this.intercomTurnUser = '',
    this.intercomTurnPass = '',
  });

  /// null = 跟随系统。
  final String? localeCode;
  final AppThemeMode themeMode;
  final int seedColor;

  /// 0 = 不限码率。
  final int minBitrate;

  /// 空串 = 自动发现 API 服务器。
  final String customMirror;

  /// 对讲信令服务器 ws:// 或 wss:// 地址，空串 = 未配置。
  final String intercomServerUrl;
  final String intercomNickname;

  /// TURN 中继（可选，蜂窝 CGNAT 兜底）。
  final String intercomTurnUrl;
  final String intercomTurnUser;
  final String intercomTurnPass;

  AppSettings copyWith({
    Object? localeCode = _sentinel,
    AppThemeMode? themeMode,
    int? seedColor,
    int? minBitrate,
    String? customMirror,
    String? intercomServerUrl,
    String? intercomNickname,
    String? intercomTurnUrl,
    String? intercomTurnUser,
    String? intercomTurnPass,
  }) {
    return AppSettings(
      localeCode: localeCode == _sentinel
          ? this.localeCode
          : localeCode as String?,
      themeMode: themeMode ?? this.themeMode,
      seedColor: seedColor ?? this.seedColor,
      minBitrate: minBitrate ?? this.minBitrate,
      customMirror: customMirror ?? this.customMirror,
      intercomServerUrl: intercomServerUrl ?? this.intercomServerUrl,
      intercomNickname: intercomNickname ?? this.intercomNickname,
      intercomTurnUrl: intercomTurnUrl ?? this.intercomTurnUrl,
      intercomTurnUser: intercomTurnUser ?? this.intercomTurnUser,
      intercomTurnPass: intercomTurnPass ?? this.intercomTurnPass,
    );
  }

  static const Object _sentinel = Object();
}

/// 设置持久化（SharedPreferences）。
class SettingsLocalDs {
  SettingsLocalDs(this._prefs);

  final SharedPreferencesAsync _prefs;

  static const _kLocale = 'locale_code';
  static const _kThemeMode = 'theme_mode';
  static const _kSeedColor = 'seed_color';
  static const _kMinBitrate = 'min_bitrate';
  static const _kCustomMirror = 'custom_mirror';
  static const _kSelectedCountry = 'selected_country';
  static const _kCountryUsage = 'country_usage';
  static const _kIntercomServer = 'intercom_server_url';
  static const _kIntercomNick = 'intercom_nickname';
  static const _kIntercomTurnUrl = 'intercom_turn_url';
  static const _kIntercomTurnUser = 'intercom_turn_user';
  static const _kIntercomTurnPass = 'intercom_turn_pass';

  /// 读取全部持久化值；旧版 Material 种子色一次性迁移到霓虹青。
  Future<AppSettings> load() async {
    final themeIndex = await _prefs.getInt(_kThemeMode) ?? 0;
    var seed = await _prefs.getInt(_kSeedColor) ?? AppTheme.defaultSeedValue;
    if (seed == AppTheme.legacySeedValue) {
      seed = AppTheme.defaultSeedValue;
      await _prefs.setInt(_kSeedColor, seed);
    }
    return AppSettings(
      localeCode: await _prefs.getString(_kLocale),
      themeMode: AppThemeMode.values[themeIndex.clamp(0, 2)],
      seedColor: seed,
      minBitrate: await _prefs.getInt(_kMinBitrate) ?? 0,
      customMirror: await _prefs.getString(_kCustomMirror) ?? '',
      intercomServerUrl: await _prefs.getString(_kIntercomServer) ?? '',
      intercomNickname: await _prefs.getString(_kIntercomNick) ?? '',
      intercomTurnUrl: await _prefs.getString(_kIntercomTurnUrl) ?? '',
      intercomTurnUser: await _prefs.getString(_kIntercomTurnUser) ?? '',
      intercomTurnPass: await _prefs.getString(_kIntercomTurnPass) ?? '',
    );
  }

  Future<void> saveLocale(String? code) async {
    if (code == null) {
      await _prefs.remove(_kLocale);
    } else {
      await _prefs.setString(_kLocale, code);
    }
  }

  Future<void> saveThemeMode(AppThemeMode mode) =>
      _prefs.setInt(_kThemeMode, mode.index);

  Future<void> saveSeedColor(int value) => _prefs.setInt(_kSeedColor, value);

  Future<void> saveMinBitrate(int value) =>
      _prefs.setInt(_kMinBitrate, value);

  Future<void> saveCustomMirror(String host) =>
      _prefs.setString(_kCustomMirror, host);

  Future<void> saveIntercomServerUrl(String url) =>
      _prefs.setString(_kIntercomServer, url);

  Future<void> saveIntercomNickname(String nick) =>
      _prefs.setString(_kIntercomNick, nick);

  Future<void> saveIntercomTurn({
    required String url,
    required String user,
    required String pass,
  }) async {
    await _prefs.setString(_kIntercomTurnUrl, url);
    await _prefs.setString(_kIntercomTurnUser, user);
    await _prefs.setString(_kIntercomTurnPass, pass);
  }

  Future<String> loadSelectedCountry() async =>
      await _prefs.getString(_kSelectedCountry) ?? '';

  Future<void> saveSelectedCountry(String code) async {
    if (code.isEmpty) {
      await _prefs.remove(_kSelectedCountry);
    } else {
      await _prefs.setString(_kSelectedCountry, code);
    }
  }

  /// 国家选择页使用频次（ISO 码 -> 选择次数）。
  Future<Map<String, int>> loadCountryUsage() async {
    final raw = await _prefs.getString(_kCountryUsage);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries) e.key: (e.value as num).toInt(),
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> recordCountryUsage(String code) async {
    if (code.isEmpty) return;
    final usage = await loadCountryUsage();
    await _prefs.setString(
      _kCountryUsage,
      jsonEncode({...usage, code: (usage[code] ?? 0) + 1}),
    );
  }
}
