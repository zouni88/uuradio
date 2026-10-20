// 收藏备份导出/导入（DocumentViewPicker，无需存储权限）。
// 格式：{ "app": "iradio", "version": 1, "exportedAt": ..., "stations": [...] }
import { picker } from '@kit.CoreFileKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { KvStore } from '../core/kvstore';
import { Station } from '../domain/models';
import { stationFromLocalJson } from '../data/radio_repository';
import { FavoritesLocalDs, PREFIX_FAVORITES } from '../data/stores/record_store';

export class BackupService {
  private favoritesDs: FavoritesLocalDs;

  constructor(favoritesDs: FavoritesLocalDs) {
    this.favoritesDs = favoritesDs;
  }

  /// 导出收藏。返回保存的文件名；'' 表示取消或失败。
  async exportFavorites(): Promise<string> {
    const favorites = await this.favoritesDs.getAll();
    const stations: Object[] = [];
    for (const s of favorites) {
      const item: Record<string, Object> = {
        'uuid': s.uuid,
        'name': s.name,
        'streamUrl': s.streamUrl,
        'logoUrl': s.logoUrl,
        'homepage': s.homepage,
        'countryCode': s.countryCode,
        'country': s.country,
        'tags': s.tags
      };
      // addedAt 从收藏原始记录读取，缺省取当前时间
      const raw = await KvStore.get(PREFIX_FAVORITES + s.uuid);
      let addedAt = new Date().toISOString();
      if (raw !== null) {
        try {
          const map = JSON.parse(raw) as Record<string, Object>;
          const at = map['addedAt'];
          if (typeof at === 'string') {
            addedAt = at;
          }
        } catch (e) {
        }
      }
      item['addedAt'] = addedAt;
      stations.push(item);
    }
    const payload: Record<string, Object> = {
      'app': 'iradio',
      'version': 1,
      'exportedAt': new Date().toISOString(),
      'stations': stations
    };
    const json = JSON.stringify(payload, null, 2);
    const stamp = new Date().toISOString().substring(0, 10).split('-').join('');
    const fileName = `iradio_favorites_${stamp}.json`;
    try {
      const docPicker = new picker.DocumentViewPicker();
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [fileName];
      const uris = await docPicker.save(options);
      if (uris.length === 0) {
        return '';
      }
      const file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      fileIo.writeSync(file.fd, json);
      fileIo.closeSync(file.fd);
      return fileName;
    } catch (e) {
      return '';
    }
  }

  /// 导入收藏（合并去重）。返回导入数量；用户取消返回 -1。
  async importFavorites(): Promise<number> {
    let content = '';
    try {
      const docPicker = new picker.DocumentViewPicker();
      const options = new picker.DocumentSelectOptions();
      const uris = await docPicker.select(options);
      if (uris.length === 0) {
        return -1;
      }
      const file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(file.fd);
      const buf = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file.fd);
      const decoder = util.TextDecoder.create('utf-8');
      content = decoder.decodeToString(new Uint8Array(buf));
    } catch (e) {
      throw new Error('read failed');
    }
    if (content.length === 0) {
      throw new Error('empty file');
    }
    const imported = BackupService.parseBackup(content);
    let count = 0;
    for (const station of imported) {
      if (station.uuid.length === 0 || station.streamUrl.length === 0) {
        continue;
      }
      const exists = await this.favoritesDs.isFavorite(station.uuid);
      if (!exists) {
        await this.favoritesDs.add(station);
        count++;
      }
    }
    return count;
  }

  /// 解析备份 JSON；对非法内容抛 Error。
  static parseBackup(content: string): Station[] {
    const root = JSON.parse(content) as Record<string, Object>;
    const list = root['stations'];
    if (!Array.isArray(list)) {
      throw new Error('backup missing stations array');
    }
    const out: Station[] = [];
    for (const item of list as Object[]) {
      if (item !== null && typeof item === 'object') {
        out.push(stationFromLocalJson(item as Record<string, Object>));
      }
    }
    return out;
  }
}
