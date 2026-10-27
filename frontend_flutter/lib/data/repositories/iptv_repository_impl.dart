import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/browse_category.dart';
import '../../domain/models/station.dart';
import '../../domain/models/tv_stream_meta.dart';
import '../../domain/repositories/iptv_repository.dart';
import '../dto/iptv_dto.dart';
import '../local/browse_cache_ds.dart';

/// iptv-org 社区数据源实现：全量 JSON 三表 join + SWR 缓存 + 内存过滤。
///
/// 数据端点（GitHub Pages，国内速度不稳，靠 SWR 先出缓存兜底）：
/// channels.json（元数据）× streams.json（流地址）× logos.json（台标，可关）
/// × countries.json（译名）− blocklist.json（dmca/nsfw 兜底）。
class IptvRepositoryImpl implements IptvRepository {
  IptvRepositoryImpl(this._dio, this._cache, {this.enableLogos = true});

  final Dio _dio;
  final BrowseCacheDs _cache;

  /// logos.json 是最大文件（5-8MB），失败/关闭仅降级为占位台标。
  final bool enableLogos;

  static const String _base = 'https://iptv-org.github.io/api';
  static const String _kChannels = 'tv:channels';
  static const String _kMeta = 'tv:meta';

  /// 大文件放宽接收超时（全局 apiTimeout=10s 不够）。
  static const Duration _bigFileTimeout = Duration(seconds: 30);

  List<Station>? _channels;
  Map<String, TvStreamMeta>? _meta;
  Future<void>? _inflight;

  @override
  Future<List<Station>> channels({
    String? countryCode,
    String? group,
    String? keyword,
  }) async {
    await _ensureLoaded();
    final all = _channels ?? const <Station>[];
    final code = countryCode?.toUpperCase() ?? '';
    final kw = keyword?.trim().toLowerCase() ?? '';
    return all.where((s) {
      if (code.isNotEmpty && s.countryCode != code) return false;
      if (group != null && group.isNotEmpty && !s.tags.contains(group)) {
        return false;
      }
      if (kw.isNotEmpty && !s.name.toLowerCase().contains(kw)) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<BrowseCategory>> countries() async {
    await _ensureLoaded();
    final byCode = <String, ({String name, int count})>{};
    for (final s in _channels ?? const <Station>[]) {
      if (s.countryCode.isEmpty) continue;
      final cur = byCode[s.countryCode];
      byCode[s.countryCode] = (
        name: cur?.name.isNotEmpty == true ? cur!.name : s.country,
        count: (cur?.count ?? 0) + 1,
      );
    }
    final list = byCode.entries
        .map((e) => BrowseCategory(
              name: e.value.name.isNotEmpty ? e.value.name : e.key,
              stationCount: e.value.count,
              isoCode: e.key,
            ))
        .toList()
      ..sort((a, b) => b.stationCount.compareTo(a.stationCount));
    return list;
  }

  @override
  Future<List<BrowseCategory>> groups() async {
    await _ensureLoaded();
    final counts = <String, int>{};
    for (final s in _channels ?? const <Station>[]) {
      for (final tag in s.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final list = counts.entries
        .map((e) => BrowseCategory(name: e.key, stationCount: e.value))
        .toList()
      ..sort((a, b) {
        final byCount = b.stationCount.compareTo(a.stationCount);
        return byCount != 0 ? byCount : a.name.compareTo(b.name);
      });
    return list;
  }

  @override
  Future<TvStreamMeta?> streamMeta(String stationUuid) async {
    await _ensureLoaded();
    return _meta?[stationUuid];
  }

  @override
  Future<void> refresh() => _load(force: true);

  /// 缓存秒出（不转圈）+ 后台静默刷新；未命中缓存才等网络。
  Future<void> _ensureLoaded() async {
    if (_channels != null) return;
    final cached = _cache.getStations(_kChannels);
    if (cached != null && cached.isNotEmpty) {
      _channels = cached;
      _meta = _decodeMeta(_cache.getRaw(_kMeta));
      unawaited(() async {
        try {
          await _load(force: true);
        } catch (_) {
          // 静默刷新失败：保留旧缓存。
        }
      }());
      return;
    }
    await _load(force: false);
  }

  Future<void> _load({required bool force}) {
    if (!force && _channels != null) return Future.value();
    final pending = _inflight;
    if (pending != null) return pending;
    final future = _fetchAndStore().whenComplete(() => _inflight = null);
    _inflight = future;
    return future;
  }

  Future<void> _fetchAndStore() async {
    final bundle = await _fetchJoin();
    if (bundle.channels.isEmpty) return; // 不用空结果覆盖旧缓存。
    _channels = bundle.channels;
    _meta = bundle.meta;
    await _cache.putStations(_kChannels, bundle.channels);
    await _cache.putRaw(_kMeta, _encodeMeta(bundle.meta));
  }

  Future<IptvBundle> _fetchJoin() async {
    final channels = await _get('channels.json', mustHave: true);
    final streams = await _get('streams.json', mustHave: true);
    final logos = enableLogos ? await _get('logos.json') : null;
    final countries = await _get('countries.json');
    final blocklist = await _get('blocklist.json');
    // 1 万+ 对象的解码与 join 放后台 isolate，避免卡 UI 线程。
    return compute(
      decodeIptvBundle,
      IptvRawPayload(
        channels: channels,
        streams: streams,
        logos: logos,
        countries: countries,
        blocklist: blocklist,
      ),
    );
  }

  /// 可选文件失败返回 null（降级）；mustHave 文件失败抛出（由上层映射错误态）。
  Future<String?> _get(String path, {bool mustHave = false}) async {
    try {
      final resp = await _dio.get<String>(
        '$_base/$path',
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: _bigFileTimeout,
        ),
      );
      return resp.data;
    } on DioException catch (e) {
      if (mustHave) {
        if (e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          throw TimeoutException('iptv-org request: $path');
        }
        rethrow;
      }
      if (kDebugMode) {
        debugPrint('[IPTV] optional $path failed: ${e.type.name}');
      }
      return null;
    }
  }

  String _encodeMeta(Map<String, TvStreamMeta> meta) => jsonEncode({
        'items': {
          for (final e in meta.entries) e.key: e.value.toJson(),
        },
      });

  Map<String, TvStreamMeta> _decodeMeta(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final items = map['items'] as Map<String, dynamic>;
      return {
        for (final e in items.entries)
          e.key: TvStreamMeta.fromJson(e.value as Map<String, dynamic>),
      };
    } catch (_) {
      return const {};
    }
  }
}
