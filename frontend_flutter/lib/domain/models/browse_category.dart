/// 浏览分类（国家 / 标签 / 语言共用的展示模型）。
class BrowseCategory {
  const BrowseCategory({
    required this.name,
    this.stationCount = 0,
    this.isoCode,
  });

  final String name;
  final int stationCount;

  /// 仅国家有：ISO 3166-1 alpha-2 代码。
  final String? isoCode;
}
