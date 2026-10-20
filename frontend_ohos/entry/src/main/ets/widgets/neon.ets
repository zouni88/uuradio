// 霓虹通用组件：发光文字 / 发光容器 / 渐隐分隔线（对齐 Flutter core/widgets/neon.dart）。
// 说明：ArkUI .shadow() 仅接受单个 ShadowOptions（此 SDK 无数组重载），
// 多层霓虹光晕近似为 strongest 一层；属性名避开内置属性（size/background/borderRadius/borderWidth）。
import { Scheme, TextSpec, withAlpha, darkScheme, lightScheme, DEFAULT_ACCENT } from '../core/theme';

/// 霓虹发光阴影：近距锐光 + 中距弥散合并为单层（0.5/blur）。
export function neonShadows(color: number, blur: number = 14, near: number = 2): ShadowOptions {
  return { radius: blur, color: withAlpha(color, 0.5) };
}

/// 霓虹发光文字（color 缺省回退 spec 颜色 → 主题 primary）。
@Component
export struct NeonText {
  accent: number = DEFAULT_ACCENT;
  dark: boolean = true;
  text: string = '';
  spec?: TextSpec;
  color?: number;
  fontSize?: number;
  fontWeight?: number;
  fontFamily?: string;
  letterSpacing?: number;
  textAlign?: TextAlign;
  /// 0 = 不限行数。
  maxLines: number = 0;

  private sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  private resolvedColor(): number {
    if (this.color !== undefined) {
      return this.color;
    }
    if (this.spec !== undefined) {
      return this.spec.color;
    }
    return this.sc().primary;
  }

  private fs(): number {
    if (this.fontSize !== undefined) {
      return this.fontSize;
    }
    return this.spec !== undefined ? this.spec.size : 14;
  }

  private weight(): number {
    if (this.fontWeight !== undefined) {
      return this.fontWeight;
    }
    return this.spec !== undefined ? this.spec.weight : 400;
  }

  private family(): string {
    if (this.fontFamily !== undefined) {
      return this.fontFamily;
    }
    return this.spec !== undefined ? this.spec.family : 'HarmonyOS Sans';
  }

  private ls(): number {
    if (this.letterSpacing !== undefined) {
      return this.letterSpacing;
    }
    return this.spec !== undefined ? this.spec.letterSpacing : 0;
  }

  build() {
    Text(this.text)
      .fontColor(this.resolvedColor())
      .fontSize(this.fs())
      .fontWeight(this.weight())
      .fontFamily(this.family())
      .letterSpacing(this.ls())
      .textAlign(this.textAlign ?? TextAlign.Start)
      .maxLines(this.maxLines > 0 ? this.maxLines : 9999)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .shadow(neonShadows(this.resolvedColor()))
  }
}

@Builder
function neonBoxEmpty() {
}

/// 霓虹发光容器：半透明底 + 描边 + 外光晕。
@Component
export struct NeonBox {
  accent: number = DEFAULT_ACCENT;
  dark: boolean = true;
  @BuilderParam content: () => void = neonBoxEmpty;
  color?: number;
  bgColor?: number;
  boxRadius: number = 14;
  borderW: number = 1;
  glow: number = 12;
  paddingCfg?: Padding | number;

  private sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  private bg(): number {
    if (this.bgColor !== undefined) {
      return this.bgColor;
    }
    const alpha = this.sc().isDark ? 0.72 : 1;
    return withAlpha(this.sc().surfaceLow, alpha);
  }

  private accentColor(): number {
    return this.color !== undefined ? this.color : this.sc().primary;
  }

  build() {
    Column() {
      this.content()
    }
    .backgroundColor(this.bg())
    .borderRadius(this.boxRadius)
    .border({ width: this.borderW, color: withAlpha(this.accentColor(), 0.55) })
    .shadow({ radius: this.glow, color: withAlpha(this.accentColor(), 0.22) })
    .padding(this.paddingCfg ?? 0)
  }
}

/// 霓虹渐隐分隔线（左强右淡）。
@Component
export struct NeonDivider {
  accent: number = DEFAULT_ACCENT;
  dark: boolean = true;
  color?: number;
  thickness: number = 1.2;
  indent: number = 0;
  endIndent: number = 0;

  private sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  private c(): number {
    return this.color !== undefined ? this.color : this.sc().primary;
  }

  build() {
    Row()
      .height(this.thickness)
      .borderRadius(this.thickness)
      .linearGradient({
        direction: GradientDirection.Right,
        colors: [
          [withAlpha(this.c(), 0.7), 0],
          [withAlpha(this.c(), 0.15), 0.5],
          [withAlpha(this.c(), 0), 1],
        ]
      })
      .margin({ left: this.indent, right: this.endIndent })
  }
}
