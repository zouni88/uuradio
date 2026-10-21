import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_navigator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/station_logo.dart';
import '../../../core/widgets/station_tile.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n_helper.dart';
import '../../../domain/models/browse_category.dart';
import '../../../domain/models/station.dart';
import '../../../domain/models/station_query.dart';
import '../../player/player_controller.dart';
import '../filters/category_picker_page.dart';
import 'discover_controller.dart';

/// 发现页：热门榜单横滑卡片 + 当前国家电台列表 + 分类入口。
class DiscoverPage extends ConsumerWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 固定顶栏：标题 + 右上角分类入口（国家/地区、标签、语言）。
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.tabDiscover,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _CategoryButton(
                    icon: Icons.public_rounded,
                    label: l10n.countries,
                    kind: CategoryKind.country,
                  ),
                  const SizedBox(width: 10),
                  _CategoryButton(
                    icon: Icons.local_offer_rounded,
                    label: l10n.tags,
                    kind: CategoryKind.tag,
                  ),
                  const SizedBox(width: 10),
                  _CategoryButton(
                    icon: Icons.language_rounded,
                    label: l10n.languages,
                    kind: CategoryKind.language,
                  ),
                ],
              ),
            ),
            // 固定区与滚动区的分隔。
            Divider(
              height: 1,
              thickness: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  _SectionHeader(title: l10n.sectionHot),
                  const SizedBox(height: 12),
                  _HotRail(async: ref.watch(topClicksProvider)),
                  const SizedBox(height: 24),
                  _CountrySection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 区块标题（霓虹竖标 + 文案，右侧可选操作，标题可点击选国家）。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onTap});

  final String title;
  final Widget? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 霓虹竖标
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.6),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: onTap == null
                ? Text(title, style: titleStyle)
                : InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: titleStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.expand_more_rounded,
                            size: 20,
                            color: scheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// 选中国家电台列表区块：标题显示国家名，点击标题切换国家。
class _CountrySection extends ConsumerWidget {
  const _CountrySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final code = effectiveCountryCode(ref.watch(selectedCountryProvider));
    // 国家名称从分类列表反查（缓存秒出），查不到显示代码。
    final countries =
        ref.watch(countriesProvider).value ?? const <BrowseCategory>[];
    var name = code;
    for (final c in countries) {
      if (c.isoCode == code) {
        name = c.name;
        break;
      }
    }
    final listProvider = ref.watch(countryStationsProvider);
    final async = ref.watch(listProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: name,
          onTap: () async {
            final picked = await AppNavigator.openCategoryPicker(
              context,
              kind: CategoryKind.country,
            );
            final iso = picked?.isoCode;
            if (iso == null || iso.isEmpty) return;
            ref.read(selectedCountryProvider.notifier).select(iso);
          },
          action: TextButton(
            onPressed: () => AppNavigator.openStationList(
              context,
              title: name,
              query: StationQuery(
                countryCode: code,
                order: StationQuery.orderByClicks,
                reverse: true,
              ),
            ),
            child: Text(l10n.viewAll),
          ),
        ),
        const SizedBox(height: 4),
        async.when(
          loading: () => StationListSkeleton.fill(context),
          error: (error, _) => ErrorRetryView(
            error: error,
            onRetry: () => ref.invalidate(listProvider),
          ),
          data: (stations) {
            if (stations.isEmpty) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Text(
                  l10n.noResults,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final station in stations)
                  StationTile(
                    station: station,
                    onTap: () {
                      ref.playFromBand(station, stations);
                      AppNavigator.openPlayer(context);
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// 热门电台横滑列表。
class _HotRail extends ConsumerWidget {
  const _HotRail({required this.async});

  final AsyncValue<List<Station>> async;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = topClicksProvider;
    return async.when(
      loading: () => const HotRailSkeleton(),
      error: (error, _) => ErrorRetryView(
        error: error,
        onRetry: () => ref.invalidate(provider),
      ),
      data: (stations) {
        final scheme = Theme.of(context).colorScheme;
        return SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: stations.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final station = stations[index];
              return _HotCard(
                station: station,
                index: index,
                band: stations,
                scheme: scheme,
              );
            },
          ),
        );
      },
    );
  }
}

class _HotCard extends ConsumerWidget {
  const _HotCard({
    required this.station,
    required this.index,
    required this.band,
    required this.scheme,
  });

  final Station station;
  final int index;
  final List<Station> band;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        ref.playFromBand(station, band);
        AppNavigator.openPlayer(context);
      },
      child: Stack(
        children: [
          Container(
            width: 132,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.9),
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.07),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.22),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: StationLogo(
                      logoUrl: station.logoUrl,
                      name: station.name,
                      size: 84,
                      borderRadius: 18,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  station.name.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stationSubtitleShort(station),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontMono,
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // 排名角标
          Positioned(
            top: 6,
            right: 8,
            child: Text(
              (index + 1).toString().padLeft(2, '0'),
              style: TextStyle(
                fontFamily: AppTheme.fontMono,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: scheme.primary.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分类入口按钮（顶栏右上角：国家/地区、标签、语言）。
class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.icon,
    required this.label,
    required this.kind,
  });

  final IconData icon;
  final String label;
  final CategoryKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final picked =
              await AppNavigator.openCategoryPicker(context, kind: kind);
          if (picked == null || !context.mounted) return;
          AppNavigator.openStationList(
            context,
            title: picked.name,
            query: _queryFor(kind, picked),
          );
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.9),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.06),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: scheme.primary),
        ),
      ),
    );
  }
}

/// 分类 → 查询参数。
StationQuery _queryFor(CategoryKind kind, BrowseCategory category) {
  return switch (kind) {
    CategoryKind.country => StationQuery(
        countryCode: category.isoCode ?? '',
        order: StationQuery.orderByClicks,
        reverse: true,
      ),
    CategoryKind.tag => StationQuery(
        tag: category.name,
        order: StationQuery.orderByClicks,
        reverse: true,
      ),
    CategoryKind.language => StationQuery(
        language: category.name,
        order: StationQuery.orderByClicks,
        reverse: true,
      ),
  };
}

String stationSubtitleShort(Station station) {
  final parts = <String>[
    if (station.country.isNotEmpty) station.country,
    if (station.bitrate > 0) '${station.bitrate} kbps',
  ];
  return parts.join(' · ');
}
