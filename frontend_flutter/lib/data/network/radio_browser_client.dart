import 'dart:async';

import 'package:dio/dio.dart';

import '../../../domain/models/browse_category.dart';
import '../../../domain/models/station.dart';
import '../../../domain/models/station_query.dart';
import '../../core/constants/api_constants.dart';
import '../../core/error/app_exception.dart';
import '../dto/category_dto.dart';
import '../dto/station_dto.dart';
import 'api_server_resolver.dart';

/// RadioBrowser HTTP 客户端：UA 头 + 服务器失败轮换。
class RadioBrowserClient {
  RadioBrowserClient(this._resolver);

  final ApiServerResolver _resolver;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: ApiConstants.apiTimeout,
    receiveTimeout: ApiConstants.apiTimeout,
    headers: {'User-Agent': ApiConstants.userAgent},
  ));

  /// 带失败轮换的 GET：超时/连接失败/5xx 时切换镜像重试（最多 3 次）。
  Future<List<dynamic>> getList(String path, {Map<String, dynamic>? query}) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      final host = await _resolver.host();
      try {
        final response = await _dio
            .get<List<dynamic>>(
              'https://$host$path',
              queryParameters: query,
              options: Options(responseType: ResponseType.json),
            )
            .timeout(ApiConstants.apiTimeout);
        return response.data ?? const [];
      } on DioException catch (e) {
        lastError = e;
        final status = e.response?.statusCode ?? 0;
        final retryable = status >= 500 || e.response == null;
        if (!retryable) rethrow;
        await _resolver.invalidate();
      } on TimeoutException catch (e) {
        lastError = e;
        await _resolver.invalidate();
      } on Exception catch (e) {
        lastError = e;
        await _resolver.invalidate();
      }
    }
    throw AppException.from(lastError ?? 'request failed: $path');
  }

  Future<List<Station>> search(StationQuery query) async {
    final list = await getList(
      '/json/stations/search',
      query: query.toQueryParameters(),
    );
    return list.map(_toStation).toList();
  }

  Future<List<Station>> _top(String path, int limit) async {
    final list = await getList('/json/stations/$path/$limit');
    return list.map(_toStation).toList();
  }

  Future<List<Station>> topByClicks({required int limit}) =>
      _top('topclick', limit);

  Future<List<Station>> topByVotes({required int limit}) =>
      _top('topvote', limit);

  Future<List<BrowseCategory>> countries() async =>
      (await getList('/json/countries')).map(_toCategory).toList();

  Future<List<BrowseCategory>> tags({int limit = 100}) async {
    final list = await getList('/json/tags', query: {
      'order': 'stationcount',
      'reverse': 'true',
      'limit': '$limit',
      'hidebroken': 'true',
    });
    return list.map(_toCategory).toList();
  }

  Future<List<BrowseCategory>> languages() async {
    final list = await getList('/json/languages', query: {
      'order': 'stationcount',
      'reverse': 'true',
      'hidebroken': 'true',
    });
    return list.map(_toCategory).toList();
  }

  Future<void> reportClick(String stationUuid) async {
    await getList('/json/url/$stationUuid');
  }

  Future<List<Station>> stationsByUuids(List<String> uuids) async {
    if (uuids.isEmpty) return const [];
    final list = await getList(
      '/json/stations/byuuid',
      query: {'uuids': uuids.join(',')},
    );
    return list.map(_toStation).toList();
  }

  Station _toStation(dynamic item) {
    if (item is Map<String, dynamic>) return StationDto.fromJson(item).toDomain();
    return StationDto.fromJson(const {}).toDomain();
  }

  BrowseCategory _toCategory(dynamic item) {
    if (item is Map<String, dynamic>) return CategoryDto.fromJson(item).toDomain();
    return const BrowseCategory(name: '');
  }
}
