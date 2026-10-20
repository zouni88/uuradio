import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 赛博朋克霓虹主题：深空底色 + 霓虹描边 + Orbitron 展示字体。
class AppTheme {
  AppTheme._();

  /// 展示字体（标题 / 数字 / 按钮），拉丁字形，中文自动回退系统字体。
  static const String fontDisplay = 'Orbitron';

  /// 等宽数据字体（码率 / 状态行）。
  static const String fontMono = 'JetBrainsMono';

  /// 默认主霓虹色：电光青。
  static const int defaultSeedValue = 0xFF00E5FF;

  /// 旧版 Material 种子色，用于一次性迁移到霓虹青。
  static const int legacySeedValue = 0xFF5B5BD6;

  /// 设置页可选的霓虹色盘。
  static const List<int> palette = [
    0xFF00E5FF, // 电光青
    0xFF05FFA1, // 酸性绿
    0xFFFF2A6D, // 霓虹粉
    0xFFB026FF, // 紫脉冲
    0xFFFCEE0A, // 赛博黄
    0xFFFF6E27, // 熔岩橙
    0xFF2E6BFF, // 极限蓝
    0xFF64FFDA, // 薄荷辉光
  ];

  /// 深空黑（暗色基底）。
  static const Color voidBlack = Color(0xFF05070D);

  /// 霓虹粉（次强调，全主题通用）。
  static const Color neonMagenta = Color(0xFFFF2A6D);

  static Color seedColorOf(int value) => Color(value);

  static ThemeData light(int accentValue) => _theme(_lightScheme(accentValue));

  static ThemeData dark(int accentValue) => _theme(_darkScheme(accentValue));

  // ---------- ColorScheme ----------

  static ColorScheme _darkScheme(int accentValue) {
    const onNeon = Color(0xFF04060C);
    const containerBase = Color(0xFF0A0F1C);
    final primary = Color(accentValue);
    return ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: onNeon,
      primaryContainer:
          Color.alphaBlend(primary.withValues(alpha: 0.16), containerBase),
      onPrimaryContainer: Color.lerp(primary, Colors.white, 0.32)!,
      secondary: neonMagenta,
      onSecondary: onNeon,
      secondaryContainer:
          Color.alphaBlend(neonMagenta.withValues(alpha: 0.16), containerBase),
      onSecondaryContainer: const Color(0xFFFF9DB8),
      tertiary: const Color(0xFFB026FF),
      onTertiary: onNeon,
      tertiaryContainer: const Color(0xFF3A1660),
      onTertiaryContainer: const Color(0xFFE5BCFF),
      error: const Color(0xFFFF3B5C),
      onError: onNeon,
      errorContainer: const Color(0xFF3A0B18),
      onErrorContainer: const Color(0xFFFFB1C0),
      surface: voidBlack,
      onSurface: const Color(0xFFDCF3FF),
      surfaceContainerLowest: const Color(0xFF02040A),
      surfaceContainerLow: containerBase,
      surfaceContainer: const Color(0xFF0D1526),
      surfaceContainerHigh: const Color(0xFF121B30),
      surfaceContainerHighest: const Color(0xFF1A2545),
      onSurfaceVariant: const Color(0xFF8CA3C3),
      outline: const Color(0xFF2C3D5E),
      outlineVariant: const Color(0xFF1C2942),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFFDCF3FF),
      onInverseSurface: voidBlack,
      inversePrimary: primary,
      surfaceTint: primary,
    );
  }

  static ColorScheme _lightScheme(int accentValue) {
    const surface = Color(0xFFF2F5FA);
    final primary = _readableAccent(Color(accentValue));
    final magenta = _readableAccent(neonMagenta);
    return ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer:
          Color.alphaBlend(primary.withValues(alpha: 0.14), Colors.white),
      onPrimaryContainer: primary,
      secondary: magenta,
      onSecondary: Colors.white,
      secondaryContainer:
          Color.alphaBlend(magenta.withValues(alpha: 0.14), Colors.white),
      onSecondaryContainer: magenta,
      tertiary: _readableAccent(const Color(0xFFB026FF)),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFF1DDFF),
      onTertiaryContainer: const Color(0xFF5A1480),
      error: const Color(0xFFD92648),
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDDE3),
      onErrorContainer: const Color(0xFF8A0E2A),
      surface: surface,
      onSurface: const Color(0xFF0B1322),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF8FAFD),
      surfaceContainer: const Color(0xFFEFF3F9),
      surfaceContainerHigh: const Color(0xFFE6ECF5),
      surfaceContainerHighest: const Color(0xFFDCE4F0),
      onSurfaceVariant: const Color(0xFF5A6880),
      outline: const Color(0xFFAEBBD0),
      outlineVariant: const Color(0xFFDCE2EC),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFF1A2545),
      onInverseSurface: const Color(0xFFDCF3FF),
      inversePrimary: Color(accentValue),
      surfaceTint: primary,
    );
  }

  /// 亮色模式下把霓虹色加深以保证可读性。
  static Color _readableAccent(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness(math.min(hsl.lightness * 0.72, 0.44)).toColor();
  }

  // ---------- ThemeData ----------

  static TextStyle? _display(
    TextStyle? base,
    FontWeight weight,
    double letterSpacing,
  ) =>
      base?.copyWith(
        fontFamily: fontDisplay,
        fontWeight: weight,
        letterSpacing: letterSpacing,
      );

  static ThemeData _theme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final t = base.textTheme;
    final textTheme = t.copyWith(
      displayLarge: _display(t.displayLarge, FontWeight.w900, 2),
      displayMedium: _display(t.displayMedium, FontWeight.w900, 1.5),
      displaySmall: _display(t.displaySmall, FontWeight.w900, 1.5),
      headlineMedium: _display(t.headlineMedium, FontWeight.w700, 1.2),
      headlineSmall: _display(t.headlineSmall, FontWeight.w700, 1),
      titleLarge: _display(t.titleLarge, FontWeight.w700, 1.2),
      titleMedium: _display(t.titleMedium, FontWeight.w500, 0.8),
    );

    OutlineInputBorder fieldBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      splashColor: scheme.primary.withValues(alpha: 0.08),
      highlightColor: scheme.primary.withValues(alpha: 0.05),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontDisplay,
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF070B14) : Colors.white,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        surfaceTintColor: Colors.transparent,
        height: 64,
        indicatorShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 11.5,
              letterSpacing: 0.3,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            )),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.8),
        thickness: 0.8,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF121B30)
            : const Color(0xFF1A2545),
        contentTextStyle: TextStyle(
          color: isDark ? scheme.onSurface : Colors.white,
          fontSize: 13.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.45)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isDark ? Colors.white.withValues(alpha: 0.045) : Colors.white,
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
          fontSize: 14.5,
        ),
        border: fieldBorder(scheme.outline),
        enabledBorder: fieldBorder(scheme.outline.withValues(alpha: 0.7)),
        focusedBorder: fieldBorder(scheme.primary, 1.4),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
        selectedColor: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.25),
          scheme.surfaceContainerHigh,
        ),
        checkmarkColor: scheme.primary,
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: TextStyle(fontSize: 13, color: scheme.onSurface),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: TextStyle(
            fontFamily: fontDisplay,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
        overlayColor:
            WidgetStatePropertyAll(scheme.primary.withValues(alpha: 0.06)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.35)),
        ),
        titleTextStyle: TextStyle(
          fontFamily: fontDisplay,
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        modalBackgroundColor: scheme.surfaceContainerLow,
        dragHandleColor: scheme.outline,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.3)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        circularTrackColor: scheme.outlineVariant.withValues(alpha: 0.3),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.3),
        selectionHandleColor: scheme.primary,
      ),
    );
  }
}
