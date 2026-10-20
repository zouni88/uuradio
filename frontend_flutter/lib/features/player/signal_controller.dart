import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'signal_service.dart';

export 'signal_service.dart' show NetType, SignalInfo;

/// 信号控制器：每 2.5s 轮询原生信号快照。
///
/// autoDispose：仅播放页打开时活跃。
class SignalController extends Notifier<SignalInfo> {
  final _service = SignalService();
  Timer? _timer;

  @override
  SignalInfo build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    _poll();
    _timer = Timer.periodic(
      const Duration(milliseconds: 2500),
      (_) => _poll(),
    );
    return const SignalInfo.unknown();
  }

  Future<void> _poll() async {
    final info = await _service.read();
    if (ref.mounted) state = info;
  }
}

/// 仅播放页挂载的信号 provider。
final signalProvider = NotifierProvider.autoDispose<SignalController, SignalInfo>(
  SignalController.new,
);
