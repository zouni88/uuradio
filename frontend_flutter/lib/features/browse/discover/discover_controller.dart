import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../domain/models/browse_category.dart';
import '../../../domain/models/station.dart';
import '../../../domain/models/station_query.dart';
import 'station_list_controller.dart';

/// 设备所在国家/地区码（ISO 3166-1 alpha-2，可能为空）。
String deviceCountryCode() =>
    PlatformDispatcher.instance.locale.countryCode ?? '';

/// 选中国家码为空时跟随设备。
String effectiveCountryCode(String selected) =>
    selected.isEmpty ? deviceCountryCode() : selected;

/// 发现页选中国家（空 = 跟随设备国家）。持久化，启动时异步回填。
class SelectedCountryController extends Notifier<String> {
  @override
  String build() {
    ref.watch(settingsDsProvider).loadSelectedCountry().then((code) {
      if (ref.mounted && state.isEmpty && code.isNotEmpty) state = code;
    }).catchError((_) {});
    return '';
  }

  Future<void> select(String code) async {
    state = code;
    await ref.read(settingsDsProvider).saveSelectedCountry(code);
  }
}

final selectedCountryProvider =
    NotifierProvider<SelectedCountryController, String>(
        SelectedCountryController.new);

/// 国家选择页使用频次（ISO 码 -> 选择次数），用于「常用国家」置顶。
class CountryUsageController extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() {
    ref.watch(settingsDsProvider).loadCountryUsage().then((usage) {
      if (ref.mounted && state.isEmpty && usage.isNotEmpty) state = usage;
    }).catchError((_) {});
    return const {};
  }

  void record(String code) {
    if (code.isEmpty) return;
    state = {...state, code: (state[code] ?? 0) + 1};
    ref.read(settingsDsProvider).recordCountryUsage(code).catchError((_) {});
  }
}

final countryUsageProvider =
    NotifierProvider<CountryUsageController, Map<String, int>>(
        CountryUsageController.new);

/// 发现页数据：热门榜单 + 分类列表。
/// 热门跟随选中国家（默认设备国家），取该区点击量 Top 20，无数据时回退全球榜。
final topClicksProvider = FutureProvider.autoDispose<List<Station>>(
  (ref) async {
    final repo = ref.watch(radioRepositoryProvider);
    final code = effectiveCountryCode(ref.watch(selectedCountryProvider));
    if (code.isNotEmpty) {
      try {
        final local = await repo.search(StationQuery(
          countryCode: code,
          order: StationQuery.orderByClicks,
          reverse: true,
          limit: 20,
        ));
        if (local.isNotEmpty) return local;
      } catch (_) {
        // 本国榜失败回退全球榜。
      }
    }
    return repo.topByClicks(limit: 20);
  },
);

/// 发现页选中国家的电台列表：选中国家变化时创建新列表 provider（旧实例 autoDispose）。
final countryStationsProvider = Provider.autoDispose<StationListProvider>(
  (ref) {
    final code = effectiveCountryCode(ref.watch(selectedCountryProvider));
    return makeStationListProvider(StationQuery(
      countryCode: code,
      order: StationQuery.orderByClicks,
      reverse: true,
    ));
  },
);

final topVotesProvider = FutureProvider.autoDispose<List<Station>>(
  (ref) => ref.watch(radioRepositoryProvider).topByVotes(limit: 20),
);

final countriesProvider = FutureProvider.autoDispose<List<BrowseCategory>>(
  (ref) => ref.watch(radioRepositoryProvider).countries(),
);

final tagsProvider = FutureProvider.autoDispose<List<BrowseCategory>>(
  (ref) => ref.watch(radioRepositoryProvider).tags(limit: 60),
);

final languagesProvider = FutureProvider.autoDispose<List<BrowseCategory>>(
  (ref) => ref.watch(radioRepositoryProvider).languages(),
);
