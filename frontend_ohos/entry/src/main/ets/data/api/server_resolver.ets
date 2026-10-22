// RadioBrowser 服务器发现与轮换。
// API 官方约定：不硬连单一服务器、通过 /json/servers 自适应镜像列表。
// 方案：缓存列表 + 种子镜像随机探测（对齐 Flutter api_server_resolver.dart）。
import { ApiConstants } from '../../core/api_constants';
import { Http } from '../../core/http';
import { Prefs, PrefKeys } from '../../core/prefs';

/// 镜像缓存条目。
class ServerCache {
  servers: string[] = [];
  savedAt: number = 0;
}

function encodeCache(servers: string[], savedAt: number): string {
  return JSON.stringify({
    'savedAt': new Date(savedAt).toISOString(),
    'servers': servers
  } as Record<string, Object>);
}

function decodeCache(raw: string): ServerCache | null {
  try {
    const map = JSON.parse(raw) as Record<string, Object>;
    const arr = map['servers'] as string[];
    const atStr = `${map['savedAt']}`;
    const at = Date.parse(atStr);
    if (!arr || arr.length === 0 || isNaN(at)) {
      return null;
    }
    const c = new ServerCache();
    c.servers = arr;
    c.savedAt = at;
    return c;
  } catch (e) {
    return null;
  }
}

export class ApiServerResolver {
  private current: string = '';

  /// 当前可用服务器（首次调用会触发发现流程）。
  async currentServer(): Promise<string> {
    if (this.current.length > 0) {
      return this.current;
    }
    return this.discover();
  }

  /// 当前服务器请求失败后切换下一台。
  async rotate(): Promise<string> {
    this.current = '';
    return this.discover();
  }

  private async discover(): Promise<string> {
    const candidates = await this.candidateServers();
    for (const host of candidates) {
      const servers = await this.probe(host);
      if (servers !== null) {
        this.current = host;
        await Prefs.putString(PrefKeys.serverCache, encodeCache(servers, Date.now()));
        return host;
      }
    }
    // 全部失败：退回种子列表里的第一台，让上层报网络错误。
    this.current = ApiConstants.SEED_SERVERS[0];
    return this.current;
  }

  /// 候选列表 = 未过期的缓存镜像 + 种子镜像（去重、随机排序）。
  private async candidateServers(): Promise<string[]> {
    const cached = await this.loadCache();
    const all: string[] = [];
    if (cached !== null) {
      for (const s of cached.servers) {
        all.push(s);
      }
    }
    for (const s of ApiConstants.SEED_SERVERS) {
      all.push(s);
    }
    const seen = new Set<string>();
    const unique: string[] = [];
    for (const s of all) {
      if (!seen.has(s)) {
        seen.add(s);
        unique.push(s);
      }
    }
    // Fisher-Yates 洗牌
    for (let i = unique.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const tmp = unique[i];
      unique[i] = unique[j];
      unique[j] = tmp;
    }
    return unique;
  }

  private async loadCache(): Promise<ServerCache | null> {
    const raw = await Prefs.getString(PrefKeys.serverCache);
    if (raw === null) {
      return null;
    }
    const decoded = decodeCache(raw);
    if (decoded === null) {
      return null;
    }
    if (Date.now() - decoded.savedAt > ApiConstants.SERVER_CACHE_TTL) {
      return null;
    }
    return decoded;
  }

  /// 探测一台镜像；成功时顺带返回 /json/servers 的全量服务器列表。
  private async probe(host: string): Promise<string[] | null> {
    try {
      const text = await Http.getJson(
        `https://${host}/json/servers`,
        ApiConstants.PROBE_TIMEOUT,
        ApiConstants.USER_AGENT
      );
      const data = JSON.parse(text) as Object[];
      if (!data || data.length === 0) {
        return null;
      }
      const hosts: string[] = [];
      for (const item of data) {
        const map = item as Record<string, Object>;
        const ip = map['ip'];
        const name = map['name'];
        if (typeof ip === 'string' && typeof name === 'string' && name.length > 0) {
          hosts.push(name);
        }
      }
      return hosts.length > 0 ? hosts : null;
    } catch (e) {
      return null;
    }
  }
}
