// 发现页数据：热门榜单（跟随选中国家，失败回退全球榜）+ 国家分类 + 选中国家电台列表。
// 对齐 Flutter discover_controller.dart。
import { AppErrorType, AppException } from '../core/app_exception';
import { Station, BrowseCategory, StationQuery } from '../domain/models';
import { RadioRepository } from '../data/radio_repository';
import { RadioBrowserApi } from '../data/api/radio_browser_api';
import { ApiServerResolver } from '../data/api/server_resolver';
import { BrowseCacheStore } from '../data/stores/browse_cache_store';
import { StationListController } from './list_controller';
import { SettingsController, effectiveCountryCode } from './settings_controller';

export class DiscoverController {
  private static instance: DiscoverController | null = null;

  static inst(): DiscoverController {
    if (DiscoverController.instance === null) {
      DiscoverController.instance = new DiscoverController();
    }
    return DiscoverController.instance;
  }

  // 热门榜
  topItems: Station[] = [];
  topLoading: boolean = true;
  topError: AppErrorType | null = null;
  // 国家分类列表
  countryItems: BrowseCategory[] = [];
  countryLoading: boolean = true;
  countryError: AppErrorType | null = null;
  // 选中国家电台列表（选中国家变化时重建）
  countryStations: StationListController | null = null;

  private repository: RadioRepository;
  private settings: SettingsController;
  private listeners: Set<() => void> = new Set();
  private started: boolean = false;

  constructor() {
    this.repository = AppRepositories.repo;
    this.settings = SettingsController.inst();
  }

  addListener(fn: () => void): void {
    this.listeners.add(fn);
  }

  removeListener(fn: () => void): void {
    this.listeners.delete(fn);
  }

  private notify(): void {
    this.listeners.forEach((fn: () => void) => fn());
  }

  /// 首次进入发现页时启动加载。
  start(): void {
    if (this.started) {
      return;
    }
    this.started = true;
    this.settings.addListener(() => this.onSettingsChanged());
    this.reloadTop();
    this.reloadCountries();
    this.rebuildCountryStations();
  }

  /// 选中国家变化：重建榜单与国家列表。
  private onSettingsChanged(): void {
    this.reloadTop();
    this.rebuildCountryStations();
    this.notify();
  }

  private async reloadTop(): Promise<void> {
    this.topLoading = true;
    this.topError = null;
    this.notify();
    const code = effectiveCountryCode(this.settings.selectedCountry);
    try {
      if (code.length > 0) {
        try {
          const q = new StationQuery();
          q.countryCode = code;
          q.order = StationQuery.ORDER_BY_CLICKS;
          q.reverse = true;
          q.limit = 20;
          const local = await this.repository.search(q);
          if (local.length > 0) {
            this.topItems = local;
            this.topLoading = false;
            this.notify();
            return;
          }
        } catch (e) {
          // 本国榜失败回退全球榜。
        }
      }
      this.topItems = await this.repository.topByClicks(20);
      this.topLoading = false;
    } catch (e) {
      this.topLoading = false;
      this.topError = AppException.fromError(e).type;
    }
    this.notify();
  }

  private async reloadCountries(): Promise<void> {
    this.countryLoading = true;
    this.countryError = null;
    this.notify();
    try {
      this.countryItems = await this.repository.countries();
      this.countryLoading = false;
    } catch (e) {
      this.countryLoading = false;
      this.countryError = AppException.fromError(e).type;
    }
    this.notify();
  }

  retryTop(): void {
    this.reloadTop();
  }

  retryCountries(): void {
    this.reloadCountries();
  }

  private rebuildCountryStations(): void {
    const code = effectiveCountryCode(this.settings.selectedCountry);
    const q = new StationQuery();
    q.countryCode = code;
    q.order = StationQuery.ORDER_BY_CLICKS;
    q.reverse = true;
    const controller = new StationListController(this.repository, q);
    this.countryStations = controller;
    controller.addListener(() => this.notify());
    controller.start();
  }

  /// 当前生效国家码。
  currentCountryCode(): string {
    return effectiveCountryCode(this.settings.selectedCountry);
  }
}

/// 全局仓库持有者（KvStore/Prefs 初始化后使用；数据层依赖经顶部 import 装配）。
export class AppRepositories {
  static resolver: ApiServerResolver = new ApiServerResolver();
  static api: RadioBrowserApi = new RadioBrowserApi(AppRepositories.resolver);
  static cache: BrowseCacheStore = new BrowseCacheStore();
  static repo: RadioRepository = new RadioRepository(AppRepositories.api, AppRepositories.cache);
}
