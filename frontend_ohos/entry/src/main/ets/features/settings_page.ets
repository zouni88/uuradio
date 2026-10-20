// 设置页：语言 / 主题 / 主题色 / 码率偏好 / 导入导出 / 关于。
// 对齐 Flutter settings_page.dart（单选对话框改为页面内自绘覆盖层）。
import { ThemeMode, SettingsController } from '../controllers/settings_controller';
import { BackupService } from '../services/backup_service';
import { FavoritesLocalDs } from '../data/stores/record_store';
import { ACCENT_PALETTE, Scheme, withAlpha, darkScheme, lightScheme, DEFAULT_ACCENT, displayFamily } from '../core/theme';
import { t, tf } from '../core/l10n';
import { promptAction } from '@kit.ArkUI';
import { AppBarRow, TileRow, RadioOptionRow, ThemedDivider } from './common';

type DialogKind = '' | 'locale' | 'theme' | 'bitrate';

@Component
export struct SettingsPage {
  @Prop accent: number = DEFAULT_ACCENT;
  @Prop dark: boolean = true;
  @Prop langVer: number = 0;

  @State private dialogKind: DialogKind = '';
  private settings: SettingsController = SettingsController.inst();
  private backup: BackupService = new BackupService(new FavoritesLocalDs());

  sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  /// 主题色圆点阴影（显式类型常量：shadow 参数为 union，拒绝三元字面量）。
  private swatchShadow(selected: boolean, value: number): ShadowOptions {
    if (selected) {
      const on: ShadowOptions = { radius: 14, color: withAlpha(value, 0.55) };
      return on;
    }
    const off: ShadowOptions = { radius: 0, color: 0x00000000 };
    return off;
  }

  private localeLabel(): string {
    const code = this.settings.localeCode;
    if (code.length === 0) {
      return t('languageSystem');
    }
    if (code === 'zh') {
      return '中文';
    }
    if (code === 'en') {
      return 'English';
    }
    return code;
  }

  private themeLabel(): string {
    if (this.settings.themeMode === ThemeMode.system) {
      return t('themeSystem');
    }
    return this.settings.themeMode === ThemeMode.light ? t('themeLight') : t('themeDark');
  }

  private bitrateLabel(): string {
    return this.settings.minBitrate > 0
      ? tf('bitrateKbps', 'kbps', `${this.settings.minBitrate}`)
      : t('bitrateAny');
  }

  private async doExport(): Promise<void> {
    try {
      const saved = await this.backup.exportFavorites();
      if (saved.length > 0) {
        promptAction.showToast({ message: saved });
      }
    } catch (e) {
      promptAction.showToast({ message: t('importFailed') });
    }
  }

  private async doImport(): Promise<void> {
    try {
      const count = await this.backup.importFavorites();
      if (count >= 0) {
        promptAction.showToast({ message: tf('importSuccess', 'count', `${count}`) });
      }
    } catch (e) {
      promptAction.showToast({ message: t('importFailed') });
    }
  }

  /// 覆盖层单选对话框。
  @Builder
  private dialogLayer() {
    if (this.dialogKind.length > 0) {
      Column() {
        Column() {
          Text(this.dialogKind === 'locale' ? t('language')
            : (this.dialogKind === 'theme' ? t('theme') : t('minBitratePref')))
            .fontSize(18)
            .fontWeight(700)
            .letterSpacing(1)
            .fontFamily(displayFamily(700))
            .fontColor(this.sc().onSurface)
            .margin({ top: 24, left: 24, right: 24, bottom: 8 })

          // 选项
          if (this.dialogKind === 'locale') {
            RadioOptionRow({
              accent: this.accent, dark: this.dark,
              selected: this.settings.localeCode.length === 0,
              title: t('languageSystem'),
              onSelect: () => this.pickLocale('')
            })
            RadioOptionRow({
              accent: this.accent, dark: this.dark,
              selected: this.settings.localeCode === 'zh',
              title: '中文',
              onSelect: () => this.pickLocale('zh')
            })
            RadioOptionRow({
              accent: this.accent, dark: this.dark,
              selected: this.settings.localeCode === 'en',
              title: 'English',
              onSelect: () => this.pickLocale('en')
            })
          } else if (this.dialogKind === 'theme') {
            RadioOptionRow({
              accent: this.accent, dark: this.dark,
              selected: this.settings.themeMode === ThemeMode.system,
              title: t('themeSystem'),
              onSelect: () => this.pickTheme(ThemeMode.system)
            })
            RadioOptionRow({
              accent: this.accent, dark: this.dark,
              selected: this.settings.themeMode === ThemeMode.light,
              title: t('themeLight'),
              onSelect: () => this.pickTheme(ThemeMode.light)
            })
            RadioOptionRow({
              accent: this.accent, dark: this.dark,
              selected: this.settings.themeMode === ThemeMode.dark,
              title: t('themeDark'),
              onSelect: () => this.pickTheme(ThemeMode.dark)
            })
          } else {
            RadioOptionRow({
              accent: this.accent, dark: this.dark,
              selected: this.settings.minBitrate === 0,
              title: t('bitrateAny'),
              onSelect: () => this.pickBitrate(0)
            })
            ForEach([64, 128, 192], (b: number) => {
              RadioOptionRow({
                accent: this.accent, dark: this.dark,
                selected: this.settings.minBitrate === b,
                title: tf('bitrateKbps', 'kbps', `${b}`),
                onSelect: () => this.pickBitrate(b)
              })
            }, (b: number) => `b${b}`)
          }

          Row()
            .height(0.8)
            .margin({ top: 12 })
            .backgroundColor(withAlpha(this.sc().outlineVariant, 0.8))
          Row() {
            Text(t('cancel'))
              .fontSize(14)
              .fontWeight(600)
              .fontColor(this.sc().primary)
              .padding({ left: 20, right: 20, top: 12, bottom: 12 })
              .onClick(() => {
                this.dialogKind = '';
              })
          }
          .justifyContent(FlexAlign.End)
          .width('100%')
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
      .onClick(() => {
        this.dialogKind = '';
      })
    }
  }

  private pickLocale(code: string): void {
    this.dialogKind = '';
    this.settings.setLocale(code);
  }

  private pickTheme(mode: ThemeMode): void {
    this.dialogKind = '';
    this.settings.setThemeMode(mode);
  }

  private pickBitrate(value: number): void {
    this.dialogKind = '';
    this.settings.setMinBitrate(value);
  }

  build() {
    Stack() {
      Scroll() {
        Column() {
          AppBarRow({
            sc: this.sc(),
            title: t('tabSettings'),
            showBack: false
          })
          Column() {
            TileRow({
              accent: this.accent, dark: this.dark,
              icon: $r('sys.symbol.translate'),
              title: t('language'),
              trailingText: this.localeLabel(),
              onTap: () => {
                this.dialogKind = 'locale';
              }
            })
            TileRow({
              accent: this.accent, dark: this.dark,
              icon: $r('sys.symbol.contrast'),
              title: t('theme'),
              trailingText: this.themeLabel(),
              onTap: () => {
                this.dialogKind = 'theme';
              }
            })
            TileRow({
              accent: this.accent, dark: this.dark,
              icon: $r('sys.symbol.paintpalette'),
              title: t('accentColor')
            })
            // 主题色选择行
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach(ACCENT_PALETTE, (value: number) => {
                Column() {
                  if (this.settings.seedColor === value) {
                    SymbolGlyph($r('sys.symbol.checkmark'))
                      .fontSize(20)
                      .fontColor([0xFF000000])
                  }
                }
                .width(40)
                .height(40)
                .borderRadius(20)
                .backgroundColor(value)
                .border({
                  width: 2.5,
                  color: this.settings.seedColor === value ? 0xFFFFFFFF : 0x00000000
                })
                .shadow(this.swatchShadow(this.settings.seedColor === value, value))
                .margin({ right: 12, bottom: 4 })
                .onClick(() => {
                  this.settings.setSeedColor(value);
                })
              }, (value: number) => `${value}`)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 4, bottom: 12 })

            ThemedDivider({ accent: this.accent, dark: this.dark })
            TileRow({
              accent: this.accent, dark: this.dark,
              icon: $r('sys.symbol.dial'),
              title: t('minBitratePref'),
              trailingText: this.bitrateLabel(),
              onTap: () => {
                this.dialogKind = 'bitrate';
              }
            })
            ThemedDivider({ accent: this.accent, dark: this.dark })
            TileRow({
              accent: this.accent, dark: this.dark,
              icon: $r('sys.symbol.share'),
              title: t('exportFavorites'),
              onTap: () => this.doExport()
            })
            TileRow({
              accent: this.accent, dark: this.dark,
              icon: $r('sys.symbol.square_and_arrow_down'),
              title: t('importFavorites'),
              onTap: () => this.doImport()
            })
            ThemedDivider({ accent: this.accent, dark: this.dark })
            Row() {
              Text(t('about'))
                .fontSize(16)
                .fontWeight(500)
                .fontColor(this.sc().onSurface)
              Blank()
              SymbolGlyph($r('sys.symbol.info_circle'))
                .fontSize(22)
                .fontColor([this.sc().onSurface])
            }
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16 })

            Text(`${t('aboutDesc')}\nv1.0.0`)
              .fontSize(12.5)
              .lineHeight(18)
              .fontColor(this.sc().onSurfaceVariant)
              .width('100%')
              .padding({ left: 56, right: 16, bottom: 24 })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ top: 8 })
        .constraintSize({ minHeight: '100%' })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)

      this.dialogLayer()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.sc().surface)
  }
}
