import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_navigator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_retry_view.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/station_tile.dart';
import '../../data/providers.dart';
import '../../domain/models/browse_category.dart';
import '../../l10n_helper.dart';
import 'tv_player_page.dart';
import 'tv_providers.dart';

/// 电视直播 Tab：国家/分组筛选 + 关键字 + 频道列表（复用 StationTile）。
class TvPage extends ConsumerStatefulWidget {
  const TvPage({super.key});

  @override
  ConsumerState<TvPage> createState() => _TvPageState();
}

class _TvPageState extends ConsumerState<TvPage> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      await ref.read(iptvRepositoryProvider).refresh();
    } catch (_) {
      // 刷新失败仍失效重建，走缓存秒出/错误态。
    }
    if (!mounted) return;
    ref.invalidate(tvAllChannelsProvider);
    ref.invalidate(tvCountriesProvider);
    ref.invalidate(tvGroupsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final filter = ref.watch(tvFilterProvider);
    final channels = ref.watch(tvAllChannelsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.tvTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: l10n.retry,
                    onPressed: () => _refresh(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                style: TextStyle(
                  fontFamily: AppTheme.fontMono,
                  fontSize: 13,
                  color: scheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: l10n.tvSearchHint,
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: filter.keyword.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () {
                            _search.clear();
                            ref
                                .read(tvFilterProvider.notifier)
                                .setKeyword('');
                          },
                        ),
                ),
                onChanged: (v) =>
                    ref.read(tvFilterProvider.notifier).setKeyword(v.trim()),
              ),
            ),
            const SizedBox(height: 8),
            _ChipRow(
              items: ref
                  .watch(tvCountriesProvider)
                  .maybeWhen(
                    data: (list) => list,
                    orElse: () => const <BrowseCategory>[],
                  )
                  .take(60)
                  .toList(),
              allLabel: l10n.tvAllCountries,
              selected: filter.countryCode,
              onSelected: (code) =>
                  ref.read(tvFilterProvider.notifier).selectCountry(code),
            ),
            _ChipRow(
              items: ref
                  .watch(tvGroupsProvider)
                  .maybeWhen(
                    data: (list) => list,
                    orElse: () => const <BrowseCategory>[],
                  )
                  .take(40)
                  .toList(),
              allLabel: l10n.tvAllGroups,
              selected: filter.group,
              onSelected: (name) =>
                  ref.read(tvFilterProvider.notifier).selectGroup(name),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: channels.when(
                  loading: () => ListView(
                    children: [StationListSkeleton.fill(context)]),
                  error: (error, _) => ListView(
                    children: [
                      ErrorRetryView(
                        error: error,
                        onRetry: () {
                          ref.invalidate(tvAllChannelsProvider);
                          ref.invalidate(tvCountriesProvider);
                          ref.invalidate(tvGroupsProvider);
                        },
                      ),
                    ],
                  ),
                  data: (all) {
                    final list =
                        all.where(filter.matches).toList(growable: false);
                    if (list.isEmpty) {
                      return ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              l10n.tvEmpty,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 24),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final channel = list[index];
                        return StationTile(
                          station: channel,
                          onTap: () => AppNavigator.push(
                            context,
                            TvPlayerPage(channel: channel),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 横向筛选 chips（"全部" + 各分类，带频道数）。
class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.items,
    required this.allLabel,
    required this.selected,
    required this.onSelected,
  });

  final List<BrowseCategory> items;
  final String allLabel;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox(height: 4);
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildChip(
              scheme: scheme,
              label: allLabel,
              active: selected.isEmpty,
              onTap: () => onSelected(''),
            );
          }
          final item = items[index - 1];
          final code = item.isoCode ?? item.name;
          final active = selected == code;
          return _buildChip(
            scheme: scheme,
            label: item.isoCode == null
                ? '${item.name} · ${item.stationCount}'
                : item.name,
            active: active,
            onTap: () => onSelected(active ? '' : code),
          );
        },
      ),
    );
  }

  Widget _buildChip({
    required ColorScheme scheme,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
    );
  }
}
