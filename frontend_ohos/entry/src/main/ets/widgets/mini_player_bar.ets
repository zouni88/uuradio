// 底部迷你播放条：黑玻璃底 + 霓虹顶描边（对齐 Flutter mini_player_bar.dart）。
import { PlayerController, PlayerUiState } from '../controllers/player_controller';
import { Scheme, withAlpha, darkScheme, DEFAULT_ACCENT, FONT_MONO } from '../core/theme';
import { t } from '../core/l10n';
import { Router } from '../core/router';
import { StationLogo } from './station_logo';

/// 播放中的微型均衡器图标（对应 Flutter graphic_eq 图标，3 根跳动竖条）。
@Component
struct MiniEq {
  color: number = 0xFFFFFFFF;

  build() {
    Row({ space: 2 }) {
      Column().width(2).height(6).borderRadius(1).backgroundColor(this.color)
      Column().width(2).height(12).borderRadius(1).backgroundColor(this.color)
      Column().width(2).height(8).borderRadius(1).backgroundColor(this.color)
    }
    .alignItems(VerticalAlign.Center)
    .margin({ right: 4 })
  }
}

@Component
export struct MiniPlayerBar {
  scheme: Scheme = darkScheme(DEFAULT_ACCENT);
  @State private st: PlayerUiState = PlayerController.inst().state;
  private pc: PlayerController = PlayerController.inst();
  private cb: () => void = () => {
    this.st = this.pc.state;
  };

  aboutToAppear(): void {
    this.pc.addListener(this.cb);
  }

  aboutToDisappear(): void {
    this.pc.removeListener(this.cb);
  }

  private statusText(): string {
    const s = this.st;
    if (s.loading) {
      return t('connecting');
    }
    if (s.playing) {
      return s.icyTitle.length > 0 ? s.icyTitle : t('nowPlaying');
    }
    if (s.errorType !== null) {
      return t('playbackError');
    }
    return t('paused');
  }

  private statusColor(): number {
    if (this.st.loading || this.st.playing) {
      return this.scheme.primary;
    }
    if (this.st.errorType !== null) {
      return this.scheme.error;
    }
    return this.scheme.onSurfaceVariant;
  }

  build() {
    if (!this.st.hasStation) {
      // 对齐 Flutter SizedBox.shrink()
      Row().width(0).height(0)
    } else {
      Column() {
        Row() {
          StationLogo({
            scheme: this.scheme,
            logoUrl: this.st.station?.logoUrl ?? '',
            name: this.st.station?.name ?? '',
            logoSize: 32,
            logoRadius: 8
          }).margin({ right: 10 })

          Column({ space: 1 }) {
            Text(this.st.station?.name.trim() ?? '')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontSize(13.5)
              .fontWeight(600)
              .letterSpacing(0.2)
            Row() {
              if (this.st.playing) {
                MiniEq({ color: this.scheme.primary })
              }
              Text(this.statusText())
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .fontFamily(FONT_MONO)
                .fontSize(11)
                .fontColor(this.statusColor())
                .layoutWeight(1)
            }
            .alignItems(VerticalAlign.Center)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          if (this.st.loading) {
            // 缓冲圈（允许保留，属播放态）
            LoadingProgress()
              .width(20)
              .height(20)
              .color(this.scheme.primary)
              .margin({ left: 8, right: 8 })
          } else {
            Row() {
              SymbolGlyph(this.st.playing ? $r('sys.symbol.pause') : $r('sys.symbol.play_fill'))
                .fontSize(28)
                .fontColor([this.st.playing ? this.scheme.primary : this.scheme.onSurface])
            }
            .width(40)
            .height(40)
            .justifyContent(FlexAlign.Center)
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => {
              this.pc.togglePlayPause();
            })

            Row() {
              SymbolGlyph($r('sys.symbol.xmark'))
                .fontSize(20)
                .fontColor([this.scheme.onSurfaceVariant])
            }
            .width(40)
            .height(40)
            .justifyContent(FlexAlign.Center)
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => {
              this.pc.stop();
            })
          }
        }
        .width('100%')
        .padding({ left: 12, right: 2, top: 4, bottom: 4 })
      }
      .width('100%')
      .backgroundColor(this.scheme.surfaceHigh)
      .border({ width: { top: 1 }, color: { top: withAlpha(this.scheme.primary, 0.4) } })
      .shadow({ radius: 16, color: withAlpha(this.scheme.primary, 0.12), offsetY: -2 })
      .onClick(() => {
        Router.openPlayer();
      })
    }
  }
}
