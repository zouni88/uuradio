// 频谱控制器：播放开始后请求麦克风授权并启动真实 FFT；失败/拒绝降级合成动画。
// 合成动画参数逐值对齐 Flutter visualizer_controller.dart。
import { common } from '@kit.AbilityKit';
import { VisualizerService } from '../services/visualizer_service';
import { AudioPlayerService } from '../services/audio_player_service';

export const BAND_COUNT = 32;

export class VisualizerController {
  private static instance: VisualizerController | null = null;

  static inst(): VisualizerController {
    if (VisualizerController.instance === null) {
      VisualizerController.instance = new VisualizerController();
    }
    return VisualizerController.instance;
  }

  bands: number[] = [];
  /// true = 真实 FFT；false = 合成动画。
  real: boolean = false;
  permissionDenied: boolean = false;

  private service: VisualizerService = new VisualizerService();
  private playerService: AudioPlayerService = AudioPlayerService.inst();
  private listeners: Set<() => void> = new Set();
  private smoothed: number[] = new Array<number>(BAND_COUNT).fill(0);
  private synthTimerId: number = -1;
  private context: common.UIAbilityContext | null = null;
  private attached: boolean = false;
  private trying: boolean = false;

  addListener(fn: () => void): void {
    this.listeners.add(fn);
  }

  removeListener(fn: () => void): void {
    this.listeners.delete(fn);
  }

  private notify(): void {
    this.listeners.forEach((fn: () => void) => fn());
  }

  private copySmoothed(): number[] {
    return this.smoothed.slice();
  }

  /// 播放页挂载时调用。
  attach(context: common.UIAbilityContext): void {
    this.context = context;
    if (!this.attached) {
      this.attached = true;
      this.playerService.addListener(() => this.onPlayerChanged());
    }
    this.onPlayerChanged();
  }

  /// 播放页卸载时调用。
  detach(): void {
    this.playerService.removeListener(() => this.onPlayerChanged());
    this.attached = false;
    this.teardown();
  }

  private onPlayerChanged(): void {
    // 播放开始且尚未启动任何模式时，尝试挂真实频谱。
    if (this.playerService.snapshot.playing && this.synthTimerId < 0 && !this.real) {
      this.tryStartReal();
    }
  }

  private async tryStartReal(): Promise<void> {
    if (this.trying || this.context === null) {
      return;
    }
    this.trying = true;
    try {
      const granted = await VisualizerService.requestMicPermission(this.context);
      if (!granted) {
        this.startSynthetic();
        this.real = false;
        this.permissionDenied = true;
        this.notify();
        return;
      }
      const ok = await this.service.start();
      if (!ok) {
        this.startSynthetic();
        this.notify();
        return;
      }
      this.real = true;
      this.service.onBands = (bands: number[]) => {
        this.onRealBands(bands);
      };
      this.notify();
    } finally {
      this.trying = false;
    }
  }

  private onRealBands(bands: number[]): void {
    if (bands.length === 0) {
      return;
    }
    // 指数平滑防抖动（0.45 / 0.55）。
    for (let i = 0; i < this.smoothed.length; i++) {
      const v = i < bands.length ? bands[i] : 0.0;
      this.smoothed[i] = this.smoothed[i] * 0.45 + v * 0.55;
    }
    this.bands = this.copySmoothed();
    this.notify();
  }

  /// 未授权/不支持时的降级：平滑随机游走合成动画（80ms tick）。
  private startSynthetic(): void {
    this.stopSynthetic();
    let phase = 0.0;
    const targets: number[] = [];
    for (let i = 0; i < BAND_COUNT; i++) {
      targets.push(0.3);
    }
    this.synthTimerId = setInterval(() => {
      phase += 0.35;
      for (let i = 0; i < targets.length; i++) {
        if (Math.random() < 0.18) {
          targets[i] = 0.15 + Math.random() * 0.85;
        }
        const wave = 0.12 * Math.sin(phase * 0.6 + i * 0.4);
        let target = targets[i] + wave;
        if (target < 0.05) {
          target = 0.05;
        }
        if (target > 1.0) {
          target = 1.0;
        }
        this.smoothed[i] = this.smoothed[i] * 0.6 + target * 0.4;
      }
      this.bands = this.copySmoothed();
      this.notify();
    }, 80);
  }

  private stopSynthetic(): void {
    if (this.synthTimerId >= 0) {
      clearInterval(this.synthTimerId);
      this.synthTimerId = -1;
    }
  }

  private teardown(): void {
    this.stopSynthetic();
    this.service.stop();
    this.real = false;
    this.permissionDenied = false;
    this.bands = [];
    this.notify();
  }
}
