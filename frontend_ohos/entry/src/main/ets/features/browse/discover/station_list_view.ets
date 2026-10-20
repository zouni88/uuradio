// 通用分页电台列表内容（StationListPage 与搜索页共用主体）。
// 对齐 Flutter StationListView：触底预加载 + 末尾行骨架占位（不用转圈）。
import { Station, StationQuery } from '../../../domain/models';
import { StationListController } from '../../../controllers/list_controller';
import { PlayerController } from '../../../controllers/player_controller';
import { AppRepositories } from '../../../controllers/discover_controller';
import { Scheme, darkScheme, lightScheme, DEFAULT_ACCENT } from '../../../core/theme';
import { t } from '../../../core/l10n';
import { display } from '@kit.ArkUI';
import { StationTile } from '../../../widgets/station_tile';
import { StationTileSkeleton, StationListSkeleton, stationListSkeletonCount } from '../../../widgets/skeleton';
import { ErrorRetryView } from '../../../widgets/error_retry_view';

@Component
export struct StationListView {
  @Prop accent: number = DEFAULT_ACCENT;
  @Prop dark: boolean = true;
  @Prop langVer: number = 0;
  controller: StationListController = new StationListController(AppRepositories.repo, new StationQuery());

  @State private items: Station[] = [];
  @State private loading: boolean = true;
  @State private err: string = '';
  private cb: () => void = () => {
    this.items = this.controller.items;
    this.loading = this.controller.loading;
    this.err = `${this.controller.error ?? ''}`;
  };

  sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  aboutToAppear(): void {
    this.cb();
    this.controller.addListener(this.cb);
    this.controller.start();
  }

  aboutToDisappear(): void {
    this.controller.removeListener(this.cb);
  }

  private openPlayer(station: Station): void {
    PlayerController.inst().play(station);
  }

  private skeletonFillCount(): number {
    const d = display.getDefaultDisplaySync();
    const vpH = d.height / d.densityPixels;
    return stationListSkeletonCount(vpH);
  }

  @Builder
  private body() {
    if (this.loading) {
      StationListSkeleton({ scheme: this.sc(), itemCount: this.skeletonFillCount() })
    } else if (this.err.length > 0) {
      ErrorRetryView({
        accent: this.accent, dark: this.dark,
        error: new Error(this.err),
        onRetry: () => {
          this.controller.retry();
        }
      })
    } else if (this.items.length === 0) {
      Column() {
        Text(t('noResults'))
          .fontSize(14)
          .fontColor(this.sc().onSurfaceVariant)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 0 }) {
        ForEach(this.items, (station: Station) => {
          ListItem() {
            StationTile({
              accent: this.accent, dark: this.dark,
              station: station,
              onTap: () => this.openPlayer(station)
            })
          }
        }, (station: Station) => station.uuid)
        // 末尾固定行骨架：加载更多占位（对齐 Flutter 恒定 +1 行）。
        ListItem() {
          StationTileSkeleton({ scheme: this.sc() })
        }
      }
      .width('100%')
      .height('100%')
      .padding({ top: 4, bottom: 24 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onReachEnd(() => {
        this.controller.loadMore();
      })
    }
  }

  build() {
    Column() {
      this.body()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.sc().surface)
  }
}
