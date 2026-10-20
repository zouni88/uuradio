import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 霓虹频谱画笔：32 根渐变圆角柱 + 光晕 + 顶端亮点。
class SpectrumPainter extends CustomPainter {
  SpectrumPainter({
    required this.bands,
    required this.color,
    required this.playing,
    this.secondary,
  });

  final List<double> bands;
  final Color color;

  /// 柱顶渐变收尾色（次强调色）。
  final Color? secondary;
  final bool playing;

  @override
  void paint(Canvas canvas, Size size) {
    final count = bands.isEmpty ? 32 : bands.length;
    final gap = size.width * 0.008;
    final barWidth = (size.width - gap * (count - 1)) / count;
    final radius = Radius.circular(barWidth / 2);
    final topColor = secondary ?? color;

    for (var i = 0; i < count; i++) {
      final value = i < bands.length ? bands[i] : 0.0;
      final intensity = playing ? value : value * 0.12;
      final minH = size.height * 0.04;
      final h = math.max(minH, size.height * intensity.clamp(0.0, 1.0));
      final x = i * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - h, barWidth, h),
        radius,
      );

      // 光晕层（播放中且柱体可见时）。
      if (playing && value > 0.02) {
        final glow = Paint()
          ..color = color.withValues(alpha: 0.4 * value.clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
        canvas.drawRRect(rect, glow);
      }

      // 渐变柱体。
      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            color.withValues(alpha: 0.45),
            color,
            topColor,
          ],
        ).createShader(rect.outerRect);
      canvas.drawRRect(rect, barPaint);

      // 顶端亮点。
      if (playing && value > 0.04) {
        canvas.drawCircle(
          Offset(x + barWidth / 2, size.height - h),
          barWidth * 0.28,
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
      }
    }
  }

  @override
  bool shouldRepaint(SpectrumPainter oldDelegate) =>
      oldDelegate.playing != playing ||
      oldDelegate.color != color ||
      oldDelegate.secondary != secondary ||
      !_same(oldDelegate.bands, bands);

  static bool _same(List<double> a, List<double> b) {
    if (identical(a, b) || a.length != b.length) return a.length == b.length;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
