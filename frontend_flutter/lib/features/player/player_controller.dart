import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_exception.dart';
import '../../data/providers.dart';
import '../../domain/models/station.dart';
import '../history/history_controller.dart';
import 'audio_handler.dart';

/// 注入点：main 中 AudioService.init 创建的 handler。
final audioHandlerProvider = Provider<RadioAudioHandler>(
  (ref) => throw UnimplementedError('override in main'),
);

/// UI 侧播放状态。
class PlayerUiState {
  const PlayerUiState({
    this.station,
    this.playing = false,
    this.loading = false,
    this.buffering = false,
    this.icyTitle,
    this.errorType,
  });

  final Station? station;
  final bool playing;
  final bool loading;
  final bool buffering;
  final String? icyTitle;
  final AppErrorType? errorType;

  bool get hasStation => station != null;
}

/// 播放门面：转发 handler 状态 + 播放成功后的上报/历史记录。
class PlayerController extends Notifier<PlayerUiState> {
  StreamSubscription<PlaybackSnapshot>? _sub;
  String? _reportedUuid;

  @override
  PlayerUiState build() {
    final handler = ref.watch(audioHandlerProvider);
    _sub?.cancel();
    _sub = handler.snapshotStream.listen((s) {
      if (!ref.mounted) return;
      state = PlayerUiState(
        station: s.station,
        playing: s.playing,
        loading: s.loading,
        buffering: s.buffering,
        icyTitle: s.icyTitle,
        errorType: s.errorType,
      );
      final station = s.station;
      if (station != null &&
          s.playing &&
          _reportedUuid != station.uuid) {
        _reportedUuid = station.uuid;
        _onPlaybackStarted(station);
      }
    });
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });
    final initial = handler.snapshot;
    return PlayerUiState(
      station: initial.station,
      playing: initial.playing,
      loading: initial.loading,
      buffering: initial.buffering,
      icyTitle: initial.icyTitle,
      errorType: initial.errorType,
    );
  }

  Future<void> play(Station station) =>
      ref.read(audioHandlerProvider).playStation(station);

  Future<void> togglePlayPause() =>
      ref.read(audioHandlerProvider).togglePlayPause();

  Future<void> pause() => ref.read(audioHandlerProvider).pause();

  void stop() => ref.read(audioHandlerProvider).stop();

  /// 播放成功后：写历史 + 点击计数上报（均 fire-and-forget）。
  void _onPlaybackStarted(Station station) {
    try {
      ref.read(playRecordRepositoryProvider).recordPlay(station);
      ref.read(radioRepositoryProvider).reportClick(station.uuid);
      ref.read(historyProvider.notifier).refresh();
    } catch (_) {
      // 记录失败不影响播放。
    }
  }
}

final playerProvider =
    NotifierProvider<PlayerController, PlayerUiState>(PlayerController.new);

/// 调谐"波段"：最近一次播放入口所在的电台列表。
/// 播放页飞梭旋钮在该列表内上一台/下一台切换，类似传统收音机换波段。
class TuningBandController extends Notifier<List<Station>> {
  /// 分页来源的续载回调（null = 固定列表，如收藏/热门榜）。
  Future<List<Station>?> Function()? _loadMore;
  bool _loadingMore = false;

  @override
  List<Station> build() => const [];

  void set(List<Station> band, {Future<List<Station>?> Function()? loadMore}) {
    _loadMore = loadMore;
    if (!identical(state, band)) state = band;
  }

  /// 是否还有可续载的分页来源（固定列表或已耗尽 = false）。
  bool get canLoadMore => _loadMore != null;

  /// 波段来源为分页列表时续载下一页并增长波段；固定列表为空操作。
  Future<void> loadMore() async {
    final fn = _loadMore;
    if (fn == null || _loadingMore) return;
    _loadingMore = true;
    try {
      final updated = await fn();
      if (!ref.mounted) return;
      if (updated != null && updated.length > state.length) {
        state = updated;
      } else if (updated != null) {
        // 来源已到底：清除回调，之后末尾步进允许回卷。
        _loadMore = null;
      }
    } finally {
      _loadingMore = false;
    }
  }
}

final tuningBandProvider = NotifierProvider<TuningBandController, List<Station>>(
    TuningBandController.new);

/// 调谐防抖：飞梭/滑轨连续步进时，停手 320ms 才真正切流。
/// state = 待切换的目标索引（null = 空闲）。
class TunerController extends Notifier<int?> {
  Timer? _timer;

  @override
  int? build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    return null;
  }

  void tune(int dir) {
    final band = ref.read(tuningBandProvider);
    if (band.isEmpty) return;
    final bandCtrl = ref.read(tuningBandProvider.notifier);
    final current = ref.read(playerProvider).station;
    final base = state ??
        (current == null
            ? -1
            : band.indexWhere((s) => s.uuid == current.uuid));
    // 末尾继续向前且来源还有下一页：触发续载并停在最后一台，
    // 不回卷到第一台（加载期间滚轮步进同样被钳制在此）。
    if (dir > 0 && base == band.length - 1 && bandCtrl.canLoadMore) {
      bandCtrl.loadMore();
      return;
    }
    final next =
        base < 0 ? (dir > 0 ? 0 : band.length - 1) : (base + dir) % band.length;
    state = next;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 320), () {
      _timer = null;
      if (!ref.mounted) return;
      state = null;
      ref.read(playerProvider.notifier).play(band[next]);
    });
  }
}

final tunerProvider =
    NotifierProvider<TunerController, int?>(TunerController.new);

/// 便捷播放入口：列表卡片点击即播。
extension PlayStationX on WidgetRef {
  void playStation(Station station) =>
      read(playerProvider.notifier).play(station);

  /// 从列表播入，并把该列表设为飞梭调谐波段。
  void playFromBand(Station station, List<Station> band) {
    read(tuningBandProvider.notifier).set(band);
    read(playerProvider.notifier).play(station);
  }
}
