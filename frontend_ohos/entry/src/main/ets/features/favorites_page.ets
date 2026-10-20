// 收藏页：收藏 / 最近播放 两个分段。对齐 Flutter favorites_page.dart。
import { Station } from '../domain/models';
import { FavoritesController } from '../controllers/favorites_controller';
import { HistoryController } from '../controllers/history_controller';
import { PlayerController } from '../controllers/player_controller';
import { Scheme, withAlpha, displayFamily, darkScheme, lightScheme, DEFAULT_ACCENT } from '../core/theme';
import { t } from '../core/l10n';
import { Router } from '../core/router';
import { AppBarRow, EmptyView, NeonButton } from './common';
import { StationTile } from '../widgets/station_tile';

@Component
export struct FavoritesPage {
  @Prop accent: number = DEFAULT_ACCENT;
  @Prop dark: boolean = true;
  @Prop langVer: number = 0;

  @State private favItems: Station[] = [];
  @State private histItems: Station[] = [];
  @State private segment: number = 0;
  @State private confirmShow: boolean = false;
  private favs: FavoritesController = FavoritesController.inst();
  private history: HistoryController = HistoryController.inst();
  private cb: () => void = () => {
    this.favItems = this.favs.items;
    this.histItems = this.history.items.map((e) => e.station);
  };

  sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  aboutToAppear(): void {
    this.cb();
    this.favs.addListener(this.cb);
    this.history.addListener(this.cb);
  }

  aboutToDisappear(): void {
    this.favs.removeListener(this.cb);
    this.history.removeListener(this.cb);
  }

  private openStation(station: Station): void {
    PlayerController.inst().play(station);
    Router.openPlayer();
  }

  @Builder
  private stationColumn(items: Station[]) {
    List() {
      ForEach(items, (station: Station) => {
        ListItem() {
          StationTile({
            accent: this.accent, dark: this.dark,
            station: station,
            onTap: () => this.openStation(station)
          })
        }
      }, (station: Station) => station.uuid)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .padding({ top: 4, bottom: 24 })
  }

  /// 分段条（TabBar 样式：选中主色粗体 + 底部指示线）。
  @Builder
  private segmentBar() {
    Row() {
      Column() {
        Text(t('favoritesSegment'))
          .fontSize(14)
          .fontWeight(this.segment === 0 ? 700 : 500)
          .letterSpacing(0.5)
          .fontColor(this.segment === 0 ? this.sc().primary : this.sc().onSurfaceVariant)
        Row()
          .height(2)
          .backgroundColor(this.segment === 0 ? this.sc().primary : Color.Transparent)
          .width('100%')
      }
      .layoutWeight(1)
      .onClick(() => {
        this.segment = 0;
      })

      Column() {
        Text(t('historySegment'))
          .fontSize(14)
          .fontWeight(this.segment === 1 ? 700 : 500)
          .letterSpacing(0.5)
          .fontColor(this.segment === 1 ? this.sc().primary : this.sc().onSurfaceVariant)
        Row()
          .height(2)
          .backgroundColor(this.segment === 1 ? this.sc().primary : Color.Transparent)
          .width('100%')
      }
      .layoutWeight(1)
      .onClick(() => {
        this.segment = 1;
      })
    }
    .width('100%')
    .height(48)
  }

  build() {
    Stack() {
      Column() {
        AppBarRow({
          sc: this.sc(),
          title: t('tabFavorites'),
          showBack: false
        }) {
          Row() {
            SymbolGlyph($r('sys.symbol.trash'))
              .fontSize(22)
              .fontColor([this.sc().onSurface])
          }
          .width(48)
          .height(48)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.confirmShow = true;
          })
        }

        this.segmentBar()

        // 内容（双 tab 同时挂树保状态，对齐 TabBarView + IndexedStack 行为）
        Stack() {
          Column() {
            if (this.favItems.length === 0) {
              EmptyView({
                accent: this.accent, dark: this.dark,
                icon: $r('sys.symbol.heart'),
                message: t('emptyFavorites')
              })
            } else {
              this.stationColumn(this.favItems)
            }
          }
          .width('100%')
          .height('100%')
          .visibility(this.segment === 0 ? Visibility.Visible : Visibility.None)

          Column() {
            if (this.histItems.length === 0) {
              EmptyView({
                accent: this.accent, dark: this.dark,
                icon: $r('sys.symbol.clock'),
                message: t('emptyHistory')
              })
            } else {
              this.stationColumn(this.histItems)
            }
          }
          .width('100%')
          .height('100%')
          .visibility(this.segment === 1 ? Visibility.Visible : Visibility.None)
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.sc().surface)

      // 清空历史确认对话框（自绘外壳：surfaceLow 底 + 主色描边圆角 18）
      Column() {
        Column() {
          Text(t('clearHistory'))
            .fontSize(18)
            .fontWeight(700)
            .letterSpacing(1)
            .fontFamily(displayFamily(700))
            .fontColor(this.sc().onSurface)
            .margin({ top: 24, left: 24, right: 24, bottom: 8 })
          Text(t('clearHistoryConfirm'))
            .fontSize(14)
            .fontColor(this.sc().onSurface)
            .margin({ left: 24, right: 24 })
          Row() {
            NeonButton({
              accent: this.accent, dark: this.dark,
              label: t('cancel'),
              onTap: () => {
                this.confirmShow = false;
              }
            })
            NeonButton({
              accent: this.accent, dark: this.dark,
              label: t('clear'),
              filled: true,
              onTap: () => {
                this.confirmShow = false;
                this.history.clear();
              }
            })
          }
          .justifyContent(FlexAlign.End)
          .margin({ top: 12, left: 24, right: 12, bottom: 12 })
        }
        .backgroundColor(this.sc().surfaceLow)
        .borderRadius(18)
        .border({ width: 1, color: withAlpha(this.sc().primary, 0.35) })
        .width('86%')
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .height('100%')
      .backgroundColor(withAlpha(0x000000, 0.6))
      .visibility(this.confirmShow ? Visibility.Visible : Visibility.None)
      .onClick(() => {
        this.confirmShow = false;
      })
    }
    .width('100%')
    .height('100%')
  }
}
