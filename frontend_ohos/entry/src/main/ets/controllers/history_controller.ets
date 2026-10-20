// 播放历史（全局单例，播放器写入、页面读取）。
import { PlayHistoryEntry, Station } from '../domain/models';
import { HistoryLocalDs } from '../data/stores/record_store';

export class HistoryController {
  private static instance: HistoryController | null = null;

  static inst(): HistoryController {
    if (HistoryController.instance === null) {
      HistoryController.instance = new HistoryController();
    }
    return HistoryController.instance;
  }

  items: PlayHistoryEntry[] = [];
  private ds: HistoryLocalDs = new HistoryLocalDs();
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

  async load(): Promise<void> {
    this.items = await this.ds.getAll();
    this.notify();
  }

  async refresh(): Promise<void> {
    await this.load();
  }

  /// 写入一条播放记录并刷新（播放器调用）。
  async record(station: Station): Promise<void> {
    await this.ds.record(station);
    await this.load();
  }

  async clear(): Promise<void> {
    await this.ds.clear();
    await this.load();
  }
}
