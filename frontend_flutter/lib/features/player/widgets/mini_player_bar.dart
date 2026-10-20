import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_navigator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/station_logo.dart';
import '../../../l10n_helper.dart';
import '../player_controller.dart';

/// 底部迷你播放条：黑玻璃底 + 霓虹顶描边。
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final station = player.station;
    if (station == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    String status;
    Color statusColor;
    if (player.loading) {
      status = l10n.connecting;
      statusColor = scheme.primary;
    } else if (player.playing) {
      status = player.icyTitle ?? l10n.nowPlaying;
      statusColor = scheme.primary;
    } else if (player.errorType != null) {
      status = l10n.playbackError;
      statusColor = scheme.error;
    } else {
      status = l10n.paused;
      statusColor = scheme.onSurfaceVariant;
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          border: Border(
            top: BorderSide(color: scheme.primary.withValues(alpha: 0.4)),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => AppNavigator.openPlayer(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 2, 4),
            child: Row(
              children: [
                StationLogo(
                  logoUrl: station.logoUrl,
                  name: station.name,
                  size: 32,
                  borderRadius: 8,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          if (player.playing) ...[
                            Icon(
                              Icons.graphic_eq_rounded,
                              size: 13,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTheme.fontMono,
                                fontSize: 11,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (player.loading)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: scheme.primary,
                      ),
                    ),
                  )
                else
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        ref.read(playerProvider.notifier).togglePlayPause(),
                    icon: Icon(
                      player.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 28,
                      color: player.playing ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ref.read(playerProvider.notifier).stop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
