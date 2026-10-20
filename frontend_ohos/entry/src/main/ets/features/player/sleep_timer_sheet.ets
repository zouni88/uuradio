// 睡眠定时器底部弹窗：15/30/60/90 分钟预设 + 取消（对齐 Flutter sleep_timer_sheet.dart）。
import { SleepTimerController } from '../../controllers/sleep_timer_controller';
import { Scheme, titleMedium, withAlpha, darkScheme, lightScheme, DEFAULT_ACCENT } from '../../core/theme';
import { t, tf } from '../../core/l10n';
import { TileRow, ThemedDivider } from '../common';

@Component
export struct SleepTimerSheet {
  @Prop accent: number = DEFAULT_ACCENT;
  @Prop dark: boolean = true;
  @Prop langVer: number = 0;
  onClose: () => void = () => {
  };
  @State private remainingSec: number = -1;
  private st: SleepTimerController = SleepTimerController.inst();
  private cb: () => void = () => {
    this.remainingSec = this.st.remainingSec;
  };

  sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  aboutToAppear(): void {
    this.cb();
    this.st.addListener(this.cb);
  }

  aboutToDisappear(): void {
    this.st.removeListener(this.cb);
  }

  private fmt(): string {
    const total = Math.max(this.remainingSec, 0);
    const m = Math.floor(total / 60);
    const s = total % 60;
    const ss = s < 10 ? `0${s}` : `${s}`;
    return `${m}:${ss}`;
  }

  build() {
    Column() {
      Row() {
        Text(t('sleepTimer'))
          .fontSize(titleMedium(this.sc()).size)
          .fontWeight(titleMedium(this.sc()).weight)
          .letterSpacing(titleMedium(this.sc()).letterSpacing)
          .fontColor(this.sc().onSurface)
        Blank()
        if (this.remainingSec >= 0) {
          Text(this.fmt())
            .fontWeight(600)
            .fontColor(this.sc().primary)
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 10, bottom: 6 })

      ForEach([15, 30, 60, 90], (minutes: number) => {
        TileRow({
          accent: this.accent, dark: this.dark,
          icon: $r('sys.symbol.clock'),
          title: tf('sleepMinutesOption', 'minutes', `${minutes}`),
          onTap: () => {
            this.st.start(minutes);
            this.onClose();
          }
        })
      }, (minutes: number) => `st${minutes}`)

      ThemedDivider({ accent: this.accent, dark: this.dark })
      Row().height(8)
      Row() {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(20)
          .fontColor([this.sc().onSurfaceVariant])
          .margin({ right: 16 })
        Text(this.remainingSec < 0 ? t('sleepOff') : t('cancel'))
          .fontSize(16)
          .fontWeight(500)
          .fontColor(this.remainingSec < 0 ? withAlpha(this.sc().onSurface, 0.35) : this.sc().onSurface)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .opacity(this.remainingSec < 0 ? 0.6 : 1)
      .onClick(() => {
        if (this.remainingSec >= 0) {
          this.st.cancel();
          this.onClose();
        }
      })
      Row().height(16)
    }
    .width('100%')
    .backgroundColor(this.sc().surfaceLow)
  }
}
