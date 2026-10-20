import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_controller.dart';
import 'visualizer_service.dart';

/// 频谱状态：真实 FFT 或降级合成。
class VisualizerState {
  const VisualizerState({
    this.bands = idleBands,
    this.real = false,
    this.permissionDenied = false,
  });

  static const int bandCount = 32;
  static const List<double> idleBands = <double>[];

  final List<double> bands;

  /// true = 真实 FFT；false = 合成动画。
  final bool real;
  final bool permissionDenied;

  VisualizerState copyWithBands(List<double> bands) =>
      VisualizerState(bands: bands, real: real, permissionDenied: permissionDenied);

  VisualizerState copyWith({
    List<double>? bands,
    bool? real,
    bool? permissionDenied,
  }) {
    return VisualizerState(
      bands: bands ?? this.bands,
      real: real ?? this.real,
      permissionDenied: permissionDenied ?? this.permissionDenied,
    );
  }
}

/// 频谱控制器：跟随音频会话 ID 挂载 Visualizer，失败降级为合成动画。
///
/// autoDispose：仅播放页打开时活跃。
class VisualizerController extends Notifier<VisualizerState> {
  final _service = SpectrumVisualizerService();
  StreamSubscription<int?>? _sessionIdSub;
  StreamSubscription<List<double>>? _bandsSub;
  Timer? _synthTimer;
  final _random = Random();
  final List<double> _smoothed =
      List.filled(VisualizerState.bandCount, 0, growable: false);

  @override
  VisualizerState build() {
    ref.onDispose(_teardown);
    if (!Platform.isAndroid) {
      // iOS 无公开的音频输出 FFT 采集 API：直接走合成动画，
      // 不请求麦克风、不触碰原生通道。
      Future.microtask(_startSynthetic);
      return const VisualizerState();
    }
    final handler = ref.watch(audioHandlerProvider);
    _sessionIdSub =
        handler.androidAudioSessionIdStream.listen(_onSessionIdChanged);
    return const VisualizerState();
  }

  Future<void> _onSessionIdChanged(int? sessionId) async {
    await _detach();
    if (sessionId == null) return;

    final granted = await _service.requestPermission();
    if (!granted) {
      _startSynthetic();
      if (ref.mounted) {
        state = state.copyWith(real: false, permissionDenied: true);
      }
      return;
    }
    final ok = await _service.enable(sessionId);
    if (!ok) {
      _startSynthetic();
      return;
    }
    _bandsSub = _service.bands.listen(_onBands);
  }

  void _onBands(List<double> bands) {
    if (!ref.mounted || bands.isEmpty) return;
    // 指数平滑防抖动。
    for (var i = 0; i < _smoothed.length; i++) {
      final v = i < bands.length ? bands[i] : 0.0;
      _smoothed[i] = _smoothed[i] * 0.45 + v * 0.55;
    }
    state = state.copyWithBands(List.of(_smoothed));
  }

  /// 未授权/不支持时的降级：平滑随机游走合成动画。
  void _startSynthetic() {
    _synthTimer?.cancel();
    var phase = 0.0;
    final targets =
        List<double>.generate(VisualizerState.bandCount, (_) => 0.3);
    _synthTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (!ref.mounted) return;
      phase += 0.35;
      for (var i = 0; i < targets.length; i++) {
        if (_random.nextDouble() < 0.18) {
          targets[i] = 0.15 + _random.nextDouble() * 0.85;
        }
        final wave = 0.12 * sin(phase * 0.6 + i * 0.4);
        final target =
            (targets[i] + wave).clamp(0.05, 1.0).toDouble();
        _smoothed[i] = _smoothed[i] * 0.6 + target * 0.4;
      }
      state = state.copyWithBands(List.of(_smoothed));
    });
  }

  Future<void> _detach() async {
    _bandsSub?.cancel();
    _bandsSub = null;
    await _service.disable();
  }

  void _teardown() {
    _sessionIdSub?.cancel();
    _sessionIdSub = null;
    _bandsSub?.cancel();
    _bandsSub = null;
    _synthTimer?.cancel();
    _synthTimer = null;
    _service.disable();
  }
}

/// 仅播放页挂载的频谱 provider。
final visualizerProvider = NotifierProvider.autoDispose<VisualizerController,
    VisualizerState>(VisualizerController.new);
