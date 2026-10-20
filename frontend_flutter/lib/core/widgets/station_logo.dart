import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 电台 logo：网络图 + 失败/缺失时的霓虹首字符占位。
class StationLogo extends StatelessWidget {
  const StationLogo({
    super.key,
    required this.logoUrl,
    required this.name,
    this.size = 56,
    this.borderRadius = 14,
  });

  final String logoUrl;
  final String name;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.22), scheme.surfaceContainerHigh),
            Color.alphaBlend(
                scheme.secondary.withValues(alpha: 0.22), scheme.surfaceContainerHigh),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        _initial(),
        style: TextStyle(
          color: scheme.primary,
          fontSize: size * 0.38,
          fontFamily: AppTheme.fontDisplay,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (logoUrl.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: logoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }

  String _initial() {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }
}
