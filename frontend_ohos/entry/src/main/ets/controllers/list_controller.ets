// 通用分页电台列表控制器（榜单/搜索/分类共用）。
// 对齐 Flutter station_list_controller.dart：每次导航创建全新实例。
import { AppErrorType, AppException } from '../core/app_exception';
import { ApiConstants } from '../core/api_constants';
import { Station, StationQuery } from '../domain/models';
import { RadioRepository } from '../data/radio_repository';

/// 常用榜单分页大小。
export const LIST_PAGE_SIZE = ApiConstants.PAGE_SIZE;

export class StationListController {
  query: StationQuery;
  items: Station[] = [];
  loading: boolean = true;
  error: AppErrorType | null = null;
  loadingMore: boolean = false;

  private repository: RadioRepository;
  private hasMore: boolean = true;
  private listeners: Set<() => void> = new Set();

  constructor(repository: RadioRepository, query: StationQuery) {
    this.repository = repository;
    this.query = query;
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

  /// 首屏加载。
  async start(): Promise<void> {
    this.loading = true;
    this.error = null;
    this.notify();
    try {
      this.items = await this.repository.search(this.query);
      this.loading = false;
    } catch (e) {
      this.loading = false;
      this.error = AppException.fromError(e).type;
    }
    this.notify();
  }

  /// 重试。
  async retry(): Promise<void> {
    await this.start();
  }

  /// 分页加载（距底 400px 触发；失败不打断已展示的列表）。
  async loadMore(): Promise<void> {
    if (this.loadingMore || !this.hasMore || this.loading || this.error !== null) {
      return;
    }
    this.loadingMore = true;
    this.notify();
    try {
      const nextQuery = new StationQuery();
      nextQuery.name = this.query.name;
      nextQuery.countryCode = this.query.countryCode;
      nextQuery.tag = this.query.tag;
      nextQuery.language = this.query.language;
      nextQuery.order = this.query.order;
      nextQuery.reverse = this.query.reverse;
      nextQuery.minBitrate = this.query.minBitrate;
      nextQuery.limit = this.query.limit;
      nextQuery.offset = this.items.length;
      const next = await this.repository.search(nextQuery);
      const seen = new Set<string>();
      for (const s of this.items) {
        seen.add(s.uuid);
      }
      const fresh: Station[] = [];
      for (const s of next) {
        if (!seen.has(s.uuid)) {
          fresh.push(s);
        }
      }
      this.hasMore = next.length >= this.query.limit;
      if (fresh.length > 0) {
        this.items = this.items.concat(fresh);
      } else {
        this.hasMore = false;
      }
    } catch (e) {
      // 加载更多失败不打断已展示的列表。
    } finally {
      this.loadingMore = false;
      this.notify();
    }
  }
}
