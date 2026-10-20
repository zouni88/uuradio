import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/station.dart';
import '../../favorites/favorites_controller.dart';
import '../player_controller.dart';
import '../signal_controller.dart';

/// 竖屏播放页与横屏调谐台共用的组件：信号 HUD / 播放键 / 控制键 / 收藏键。

/// 信号 HUD：SIGNAL（dBm/等级）/ NET（网络类型）/ LINK（流链路状态）三块芯片。
class SignalHud extends ConsumerWidget {
  const SignalHud({super.key, required this.player});

  final PlayerUiState player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final signal = ref.watch(signalProvider);

    final (String linkLabel, Color linkColor) = player.errorType != null
        ? ('LOST', scheme.error)
        : player.loading
            ? ('DIAL', scheme.secondary)
            : player.buffering
                ? ('SYNC', scheme.secondary)
                : player.playing
                    ? ('LOCK', scheme.primary)
                    : ('IDLE', scheme.onSurfaceVariant);

    final netLabel = switch (signal.type) {
      NetType.wifi => 'WIFI',
      NetType.cell => 'CELL',
      NetType.none => 'OFF',
    };
    final netColor =
        signal.available ? scheme.primary : scheme.onSurfaceVariant;

    final signalValue = signal.available
        ? signal.rssi != null
            ? '${signal.rssi} dBm'
            : 'LVL ${signal.level < 0 ? 0 : signal.level}'
        : 'NO SIG';
    final signalColor =
        signal.available ? scheme.primary : scheme.onSurfaceVariant;
    final bars = signal.available
        ? (signal.level < 0 ? 0 : (signal.level > 4 ? 4 : signal.level))
        : 0;

    return Row(
      children: [
        Expanded(
          child: HudChip(
            label: 'SIGNAL',
            value: signalValue,
            valueColor: signalColor,
            bars: bars,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: HudChip(
            label: 'NET',
            value: netLabel,
            valueColor: netColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: HudChip(
            label: 'LINK',
            value: linkLabel,
            valueColor: linkColor,
          ),
        ),
      ],
    );
  }
}

class HudChip extends StatelessWidget {
  const HudChip({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
    this.bars,
  });

  final String label;
  final String value;
  final Color valueColor;

  /// 信号格数（0..4），null = 不显示格条。
  final int? bars;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontMono,
              fontSize: 9,
              letterSpacing: 2.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (bars != null) ...[
                _SignalBars(lit: bars!),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontMono,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 四格信号条。
class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.lit});

  final int lit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            width: 3,
            height: 4.0 + i * 2.5,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: i < lit ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(1),
              boxShadow: i < lit
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
      ],
    );
  }
}

/// 收藏按钮。
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.station});

  final Station? station;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final current = station;
    if (current == null) return const SizedBox.shrink();
    final isFavorite = ref.watch(
      favoritesProvider.select((f) => f.any((s) => s.uuid == current.uuid)),
    );
    return IconButton(
      icon: Icon(
        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: 26,
      ),
      color: isFavorite ? scheme.primary : scheme.onSurfaceVariant,
      onPressed: () => ref.read(favoritesProvider.notifier).toggle(current),
    );
  }
}

/// 小控制键（睡眠定时 / 停止等）。
class ControlIcon extends StatelessWidget {
  const ControlIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.size = 26,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: size),
      color: active ? scheme.primary : scheme.onSurfaceVariant,
    );
  }
}

/// 霓虹发光播放键。
class PlayButton extends ConsumerWidget {
  const PlayButton({
    super.key,
    required this.player,
    required this.station,
    this.size = 84,
  });

  final PlayerUiState player;
  final Station station;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.55),
              blurRadius: size * 0.4,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            shape: const CircleBorder(),
            side: BorderSide(
              color: scheme.onPrimary.withValues(alpha: 0.6),
              width: 1.2,
            ),
          ),
          onPressed: player.loading
              ? null
              : () => ref.read(playerProvider.notifier).togglePlayPause(),
          child: player.loading
              ? SizedBox(
                  width: size * 0.36,
                  height: size * 0.36,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: scheme.onPrimary,
                  ),
                )
              : Icon(
                  player.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: size * 0.52,
                ),
        ),
      ),
    );
  }
}

/// 播放状态文本（错误文案映射）。
String? playbackErrorText(PlayerUiState player, String Function() l10nError) {
  return switch (player.errorType) {
    AppErrorType.network => l10nError(),
    AppErrorType.timeout => l10nError(),
    AppErrorType.server ||
    AppErrorType.unknown ||
    null =>
      player.errorType == null ? null : l10nError(),
  };
}
