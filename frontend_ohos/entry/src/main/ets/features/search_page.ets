// 搜索页：名称搜索（350ms 防抖）+ 码率/分类过滤。
// 对齐 Flutter search_page.dart。
import { BrowseCategory } from '../domain/models';
import { StationQuery } from '../domain/models';
import { StationListController } from '../controllers/list_controller';
import { SettingsController } from '../controllers/settings_controller';
import { AppRepositories } from '../controllers/discover_controller';
import { Scheme, withAlpha, darkScheme, lightScheme, DEFAULT_ACCENT } from '../core/theme';
import { t, tf } from '../core/l10n';
import { Routes, Router } from '../core/router';
import { AppBarRow, FilterChipView, RadioOptionRow } from './common';
import { StationListView } from './browse/discover/station_list_view';
import { CategoryPickerArgs, CategoryKind } from './browse/filters/category_picker_page';

const BITRATE_OPTIONS: number[] = [0, 64, 128, 192];

@Component
export struct SearchPage {
  @Prop accent: number = DEFAULT_ACCENT;
  @Prop dark: boolean = true;
  @Prop langVer: number = 0;

  @State private input: string = '';
  @State private focused: boolean = false;
  @State private country: BrowseCategory | null = null;
  @State private tag: BrowseCategory | null = null;
  @State private language: BrowseCategory | null = null;
  @State private listCtl: StationListController | null = null;
  @State private sheetShow: boolean = false;
  private debounceId: number = -1;
  private settings: SettingsController = SettingsController.inst();

  sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  aboutToDisappear(): void {
    if (this.debounceId >= 0) {
      clearTimeout(this.debounceId);
    }
  }

  private refreshProvider(): void {
    const text = this.input.trim();
    if (text.length === 0) {
      this.listCtl = null;
      return;
    }
    const q = new StationQuery();
    q.name = text;
    q.order = StationQuery.ORDER_BY_CLICKS;
    q.reverse = true;
    q.countryCode = this.country !== null ? this.country.isoCode : '';
    q.tag = this.tag !== null ? this.tag.name : '';
    q.language = this.language !== null ? this.language.name : '';
    q.minBitrate = this.settings.minBitrate;
    this.listCtl = new StationListController(AppRepositories.repo, q);
  }

  private onTextChanged(value: string): void {
    this.input = value;
    if (this.debounceId >= 0) {
      clearTimeout(this.debounceId);
    }
    this.debounceId = setTimeout(() => this.refreshProvider(), 350);
  }

  private pickCategory(kind: CategoryKind): void {
    const args = new CategoryPickerArgs();
    args.kind = kind;
    Router.push(Routes.CategoryPicker, args, (popInfo: PopInfo) => {
      const picked = popInfo.result as BrowseCategory;
      if (picked === null || picked === undefined) {
        return;
      }
      if (kind === CategoryKind.country) {
        this.country = picked;
      } else if (kind === CategoryKind.tag) {
        this.tag = picked;
      } else {
        this.language = picked;
      }
      if (this.input.trim().length > 0) {
        this.refreshProvider();
      }
    });
  }

  private setBitrate(option: number): void {
    this.settings.setMinBitrate(option);
    if (this.input.trim().length > 0) {
      this.refreshProvider();
    }
  }

  @Builder
  private searchField() {
    Row() {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(18)
        .fontColor([withAlpha(this.sc().onSurfaceVariant, 0.8)])
        .margin({ left: 14, right: 8 })
      TextInput({ text: this.input, placeholder: t('searchHint') })
        .layoutWeight(1)
        .height(44)
        .backgroundColor(Color.Transparent)
        .placeholderColor(withAlpha(this.sc().onSurfaceVariant, 0.8))
        .placeholderFont({ size: 14.5 })
        .fontColor(this.sc().onSurface)
        .fontSize(14.5)
        .enterKeyType(EnterKeyType.Search)
        .border({ width: 0 })
        .onChange((v: string) => {
          this.onTextChanged(v);
        })
        .onSubmit(() => {
          this.refreshProvider();
        })
        .onFocus(() => {
          this.focused = true;
        })
        .onBlur(() => {
          this.focused = false;
        })
      if (this.input.length > 0) {
        Row() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor([this.sc().onSurfaceVariant])
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.input = '';
          this.listCtl = null;
        })
      }
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

  /// 码率选择半模态。
  @Builder
  private bitrateSheet() {
    Column() {
      ForEach(BITRATE_OPTIONS, (option: number) => {
        RadioOptionRow({
          accent: this.accent, dark: this.dark,
          selected: this.settings.minBitrate === option,
          title: option === 0 ? t('bitrateAny') : tf('bitrateKbps', 'kbps', `${option}`),
          onSelect: () => {
            this.sheetShow = false;
            this.setBitrate(option);
          }
        })
      }, (option: number) => `br${option}`)
      Row().height(16)
    }
    .width('100%')
    .padding({ top: 12 })
    .backgroundColor(this.sc().surfaceLow)
  }

  build() {
    Column() {
      AppBarRow({
        sc: this.sc(),
        title: t('tabSearch'),
        showBack: false
      })
      Column() {
        this.searchField()
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 4 })

      // 过滤行
      Scroll() {
        Row({ space: 8 }) {
          FilterChipView({
            accent: this.accent, dark: this.dark,
            label: this.country !== null ? this.country.name : t('countries'),
            selected: this.country !== null,
            showClear: this.country !== null,
            onTap: () => this.pickCategory(CategoryKind.country),
            onClear: () => {
              this.country = null;
            }
          })
          FilterChipView({
            accent: this.accent, dark: this.dark,
            label: this.tag !== null ? this.tag.name : t('tags'),
            selected: this.tag !== null,
            showClear: this.tag !== null,
            onTap: () => this.pickCategory(CategoryKind.tag),
            onClear: () => {
              this.tag = null;
            }
          })
          FilterChipView({
            accent: this.accent, dark: this.dark,
            label: this.language !== null ? this.language.name : t('languages'),
            selected: this.language !== null,
            showClear: this.language !== null,
            onTap: () => this.pickCategory(CategoryKind.language),
            onClear: () => {
              this.language = null;
            }
          })
          FilterChipView({
            accent: this.accent, dark: this.dark,
            label: this.settings.minBitrate > 0
              ? tf('bitrateKbps', 'kbps', `${this.settings.minBitrate}`)
              : t('minBitratePref'),
            selected: this.settings.minBitrate > 0,
            onTap: () => {
              this.sheetShow = true;
            }
          })
        }
        .padding({ left: 16, right: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(44)

      // 结果区
      if (this.listCtl === null) {
        Column() {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(56)
            .fontColor([withAlpha(this.sc().primary, 0.35)])
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          StationListView({
            accent: this.accent, dark: this.dark, langVer: this.langVer,
            controller: this.listCtl
          })
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.sc().surface)
    .bindSheet($$this.sheetShow, this.bitrateSheet(), {
      height: SheetSize.FIT_CONTENT,
      showClose: false,
      backgroundColor: this.sc().surfaceLow,
      onDisappear: () => {
        this.sheetShow = false;
      }
    })
  }
}
