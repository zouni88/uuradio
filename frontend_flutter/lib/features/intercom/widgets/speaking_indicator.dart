import 'package:flutter/material.dart';

import '../../../core/widgets/neon.dart';
import '../../../domain/models/intercom_models.dart';

/// 讲话状态指示条：TX 红 / RX 青，静态辉光（不做持续动画，省电）。
class SpeakingIndicator extends StatelessWidget {
  const SpeakingIndicator({
    super.key,
    required this.ptt,
    required this.text,
  });

  final PttState ptt;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = ptt == PttState.talking || ptt == PttState.listening;
    if (!active) return const SizedBox.shrink();
    final tone = ptt == PttState.talking ? scheme.error : scheme.primary;
    return NeonBox(
      color: tone,
      glow: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ptt == PttState.talking
                ? Icons.circle
                : Icons.sensors_rounded,
            size: 12,
            color: tone,
          ),
          const SizedBox(width: 8),
          NeonText(
            text,
            color: tone,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.5,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
