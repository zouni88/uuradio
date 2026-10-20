// 睡眠定时器：剩余秒数（-1 = 未启用），到点暂停播放。
import { PlayerController } from './player_controller';

export class SleepTimerController {
  private static instance: SleepTimerController | null = null;

  static inst(): SleepTimerController {
    if (SleepTimerController.instance === null) {
      SleepTimerController.instance = new SleepTimerController();
    }
    return SleepTimerController.instance;
  }

  /// 剩余秒数；-1 = 未启用。
  remainingSec: number = -1;
  private timerId: number = -1;
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

  start(minutes: number): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.remainingSec = minutes * 60;
    this.notify();
    this.timerId = setInterval(() => {
      this.remainingSec--;
      if (this.remainingSec <= 0) {
        clearInterval(this.timerId);
        this.timerId = -1;
        this.remainingSec = -1;
        PlayerController.inst().pause();
      }
      this.notify();
    }, 1000);
  }

  cancel(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.remainingSec = -1;
    this.notify();
  }
}
