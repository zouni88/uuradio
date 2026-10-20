import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/record_local_ds.dart';
import '../../data/providers.dart';
import '../../data/repositories/radio_repository_impl.dart';
import '../../domain/models/station.dart';

/// 收藏备份格式。
/// { "app": "iradio", "version": 1, "exportedAt": ..., "stations": [...] }
class BackupService {
  BackupService(this._ref);

  final Ref _ref;

  /// 导出收藏（Android SAF，无需存储权限）。返回保存位置或 null（用户取消）。
  Future<Uri?> exportFavorites() async {
    final favorites = _ref.read(playRecordRepositoryProvider).favorites();
    final payload = {
      'app': 'iradio',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'stations': favorites.map(_stationToBackupJson).toList(),
    };
    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final stamp = DateTime.now()
        .toIso8601String()
        .substring(0, 10)
        .replaceAll('-', '');
    final fileName = 'iradio_favorites_$stamp.json';
    final result = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(json)),
      mimeType: 'application/json',
    );
    return result;
  }

  /// 导入收藏（合并去重）。返回导入数量；用户取消返回 null。
  Future<int?> importFavorites() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw const FormatException('empty file');

    final imported = parseBackup(utf8.decode(bytes));
    final repo = _ref.read(playRecordRepositoryProvider);
    var count = 0;
    for (final station in imported) {
      if (station.uuid.isEmpty || station.streamUrl.isEmpty) continue;
      if (!repo.isFavorite(station.uuid)) {
        await repo.addFavorite(station);
        count++;
      }
    }
    return count;
  }

  /// 解析备份 JSON；对非法内容抛 FormatException。
  static List<Station> parseBackup(String content) {
    final root = jsonDecode(content);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('backup root must be an object');
    }
    final list = root['stations'];
    if (list is! List) {
      throw const FormatException('backup missing stations array');
    }
    return list
        .whereType<Map<String, dynamic>>()
        .map(stationFromLocalJson)
        .toList();
  }

  static Map<String, dynamic> _stationToBackupJson(Station s) {
    final box = hiveBox(HiveBoxes.favorites);
    var addedAt = DateTime.now().toUtc().toIso8601String();
    final raw = box.get(s.uuid);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final at = map['addedAt'];
        if (at is String) addedAt = at;
      } catch (_) {}
    }
    return {
      'uuid': s.uuid,
      'name': s.name,
      'streamUrl': s.streamUrl,
      'logoUrl': s.logoUrl,
      'homepage': s.homepage,
      'countryCode': s.countryCode,
      'country': s.country,
      'tags': s.tags,
      'addedAt': addedAt,
    };
  }
}
