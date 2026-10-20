// 信号快照：网络类型 + dBm 场强 + 信号等级 0..4（对齐 Flutter signal_service.dart）。
// WiFi 用 wifiManager.getWifiLinkInfo（GET_WIFI_INFO），蜂窝用 radio.getSignalInformation（GET_NETWORK_INFO）。
import { wifiManager } from '@kit.ConnectivityKit';
import { radio } from '@kit.TelephonyKit';

export enum NetType {
  wifi,
  cell,
  none
}

export class SignalInfo {
  type: NetType = NetType.none;
  /// dBm 场强，不可测时为 -1。
  rssi: number = -1;
  hasRssi: boolean = false;
  /// 信号等级 0..4。
  level: number = 0;

  get available(): boolean {
    return this.type !== NetType.none;
  }
}

export class SignalService {
  async read(): Promise<SignalInfo> {
    // WiFi 优先
    try {
      const info: wifiManager.WifiLinkedInfo = await wifiManager.getLinkedInfo();
      const s = new SignalInfo();
      s.type = NetType.wifi;
      s.rssi = info.rssi;
      s.hasRssi = true;
      s.level = Math.min(4, wifiManager.getSignalLevel(info.rssi, info.band));
      return s;
    } catch (e) {
      // 无 WiFi 连接/权限缺失：继续探测蜂窝
    }
    // 蜂窝
    try {
      const infos = await radio.getSignalInformation(0);
      let bestLevel = 0;
      let bestDbm = 0;
      let hasDbm = false;
      for (const si of infos) {
        if (si.signalLevel > bestLevel) {
          bestLevel = si.signalLevel;
        }
        if (si.dBm >= 0) {
          hasDbm = true;
          if (si.dBm > bestDbm) {
            bestDbm = si.dBm;
          }
        }
      }
      if (bestLevel > 0) {
        const s = new SignalInfo();
        s.type = NetType.cell;
        s.level = Math.min(4, bestLevel);
        if (hasDbm) {
          s.rssi = bestDbm;
          s.hasRssi = true;
        }
        return s;
      }
    } catch (e) {
    }
    return new SignalInfo();
  }
}
