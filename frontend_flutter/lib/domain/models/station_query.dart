/// 电台搜索参数对象（覆盖 radio-browser /json/stations/search 的常用参数）。
class StationQuery {
  const StationQuery({
    this.name,
    this.countryCode,
    this.tag,
    this.language,
    this.order,
    this.reverse = false,
    this.minBitrate,
    this.limit = 50,
    this.offset = 0,
  });

  static const String orderByClicks = 'clickcount';
  static const String orderByVotes = 'votes';
  static const String orderByBitrate = 'bitrate';
  static const String orderByName = 'name';

  final String? name;
  final String? countryCode;
  final String? tag;
  final String? language;
  final String? order;
  final bool reverse;
  final int? minBitrate;
  final int limit;
  final int offset;

  StationQuery copyWith({
    String? name,
    String? countryCode,
    Object? tag = _sentinel,
    Object? language = _sentinel,
    String? order,
    bool? reverse,
    int? minBitrate,
    int? limit,
    int? offset,
  }) {
    return StationQuery(
      name: name ?? this.name,
      countryCode: countryCode ?? this.countryCode,
      tag: tag == _sentinel ? this.tag : tag as String?,
      language: language == _sentinel ? this.language : language as String?,
      order: order ?? this.order,
      reverse: reverse ?? this.reverse,
      minBitrate: minBitrate ?? this.minBitrate,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }

  Map<String, dynamic> toQueryParameters() {
    return {
      if (name != null && name!.isNotEmpty) 'name': name,
      if (countryCode != null && countryCode!.isNotEmpty)
        'countrycode': countryCode,
      if (tag != null && tag!.isNotEmpty) 'tag': tag,
      if (language != null && language!.isNotEmpty) 'language': language,
      if (order != null && order!.isNotEmpty) 'order': order,
      if (reverse) 'reverse': 'true',
      if (minBitrate != null && minBitrate! > 0) 'minBitrate': '$minBitrate',
      'hidebroken': 'true',
      'limit': '$limit',
      'offset': '$offset',
    };
  }

  static const Object _sentinel = Object();
}
