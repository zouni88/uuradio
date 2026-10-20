/// 纯展示的电台模型（与 API 字段解耦）。
class Station {
  const Station({
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

  /// 播放永远使用 url_resolved（已解析的最终地址）。
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

  Station copyWith({
    String? uuid,
    String? name,
    String? streamUrl,
    String? logoUrl,
    String? homepage,
    String? countryCode,
    String? country,
    List<String>? languages,
    List<String>? tags,
    String? codec,
    int? bitrate,
    int? clickCount,
    int? votes,
  }) {
    return Station(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      streamUrl: streamUrl ?? this.streamUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      homepage: homepage ?? this.homepage,
      countryCode: countryCode ?? this.countryCode,
      country: country ?? this.country,
      languages: languages ?? this.languages,
      tags: tags ?? this.tags,
      codec: codec ?? this.codec,
      bitrate: bitrate ?? this.bitrate,
      clickCount: clickCount ?? this.clickCount,
      votes: votes ?? this.votes,
    );
  }

  @override
  bool operator ==(Object other) => other is Station && other.uuid == uuid;

  @override
  int get hashCode => uuid.hashCode;
}
