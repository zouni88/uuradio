import '../models/browse_category.dart';
import '../models/station.dart';
import '../models/tv_stream_meta.dart';

/// IPTV 频道数据源抽象：换源（自建后端/镜像代理）只需提供新的实现。
/// 频道以 [Station] 形态返回（uuid 带 `iptv:` 前缀），复用列表/缓存/收藏组件。
abstract interface class IptvRepository {
  /// 频道列表：countryCode/group 为空表示不限；keyword 匹配频道名。
  Future<List<Station>> channels({
    String? countryCode,
    String? group,
    String? keyword,
  });

  /// 有频道的国家（含频道数），用于筛选。
  Future<List<BrowseCategory>> countries();

  /// 分组（iptv categories，含频道数）。
  Future<List<BrowseCategory>> groups();

  /// 播放附加信息（referrer/user_agent/labels），按 Station.uuid 查。
  Future<TvStreamMeta?> streamMeta(String stationUuid);

  /// 强制重拉全量并刷新缓存（下拉刷新用）。
  Future<void> refresh();
}
