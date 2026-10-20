// 加载失败 + 重试视图（对齐 Flutter error_retry_view.dart）。
import { AppException, AppErrorType } from '../core/app_exception';
import { t } from '../core/l10n';
import { Scheme, withAlpha, darkScheme, lightScheme, DEFAULT_ACCENT } from '../core/theme';

@Component
export struct ErrorRetryView {
  accent: number = DEFAULT_ACCENT;
  dark: boolean = true;
  error?: Error | AppException;
  onRetry: () => void = () => {
  };

  private sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  private message(): string {
    if (this.error instanceof AppException) {
      const ae = this.error as AppException;
      if (ae.type === AppErrorType.network || ae.type === AppErrorType.timeout) {
        return t('errorNetwork');
      }
    }
    return t('errorGeneric');
  }

  build() {
    Column() {
      SymbolGlyph($r('sys.symbol.wifi_slash'))
        .fontSize(44)
        .fontColor([withAlpha(this.sc().primary, 0.55)])
      Row().height(16)
      Text(this.message())
        .textAlign(TextAlign.Center)
        .fontColor(this.sc().onSurfaceVariant)
        .fontSize(14)
      Row().height(20)
      Button(t('retry'), { type: ButtonType.Capsule })
        .backgroundColor(this.sc().secondaryContainer)
        .fontColor(this.sc().onSecondaryContainer)
        .fontSize(14)
        .onClick(() => {
          this.onRetry();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(32)
  }
}
