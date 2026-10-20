// 播放门面：转发引擎状态 + 播放成功后的上报/历史记录。
// 对齐 Flutter player_controller.dart。
import { AppErrorType } from '../core/app_exception';
import { Station } from '../domain/models';
import { AudioPlayerService, PlaybackSnapshot } from '../services/audio_player_service';
import { HistoryController } from './history_controller';
import { RadioRepository, stationFromLocalJson } from '../data/radio_repository';
import { AppRepositories } from './discover_controller';

/// UI 侧播放状态。
export class PlayerUiState {
  station: Station | null = null;
  playing: boolean = false;
  loading: boolean = false;
  buffering: boolean = false;
  icyTitle: string = '';
  errorType: AppErrorType | null = null;

  get hasStation(): boolean {
    return this.station !== null;
  }
}

export class PlayerController {
  private static instance: PlayerController | null = null;

  static inst(): PlayerController {
    if (PlayerController.instance === null) {
      PlayerController.instance = new PlayerController();
    }
    return PlayerController.instance;
  }

  state: PlayerUiState = new PlayerUiState();
  private service: AudioPlayerService = AudioPlayerService.inst();
  private history: HistoryController = HistoryController.inst();
  private repository: RadioRepository = AppRepositories.repo;
  private listeners: Set<() => void> = new Set();
  private reportedUuid: string = '';

  constructor() {
    this.service.addListener(() => this.onServiceChanged());
    this.onServiceChanged();
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

  private onServiceChanged(): void {
    const s: PlaybackSnapshot = this.service.snapshot;
    const next = new PlayerUiState();
    next.station = s.station;
    next.playing = s.playing;
    next.loading = s.loading;
    next.buffering = s.buffering;
    next.icyTitle = s.icyTitle;
    next.errorType = s.errorType;
    this.state = next;
    this.notify();
    // 播放成功后：写历史 + 点击计数上报（均 fire-and-forget）
    const station = s.station;
    if (station !== null && s.playing && this.reportedUuid !== station.uuid) {
      this.reportedUuid = station.uuid;
      this.onPlaybackStarted(station);
    }
  }

  /// 播放成功后：写历史 + 点击计数上报（失败不影响播放）。
  private onPlaybackStarted(station: Station): void {
    try {
      this.history.record(station);
      this.repository.reportClick(station.uuid);
    } catch (e) {
    }
  }

  play(station: Station): Promise<void> {
    return this.service.playStation(station);
  }

  togglePlayPause(): Promise<void> {
    return this.service.togglePlayPause();
  }

  pause(): Promise<void> {
    return this.service.pause();
  }

  stop(): Promise<void> {
    return this.service.stop();
  }
}
