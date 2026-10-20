import 'station.dart';

/// 一条播放历史记录。
class PlayHistoryEntry {
  const PlayHistoryEntry({required this.station, required this.playedAt});

  final Station station;
  final DateTime playedAt;
}
