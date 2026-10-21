import 'package:flutter/services.dart';

/// 媒体音量（车机模式音量滚轮数据源）。
/// Android 走原生 AudioManager；未实现平台（iOS）返回 null，由 UI 降级置灰。
class VolumeControl {
  VolumeControl._();

  static const MethodChannel _ch = MethodChannel('iradio/volume');

  static Future<VolumeLevel?> get() async {
    try {
      final r = await _ch.invokeMapMethod<String, Object?>('get');
      return _parse(r);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<VolumeLevel?> set(int volume) async {
    try {
      final r = await _ch.invokeMapMethod<String, Object?>(
        'set',
        {'volume': volume},
      );
      return _parse(r);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static VolumeLevel? _parse(Map<String, Object?>? r) {
    final v = r?['volume'];
    final m = r?['max'];
    if (v is! int || m is! int || m <= 0) return null;
    return VolumeLevel(volume: v.clamp(0, m), max: m);
  }
}

class VolumeLevel {
  const VolumeLevel({required this.volume, required this.max});

  final int volume;
  final int max;
}
