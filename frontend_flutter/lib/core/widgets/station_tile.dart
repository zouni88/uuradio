import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/station_logo.dart';
import '../../domain/models/station.dart';
import '../../features/favorites/favorites_controller.dart';
import '../../l10n_helper.dart';

/// 电台行：霓虹面板卡片（logo、名称、国家/码率、收藏心形）。
class StationTile extends ConsumerWidget {
  const StationTile({
    super.key,
    required this.station,
    required this.onTap,
    this.showFavorite = true,
  });

  final Station station;
  final VoidCallback onTap;
  final bool showFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final isFavorite =
        ref.watch(favoritesProvider.select((f) => f.any((s) => s.uuid == station.uuid)));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.65),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                StationLogo(logoUrl: station.logoUrl, name: station.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        stationSubtitle(
                          station.countryCode,
                          station.country,
                          station.bitrate,
                          station.codec,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontMono,
                          color: scheme.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showFavorite)
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 22,
                    ),
                    color: isFavorite ? scheme.primary : scheme.onSurfaceVariant,
                    tooltip: isFavorite ? l10n.favoriteRemove : l10n.favoriteAdd,
                    onPressed: () =>
                        ref.read(favoritesProvider.notifier).toggle(station),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
