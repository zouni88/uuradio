// 全屏播放页：赛博朋克舞台 —— 模糊封面 + 霓虹发光封面 + 频谱 + 信号 HUD。
// 对齐 Flutter player_page.dart。
import { Station } from '../../domain/models';
import { PlayerController, PlayerUiState } from '../../controllers/player_controller';
import { VisualizerController } from '../../controllers/visualizer_controller';
import { SleepTimerController } from '../../controllers/sleep_timer_controller';
import { SignalController } from '../../controllers/signal_controller';
import { NetType, SignalInfo } from '../../services/signal_service';
import { FavoritesController } from '../../controllers/favorites_controller';
import { AppErrorType } from '../../core/app_exception';
import { Scheme, headlineSmall, withAlpha, darkScheme, lightScheme, DEFAULT_ACCENT, FONT_MONO, FONT_DISPLAY_BASE } from '../../core/theme';
import { t, tf } from '../../core/l10n';
import { stationSubtitle } from '../../core/format';
import { Routes, Router } from '../../core/router';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { StationLogo } from '../../widgets/station_logo';
import { AppBarRow } from '../common';
import { SpectrumView } from './spectrum_view';
import { SleepTimerSheet } from './sleep_timer_sheet';

@Component
export struct PlayerPage {
  @Prop accent: number = DEFAULT_ACCENT;
  @Prop dark: boolean = true;
  @Prop langVer: number = 0;

  @State private st: PlayerUiState = PlayerController.inst().state;
  @State private remainingSec: number = SleepTimerController.inst().remainingSec;
  @State private signal: SignalInfo = new SignalInfo();
  @State private isFav: boolean = false;
  @State private sheetShow: boolean = false;
  @State private bgFailed: boolean = false;
  private fallbackNotified: boolean = false;
  private pc: PlayerController = PlayerController.inst();
  private vc: VisualizerController = VisualizerController.inst();
  private sc2: SleepTimerController = SleepTimerController.inst();
  private sigCtl: SignalController = SignalController.inst();
  private favs: FavoritesController = FavoritesController.inst();

  private cbPlayer: () => void = () => {
    this.st = this.pc.state;
    const s = this.st.station;
    this.isFav = s !== null && this.favs.isFavorite(s.uuid);
  };
  private cbViz: () => void = () => {
    // 频谱权限被拒绝时提示一次。
    if (this.vc.permissionDenied && !this.fallbackNotified) {
      this.fallbackNotified = true;
      promptAction.showToast({ message: t('spectrumFallback') });
    }
  };
  private cbSleep: () => void = () => {
    this.remainingSec = this.sc2.remainingSec;
  };
  private cbSignal: () => void = () => {
    this.signal = this.sigCtl.info;
  };
  private cbFavs: () => void = () => {
    const s = this.st.station;
    this.isFav = s !== null && this.favs.isFavorite(s.uuid);
  };

  sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  aboutToAppear(): void {
    this.cbPlayer();
    this.cbSleep();
    this.cbSignal();
    this.cbFavs();
    this.pc.addListener(this.cbPlayer);
    this.vc.addListener(this.cbViz);
    this.sc2.addListener(this.cbSleep);
    this.sigCtl.addListener(this.cbSignal);
    this.favs.addListener(this.cbFavs);
    this.sigCtl.start();
    this.vc.attach(getContext(this) as common.UIAbilityContext);
  }

  aboutToDisappear(): void {
    this.pc.removeListener(this.cbPlayer);
    this.vc.removeListener(this.cbViz);
    this.sc2.removeListener(this.cbSleep);
    this.sigCtl.removeListener(this.cbSignal);
    this.favs.removeListener(this.cbFavs);
    this.sigCtl.stop();
    this.vc.detach();
  }

  private errorText(): string {
    const ty = this.st.errorType;
    if (ty === null) {
      return '';
    }
    if (ty === AppErrorType.network || ty === AppErrorType.timeout) {
      return t('errorNetwork');
    }
    return t('playbackError');
  }

  private statusText(): string {
    const s = this.st;
    if (s.loading) {
      return t('connecting');
    }
    if (s.playing) {
      return s.icyTitle.length > 0 ? tf('nowBroadcasting', 'title', s.icyTitle) : t('nowPlaying');
    }
    const err = this.errorText();
    return err.length > 0 ? err : t('paused');
  }

  private statusColor(): number {
    const s = this.st;
    if (s.errorType !== null) {
      return this.sc().error;
    }
    return s.playing ? this.sc().primary : this.sc().onSurfaceVariant;
  }

  /// HUD：LINK 芯片取值。
  private linkLabel(): string {
    const s = this.st;
    if (s.errorType !== null) {
      return 'LOST';
    }
    if (s.loading) {
      return 'DIAL';
    }
    if (s.buffering) {
      return 'SYNC';
    }
    return s.playing ? 'LOCK' : 'IDLE';
  }

  private linkColor(): number {
    const s = this.st;
    if (s.errorType !== null) {
      return this.sc().error;
    }
    if (s.loading || s.buffering) {
      return this.sc().secondary;
    }
    return s.playing ? this.sc().primary : this.sc().onSurfaceVariant;
  }

  build() {
    NavDestination() {
      if (this.st.station === null) {
        Column() {
          AppBarRow({ sc: this.sc(), title: '', onBack: () => Router.pop() })
          Text(t('empty'))
            .fontSize(14)
            .fontColor(this.sc().onSurfaceVariant)
            .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.sc().surface)
      } else {
        Stack() {
          // 模糊封面背景
          if (this.st.station!.logoUrl.length > 0 && !this.bgFailed) {
            Image(this.st.station!.logoUrl)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Cover)
              .blur(28)
              .onError(() => {
                this.bgFailed = true;
              })
          }
          // 暗化渐变
          Column()
            .width('100%')
            .height('100%')
            .linearGradient({
              direction: GradientDirection.Bottom,
              colors: [
                [withAlpha(this.sc().surface, 0.86), 0],
                [withAlpha(this.sc().surface, 0.96), 1],
              ]
            })

          // 主内容列
          Column() {
            // 顶栏
            Row() {
              Row() {
                SymbolGlyph($r('sys.symbol.chevron_down'))
                  .fontSize(30)
                  .fontColor([this.sc().onSurface])
              }
              .width(48)
              .height(48)
              .justifyContent(FlexAlign.Center)
              .onClick(() => Router.pop())

              Blank()

              // NOW PLAYING 胶囊
              Text(t('nowPlaying'))
                .fontFamily(FONT_DISPLAY_BASE)
                .fontSize(10.5)
                .fontWeight(700)
                .letterSpacing(2)
                .fontColor(this.sc().primary)
                .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                .borderRadius(20)
                .border({ width: 1, color: withAlpha(this.sc().primary, 0.55) })
                .shadow({ radius: 12, color: withAlpha(this.sc().primary, 0.18) })

              Row() {
                SymbolGlyph(this.isFav ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
                  .fontSize(26)
                  .fontColor([this.isFav ? this.sc().primary : this.sc().onSurfaceVariant])
              }
              .width(48)
              .height(48)
              .justifyContent(FlexAlign.Center)
              .onClick(() => {
                this.favs.toggle(this.st.station!);
              })
            }
            .width('100%')

            Row().height(8)
            // 信号 HUD
            this.signalHud()
            Blank()
            // 霓虹发光封面
            Column() {
              StationLogo({
                scheme: this.sc(),
                logoUrl: this.st.station!.logoUrl,
                name: this.st.station!.name,
                logoSize: 214,
                logoRadius: 28
              })
            }
            .padding(4)
            .borderRadius(34)
            .border({ width: 1.4, color: withAlpha(this.sc().primary, 0.85) })
            .shadow({ radius: 44, color: withAlpha(this.sc().primary, 0.4) })
            Row().height(28)

            Text(this.st.station!.name.trim())
              .fontSize(headlineSmall(this.sc()).size)
              .fontWeight(headlineSmall(this.sc()).weight)
              .letterSpacing(headlineSmall(this.sc()).letterSpacing)
              .fontFamily(headlineSmall(this.sc()).family)
              .fontColor(this.sc().onSurface)
              .maxLines(2)
              .textAlign(TextAlign.Center)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Row().height(8)
            Text(stationSubtitle(this.st.station!.countryCode, this.st.station!.country,
              this.st.station!.bitrate, this.st.station!.codec))
              .fontFamily(FONT_MONO)
              .fontSize(12.5)
              .letterSpacing(0.5)
              .fontColor(this.sc().onSurfaceVariant)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .textAlign(TextAlign.Center)
            Row().height(20)
            // 频谱
            Column() {
              SpectrumView({
                accent: this.accent, dark: this.dark,
                playing: this.st.playing
              })
            }
            .width(300)
            .height(60)
            Row().height(14)
            // 状态行
            Text(this.statusText())
              .fontFamily(FONT_MONO)
              .fontSize(12.5)
              .fontColor(this.statusColor())
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .height(20)
              .width('100%')
              .textAlign(TextAlign.Center)
            Blank()

            // 控制区
            Row() {
              Row() {
                SymbolGlyph($r('sys.symbol.moon'))
                  .fontSize(26)
                  .fontColor([this.remainingSec >= 0 ? this.sc().primary : this.sc().onSurfaceVariant])
              }
              .width(48)
              .height(48)
              .justifyContent(FlexAlign.Center)
              .onClick(() => {
                this.sheetShow = true;
              })

              Row({ space: 28 }) {
                // 播放大按钮
                Column() {
                  if (this.st.loading) {
                    LoadingProgress()
                      .width(30)
                      .height(30)
                      .color(this.sc().onPrimary)
                  } else {
                    SymbolGlyph(this.st.playing ? $r('sys.symbol.pause') : $r('sys.symbol.play_fill'))
                      .fontSize(44)
                      .fontColor([this.sc().onPrimary])
                  }
                }
                .width(84)
                .height(84)
                .justifyContent(FlexAlign.Center)
                .borderRadius(42)
                .backgroundColor(this.sc().primary)
                .border({ width: 1.2, color: withAlpha(this.sc().onPrimary, 0.6) })
                .shadow({ radius: 34, color: withAlpha(this.sc().primary, 0.55) })
                .opacity(this.st.loading ? 0.9 : 1)
                .onClick(() => {
                  if (!this.st.loading) {
                    this.pc.togglePlayPause();
                  }
                })

                Row() {
                  SymbolGlyph($r('sys.symbol.stop_circle'))
                    .fontSize(26)
                    .fontColor([this.sc().onSurfaceVariant])
                }
                .width(48)
                .height(48)
                .justifyContent(FlexAlign.Center)
                .onClick(() => {
                  this.pc.stop();
                  Router.pop();
                })
              }

              Blank()
            }
            .width('100%')
            .padding({ left: 0, right: 12 })

            Row().height(20)
            // 主页链接
            if (this.st.station!.homepage.length > 0) {
              Row({ space: 6 }) {
                SymbolGlyph($r('sys.symbol.link'))
                  .fontSize(18)
                  .fontColor([this.sc().primary])
                Text(t('visitHomepage'))
                  .fontSize(14)
                  .fontWeight(500)
                  .fontColor(this.sc().primary)
              }
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .onClick(() => {
                Router.openHomepage(this.st.station!.homepage);
              })
            }
            Row().height(24)
          }
          .width('100%')
          .height('100%')
          .padding({ left: 24, right: 24, top: 16, bottom: 8 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.sc().surface)
      }
    }
    .hideTitleBar(true)
    .backgroundColor(this.sc().surface)
    .bindSheet($$this.sheetShow, this.sleepSheet(), {
      height: SheetSize.FIT_CONTENT,
      showClose: false,
      backgroundColor: this.sc().surfaceLow,
      onDisappear: () => {
        this.sheetShow = false;
      }
    })
  }

  @Builder
  private sleepSheet() {
    SleepTimerSheet({
      accent: this.accent, dark: this.dark, langVer: this.langVer,
      onClose: () => {
        this.sheetShow = false;
      }
    })
  }

  /// 信号 HUD：SIGNAL / NET / LINK 三块芯片。
  @Builder
  private signalHud() {
    Row({ space: 10 }) {
      this.hudChip('SIGNAL', this.signalValue(), this.signalColor(), this.bars())
      this.hudChip('NET', this.netLabel(), this.netColor(), -1)
      this.hudChip('LINK', this.linkLabel(), this.linkColor(), -1)
    }
    .width('100%')
  }

  private signalValue(): string {
    const info = this.signal;
    if (info.type === NetType.none) {
      return 'NO SIG';
    }
    return info.hasRssi ? `${info.rssi} dBm` : `LVL ${info.level < 0 ? 0 : info.level}`;
  }

  private signalColor(): number {
    return this.signal.type === NetType.none ? this.sc().onSurfaceVariant : this.sc().primary;
  }

  private bars(): number {
    const info = this.signal;
    if (info.type === NetType.none) {
      return 0;
    }
    return Math.min(Math.max(info.level, 0), 4);
  }

  private netLabel(): string {
    const ty = this.signal.type;
    if (ty === NetType.wifi) {
      return 'WIFI';
    }
    return ty === NetType.cell ? 'CELL' : 'OFF';
  }

  private netColor(): number {
    return this.signal.type === NetType.none ? this.sc().onSurfaceVariant : this.sc().primary;
  }

  /// 信号条阴影（显式类型常量：shadow 参数为 union，拒绝三元字面量）。
  private barShadow(active: boolean): ShadowOptions {
    if (active) {
      const on: ShadowOptions = { radius: 4, color: withAlpha(this.sc().primary, 0.5) };
      return on;
    }
    const off: ShadowOptions = { radius: 0, color: 0x00000000 };
    return off;
  }

  @Builder
  private hudChip(label: string, value: string, valueColor: number, bars: number) {
    Column() {
      Text(label)
        .fontFamily(FONT_MONO)
        .fontSize(9)
        .letterSpacing(2.5)
        .fontColor(this.sc().onSurfaceVariant)
      Row().height(4)
      Row() {
        if (bars >= 0) {
          Row({ space: 2 }) {
            ForEach([0, 1, 2, 3], (i: number) => {
              Column()
                .width(3)
                .height(4.0 + i * 2.5)
                .borderRadius(1)
                .backgroundColor(i < bars ? this.sc().primary : this.sc().outlineVariant)
                .shadow(this.barShadow(i < bars))
            }, (i: number) => `bar${i}`)
          }
          .alignItems(VerticalAlign.Bottom)
          .margin({ right: 6 })
        }
        Text(value)
          .fontFamily(FONT_MONO)
          .fontSize(12)
          .fontWeight(700)
          .fontColor(valueColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(VerticalAlign.Center)
    }
    .constraintSize({ minHeight: 0 })
    .padding({ left: 10, right: 10, top: 7, bottom: 7 })
    .backgroundColor(withAlpha(this.sc().surfaceLow, 0.55))
    .borderRadius(10)
    .border({ width: 1, color: withAlpha(this.sc().outlineVariant, 0.9) })
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }
}
