import '../models/play_history_entry.dart';
import '../models/station.dart';

/// 收藏与播放历史的抽象。
abstract interface class PlayRecordRepository {
  List<Station> favorites();
  bool isFavorite(String uuid);
  Future<void> addFavorite(Station station);
  Future<void> removeFavorite(String uuid);

  List<PlayHistoryEntry> history();
  Future<void> recordPlay(Station station);
  Future<void> clearHistory();
}
