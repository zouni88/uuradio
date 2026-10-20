// 页面间共享的 M3 风格小部件（AppBar 行 / ListTile 行 / 单选行 / 过滤胶囊 / 空视图 / 对话框外壳 / 按钮）。
// 对齐 Flutter app_theme.dart 各组件主题的视觉规格。
// 约定：组件入参用 accent + dark（内部 sc() 派生配色）；AppBarRow 例外，直接接 sc。
import { Scheme, withAlpha, alphaBlend, displayFamily, darkScheme, lightScheme, DEFAULT_ACCENT } from '../core/theme';

@Builder
function emptyBuilder() {
}

/// 自绘 AppBar 行：返回键 + display 标题（bg=surface，无边框，高 56）。
@Component
export struct AppBarRow {
  sc: Scheme = darkScheme(DEFAULT_ACCENT);
  title: string = '';
  showBack: boolean = true;
  onBack: () => void = () => {
  };
  @BuilderParam trailing: () => void = emptyBuilder;

  build() {
    Row() {
      if (this.showBack) {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(26)
            .fontColor([this.sc.onSurface])
        }
        .width(48)
        .height(48)
        .justifyContent(FlexAlign.Center)
        .onClick(() => this.onBack())
      }
      Text(this.title)
        .fontSize(18)
        .fontWeight(700)
        .letterSpacing(1.5)
        .fontFamily(displayFamily(700))
        .fontColor(this.sc.onSurface)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: this.showBack ? 0 : 16 })
      this.trailing()
    }
    .width('100%')
    .height(56)
    .padding({ left: 4, right: 4 })
    .backgroundColor(this.sc.surface)
  }
}

/// ListTile 等价行：leading 图标 + 标题 + 尾部文字，高 56。
@Component
export struct TileRow {
  accent: number = DEFAULT_ACCENT;
  dark: boolean = true;
  icon?: Resource;
  title: string = '';
  trailingText: string = '';
  isEnabled: boolean = true;
  onTap: () => void = () => {
  };

  private sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  build() {
    Row() {
      if (this.icon !== undefined) {
        SymbolGlyph(this.icon)
          .fontSize(22)
          .fontColor([this.sc().onSurface])
          .margin({ right: 16 })
      }
      Text(this.title)
        .fontSize(16)
        .fontWeight(500)
        .fontColor(this.sc().onSurface)
        .layoutWeight(1)
      if (this.trailingText.length > 0) {
        Text(this.trailingText)
          .fontSize(13.5)
          .fontColor(this.sc().onSurfaceVariant)
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .opacity(this.isEnabled ? 1 : 0.5)
    .onClick(() => {
      if (this.isEnabled) {
        this.onTap();
      }
    })
  }
}

/// 对话框单选行：圆圈 + 标题。
@Component
export struct RadioOptionRow {
  accent: number = DEFAULT_ACCENT;
  dark: boolean = true;
  selected: boolean = false;
  title: string = '';
  onSelect: () => void = () => {
  };

  private sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  build() {
    Row() {
      Column() {
        if (this.selected) {
          Column()
            .width(10)
            .height(10)
            .borderRadius(5)
            .backgroundColor(this.sc().primary)
        }
      }
      .width(20)
      .height(20)
      .borderRadius(10)
      .border({ width: 2, color: this.selected ? this.sc().primary : this.sc().onSurfaceVariant })
      .margin({ right: 12 })
      Text(this.title)
        .fontSize(16)
        .fontColor(this.sc().onSurface)
        .layoutWeight(1)
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .onClick(() => this.onSelect())
  }
}

/// FilterChip 等价：胶囊（选中主色底），可选清除叉。
@Component
export struct FilterChipView {
  accent: number = DEFAULT_ACCENT;
  dark: boolean = true;
  label: string = '';
  selected: boolean = false;
  showClear: boolean = false;
  onTap: () => void = () => {
  };
  onClear: () => void = () => {
  };

  private sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  build() {
    Row({ space: 2 }) {
      Text(this.label)
        .fontSize(13)
        .fontColor(this.sc().onSurface)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.showClear) {
        Row() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(15)
            .fontColor([this.sc().onSurface])
        }
        .padding(4)
        .hitTestBehavior(HitTestMode.Block)
        .onClick(() => {
          this.onClear();
        })
      }
    }
    .height(32)
    .padding({ left: 12, right: this.showClear ? 4 : 12 })
    .borderRadius(8)
    .backgroundColor(this.selected
      ? alphaBlend(this.sc().primary, 0.25, this.sc().surfaceHigh)
      : withAlpha(this.sc().surfaceHigh, 0.6))
    .border({ width: 1, color: withAlpha(this.sc().outline, 0.8) })
    .onClick(() => this.onTap())
  }
}

/// 空视图：大图标 + 居中文案。
@Component
export struct EmptyView {
  accent: number = DEFAULT_ACCENT;
  dark: boolean = true;
  icon: Resource = $r('sys.symbol.heart');
  message: string = '';

  private sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  build() {
    Column() {
      SymbolGlyph(this.icon)
        .fontSize(48)
        .fontColor([withAlpha(this.sc().primary, 0.45)])
      Row().height(16)
      Text(this.message)
        .textAlign(TextAlign.Center)
        .fontSize(13.5)
        .fontColor(this.sc().onSurfaceVariant)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(40)
  }
}

/// 对话框外壳：surfaceLow 底 + 主色描边圆角 18（对齐 dialogTheme）。
@Component
export struct DialogShell {
  accent: number = DEFAULT_ACCENT;
  dark: boolean = true;
  title: string = '';
  @BuilderParam content: () => void = emptyBuilder;
  @BuilderParam actions: () => void = emptyBuilder;

  private sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  build() {
    Column() {
      Text(this.title)
        .fontSize(18)
        .fontWeight(700)
        .letterSpacing(1)
        .fontFamily(displayFamily(700))
        .fontColor(this.sc().onSurface)
        .margin({ top: 24, left: 24, right: 24, bottom: 8 })
      this.content()
      Row() {
        this.actions()
      }
      .justifyContent(FlexAlign.End)
      .margin({ top: 12, left: 24, right: 12, bottom: 12 })
    }
    .backgroundColor(this.sc().surfaceLow)
    .borderRadius(18)
    .border({ width: 1, color: withAlpha(this.sc().primary, 0.35) })
    .width('86%')
  }
}

/// 文本按钮（TextButton） / 实心按钮（FilledButton，r10 + display 字体）。
@Component
export struct NeonButton {
  accent: number = DEFAULT_ACCENT;
  dark: boolean = true;
  label: string = '';
  filled: boolean = false;
  onTap: () => void = () => {
  };

  private sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  build() {
    Text(this.label)
      .fontFamily(displayFamily(700))
      .fontSize(14)
      .letterSpacing(0.8)
      .fontColor(this.filled ? this.sc().onPrimary : this.sc().primary)
      .padding({ left: 20, right: 20, top: 12, bottom: 12 })
      .backgroundColor(this.filled ? this.sc().primary : Color.Transparent)
      .borderRadius(10)
      .onClick(() => this.onTap())
  }
}

/// 设置项分隔线（indent 16 / endIndent 16）。
@Component
export struct ThemedDivider {
  accent: number = DEFAULT_ACCENT;
  dark: boolean = true;

  private sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  build() {
    Row()
      .height(0.8)
      .margin({ left: 16, right: 16 })
      .backgroundColor(withAlpha(this.sc().outlineVariant, 0.8))
  }
}
