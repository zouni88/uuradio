// 通用分页电台列表页（榜单/国家/标签/语言共用）。
// 参数：{ title: string, query: StationQuery }（由 Router.push 传入）。
import { StationQuery } from '../../../domain/models';
import { StationListController } from '../../../controllers/list_controller';
import { AppRepositories } from '../../../controllers/discover_controller';
import { Scheme, darkScheme, lightScheme, DEFAULT_ACCENT } from '../../../core/theme';
import { Routes, Router } from '../../../core/router';
import { AppBarRow } from '../../common';
import { StationListView } from './station_list_view';

/// 路由参数对象。
export class StationListArgs {
  title: string = '';
  query: StationQuery = new StationQuery();
}

@Component
export struct StationListPage {
  @Prop accent: number = DEFAULT_ACCENT;
  @Prop dark: boolean = true;
  @Prop langVer: number = 0;
  @State private args: StationListArgs = new StationListArgs();
  private ctl: StationListController | null = null;

  sc(): Scheme {
    return this.dark ? darkScheme(this.accent) : lightScheme(this.accent);
  }

  build() {
    NavDestination() {
      Column() {
        AppBarRow({
          sc: this.sc(),
          title: this.args.title,
          onBack: () => Router.pop()
        })
        if (this.ctl !== null) {
          StationListView({
            accent: this.accent, dark: this.dark, langVer: this.langVer,
            controller: this.ctl
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.sc().surface)
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      const param: Object | null = ctx.pathInfo.param as Object | null;
      if (param !== null && param !== undefined) {
        this.args = param as StationListArgs;
        if (this.ctl === null) {
          this.ctl = new StationListController(AppRepositories.repo, this.args.query);
        }
      }
    })
  }
}
