import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/router/app_navigator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/widgets/station_logo.dart';
import '../../../l10n_helper.dart';
import '../../../domain/models/station.dart';
import '../player_controller.dart';
import '../sleep_timer_controller.dart';
import '../visualizer_controller.dart';
import 'player_widgets.dart';
import 'sleep_timer_sheet.dart';
import 'spectrum_painter.dart';
import 'tuner_deck.dart';

/// 全屏播放页：竖屏为赛博朋克舞台；点调谐按钮进入横屏调谐台（TunerDeck）。
/// 横屏仅由按钮控制，不跟随物理旋转，也不受系统方向锁影响。
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  bool _fallbackNotified = false;

  /// 调谐台模式：不改变系统方向，在竖屏窗口内旋转渲染，
  /// 因此不受系统"锁定屏幕方向"影响，且仅由按钮控制进出。
  bool _deckMode = false;

  @override
  void dispose() {
    if (_deckMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _enterDeck() {
    setState(() => _deckMode = true);
    // 沉浸式全屏：隐藏状态栏/导航栏，横屏视野不被系统栏遮挡。
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitDeck() {
    setState(() => _deckMode = false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final player = ref.watch(playerProvider);
    final visualizer = ref.watch(visualizerProvider);
    final sleepRemaining = ref.watch(sleepTimerProvider);
    final station = player.station;

    // 频谱权限被拒绝时提示一次。
    ref.listen(visualizerProvider.select((s) => s.permissionDenied),
        (prev, next) {
      if (next && !_fallbackNotified) {
        _fallbackNotified = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.spectrumFallback)),
        );
      }
    });

    if (station == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.empty)),
      );
    }

    final errorText = switch (player.errorType) {
      AppErrorType.network => l10n.errorNetwork,
      AppErrorType.timeout => l10n.errorNetwork,
      AppErrorType.server || AppErrorType.unknown || null => player.errorType == null
          ? null
          : l10n.playbackError,
    };

    final statusColor = player.errorType != null
        ? scheme.error
        : player.playing
            ? scheme.primary
            : scheme.onSurfaceVariant;

    if (_deckMode) {
      return Scaffold(
        body: _RotatedLandscape(child: TunerDeck(onExit: _exitDeck)),
      );
    }

    return Scaffold(
      body: _buildPortrait(
        context,
        l10n: l10n,
        scheme: scheme,
        player: player,
        visualizer: visualizer,
        sleepRemaining: sleepRemaining,
        station: station,
        errorText: errorText,
        statusColor: statusColor,
      ),
    );
  }

  // ---------- 竖屏：赛博朋克舞台 ----------

  Widget _buildPortrait(
    BuildContext context, {
    required AppLocalizations l10n,
    required ColorScheme scheme,
    required PlayerUiState player,
    required VisualizerState visualizer,
    required Duration? sleepRemaining,
    required Station station,
    required String? errorText,
    required Color statusColor,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 模糊封面背景
        if (station.logoUrl.isNotEmpty)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Image.network(
                station.logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        // 暗化渐变
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surface.withValues(alpha: 0.86),
                  scheme.surface.withValues(alpha: 0.96),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              // 小屏内容超高时可滚动；空间充足时三组之间用 spaceBetween 撑开。
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // ---- 顶组：导航 + 信号 HUD ----
                        Column(
                          children: [
                            // 顶栏
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 30),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: scheme.primary
                                          .withValues(alpha: 0.55),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: scheme.primary
                                            .withValues(alpha: 0.18),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    l10n.nowPlaying,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontDisplay,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 进入横屏调谐台（按钮控制，不跟随物理旋转/系统方向锁）
                                IconButton(
                                  icon: const Icon(Icons.tune_rounded,
                                      size: 24),
                                  color: scheme.onSurfaceVariant,
                                  onPressed: _enterDeck,
                                ),
                                FavoriteButton(station: station),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // 信号 HUD：SIGNAL / NET / LINK
                            SignalHud(player: player),
                          ],
                        ),
                        // ---- 中组：封面 + 台名 + 频谱 ----
                        Column(
                          children: [
                            // 霓虹发光封面
                            Hero(
                              tag: 'station-logo-${station.uuid}',
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(34),
                                  border: Border.all(
                                    color:
                                        scheme.primary.withValues(alpha: 0.85),
                                    width: 1.4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: scheme.primary
                                          .withValues(alpha: 0.4),
                                      blurRadius: 44,
                                      spreadRadius: 2,
                                    ),
                                    BoxShadow(
                                      color: scheme.secondary
                                          .withValues(alpha: 0.28),
                                      blurRadius: 90,
                                    ),
                                  ],
                                ),
                                child: StationLogo(
                                  logoUrl: station.logoUrl,
                                  name: station.name,
                                  size: 214,
                                  borderRadius: 28,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              station.name.trim(),
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(color: scheme.onSurface),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              stationSubtitle(
                                station.countryCode,
                                station.country,
                                station.bitrate,
                                station.codec,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTheme.fontMono,
                                color: scheme.onSurfaceVariant,
                                fontSize: 12.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // 频谱
                              SizedBox(
                              width: 300,
                              height: 60,
                              child: CustomPaint(
                                painter: SpectrumPainter(
                                  bands: visualizer.bands.isEmpty
                                      ? const <double>[]
                                      : visualizer.bands,
                                  color: scheme.primary,
                                  secondary: scheme.secondary,
                                  playing: player.playing,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // 状态行
                            SizedBox(
                              height: 20,
                              child: Text(
                                player.loading
                                    ? l10n.connecting
                                    : player.playing
                                        ? (player.icyTitle != null
                                            ? l10n.nowBroadcasting(
                                                player.icyTitle!)
                                            : l10n.nowPlaying)
                                        : (errorText ?? l10n.paused),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontMono,
                                  color: statusColor,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // ---- 底组：控制区 ----
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ControlIcon(
                                  icon: Icons.bedtime_rounded,
                                  tooltip: l10n.sleepTimer,
                                  active: sleepRemaining != null,
                                  onTap: () => showSleepTimerSheet(context),
                                ),
                                const SizedBox(width: 28),
                                PlayButton(player: player, station: station),
                                const SizedBox(width: 28),
                                ControlIcon(
                                  icon: Icons.stop_rounded,
                                  tooltip: l10n.paused,
                                  onTap: () {
                                    ref.read(playerProvider.notifier).stop();
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // 主页链接
                            if (station.homepage.isNotEmpty)
                              TextButton.icon(
                                onPressed: () => AppNavigator.openHomepage(
                                    context, station.homepage),
                                icon: const Icon(Icons.link_rounded, size: 18),
                                label: Text(l10n.visitHomepage),
                              ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 强制横屏渲染包装：不改变系统屏幕方向，而是把子内容按横屏尺寸
/// 布局后旋转 90° 绘制在竖屏窗口内。因此系统"锁定屏幕方向"不影响它，
/// 触摸命中测试由 Flutter 自动换算。
/// 进入时配合 immersiveSticky 隐藏系统栏，刘海/圆角安全区
/// 按旋转后的方向映射为内容内边距。
class _RotatedLandscape extends StatelessWidget {
  const _RotatedLandscape({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Center(
            child: RotatedBox(
              quarterTurns: 1,
              child: SizedBox(
                width: constraints.maxHeight,
                height: constraints.maxWidth,
                child: Padding(
                  // 竖屏的四边安全区映射到旋转后内容的四边。
                  padding: EdgeInsets.only(
                    left: padding.top,
                    top: padding.right,
                    right: padding.bottom,
                    bottom: padding.left,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
