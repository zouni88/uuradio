import '../../domain/models/station.dart';

/// 电台 DTO：兼容 API JSON（snake_case）与本地 JSON（camelCase）两种形态。
/// 播放永远使用 url_resolved（已解析的最终地址）。
class StationDto {
  const StationDto({
    required this.uuid,
    required this.name,
    required this.streamUrl,
    this.logoUrl = '',
    this.homepage = '',
    this.countryCode = '',
    this.country = '',
    this.languages = const [],
    this.tags = const [],
    this.codec = '',
    this.bitrate = 0,
    this.clickCount = 0,
    this.votes = 0,
  });

  final String uuid;
  final String name;
  final String streamUrl;
  final String logoUrl;
  final String homepage;
  final String countryCode;
  final String country;
  final List<String> languages;
  final List<String> tags;
  final String codec;
  final int bitrate;
  final int clickCount;
  final int votes;

  /// API 偶发字符串数字（如 bitrate: '128'），统一容错解析。
  factory StationDto.fromJson(Map<String, dynamic> json) {
    String s(Object? v) => v?.toString() ?? '';
    int i(Object? v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    String pick(Object? a, Object? b) {
      final sa = s(a);
      return sa.isNotEmpty ? sa : s(b);
    }

    /// API 用逗号分隔字符串（language/tags），本地存储用 List。
    List<String> list(Object? apiField, Object? localField) {
      final raw = _present(apiField) ? apiField : localField;
      if (raw is List) {
        return raw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (raw is String) {
        return raw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return const [];
    }

    int pickInt(Object? a, Object? b) => _present(a) ? i(a) : i(b);

    return StationDto(
      uuid: pick(json['stationuuid'], json['uuid']),
      name: s(json['name']).trim(),
      streamUrl: pick(pick(json['url_resolved'], json['streamUrl']), json['url']),
      logoUrl: pick(json['favicon'], json['logoUrl']),
      homepage: s(json['homepage']),
      countryCode: pick(json['countrycode'], json['countryCode']).toUpperCase(),
      country: s(json['country']),
      languages: list(json['language'], json['languages']),
      tags: list(json['tags'], json['tags']),
      codec: s(json['codec']),
      bitrate: i(json['bitrate']),
      clickCount: pickInt(json['clickcount'], json['clickCount']),
      votes: i(json['votes']),
    );
  }

  static bool _present(Object? v) => v != null && !(v is String && v.isEmpty);

  factory StationDto.fromDomain(Station s) {
    return StationDto(
      uuid: s.uuid,
      name: s.name,
      streamUrl: s.streamUrl,
      logoUrl: s.logoUrl,
      homepage: s.homepage,
      countryCode: s.countryCode,
      country: s.country,
      languages: s.languages,
      tags: s.tags,
      codec: s.codec,
      bitrate: s.bitrate,
      clickCount: s.clickCount,
      votes: s.votes,
    );
  }

  /// 本地存储形态（camelCase，字段无损往返）。
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'name': name,
      'streamUrl': streamUrl,
      'logoUrl': logoUrl,
      'homepage': homepage,
      'countryCode': countryCode,
      'country': country,
      'languages': languages,
      'tags': tags,
      'codec': codec,
      'bitrate': bitrate,
      'clickCount': clickCount,
      'votes': votes,
    };
  }

  Station toDomain() {
    return Station(
      uuid: uuid,
      name: name,
      streamUrl: streamUrl,
      logoUrl: logoUrl,
      homepage: homepage,
      countryCode: countryCode,
      country: country,
      languages: languages,
      tags: tags,
      codec: codec,
      bitrate: bitrate,
      clickCount: clickCount,
      votes: votes,
    );
  }
}
