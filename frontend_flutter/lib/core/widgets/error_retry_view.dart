import 'package:flutter/material.dart';

import '../error/app_exception.dart';
import '../../l10n_helper.dart';

/// 加载失败 + 重试视图。
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final message = switch (error) {
      AppException(type: AppErrorType.network) => l10n.errorNetwork,
      AppException(type: AppErrorType.timeout) => l10n.errorNetwork,
      _ => l10n.errorGeneric,
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 44, color: scheme.primary.withValues(alpha: 0.55)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
