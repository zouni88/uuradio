import 'package:flutter/services.dart';

/// Android Visualizer 桥：原生侧完成 FFT 采集与对数分桶，
/// 通过 EventChannel 推送 32 段归一化强度（0~1）。
class SpectrumVisualizerService {
  static const _channel = MethodChannel('iradio/visualizer');
  static const _events = EventChannel('iradio/visualizer_events');

  /// 请求 RECORD_AUDIO 授权（原生侧发起系统弹窗）。已授权/授权成功返回 true。
  Future<bool> requestPermission() async {
    try {
      return await _channel
              .invokeMethod<bool>('requestPermission') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// 启用频谱采集。未授权麦克风或设备不支持时返回 false。
  Future<bool> enable(int sessionId) async {
    try {
      return await _channel.invokeMethod<bool>('enable', {
            'sessionId': sessionId,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> disable() async {
    try {
      await _channel.invokeMethod<void>('disable');
    } on PlatformException {
      // 忽略。
    }
  }

  Stream<List<double>> get bands => _events.receiveBroadcastStream().map(
        (data) {
          if (data is List) {
            return data.map((e) => (e as num).toDouble()).toList();
          }
          return const <double>[];
        },
      );
}
