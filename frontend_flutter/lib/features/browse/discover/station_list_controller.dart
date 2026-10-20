import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/error/app_exception.dart';
import '../../../data/providers.dart';
import '../../../domain/models/station.dart';
import '../../../domain/models/station_query.dart';

/// 通用分页电台列表控制器（榜单/搜索/分类共用）。
class StationListController extends AsyncNotifier<List<Station>> {
  StationListController(this.query);

  final StationQuery query;

  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  Future<List<Station>> build() async {
    try {
      return await ref.read(radioRepositoryProvider).search(query);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final current = state.value;
    if (current == null) return;
    _loadingMore = true;
    try {
      final next = await ref
          .read(radioRepositoryProvider)
          .search(query.copyWith(offset: current.length));
      final seen = current.map((s) => s.uuid).toSet();
      final fresh = next.where((s) => !seen.contains(s.uuid)).toList();
      _hasMore = next.length >= query.limit;
      if (fresh.isNotEmpty) {
        state = AsyncData([...current, ...fresh]);
      } else {
        _hasMore = false;
      }
    } catch (_) {
      // 加载更多失败不打断已展示的列表。
    } finally {
      _loadingMore = false;
    }
  }
}

typedef StationListProvider
    = AsyncNotifierProvider<StationListController, List<Station>>;

/// 每次导航创建全新 provider 实例，autoDispose 保证离开页面即释放。
StationListProvider makeStationListProvider(StationQuery query) {
  return AsyncNotifierProvider.autoDispose<StationListController,
      List<Station>>(() => StationListController(query));
}

/// 常用榜单分页大小。
const int kListPageSize = ApiConstants.pageSize;
