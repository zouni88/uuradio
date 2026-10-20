// 全局常量：RadioBrowser API 相关（对齐 Flutter api_constants.dart）。
export class ApiConstants {
  /// API 要求自定义 UA 标识应用。
  static readonly USER_AGENT = 'iradio/1.0 (HarmonyOS)';

  /// 官方镜像种子服务器（不硬连单一服务器是 API 的使用约定）。
  static readonly SEED_SERVERS: string[] = [
    'de1.api.radio-browser.info',
    'at1.api.radio-browser.info',
    'nl1.api.radio-browser.info',
    'fi1.api.radio-browser.info'
  ];

  static readonly PAGE_SIZE = 50;

  /// API 请求超时（毫秒）。
  static readonly API_TIMEOUT = 10000;
  /// 镜像探测超时（毫秒）。
  static readonly PROBE_TIMEOUT = 5000;
  /// 直播流连接超时（毫秒）。
  static readonly STREAM_SET_TIMEOUT = 15000;
  /// 服务器镜像缓存 TTL（7 天，毫秒）。
  static readonly SERVER_CACHE_TTL = 7 * 24 * 60 * 60 * 1000;
  /// 播放历史条数上限。
  static readonly HISTORY_LIMIT = 100;
}
