import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api_constants.dart';
import '../domain/repositories/intercom_repository.dart';
import '../domain/repositories/iptv_repository.dart';
import '../domain/repositories/play_record_repository.dart';
import '../domain/repositories/radio_repository.dart';
import 'local/browse_cache_ds.dart';
import 'local/record_local_ds.dart';
import 'local/settings_local_ds.dart';
import 'network/api_server_resolver.dart';
import 'network/intercom_signaling_client.dart';
import 'repositories/intercom_repository_impl.dart';
import 'repositories/iptv_repository_impl.dart';
import 'repositories/radio_repository_impl.dart';

/// 设置本地数据源：main 中 overrideWithValue 注入。
final settingsDsProvider = Provider<SettingsLocalDs>(
  (ref) => SettingsLocalDs(SharedPreferencesAsync()),
);

/// API 服务器解析器。
final apiServerResolverProvider = Provider<ApiServerResolver>((ref) {
  return ApiServerResolver(
    ref.watch(settingsDsProvider),
    Hive.box<String>(HiveBoxes.browseCache),
    ref.watch(dioProvider),
  );
});

/// 共享 Dio 实例。
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    connectTimeout: ApiConstants.apiTimeout,
    receiveTimeout: ApiConstants.apiTimeout,
    headers: {'User-Agent': ApiConstants.userAgent},
  ));
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestHeader: false,
      responseHeader: false,
      error: true,
      logPrint: (obj) => debugPrint('[API] $obj'),
    ));
  }
  return dio;
});

/// 浏览列表缓存数据源（box 已在 main 中打开）。
final browseCacheDsProvider = Provider<BrowseCacheDs>(
  (ref) => BrowseCacheDs(Hive.box<String>(HiveBoxes.browseCache)),
);

/// 电台数据源。
final radioRepositoryProvider = Provider<RadioRepository>((ref) {
  return RadioRepositoryImpl(
    ref.watch(apiServerResolverProvider),
    ref.watch(dioProvider),
    ref.watch(browseCacheDsProvider),
  );
});

/// IPTV 频道数据源（iptv-org 社区，全量 join + SWR 缓存）。
final iptvRepositoryProvider = Provider<IptvRepository>((ref) {
  return IptvRepositoryImpl(
    ref.watch(dioProvider),
    ref.watch(browseCacheDsProvider),
    enableLogos: true,
  );
});

/// 收藏与播放历史。
final playRecordRepositoryProvider = Provider<PlayRecordRepository>((ref) {
  return RecordLocalDs();
});

/// 对讲信令仓库。非 autoDispose：连接跨页面重建存活，退出频道由控制器显式 leave。
final intercomRepositoryProvider = Provider<IntercomRepository>((ref) {
  final repo = IntercomRepositoryImpl(IntercomSignalingClient());
  ref.onDispose(repo.dispose);
  return repo;
});
