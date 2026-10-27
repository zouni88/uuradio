import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/api_constants.dart';
import '../../core/error/app_exception.dart';
import '../../data/providers.dart';
import '../../domain/models/station.dart';
import '../player/player_controller.dart';

/// IPTV 视频播放内核（video_player：Android=ExoPlayer / iOS=AVPlayer，原生 HLS）。
///
/// 已知平台限制：video_player 无鸿蒙（OHOS）实现。1:1 复刻电视功能时需自研
/// OHOS AVPlayer 原生插件或 libmpv 方案——播放内核收口在本文件一处
/// （页面只依赖 [TvPlayerUiState] 与 play/pause/retry 方法），换内核不动 UI。
class TvPlayerUiState {
  const TvPlayerUiState({
    this.channel,
    this.quality = '',
    this.geoBlocked = false,
    this.initializing = false,
    this.playing = false,
    this.buffering = false,
    this.errorType,
  });

  final Station? channel;
  final String quality;
  final bool geoBlocked;
  final bool initializing;
  final bool playing;
  final bool buffering;

  /// 非空 = 播放失败/信号丢失（加载列表错误在页面层，不在此）。
  final AppErrorType? errorType;

  bool get hasError => errorType != null;
}

class TvPlaybackController extends Notifier<TvPlayerUiState> {
  VideoPlayerController? _video;
  String? _currentUuid;

  /// 页面渲染视频画面用；isInitialized 后才可交给 VideoPlayer。
  VideoPlayerController? get videoController => _video;

  @override
  TvPlayerUiState build() {
    // 反向互斥：TV 存活期间用户起了电台 -> 释放视频，避免两路声音。
    ref.listen(playerProvider, (_, next) {
      if (next.playing && _video != null) {
        _currentUuid = null;
        unawaited(_releaseVideo());
        state = const TvPlayerUiState();
      }
    });
    ref.onDispose(() {
      final v = _video;
      _video = null;
      v?.dispose();
    });
    return const TvPlayerUiState();
  }

  Future<void> play(Station channel) async {
    if (_currentUuid == channel.uuid && _video != null) return;
    _currentUuid = channel.uuid;
    // 互斥：先停电台，保证同一时刻只有一路音频焦点。
    ref.read(playerProvider.notifier).stop();
    await _releaseVideo();
    if (!ref.mounted || _currentUuid != channel.uuid) return;
    state = TvPlayerUiState(channel: channel, initializing: true);
    try {
      // 部分社区流要求自定义 Referer/UA（Station 装不下，旁路查询）。
      final meta =
          await ref.read(iptvRepositoryProvider).streamMeta(channel.uuid);
      if (!ref.mounted || _currentUuid != channel.uuid) return;
      state = TvPlayerUiState(
        channel: channel,
        quality: meta?.quality ?? '',
        geoBlocked: meta?.geoBlocked ?? false,
        initializing: true,
      );
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(channel.streamUrl),
        httpHeaders: {
          if (meta?.referrer != null && meta!.referrer!.isNotEmpty)
            'Referer': meta.referrer!,
          if (meta?.userAgent != null && meta!.userAgent!.isNotEmpty)
            'User-Agent': meta.userAgent!,
        },
      );
      _video = controller;
      controller.addListener(_onVideoChanged);
      // 社区流失效率高：起播加超时保护，到点即错误态一键重试。
      await controller.initialize().timeout(ApiConstants.streamSetTimeout);
      if (!ref.mounted || _currentUuid != channel.uuid) {
        controller.removeListener(_onVideoChanged);
        await controller.dispose();
        return;
      }
      await controller.play();
    } catch (e) {
      await _releaseVideo();
      if (!ref.mounted || _currentUuid != channel.uuid) return;
      state = TvPlayerUiState(
        channel: channel,
        quality: state.quality,
        geoBlocked: state.geoBlocked,
        errorType: AppException.from(e).type,
      );
    }
  }

  void _onVideoChanged() {
    final v = _video;
    if (v == null || !ref.mounted) return;
    final value = v.value;
    state = TvPlayerUiState(
      channel: state.channel,
      quality: state.quality,
      geoBlocked: state.geoBlocked,
      playing: value.isInitialized && value.isPlaying,
      buffering: value.isBuffering,
      // 播放中途解码/网络错误：置错误态（页面显示信号丢失 + 重试）。
      errorType: value.hasError ? AppErrorType.unknown : null,
    );
  }

  Future<void> togglePlayPause() async {
    final v = _video;
    if (v == null || !v.value.isInitialized || v.value.hasError) return;
    if (v.value.isPlaying) {
      await v.pause();
    } else {
      await v.play();
    }
  }

  void retry() {
    final channel = state.channel;
    if (channel == null) return;
    _currentUuid = null;
    unawaited(play(channel));
  }

  Future<void> _releaseVideo() async {
    final v = _video;
    _video = null;
    if (v != null) {
      v.removeListener(_onVideoChanged);
      await v.dispose();
    }
  }
}

/// autoDispose：TV 播放页 pop 即释放解码器。
final tvPlaybackProvider =
    NotifierProvider.autoDispose<TvPlaybackController, TvPlayerUiState>(
        TvPlaybackController.new);
