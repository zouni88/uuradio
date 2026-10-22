// 收藏与播放历史本地数据源（KV 存储，key=uuid，value=dto JSON + 时间戳）。
// 对齐 Flutter record_local_ds.dart；box 名映射为键前缀。
import { ApiConstants } from '../../core/api_constants';
import { KvStore } from '../../core/kvstore';
import { Station, PlayHistoryEntry } from '../../domain/models';
import { StationDto } from '../dto';

export const PREFIX_FAVORITES = 'fav:';
export const PREFIX_HISTORY = 'hist:';

function parseIso(value: Object | undefined | null): number {
  if (value === undefined || value === null) {
    return 0;
  }
  const at = Date.parse(`${value}`);
  return isNaN(at) ? 0 : at;
}

function toIso(ms: number): string {
  return new Date(ms).toISOString();
}

/// 收藏本地数据源：按收藏时间倒序。
export class FavoritesLocalDs {
  async getAll(): Promise<Station[]> {
    const map = await KvStore.getByPrefix(PREFIX_FAVORITES);
    const entries: Station[] = [];
    const times: number[] = [];
    map.forEach((value: string) => {
      try {
        const parsed = JSON.parse(value) as Record<string, Object>;
        entries.push(StationDto.fromJson(parsed).toDomain());
        times.push(parseIso(parsed['addedAt']));
      } catch (e) {
      }
    });
    // 按收藏时间倒序（同步排序 stations 与 times）
    const idx: number[] = entries.map((_: Station, i: number) => i);
    idx.sort((a: number, b: number) => times[b] - times[a]);
    return idx.map((i: number) => entries[i]);
  }

  async isFavorite(uuid: string): Promise<boolean> {
    return (await KvStore.get(PREFIX_FAVORITES + uuid)) !== null;
  }

  async add(station: Station): Promise<void> {
    const dto = StationDto.fromDomain(station);
    const json = dto.toJson();
    json['addedAt'] = toIso(Date.now());
    await KvStore.put(PREFIX_FAVORITES + station.uuid, JSON.stringify(json));
  }

  async remove(uuid: string): Promise<void> {
    await KvStore.remove(PREFIX_FAVORITES + uuid);
  }
}

/// 播放历史本地数据源：key=uuid 覆盖更新，上限 100 条。
export class HistoryLocalDs {
  async getAll(): Promise<PlayHistoryEntry[]> {
    const map = await KvStore.getByPrefix(PREFIX_HISTORY);
    const out: PlayHistoryEntry[] = [];
    map.forEach((value: string) => {
      try {
        const parsed = JSON.parse(value) as Record<string, Object>;
        const at = parseIso(parsed['playedAt']);
        if (at === 0) {
          return;
        }
        const entry = new PlayHistoryEntry();
        entry.station = StationDto.fromJson(parsed).toDomain();
        entry.playedAt = at;
        out.push(entry);
      } catch (e) {
      }
    });
    out.sort((a: PlayHistoryEntry, b: PlayHistoryEntry) => b.playedAt - a.playedAt);
    return out;
  }

  async record(station: Station): Promise<void> {
    const dto = StationDto.fromDomain(station);
    const json = dto.toJson();
    json['playedAt'] = toIso(Date.now());
    await KvStore.put(PREFIX_HISTORY + station.uuid, JSON.stringify(json));
    await this.trim();
  }

  async clear(): Promise<void> {
    await KvStore.removeByPrefix(PREFIX_HISTORY);
  }

  private async trim(): Promise<void> {
    const sorted = await this.getAll();
    if (sorted.length <= ApiConstants.HISTORY_LIMIT) {
      return;
    }
    for (let i = ApiConstants.HISTORY_LIMIT; i < sorted.length; i++) {
      await KvStore.remove(PREFIX_HISTORY + sorted[i].station.uuid);
    }
  }
}
