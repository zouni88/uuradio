// KV 存储：relationalStore 单表 kv(k,v)，存 JSON 字符串。
// 替代 Flutter 端三个 Hive box：favorites / history / browse_cache（键前缀区分）。
import { relationalStore } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';

const TABLE = 'kv';

export class KvStore {
  private static store: relationalStore.RdbStore | null = null;

  static async init(context: Context): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: 'iradio.db',
      securityLevel: relationalStore.SecurityLevel.S1
    };
    const store = await relationalStore.getRdbStore(context, config);
    await store.executeSql(`CREATE TABLE IF NOT EXISTS ${TABLE} (k TEXT PRIMARY KEY, v TEXT NOT NULL)`);
    KvStore.store = store;
  }

  private static db(): relationalStore.RdbStore {
    if (KvStore.store === null) {
      throw new Error('KvStore not initialized');
    }
    return KvStore.store;
  }

  static async get(key: string): Promise<string | null> {
    try {
      const pred = new relationalStore.RdbPredicates(TABLE);
      pred.equalTo('k', key);
      const rs = await KvStore.db().query(pred, ['v']);
      let out: string | null = null;
      if (rs.goToNextRow()) {
        out = rs.getString(rs.getColumnIndex('v'));
      }
      rs.close();
      return out;
    } catch (e) {
      return null;
    }
  }

  static async put(key: string, value: string): Promise<void> {
    try {
      await KvStore.db().executeSql(`INSERT OR REPLACE INTO ${TABLE} (k, v) VALUES (?, ?)`, [key, value]);
    } catch (e) {
      // 写失败不影响主流程（缓存类数据可丢弃）
    }
  }

  static async remove(key: string): Promise<void> {
    try {
      const pred = new relationalStore.RdbPredicates(TABLE);
      pred.equalTo('k', key);
      await KvStore.db().delete(pred);
    } catch (e) {
    }
  }

  /// 取某前缀的全部键值（如收藏全量加载）。
  static async getByPrefix(prefix: string): Promise<Map<string, string>> {
    const out = new Map<string, string>();
    try {
      const pred = new relationalStore.RdbPredicates(TABLE);
      pred.like('k', `${prefix}%`);
      const rs = await KvStore.db().query(pred, ['k', 'v']);
      while (rs.goToNextRow()) {
        out.set(rs.getString(rs.getColumnIndex('k')), rs.getString(rs.getColumnIndex('v')));
      }
      rs.close();
    } catch (e) {
    }
    return out;
  }

  /// 删除某前缀全部键。
  static async removeByPrefix(prefix: string): Promise<void> {
    try {
      const pred = new relationalStore.RdbPredicates(TABLE);
      pred.like('k', `${prefix}%`);
      await KvStore.db().delete(pred);
    } catch (e) {
    }
  }

  static async clear(): Promise<void> {
    try {
      await KvStore.db().executeSql(`DELETE FROM ${TABLE}`);
    } catch (e) {
    }
  }
}
