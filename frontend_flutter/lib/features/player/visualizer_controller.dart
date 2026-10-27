import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
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
/// 省电约束（2026-10-22）：频谱只服务于"正在播放且 App 在前台"的画面。
/// 暂停或退后台时立即停掉原生 FFT 采集 / 合成动画定时器，回到空闲态；
/// 恢复播放/回前台再自动重新挂载。电台静音时不应再有 25Hz 的采集与重建。
///
/// autoDispose：仅播放页打开时活跃。
class VisualizerController extends Notifier<VisualizerState>
    with WidgetsBindingObserver {
  final _service = SpectrumVisualizerService();
  StreamSubscription<int?>? _sessionIdSub;
  StreamSubscription<List<double>>? _bandsSub;
  Timer? _synthTimer;
  final _random = Random();
  final List<double> _smoothed =
      List.filled(VisualizerState.bandCount, 0, growable: false);

  int? _sessionId;
  bool _playing = false;
  bool _foreground = true;
  bool _useSynthetic = false; // iOS / 权限拒绝 / 设备不支持
  bool _realEnabled = false; // 原生 Visualizer 当前已启用
  bool _starting = false; // 防止 enable 异步期间并发重入

  @override
  VisualizerState build() {
    ref.onDispose(_teardown);
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));

    _foreground = _isForeground(WidgetsBinding.instance.lifecycleState);
    _playing = ref.read(playerProvider.select((p) => p.playing));
    ref.listen(playerProvider.select((p) => p.playing), (_, next) {
      _playing = next;
      _sync();
    });

    if (!Platform.isAndroid) {
      // iOS 无公开的音频输出 FFT 采集 API：走合成动画（仅播放中运行）。
      _useSynthetic = true;
    } else {
      final handler = ref.watch(audioHandlerProvider);
      // 流对新订阅者先重放当前会话 ID（播放中再进页面也能挂上），
      // 之后每次会话变更（换流/重建播放器）先卸载旧采集再由 _sync 重挂。
      _sessionIdSub = handler.androidAudioSessionIdStream.listen((id) {
        _sessionId = id;
        _stopCapture();
        _sync();
      });
    }
    // 首次同步推迟到 build 返回之后：build 期间 state 尚未初始化，
    // 直接 _sync() 会在非活跃分支读 state 触发 Riverpod 循环依赖崩溃。
    Future<void>.microtask(_sync);
    return const VisualizerState();
  }

  static bool _isForeground(AppLifecycleState? state) =>
      state == null ||
      state == AppLifecycleState.resumed ||
      state == AppLifecycleState.inactive;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = _isForeground(state);
    _sync();
  }

  /// 按"播放中且前台"开关采集：不活跃时停掉一切周期性功耗源并回空闲态。
  void _sync() {
    if (!ref.mounted) return;
    final active = _playing && _foreground;
    if (!active) {
      _stopCapture();
      if (state.bands.isNotEmpty) {
        state = state.copyWith(bands: VisualizerState.idleBands);
      }
      return;
    }
    if (_useSynthetic) {
      _startSynthetic();
      return;
    }
    final id = _sessionId;
    if (id == null || _starting || _bandsSub != null) return;
    _startReal(id);
  }

  Future<void> _startReal(int sessionId) async {
    _starting = true;
    try {
      final granted = await _service.requestPermission();
      if (!ref.mounted) return;
      if (!granted) {
        _useSynthetic = true;
        state = state.copyWith(real: false, permissionDenied: true);
        _sync();
        return;
      }
      final ok = await _service.enable(sessionId);
      if (!ref.mounted) return;
      if (!ok) {
        _useSynthetic = true;
        _sync();
        return;
      }
      // 异步等待期间可能已暂停/退后台：不活跃则立刻释放。
      if (!(_playing && _foreground)) {
        await _service.disable();
        return;
      }
      _realEnabled = true;
      _bandsSub = _service.bands.listen(_onBands);
    } finally {
      _starting = false;
    }
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

  /// 未授权/不支持时的降级：平滑随机游走合成动画（仅播放中运行）。
  void _startSynthetic() {
    if (_synthTimer != null) return;
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

  void _stopCapture() {
    _synthTimer?.cancel();
    _synthTimer = null;
    final hadReal = _realEnabled || _bandsSub != null;
    _bandsSub?.cancel();
    _bandsSub = null;
    _realEnabled = false;
    if (hadReal) _service.disable();
  }

  void _teardown() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionIdSub?.cancel();
    _sessionIdSub = null;
    _stopCapture();
    _service.disable();
  }
}

/// 仅播放页挂载的频谱 provider。
final visualizerProvider = NotifierProvider.autoDispose<VisualizerController,
    VisualizerState>(VisualizerController.new);
