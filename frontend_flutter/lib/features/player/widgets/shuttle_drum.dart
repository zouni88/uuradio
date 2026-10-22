import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// 每档（一个电台）对应的滚动像素。
const double _notchPx = 14;

/// 滚轮配色方案：鼓面受光剖面 + 槽/棱/高光颜色。
class DrumPalette {
  const DrumPalette({
    required this.body,
    required this.groove,
    required this.ridge,
    required this.highlight,
  });

  /// 基面渐变（迎光→背光 6 档）。
  final List<Color> body;

  /// 环间深槽颜色。
  final Color groove;

  /// 环顶亮边颜色。
  final Color ridge;

  /// 固定镜面柔光带颜色。
  final Color highlight;

  static const DrumPalette graphite = DrumPalette(
    body: [
      Color(0xFF78818F),
      Color(0xFF9AA3B1),
      Color(0xFF767E8C),
      Color(0xFF535A66),
      Color(0xFF333840),
      Color(0xFF1D2026),
    ],
    groove: Color(0xFF04060A),
    ridge: Color(0xFFC3CCD9),
    highlight: Color(0xFFE8EEF5),
  );

  static const DrumPalette neonCyan = DrumPalette(
    body: [
      Color(0xFF12525C),
      Color(0xFF1B7482),
      Color(0xFF125A66),
      Color(0xFF0B3A44),
      Color(0xFF072630),
      Color(0xFF04161E),
    ],
    groove: Color(0xFF02121A),
    ridge: Color(0xFF5BE7F4),
    highlight: Color(0xFF8AF2FB),
  );

  static const DrumPalette pianoBlack = DrumPalette(
    body: [
      Color(0xFF30353D),
      Color(0xFF4C525C),
      Color(0xFF323840),
      Color(0xFF1C2026),
      Color(0xFF0D0F13),
      Color(0xFF050608),
    ],
    groove: Color(0xFF000000),
    ridge: Color(0xFFD7DEE7),
    highlight: Color(0xFFFFFFFF),
  );

  static const DrumPalette warmCopper = DrumPalette(
    body: [
      Color(0xFF8A6440),
      Color(0xFFC49468),
      Color(0xFF96704A),
      Color(0xFF66482C),
      Color(0xFF402C1A),
      Color(0xFF251810),
    ],
    groove: Color(0xFF120A04),
    ridge: Color(0xFFEFC9A0),
    highlight: Color(0xFFF5DDBE),
  );

  static const DrumPalette panelGrey = DrumPalette(
    body: [
      Color(0xFF333A46),
      Color(0xFF454D5B),
      Color(0xFF313742),
      Color(0xFF22262E),
      Color(0xFF15181E),
      Color(0xFF0D0F13),
    ],
    groove: Color(0xFF05070B),
    ridge: Color(0xFF7E8794),
    highlight: Color(0xFFC8D2DE),
  );
}

/// 飞梭（调谐滚轮）：横向左右拖动 或 纵向上下拨动，滚过一格切换一台。
/// 环叠金属鼓面随拖动滚动；带惯性、刻度吸附与触感反馈。
class ShuttleDrum extends StatefulWidget {
  const ShuttleDrum({
    super.key,
    required this.onStep,
    this.enabled = true,
    this.width = 150,
    this.height = 62,
    this.axis = Axis.horizontal,
    this.tiltY = 0,
    this.palette = DrumPalette.neonCyan,
  });

  /// 每滚过一格回调：direction 为 +1（下一台）/ -1（上一台）。
  final ValueChanged<int> onStep;
  final bool enabled;
  final double width;
  final double height;

  /// 滚动轴：horizontal = 左右拨，vertical = 上下拨（纵向时高度填满父约束）。
  final Axis axis;

  /// 绕 Y 轴的透视倾角（度）：让滚轮像斜对驾驶位的实体飞轮，
  /// 正角 = 左缘朝向观察者。0 = 正对屏幕平面。
  final double tiltY;

  /// 配色方案（鼓面金属色调）。
  final DrumPalette palette;

  @override
  State<ShuttleDrum> createState() => _ShuttleDrumState();
}

class _ShuttleDrumState extends State<ShuttleDrum>
    with TickerProviderStateMixin {
  /// 惯性摩擦（指数衰减系数）。
  static const double _friction = 4.5;

  /// 触发惯性的最低线速度（px/s）。
  static const double _flickSpeed = 260;

  /// 惯性停止阈值。
  static const double _stopSpeed = 40;

  /// 线速度上限。
  static const double _maxSpeed = 1600;

  double _pos = 0;
  double _speed = 0;
  Duration? _lastMoveTime;
  Duration? _lastTickTime;

  late final Ticker _spinTicker = createTicker(_onSpinTick);
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  Tween<double>? _settleTween;

  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      final tw = _settleTween;
      if (tw == null) return;
      setState(() => _pos = tw.evaluate(_settle));
    });
  }

  @override
  void dispose() {
    _spinTicker.dispose();
    _settle.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails d) {
    if (!widget.enabled) return;
    _spinTicker.stop();
    _settle.stop();
    _speed = 0;
    _lastMoveTime = d.sourceTimeStamp;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!widget.enabled) return;
    final delta = widget.axis == Axis.horizontal ? d.delta.dx : d.delta.dy;
    final prev = _pos;
    _pos += delta;
    _fireNotches(prev, _pos);

    final now = d.sourceTimeStamp;
    final dtUs = _lastMoveTime == null || now == null
        ? 0
        : now.inMicroseconds - _lastMoveTime!.inMicroseconds;
    if (dtUs > 0) {
      final v = delta / (dtUs / 1e6);
      _speed = _speed * 0.55 + v * 0.45;
    }
    _lastMoveTime = now;
    setState(() {});
  }

  void _onDragEnd(DragEndDetails d) {
    if (!widget.enabled) return;
    _speed = _speed.clamp(-_maxSpeed, _maxSpeed);
    if (_speed.abs() > _flickSpeed) {
      _lastTickTime = null;
      _spinTicker.start();
    } else {
      _snap();
    }
  }

  void _onSpinTick(Duration elapsed) {
    final last = _lastTickTime;
    _lastTickTime = elapsed;
    if (last == null) return;
    final dt = (elapsed.inMicroseconds - last.inMicroseconds) / 1e6;
    if (dt <= 0) return;
    final prev = _pos;
    _pos += _speed * dt;
    _speed *= math.exp(-_friction * dt);
    _fireNotches(prev, _pos);
    if (_speed.abs() < _stopSpeed) {
      _spinTicker.stop();
      _snap();
    }
    setState(() {});
  }

  void _snap() {
    final target = (_pos / _notchPx).roundToDouble() * _notchPx;
    if ((target - _pos).abs() < 0.0001) {
      setState(() => _pos = target);
      return;
    }
    _settleTween = Tween(begin: _pos, end: target);
    _settle.forward(from: 0);
  }

  /// 跨过一格触发步进；向左/向上滚 = 下一台。单次事件最多补 4 步。
  void _fireNotches(double from, double to) {
    final a = (from / _notchPx).floor();
    final b = (to / _notchPx).floor();
    if (a == b) return;
    final dir = b < a ? 1 : -1;
    var count = (b - a).abs();
    if (count > 4) count = 4;
    for (var i = 0; i < count; i++) {
      HapticFeedback.selectionClick();
      widget.onStep(dir);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vertical = widget.axis == Axis.vertical;
    Widget drum = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: vertical ? null : _onDragStart,
      onHorizontalDragUpdate: vertical ? null : _onDragUpdate,
      onHorizontalDragEnd: vertical ? null : _onDragEnd,
      onVerticalDragStart: vertical ? _onDragStart : null,
      onVerticalDragUpdate: vertical ? _onDragUpdate : null,
      onVerticalDragEnd: vertical ? _onDragEnd : null,
      child: SizedBox(
        width: widget.width,
        height: vertical ? null : widget.height,
        child: CustomPaint(
          painter: _DrumPainter(
            pos: _pos,
            scheme: Theme.of(context).colorScheme,
            enabled: widget.enabled,
            axis: widget.axis,
            palette: widget.palette,
          ),
          // 无 child 的 CustomPaint 在松约束下会塌缩为 0 尺寸（纵向模式高度
          // 约束是松的），用 SizedBox.expand 强制填满。
          child: const SizedBox.expand(),
        ),
      ),
    );
    if (widget.tiltY != 0) {
      // 透视倾斜：滚轮像斜对驾驶位的实体飞轮，近侧略大、远侧收窄。
      drum = Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0014)
          ..rotateY(widget.tiltY * math.pi / 180),
        alignment: Alignment.center,
        child: drum,
      );
    }
    return drum;
  }
}

/// 鼓面绘制：实体调谐滚轮的"环叠"结构——一圈圈金属环堆叠、环间窄黑槽，
/// 随 pos 滚动并沿圆柱弧面投影压缩，固定镜面柔光带 + 左亮右暗受光剖面。
class _DrumPainter extends CustomPainter {
  _DrumPainter({
    required this.pos,
    required this.scheme,
    required this.enabled,
    required this.axis,
    this.palette = DrumPalette.neonCyan,
  });

  final double pos;
  final ColorScheme scheme;
  final bool enabled;
  final Axis axis;
  final DrumPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final vertical = axis == Axis.vertical;
    final rRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      // 平端圆柱：两端不是胶囊圆头，只留极小倒角（PL-990 飞轮是平端面）。
      const Radius.circular(5),
    );

    // ---- 圆柱几何：可视面是一段圆弧（±θmax），纹理坐标 s（弧长）
    // 投影为 center + R·sin(s/R)——越靠两端棱纹越密、越暗，
    // 像真实滚轮绕离视线那样"卷"进机壳。 ----
    const thetaMax = 1.326; // ≈76°
    final span = vertical ? h : w;
    final center = span / 2;
    final radius = center / math.sin(thetaMax);
    final arcHalf = radius * thetaMax;

    double project(double s) {
      final th = (s / radius).clamp(-thetaMax, thetaMax);
      return center + radius * math.sin(th);
    }

    double shade(double s) {
      final th = (s / radius).clamp(-thetaMax, thetaMax);
      return math.pow(math.cos(th), 1.3).toDouble();
    }

    // ---- 安装槽：滚轮嵌入机壳的暗缝（纵向=右缘、横向=底缘）----
    final slot = Paint()
      ..color = const Color(0xFF04060A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawRRect(
      rRect
          .shift(vertical ? const Offset(5, 0) : const Offset(0, 5))
          .inflate(2),
      slot,
    );

    // ---- 投影：滚轮凸出面板，在左侧面板上投下柔和阴影 ----
    canvas.drawRRect(
      rRect.shift(vertical ? const Offset(-9, 5) : const Offset(3, 9)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // ---- 中灰滚轮基面：清晰的左亮右暗圆柱受光剖面（纵向）----
    canvas.drawRRect(
      rRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: palette.body,
          stops: const [0.0, 0.10, 0.32, 0.56, 0.80, 1.0],
          transform: _AxisGradient(vertical),
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipRRect(rRect);

    // ---- 环叠结构：滚轮 = 一圈圈独立金属环堆叠。每环上缘受光、下缘
    // 入影，环与环之间是窄而深的黑槽——这是实体调谐滚轮的读法。 ----
    final ring = Paint();
    for (var i = (((-arcHalf - pos) / _notchPx).ceilToDouble()); ; i++) {
      final s = pos + i * _notchPx;
      if (s > arcHalf) break;
      final f = shade(s);
      final yA = project(s - _notchPx / 2);
      final yB = project(s + _notchPx / 2);
      final band = vertical
          ? Rect.fromLTRB(0, yA, w, yB)
          : Rect.fromLTRB(yA, 0, yB, h);
      // 环面自身弧度：上亮下暗。
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.16 * f),
              const Color(0x00000000),
              Colors.black.withValues(alpha: 0.26 * f),
            ],
            stops: const [0.0, 0.52, 1.0],
          ).createShader(band),
      );
      // 槽上方窄影：黑槽之前的过渡暗带，加深"陷进去"的感觉。
      ring.strokeWidth = 4;
      ring.color = Colors.black.withValues(alpha: 0.18 * f);
      _drawGroove(canvas, yB - 3, 5.0, w, h, vertical, ring);
      // 环间深槽：窄、黑、实。
      ring.strokeWidth = 2.0;
      ring.color = palette.groove.withValues(alpha: 0.92 * f);
      _drawGroove(canvas, yB, 4.0, w, h, vertical, ring);
      // 下一环顶缘亮线：金属环棱边反光。
      ring.strokeWidth = 1.2;
      ring.color = palette.ridge.withValues(alpha: 0.60 * f);
      _drawGroove(canvas, yB + 2.2, 5.0, w, h, vertical, ring);
    }

    // ---- 圆柱整体受光覆层：右半沉暗（纵向），统一环面与槽的光照 ----
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Color(0x00000000),
            Color(0x0A000000),
            Color(0x59000000),
          ],
          stops: const [0.0, 0.55, 1.0],
          transform: _AxisGradient(vertical),
        ).createShader(Offset.zero & size),
    );

    // ---- 固定镜面柔光带：不随滚动，是圆柱面对光源的连续高光 ----
    final hlX = vertical ? w * 0.18 : h * 0.18;
    canvas.drawLine(
      vertical ? Offset(hlX, 8) : Offset(8, hlX),
      vertical ? Offset(hlX, h - 8) : Offset(w - 8, hlX),
      Paint()
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = palette.highlight.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // ---- 两端环境光遮蔽：滚轴卷离视线处沉入暗影（圆柱纵深感）----
    final aoEnd = vertical ? Alignment.bottomCenter : Alignment.centerRight;
    final aoBegin = vertical ? Alignment.topCenter : Alignment.centerLeft;
    canvas.drawRRect(
      rRect,
      Paint()
        ..shader = LinearGradient(
          begin: aoBegin,
          end: aoEnd,
          colors: const [
            Color(0x73000000),
            Color(0x00000000),
            Color(0x00000000),
            Color(0x73000000),
          ],
          stops: const [0.0, 0.12, 0.88, 1.0],
        ).createShader(Offset.zero & size),
    );

    canvas.restore();

    // ---- 轮廓：外圈暗描边定形 + 迎光棱缘微弱提亮 ----
    canvas.drawRRect(
      rRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF030508),
    );
    canvas.drawLine(
      vertical ? const Offset(2.5, 10) : const Offset(10, 2.5),
      vertical ? Offset(2.5, h - 10) : Offset(w - 10, 2.5),
      Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }

  void _drawGroove(
    Canvas canvas,
    double p,
    double inset,
    double w,
    double h,
    bool vertical,
    Paint paint,
  ) {
    if (vertical) {
      canvas.drawLine(Offset(inset, p), Offset(w - inset, p), paint);
    } else {
      canvas.drawLine(Offset(p, inset), Offset(p, h - inset), paint);
    }
  }

  @override
  bool shouldRepaint(_DrumPainter oldDelegate) =>
      oldDelegate.pos != pos ||
      oldDelegate.enabled != enabled ||
      oldDelegate.scheme != scheme ||
      oldDelegate.axis != axis;
}

/// 让横向/纵向共用同一组渐变色：纵向时把顶→底渐变旋转为左→右。
class _AxisGradient extends GradientTransform {
  const _AxisGradient(this.vertical);

  final bool vertical;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      vertical ? (Matrix4.identity()..rotateZ(math.pi / 2)) : null;
}
