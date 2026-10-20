// 电台 logo：网络图 + 失败/缺失时的霓虹首字符占位（对齐 Flutter station_logo.dart）。
import { Scheme, withAlpha, alphaBlend, displayFamily, darkScheme, DEFAULT_ACCENT } from '../core/theme';

@Component
export struct StationLogo {
  scheme: Scheme = darkScheme(DEFAULT_ACCENT);
  logoUrl: string = '';
  name: string = '';
  logoSize: number = 56;
  logoRadius: number = 14;
  @State private failed: boolean = false;

  private initial(): string {
    const trimmed = this.name.trim();
    if (trimmed.length === 0) {
      return '?';
    }
    const cp = trimmed.codePointAt(0);
    if (cp === undefined) {
      return '?';
    }
    return String.fromCodePoint(cp).toUpperCase();
  }

  @Builder
  private placeholder() {
    Column() {
      Text(this.initial())
        .fontColor(this.scheme.primary)
        .fontSize(this.logoSize * 0.38)
        .fontFamily(displayFamily(700))
    }
    .width(this.logoSize)
    .height(this.logoSize)
    .justifyContent(FlexAlign.Center)
    .linearGradient({
      direction: GradientDirection.RightBottom,
      colors: [
        [alphaBlend(this.scheme.primary, 0.22, this.scheme.surfaceHigh), 0],
        [alphaBlend(this.scheme.secondary, 0.22, this.scheme.surfaceHigh), 1],
      ]
    })
    .borderRadius(this.logoRadius)
  }

  build() {
    if (this.logoUrl.length === 0 || this.failed) {
      this.placeholder()
    } else {
      Image(this.logoUrl)
        .width(this.logoSize)
        .height(this.logoSize)
        .borderRadius(this.logoRadius)
        .objectFit(ImageFit.Cover)
        .onError(() => {
          this.failed = true;
        })
    }
  }
}
