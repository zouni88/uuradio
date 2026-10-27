import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/neon.dart';
import '../../core/widgets/skeleton.dart';
import '../../domain/models/station.dart';
import '../../l10n_helper.dart';
import 'tv_playback_controller.dart';

/// IPTV 全屏视频播放页：赛博朋克描边画面 + 霓虹控制条。
class TvPlayerPage extends ConsumerStatefulWidget {
  const TvPlayerPage({super.key, required this.channel});

  final Station channel;

  @override
  ConsumerState<TvPlayerPage> createState() => _TvPlayerPageState();
}

class _TvPlayerPageState extends ConsumerState<TvPlayerPage> {
  @override
  void initState() {
    super.initState();
    // 首帧后起播（build 的 watch 让 provider 随页面存活，pop 即 autoDispose）。
    Future.microtask(() {
      if (mounted) ref.read(tvPlaybackProvider.notifier).play(widget.channel);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    // watch 同时保活 provider。
    final state = ref.watch(tvPlaybackProvider);
    final controller = ref.read(tvPlaybackProvider.notifier).videoController;
    final showVideo = controller != null &&
        controller.value.isInitialized &&
        !state.hasError;

    return Scaffold(
      backgroundColor: scheme.scrim,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: NeonText(
          state.channel?.name ?? widget.channel.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (state.quality.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  state.quality.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AppTheme.fontMono,
                    fontSize: 12,
                    color: scheme.primary.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          if (state.geoBlocked)
            Tooltip(
              message: l10n.tvGeoBlocked,
              child: Icon(Icons.gps_not_fixed_rounded,
                  size: 20, color: scheme.tertiary),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: state.hasError
                  ? _SignalLost(onRetry: _retry)
                  : showVideo
                      ? _VideoSurface(controller: controller)
                      : _LoadingSurface(
                          label:
                              state.initializing ? l10n.tvLoading : l10n.tvBuffering,
                        ),
            ),
          ),
          _ControlBar(state: state, onToggle: _toggle),
        ],
      ),
    );
  }

  void _toggle() => ref.read(tvPlaybackProvider.notifier).togglePlayPause();

  void _retry() => ref.read(tvPlaybackProvider.notifier).retry();
}

/// 视频画面：霓虹描边内凹屏。
class _VideoSurface extends StatelessWidget {
  const _VideoSurface({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: NeonBox(
        background: Colors.black,
        borderRadius: 14,
        padding: const EdgeInsets.all(6),
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio.isFinite &&
                  controller.value.aspectRatio > 0
              ? controller.value.aspectRatio
              : 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}

/// 起播/缓冲占位：16:9 骨架 + 霓虹文案。
class _LoadingSurface extends StatelessWidget {
  const _LoadingSurface({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: LayoutBuilder(
              builder: (context, constraints) => Skeleton(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                radius: 14,
              ),
            ),
          ),
          const SizedBox(height: 18),
          NeonText(label,
              style: const TextStyle(fontFamily: AppTheme.fontMono, fontSize: 13)),
        ],
      ),
    );
  }
}

/// 信号丢失（社区流失效是常态）：文案 + 一键重试。
class _SignalLost extends StatelessWidget {
  const _SignalLost({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off_rounded,
              size: 44, color: scheme.primary.withValues(alpha: 0.55)),
          const SizedBox(height: 16),
          Text(
            l10n.tvSignalLost,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 20),
          FilledButton.tonal(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}

/// 底部控制条：播放/暂停 + 正在收看。
class _ControlBar extends StatelessWidget {
  const _ControlBar({required this.state, required this.onToggle});

  final TvPlayerUiState state;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        children: [
          IconButton(
            iconSize: 40,
            onPressed: state.hasError || state.channel == null
                ? null
                : onToggle,
            icon: Icon(
              state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: scheme.primary,
            ),
            style: IconButton.styleFrom(
              backgroundColor:
                  scheme.surfaceContainerLow.withValues(alpha: 0.75),
              side: BorderSide(color: scheme.primary.withValues(alpha: 0.45)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.tvNowWatching,
                  style: TextStyle(
                    fontFamily: AppTheme.fontMono,
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.channel?.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
