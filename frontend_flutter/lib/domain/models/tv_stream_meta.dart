/// IPTV 流旁路元信息（iptv-org streams.json 的附加字段）。
/// Station 装不下这些字段，也不该硬塞——播放时按 uuid 旁路查询。
class TvStreamMeta {
  const TvStreamMeta({
    this.userAgent,
    this.referrer,
    this.labels = const [],
    this.quality = '',
  });

  final String? userAgent;
  final String? referrer;
  final List<String> labels;

  /// 画质标记（如 1080p / 720p）。
  final String quality;

  /// 社区源可能标注 Geo-blocked（地区受限）。
  bool get geoBlocked =>
      labels.any((l) => l.toLowerCase().contains('geo-blocked'));

  Map<String, dynamic> toJson() => {
        if (userAgent != null && userAgent!.isNotEmpty) 'ua': userAgent,
        if (referrer != null && referrer!.isNotEmpty) 'ref': referrer,
        if (labels.isNotEmpty) 'labels': labels,
        if (quality.isNotEmpty) 'q': quality,
      };

  factory TvStreamMeta.fromJson(Map<String, dynamic> json) {
    return TvStreamMeta(
      userAgent: json['ua'] as String?,
      referrer: json['ref'] as String?,
      labels: (json['labels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      quality: json['q'] as String? ?? '',
    );
  }
}
