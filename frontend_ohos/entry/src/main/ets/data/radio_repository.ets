// RadioBrowser 仓库实现：SWR 缓存优先静默加载（对齐 Flutter radio_repository_impl.dart）。
import { Station, BrowseCategory, StationQuery } from '../domain/models';
import { RadioBrowserApi } from './api/radio_browser_api';
import { BrowseCacheStore } from './stores/browse_cache_store';

export class RadioRepository {
  private client: RadioBrowserApi;
  private cache: BrowseCacheStore;

  constructor(client: RadioBrowserApi, cache: BrowseCacheStore) {
    this.client = client;
    this.cache = cache;
  }

  async search(query: StationQuery): Promise<Station[]> {
    const key = RadioRepository.cacheKey(query);
    if (key === null) {
      return this.client.search(query);
    }
    return this.cached(key, () => this.client.search(query));
  }

  async topByClicks(limit: number): Promise<Station[]> {
    return this.cached(`topclick/${limit}`, () => this.client.topByClicks(limit));
  }

  async topByVotes(limit: number): Promise<Station[]> {
    return this.cached(`topvote/${limit}`, () => this.client.topByVotes(limit));
  }

  async countries(): Promise<BrowseCategory[]> {
    return this.cachedCategories('cat/countries', () => this.client.countries());
  }

  async tags(limit: number = 100): Promise<BrowseCategory[]> {
    return this.cachedCategories(`cat/tags/${limit}`, () => this.client.tags(limit));
  }

  async languages(): Promise<BrowseCategory[]> {
    return this.cachedCategories('cat/languages', () => this.client.languages());
  }

  async reportClick(stationUuid: string): Promise<void> {
    try {
      await this.client.reportClick(stationUuid);
    } catch (e) {
      // 上报失败不影响播放。
    }
  }

  async stationsByUuids(uuids: string[]): Promise<Station[]> {
    return this.client.stationsByUuids(uuids);
  }

  /// 缓存优先静默加载：命中缓存立即返回（不转圈），后台静默刷新缓存；未命中才等网络。
  private async cached(key: string, fetch: () => Promise<Station[]>): Promise<Station[]> {
    const cachedList = await this.cache.getStations(key);
    if (cachedList !== null) {
      this.refresh(key, fetch);
      return cachedList;
    }
    return this.refresh(key, fetch);
  }

  /// 拉取并写入缓存。静默刷新失败时保持旧缓存；无缓存的首次加载把错误抛给页面。
  private async refresh(key: string, fetch: () => Promise<Station[]>): Promise<Station[]> {
    try {
      const list = await fetch();
      await this.cache.putStations(key, list);
      return list;
    } catch (e) {
      const cachedList = await this.cache.getStations(key);
      if (cachedList !== null) {
        return cachedList;
      }
      throw e as Error;
    }
  }

  private async cachedCategories(key: string, fetch: () => Promise<BrowseCategory[]>): Promise<BrowseCategory[]> {
    const cachedList = await this.cache.getCategories(key);
    if (cachedList !== null) {
      this.refreshCategories(key, fetch);
      return cachedList;
    }
    return this.refreshCategories(key, fetch);
  }

  private async refreshCategories(key: string, fetch: () => Promise<BrowseCategory[]>): Promise<BrowseCategory[]> {
    try {
      const list = await fetch();
      await this.cache.putCategories(key, list);
      return list;
    } catch (e) {
      const cachedList = await this.cache.getCategories(key);
      if (cachedList !== null) {
        return cachedList;
      }
      throw e as Error;
    }
  }

  /// 名称搜索结果不缓存（key 无界）；榜单与国家/标签/语言列表缓存。
  private static cacheKey(q: StationQuery): string | null {
    if (q.name.trim().length > 0) {
      return null;
    }
    return `list/${q.countryCode}/${q.tag}/${q.language}/` +
      `${q.order}/${q.reverse ? 1 : 0}/${q.minBitrate}/${q.limit}/${q.offset}`;
  }
}

/// 备份/导入共用：从本地 JSON 键直接构造 Station（对齐 stationFromLocalJson）。
export function stationFromLocalJson(json: Record<string, Object>): Station {
  const str = (key: string, alt?: string): string => {
    let v = json[key];
    if ((v === undefined || v === null) && alt !== undefined) {
      v = json[alt];
    }
    if (v === undefined || v === null) {
      return '';
    }
    return `${v}`;
  };
  const csv = (key: string): string[] => {
    if (key.length === 0) {
      return [];
    }
    return key.split(',')
      .map((e: string) => e.trim())
      .filter((e: string) => e.length > 0);
  };
  const toInt = (raw: string): number => {
    const n = parseInt(raw, 10);
    return isNaN(n) ? 0 : n;
  };

  const tagsRaw = json['tags'];
  const tags: string[] = [];
  if (Array.isArray(tagsRaw)) {
    for (const e of tagsRaw as Object[]) {
      tags.push(`${e}`);
    }
  } else {
    for (const e of csv(str('tags'))) {
      tags.push(e);
    }
  }
  const languageRaw = json['language'];
  const languages: string[] = [];
  if (Array.isArray(languageRaw)) {
    for (const e of languageRaw as Object[]) {
      languages.push(`${e}`);
    }
  } else {
    for (const e of csv(str('language'))) {
      languages.push(e);
    }
  }

  const streamUrl = str('streamUrl', 'url_resolved');
  const s = new Station();
  s.uuid = str('uuid', 'stationuuid');
  s.name = str('name');
  s.streamUrl = streamUrl.length > 0 ? streamUrl : str('url');
  s.logoUrl = str('logoUrl', 'favicon');
  s.homepage = str('homepage');
  s.countryCode = str('countryCode', 'countrycode');
  s.country = str('country');
  s.languages = languages;
  s.tags = tags;
  s.codec = str('codec');
  s.bitrate = toInt(str('bitrate'));
  s.clickCount = toInt(str('clickCount', 'clickcount'));
  s.votes = toInt(str('votes'));
  return s;
}
