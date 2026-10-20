import '../models/browse_category.dart';
import '../models/station.dart';
import '../models/station_query.dart';

/// 电台数据源抽象：换数据源（如未来自建后端）只需提供新的实现。
abstract interface class RadioRepository {
  Future<List<Station>> search(StationQuery query);
  Future<List<Station>> topByClicks({required int limit});
  Future<List<Station>> topByVotes({required int limit});
  Future<List<BrowseCategory>> countries();
  Future<List<BrowseCategory>> tags({int limit});
  Future<List<BrowseCategory>> languages();
  Future<void> reportClick(String stationUuid);
  Future<List<Station>> stationsByUuids(List<String> uuids);
}
