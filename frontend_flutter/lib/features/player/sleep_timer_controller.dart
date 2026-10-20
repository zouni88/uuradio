import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_controller.dart';

/// 睡眠定时器：state = 剩余时长（null 表示未启用）。
class SleepTimerController extends Notifier<Duration?> {
  Timer? _timer;

  @override
  Duration? build() => null;

  void start(Duration duration) {
    _timer?.cancel();
    var remaining = duration;
    state = remaining;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining -= const Duration(seconds: 1);
      if (remaining <= Duration.zero) {
        timer.cancel();
        _timer = null;
        state = null;
        ref.read(playerProvider.notifier).pause();
      } else {
        state = remaining;
      }
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    state = null;
  }
}

final sleepTimerProvider =
    NotifierProvider<SleepTimerController, Duration?>(
  SleepTimerController.new,
);
