// 发现页：热门榜单横滑卡片 + 当前国家电台列表 + 分类入口。
// 对齐 Flutter discover_page.dart。
import { Station, BrowseCategory, StationQuery } from '../../../domain/models';
import { DiscoverController } from '../../../controllers/discover_controller';
import { SettingsController } from '../../../controllers/settings_controller';
import { PlayerController } from '../../../controllers/player_controller';
import { Scheme, titleLarge, withAlpha, darkScheme, lightScheme, DEFAULT_ACCENT, FONT_MONO } from '../../../core/theme';
import { t } from '../../../core/l10n';
import { Routes, Router } from '../../../core/router';
import { display } from '@kit.ArkUI';
import { StationLogo } from '../../../widgets/station_logo';
import { StationTile } from '../../../widgets/station_tile';
import { ErrorRetryView } from '../../../widgets/error_retry_view';
import { HotRailSkeleton, StationListSkeleton, stationListSkeletonCount } from '../../../widgets/skeleton';
import { StationListArgs } from './station_list_page';
import { CategoryPickerArgs, CategoryKind } from '../filters/category_picker_page';

/// 电台短副标题：国家 + 码率（对齐 Flutter stationSubtitleShort）。
function stationSubtitleShort(station: Station): string {
  const parts: string[] = [];
  if (station.country.length > 0) {
    parts.push(station.country);
  }
  if (station.bitrate > 0) {
    parts.push(`${station.bitrate} kbps`);
  }
  return parts.join(' · ');
}

/// 分类 → 查询参数（点击数倒序）。
function queryFor(kind: CategoryKind, category: BrowseCategory): StationQuery {
  const q = new StationQuery();
  q.order = StationQuery.ORDER_BY_CLICKS;
  q.reverse = true;
  if (kind === CategoryKind.country) {
    q.countryCode = category.isoCode;
  } else if (kind === CategoryKind.tag) {
    q.tag = category.name;
  } else {
    q.language = category.name;
  }
  return q;
}

@Component
export struct DiscoverPage {
  @Prop accent: number = DEFAULT_ACCENT;
  @Prop dark: boolean = true;
  @Prop langVer: number = 0;

  @State private topItems: Station[] = [];
  @State private topLoading: boolean = true;
  @State private topErr: string = '';
  @State private countryItems: BrowseCategory[] = [];
  @State private cItems: Station[] = [];
  @State private cLoading: boolean = true;
  @State private cErr: string = '';

  private disc: DiscoverController = DiscoverController.inst();
  private settings: SettingsController = SettingsController.inst();
  private cb: () => void = () => {
    this.topItems = this.disc.topItems;
    this.topLoading = this.disc.topLoading;
    this.topErr = `${this.disc.topError ?? ''}`;
    this.countryItems = this.disc.countryItems;
    const cs = this.disc.countryStations;
    if (cs !== null) {
      this.cItems = cs.items;
      this.cLoading = cs.loading;
      this.cErr = `${cs.error ?? ''}`;
    }
  };

  sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  aboutToAppear(): void {
    this.cb();
    this.disc.addListener(this.cb);
    this.disc.start();
  }

  aboutToDisappear(): void {
    this.disc.removeListener(this.cb);
  }

  /// 选中国家显示名（分类列表反查，查不到显示代码）。
  private countryName(): string {
    const code = this.settings.selectedCountry.length > 0
      ? this.settings.selectedCountry
      : this.disc.currentCountryCode();
    for (const c of this.countryItems) {
      if (c.isoCode === code) {
        return c.name;
      }
    }
    return code;
  }

  private skeletonFillCount(): number {
    const d = display.getDefaultDisplaySync();
    return stationListSkeletonCount(d.height / d.densityPixels);
  }

  private openStationList(title: string, query: StationQuery): void {
    const args = new StationListArgs();
    args.title = title;
    args.query = query;
    Router.push(Routes.StationList, args);
  }

  private openPicker(kind: CategoryKind, onPicked: (c: BrowseCategory) => void): void {
    const args = new CategoryPickerArgs();
    args.kind = kind;
    Router.push(Routes.CategoryPicker, args, (popInfo: PopInfo) => {
      const picked = popInfo.result as BrowseCategory;
      if (picked !== null && picked !== undefined) {
        onPicked(picked);
      }
    });
  }

  /// 区块标题：霓虹竖标 + 文案（可点）+ 右侧操作。
  @Builder
  private sectionHeader(title: string, tappable: boolean, onTap: () => void, showAction: boolean, onAction: () => void) {
    Row() {
      Column()
        .width(4)
        .height(20)
        .borderRadius(2)
        .backgroundColor(this.sc().primary)
        .shadow({ radius: 10, color: withAlpha(this.sc().primary, 0.6) })
      Row() {
        Text(title)
          .fontSize(titleLarge(this.sc()).size)
          .fontWeight(titleLarge(this.sc()).weight)
          .letterSpacing(titleLarge(this.sc()).letterSpacing)
          .fontFamily(titleLarge(this.sc()).family)
          .fontColor(this.sc().onSurface)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (tappable) {
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(20)
            .fontColor([this.sc().primary])
        }
      }
      .layoutWeight(1)
      .margin({ left: 10 })
      .padding({ top: 4, bottom: 4 })
      .borderRadius(8)
      .onClick(() => {
        if (tappable) {
          onTap();
        }
      })
      if (showAction) {
        Text(t('viewAll'))
          .fontSize(14)
          .fontWeight(600)
          .fontColor(this.sc().primary)
          .padding({ left: 8, top: 8, bottom: 8 })
          .onClick(() => onAction())
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  /// 热门横滑卡片。
  @Builder
  private hotCard(station: Station, index: number) {
    Stack() {
      Column() {
        Column() {
          StationLogo({
            scheme: this.sc(),
            logoUrl: station.logoUrl,
            name: station.name,
            logoSize: 84,
            logoRadius: 18
          })
        }
        .shadow({ radius: 16, color: withAlpha(this.sc().primary, 0.22) })
        .borderRadius(18)

        Blank().layoutWeight(1)

        Text(station.name.trim())
          .fontSize(13.5)
          .fontWeight(600)
          .letterSpacing(0.2)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Row().height(2)
        Text(stationSubtitleShort(station))
          .fontFamily(FONT_MONO)
          .fontSize(11)
          .fontColor(this.sc().onSurfaceVariant)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .width(132)
      .height(180)
      .padding(10)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(withAlpha(this.sc().surfaceLow, 0.75))
      .borderRadius(16)
      .border({ width: 1, color: withAlpha(this.sc().outlineVariant, 0.9) })
      .shadow({ radius: 14, color: withAlpha(this.sc().primary, 0.07) })
      .onClick(() => {
        PlayerController.inst().play(station);
        Router.openPlayer();
      })

      Text(`${index + 1}`.padStart(2, '0'))
        .fontFamily(FONT_MONO)
        .fontSize(11)
        .fontWeight(700)
        .fontColor(withAlpha(this.sc().primary, 0.8))
        .position({ right: 8, top: 6 })
    }
  }

  /// 分类入口按钮（顶栏右上角）。
  @Builder
  private categoryButton(icon: Resource, label: string, kind: CategoryKind) {
    Column() {
      SymbolGlyph(icon)
        .fontSize(20)
        .fontColor([this.sc().primary])
    }
    .width(40)
    .height(40)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(withAlpha(this.sc().surfaceLow, 0.75))
    .borderRadius(12)
    .border({ width: 1, color: withAlpha(this.sc().outlineVariant, 0.9) })
    .shadow({ radius: 10, color: withAlpha(this.sc().primary, 0.06) })
    .margin({ left: 10 })
    .onClick(() => {
      this.openPicker(kind, (picked: BrowseCategory) => {
        this.openStationList(picked.name, queryFor(kind, picked));
      });
    })
  }

  build() {
    Column() {
      // 固定顶栏
      Row() {
        Text(t('tabDiscover'))
          .fontSize(titleLarge(this.sc()).size)
          .fontWeight(titleLarge(this.sc()).weight)
          .letterSpacing(titleLarge(this.sc()).letterSpacing)
          .fontFamily(titleLarge(this.sc()).family)
          .fontColor(this.sc().onSurface)
          .layoutWeight(1)
        this.categoryButton($r('sys.symbol.flag'), t('countries'), CategoryKind.country)
        this.categoryButton($r('sys.symbol.label'), t('tags'), CategoryKind.tag)
        this.categoryButton($r('sys.symbol.translate'), t('languages'), CategoryKind.language)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })

      // 分隔
      Row()
        .height(1)
        .backgroundColor(withAlpha(this.sc().outlineVariant, 0.35))

      // 滚动区
      Scroll() {
        Column() {
          this.sectionHeader(t('sectionHot'), false, () => {
          }, false, () => {
          })
          Row().height(12)
          if (this.topLoading) {
            HotRailSkeleton({ scheme: this.sc() })
          } else if (this.topErr.length > 0) {
            Column() {
              ErrorRetryView({
                accent: this.accent, dark: this.dark,
                error: new Error(this.topErr),
                onRetry: () => this.disc.retryTop()
              })
            }
            .height(120)
          } else {
            Scroll() {
              Row({ space: 12 }) {
                ForEach(this.topItems, (station: Station, index: number) => {
                  this.hotCard(station, index)
                }, (station: Station) => station.uuid)
              }
              .padding({ left: 16, right: 16 })
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')
            .height(180)
          }
          Row().height(24)

          // 选中国家电台列表区块
          this.sectionHeader(this.countryName(), true, () => {
            this.openPicker(CategoryKind.country, (picked: BrowseCategory) => {
              if (picked.isoCode.length > 0) {
                this.settings.selectCountry(picked.isoCode);
              }
            });
          }, true, () => {
            const q = new StationQuery();
            q.countryCode = this.settings.selectedCountry.length > 0
              ? this.settings.selectedCountry
              : this.disc.currentCountryCode();
            q.order = StationQuery.ORDER_BY_CLICKS;
            q.reverse = true;
            this.openStationList(this.countryName(), q);
          })
          Row().height(4)
          if (this.cLoading) {
            StationListSkeleton({ scheme: this.sc(), itemCount: this.skeletonFillCount() })
          } else if (this.cErr.length > 0) {
            Column() {
              ErrorRetryView({
                accent: this.accent, dark: this.dark,
                error: new Error(this.cErr),
                onRetry: () => {
                  const cs = this.disc.countryStations;
                  if (cs !== null) {
                    cs.retry();
                  }
                }
              })
            }
            .height(120)
          } else if (this.cItems.length === 0) {
            Text(t('noResults'))
              .fontSize(14)
              .fontColor(this.sc().onSurfaceVariant)
              .width('100%')
              .padding({ left: 16, right: 16, top: 24, bottom: 24 })
          } else {
            ForEach(this.cItems, (station: Station) => {
              StationTile({
                accent: this.accent, dark: this.dark,
                station: station,
                onTap: () => {
                  PlayerController.inst().play(station);
                  Router.openPlayer();
                }
              })
            }, (station: Station) => station.uuid)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ top: 16, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.sc().surface)
  }
}
