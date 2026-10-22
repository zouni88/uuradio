// 浏览类列表缓存：key=请求签名，value=JSON（{'items': [...]}）。
// 命中缓存先秒出（不转圈），网络后台静默刷新；网络失败回落缓存。
// 对齐 Flutter browse_cache_ds.dart（browse_cache box → 'bc:' 前缀）。
import { KvStore } from '../../core/kvstore';
import { Station, BrowseCategory } from '../../domain/models';
import { StationDto, CategoryDto } from '../dto';

const PREFIX = 'bc:';

export class BrowseCacheStore {
  async getStations(key: string): Promise<Station[] | null> {
    const raw = await KvStore.get(PREFIX + key);
    if (raw === null) {
      return null;
    }
    try {
      const map = JSON.parse(raw) as Record<string, Object>;
      const items = map['items'] as Object[];
      const out: Station[] = [];
      for (const e of items) {
        out.push(StationDto.fromJson(e as Record<string, Object>).toDomain());
      }
      return out;
    } catch (e) {
      return null;
    }
  }

  async putStations(key: string, stations: Station[]): Promise<void> {
    const items: Object[] = [];
    for (const s of stations) {
      items.push(StationDto.fromDomain(s).toJson());
    }
    await KvStore.put(PREFIX + key, JSON.stringify({ 'items': items } as Record<string, Object>));
  }

  async getCategories(key: string): Promise<BrowseCategory[] | null> {
    const raw = await KvStore.get(PREFIX + key);
    if (raw === null) {
      return null;
    }
    try {
      const map = JSON.parse(raw) as Record<string, Object>;
      const items = map['items'] as Object[];
      const out: BrowseCategory[] = [];
      for (const e of items) {
        out.push(CategoryDto.fromJson(e as Record<string, Object>).toDomain());
      }
      return out;
    } catch (e) {
      return null;
    }
  }

  async putCategories(key: string, categories: BrowseCategory[]): Promise<void> {
    const items: Object[] = [];
    for (const c of categories) {
      const dto = new CategoryDto();
      dto.name = c.name;
      dto.stationCount = c.stationCount;
      dto.isoCode = c.isoCode;
      items.push(dto.toJson());
    }
    await KvStore.put(PREFIX + key, JSON.stringify({ 'items': items } as Record<string, Object>));
  }
}
