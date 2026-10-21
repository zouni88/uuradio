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
  });

  /// null = 跟随系统。
  final String? localeCode;
  final AppThemeMode themeMode;
  final int seedColor;

  /// 0 = 不限码率。
  final int minBitrate;

  /// 空串 = 自动发现 API 服务器。
  final String customMirror;

  AppSettings copyWith({
    Object? localeCode = _sentinel,
    AppThemeMode? themeMode,
    int? seedColor,
    int? minBitrate,
    String? customMirror,
  }) {
    return AppSettings(
      localeCode: localeCode == _sentinel
          ? this.localeCode
          : localeCode as String?,
      themeMode: themeMode ?? this.themeMode,
      seedColor: seedColor ?? this.seedColor,
      minBitrate: minBitrate ?? this.minBitrate,
      customMirror: customMirror ?? this.customMirror,
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

  Future<String> loadSelectedCountry() async =>
      await _prefs.getString(_kSelectedCountry) ?? '';

  Future<void> saveSelectedCountry(String code) async {
    if (code.isEmpty) {
      await _prefs.remove(_kSelectedCountry);
    } else {
      await _prefs.setString(_kSelectedCountry, code);
    }
  }
}
