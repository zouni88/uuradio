import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// 每档（一个电台）对应的滚动像素。
const double _notchPx = 14;

/// 横向飞梭（调谐滚轮）：左右拖动/甩动，滚过一格切换一台。
/// 俯视一个横向滚动的滚花鼓面，纹理随拖动滚动，
/// 中央固定霓虹指针；带惯性、刻度吸附与触感反馈。
class ShuttleDrum extends StatefulWidget {
  const ShuttleDrum({
    super.key,
    required this.onStep,
    this.enabled = true,
    this.width = 150,
    this.height = 62,
  });

  /// 每滚过一格回调：direction 为 +1（下一台）/ -1（上一台）。
  final ValueChanged<int> onStep;
  final bool enabled;
  final double width;
  final double height;

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
    final delta = d.delta.dx;
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

  /// 跨过一格触发步进；向左滚 = 下一台。单次事件最多补 4 步。
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: CustomPaint(
          painter: _DrumPainter(
            pos: _pos,
            scheme: Theme.of(context).colorScheme,
            enabled: widget.enabled,
          ),
        ),
      ),
    );
  }
}

/// 鼓面绘制：胶囊底盘 + 滚动滚花齿（两端渐隐）+ 中央固定霓虹指针。
class _DrumPainter extends CustomPainter {
  _DrumPainter({
    required this.pos,
    required this.scheme,
    required this.enabled,
  });

  final double pos;
  final ColorScheme scheme;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(h / 2),
    );
    final accent = enabled ? scheme.primary : scheme.onSurfaceVariant;

    // 鼓身：拉丝金属圆柱受光感（顶部亮、底部暗）。
    canvas.drawRRect(
      rRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF343B49), Color(0xFF1A1E27)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      rRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF4A5262),
    );

    canvas.save();
    canvas.clipRRect(rRect);

    // 顶部金属高光弧线。
    canvas.drawLine(
      Offset(10, 3.5),
      Offset(w - 10, 3.5),
      Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.10),
    );

    // 机加工凹槽：随 pos 滚动，两端渐隐，明暗相间像滚花边缘。
    final groove = Paint()..strokeWidth = 2;
    var x = ((pos % _notchPx) + _notchPx) % _notchPx;
    for (; x < w; x += _notchPx) {
      final edge = math.min(x, w - x) / 20;
      final fade = edge.clamp(0.0, 1.0);
      // 暗槽 + 右侧亮棱，形成金属刻纹立体感。
      groove.color = Color(0xFF0D1016).withValues(alpha: 0.85 * fade);
      canvas.drawLine(Offset(x, 7), Offset(x, h - 7), groove);
      groove.color = Colors.white.withValues(alpha: 0.10 * fade);
      canvas.drawLine(Offset(x + 1.6, 8), Offset(x + 1.6, h - 8), groove);
    }

    // 中央背光指针：青色细线 + 微光 + 上下指示点（车机游标感）。
    canvas.drawLine(
      Offset(w / 2, 4),
      Offset(w / 2, h - 4),
      Paint()
        ..color = accent.withValues(alpha: enabled ? 0.45 : 0.18)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawLine(
      Offset(w / 2, 4),
      Offset(w / 2, h - 4),
      Paint()
        ..color = accent
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    final dot = Paint()..color = accent;
    canvas.drawCircle(Offset(w / 2, 5), 2.4, dot);
    canvas.drawCircle(Offset(w / 2, h - 5), 2.4, dot);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_DrumPainter oldDelegate) =>
      oldDelegate.pos != pos ||
      oldDelegate.enabled != enabled ||
      oldDelegate.scheme != scheme;
}
