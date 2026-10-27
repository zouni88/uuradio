import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:iradio/data/dto/iptv_dto.dart';
import 'package:iradio/data/local/browse_cache_ds.dart';
import 'package:iradio/data/repositories/iptv_repository_impl.dart';

/// 按文件名路由的假适配器：GET .../api/ 下的文件返回预设内容。
class _PathFakeAdapter implements HttpClientAdapter {
  final Map<String, Object?> responses = {};
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    final file = options.uri.pathSegments.last;
    final body = responses[file];
    if (body == null) {
      return ResponseBody.fromString('', 404);
    }
    return ResponseBody.fromString(
      body is String ? body : jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['text/plain'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('decodeIptvBundle 三表 join', () {
    test('合并频道/流/台标/国家名，过滤 nsfw/黑名单/孤儿流，取最高画质', () {
      final payload = IptvRawPayload(
        channels: jsonEncode([
          {'id': 'cn.1', 'name': 'CCTV-1 (720p)', 'country': 'CN', 'categories': ['General'], 'website': 'https://cctv.com'},
          {'id': 'cn.2', 'name': 'Bad', 'country': 'CN', 'is_nsfw': true},
          {'id': 'cn.3', 'name': 'Blocked', 'country': 'CN'},
          {'id': 'cn.4', 'name': 'NoStream', 'country': 'CN'},
        ]),
        streams: jsonEncode([
          {'channel': 'cn.1', 'url': 'http://low.m3u8', 'quality': '576p'},
          {'channel': 'cn.1', 'url': 'http://high.m3u8', 'quality': '1080p', 'referrer': 'https://ref', 'user_agent': 'UA/1', 'labels': ['Geo-blocked']},
          {'channel': 'cn.2', 'url': 'http://nsfw.m3u8'},
          {'channel': 'cn.3', 'url': 'http://block.m3u8'},
          {'channel': 'orphan', 'url': 'http://orphan.m3u8'},
          {'url': 'http://nochannel.m3u8'},
        ]),
        logos: jsonEncode([
          {'channel': 'cn.1', 'url': 'http://logo-old.png', 'in_use': false},
          {'channel': 'cn.1', 'url': 'http://logo-use.png', 'in_use': true},
        ]),
        countries: jsonEncode([
          {'code': 'CN', 'name': 'China'},
        ]),
        blocklist: jsonEncode([
          {'channel': 'cn.3', 'reason': 'dmca'},
        ]),
      );

      final bundle = decodeIptvBundle(payload);

      expect(bundle.channels.length, 1);
      final s = bundle.channels.single;
      expect(s.uuid, 'iptv:cn.1');
      expect(s.name, 'CCTV-1'); // 画质后缀被剥离
      expect(s.streamUrl, 'http://high.m3u8'); // 取最高画质
      expect(s.logoUrl, 'http://logo-use.png'); // in_use 优先
      expect(s.countryCode, 'CN');
      expect(s.country, 'China');
      expect(s.tags, ['General']);
      expect(s.homepage, 'https://cctv.com');

      final meta = bundle.meta['iptv:cn.1']!;
      expect(meta.referrer, 'https://ref');
      expect(meta.userAgent, 'UA/1');
      expect(meta.quality, '1080p');
      expect(meta.geoBlocked, true);
    });

    test('频道名为空时回退流标题；无流的频道丢弃', () {
      final payload = IptvRawPayload(
        channels: jsonEncode([
          {'id': 'x.1', 'name': '', 'country': 'US'},
          {'id': 'x.2', 'name': 'Empty', 'country': 'US'},
        ]),
        streams: jsonEncode([
          {'channel': 'x.1', 'url': 'http://a.m3u8', 'title': 'News Channel (HD)'},
        ]),
      );
      final bundle = decodeIptvBundle(payload);
      expect(bundle.channels.single.name, 'News Channel');
      expect(bundle.channels.single.uuid, 'iptv:x.1');
    });

    test('qualityValue 解析', () {
      expect(qualityValue('1080p'), 1080);
      expect(qualityValue('720P'), 720);
      expect(qualityValue('sd'), 480);
      expect(qualityValue('HD'), 720);
      expect(qualityValue(''), 0);
    });
  });

  group('IptvRepositoryImpl SWR 缓存与过滤', () {
    late Directory hiveDir;
    late Box<String> box;
    late _PathFakeAdapter adapter;
    late IptvRepositoryImpl repo;
    var boxSeq = 0;

    setUp(() async {
      hiveDir = await Directory.systemTemp.createTemp('iradio_iptv_test');
      Hive.init(hiveDir.path);
      box = await Hive.openBox<String>('iptv_cache_${boxSeq++}');
      adapter = _PathFakeAdapter();
      adapter.responses['channels.json'] = [
        {'id': 'cn.a', 'name': 'Alpha', 'country': 'CN', 'categories': ['News']},
        {'id': 'us.b', 'name': 'Beta', 'country': 'US', 'categories': ['Music']},
      ];
      adapter.responses['streams.json'] = [
        {'channel': 'cn.a', 'url': 'http://a.m3u8', 'quality': '720p', 'referrer': 'https://r'},
        {'channel': 'us.b', 'url': 'http://b.m3u8'},
      ];
      adapter.responses['countries.json'] = [
        {'code': 'CN', 'name': 'China'},
        {'code': 'US', 'name': 'United States'},
      ];
      repo = IptvRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
        BrowseCacheDs(box),
        enableLogos: false,
      );
    });

    tearDown(() async {
      await box.deleteFromDisk();
      await Hive.close();
      if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
    });

    test('首次加载全量 join；二次进入缓存秒出（不转圈）', () async {
      final r1 = await repo.channels();
      expect(r1.map((s) => s.name), ['Alpha', 'Beta']);

      // 网络数据变化：新 repo 实例应秒出缓存旧数据。
      adapter.responses['channels.json'] = [
        {'id': 'cn.c', 'name': 'Gamma', 'country': 'CN'},
      ];
      adapter.responses['streams.json'] = [
        {'channel': 'cn.c', 'url': 'http://c.m3u8'},
      ];
      final repo2 = IptvRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
        BrowseCacheDs(box),
        enableLogos: false,
      );
      final r2 = await repo2.channels();
      expect(r2.map((s) => s.name), ['Alpha', 'Beta']);
    });

    test('streamMeta 缓存往返（referrer 持久化）', () async {
      await repo.channels();
      final repo2 = IptvRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
        BrowseCacheDs(box),
        enableLogos: false,
      );
      final meta = await repo2.streamMeta('iptv:cn.a');
      expect(meta, isNotNull);
      expect(meta!.referrer, 'https://r');
      expect(meta.quality, '720p');
    });

    test('按国家/分组/关键字内存过滤', () async {
      await repo.channels();
      final cn = await repo.channels(countryCode: 'cn'); // 大小写不敏感
      expect(cn.map((s) => s.name), ['Alpha']);
      final music = await repo.channels(group: 'Music');
      expect(music.map((s) => s.name), ['Beta']);
      final kw = await repo.channels(keyword: 'alp');
      expect(kw.map((s) => s.name), ['Alpha']);
    });

    test('countries/groups 从 join 结果内存聚合（按数量降序）', () async {
      final countries = await repo.countries();
      expect(countries.map((c) => c.isoCode), containsAll(['CN', 'US']));
      expect(countries.first.stationCount, 1);

      final groups = await repo.groups();
      expect(groups.map((g) => g.name), containsAll(['News', 'Music']));
    });

    test('无缓存且网络失败时抛异常', () async {
      adapter.responses.clear();
      await expectLater(repo.channels(), throwsA(anything));
    });
  });
}
