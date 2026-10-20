// 骨架屏：呼吸脉冲占位（对齐 Flutter core/widgets/skeleton.dart）。
// 注意：属性不能用 width/height 等内置属性名（与 CustomComponent 冲突）。
import { Scheme, withAlpha, darkScheme, DEFAULT_ACCENT } from '../core/theme';

/// 骨架屏基础块：呼吸脉冲占位块（1100ms 0.3→0.85 往返循环）。
@Component
export struct Skeleton {
  scheme: Scheme = darkScheme(DEFAULT_ACCENT);
  /// undefined = 自适应宽度。
  w?: number;
  @Prop h: number = 12;
  @Prop radius: number = 12;
  @State private op: number = 0.3;

  build() {
    Column()
      .width(this.w ?? 'auto')
      .height(this.h)
      .borderRadius(this.radius)
      .backgroundColor(withAlpha(this.scheme.surfaceHighest, 0.5))
      .opacity(this.op)
      .onAppear(() => {
        this.getUIContext().animateTo({
          duration: 1100,
          curve: Curve.EaseInOut,
          iterations: -1,
          playMode: PlayMode.Alternate
        }, () => {
          this.op = 0.85;
        });
      })
  }
}

/// 电台列表行骨架（对应 StationTile 布局）。
@Component
export struct StationTileSkeleton {
  scheme: Scheme = darkScheme(DEFAULT_ACCENT);

  build() {
    Column() {
      Row() {
        Skeleton({ scheme: this.scheme, w: 44, h: 44 })
        Column({ space: 8 }) {
          Skeleton({ scheme: this.scheme, w: 140, h: 12, radius: 6 })
          Skeleton({ scheme: this.scheme, w: 90, h: 10, radius: 5 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Skeleton({ scheme: this.scheme, w: 22, h: 22, radius: 8 })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 4, bottom: 4 })
    .backgroundColor(withAlpha(this.scheme.surfaceLow, 0.65))
    .borderRadius(12)
    .border({ width: 1, color: withAlpha(this.scheme.outlineVariant, 0.6) })
  }
}

/// 按视口高度估算行数，保证铺满整个屏幕（单行高约 72）。
export function stationListSkeletonCount(viewportH: number): number {
  return Math.ceil(viewportH / 72);
}

/// 电台列表加载骨架：[itemCount] 行占位。
@Component
export struct StationListSkeleton {
  scheme: Scheme = darkScheme(DEFAULT_ACCENT);
  itemCount: number = 6;

  private rows(): number[] {
    const r: number[] = [];
    for (let i = 0; i < this.itemCount; i++) {
      r.push(i);
    }
    return r;
  }

  build() {
    Column() {
      ForEach(this.rows(), (i: number) => {
        StationTileSkeleton({ scheme: this.scheme })
      }, (i: number) => `sk${i}`)
    }
  }
}

/// 热门横滑卡片骨架（对应发现页 HotCard 布局）。
@Component
export struct HotCardSkeleton {
  scheme: Scheme = darkScheme(DEFAULT_ACCENT);

  build() {
    Column() {
      Column() {
        Skeleton({ scheme: this.scheme, w: 84, h: 84, radius: 18 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      Blank().layoutWeight(1)
      Skeleton({ scheme: this.scheme, w: 96, h: 12, radius: 6 })
      Row().height(6)
      Skeleton({ scheme: this.scheme, w: 72, h: 10, radius: 5 })
    }
    .width(132)
    .height(180)
    .padding(10)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(withAlpha(this.scheme.surfaceLow, 0.75))
    .borderRadius(16)
    .border({ width: 1, color: withAlpha(this.scheme.outlineVariant, 0.9) })
    .shadow({ radius: 14, color: withAlpha(this.scheme.primary, 0.07) })
  }
}

/// 热门横滑加载骨架：一排卡片占位。
@Component
export struct HotRailSkeleton {
  scheme: Scheme = darkScheme(DEFAULT_ACCENT);
  itemCount: number = 6;

  private rows(): number[] {
    const r: number[] = [];
    for (let i = 0; i < this.itemCount; i++) {
      r.push(i);
    }
    return r;
  }

  build() {
    Column() {
      Scroll() {
        Row({ space: 12 }) {
          ForEach(this.rows(), (i: number) => {
            HotCardSkeleton({ scheme: this.scheme })
          }, (i: number) => `hot${i}`)
        }
        .padding({ left: 16, right: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
    .height(180)
  }
}
