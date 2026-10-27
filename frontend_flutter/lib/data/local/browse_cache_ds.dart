import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../../domain/models/browse_category.dart';
import '../../domain/models/station.dart';
import '../dto/category_dto.dart';
import '../dto/station_dto.dart';

/// 浏览类列表缓存：key=请求签名，value=JSON。
/// 命中缓存先秒出（不转圈），网络后台静默刷新；网络失败回落缓存。
class BrowseCacheDs {
  BrowseCacheDs(this._box);

  final Box<String> _box;

  // ---- 电台列表（榜单/国家/标签/语言） ----

  List<Station>? getStations(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final items = map['items'] as List<dynamic>;
      return items
          .map((e) => StationDto.fromJson(e as Map<String, dynamic>).toDomain())
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> putStations(String key, List<Station> stations) {
    final raw = jsonEncode({
      'items': stations.map((s) => StationDto.fromDomain(s).toJson()).toList(),
    });
    return _box.put(key, raw);
  }

  // ---- 分类列表（国家/标签/语言） ----

  List<BrowseCategory>? getCategories(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final items = map['items'] as List<dynamic>;
      return items
          .map(
              (e) => CategoryDto.fromJson(e as Map<String, dynamic>).toDomain())
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> putCategories(String key, List<BrowseCategory> categories) {
    final raw = jsonEncode({
      'items':
          categories.map((c) => CategoryDto.fromDomain(c).toJson()).toList(),
    });
    return _box.put(key, raw);
  }

  // ---- 通用原始 JSON 字符串（如 TV 流旁路元信息） ----

  String? getRaw(String key) => _box.get(key);

  Future<void> putRaw(String key, String raw) => _box.put(key, raw);
}
