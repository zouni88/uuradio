import 'dart:convert';

import '../../domain/models/station.dart';
import '../../domain/models/tv_stream_meta.dart';

/// compute 入参：iptv-org 各 JSON 的原始字符串（可选项失败时为 null）。
class IptvRawPayload {
  const IptvRawPayload({
    required this.channels,
    required this.streams,
    this.logos,
    this.countries,
    this.blocklist,
  });

  final String? channels;
  final String? streams;
  final String? logos;
  final String? countries;
  final String? blocklist;
}

/// 三表 join 结果：频道列表 + 按 uuid 索引的流附加信息。
class IptvBundle {
  const IptvBundle({required this.channels, required this.meta});

  final List<Station> channels;
  final Map<String, TvStreamMeta> meta;
}

/// uuid 前缀：隔离 radio-browser 命名空间，收藏/历史/波段不串台。
const String kIptvUuidPrefix = 'iptv:';

bool isIptvStation(Station s) => s.uuid.startsWith(kIptvUuidPrefix);

List<dynamic> _list(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded : const [];
  } catch (_) {
    return const [];
  }
}

String _str(Map<String, dynamic> j, String key) => j[key]?.toString() ?? '';

/// 画质字符串 -> 可比较数值（1080p=1080、hd=720、sd=480、空=0）。
int qualityValue(String quality) {
  final lower = quality.toLowerCase();
  final match = RegExp(r'(\d+)p').firstMatch(lower);
  if (match != null) return int.tryParse(match.group(1)!) ?? 0;
  if (lower.contains('fullhd') || lower.contains('fhd')) return 1080;
  if (lower.contains('hd')) return 720;
  if (lower.contains('sd')) return 480;
  return 0;
}

/// 去掉频道名/标题尾部的画质后缀，如 "CCTV-1 (720p)" -> "CCTV-1"。
String stripQualitySuffix(String name) {
  return name
      .replaceAll(RegExp(r'\s*\((\d+p|fhd|fullhd|hd|sd)\)\s*$',
          caseSensitive: false), '')
      .trim();
}

/// 在后台 isolate 解析并 join：
/// channels(元数据) × streams(地址) × logos(台标) × countries(译名) − blocklist。
/// 纯函数，便于单测；1 万+ 对象不能在主 isolate 解析。
IptvBundle decodeIptvBundle(IptvRawPayload payload) {
  // 国家 code -> 显示名。
  final countryNames = <String, String>{};
  for (final item in _list(payload.countries)) {
    if (item is! Map<String, dynamic>) continue;
    final code = _str(item, 'code').toUpperCase();
    if (code.isEmpty) continue;
    countryNames[code] = _str(item, 'name');
  }

  // 黑名单频道（dmca/nsfw 兜底）。
  final blocked = <String>{};
  for (final item in _list(payload.blocklist)) {
    if (item is! Map<String, dynamic>) continue;
    final id = _str(item, 'channel');
    if (id.isNotEmpty) blocked.add(id);
  }

  // 频道元数据（过滤 nsfw / 黑名单 / 空 id）。
  final channelInfo = <String, Map<String, dynamic>>{};
  for (final item in _list(payload.channels)) {
    if (item is! Map<String, dynamic>) continue;
    final id = _str(item, 'id');
    if (id.isEmpty) continue;
    if (item['is_nsfw'] == true) continue;
    if (blocked.contains(id)) continue;
    channelInfo[id] = item;
  }

  // 每个频道取画质最高的一条流；channel 为空或无元数据的孤儿流丢弃。
  final bestStream = <String, Map<String, dynamic>>{};
  for (final item in _list(payload.streams)) {
    if (item is! Map<String, dynamic>) continue;
    final channel = _str(item, 'channel');
    final url = _str(item, 'url');
    if (channel.isEmpty || url.isEmpty) continue;
    if (!channelInfo.containsKey(channel)) continue;
    final current = bestStream[channel];
    if (current == null ||
        qualityValue(_str(item, 'quality')) >
            qualityValue(_str(current, 'quality'))) {
      bestStream[channel] = item;
    }
  }

  // 台标：in_use 优先，其余首条兜底。
  final logoUrl = <String, String>{};
  final logoInUse = <String>{};
  for (final item in _list(payload.logos)) {
    if (item is! Map<String, dynamic>) continue;
    final channel = _str(item, 'channel');
    final url = _str(item, 'url');
    if (channel.isEmpty || url.isEmpty) continue;
    final inUse = item['in_use'] == true;
    if (!logoUrl.containsKey(channel) || (inUse && !logoInUse.contains(channel))) {
      logoUrl[channel] = url;
      if (inUse) logoInUse.add(channel);
    }
  }

  final channels = <Station>[];
  final meta = <String, TvStreamMeta>{};
  for (final entry in channelInfo.entries) {
    final stream = bestStream[entry.key];
    if (stream == null) continue; // 无流地址的频道不可播，丢弃。
    final j = entry.value;
    final code = _str(j, 'country').toUpperCase();
    var name = stripQualitySuffix(_str(j, 'name'));
    if (name.isEmpty) name = stripQualitySuffix(_str(stream, 'title'));
    if (name.isEmpty) continue;
    final uuid = '$kIptvUuidPrefix${entry.key}';
    channels.add(Station(
      uuid: uuid,
      name: name,
      streamUrl: _str(stream, 'url'),
      logoUrl: logoUrl[entry.key] ?? '',
      homepage: _str(j, 'website'),
      countryCode: code,
      country: countryNames[code] ?? '',
      tags: (_listNull(j['categories']) ?? const []),
      codec: '',
      bitrate: 0,
      clickCount: 0,
      votes: 0,
    ));
    meta[uuid] = TvStreamMeta(
      userAgent: _optStr(stream, 'user_agent'),
      referrer: _optStr(stream, 'referrer'),
      labels: _listNull(stream['labels']) ?? const [],
      quality: _str(stream, 'quality'),
    );
  }

  channels.sort((a, b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return IptvBundle(channels: channels, meta: meta);
}

String? _optStr(Map<String, dynamic> j, String key) {
  final v = _str(j, key);
  return v.isEmpty ? null : v;
}

/// JSON 对象内的字符串数组字段。
List<String>? _listNull(Object? raw) {
  if (raw is List) {
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return null;
}
