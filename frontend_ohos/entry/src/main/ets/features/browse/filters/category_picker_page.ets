// 国家 / 标签 / 语言 通用选择页，选中后 pop 回传 BrowseCategory。
// 对齐 Flutter category_picker_page.dart。
import { BrowseCategory } from '../../../domain/models';
import { AppErrorType, AppException } from '../../../core/app_exception';
import { AppRepositories } from '../../../controllers/discover_controller';
import { Scheme, withAlpha, darkScheme, lightScheme, DEFAULT_ACCENT } from '../../../core/theme';
import { t, tf } from '../../../core/l10n';
import { Routes, Router } from '../../../core/router';
import { display } from '@kit.ArkUI';
import { AppBarRow } from '../../common';
import { StationListSkeleton, stationListSkeletonCount } from '../../../widgets/skeleton';
import { ErrorRetryView } from '../../../widgets/error_retry_view';
import { IndexedCategoryList } from './indexed_category_list';

export enum CategoryKind {
  country,
  tag,
  language
}

export class CategoryPickerArgs {
  kind: CategoryKind = CategoryKind.country;
}

@Component
export struct CategoryPickerPage {
  @Prop accent: number = DEFAULT_ACCENT;
  @Prop dark: boolean = true;
  @Prop langVer: number = 0;
  @State private kind: CategoryKind = CategoryKind.country;
  @State private filter: string = '';
  @State private focused: boolean = false;
  @State private items: BrowseCategory[] = [];
  @State private loading: boolean = true;
  @State private errType: AppErrorType | null = null;

  sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  private title(): string {
    if (this.kind === CategoryKind.country) {
      return t('countries');
    }
    return this.kind === CategoryKind.tag ? t('tags') : t('languages');
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.errType = null;
    try {
      if (this.kind === CategoryKind.country) {
        this.items = await AppRepositories.repo.countries();
      } else if (this.kind === CategoryKind.tag) {
        this.items = await AppRepositories.repo.tags(100);
      } else {
        this.items = await AppRepositories.repo.languages();
      }
      this.loading = false;
    } catch (e) {
      this.loading = false;
      this.errType = AppException.fromError(e).type;
    }
  }

  private filtered(): BrowseCategory[] {
    const f = this.filter.trim().toLowerCase();
    if (f.length === 0) {
      return this.items;
    }
    return this.items.filter((c: BrowseCategory) => c.name.toLowerCase().includes(f));
  }

  private skeletonFillCount(): number {
    const d = display.getDefaultDisplaySync();
    return stationListSkeletonCount(d.height / d.densityPixels);
  }

  @Builder
  private searchField() {
    Row() {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(18)
        .fontColor([withAlpha(this.sc().onSurfaceVariant, 0.8)])
        .margin({ left: 14, right: 8 })
      TextInput({ text: this.filter, placeholder: this.title() })
        .layoutWeight(1)
        .height(44)
        .backgroundColor(Color.Transparent)
        .placeholderColor(withAlpha(this.sc().onSurfaceVariant, 0.8))
        .placeholderFont({ size: 14.5 })
        .fontColor(this.sc().onSurface)
        .fontSize(14.5)
        .border({ width: 0 })
        .onChange((v: string) => {
          this.filter = v;
        })
        .onFocus(() => {
          this.focused = true;
        })
        .onBlur(() => {
          this.focused = false;
        })
    }
    .width('100%')
    .height(46)
    .backgroundColor(this.dark ? withAlpha(0xFFFFFFFF, 0.045) : 0xFFFFFFFF)
    .borderRadius(10)
    .border({
      width: this.focused ? 1.4 : 1,
      color: this.focused ? this.sc().primary : withAlpha(this.sc().outline, 0.7)
    })
  }

  @Builder
  private simpleList() {
    List() {
      ForEach(this.filtered(), (c: BrowseCategory) => {
        ListItem() {
          Row() {
            SymbolGlyph(this.kind === CategoryKind.tag
              ? $r('sys.symbol.label')
              : $r('sys.symbol.translate'))
              .fontSize(20)
              .fontColor([this.sc().primary])
              .margin({ right: 16 })
            Text(c.name)
              .fontSize(16)
              .fontColor(this.sc().onSurface)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text(tf('stationCount', 'count', `${c.stationCount}`))
              .fontSize(12)
              .fontColor(this.sc().onSurfaceVariant)
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            Router.pop(c);
          })
        }
      }, (c: BrowseCategory) => `${c.name}_${c.stationCount}`)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .padding({ bottom: 24 })
  }

  @Builder
  private body() {
    if (this.loading) {
      Column() {
        StationListSkeleton({ scheme: this.sc(), itemCount: this.skeletonFillCount() })
      }
      .width('100%')
    } else if (this.errType !== null) {
      ErrorRetryView({
        accent: this.accent, dark: this.dark,
        error: new AppException(this.errType, ''),
        onRetry: () => this.load()
      })
    } else if (this.kind === CategoryKind.country) {
      IndexedCategoryList({
        accent: this.accent, dark: this.dark, langVer: this.langVer,
        categories: this.filtered(),
        onSelect: (c: BrowseCategory) => {
          Router.pop(c);
        }
      })
    } else {
      this.simpleList()
    }
  }

  build() {
    NavDestination() {
      Column() {
        AppBarRow({
          sc: this.sc(),
          title: this.title(),
          onBack: () => Router.pop()
        })
        Column() {
          this.searchField()
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        Column() {
          this.body()
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.sc().surface)
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      const param: Object | null = ctx.pathInfo.param as Object | null;
      if (param !== null && param !== undefined) {
        const args = param as CategoryPickerArgs;
        this.kind = args.kind;
      }
      this.load();
    })
  }
}
