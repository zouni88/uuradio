import 'dart:async';

import '../../domain/models/intercom_models.dart';
import '../../domain/repositories/intercom_repository.dart';
import '../network/intercom_protocol.dart';
import '../network/intercom_signaling_client.dart';

/// 信令仓库实现：IntercomSignal → 领域事件映射。
class IntercomRepositoryImpl implements IntercomRepository {
  IntercomRepositoryImpl(this._client) {
    _sub = _client.incoming.listen(_onSignal);
    _linkSub = _client.linkEvents.listen((online) {
      _events.add(LinkChanged(online));
    });
  }

  final IntercomSignalingClient _client;
  final _events = StreamController<IntercomEvent>.broadcast();
  StreamSubscription<IntercomSignal>? _sub;
  StreamSubscription<bool>? _linkSub;

  @override
  Stream<IntercomEvent> get events => _events.stream;

  @override
  void join({
    required String serverUrl,
    required String channel,
    required String nickname,
    required String selfId,
  }) {
    _client.connect(
      serverUrl,
      IntercomSignal.join(ch: channel, nick: nickname, id: selfId),
    );
  }

  @override
  void leave() => _client.disconnect();

  @override
  void sendSignaling({
    required String to,
    required String kind,
    required Object payload,
  }) {
    switch (kind) {
      case 'offer':
        _client.send(IntercomSignal.offer(to, payload as String));
      case 'answer':
        _client.send(IntercomSignal.answer(to, payload as String));
      case 'ice':
        _client.send(IntercomSignal.ice(
            to, Map<String, Object?>.from(payload as Map)));
      default:
    }
  }

  @override
  void requestTalk() => _client.send(IntercomSignal.talkReq);

  @override
  void releaseTalk() => _client.send(IntercomSignal.talkReleased);

  @override
  void dispose() {
    _sub?.cancel();
    _linkSub?.cancel();
    _client.dispose();
    _events.close();
  }

  void _onSignal(IntercomSignal s) {
    switch (s.type) {
      case 'joined':
      case 'members':
        _events.add(MembersChanged(memberListOf(s)
            .map((m) => IntercomMember.fromMap(m))
            .where((m) => m.id.isNotEmpty)
            .toList()));
      case 'offer':
      case 'answer':
        _events.add(PeerSignalArrived(
          from: s['from'] as String? ?? '',
          kind: s.type,
          payload: s['sdp'] as String? ?? '',
        ));
      case 'ice':
        _events.add(PeerSignalArrived(
          from: s['from'] as String? ?? '',
          kind: 'ice',
          payload: s['candidate'] ?? const <String, Object?>{},
        ));
      case 'talk_granted':
        _events.add(FloorGranted());
      case 'talk_denied':
        _events.add(FloorDenied(s['reason'] as String? ?? 'busy'));
      case 'talk_started':
        _events.add(FloorStarted(
          speakerId: s['id'] as String? ?? '',
          nick: s['nick'] as String? ?? '',
        ));
      case 'talk_stopped':
        _events.add(FloorStopped(s['id'] as String? ?? ''));
      case 'error':
        _events.add(IntercomNotice(
          code: s['code'] as String? ?? 'error',
          message: s['msg'] as String? ?? '',
        ));
      default:
      // join/leave/heartbeat 为上行回声，忽略。
    }
  }
}
