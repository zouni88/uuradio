// 轻量路由：NavPathStack 单例 + 常用跳转（对齐 Flutter AppNavigator）。
// NavPathStack / PopInfo 为 ArkUI 全局类型，无需 import。
import { common } from '@kit.AbilityKit';
import url from '@ohos.url';

export class Routes {
  static readonly StationList = 'StationList';
  static readonly CategoryPicker = 'CategoryPicker';
  static readonly Player = 'Player';
}

export class Router {
  private static stack: NavPathStack | null = null;
  private static abilityContext: common.UIAbilityContext | null = null;

  static init(stack: NavPathStack, context: common.UIAbilityContext): void {
    Router.stack = stack;
    Router.abilityContext = context;
  }

  static push(name: string, param?: Object, onPop?: (info: PopInfo) => void): void {
    if (onPop !== undefined) {
      Router.stack?.pushPathByName(name, param ?? null, onPop, true);
    } else {
      Router.stack?.pushPathByName(name, param ?? null);
    }
  }

  static pop(result?: Object): void {
    if (result) {
      Router.stack?.pop(result);
    } else {
      Router.stack?.pop();
    }
  }

  /// 播放页（由 Index 的 customNavContentBuilder 提供底部滑入动画）。
  static openPlayer(): void {
    Router.push(Routes.Player);
  }

  /// 浏览器打开电台主页（非法 URL 静默忽略，对齐 Flutter openHomepage 校验）。
  static openHomepage(urlStr: string): void {
    const trimmed = urlStr.trim();
    try {
      const parsed = url.URL.parseURL(trimmed);
      if (parsed.host === undefined || !parsed.host.includes('.')) {
        return;
      }
      Router.abilityContext?.openLink(trimmed);
    } catch (e) {
      // 解析失败忽略
    }
  }
}
