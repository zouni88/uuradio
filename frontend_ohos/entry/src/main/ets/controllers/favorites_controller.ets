// 收藏（全局单例，任何页面的心形操作都实时同步）。
import { Station } from '../domain/models';
import { FavoritesLocalDs } from '../data/stores/record_store';

export class FavoritesController {
  private static instance: FavoritesController | null = null;

  static inst(): FavoritesController {
    if (FavoritesController.instance === null) {
      FavoritesController.instance = new FavoritesController();
    }
    return FavoritesController.instance;
  }

  items: Station[] = [];
  private favSet: Set<string> = new Set();
  private ds: FavoritesLocalDs = new FavoritesLocalDs();
  private listeners: Set<() => void> = new Set();

  addListener(fn: () => void): void {
    this.listeners.add(fn);
  }

  removeListener(fn: () => void): void {
    this.listeners.delete(fn);
  }

  private notify(): void {
    this.listeners.forEach((fn: () => void) => fn());
  }

  /// 启动加载（EntryAbility 调用）。
  async load(): Promise<void> {
    this.items = await this.ds.getAll();
    this.favSet.clear();
    for (const s of this.items) {
      this.favSet.add(s.uuid);
    }
    this.notify();
  }

  isFavorite(uuid: string): boolean {
    return this.favSet.has(uuid);
  }

  async toggle(station: Station): Promise<void> {
    if (this.favSet.has(station.uuid)) {
      await this.ds.remove(station.uuid);
    } else {
      await this.ds.add(station);
    }
    this.items = await this.ds.getAll();
    this.favSet.clear();
    for (const s of this.items) {
      this.favSet.add(s.uuid);
    }
    this.notify();
  }
}
