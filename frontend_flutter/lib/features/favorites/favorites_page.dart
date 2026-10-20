import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_navigator.dart';
import '../../core/widgets/station_tile.dart';
import '../../l10n_helper.dart';
import '../history/history_controller.dart';
import '../player/player_controller.dart';
import 'favorites_controller.dart';

/// 收藏页：收藏 / 最近播放 两个分段。
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.tabFavorites),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, size: 22),
              tooltip: l10n.clearHistory,
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.clearHistory),
                    content: Text(l10n.clearHistoryConfirm),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(l10n.clear),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  ref.read(historyProvider.notifier).clear();
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            TabBar(
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: l10n.favoritesSegment),
                Tab(text: l10n.historySegment),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [_FavoritesTab(), _HistoryTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final favorites = ref.watch(favoritesProvider);
    if (favorites.isEmpty) {
      return _EmptyView(
        icon: Icons.favorite_border_rounded,
        message: l10n.emptyFavorites,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final station = favorites[index];
        return StationTile(
          station: station,
          onTap: () {
            ref.playFromBand(station, favorites);
            AppNavigator.openPlayer(context);
          },
        );
      },
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final history = ref.watch(historyProvider);
    if (history.isEmpty) {
      return _EmptyView(
        icon: Icons.history_rounded,
        message: l10n.emptyHistory,
      );
    }
    // 飞梭波段：整份最近播放列表。
    final band = [for (final h in history) h.station];
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final station = history[index].station;
        return StationTile(
          station: station,
          onTap: () {
            ref.playFromBand(station, band);
            AppNavigator.openPlayer(context);
          },
        );
      },
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.primary.withValues(alpha: 0.45)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}
