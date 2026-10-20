import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iradio/data/dto/station_dto.dart';
import 'package:iradio/domain/models/station.dart';
import 'package:iradio/domain/models/station_query.dart';
import 'package:iradio/features/settings/backup_service.dart';

void main() {
  test('StationDto 解析 API JSON 并映射到 domain', () {
    final dto = StationDto.fromJson({
      'stationuuid': 'uuid-1',
      'name': ' Radio Test ',
      'url': 'http://a',
      'url_resolved': 'https://a/resolved',
      'favicon': 'http://logo.png',
      'country': 'Germany',
      'countrycode': 'DE',
      'language': 'german, english',
      'tags': 'jazz, blues',
      'codec': 'MP3',
      'bitrate': '128', // API 偶发字符串数字
      'clickcount': 10,
      'votes': 5,
    });
    final s = dto.toDomain();
    expect(s.uuid, 'uuid-1');
    expect(s.streamUrl, 'https://a/resolved');
    expect(s.countryCode, 'DE');
    expect(s.languages, ['german', 'english']);
    expect(s.tags, ['jazz', 'blues']);
    expect(s.bitrate, 128);
  });

  test('StationDto 本地 JSON 直接往返（缓存/收藏真实路径）', () {
    const station = Station(
      uuid: 'u1',
      name: 'N1',
      streamUrl: 'https://s',
      logoUrl: 'https://l',
      homepage: 'https://h',
      countryCode: 'FR',
      country: 'France',
      tags: ['pop'],
      bitrate: 96,
      clickCount: 7,
    );
    final json = StationDto.fromDomain(station).toJson();
    // 缓存/收藏就是把 toJson 结果原样交给 fromJson，不允许丢字段。
    final restored = StationDto.fromJson(json).toDomain();
    expect(restored, station);
    expect(restored.logoUrl, 'https://l');
    expect(restored.streamUrl, 'https://s');
    expect(restored.clickCount, 7);
  });

  test('备份 JSON 解析（导出格式）', () {
    const station = Station(uuid: 'u9', name: 'X', streamUrl: 'https://x');
    final backup = jsonEncode({
      'app': 'iradio',
      'version': 1,
      'exportedAt': '2026-01-01T00:00:00Z',
      'stations': [
        {
          'uuid': station.uuid,
          'name': station.name,
          'streamUrl': station.streamUrl,
          'tags': ['a', 'b'],
        },
      ],
    });
    final list = BackupService.parseBackup(backup);
    expect(list.length, 1);
    expect(list.first.uuid, 'u9');
    expect(list.first.streamUrl, 'https://x');
    expect(list.first.tags, ['a', 'b']);
  });

  test('StationQuery 参数拼装', () {
    final params = const StationQuery(
      name: 'bbc',
      minBitrate: 128,
      order: StationQuery.orderByClicks,
      reverse: true,
      limit: 50,
      offset: 50,
    ).toQueryParameters();
    expect(params['name'], 'bbc');
    expect(params['minBitrate'], '128');
    expect(params['hidebroken'], 'true');
    expect(params['offset'], '50');
    expect(params.containsKey('tag'), isFalse);
  });
}
