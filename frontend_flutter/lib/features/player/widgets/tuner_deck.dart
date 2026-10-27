import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/volume_control.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/station_logo.dart';
import '../../../data/dto/iptv_dto.dart';
import '../../../data/providers.dart';
import '../../../domain/models/station.dart';
import '../../../l10n_helper.dart';
import '../../browse/discover/discover_controller.dart';
import '../player_controller.dart';
import '../visualizer_controller.dart';
import 'player_widgets.dart';
import 'shuttle_drum.dart';

/// 刻度尺上每个电台占用的横向间距。
const double kTunerSlotWidth = 40;

/// 中央列内容自然总高（显示屏70+间距+刻度尺66+波形40+走带键78）。
const double _kDeckCenterHeight = 280;

/// 车机模式（MMI 金属质感）：深色拉丝面板 + 背光实体按键 + 大触控目标，
/// 驾驶盲操习惯——最左列功能键（退出/停止/波段序号/收藏），中央车载
/// 显示屏/刻度尺/走带键，右侧预设列表与双滚轮列（上=电台飞梭、下=音量）。
class TunerDeck extends ConsumerStatefulWidget {
  const TunerDeck({super.key, required this.onExit});

  /// 退出车机模式，回到竖屏。
  final VoidCallback onExit;

  @override
  ConsumerState<TunerDeck> createState() => _TunerDeckState();
}

class _TunerDeckState extends ConsumerState<TunerDeck>
    with SingleTickerProviderStateMixin {
  static const Duration _alignDuration = Duration(milliseconds: 260);

  /// 滑轨偏移：单位 = 电台槽位（double），中心指针处的槽位值。
  double _offset = 0;
  bool _dragging = false;
  int? _lastTarget;
  int _lastFloor = 0;

  /// PRESETS 列表滚动：调台时自动滚到当前台。
  final ScrollController _presetsCtrl = ScrollController();

  /// 游标卡尺联动：列表自由滚动，中线游标停在哪个行就选哪个台。
  bool _listDragging = false;
  int _lastCenter = -1;

  /// 预设行固定高度（内容 38 + 底部外距 6）。
  static const double _presetRowExtent = 45;

  late final AnimationController _align = AnimationController(
    vsync: this,
    duration: _alignDuration,
  );
  Tween<double>? _tween;

  /// 媒体音量（右下滚轮）。原生系统音量通道不可用时降级为播放器音量，
  /// 滚轮始终可动；仅两者都不可用才置灰（实际不存在这种情况）。
  int _volume = 0;
  int _maxVolume = 15;
  bool _nativeVolume = false;

  /// BAND 键：电台波段 ↔ TV 波段切换。车机横屏无视频画面（驾驶安全 +
  /// video_player 无鸿蒙/无车机 surface），TV 频道走 just_audio 播 m3u8
  /// 音频轨；个别纯视频流无声、需自定义 Referer 的流会失败（已知限制）。
  List<Station>? _savedRadioBand;
  bool _tvBandLoading = false;

  @override
  void initState() {
    super.initState();
    _align.addListener(() {
      final tween = _tween;
      if (tween == null) return;
      setState(() => _offset = tween.evaluate(_align));
    });
    _loadVolume();
    _presetsCtrl.addListener(_onPresetsScroll);
  }

  /// PRESETS 滚近底部：向分页来源续载电台（固定列表为空操作）。
  void _onPresetsScroll() {
    if (!_presetsCtrl.hasClients) return;
    final pos = _presetsCtrl.position;
    if (pos.maxScrollExtent - pos.pixels <= 120) {
      ref.read(tuningBandProvider.notifier).loadMore();
    }
  }

  /// 游标卡尺联动：列表自由滚动，中线游标正对的那一行就是当前电台。
  /// 中心索引 = round(滚动偏移 / 行高)，索引一变即 _tune 到该台
  /// （复用飞梭的 320ms 防抖与触感）；完全静止后吸附让该行正对游标。
  /// 程序滚动（飞梭/走带/点台触发的 _scrollPresets）只发生在
  /// _listDragging=false 时，不参与索引读取，不会形成回环。
  bool _onPresetsNotification(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _listDragging = true;
      _lastCenter = _centerIndex();
      return false;
    }
    if (n is ScrollUpdateNotification && _listDragging) {
      final i = _centerIndex();
      if (i >= 0 && i != _lastCenter) {
        final dir = _lastCenter < 0 ? 0 : i - _lastCenter;
        _lastCenter = i;
        if (dir != 0) {
          HapticFeedback.selectionClick();
          _tune(dir);
        }
      }
      return false;
    }
    if (n is ScrollEndNotification && _listDragging) {
      _listDragging = false;
      final i = _lastCenter;
      if (i >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollPresets(i);
        });
      }
    }
    return false;
  }

  /// 当前正对中线游标的电台索引；无电台时返回 -1。
  /// 列表上下 padding = (视口高-行高)/2，故 offset = index × 行高
  /// 时该行恰好卡进游标，首尾台也能居中。
  int _centerIndex() {
    if (!_presetsCtrl.hasClients) return -1;
    final count = ref.read(tuningBandProvider).length;
    if (count == 0) return -1;
    return (_presetsCtrl.offset / _presetRowExtent).round().clamp(0, count - 1);
  }

  Future<void> _loadVolume() async {
    final lvl = await VolumeControl.get();
    if (!mounted) return;
    if (lvl != null) {
      setState(() {
        _volume = lvl.volume;
        _maxVolume = lvl.max;
        _nativeVolume = true;
      });
      return;
    }
    // 降级：播放器音量（0..1）映射到 0..15 档。
    final pv = ref.read(audioHandlerProvider).playerVolume;
    setState(() {
      _volume = (pv * _maxVolume).round().clamp(0, _maxVolume);
    });
  }

  /// 音量滚轮步进：上拨（dir=+1）增大、下拨减小。
  Future<void> _changeVolume(int dir) async {
    final next = (_volume + dir).clamp(0, _maxVolume);
    if (next == _volume) return;
    setState(() => _volume = next);
    if (_nativeVolume) {
      final lvl = await VolumeControl.set(next);
      if (!mounted || lvl == null) return;
      setState(() {
        _volume = lvl.volume;
        _maxVolume = lvl.max;
      });
    } else {
      await ref.read(audioHandlerProvider).setPlayerVolume(next / _maxVolume);
    }
  }

  @override
  void dispose() {
    _presetsCtrl.removeListener(_onPresetsScroll);
    _presetsCtrl.dispose();
    _align.dispose();
    super.dispose();
  }

  void _tune(int dir) => ref.read(tunerProvider.notifier).tune(dir);

  /// PRESETS 列表滚到第 [index] 台，使其可见（滚轮/刻度/跳台联动）。
  void _scrollPresets(int index) {
    if (!_presetsCtrl.hasClients) return;
    final pos = _presetsCtrl.position;
    final want = (index * _presetRowExtent).clamp(0.0, pos.maxScrollExtent);
    if ((pos.pixels - want).abs() < 1) return;
    _presetsCtrl.animateTo(
      want,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

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

  bool _isTvBandOf(List<Station> band) =>
      band.isNotEmpty && isIptvStation(band.first);

  /// BAND 键：电台波段 ↔ TV 波段（选中国家，固定列表；tune/play 链路零改动）。
  Future<void> _toggleBand() async {
    if (_tvBandLoading) return;
    final ctrl = ref.read(tuningBandProvider.notifier);
    if (_isTvBandOf(ref.read(tuningBandProvider))) {
      final saved = _savedRadioBand;
      if (saved != null) ctrl.set(saved);
      return;
    }
    _savedRadioBand = ref.read(tuningBandProvider);
    setState(() => _tvBandLoading = true);
    try {
      final code = effectiveCountryCode(
        ref.read(selectedCountryProvider),
      ).toUpperCase();
      final tv = await ref
          .read(iptvRepositoryProvider)
          .channels(countryCode: code);
      if (!mounted || tv.isEmpty) return;
      ctrl.set(tv);
    } catch (_) {
      // 加载失败：保持当前电台波段。
    } finally {
      if (mounted) setState(() => _tvBandLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final player = ref.watch(playerProvider);
    final band = ref.watch(tuningBandProvider);
    final pending = ref.watch(tunerProvider);
    final station = player.station;

    final bandIdx = station == null
        ? -1
        : band.indexWhere((s) => s.uuid == station.uuid);
    final target = pending ?? bandIdx;
    final tuning = pending != null;

    // 目标变化时滑轨对齐 + PRESETS 列表滚动到当前台（postFrame，避免
    // build 中触发动画）。
    if (_lastTarget != target) {
      _lastTarget = target;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _alignTo(target.toDouble());
        // 用户正在拖列表：位置由手指掌控，程序回滚会与其滚动事件互相
        // 触发形成回环，跳过（松手时由 _onPresetsNotification 吸附）。
        if (!_listDragging) _scrollPresets(target);
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
        child: Row(
          children: [
            // ---- 最左列：退出 / 停止 / 波段序号 / 收藏 ----
            SizedBox(
              width: 56,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PhysBtn(
                      icon: Icons.fullscreen_exit_rounded,
                      size: 44,
                      iconSize: 22,
                      onTap: widget.onExit,
                    ),
                    const SizedBox(height: 10),
                    _PhysBtn(
                      icon: Icons.power_settings_new_rounded,
                      size: 44,
                      iconSize: 22,
                      onTap: _stopAll,
                    ),
                    const SizedBox(height: 12),
                    Tooltip(
                      message: l10n.tvAudioOnlyHint,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _toggleBand,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Column(
                            children: [
                              Text(
                                _isTvBandOf(band) ? 'BAND·TV' : 'BAND',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontMono,
                                  fontSize: 9,
                                  letterSpacing: 2,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _tvBandLoading
                                    ? '··'
                                    : '${bandIdx < 0 ? '--' : (bandIdx + 1).toString().padLeft(2, '0')}/${band.length}',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontMono,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FavoriteButton(station: station),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
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
                          logoUrl: station?.logoUrl ?? '',
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
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      )
                                    : const SizedBox.expand(),
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
                            // 波形独立订阅频谱流，重建/重绘都被限制在
                            // 这条 34px 高的子树，不再牵动整个车机页。
                            child: _DeckWaveform(
                              playing: player.playing,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // 走带键：上一台 / 播放 / 下一台（大触控目标，可盲操）。
                        // FittedBox 兜底：窄屏时按钮行按自然宽收缩并等比微缩，防溢出。
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
            // ---- 右：电台预设列 ----
            SizedBox(
              width: 170,
              child: _MetalPanel(
                radius: 12,
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 14,
                      child: Padding(
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
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      // 上下各垫 (视口高-行高)/2 的 padding：
                      // scroll = index × 行高 时选中行恰好居中，
                      // 且首尾台也能居中（滚动范围恰好覆盖）。
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final pad = ((c.maxHeight - _presetRowExtent) / 2)
                              .clamp(0.0, double.infinity);
                          final list = NotificationListener<ScrollNotification>(
                            onNotification: _onPresetsNotification,
                            child: ListView.builder(
                              controller: _presetsCtrl,
                              padding: EdgeInsets.symmetric(vertical: pad),
                              itemExtent: _presetRowExtent,
                              itemCount: band.length,
                              itemBuilder: (context, i) {
                                final s = band[i];
                                // 行本身无选中态：哪一行被中线游标"夹住"
                                // 哪一行就是当前电台，样式完全统一。
                                return _PresetRow(
                                  index: i,
                                  name: s.name.trim(),
                                  onTap: () =>
                                      ref.read(playerProvider.notifier).play(s),
                                );
                              },
                            ),
                          );
                          if (band.isEmpty) return list;
                          // 游标卡尺：固定在中线的卡爪游标，列表从其上下
                          // 自由滑过，滚动读台（不随列表移动）。
                          return Stack(
                            children: [
                              list,
                              Positioned(
                                top: (c.maxHeight - _presetRowExtent) / 2,
                                left: 0,
                                right: 4,
                                height: _presetRowExtent,
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    // 卡片高 = 行高 - 底部外距 6。
                                    painter: _CaliperPainter(
                                      scheme.primary,
                                      cardHeight: _presetRowExtent - 6,
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    // 与顶部标题区对称，使列表视口中心 = 面板中心，
                    // 选中行恰好居于中线。
                    const SizedBox(height: 6),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // ---- 最右：双滚轮同列——上=电台飞梭，下=音量。
            // 音量图标与数字竖排在滚轮左侧，滚轮本体与飞梭右缘对齐。----
            SizedBox(
              width: 78,
              child: Column(
                children: [
                  // 电台切换飞梭（上拨=下一台）：连杆紧贴滚轮左缘，
                  // 与飞轮同排右对齐（鼓面右缘仍与音量滚轮对齐），
                  // 视觉上把飞轮与左侧预设列表扣成一体。
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IgnorePointer(
                            child: _LinkRod(
                              color: band.isNotEmpty
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                          ShuttleDrum(
                            width: 56,
                            axis: Axis.vertical,
                            // 向内侧倾斜：左缘朝向观察者。
                            tiltY: 8,
                            enabled: band.isNotEmpty,
                            onStep: _tune,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // 音量滚轮（上拨增大、下拨减小）。
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _volume > 0
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_off_rounded,
                                size: 16,
                                color: _volume > 0
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$_volume',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontMono,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: ShuttleDrum(
                            width: 56,
                            axis: Axis.vertical,
                            tiltY: 8,
                            onStep: _changeVolume,
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

/// 车载显示屏：内凹深色屏 + 电台台标 + 台名/状态，暗光下可远读。
class _DisplayPanel extends StatelessWidget {
  const _DisplayPanel({
    required this.logoUrl,
    required this.tuning,
    required this.name,
    required this.statusText,
    required this.statusColor,
  });

  final String logoUrl;
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
          // 电台台标（替代原 CH 序号读数）。
          StationLogo(logoUrl: logoUrl, name: name, size: 48, borderRadius: 8),
          const SizedBox(width: 14),
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

/// 预设行：编号 + 台名的大触控条。行本身无选中态——当前台由中线
/// 卡尺游标"夹住"读出，所有行样式完全统一。
class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.index,
    required this.name,
    required this.onTap,
  });

  final int index;
  final String name;
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
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF20252F), Color(0xFF141820)],
              ),
              border: Border.all(color: const Color(0xFF313846)),
            ),
            child: Row(
              children: [
                Text(
                  (index + 1).toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontFamily: AppTheme.fontMono,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
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
                      color: scheme.onSurface,
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

/// 卡尺游标：只画在列表左缘——一道青色竖向准线 + 指向行内的三角，
/// 垂直对准被选中行的中心。列表从其上下自由滑过，准线停在哪一行
/// 就选中哪一行（不包裹整行，避免"列表上多了一个东西"的观感）。
class _CaliperPainter extends CustomPainter {
  _CaliperPainter(this.color, {required this.cardHeight});

  final Color color;
  final double cardHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = cardHeight / 2;
    // 准线柔光衬底。
    canvas.drawLine(
      Offset(2, cy - 13),
      Offset(2, cy + 13),
      Paint()
        ..color = color.withValues(alpha: 0.20)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // 左缘竖向准线。
    canvas.drawLine(
      Offset(2, cy - 13),
      Offset(2, cy + 13),
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    // 指向行内的三角：标出被夹住的行（尖到 x=9，不压行号文字）。
    canvas.drawPath(
      Path()
        ..moveTo(4, cy - 4.5)
        ..lineTo(9, cy)
        ..lineTo(4, cy + 4.5)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_CaliperPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.cardHeight != cardHeight;
}

/// 连杆：电台飞梭与预设列表间隙里的发光机械连接杆——水平发光
/// 短杆 + 两端销钉 + 金属高光棱线，把飞轮与列表"扣"成一体。
class _LinkRod extends StatelessWidget {
  const _LinkRod({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(
        painter: _RodPainter(color: color),
        // 无 child 的 CustomPaint 在松约束下塌缩为 0。
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RodPainter extends CustomPainter {
  _RodPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    // 微光衬底。
    canvas.drawLine(
      Offset(1, y),
      Offset(size.width - 1, y),
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // 杆身。
    canvas.drawLine(
      Offset(1, y),
      Offset(size.width - 1, y),
      Paint()
        ..color = color
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    // 高光棱线：金属杆的受光面。
    canvas.drawLine(
      Offset(1, y - 1.2),
      Offset(size.width - 1, y - 1.2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    // 两端销钉。
    canvas.drawCircle(Offset(3, y), 4.2, Paint()..color = color);
    canvas.drawCircle(Offset(size.width - 3, y), 4.2, Paint()..color = color);
    canvas.drawCircle(
      Offset(3, y - 1),
      1.6,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
    canvas.drawCircle(
      Offset(size.width - 3, y - 1),
      1.6,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_RodPainter oldDelegate) => oldDelegate.color != color;
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

    // 刻度/文字/辉光裁进画布：iMin 侧最远可到 x=-40，无裁剪会画出面板
    // 叠到左侧封面上（CustomPaint 默认不裁剪绘制内容）。
    canvas.clipRect(Offset.zero & size);

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

/// 车机波形：全页唯一订阅 visualizerProvider 的子树。
/// 自带流动相位 ticker，频谱帧只重建这条 34px 高的波形带；
/// RepaintBoundary 把每帧重绘（含 MaskFilter 辉光）隔离在本子树。
class _DeckWaveform extends ConsumerStatefulWidget {
  const _DeckWaveform({required this.playing, required this.color});

  final bool playing;
  final Color color;

  @override
  ConsumerState<_DeckWaveform> createState() => _DeckWaveformState();
}

class _DeckWaveformState extends ConsumerState<_DeckWaveform>
    with SingleTickerProviderStateMixin {
  /// 波形相位：播放中持续流动，让合成波形线"活"起来；
  /// 暂停即停（省电：不再 60fps 重绘这条辉光路径）。
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _wave.repeat();
  }

  @override
  void didUpdateWidget(_DeckWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing == widget.playing) return;
    if (widget.playing) {
      if (!_wave.isAnimating) _wave.repeat();
    } else {
      _wave.stop();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bands = ref.watch(visualizerProvider.select((s) => s.bands));
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _wave,
        builder: (context, _) => CustomPaint(
          painter: _WaveformPainter(
            bands: bands,
            t: _wave.value,
            playing: widget.playing,
            color: widget.color,
          ),
          // 无 child 的 CustomPaint 在松约束下塌缩为 0。
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
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
