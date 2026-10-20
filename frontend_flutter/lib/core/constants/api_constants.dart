/// 全局常量：RadioBrowser API 相关。
class ApiConstants {
  ApiConstants._();

  /// API 要求自定义 UA 标识应用。
  static const String userAgent = 'iradio/1.0 (Flutter; Android)';

  /// 官方镜像种子服务器（不硬连单一服务器是 API 的使用约定）。
  static const List<String> seedServers = [
    'de1.api.radio-browser.info',
    'at1.api.radio-browser.info',
    'nl1.api.radio-browser.info',
    'fi1.api.radio-browser.info',
  ];

  static const int pageSize = 50;

  static const Duration apiTimeout = Duration(seconds: 10);
  static const Duration probeTimeout = Duration(seconds: 5);

  /// 直播流连接超时。
  static const Duration streamSetTimeout = Duration(seconds: 15);

  static const Duration serverCacheTtl = Duration(days: 7);

  /// 播放历史条数上限。
  static const int historyLimit = 100;
}
