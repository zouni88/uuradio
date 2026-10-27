import 'dart:convert';

/// 信令消息编解码（与 Go 服务器 internal/room.go、hub.go 逐字段对齐）。
/// 纯 Dart，可直接单测。
class IntercomSignal {
  const IntercomSignal(this.type, [this.fields = const {}]);

  /// "t" 字段：join/leave/offer/answer/ice/talk_req/talk_released/heartbeat
  /// 及下行 joined/members/talk_granted/talk_denied/talk_started/talk_stopped/error。
  final String type;
  final Map<String, Object?> fields;

  static const _knownTypes = {
    'join', 'joined', 'leave', 'members',
    'offer', 'answer', 'ice',
    'talk_req', 'talk_granted', 'talk_denied',
    'talk_started', 'talk_stopped',
    'heartbeat', 'error',
  };

  String encode() => jsonEncode({'t': type, ...fields});

  /// 解码；非法 JSON / 未知类型返回 null（坏帧拒绝）。
  static IntercomSignal? decode(String raw) {
    try {
      final obj = jsonDecode(raw);
      if (obj is! Map<String, dynamic>) return null;
      final t = obj['t'];
      if (t is! String || !_knownTypes.contains(t)) return null;
      final fields = Map<String, Object?>.from(obj)..remove('t');
      return IntercomSignal(t, fields);
    } catch (_) {
      return null;
    }
  }

  // ---- 上行便捷构造 ----

  factory IntercomSignal.join({
    required String ch,
    required String nick,
    required String id,
  }) =>
      IntercomSignal('join', {'ch': ch, 'nick': nick, 'id': id});

  static final IntercomSignal leave = const IntercomSignal('leave');

  static IntercomSignal offer(String to, String sdp) =>
      IntercomSignal('offer', {'to': to, 'sdp': sdp});

  static IntercomSignal answer(String to, String sdp) =>
      IntercomSignal('answer', {'to': to, 'sdp': sdp});

  static IntercomSignal ice(String to, Map<String, Object?> candidate) =>
      IntercomSignal('ice', {'to': to, 'candidate': candidate});

  static final IntercomSignal talkReq = const IntercomSignal('talk_req');

  static final IntercomSignal talkReleased = const IntercomSignal('talk_released');

  static IntercomSignal heartbeat(int ts) =>
      IntercomSignal('heartbeat', {'ts': ts});

  // ---- 下行字段读取 ----

  Object? operator [](String key) => fields[key];
}

/// joined/members 消息中的成员数组。
List<Map<Object?, Object?>> memberListOf(IntercomSignal s) {
  final raw = s['members'];
  if (raw is! List) return const [];
  return raw.whereType<Map<Object?, Object?>>().toList();
}
