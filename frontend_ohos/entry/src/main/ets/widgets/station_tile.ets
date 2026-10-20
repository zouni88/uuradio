// 电台行：霓虹面板卡片（logo、名称、国家/码率、收藏心形）。对齐 Flutter station_tile.dart。
import { Station } from '../domain/models';
import { Scheme, withAlpha, darkScheme, lightScheme, DEFAULT_ACCENT, FONT_MONO } from '../core/theme';
import { stationSubtitle } from '../core/format';
import { FavoritesController } from '../controllers/favorites_controller';
import { StationLogo } from './station_logo';

@Component
export struct StationTile {
  accent: number = DEFAULT_ACCENT;
  dark: boolean = true;
  station: Station = new Station();
  onTap: () => void = () => {
  };
  showFavorite: boolean = true;
  @State private isFav: boolean = false;
  private favs: FavoritesController = FavoritesController.inst();
  private cb: () => void = () => {
    this.isFav = this.favs.isFavorite(this.station.uuid);
  };

  private sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  aboutToAppear(): void {
    this.isFav = this.favs.isFavorite(this.station.uuid);
    this.favs.addListener(this.cb);
  }

  aboutToDisappear(): void {
    this.favs.removeListener(this.cb);
  }

  build() {
    // 外层：横向 12 / 纵向 4 间距
    Column() {
      // 卡片本体
      Row() {
        StationLogo({
          scheme: this.sc(),
          logoUrl: this.station.logoUrl,
          name: this.station.name
        }).margin({ right: 12 })

        Column({ space: 3 }) {
          Text(this.station.name.trim())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(this.sc().onSurface)
            .fontSize(15)
            .fontWeight(600)
            .letterSpacing(0.2)
          Text(stationSubtitle(this.station.countryCode, this.station.country, this.station.bitrate, this.station.codec))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontFamily(FONT_MONO)
            .fontColor(this.sc().onSurfaceVariant)
            .fontSize(11.5)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.showFavorite) {
          Row() {
            SymbolGlyph(this.isFav ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
              .fontSize(22)
              .fontColor([this.isFav ? this.sc().primary : this.sc().onSurfaceVariant])
          }
          .width(40)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .hitTestBehavior(HitTestMode.Block)
          .onClick(() => {
            this.favs.toggle(this.station);
          })
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .onClick(() => {
        this.onTap();
      })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 4, bottom: 4 })
    .backgroundColor(withAlpha(this.sc().surfaceLow, 0.65))
    .borderRadius(12)
    .border({ width: 1, color: withAlpha(this.sc().outlineVariant, 0.6) })
  }
}
