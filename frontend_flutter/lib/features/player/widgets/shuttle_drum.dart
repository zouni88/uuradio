import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// 每档（一个电台）对应的滚动像素。
const double _notchPx = 14;

/// 飞梭（调谐滚轮）：横向左右拖动 或 纵向上下拨动，滚过一格切换一台。
/// 拉丝金属鼓面纹理随拖动滚动，中央固定背光游标；带惯性、刻度吸附与触感反馈。
class ShuttleDrum extends StatefulWidget {
  const ShuttleDrum({
    super.key,
    required this.onStep,
    this.enabled = true,
    this.width = 150,
    this.height = 62,
    this.axis = Axis.horizontal,
    this.tiltY = 0,
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

/// 鼓面绘制：拉丝金属胶囊 + 随 pos 滚动的机加工凹槽（两端渐隐）+ 中央固定背光游标。
class _DrumPainter extends CustomPainter {
  _DrumPainter({
    required this.pos,
    required this.scheme,
    required this.enabled,
    required this.axis,
  });

  final double pos;
  final ColorScheme scheme;
  final bool enabled;
  final Axis axis;

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

    // ---- 亮银车削铝：多段明暗 = 真实铝件的镜面受光剖面 ----
    // （纵向左亮右暗；横向顶亮底暗）。
    canvas.drawRRect(
      rRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFF7A828E), // 0.00 迎光棱缘
            Color(0xFFE9EEF5), // 0.06 镜面高光带（最亮）
            Color(0xFFC3CAD4), // 0.20 亮部
            Color(0xFF9BA2AE), // 0.42 中间调
            Color(0xFF6B727E), // 0.68 暗部过渡
            Color(0xFF474D58), // 0.86 芯部阴影
            Color(0xFF2F343D), // 1.00 背光侧边缘
          ],
          stops: const [0.0, 0.06, 0.20, 0.42, 0.68, 0.86, 1.0],
          transform: _AxisGradient(vertical),
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipRRect(rRect);

    // ---- 拉丝纹理：亮铝面上的发丝细纹（静态、稳定伪随机）----
    final span = vertical ? h : w;
    final hair = Paint()..strokeWidth = 0.7;
    for (var i = 0; i < span / 2.6; i++) {
      final t = i * 2.6 + 1.3;
      final rnd = ((i * 137) % 251) / 251;
      hair.color = Colors.white.withValues(alpha: 0.03 + rnd * 0.06);
      _drawHairline(canvas, t, w, h, vertical, hair);
      if (i % 3 == 0) {
        hair.color = Colors.black.withValues(alpha: 0.05 + rnd * 0.05);
        _drawHairline(canvas, t + 1.1, w, h, vertical, hair);
      }
    }

    // ---- 镜面反光：受光侧贯通滚轴的柔光棱 + 细亮线 ----
    final streakX = vertical ? w * 0.16 : h * 0.16;
    final streakEnd = vertical
        ? Offset(streakX, h - 6)
        : Offset(w - 6, streakX);
    canvas.drawLine(
      vertical ? Offset(streakX, 6) : Offset(6, streakX),
      streakEnd,
      Paint()
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawLine(
      vertical ? Offset(streakX, 10) : Offset(10, streakX),
      vertical ? Offset(streakX, h - 10) : Offset(w - 10, streakX),
      Paint()
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.22),
    );

    // ---- 两端环境光遮蔽：滚轴与空气交界处自然变暗（圆柱纵深感）----
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
          stops: const [0.0, 0.14, 0.86, 1.0],
        ).createShader(Offset.zero & size),
    );

    // ---- 细密滚花：PL-990 飞轮边缘的密齿纹（3.5px 齿距，随 pos 滚动）----
    final knurl = Paint()..strokeWidth = 1.0;
    var k = ((pos % 3.5) + 3.5) % 3.5;
    for (; k < span; k += 3.5) {
      final edge = math.min(k, span - k) / 16;
      final fade = edge.clamp(0.0, 1.0);
      knurl.color = Colors.black.withValues(alpha: 0.20 * fade);
      _drawGroove(canvas, k, 4.5, w, h, vertical, knurl);
      knurl.color = const Color(0xFFDDE3EB).withValues(alpha: 0.10 * fade);
      _drawGroove(canvas, k + 0.9, 5.5, w, h, vertical, knurl);
    }

    // ---- 主档位棱纹：随 pos 滚动，两端渐隐（宽影带 + 深槽 + 亮棱）----
    final groove = Paint()..strokeWidth = 2;
    var p = ((pos % _notchPx) + _notchPx) % _notchPx;
    for (; p < span; p += _notchPx) {
      final edge = math.min(p, span - p) / 20;
      final fade = edge.clamp(0.0, 1.0);
      // 槽周柔影：让刻纹在铝面上压出深度。
      groove.strokeWidth = 9;
      groove.color = Colors.black.withValues(alpha: 0.20 * fade);
      _drawGroove(canvas, p, 6.0, w, h, vertical, groove);
      // 深色槽底。
      groove.strokeWidth = 2.4;
      groove.color = const Color(0xFF06080B).withValues(alpha: 0.95 * fade);
      _drawGroove(canvas, p, 7.0, w, h, vertical, groove);
      // 受光亮棱：齿顶翻出的镜面高光。
      groove.strokeWidth = 1.5;
      groove.color = const Color(0xFFE4EAF1).withValues(alpha: 0.24 * fade);
      _drawGroove(canvas, p + 1.8, 8.0, w, h, vertical, groove);
    }

    canvas.restore();

    // ---- 轮廓：外圈暗描边定形 + 迎光棱缘提亮 ----
    canvas.drawRRect(
      rRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF181C24),
    );
    canvas.drawLine(
      vertical ? const Offset(2.5, 10) : const Offset(10, 2.5),
      vertical ? Offset(2.5, h - 10) : Offset(w - 10, 2.5),
      Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }

  /// 拉丝纹理发丝线：垂直于滚轴横贯鼓身。
  void _drawHairline(
    Canvas canvas,
    double t,
    double w,
    double h,
    bool vertical,
    Paint paint,
  ) {
    if (vertical) {
      canvas.drawLine(
        const Offset(3, 0),
        Offset(w - 3, 0).translate(0, t),
        paint,
      );
    } else {
      canvas.drawLine(
        const Offset(0, 3),
        Offset(0, h - 3).translate(t, 0),
        paint,
      );
    }
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
