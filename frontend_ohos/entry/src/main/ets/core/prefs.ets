// 设置持久化（@ohos.data.preferences），键名与 Flutter SharedPreferencesAsync 完全一致。
import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';

const FILE = 'settings';

export class Prefs {
  private static inst: preferences.Preferences | null = null;

  static async init(context: Context): Promise<void> {
    Prefs.inst = await preferences.getPreferences(context, FILE);
  }

  private static db(): preferences.Preferences {
    if (Prefs.inst === null) {
      throw new Error('Prefs not initialized');
    }
    return Prefs.inst;
  }

  static async getString(key: string): Promise<string | null> {
    try {
      const v = await Prefs.db().get(key, '') as string;
      return v === '' ? null : v;
    } catch (e) {
      return null;
    }
  }

  static async putString(key: string, value: string): Promise<void> {
    try {
      await Prefs.db().put(key, value);
      await Prefs.db().flush();
    } catch (e) {
    }
  }

  static async remove(key: string): Promise<void> {
    try {
      await Prefs.db().delete(key);
      await Prefs.db().flush();
    } catch (e) {
    }
  }
}

// 键名常量（对齐 settings_local_ds.dart）
export class PrefKeys {
  static readonly localeCode: string = 'settings.localeCode';
  static readonly themeMode: string = 'settings.themeMode';
  static readonly seedColor: string = 'settings.seedColor';
  static readonly minBitrate: string = 'settings.minBitrate';
  static readonly selectedCountry: string = 'settings.discoverCountryCode';
  static readonly serverCache: string = 'settings.serverCache';
  static readonly spectrumFallbackShown: string = 'settings.spectrumFallbackShown';
}
