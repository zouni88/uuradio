import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n_helper.dart';
import '../sleep_timer_controller.dart';

/// 睡眠定时器底部弹窗：15/30/60/90 分钟预设 + 取消。
Future<void> showSleepTimerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const SleepTimerSheet(),
  );
}

class SleepTimerSheet extends ConsumerWidget {
  const SleepTimerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final remaining = ref.watch(sleepTimerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Text(
                    l10n.sleepTimer,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (remaining != null)
                    Text(
                      _format(remaining),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            for (final minutes in const [15, 30, 60, 90])
              ListTile(
                leading: const Icon(Icons.schedule_rounded, size: 20),
                title: Text(l10n.sleepMinutesOption(minutes)),
                onTap: () {
                  ref
                      .read(sleepTimerProvider.notifier)
                      .start(Duration(minutes: minutes));
                  Navigator.of(context).pop();
                },
              ),
            const Divider(height: 8),
            ListTile(
              leading: Icon(
                Icons.timer_off_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text(remaining == null ? l10n.sleepOff : l10n.cancel),
              enabled: remaining != null,
              onTap: () {
                ref.read(sleepTimerProvider.notifier).cancel();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
