// 播放引擎：AVPlayer 直连电台流 + AVSession 媒体控制中心。
// 中断/拔耳机自动暂停；失败重试延迟 [1,3,7] 秒（对齐 Flutter audio_handler.dart）。
// ICY 节目名：AVPlayer 无公开 ICY 元数据接口，保留字段、始终为空（UI 自动隐藏）。
import { media } from '@kit.MediaKit';
import { avSession as avSessionKit } from '@kit.AVSessionKit';
import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Context } from '@kit.AbilityKit';
import { ApiConstants } from '../core/api_constants';
import { AppErrorType, AppException } from '../core/app_exception';
import { Station } from '../domain/models';

/// 播放快照：UI 唯一读取的播放状态。
export class PlaybackSnapshot {
  station: Station | null = null;
  playing: boolean = false;
  /// 连接电台流中（prepare 阶段）。
  loading: boolean = false;
  buffering: boolean = false;
  /// ICY metadata：电台正在播出的节目名（ohos 不可得，恒为空）。
  icyTitle: string = '';
  errorType: AppErrorType | null = null;
}

function stationSubtitleOf(station: Station): string {
  const parts: string[] = [];
  if (station.country.length > 0) {
    parts.push(station.country);
  }
  if (station.bitrate > 0) {
    parts.push(`${station.bitrate} kbps`);
  }
  return parts.join(' · ');
}

export class AudioPlayerService {
  private static instance: AudioPlayerService | null = null;

  static inst(): AudioPlayerService {
    if (AudioPlayerService.instance === null) {
      AudioPlayerService.instance = new AudioPlayerService();
    }
    return AudioPlayerService.instance;
  }

  private player: media.AVPlayer | null = null;
  private session: avSessionKit.AVSession | null = null;
  snapshot: PlaybackSnapshot = new PlaybackSnapshot();
  private listeners: Set<() => void> = new Set();
  private retryAttempt: number = 0;
  /// 播放代次：新 playStation 使旧的 watchdog/重试作废。
  private generation: number = 0;
  private watchdogId: number = -1;
  private context: Context | null = null;

  static readonly RETRY_DELAYS: number[] = [1000, 3000, 7000];

  addListener(fn: () => void): void {
    this.listeners.add(fn);
  }

  removeListener(fn: () => void): void {
    this.listeners.delete(fn);
  }

  private notify(): void {
    this.listeners.forEach((fn: () => void) => fn());
  }

  private copy(): PlaybackSnapshot {
    const s = new PlaybackSnapshot();
    s.station = this.snapshot.station;
    s.playing = this.snapshot.playing;
    s.loading = this.snapshot.loading;
    s.buffering = this.snapshot.buffering;
    s.icyTitle = this.snapshot.icyTitle;
    s.errorType = this.snapshot.errorType;
    return s;
  }

  private emit(next: PlaybackSnapshot): void {
    this.snapshot = next;
    this.notify();
    this.updateSessionState();
  }

  async init(context: Context): Promise<void> {
    this.context = context;
    try {
      const session = await avSessionKit.createAVSession(context, 'iradio', 'audio');
      this.session = session;
      session.on('play', () => {
        this.resume();
      });
      session.on('pause', () => {
        this.pause();
      });
      session.on('stop', () => {
        this.stop();
      });
      await session.activate();
    } catch (e) {
      // 媒体会话创建失败不影响应用内播放。
    }
  }

  /// 播放一个电台（切台/重试统一入口）。
  async playStation(station: Station): Promise<void> {
    this.generation++;
    this.retryAttempt = 0;
    const s = new PlaybackSnapshot();
    s.station = station;
    s.loading = true;
    this.emit(s);
    this.updateSessionMetadata(station, '');
    await this.start(station, this.generation);
  }

  async resume(): Promise<void> {
    if (this.snapshot.station !== null) {
      try {
        await this.player?.play();
      } catch (e) {
      }
    }
  }

  async pause(): Promise<void> {
    try {
      await this.player?.pause();
    } catch (e) {
    }
  }

  async togglePlayPause(): Promise<void> {
    if (this.snapshot.playing) {
      await this.pause();
    } else {
      await this.resume();
    }
  }

  async stop(): Promise<void> {
    try {
      await this.player?.stop();
    } catch (e) {
    }
    const s = this.copy();
    s.playing = false;
    s.loading = false;
    s.buffering = false;
    this.emit(s);
  }

  // ---- 内部实现 ----

  private async start(station: Station, gen: number): Promise<void> {
    const s = this.copy();
    s.loading = true;
    s.errorType = null;
    this.emit(s);
    // 流连接超时看门狗（15s）
    if (this.watchdogId >= 0) {
      clearTimeout(this.watchdogId);
      this.watchdogId = -1;
    }
    this.watchdogId = setTimeout(() => {
      this.watchdogId = -1;
      this.retryOrFail(station, gen, new AppException(AppErrorType.timeout, 'stream connect timeout'));
    }, ApiConstants.STREAM_SET_TIMEOUT);
    try {
      await this.prepareAndPlay(station.streamUrl);
      if (this.watchdogId >= 0) {
        clearTimeout(this.watchdogId);
        this.watchdogId = -1;
      }
    } catch (e) {
      if (this.watchdogId >= 0) {
        clearTimeout(this.watchdogId);
        this.watchdogId = -1;
      }
      if (gen === this.generation) {
        await this.retryOrFail(station, gen, AppException.fromError(e));
      }
    }
  }

  private async prepareAndPlay(url: string): Promise<void> {
    let player = this.player;
    if (player === null) {
      player = await media.createAVPlayer();
      this.player = player;
      this.registerPlayerCallbacks(player);
    } else {
      await player.reset();
    }
    player.url = url;
    await player.prepare();
    await player.play();
  }

  private registerPlayerCallbacks(player: media.AVPlayer): void {
    player.on('stateChange', (state: string, reason: media.StateChangeReason) => {
      const snap = this.copy();
      if (state === 'playing') {
        snap.playing = true;
        snap.loading = false;
        snap.buffering = false;
      } else if (state === 'paused' || state === 'stopped' || state === 'completed' || state === 'idle') {
        snap.playing = false;
      } else if (state === 'prepared') {
        snap.loading = false;
      }
      this.emit(snap);
    });
    player.on('error', (err: BusinessError) => {
      // 播放中途错误（start 的 catch 已覆盖 prepare/play 失败，这里兜底）
      const snap = this.copy();
      snap.playing = false;
      snap.loading = false;
      snap.buffering = false;
      snap.errorType = AppErrorType.network;
      this.emit(snap);
    });
    player.on('audioInterrupt', (event: audio.InterruptEvent) => {
      if (event.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE ||
        event.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP) {
        this.pause();
      }
    });
  }

  private async retryOrFail(station: Station, gen: number, error: AppException): Promise<void> {
    if (gen !== this.generation) {
      return;
    }
    if (this.retryAttempt < AudioPlayerService.RETRY_DELAYS.length) {
      const delay = AudioPlayerService.RETRY_DELAYS[this.retryAttempt];
      this.retryAttempt++;
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, delay));
      // 等待期间用户可能切了台。
      if (gen !== this.generation || this.snapshot.station?.uuid !== station.uuid) {
        return;
      }
      await this.start(station, gen);
      return;
    }
    const s = this.copy();
    s.loading = false;
    s.playing = false;
    s.buffering = false;
    s.errorType = error.type;
    this.emit(s);
  }

  private async updateSessionMetadata(station: Station, subtitle: string): Promise<void> {
    if (this.session === null) {
      return;
    }
    try {
      const metadata: avSessionKit.AVMetadata = {
        assetId: station.uuid,
        title: station.name,
        artist: subtitle.length > 0 ? subtitle : stationSubtitleOf(station)
      };
      await this.session.setAVMetadata(metadata);
    } catch (e) {
    }
  }

  private async updateSessionState(): Promise<void> {
    if (this.session === null) {
      return;
    }
    try {
      const state: avSessionKit.PlaybackState = this.snapshot.playing
        ? avSessionKit.PlaybackState.PLAYBACK_STATE_PLAY
        : avSessionKit.PlaybackState.PLAYBACK_STATE_PAUSE;
      const pbState: avSessionKit.AVPlaybackState = { state: state };
      await this.session.setAVPlaybackState(pbState);
    } catch (e) {
    }
  }

  /// 拔耳机等输出设备断开时自动暂停。
  onAudioDeviceDisconnected(): void {
    this.pause();
  }
}
