import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../../core/constants/api_constants.dart';
import '../local/settings_local_ds.dart';

/// RadioBrowser API 服务器解析：自定义镜像优先，否则自动发现并缓存。
/// 不硬连单一服务器是 API 的使用约定（官方镜像会随机分发请求）。
class ApiServerResolver {
  ApiServerResolver(this._settingsDs, this._cache, this._dio);

  final SettingsLocalDs _settingsDs;
  final Box<String> _cache;
  final Dio _dio;

  String? _resolved;

  static const String _kServer = 'api_server';
  static const String _kServerTime = 'api_server_time';

  /// 归一化用户输入的镜像地址：去 scheme/路径/斜杠，返回纯 host。
  /// 空串 = 恢复自动发现；非法返回 null。
  static String? normalizeHost(String input) {
    var h = input.trim();
    if (h.isEmpty) return '';
    final uri = Uri.tryParse(h.contains('://') ? h : 'https://$h');
    if (uri == null || uri.host.isEmpty) return null;
    h = uri.host;
    if (h.endsWith('.')) h = h.substring(0, h.length - 1);
    if (!RegExp(r'^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$').hasMatch(h)) {
      return null;
    }
    return h;
  }

  /// 当前应使用的 host（不含 scheme）。
  Future<String> host() async {
    final cached = _resolved;
    if (cached != null) return cached;

    final settings = await _settingsDs.load();
    if (settings.customMirror.isNotEmpty) {
      _resolved = settings.customMirror;
      return _resolved!;
    }

    final server = _cache.get(_kServer);
    final timeStr = _cache.get(_kServerTime);
    if (server != null && timeStr != null) {
      final savedAt = DateTime.tryParse(timeStr);
      if (savedAt != null &&
          DateTime.now().difference(savedAt) < ApiConstants.serverCacheTtl) {
        _resolved = server;
        return server;
      }
    }

    final fresh = await _discover();
    _resolved = fresh;
    await _cache.put(_kServer, fresh);
    await _cache.put(_kServerTime, DateTime.now().toIso8601String());
    return fresh;
  }

  /// 请求失败（主机不可达）时失效缓存，下次请求重新解析。
  Future<void> invalidate() async {
    _resolved = null;
    await _cache.delete(_kServer);
    await _cache.delete(_kServerTime);
  }

  /// 自定义镜像变更后失效内存缓存，下次请求重新解析。
  void resetCustomMirror() => _resolved = null;

  /// 轻量探活：服务器列表接口只返回少量数据，超时短。
  Future<bool> _isReachable(String host) async {
    try {
      await _dio.get<dynamic>(
        'https://$host/json/servers',
        options: Options(
          connectTimeout: ApiConstants.probeTimeout,
          receiveTimeout: ApiConstants.probeTimeout,
          sendTimeout: ApiConstants.probeTimeout,
        ),
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[API] server $host unreachable: $e');
      return false;
    }
  }

  Future<String> _discover() async {
    try {
      final resp = await _dio.get<dynamic>(
        'https://all.api.radio-browser.info/json/servers',
        options: Options(
          connectTimeout: ApiConstants.probeTimeout,
          receiveTimeout: ApiConstants.apiTimeout,
        ),
      );
      final list = resp.data;
      if (list is List) {
        final names = list
            .whereType<Map<String, dynamic>>()
            .map((e) => e['name'] as String? ?? '')
            .where((n) => n.isNotEmpty)
            .toList()
          ..shuffle(Random());
        // 逐个探活，返回第一个可达的服务器。
        for (final name in names) {
          if (await _isReachable(name)) return name;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[API] server discovery via all.api failed: $e');
      }
    }
    // 发现失败顺序探测种子服务器，避免随机选中不可达主机。
    for (final seed in ApiConstants.seedServers) {
      if (await _isReachable(seed)) return seed;
    }
    return ApiConstants.seedServers[Random().nextInt(ApiConstants.seedServers.length)];
  }
}
