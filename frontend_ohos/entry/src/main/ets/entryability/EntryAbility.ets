// 应用入口：初始化存储 / 控制器，注册赛博朋克字体，深色窗口。
import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit';
import { window, font } from '@kit.ArkUI';
import { KvStore } from '../core/kvstore';
import { Prefs } from '../core/prefs';
import { SettingsController } from '../controllers/settings_controller';
import { FavoritesController } from '../controllers/favorites_controller';
import { HistoryController } from '../controllers/history_controller';

export default class EntryAbility extends UIAbility {
  async onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): Promise<void> {
    // 存储层先就绪
    await KvStore.init(this.context);
    await Prefs.init(this.context);
    // 控制器加载持久化数据
    await SettingsController.inst().load();
    await FavoritesController.inst().load();
    await HistoryController.inst().load();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 深空底色窗口
    try {
      const win = windowStage.getMainWindowSync();
      win.setWindowBackgroundColor('#05070D');
    } catch (e) {
    }

    // 注册字体（按字重拆族，registerFont 不支持 weight）
    try {
      font.registerFont({ familyName: 'Orbitron', familySrc: 'file:///resource/rawfile/fonts/orbitron-500.ttf' });
      font.registerFont({ familyName: 'OrbitronBold', familySrc: 'file:///resource/rawfile/fonts/orbitron-700.ttf' });
      font.registerFont({ familyName: 'OrbitronBlack', familySrc: 'file:///resource/rawfile/fonts/orbitron-900.ttf' });
      font.registerFont({ familyName: 'JetBrainsMono', familySrc: 'file:///resource/rawfile/fonts/jetbrains-mono-400.ttf' });
      font.registerFont({ familyName: 'JetBrainsMonoBold', familySrc: 'file:///resource/rawfile/fonts/jetbrains-mono-700.ttf' });
    } catch (e) {
    }

    windowStage.loadContent('pages/Index', () => {
    });
  }
}
