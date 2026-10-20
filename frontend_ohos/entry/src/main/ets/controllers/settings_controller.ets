// 应用设置（语言/主题/主题色/码率偏好/发现页国家），启动时异步加载持久化值。
// 对齐 Flutter settings_controller.dart + SelectedCountryController。
import { Prefs, PrefKeys } from '../core/prefs';
import { DEFAULT_ACCENT, LEGACY_ACCENT } from '../core/theme';
import { setL10nLang, Lang } from '../core/l10n';
import { i18n } from '@kit.LocalizationKit';

export enum ThemeMode {
  system,
  light,
  dark
}

function themeModeFromString(raw: string): ThemeMode {
  if (raw === 'system') {
    return ThemeMode.system;
  }
  if (raw === 'light') {
    return ThemeMode.light;
  }
  return ThemeMode.dark; // 默认进入霓虹暗夜
}

function themeModeToString(mode: ThemeMode): string {
  return mode === ThemeMode.system ? 'system' : (mode === ThemeMode.light ? 'light' : 'dark');
}

export class SettingsController {
  private static instance: SettingsController | null = null;

  static inst(): SettingsController {
    if (SettingsController.instance === null) {
      SettingsController.instance = new SettingsController();
    }
    return SettingsController.instance;
  }

  /// '' = 跟随系统。
  localeCode: string = '';
  themeMode: ThemeMode = ThemeMode.dark;
  seedColor: number = DEFAULT_ACCENT;
  /// 0 = 不限。
  minBitrate: number = 0;
  /// 发现页选中国家码（空 = 跟随设备国家）。
  selectedCountry: string = '';

  private listeners: Set<() => void> = new Set();

  addListener(fn: () => void): void {
    this.listeners.add(fn);
  }

  removeListener(fn: () => void): void {
    this.listeners.delete(fn);
  }

  private notify(): void {
    this.listeners.forEach((fn: () => void) => fn());
  }

  /// 启动加载（EntryAbility 调用）。
  async load(): Promise<void> {
    const locale = await Prefs.getString(PrefKeys.localeCode);
    const mode = await Prefs.getString(PrefKeys.themeMode);
    const seedRaw = await Prefs.getString(PrefKeys.seedColor);
    const bitrateRaw = await Prefs.getString(PrefKeys.minBitrate);
    const country = await Prefs.getString(PrefKeys.selectedCountry);
    this.localeCode = locale ?? '';
    this.themeMode = themeModeFromString(mode ?? '');
    // 旧版 Material 默认种子色一次性迁移为霓虹青。
    let seed = DEFAULT_ACCENT;
    if (seedRaw !== null) {
      const parsed = parseInt(seedRaw, 10);
      if (!isNaN(parsed) && parsed !== LEGACY_ACCENT) {
        seed = parsed;
      }
    }
    this.seedColor = seed;
    this.minBitrate = bitrateRaw !== null ? (parseInt(bitrateRaw, 10) || 0) : 0;
    this.selectedCountry = country ?? '';
    // l10n 语言解析
    this.applyLocale();
  }

  /// 根据设置解析生效语言并写入 l10n（zh/en）。
  applyLocale(): void {
    let lang: Lang;
    if (this.localeCode === 'zh') {
      lang = 'zh';
    } else if (this.localeCode === 'en') {
      lang = 'en';
    } else {
      const sys: string = i18n.System.getSystemLanguage();
      lang = sys.startsWith('zh') ? 'zh' : 'en';
    }
    setL10nLang(lang);
  }

  /// 生效语言（供显示判断）。
  effectiveLang(): Lang {
    if (this.localeCode === 'zh') {
      return 'zh';
    }
    if (this.localeCode === 'en') {
      return 'en';
    }
    return i18n.System.getSystemLanguage().startsWith('zh') ? 'zh' : 'en';
  }

  async setLocale(code: string): Promise<void> {
    this.localeCode = code;
    this.applyLocale();
    this.notify();
    if (code.length === 0) {
      await Prefs.remove(PrefKeys.localeCode);
    } else {
      await Prefs.putString(PrefKeys.localeCode, code);
    }
  }

  async setThemeMode(mode: ThemeMode): Promise<void> {
    this.themeMode = mode;
    this.notify();
    await Prefs.putString(PrefKeys.themeMode, themeModeToString(mode));
  }

  async setSeedColor(value: number): Promise<void> {
    this.seedColor = value;
    this.notify();
    await Prefs.putString(PrefKeys.seedColor, `${value}`);
  }

  async setMinBitrate(value: number): Promise<void> {
    this.minBitrate = value;
    this.notify();
    await Prefs.putString(PrefKeys.minBitrate, `${value}`);
  }

  async selectCountry(code: string): Promise<void> {
    this.selectedCountry = code;
    this.notify();
    if (code.length === 0) {
      await Prefs.remove(PrefKeys.selectedCountry);
    } else {
      await Prefs.putString(PrefKeys.selectedCountry, code);
    }
  }
}

/// 设备所在国家/地区码（ISO 3166-1 alpha-2，可能为空）。
export function deviceCountryCode(): string {
  try {
    return i18n.System.getSystemRegion();
  } catch (e) {
    return '';
  }
}

/// 选中国家码为空时跟随设备。
export function effectiveCountryCode(selected: string): string {
  return selected.length === 0 ? deviceCountryCode() : selected;
}
