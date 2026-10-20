// 主入口：Navigation 壳 + 4 tab 主页 + 迷你播放条 + 霓虹导航栏。
// 对齐 Flutter main.dart / app.dart / home_page.dart。
// NavPathStack 为 ArkUI 全局类型，无需 import。
import { common } from '@kit.AbilityKit';
import { ThemeMode, SettingsController } from '../controllers/settings_controller';
import { Routes, Router } from '../core/router';
import { Scheme, navBarBg, withAlpha, darkScheme, lightScheme, DEFAULT_ACCENT } from '../core/theme';
import { t } from '../core/l10n';
import { DiscoverPage } from '../features/browse/discover/discover_page';
import { SearchPage } from '../features/search_page';
import { FavoritesPage } from '../features/favorites_page';
import { SettingsPage } from '../features/settings_page';
import { MiniPlayerBar } from '../widgets/mini_player_bar';
import { StationListPage } from '../features/browse/discover/station_list_page';
import { CategoryPickerPage } from '../features/browse/filters/category_picker_page';
import { PlayerPage } from '../features/player/player_page';

@Entry
@Component
struct Index {
  @Provide('navStack') navStack: NavPathStack = new NavPathStack();
  @State accent: number = DEFAULT_ACCENT;
  @State dark: boolean = true;
  @State langVer: number = 0;
  @State tabIdx: number = 0;
  private settings: SettingsController = SettingsController.inst();
  private onSettings: () => void = () => {
    this.accent = this.settings.seedColor;
    this.dark = this.calcDark();
    this.langVer++;
  };

  sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  private calcDark(): boolean {
    const mode = this.settings.themeMode;
    if (mode === ThemeMode.light) {
      return false;
    }
    if (mode === ThemeMode.dark) {
      return true;
    }
    // system：跟随系统深浅色（媒体查询；ApplicationContext 无 getColorMode）
    try {
      return this.getUIContext().getMediaQuery().matchMediaSync('(dark-mode: true)').matches;
    } catch (e) {
      return true;
    }
  }

  aboutToAppear(): void {
    Router.init(this.navStack, getContext(this) as common.UIAbilityContext);
    this.onSettings();
    this.settings.addListener(this.onSettings);
  }

  aboutToDisappear(): void {
    this.settings.removeListener(this.onSettings);
  }

  @Builder
  pageMap(name: string) {
    if (name === Routes.StationList) {
      StationListPage({ accent: this.accent, dark: this.dark, langVer: this.langVer })
    } else if (name === Routes.CategoryPicker) {
      CategoryPickerPage({ accent: this.accent, dark: this.dark, langVer: this.langVer })
    } else if (name === Routes.Player) {
      PlayerPage({ accent: this.accent, dark: this.dark, langVer: this.langVer })
    }
  }

  /// 底部导航项：药丸指示 + 图标 + 标签（M3 NavigationBar 样式）。
  @Builder
  navItem(index: number, label: string, icon: Resource, iconActive: Resource) {
    Column({ space: 4 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.tabIdx === index) {
          Column()
            .width(64)
            .height(32)
            .borderRadius(16)
            .backgroundColor(withAlpha(this.sc().primary, 0.12))
        }
        SymbolGlyph(this.tabIdx === index ? iconActive : icon)
          .fontSize(24)
          .fontColor([this.tabIdx === index ? this.sc().onSurface : this.sc().onSurfaceVariant])
      }
      .width(64)
      .height(32)
      Text(label)
        .fontSize(12)
        .fontWeight(this.tabIdx === index ? 600 : 500)
        .fontColor(this.tabIdx === index ? this.sc().onSurface : this.sc().onSurfaceVariant)
    }
    .layoutWeight(1)
    .onClick(() => {
      this.tabIdx = index;
    })
  }

  build() {
    Navigation(this.navStack) {
      Column() {
        // 4 tab 内容：同时挂树保状态（对齐 IndexedStack 行为）
        Stack() {
          Column() {
            DiscoverPage({ accent: this.accent, dark: this.dark, langVer: this.langVer })
          }
          .width('100%')
          .height('100%')
          .visibility(this.tabIdx === 0 ? Visibility.Visible : Visibility.None)

          Column() {
            SearchPage({ accent: this.accent, dark: this.dark, langVer: this.langVer })
          }
          .width('100%')
          .height('100%')
          .visibility(this.tabIdx === 1 ? Visibility.Visible : Visibility.None)

          Column() {
            FavoritesPage({ accent: this.accent, dark: this.dark, langVer: this.langVer })
          }
          .width('100%')
          .height('100%')
          .visibility(this.tabIdx === 2 ? Visibility.Visible : Visibility.None)

          Column() {
            SettingsPage({ accent: this.accent, dark: this.dark, langVer: this.langVer })
          }
          .width('100%')
          .height('100%')
          .visibility(this.tabIdx === 3 ? Visibility.Visible : Visibility.None)
        }
        .layoutWeight(1)
        .width('100%')

        // 迷你播放条 + 导航栏
        MiniPlayerBar({ scheme: this.sc() })
        Row() {
          this.navItem(0, t('tabDiscover'), $r('sys.symbol.radio'), $r('sys.symbol.radio'))
          this.navItem(1, t('tabSearch'), $r('sys.symbol.magnifyingglass'), $r('sys.symbol.magnifyingglass'))
          this.navItem(2, t('tabFavorites'), $r('sys.symbol.heart'), $r('sys.symbol.heart_fill'))
          this.navItem(3, t('tabSettings'), $r('sys.symbol.gearshape'), $r('sys.symbol.gearshape_fill'))
        }
        .width('100%')
        .height(80)
        .backgroundColor(navBarBg(this.dark))
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.sc().surface)
      .id(`langRoot${this.langVer}`)
    }
    .navDestination(this.pageMap)
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
  }
}
