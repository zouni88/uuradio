// 微信通讯录式字母分组列表：A-Z 首字母排序 + 分组头 + 右侧字母索引条。
// 支持点按/滑动索引条快速跳转，非 A-Z 首字母归入 # 组（置底）。对齐 Flutter indexed_category_list.dart。
import { BrowseCategory } from '../../../domain/models';
import { NeonBox, NeonText } from '../../../widgets/neon';
import { t, tf } from '../../../core/l10n';
import { Scheme, withAlpha, darkScheme, lightScheme, DEFAULT_ACCENT } from '../../../core/theme';

const HEADER_H = 30;
const ITEM_H = 56;

class Section {
  letter: string = '';
  items: BrowseCategory[] = [];

  constructor(letter: string, items: BrowseCategory[]) {
    this.letter = letter;
    this.items = items;
  }
}

/// 扁平行规格（组头 / 条目）。
class RowSpec {
  isHeader: boolean = false;
  letter: string = '';
  item: BrowseCategory | null = null;
  key: string = '';
}

function byName(a: BrowseCategory, b: BrowseCategory): number {
  const x = a.name.toLowerCase();
  const y = b.name.toLowerCase();
  return x < y ? -1 : (x > y ? 1 : 0);
}

function letterOf(name: string): string {
  const s = name.trim();
  if (s.length === 0) {
    return '#';
  }
  const upper = s.charAt(0).toUpperCase();
  const code = upper.charCodeAt(0);
  return (code >= 65 && code <= 90) ? upper : '#';
}

function flagEmojiOf(c: BrowseCategory): string {
  const code = c.isoCode;
  if (code.length !== 2) {
    return '🌍';
  }
  const base = 0x1F1E6;
  const a = code.toUpperCase().charCodeAt(0) - 65;
  const b = code.toUpperCase().charCodeAt(1) - 65;
  if (a < 0 || a > 25 || b < 0 || b > 25) {
    return '🌍';
  }
  return String.fromCodePoint(base + a) + String.fromCodePoint(base + b);
}

function buildSections(categories: BrowseCategory[]): Section[] {
  const map = new Map<string, BrowseCategory[]>();
  for (const c of categories) {
    const letter = letterOf(c.name);
    let arr = map.get(letter);
    if (arr === undefined) {
      arr = [];
      map.set(letter, arr);
    }
    arr.push(c);
  }
  const sections: Section[] = [];
  map.forEach((items: BrowseCategory[], key: string) => {
    items.sort(byName);
    sections.push(new Section(key, items));
  });
  sections.sort((a: Section, b: Section): number => {
    if (a.letter === '#') {
      return 1;
    }
    if (b.letter === '#') {
      return -1;
    }
    return a.letter < b.letter ? -1 : (a.letter > b.letter ? 1 : 0);
  });
  return sections;
}

@Component
export struct IndexedCategoryList {
  @Prop accent: number = DEFAULT_ACCENT;
  @Prop dark: boolean = true;
  @Prop langVer: number = 0;
  categories: BrowseCategory[] = [];
  onSelect: (c: BrowseCategory) => void = (c: BrowseCategory) => {
  };

  @State private activeIndex: number = 0;
  @State private dragging: boolean = false;
  @State private barH: number = 0;
  @State private scrollH: number = 0;
  private scroller: Scroller = new Scroller();
  private sections: Section[] = [];

  sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  aboutToAppear(): void {
    this.sections = buildSections(this.categories);
  }

  /// 分类被外部过滤后刷新分组。
  refresh(): void {
    this.sections = buildSections(this.categories);
    this.activeIndex = 0;
  }

  private rows(): RowSpec[] {
    const rows: RowSpec[] = [];
    for (const s of this.sections) {
      const h = new RowSpec();
      h.isHeader = true;
      h.letter = s.letter;
      h.key = `h${s.letter}`;
      rows.push(h);
      for (const c of s.items) {
        const r = new RowSpec();
        r.isHeader = false;
        r.item = c;
        r.key = `i${c.isoCode}_${c.name}`;
        rows.push(r);
      }
    }
    return rows;
  }

  private letters(): string[] {
    return this.sections.map((s: Section) => s.letter);
  }

  private sectionAtOffset(offset: number): number {
    let acc = 0;
    for (let i = 0; i < this.sections.length; i++) {
      acc += HEADER_H + this.sections[i].items.length * ITEM_H;
      if (offset < acc) {
        return i;
      }
    }
    return Math.max(0, this.sections.length - 1);
  }

  private offsetOfSection(index: number): number {
    let offset = 0;
    const n = Math.min(index, this.sections.length);
    for (let i = 0; i < n; i++) {
      offset += HEADER_H + this.sections[i].items.length * ITEM_H;
    }
    return offset;
  }

  /// 全部内容高度（Scroller 无 maxScrollOffset，自行计算可滚动上限）。
  private contentHeight(): number {
    let total = 0;
    for (const s of this.sections) {
      total += HEADER_H + s.items.length * ITEM_H;
    }
    return total;
  }

  private moveTo(barIndex: number, smooth: boolean): void {
    if (this.sections.length === 0) {
      return;
    }
    const idx = Math.min(Math.max(barIndex, 0), this.sections.length - 1);
    this.activeIndex = idx;
    const maxOffset: number = Math.max(0, this.contentHeight() - this.scrollH);
    const target = Math.min(this.offsetOfSection(idx), maxOffset);
    if (smooth) {
      this.scroller.scrollTo({ xOffset: 0, yOffset: target, animation: { duration: 180, curve: Curve.EaseOut } });
    } else {
      this.scroller.scrollTo({ xOffset: 0, yOffset: target });
    }
  }

  private onLetterTouch(event: TouchEvent): void {
    if (this.letters().length === 0) {
      return;
    }
    const len = this.letters().length;
    const slot = Math.min(16, this.barH / len);
    const top = (this.barH - slot * len) / 2;
    const touch = event.touches[0];
    const hit = Math.min(Math.max(Math.floor((touch.y - top) / slot), 0), len - 1);
    if (event.type === TouchType.Down) {
      this.moveTo(hit, true);
    } else if (event.type === TouchType.Move) {
      this.dragging = true;
      this.moveTo(hit, false);
    } else {
      this.dragging = false;
    }
  }

  @Builder
  private flatRow(spec: RowSpec) {
    if (spec.isHeader) {
      Row() {
        NeonText({
          accent: this.accent, dark: this.dark,
          text: spec.letter,
          fontSize: 13, fontWeight: 800, letterSpacing: 1.2
        })
      }
      .width('100%')
      .height(HEADER_H)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(withAlpha(this.sc().surfaceHigh, 0.28))
    } else {
      Row() {
        Text(flagEmojiOf(spec.item!))
          .fontSize(22)
          .margin({ right: 16 })
        Text(spec.item!.name)
          .fontSize(16)
          .fontColor(this.sc().onSurface)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(tf('stationCount', 'count', `${spec.item!.stationCount}`))
          .fontSize(12)
          .fontColor(this.sc().onSurfaceVariant)
      }
      .width('100%')
      .height(ITEM_H)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.onSelect(spec.item!);
      })
    }
  }

  build() {
    Stack() {
      Scroll(this.scroller) {
        Column() {
          ForEach(this.rows(), (spec: RowSpec) => {
            this.flatRow(spec)
          }, (spec: RowSpec) => spec.key)
          Row().height(24)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onAreaChange((_o: Area, n: Area) => {
        this.scrollH = n.height as number;
      })
      .onScroll(() => {
        const off: number = this.scroller.currentOffset().yOffset;
        const idx = this.sectionAtOffset(off);
        if (idx !== this.activeIndex) {
          this.activeIndex = idx;
        }
      })

      // 右侧字母索引条
      if (this.letters().length > 1) {
        Column() {
          ForEach(this.letters(), (letter: string, i: number) => {
            Text(letter)
              .fontSize(10)
              .fontWeight(i === this.activeIndex ? 800 : 500)
              .fontColor(i === this.activeIndex ? this.sc().primary : this.sc().onSurfaceVariant)
              .width(30)
              .textAlign(TextAlign.Center)
          }, (letter: string) => letter)
        }
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .width(30)
        .height('100%')
        .onAreaChange((_o: Area, n: Area) => {
          this.barH = n.height as number;
        })
        .onTouch((event: TouchEvent) => {
          this.onLetterTouch(event);
        })
        .position({ right: 0 })
      }

      // 拖拽大字浮层
      if (this.dragging && this.activeIndex < this.sections.length) {
        NeonBox({
          accent: this.accent, dark: this.dark,
          boxRadius: 16,
          paddingCfg: { left: 26, right: 26, top: 18, bottom: 18 }
        }) {
          NeonText({
            accent: this.accent, dark: this.dark,
            text: this.sections[this.activeIndex].letter,
            fontSize: 34, fontWeight: 800
          })
        }
      }
    }
    .width('100%')
    .height('100%')
  }
}
