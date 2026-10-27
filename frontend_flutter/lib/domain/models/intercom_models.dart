/// 对讲（PTT）领域模型：纯 Dart，不依赖 flutter。
library;

/// 频道成员。
class IntercomMember {
  const IntercomMember({required this.id, required this.nick});

  final String id;
  final String nick;

  factory IntercomMember.fromMap(Map<Object?, Object?> m) => IntercomMember(
        id: m['id'] as String? ?? '',
        nick: m['nick'] as String? ?? '',
      );

  Map<String, String> toMap() => {'id': id, 'nick': nick};

  @override
  bool operator ==(Object other) =>
      other is IntercomMember && other.id == id && other.nick == nick;

  @override
  int get hashCode => Object.hash(id, nick);
}

/// PTT 会话状态机取值。
enum PttState {
  /// 未连接信令服务器。
  disconnected,

  /// 正在连接/重连。
  connecting,

  /// 已连上信令但未入房。
  connected,

  /// 已在频道，空闲。
  idle,

  /// 已申请话权，等待仲裁。
  requesting,

  /// 本机讲话中（TX）。
  talking,

  /// 他人讲话中（RX）。
  listening,
}

/// 对讲运行所需配置（来自设置页）。
class IntercomConfig {
  const IntercomConfig({
    this.serverUrl = '',
    this.nickname = '',
    this.turnUrl = '',
    this.turnUser = '',
    this.turnPass = '',
  });

  /// ws:// 或 wss:// 信令地址，空 = 未配置。
  final String serverUrl;
  final String nickname;

  /// TURN 中继（可选，蜂窝 CGNAT 兜底）。
  final String turnUrl;
  final String turnUser;
  final String turnPass;

  bool get hasServer => serverUrl.trim().isNotEmpty;
  bool get hasTurn => turnUrl.trim().isNotEmpty;
}

/// 数据层解析信令后上报的领域事件。
sealed class IntercomEvent {}

/// 成员列表变化（含首次入房回执）。
class MembersChanged extends IntercomEvent {
  MembersChanged(this.members);
  final List<IntercomMember> members;
}

/// 来自某成员的 WebRTC 信令：kind = offer | answer | ice。
class PeerSignalArrived extends IntercomEvent {
  PeerSignalArrived({required this.from, required this.kind, required this.payload});
  final String from;
  final String kind;

  /// offer/answer 为 String sdp；ice 为 Map candidate。
  final Object payload;
}

/// 话权仲裁结果与频道广播。
class FloorGranted extends IntercomEvent {}

class FloorDenied extends IntercomEvent {
  FloorDenied(this.reason);
  final String reason;
}

class FloorStarted extends IntercomEvent {
  FloorStarted({required this.speakerId, required this.nick});
  final String speakerId;
  final String nick;
}

class FloorStopped extends IntercomEvent {
  FloorStopped(this.speakerId);
  final String speakerId;
}

/// 信令连接状态变化。
class LinkChanged extends IntercomEvent {
  LinkChanged(this.online);
  final bool online;
}

/// 服务器错误（room_full / bad_join 等）。
class IntercomNotice extends IntercomEvent {
  IntercomNotice({required this.code, required this.message});
  final String code;
  final String message;
}
