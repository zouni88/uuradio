import '../../../domain/models/browse_category.dart';

/// countries / tags / languages 接口共用的分类 DTO。
class CategoryDto {
  const CategoryDto({
    required this.name,
    this.stationCount = 0,
    this.isoCode,
  });

  final String name;
  final int stationCount;

  /// 仅国家列表有。
  final String? isoCode;

  factory CategoryDto.fromJson(Map<String, dynamic> json) {
    return CategoryDto(
      name: json['name'] as String? ?? '',
      stationCount: StationDtoIntHelper.asInt(json['stationcount']),
      isoCode: json['iso_3166_1'] as String?,
    );
  }

  factory CategoryDto.fromDomain(BrowseCategory category) {
    return CategoryDto(
      name: category.name,
      stationCount: category.stationCount,
      isoCode: category.isoCode,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'stationcount': stationCount,
        if (isoCode != null) 'iso_3166_1': isoCode,
      };

  BrowseCategory toDomain() =>
      BrowseCategory(name: name, stationCount: stationCount, isoCode: isoCode);
}

class StationDtoIntHelper {
  static int asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
