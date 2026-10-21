import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/browse_category.dart';
import '../../domain/models/station.dart';
import '../../domain/models/station_query.dart';
import '../../domain/repositories/radio_repository.dart';
import '../dto/station_dto.dart';
import '../network/api_server_resolver.dart';

/// 本地/备份 JSON -> Station（与 StationDto.toJson 的 camelCase 形态兼容）。
Station stationFromLocalJson(Map<String, dynamic> json) =>
    StationDto.fromJson(json).toDomain();

/// radio-browser.info 公开 API 实现。
class RadioRepositoryImpl implements RadioRepository {
  RadioRepositoryImpl(this._resolver, this._dio);

  final ApiServerResolver _resolver;
  final Dio _dio;

  /// 发起请求；当前主机连接失败时失效缓存并换服务器重试一次。
  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? params,
  }) async {
    for (var attempt = 0;; attempt++) {
      final host = await _resolver.host();
      try {
        final url = 'https://$host/json$path';
        final resp = method == 'get'
            ? await _dio.get<dynamic>(url, queryParameters: params)
            : await _dio.post<dynamic>(url, queryParameters: params);
        return resp.data;
      } on DioException catch (e) {
        if (kDebugMode) {
          debugPrint('[API] $method $path via $host failed: '
              '${e.type.name} ${e.message ?? e.error}');
        }
        final retriable = e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout;
        if (retriable && attempt == 0) {
          await _resolver.invalidate();
          continue;
        }
        throw _mapError(e);
      }
    }
  }

  Future<dynamic> _get(String path, {Map<String, dynamic>? params}) =>
      _request('get', path, params: params);

  Future<dynamic> _post(String path, {Map<String, dynamic>? params}) =>
      _request('post', path, params: params);

  Never _mapError(DioException e) {
    if (e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionTimeout) {
      throw TimeoutException('radio-browser request: ${e.requestOptions.path}');
    }
    throw e;
  }

  Station _stationFromApiJson(Map<String, dynamic> j) =>
      StationDto.fromJson(j).toDomain();

  List<Station> _stations(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(_stationFromApiJson)
        .where((s) => s.uuid.isNotEmpty && s.streamUrl.isNotEmpty)
        .toList();
  }

  @override
  Future<List<Station>> search(StationQuery query) async {
    final data = await _get(
      '/stations/search',
      params: query.toQueryParameters(),
    );
    return _stations(data);
  }

  @override
  Future<List<Station>> topByClicks({required int limit}) async {
    final data = await _get('/stations/topclick/$limit');
    return _stations(data);
  }

  @override
  Future<List<Station>> topByVotes({required int limit}) async {
    final data = await _get('/stations/topvote/$limit');
    return _stations(data);
  }

  @override
  Future<List<BrowseCategory>> countries() async {
    final data = await _get('/countries');
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((j) => BrowseCategory(
              name: j['name'] as String? ?? '',
              stationCount: j['stationcount'] as int? ?? 0,
              isoCode: j['iso_code'] as String?,
            ))
        .where((c) => c.name.isNotEmpty)
        .toList();
  }

  @override
  Future<List<BrowseCategory>> tags({int limit = 60}) async {
    final data = await _get('/tags', params: {'limit': '$limit'});
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((j) => BrowseCategory(
              name: j['name'] as String? ?? '',
              stationCount: j['stationcount'] as int? ?? 0,
            ))
        .where((c) => c.name.isNotEmpty)
        .toList();
  }

  @override
  Future<List<BrowseCategory>> languages() async {
    final data = await _get('/languages');
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((j) => BrowseCategory(
              name: j['name'] as String? ?? '',
              stationCount: j['stationcount'] as int? ?? 0,
            ))
        .where((c) => c.name.isNotEmpty)
        .toList();
  }

  @override
  Future<void> reportClick(String stationUuid) async {
    if (stationUuid.isEmpty) return;
    try {
      await _get('/url/click/$stationUuid');
    } catch (_) {
      // 上报失败不影响播放。
    }
  }

  @override
  Future<List<Station>> stationsByUuids(List<String> uuids) async {
    if (uuids.isEmpty) return const [];
    final data = await _post(
      '/stations/byuuid',
      params: {'uuids': uuids.join(',')},
    );
    return _stations(data);
  }
}
