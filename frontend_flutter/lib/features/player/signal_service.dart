import 'package:flutter/services.dart';

/// 网络类型。
enum NetType { wifi, cell, none }

/// 信号快照：dBm（WiFi/蜂窝可测时）+ 信号等级 0..4。
class SignalInfo {
  const SignalInfo({
    required this.type,
    this.rssi,
    this.level = 0,
  });

  const SignalInfo.unknown()
      : type = NetType.none,
        rssi = null,
        level = 0;

  final NetType type;

  /// dBm 场强（WiFi RSSI / 蜂窝 dBm），不可测时为 null。
  final int? rssi;

  /// 信号等级 0..4（无连接时可能为 -1 或 0）。
  final int level;

  bool get available => type != NetType.none;
}

/// Android 信号桥：MethodChannel iradio/signal（原生 SignalMeter）。
class SignalService {
  static const _channel = MethodChannel('iradio/signal');

  Future<SignalInfo> read() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('getSignal');
      if (raw is Map) {
        final type = switch (raw['type']) {
          'wifi' => NetType.wifi,
          'cell' => NetType.cell,
          _ => NetType.none,
        };
        final rssi = raw['rssi'] is int ? raw['rssi'] as int : null;
        final level = raw['level'] is int ? raw['level'] as int : 0;
        return SignalInfo(type: type, rssi: rssi, level: level);
      }
    } catch (_) {
      // 非 Android 平台或通道异常：未知状态。
    }
    return const SignalInfo.unknown();
  }
}
