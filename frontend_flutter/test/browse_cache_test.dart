import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:iradio/data/local/browse_cache_ds.dart';
import 'package:iradio/data/local/settings_local_ds.dart';
import 'package:iradio/data/network/api_server_resolver.dart';
import 'package:iradio/data/repositories/radio_repository_impl.dart';
import 'package:iradio/domain/models/station_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// 固定 host 的解析器（不触网、不读设置）。
class _FixedResolver extends ApiServerResolver {
  _FixedResolver(Box<String> box)
      : super(SettingsLocalDs(SharedPreferencesAsync()), box, Dio());

  @override
  Future<String> host() async => 'fake.local';

  @override
  Future<void> invalidate() async {}
}

/// 可编程假网络适配器：记录调用次数、返回预设 JSON。
class _FakeAdapter implements HttpClientAdapter {
  int calls = 0;
  bool shouldFail = false;
  List<Object?> response = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    if (shouldFail) {
      throw DioException.connectionError(
          requestOptions: options, reason: 'fake offline');
    }
    return ResponseBody.fromString(jsonEncode(response), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> apiStation(String uuid, String name) => {
      'stationuuid': uuid,
      'name': name,
      'url': 'http://$uuid',
      'url_resolved': 'https://$uuid',
      'countrycode': 'CN',
    };

void main() {
  late Directory hiveDir;
  late Box<String> box;
  late _FakeAdapter adapter;
  late RadioRepositoryImpl repo;
  var boxSeq = 0;

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('iradio_hive_test');
    Hive.init(hiveDir.path);
    box = await Hive.openBox<String>('browse_cache_${boxSeq++}');
    adapter = _FakeAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = RadioRepositoryImpl(_FixedResolver(box), dio, BrowseCacheDs(box));
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await Hive.close();
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  test('国家电台列表：二次进入缓存秒出，后台静默刷新回写', () async {
    const q = StationQuery(
        countryCode: 'CN', order: StationQuery.orderByClicks, reverse: true);

    adapter.response = [apiStation('a', 'A')];
    final r1 = await repo.search(q);
    expect(r1.map((s) => s.name), ['A']);
    expect(adapter.calls, 1);

    // 网络数据已变化：再次进入应秒出上次缓存，而不是等新数据。
    adapter.response = [apiStation('b', 'B')];
    final r2 = await repo.search(q);
    expect(r2.map((s) => s.name), ['A']);

    // 等待静默刷新回写缓存后，下一次进入即是新数据。
    for (var i = 0; i < 100 && adapter.calls < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final r3 = await repo.search(q);
    expect(r3.map((s) => s.name), ['B']);
  });

  test('名称搜索不进缓存（每次直连网络）', () async {
    adapter.response = [apiStation('a', 'A')];
    await repo.search(const StationQuery(name: 'bbc'));
    adapter.response = [apiStation('b', 'B')];
    final r2 = await repo.search(const StationQuery(name: 'bbc'));
    expect(r2.map((s) => s.name), ['B']);
    expect(adapter.calls, 2);
  });

  test('热门榜与分类列表同样缓存优先', () async {
    adapter.response = [apiStation('a', 'A')];
    await repo.topByClicks(limit: 20);
    adapter.response = [apiStation('b', 'B')];
    final again = await repo.topByClicks(limit: 20);
    expect(again.map((s) => s.name), ['A']);

    adapter.response = [
      {'name': 'China', 'iso_code': 'CN', 'stationcount': 10}
    ];
    final c1 = await repo.countries();
    expect(c1.single.name, 'China');
    adapter.response = [
      {'name': 'Germany', 'iso_code': 'DE', 'stationcount': 5}
    ];
    final c2 = await repo.countries();
    expect(c2.single.name, 'China');
  });

  test('缓存命中后网络失败不影响秒出', () async {
    const q = StationQuery(countryCode: 'FR');
    adapter.response = [apiStation('a', 'A')];
    await repo.search(q);
    adapter.shouldFail = true;
    final r = await repo.search(q);
    expect(r.map((s) => s.name), ['A']);
  });

  test('无缓存且网络失败时抛出异常', () async {
    adapter.shouldFail = true;
    await expectLater(
        repo.search(const StationQuery(countryCode: 'US')), throwsA(anything));
  });
}
