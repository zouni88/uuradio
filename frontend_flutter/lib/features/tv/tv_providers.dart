import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/browse_category.dart';
import '../../domain/models/station.dart';
import '../browse/discover/discover_controller.dart';

/// TV 页筛选条件（国家码/分组/关键字，空串 = 不限）。
class TvFilter {
  const TvFilter({
    this.countryCode = '',
    this.group = '',
    this.keyword = '',
  });

  final String countryCode;
  final String group;
  final String keyword;

  TvFilter copyWith({String? countryCode, String? group, String? keyword}) {
    return TvFilter(
      countryCode: countryCode ?? this.countryCode,
      group: group ?? this.group,
      keyword: keyword ?? this.keyword,
    );
  }

  bool matches(Station s) {
    if (countryCode.isNotEmpty && s.countryCode != countryCode) return false;
    if (group.isNotEmpty && !s.tags.contains(group)) return false;
    if (keyword.isNotEmpty &&
        !s.name.toLowerCase().contains(keyword.toLowerCase())) {
      return false;
    }
    return true;
  }
}

/// TV 页筛选状态（初值跟随发现页选中国家）。
class TvFilterController extends Notifier<TvFilter> {
  @override
  TvFilter build() {
    final code = effectiveCountryCode(ref.read(selectedCountryProvider));
    return TvFilter(countryCode: code.toUpperCase());
  }

  void selectCountry(String code) => state = state.copyWith(countryCode: code);

  void selectGroup(String group) => state = state.copyWith(group: group);

  void setKeyword(String keyword) => state = state.copyWith(keyword: keyword);
}

final tvFilterProvider =
    NotifierProvider<TvFilterController, TvFilter>(TvFilterController.new);

/// 全量频道（仓库内部 SWR 缓存秒出 + 后台静默刷新；页面内存过滤）。
final tvAllChannelsProvider = FutureProvider.autoDispose<List<Station>>(
  (ref) => ref.watch(iptvRepositoryProvider).channels(),
);

/// 有频道的国家（按频道数降序）。
final tvCountriesProvider = FutureProvider.autoDispose<List<BrowseCategory>>(
  (ref) => ref.watch(iptvRepositoryProvider).countries(),
);

/// 分组（iptv categories，按频道数降序）。
final tvGroupsProvider = FutureProvider.autoDispose<List<BrowseCategory>>(
  (ref) => ref.watch(iptvRepositoryProvider).groups(),
);

/// 发现页横滑区块用：选中国家前 12 频道，无数据回退全球。
final tvFeaturedProvider = FutureProvider.autoDispose<List<Station>>(
  (ref) async {
    final repo = ref.watch(iptvRepositoryProvider);
    final code =
        effectiveCountryCode(ref.watch(selectedCountryProvider)).toUpperCase();
    if (code.isNotEmpty) {
      try {
        final local = await repo.channels(countryCode: code);
        if (local.isNotEmpty) return local.take(12).toList();
      } catch (_) {
        // 本国无数据/失败回退全球。
      }
    }
    final all = await repo.channels();
    return all.take(12).toList();
  },
);
