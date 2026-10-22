// RadioBrowser HTTP 客户端：UA 头 + 服务器失败轮换（对齐 Flutter radio_browser_client.dart）。
import { ApiConstants } from '../../core/api_constants';
import { Http } from '../../core/http';
import { AppErrorType, AppException } from '../../core/app_exception';
import { Station, BrowseCategory, StationQuery } from '../../domain/models';
import { StationDto, CategoryDto } from '../dto';
import { ApiServerResolver } from './server_resolver';

export class RadioBrowserApi {
  private resolver: ApiServerResolver;

  constructor(resolver: ApiServerResolver) {
    this.resolver = resolver;
  }

  /// 带失败轮换的 GET：超时/连接失败/5xx 时切换镜像重试（最多 3 次）。
  async getList(path: string, query?: Record<string, string>): Promise<Object[]> {
    let qs = '';
    if (query) {
      const keys = Object.keys(query);
      for (const k of keys) {
        qs += `${qs.length === 0 ? '?' : '&'}${encodeURIComponent(k)}=${encodeURIComponent(query[k])}`;
      }
    }
    let lastError: Object = `request failed: ${path}`;
    for (let attempt = 0; attempt < 3; attempt++) {
      const host = await this.resolver.currentServer();
      try {
        const text = await Http.getJson(
          `https://${host}${path}${qs}`,
          ApiConstants.API_TIMEOUT,
          ApiConstants.USER_AGENT
        );
        const arr = JSON.parse(text) as Object[];
        return arr ?? [];
      } catch (e) {
        const ex = AppException.fromError(e);
        lastError = ex;
        // 4xx 类业务错误不轮换，直接抛出
        if (ex.type === AppErrorType.unknown) {
          throw ex;
        }
        await this.resolver.rotate();
      }
    }
    throw AppException.fromError(lastError);
  }

  async search(query: StationQuery): Promise<Station[]> {
    const list = await this.getList('/json/stations/search', query.toQueryParameters());
    return RadioBrowserApi.toStations(list);
  }

  async topByClicks(limit: number): Promise<Station[]> {
    return RadioBrowserApi.toStations(await this.getList(`/json/stations/topclick/${limit}`));
  }

  async topByVotes(limit: number): Promise<Station[]> {
    return RadioBrowserApi.toStations(await this.getList(`/json/stations/topvote/${limit}`));
  }

  async countries(): Promise<BrowseCategory[]> {
    return RadioBrowserApi.toCategories(await this.getList('/json/countries'));
  }

  async tags(limit: number = 100): Promise<BrowseCategory[]> {
    const list = await this.getList('/json/tags', {
      'order': 'stationcount',
      'reverse': 'true',
      'limit': `${limit}`,
      'hidebroken': 'true'
    });
    return RadioBrowserApi.toCategories(list);
  }

  async languages(): Promise<BrowseCategory[]> {
    const list = await this.getList('/json/languages', {
      'order': 'stationcount',
      'reverse': 'true',
      'hidebroken': 'true'
    });
    return RadioBrowserApi.toCategories(list);
  }

  async reportClick(stationUuid: string): Promise<void> {
    await this.getList(`/json/url/${stationUuid}`);
  }

  async stationsByUuids(uuids: string[]): Promise<Station[]> {
    if (uuids.length === 0) {
      return [];
    }
    const list = await this.getList('/json/stations/byuuid', { 'uuids': uuids.join(',') });
    return RadioBrowserApi.toStations(list);
  }

  private static toStations(list: Object[]): Station[] {
    const out: Station[] = [];
    for (const item of list) {
      if (item !== null && item !== undefined && typeof item === 'object') {
        out.push(StationDto.fromJson(item as Record<string, Object>).toDomain());
      } else {
        out.push(StationDto.fromJson({} as Record<string, Object>).toDomain());
      }
    }
    return out;
  }

  private static toCategories(list: Object[]): BrowseCategory[] {
    const out: BrowseCategory[] = [];
    for (const item of list) {
      if (item !== null && item !== undefined && typeof item === 'object') {
        out.push(CategoryDto.fromJson(item as Record<string, Object>).toDomain());
      } else {
        out.push(BrowseCategory.of('', 0, ''));
      }
    }
    return out;
  }
}
