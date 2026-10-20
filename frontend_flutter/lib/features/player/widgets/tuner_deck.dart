import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/station_logo.dart';
import '../../../l10n_helper.dart';
import '../player_controller.dart';
import '../visualizer_controller.dart';
import 'player_widgets.dart';
import 'shuttle_drum.dart';

/// 刻度尺上每个电台占用的横向间距。
const double kTunerSlotWidth = 40;

/// 中央列内容自然总高（显示屏70+间距+刻度尺66+波形40+走带键78）。
const double _kDeckCenterHeight = 280;

/// 车机模式（MMI 金属质感）：深色拉丝面板 + 背光实体按键 + 大触控目标，
/// 驾驶盲操习惯——左封面区、中央车载显示屏/刻度尺/走带键、右侧飞梭与电台预设。
class TunerDeck extends ConsumerStatefulWidget {
  const TunerDeck({super.key, required this.onExit});

  /// 退出车机模式，回到竖屏。
  final VoidCallback onExit;

  @override
  ConsumerState<TunerDeck> createState() => _TunerDeckState();
}

class _TunerDeckState extends ConsumerState<TunerDeck>
    with TickerProviderStateMixin {
  static const Duration _alignDuration = Duration(milliseconds: 260);

  /// 滑轨偏移：单位 = 电台槽位（double），中心指针处的槽位值。
  double _offset = 0;
  bool _dragging = false;
  int? _lastTarget;
  int _lastFloor = 0;

  late final AnimationController _align = AnimationController(
    vsync: this,
    duration: _alignDuration,
  );
  Tween<double>? _tween;

  /// 波形相位：持续流动，让合成波形线"活"起来。
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _align.addListener(() {
      final tween = _tween;
      if (tween == null) return;
      setState(() => _offset = tween.evaluate(_align));
    });
  }

  @override
  void dispose() {
    _wave.dispose();
    _align.dispose();
    super.dispose();
  }

  void _tune(int dir) => ref.read(tunerProvider.notifier).tune(dir);

  /// 滑轨对齐到目标电台（拖动中不对齐）。
  void _alignTo(double target) {
    if (_dragging || !mounted) return;
    if ((target - _offset).abs() < 0.001) {
      setState(() => _offset = target);
      return;
    }
    _tween = Tween(begin: _offset, end: target);
    _align.forward(from: 0);
  }

  void _stopAll() {
    ref.read(playerProvider.notifier).stop();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final player = ref.watch(playerProvider);
    final band = ref.watch(tuningBandProvider);
    final pending = ref.watch(tunerProvider);
    final visualizer = ref.watch(visualizerProvider);
    final station = player.station;

    final bandIdx = station == null
        ? -1
        : band.indexWhere((s) => s.uuid == station.uuid);
    final target = pending ?? bandIdx;
    final tuning = pending != null;

    // 目标变化时滑轨对齐（postFrame，避免 build 中触发动画）。
    if (_lastTarget != target) {
      _lastTarget = target;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _alignTo(target.toDouble());
      });
    }

    final errorText = switch (player.errorType) {
      AppErrorType.network => l10n.errorNetwork,
      AppErrorType.timeout => l10n.errorNetwork,
      AppErrorType.server ||
      AppErrorType.unknown ||
      null => player.errorType == null ? null : l10n.playbackError,
    };
    final statusText = player.loading
        ? l10n.connecting
        : player.playing
        ? (player.icyTitle != null
              ? l10n.nowBroadcasting(player.icyTitle!)
              : l10n.nowPlaying)
        : (errorText ?? l10n.paused);
    final statusColor = player.errorType != null
        ? scheme.error
        : player.playing
        ? scheme.primary
        : scheme.onSurfaceVariant;

    return Container(
      // 车机深色底。
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0D14), Color(0xFF05060A)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          children: [
            // ---- 顶栏：退出 / 停止 / 波段 / 收藏 ----
            Row(
              children: [
                _PhysBtn(
                  icon: Icons.fullscreen_exit_rounded,
                  size: 44,
                  iconSize: 22,
                  onTap: widget.onExit,
                ),
                const SizedBox(width: 10),
                _PhysBtn(
                  icon: Icons.power_settings_new_rounded,
                  size: 44,
                  iconSize: 22,
                  onTap: _stopAll,
                ),
                const Spacer(),
                Text(
                  'BAND',
                  style: TextStyle(
                    fontFamily: AppTheme.fontMono,
                    fontSize: 10,
                    letterSpacing: 3,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${bandIdx < 0 ? '--' : (bandIdx + 1).toString().padLeft(2, '0')} / ${band.length}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontMono,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                FavoriteButton(station: station),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  // ---- 左：大封面 + 信号 HUD ----
                  SizedBox(
                    width: 240,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _MetalPanel(
                          radius: 18,
                          padding: const EdgeInsets.all(8),
                          child: StationLogo(
                            logoUrl: station?.logoUrl ?? '',
                            name: station?.name ?? '',
                            size: 150,
                            borderRadius: 12,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SignalHud(player: player),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // ---- 中：车载显示屏 + 刻度尺 + 波形 + 走带键 ----
                  // 矮屏兜底：装得下时正常布局；装不下才用 FittedBox 等比微缩。
                  // 注意：FittedBox 会给子节点无界约束，显示屏内 Expanded /
                  // CustomPaint 在无界宽度下会塌缩导致黑屏，故始终经
                  // LayoutBuilder 传入真实宽度。
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final content = SizedBox(
                          width: constraints.maxWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _DisplayPanel(
                                target: target,
                                tuning: tuning,
                                name: station?.name.trim() ?? l10n.empty,
                                statusText: statusText,
                                statusColor: statusColor,
                              ),
                              const SizedBox(height: 8),
                              _MetalPanel(
                                radius: 12,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: SizedBox(
                                  height: 56,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onHorizontalDragStart: _onScaleDragStart,
                                    onHorizontalDragUpdate: _onScaleDragUpdate,
                                    onHorizontalDragEnd: _onScaleDragEnd,
                                    child: CustomPaint(
                                      painter: _ScalePainter(
                                        offset: _offset,
                                        count: band.length,
                                        scheme: scheme,
                                      ),
                                      child: band.isEmpty
                                          ? Center(
                                              child: Text(
                                                l10n.noResults,
                                                style: TextStyle(
                                                  fontFamily: AppTheme.fontMono,
                                                  fontSize: 12,
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _MetalPanel(
                                radius: 12,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 2,
                                ),
                                child: SizedBox(
                                  height: 34,
                                  child: AnimatedBuilder(
                                    animation: _wave,
                                    builder: (context, _) => CustomPaint(
                                      painter: _WaveformPainter(
                                        bands: visualizer.bands,
                                        t: _wave.value,
                                        playing: player.playing,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              // 走带键：上一台 / 播放 / 下一台（大触控目标，可盲操）。
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _PhysBtn(
                                    icon: Icons.skip_previous_rounded,
                                    size: 60,
                                    iconSize: 30,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      _tune(-1);
                                    },
                                  ),
                                  const SizedBox(width: 18),
                                  _PhysBtn(
                                    icon: player.loading
                                        ? Icons.autorenew_rounded
                                        : player.playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 78,
                                    iconSize: 40,
                                    active: player.playing,
                                    onTap: () {
                                      if (player.loading) return;
                                      ref
                                          .read(playerProvider.notifier)
                                          .togglePlayPause();
                                    },
                                  ),
                                  const SizedBox(width: 18),
                                  _PhysBtn(
                                    icon: Icons.skip_next_rounded,
                                    size: 60,
                                    iconSize: 30,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      _tune(1);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                        if (constraints.maxHeight >= _kDeckCenterHeight) {
                          return Center(child: content);
                        }
                        return FittedBox(fit: BoxFit.scaleDown, child: content);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // ---- 右：横向飞梭 + 电台预设 ----
                  SizedBox(
                    width: 220,
                    child: Column(
                      children: [
                        ShuttleDrum(
                          width: 200,
                          height: 60,
                          enabled: band.isNotEmpty,
                          onStep: _tune,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _MetalPanel(
                            radius: 12,
                            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    'PRESETS',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontMono,
                                      fontSize: 9,
                                      letterSpacing: 3,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: band.length,
                                    itemBuilder: (context, i) {
                                      final s = band[i];
                                      final active = i == target;
                                      return _PresetRow(
                                        index: i,
                                        name: s.name.trim(),
                                        active: active,
                                        onTap: () => ref
                                            .read(playerProvider.notifier)
                                            .play(s),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 滑轨拖动 ----------

  void _onScaleDragStart(DragStartDetails d) {
    if (ref.read(tuningBandProvider).isEmpty) return;
    setState(() {
      _dragging = true;
      _align.stop();
      _lastFloor = _offset.floor();
    });
  }

  void _onScaleDragUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    final count = ref.read(tuningBandProvider).length;
    var next = _offset - d.delta.dx / kTunerSlotWidth;
    next = next.clamp(-1.0, count.toDouble());
    final f = next.floor();
    setState(() => _offset = next);
    // 每跨过一个槽位步进一台（滑轨左移 = 下一台）。
    while (_lastFloor != f) {
      final dir = f > _lastFloor ? 1 : -1;
      HapticFeedback.selectionClick();
      ref.read(tunerProvider.notifier).tune(dir);
      _lastFloor += dir;
    }
  }

  void _onScaleDragEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    final target = _lastTarget ?? 0;
    _alignTo(target.toDouble());
  }
}

/// 拉丝金属面板：车机界面的容器基底（深色渐变 + 金属亮边 + 投影深度）。
class _MetalPanel extends StatelessWidget {
  const _MetalPanel({
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.radius = 14,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF242935), Color(0xFF14171E)],
        ),
        border: Border.all(color: const Color(0xFF3A4150)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 实体按键：金属渐变圆钮 + 亮边 + 投影，背光激活态（图标青色辉光）。
class _PhysBtn extends StatelessWidget {
  const _PhysBtn({
    required this.icon,
    required this.onTap,
    this.size = 64,
    this.iconSize = 30,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  /// 背光：当前功能处于活动态（如正在播放）。
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glowColor = scheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2C313C), Color(0xFF15181F)],
        ),
        border: Border.all(
          color: active
              ? glowColor.withValues(alpha: 0.9)
              : const Color(0xFF414959),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          if (active)
            BoxShadow(
              color: glowColor.withValues(alpha: 0.35),
              blurRadius: 18,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: iconSize,
              color: active ? glowColor : scheme.onSurface,
              shadows: active
                  ? [
                      Shadow(
                        blurRadius: 10,
                        color: glowColor.withValues(alpha: 0.8),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// 车载显示屏：内凹深色屏 + 大号 CH 读数 + 台名/状态，暗光下可远读。
class _DisplayPanel extends StatelessWidget {
  const _DisplayPanel({
    required this.target,
    required this.tuning,
    required this.name,
    required this.statusText,
    required this.statusColor,
  });

  final int target;
  final bool tuning;
  final String name;
  final String statusText;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chColor = tuning ? scheme.secondary : scheme.primary;
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF06080C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF20262F)),
        boxShadow: [
          BoxShadow(color: chColor.withValues(alpha: 0.10), blurRadius: 16),
          const BoxShadow(
            color: Color(0x66000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            target < 0 ? '--' : (target + 1).toString().padLeft(2, '0'),
            style: TextStyle(
              fontFamily: AppTheme.fontDisplay,
              fontSize: 40,
              fontWeight: FontWeight.w800,
              height: 1,
              color: chColor,
              shadows: [
                Shadow(blurRadius: 14, color: chColor.withValues(alpha: 0.55)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontDisplay,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontMono,
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: statusColor,
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

/// 预设行：编号 + 台名的大触控条，当前台背光高亮。
class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.index,
    required this.name,
    required this.active,
    required this.onTap,
  });

  final int index;
  final String name;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, right: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: active
                    ? [
                        scheme.primary.withValues(alpha: 0.22),
                        const Color(0xFF12161D),
                      ]
                    : const [Color(0xFF20252F), Color(0xFF141820)],
              ),
              border: Border.all(
                color: active
                    ? scheme.primary.withValues(alpha: 0.8)
                    : const Color(0xFF313846),
              ),
            ),
            child: Row(
              children: [
                Text(
                  (index + 1).toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontFamily: AppTheme.fontMono,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: active ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontDisplay,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: active ? Colors.white : scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 车机刻度尺：内凹屏上均匀细刻度 + 每 5/10 加高 + 每 10 标号，
/// 当前台青色游标（FM 调谐指针感）。
class _ScalePainter extends CustomPainter {
  _ScalePainter({
    required this.offset,
    required this.count,
    required this.scheme,
  });

  final double offset;
  final int count;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final baseY = h - 16.0;

    // 基线。
    canvas.drawLine(
      Offset(8, baseY),
      Offset(w - 8, baseY),
      Paint()
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    final tick = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final iMin = math.max(0, (offset - cx / kTunerSlotWidth).floor() - 1);
    final iMax = math.min(
      count - 1,
      (offset + cx / kTunerSlotWidth).ceil() + 1,
    );
    for (var i = iMin; i <= iMax; i++) {
      final x = cx + (i - offset) * kTunerSlotWidth;
      final major = i % 10 == 0;
      final mid = i % 5 == 0;
      final cur = (i - offset).abs() < 0.5;

      final len = major
          ? 26.0
          : mid
          ? 16.0
          : 9.0;
      tick
        ..strokeWidth = major ? 2 : 1.4
        ..color = cur
            ? scheme.primary
            : (major || mid
                  ? Colors.white.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.28));
      canvas.drawLine(Offset(x, baseY), Offset(x, baseY - len), tick);

      if (major) {
        final tp = TextPainter(
          text: TextSpan(
            text: (i + 1).toString().padLeft(2, '0'),
            style: TextStyle(
              fontFamily: AppTheme.fontMono,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: cur ? scheme.primary : Colors.white.withValues(alpha: 0.5),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, baseY + 3));
      }
    }

    // 中央游标：青色细线 + 微光 + 顶部三角（FM 指针）。
    canvas.drawLine(
      Offset(cx, 4),
      Offset(cx, baseY - 1),
      Paint()
        ..color = scheme.primary.withValues(alpha: 0.4)
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawLine(
      Offset(cx, 4),
      Offset(cx, baseY - 1),
      Paint()
        ..color = scheme.primary
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    final tri = Path()
      ..moveTo(cx - 4.5, 0)
      ..lineTo(cx + 4.5, 0)
      ..lineTo(cx, 8)
      ..close();
    canvas.drawPath(tri, Paint()..color = scheme.primary);
  }

  @override
  bool shouldRepaint(_ScalePainter oldDelegate) =>
      oldDelegate.offset != offset ||
      oldDelegate.count != count ||
      oldDelegate.scheme != scheme;
}

/// 音频波形：车载功放 VU 表感——单条青色背光细线随音乐能量起伏。
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.bands,
    required this.t,
    required this.playing,
    required this.color,
  });

  final List<double> bands;

  /// 0..1 循环相位。
  final double t;
  final bool playing;
  final Color color;

  double _ampAt(double x) {
    if (bands.isEmpty) return 0.02;
    final f = x * (bands.length - 1);
    final i = f.floor().clamp(0, bands.length - 1);
    final j = (i + 1).clamp(0, bands.length - 1);
    final fr = f - i;
    return (bands[i] * (1 - fr) + bands[j] * fr).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final mid = h / 2;
    final phase = t * 2 * math.pi;
    final gain = playing ? 1.0 : 0.25;

    const n = 140;
    final path = Path();
    for (var k = 0; k <= n; k++) {
      final x = k / n;
      // 两端收拢包络。
      final env = math.pow(math.sin(math.pi * x), 0.7).toDouble();
      // 多谐波叠加：整体形状由频谱能量调制。
      final v =
          math.sin(2 * math.pi * (x * 3 + phase * 0.5)) * 0.5 +
          math.sin(2 * math.pi * (x * 7 - phase * 0.8)) * 0.3 +
          math.sin(2 * math.pi * (x * 13 + phase * 1.3)) * 0.2;
      final y = mid + v * _ampAt(x) * env * h * 0.44 * gain;
      if (k == 0) {
        path.moveTo(x * w, y);
      } else {
        path.lineTo(x * w, y);
      }
    }

    // 背光衬底（弱）。
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // 主线。
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.bands != bands ||
      oldDelegate.playing != playing ||
      oldDelegate.color != color;
}
