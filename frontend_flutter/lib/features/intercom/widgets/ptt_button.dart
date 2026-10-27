import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/intercom_models.dart';

/// PTT 按住说话大按钮：onPointerDown/Up/Cancel 驱动话权申请与释放。
/// 颜色随状态变化用隐式动画（AnimatedContainer），无常驻逐帧重建。
class PttButton extends StatelessWidget {
  const PttButton({
    super.key,
    required this.ptt,
    required this.enabled,
    required this.label,
    required this.onDown,
    required this.onUp,
  });

  final PttState ptt;

  /// false = 麦克风不可用或未入房，按下无响应。
  final bool enabled;
  final String label;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (tone, filled) = switch (ptt) {
      PttState.talking => (scheme.error, true),
      PttState.requesting => (const Color(0xFFFCEE0A), false),
      PttState.listening => (scheme.primary, true),
      _ => enabled ? (scheme.primary, false) : (scheme.outline, false),
    };

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: enabled
          ? (_) {
              HapticFeedback.mediumImpact();
              onDown();
            }
          : null,
      onPointerUp: enabled ? (_) => onUp() : null,
      onPointerCancel: enabled ? (_) => onUp() : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 168,
        height: 168,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled
              ? tone.withValues(alpha: 0.18)
              : scheme.surfaceContainerLow.withValues(alpha: 0.75),
          border: Border.all(color: tone.withValues(alpha: 0.75), width: 2),
          boxShadow: [
            BoxShadow(
              color: tone.withValues(alpha: filled ? 0.45 : 0.18),
              blurRadius: filled ? 34 : 18,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              ptt == PttState.talking
                  ? Icons.graphic_eq_rounded
                  : ptt == PttState.listening
                      ? Icons.headphones_rounded
                      : Icons.mic_rounded,
              size: 46,
              color: tone,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: tone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
