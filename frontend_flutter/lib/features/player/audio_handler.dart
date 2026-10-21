import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/error/app_exception.dart';
import '../../domain/models/station.dart';

/// 播放快照：UI 唯一读取的播放状态。
class PlaybackSnapshot {
  const PlaybackSnapshot({
    this.station,
    this.playing = false,
    this.loading = false,
    this.buffering = false,
    this.icyTitle,
    this.errorType,
  });

  final Station? station;
  final bool playing;

  /// 连接电台流中（setAudioSource 阶段）。
  final bool loading;
  final bool buffering;

  /// ICY metadata：电台正在播出的节目名。
  final String? icyTitle;
  final AppErrorType? errorType;

  PlaybackSnapshot copyWith({
    Station? station,
    bool? playing,
    bool? loading,
    bool? buffering,
    String? icyTitle,
    bool clearIcy = false,
    AppErrorType? errorType,
    bool clearError = false,
  }) {
    return PlaybackSnapshot(
      station: station ?? this.station,
      playing: playing ?? this.playing,
      loading: loading ?? this.loading,
      buffering: buffering ?? this.buffering,
      icyTitle: clearIcy ? null : (icyTitle ?? this.icyTitle),
      errorType: clearError ? null : (errorType ?? this.errorType),
    );
  }
}

/// audio_service 处理器：通知栏/线控/音频焦点 + just_audio 播放引擎。
///
/// 纯播放引擎，不依赖 Riverpod；点击上报/历史记录由上层 controller 完成。
class RadioAudioHandler extends BaseAudioHandler {
  RadioAudioHandler() {
    _init();
  }

  final AudioPlayer _player = AudioPlayer();
  final _snapshotCtrl = StreamController<PlaybackSnapshot>.broadcast();
  PlaybackSnapshot _snapshot = const PlaybackSnapshot();
  int _retryAttempt = 0;

  static const _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 3),
    Duration(seconds: 7),
  ];

  PlaybackSnapshot get snapshot => _snapshot;
  Stream<PlaybackSnapshot> get snapshotStream => _snapshotCtrl.stream;

  /// Android 音频会话 ID（真实频谱 Visualizer 挂载点）。
  Stream<int?> get androidAudioSessionIdStream =>
      _player.androidAudioSessionIdStream;

  /// 播放器音量（0..1）：无系统音量通道平台（iOS）上车机音量滚轮的降级数据源。
  double get playerVolume => _player.volume;

  /// 设置播放器音量（0..1）。
  Future<void> setPlayerVolume(double v) =>
      _player.setVolume(v.clamp(0.0, 1.0));

  Station? get currentStation => _snapshot.station;

  void _emit(PlaybackSnapshot next) {
    _snapshot = next;
    if (!_snapshotCtrl.isClosed) _snapshotCtrl.add(next);
  }

  void _init() {
    _configureAudioSession();
    _player.playerStateStream.listen(_onPlayerStateChanged);
    _player.icyMetadataStream.listen(_onIcyMetadata);
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    session.interruptionEventStream.listen((event) {
      if (event.begin) pause();
    });
    session.becomingNoisyEventStream.listen((_) => pause());
  }

  // ---- 供 UI 调用 ----

  /// 播放一个电台（切台/重试统一入口）。
  Future<void> playStation(Station station) async {
    _retryAttempt = 0;
    _emit(PlaybackSnapshot(station: station, loading: true));
    mediaItem.add(_mediaItemOf(station));
    await _start(station);
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  // ---- audio_service 通知栏/线控动作 ----

  @override
  Future<void> play() async {
    if (_snapshot.station != null) await _player.play();
  }

  @override
  Future<void> pause() async => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    _emit(_snapshot.copyWith(playing: false, loading: false, buffering: false));
    playbackState.add(PlaybackState(processingState: AudioProcessingState.idle));
  }

  // ---- 内部实现 ----

  Future<void> _start(Station station) async {
    _emit(_snapshot.copyWith(loading: true, clearError: true));
    try {
      final source = AudioSource.uri(
        Uri.parse(station.streamUrl),
        headers: {'User-Agent': ApiConstants.userAgent},
      );
      await _player
          .setAudioSource(source)
          .timeout(ApiConstants.streamSetTimeout);
      await _player.play();
    } on TimeoutException {
      await _retryOrFail(station, const AppException(AppErrorType.timeout));
    } on Exception catch (e) {
      await _retryOrFail(station, AppException.from(e));
    }
  }

  Future<void> _retryOrFail(Station station, AppException error) async {
    if (_retryAttempt < _retryDelays.length) {
      final delay = _retryDelays[_retryAttempt];
      _retryAttempt++;
      await Future<void>.delayed(delay);
      // 等待期间用户可能切了台。
      if (currentStation?.uuid != station.uuid) return;
      await _start(station);
      return;
    }
    _emit(_snapshot.copyWith(
      loading: false,
      playing: false,
      buffering: false,
      errorType: error.type,
    ));
  }

  void _onPlayerStateChanged(PlayerState state) {
    final processing = switch (state.processingState) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading ||
      ProcessingState.buffering =>
        AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.idle,
    };
    playbackState.add(playbackState.value.copyWith(
      controls: [
        state.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.stop},
      processingState: processing,
      playing: state.playing,
    ));
    // loading 只由 _start 流程管理，这里只同步 playing/buffering。
    _emit(_snapshot.copyWith(
      playing: state.playing,
      buffering:
          state.processingState == ProcessingState.buffering && state.playing,
    ));
    if (state.playing &&
        state.processingState == ProcessingState.ready &&
        _snapshot.loading) {
      _emit(_snapshot.copyWith(loading: false, playing: true));
    }
  }

  void _onIcyMetadata(IcyMetadata? data) {
    final title = data?.info?.title;
    if (title == null || title.isEmpty) return;
    _emit(_snapshot.copyWith(icyTitle: title));
    final station = _snapshot.station;
    if (station != null) {
      mediaItem.add(_mediaItemOf(station, subtitle: title));
    }
  }

  MediaItem _mediaItemOf(Station station, {String? subtitle}) {
    return MediaItem(
      id: station.uuid,
      title: station.name,
      artist: subtitle ?? stationSubtitleOf(station),
      artUri: Uri.tryParse(station.logoUrl),
      genre: 'Radio',
    );
  }

  String stationSubtitleOf(Station station) {
    final parts = <String>[
      if (station.country.isNotEmpty) station.country,
      if (station.bitrate > 0) '${station.bitrate} kbps',
    ];
    return parts.join(' · ');
  }
}
