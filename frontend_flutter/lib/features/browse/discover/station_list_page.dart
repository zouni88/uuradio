import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_navigator.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/station_tile.dart';
import '../../../domain/models/station.dart';
import '../../../domain/models/station_query.dart';
import '../../../l10n_helper.dart';
import '../../player/player_controller.dart';
import 'station_list_controller.dart';

/// 通用分页电台列表页（榜单/国家/标签/语言/搜索结果共用）。
class StationListPage extends ConsumerStatefulWidget {
  const StationListPage({super.key, required this.title, required this.query});

  final String title;
  final StationQuery query;

  @override
  ConsumerState<StationListPage> createState() => _StationListPageState();
}

class _StationListPageState extends ConsumerState<StationListPage> {
  late final StationListProvider _provider =
      makeStationListProvider(widget.query);

  void _onScroll(ScrollMetrics metrics) {
    if (metrics.pixels >= metrics.maxScrollExtent - 400) {
      ref.read(_provider.notifier).loadMore();
    }
  }

  void _openPlayer(Station station, List<Station> band) {
    ref.playFromBand(station, band);
    AppNavigator.openPlayer(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(_provider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axisDirection == AxisDirection.down) {
            _onScroll(n.metrics);
          }
          return false;
        },
        child: async.when(
          loading: () => ListView(
              children: [StationListSkeleton.fill(context)]),
          error: (error, _) =>
              ErrorRetryView(error: error, onRetry: () => ref.invalidate(_provider)),
          data: (stations) {
            if (stations.isEmpty) {
              return Center(
                child: Text(
                  l10n.noResults,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(top: 4, bottom: 24),
              itemCount: stations.length + 1,
              itemBuilder: (context, index) {
                if (index == stations.length) {
                  // 加载更多：行骨架占位，不用转圈。
                  return const StationTileSkeleton();
                }
                final station = stations[index];
                return StationTile(
                  station: station,
                  onTap: () => _openPlayer(station, stations),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
