import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../../core/constants/api_constants.dart';
import '../../domain/models/play_history_entry.dart';
import '../../domain/models/station.dart';
import '../../domain/repositories/play_record_repository.dart';
import '../dto/station_dto.dart';

/// Hive box 名称常量（main 中统一打开）。
class HiveBoxes {
  HiveBoxes._();

  static const String favorites = 'favorites';
  static const String history = 'history';
  static const String browseCache = 'browseCache';
}

/// 已打开的 box 访问入口。
Box<String> hiveBox(String name) => Hive.box<String>(name);

/// 收藏与播放历史的本地实现（Hive）。
class RecordLocalDs implements PlayRecordRepository {
  Box<String> get _favorites => hiveBox(HiveBoxes.favorites);
  Box<String> get _history => hiveBox(HiveBoxes.history);

  static const String _historyKey = 'entries';

  @override
  List<Station> favorites() {
    final result = <Station>[];
    for (final raw in _favorites.values) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final station = StationDto.fromJson(json).toDomain();
        if (station.uuid.isNotEmpty) result.add(station);
      } catch (_) {
        // 跳过损坏条目。
      }
    }
    // 最新收藏在前。
    result.sort((a, b) => _addedAt(b).compareTo(_addedAt(a)));
    return result;
  }

  String _addedAt(Station s) {
    final raw = _favorites.get(s.uuid);
    if (raw == null) return '';
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return json['addedAt'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  bool isFavorite(String uuid) => _favorites.containsKey(uuid);

  @override
  Future<void> addFavorite(Station station) {
    final json = StationDto.fromDomain(station).toJson()
      ..['addedAt'] = DateTime.now().toUtc().toIso8601String();
    return _favorites.put(station.uuid, jsonEncode(json));
  }

  @override
  Future<void> removeFavorite(String uuid) => _favorites.delete(uuid);

  @override
  List<PlayHistoryEntry> history() {
    final raw = _history.get(_historyKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list.whereType<Map<String, dynamic>>().map((e) {
        final station =
            StationDto.fromJson(e['station'] as Map<String, dynamic>? ?? const {})
                .toDomain();
        return PlayHistoryEntry(
          station: station,
          playedAt: DateTime.tryParse(e['playedAt'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> recordPlay(Station station) async {
    final entries = history()
        .where((e) => e.station.uuid != station.uuid)
        .toList()
      ..insert(
        0,
        PlayHistoryEntry(station: station, playedAt: DateTime.now()),
      );
    if (entries.length > ApiConstants.historyLimit) {
      entries.removeRange(ApiConstants.historyLimit, entries.length);
    }
    final payload = entries
        .map((e) => {
              'station': StationDto.fromDomain(e.station).toJson(),
              'playedAt': e.playedAt.toIso8601String(),
            })
        .toList();
    await _history.put(_historyKey, jsonEncode(payload));
  }

  @override
  Future<void> clearHistory() => _history.delete(_historyKey);
}
