// 信号控制器：每 2.5s 轮询信号快照（仅播放页挂载时活跃）。
import { SignalInfo, SignalService } from '../services/signal_service';

export class SignalController {
  private static instance: SignalController | null = null;

  static inst(): SignalController {
    if (SignalController.instance === null) {
      SignalController.instance = new SignalController();
    }
    return SignalController.instance;
  }

  info: SignalInfo = new SignalInfo();
  private service: SignalService = new SignalService();
  private timerId: number = -1;
  private listeners: Set<() => void> = new Set();
  private polling: boolean = false;

  addListener(fn: () => void): void {
    this.listeners.add(fn);
  }

  removeListener(fn: () => void): void {
    this.listeners.delete(fn);
  }

  private notify(): void {
    this.listeners.forEach((fn: () => void) => fn());
  }

  start(): void {
    if (this.polling) {
      return;
    }
    this.polling = true;
    this.poll();
    this.timerId = setInterval(() => this.poll(), 2500);
  }

  stop(): void {
    this.polling = false;
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private async poll(): Promise<void> {
    const info = await this.service.read();
    if (this.polling) {
      this.info = info;
      this.notify();
    }
  }
}
