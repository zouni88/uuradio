// 赛博朋克霓虹主题：深空底色 + 霓虹描边 + Orbitron 展示字体。
// 1:1 对齐 Flutter 端 app_theme.dart 的全部色值与字重映射。

export const FONT_DISPLAY_BASE = 'Orbitron'; // 500
export const FONT_DISPLAY_BOLD = 'OrbitronBold'; // 700
export const FONT_DISPLAY_BLACK = 'OrbitronBlack'; // 900
export const FONT_MONO = 'JetBrainsMono'; // 400
export const FONT_MONO_BOLD = 'JetBrainsMonoBold'; // 700

/// 展示字体族按字重选择（registerFont 不支持 weight，按族名区分）。
export function displayFamily(weight: number): string {
  if (weight >= 900) {
    return FONT_DISPLAY_BLACK;
  }
  if (weight >= 700) {
    return FONT_DISPLAY_BOLD;
  }
  return FONT_DISPLAY_BASE;
}

export function monoFamily(bold: boolean): string {
  return bold ? FONT_MONO_BOLD : FONT_MONO;
}

/// 默认主霓虹色：电光青。
export const DEFAULT_ACCENT = 0xFF00E5FF;
/// 旧版 Material 种子色（迁移用）。
export const LEGACY_ACCENT = 0xFF5B5BD6;

/// 设置页可选的霓虹色盘（8 色）。
export const ACCENT_PALETTE: number[] = [
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
export const VOID_BLACK = 0xFF05070D;
/// 霓虹粉（次强调）。
export const NEON_MAGENTA = 0xFFFF2A6D;
const ON_NEON = 0xFF04060C;
const CONTAINER_BASE = 0xFF0A0F1C;

/// 底部导航背景（NavigationBarTheme.backgroundColor）。
export function navBarBg(isDark: boolean): number {
  return isDark ? 0xFF070B14 : 0xFFFFFFFF;
}

/// SnackBar 背景。
export function snackBarBg(isDark: boolean): number {
  return isDark ? 0xFF121B30 : 0xFF1A2545;
}

// ---------- 颜色工具 ----------

function clamp01(v: number): number {
  return Math.min(1, Math.max(0, v));
}

/// 等价 Flutter Color.withValues(alpha: a)。
export function withAlpha(color: number, alpha: number): number {
  const a = Math.round(clamp01(alpha) * 255);
  return ((color & 0x00FFFFFF) | ((a & 0xFF) << 24)) >>> 0;
}

/// 等价 Flutter Color.alphaBlend(fg.withValues(alpha: a), bg)。
export function alphaBlend(fg: number, fgAlpha: number, bg: number): number {
  const a = clamp01(fgAlpha);
  const r = Math.round(((fg >>> 16) & 0xFF) * a + ((bg >>> 16) & 0xFF) * (1 - a));
  const g = Math.round(((fg >>> 8) & 0xFF) * a + ((bg >>> 8) & 0xFF) * (1 - a));
  const b = Math.round((fg & 0xFF) * a + (bg & 0xFF) * (1 - a));
  return (0xFF000000 | (r << 16) | (g << 8) | b) >>> 0;
}

/// 等价 Flutter Color.lerp(a, b, t)。
export function lerpColor(a: number, b: number, t: number): number {
  const k = clamp01(t);
  const r = Math.round(((a >>> 16) & 0xFF) + (((b >>> 16) & 0xFF) - ((a >>> 16) & 0xFF)) * k);
  const g = Math.round(((a >>> 8) & 0xFF) + (((b >>> 8) & 0xFF) - ((a >>> 8) & 0xFF)) * k);
  const bl = Math.round((a & 0xFF) + ((b & 0xFF) - (a & 0xFF)) * k);
  const al = Math.round(((a >>> 24) & 0xFF) + (((b >>> 24) & 0xFF) - ((a >>> 24) & 0xFF)) * k);
  return (((al & 0xFF) << 24) | (r << 16) | (g << 8) | bl) >>> 0;
}

/// 亮色模式下把霓虹色加深以保证可读性（HSL 亮度 * 0.72，上限 0.44）。
export function readableAccent(c: number): number {
  const r = ((c >>> 16) & 0xFF) / 255;
  const g = ((c >>> 8) & 0xFF) / 255;
  const b = (c & 0xFF) / 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  let h = 0;
  let s = 0;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    if (max === r) {
      h = (g - b) / d + (g < b ? 6 : 0);
    } else if (max === g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    h /= 6;
  }
  const newL = Math.min(l * 0.72, 0.44);
  // HSL -> RGB
  let rr = newL;
  let gg = newL;
  let bb = newL;
  if (s !== 0) {
    const q = newL < 0.5 ? newL * (1 + s) : newL + s - newL * s;
    const p = 2 * newL - q;
    rr = hueToRgb(p, q, h + 1 / 3);
    gg = hueToRgb(p, q, h);
    bb = hueToRgb(p, q, h - 1 / 3);
  }
  const ri = Math.round(rr * 255);
  const gi = Math.round(gg * 255);
  const bi = Math.round(bb * 255);
  return (0xFF000000 | (ri << 16) | (gi << 8) | bi) >>> 0;
}

function hueToRgb(p: number, q: number, t0: number): number {
  let t = t0;
  if (t < 0) {
    t += 1;
  }
  if (t > 1) {
    t -= 1;
  }
  if (t < 1 / 6) {
    return p + (q - p) * 6 * t;
  }
  if (t < 1 / 2) {
    return q;
  }
  if (t < 2 / 3) {
    return p + (q - p) * (2 / 3 - t) * 6;
  }
  return p;
}

// ---------- ColorScheme ----------

/// 等价 Flutter ColorScheme（仅保留项目实际用到的字段）。
export class Scheme {
  isDark: boolean = true;
  primary: number = DEFAULT_ACCENT;
  onPrimary: number = ON_NEON;
  primaryContainer: number = 0xFF000000;
  onPrimaryContainer: number = 0xFFFFFFFF;
  secondary: number = NEON_MAGENTA;
  onSecondary: number = ON_NEON;
  secondaryContainer: number = 0xFF000000;
  onSecondaryContainer: number = 0xFFFFFFFF;
  tertiary: number = 0xFFB026FF;
  onTertiary: number = ON_NEON;
  tertiaryContainer: number = 0xFF3A1660;
  onTertiaryContainer: number = 0xFFE5BCFF;
  error: number = 0xFFFF3B5C;
  onError: number = ON_NEON;
  errorContainer: number = 0xFF3A0B18;
  onErrorContainer: number = 0xFFFFB1C0;
  surface: number = VOID_BLACK;
  onSurface: number = 0xFFDCF3FF;
  surfaceLowest: number = 0xFF02040A;
  surfaceLow: number = CONTAINER_BASE;
  surfaceContainer: number = 0xFF0D1526;
  surfaceHigh: number = 0xFF121B30;
  surfaceHighest: number = 0xFF1A2545;
  onSurfaceVariant: number = 0xFF8CA3C3;
  outline: number = 0xFF2C3D5E;
  outlineVariant: number = 0xFF1C2942;
  inverseSurface: number = 0xFFDCF3FF;
  onInverseSurface: number = VOID_BLACK;
  inversePrimary: number = DEFAULT_ACCENT;
  surfaceTint: number = DEFAULT_ACCENT;
}

export function darkScheme(accent: number): Scheme {
  const s = new Scheme();
  s.isDark = true;
  s.primary = accent;
  s.onPrimary = ON_NEON;
  s.primaryContainer = alphaBlend(accent, 0.16, CONTAINER_BASE);
  s.onPrimaryContainer = lerpColor(accent, 0xFFFFFFFF, 0.32);
  s.secondary = NEON_MAGENTA;
  s.onSecondary = ON_NEON;
  s.secondaryContainer = alphaBlend(NEON_MAGENTA, 0.16, CONTAINER_BASE);
  s.onSecondaryContainer = 0xFFFF9DB8;
  s.tertiary = 0xFFB026FF;
  s.onTertiary = ON_NEON;
  s.tertiaryContainer = 0xFF3A1660;
  s.onTertiaryContainer = 0xFFE5BCFF;
  s.error = 0xFFFF3B5C;
  s.onError = ON_NEON;
  s.errorContainer = 0xFF3A0B18;
  s.onErrorContainer = 0xFFFFB1C0;
  s.surface = VOID_BLACK;
  s.onSurface = 0xFFDCF3FF;
  s.surfaceLowest = 0xFF02040A;
  s.surfaceLow = CONTAINER_BASE;
  s.surfaceContainer = 0xFF0D1526;
  s.surfaceHigh = 0xFF121B30;
  s.surfaceHighest = 0xFF1A2545;
  s.onSurfaceVariant = 0xFF8CA3C3;
  s.outline = 0xFF2C3D5E;
  s.outlineVariant = 0xFF1C2942;
  s.inverseSurface = 0xFFDCF3FF;
  s.onInverseSurface = VOID_BLACK;
  s.inversePrimary = accent;
  s.surfaceTint = accent;
  return s;
}

export function lightScheme(accent: number): Scheme {
  const s = new Scheme();
  s.isDark = false;
  const primary = readableAccent(accent);
  const magenta = readableAccent(NEON_MAGENTA);
  s.primary = primary;
  s.onPrimary = 0xFFFFFFFF;
  s.primaryContainer = alphaBlend(primary, 0.14, 0xFFFFFFFF);
  s.onPrimaryContainer = primary;
  s.secondary = magenta;
  s.onSecondary = 0xFFFFFFFF;
  s.secondaryContainer = alphaBlend(magenta, 0.14, 0xFFFFFFFF);
  s.onSecondaryContainer = magenta;
  s.tertiary = readableAccent(0xFFB026FF);
  s.onTertiary = 0xFFFFFFFF;
  s.tertiaryContainer = 0xFFF1DDFF;
  s.onTertiaryContainer = 0xFF5A1480;
  s.error = 0xFFD92648;
  s.onError = 0xFFFFFFFF;
  s.errorContainer = 0xFFFFDDE3;
  s.onErrorContainer = 0xFF8A0E2A;
  s.surface = 0xFFF2F5FA;
  s.onSurface = 0xFF0B1322;
  s.surfaceLowest = 0xFFFFFFFF;
  s.surfaceLow = 0xFFF8FAFD;
  s.surfaceContainer = 0xFFEFF3F9;
  s.surfaceHigh = 0xFFE6ECF5;
  s.surfaceHighest = 0xFFDCE4F0;
  s.onSurfaceVariant = 0xFF5A6880;
  s.outline = 0xFFAEBBD0;
  s.outlineVariant = 0xFFDCE2EC;
  s.inverseSurface = 0xFF1A2545;
  s.onInverseSurface = 0xFFDCF3FF;
  s.inversePrimary = accent;
  s.surfaceTint = primary;
  return s;
}

// ---------- 文本样式 ----------

/// 供页面链式设置的文本规格（family/size/weight/letterSpacing/color）。
export class TextSpec {
  family: string;
  size: number;
  weight: number;
  letterSpacing: number;
  color: number;

  constructor(family: string, size: number, weight: number, letterSpacing: number, color: number) {
    this.family = family;
    this.size = size;
    this.weight = weight;
    this.letterSpacing = letterSpacing;
    this.color = color;
  }
}

function spec(family: string, size: number, weight: number, ls: number, s: Scheme): TextSpec {
  return new TextSpec(family, size, weight, ls, s.onSurface);
}

/// headlineMedium：display w900 ls2
export function headlineMedium(s: Scheme): TextSpec {
  return spec(displayFamily(900), 28, 900, 2, s);
}

/// headlineSmall：display w900 ls1.5
export function headlineSmall(s: Scheme): TextSpec {
  return spec(displayFamily(900), 24, 900, 1.5, s);
}

/// titleLarge：display w700 ls1.2
export function titleLarge(s: Scheme): TextSpec {
  return spec(displayFamily(700), 22, 700, 1.2, s);
}

/// titleMedium：display w500 ls0.8
export function titleMedium(s: Scheme): TextSpec {
  return spec(displayFamily(500), 16, 500, 0.8, s);
}

/// AppBar 标题：display w700 ls1.5 18
export function appBarTitle(s: Scheme): TextSpec {
  return spec(displayFamily(700), 18, 700, 1.5, s);
}

/// 正文 16
export function bodyLarge(s: Scheme): TextSpec {
  return new TextSpec(FONT_MONO, 16, 400, 0, s.onSurface);
}

/// 正文 14
export function bodyMedium(s: Scheme): TextSpec {
  return new TextSpec(FONT_MONO, 14, 400, 0, s.onSurface);
}

/// 次要文字 12（onSurfaceVariant）
export function bodySmall(s: Scheme): TextSpec {
  return new TextSpec(FONT_MONO, 12, 400, 0, s.onSurfaceVariant);
}

/// 等宽数据文字（码率/状态行）
export function dataSmall(s: Scheme): TextSpec {
  return new TextSpec(FONT_MONO, 12, 400, 0.2, s.onSurfaceVariant);
}
