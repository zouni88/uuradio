import 'package:flutter/material.dart';

/// 霓虹发光阴影组：近距锐光 + 中距 + 远距弥散。
List<Shadow> neonShadows(Color color, {double blur = 14, double near = 2}) => [
      Shadow(color: color.withValues(alpha: 0.9), blurRadius: near),
      Shadow(color: color.withValues(alpha: 0.55), blurRadius: blur),
      Shadow(color: color.withValues(alpha: 0.3), blurRadius: blur * 2),
    ];

/// 霓虹发光文字。
class NeonText extends StatelessWidget {
  const NeonText(
    this.text, {
    super.key,
    this.style,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final resolved =
        color ?? style?.color ?? Theme.of(context).colorScheme.primary;
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: (style ?? const TextStyle()).copyWith(
        color: resolved,
        shadows: neonShadows(resolved),
      ),
    );
  }
}

/// 霓虹发光容器：半透明底 + 描边 + 外光晕。
class NeonBox extends StatelessWidget {
  const NeonBox({
    super.key,
    required this.child,
    this.color,
    this.background,
    this.borderRadius = 14,
    this.borderWidth = 1,
    this.glow = 12,
    this.padding,
  });

  final Widget child;
  final Color? color;
  final Color? background;
  final double borderRadius;
  final double borderWidth;
  final double glow;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ??
            scheme.surfaceContainerLow.withValues(
              alpha: scheme.brightness == Brightness.dark ? 0.72 : 1,
            ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: c.withValues(alpha: 0.55), width: borderWidth),
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.22), blurRadius: glow)],
      ),
      child: child,
    );
  }
}

/// 霓虹渐隐分隔线（左强右淡）。
class NeonDivider extends StatelessWidget {
  const NeonDivider({
    super.key,
    this.color,
    this.thickness = 1.2,
    this.indent = 0,
    this.endIndent = 0,
  });

  final Color? color;
  final double thickness;
  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: EdgeInsets.only(left: indent, right: endIndent),
      child: Container(
        height: thickness,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(thickness),
          gradient: LinearGradient(
            colors: [
              c.withValues(alpha: 0.7),
              c.withValues(alpha: 0.15),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}


