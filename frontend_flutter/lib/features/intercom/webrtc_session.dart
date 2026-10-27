import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../domain/models/intercom_models.dart';

/// 全网格 WebRTC 会话管理器：每个对端成员一条常驻 PeerConnection。
/// 本地麦克风轨道常态静音，仅持有话权时开启——讲话切换零重协商。
/// 移动端远端音频由插件原生侧自动播放，无需 renderer。
class WebrtcSession {
  WebrtcSession({required this.config, required this.sendSignal});

  final IntercomConfig config;

  /// to=成员 id；kind = offer | answer | ice；
  /// payload：offer/answer 为 String sdp，ice 为 Map candidate。
  final void Function(String to, String kind, Object payload) sendSignal;

  final Map<String, RTCPeerConnection> _pcs = {};
  MediaStream? _local;
  String _selfId = '';
  bool _starting = false;

  bool get micReady => _local != null;

  /// 开启麦克风采集（flutter_webrtc 内部自行请求运行时权限）。
  /// 返回 false = 权限被拒或设备不可用（仍可收听，不能讲话）。
  Future<bool> start(String selfId) async {
    _selfId = selfId;
    if (_starting) return _local != null;
    _starting = true;
    try {
      final stream = await navigator.mediaDevices
          .getUserMedia({'audio': true, 'video': false});
      for (final t in stream.getAudioTracks()) {
        t.enabled = false;
      }
      _local = stream;
      return true;
    } catch (_) {
      return false;
    } finally {
      _starting = false;
    }
  }

  /// 按成员列表（不含自己）增删对端连接。
  void syncPeers(List<String> peerIds) {
    for (final id in _pcs.keys.toList()) {
      if (!peerIds.contains(id)) {
        _removePeer(id);
      }
    }
    for (final id in peerIds) {
      if (!_pcs.containsKey(id)) {
        unawaited(_addPeer(id));
      }
    }
  }

  /// 处理对端信令。
  Future<void> handleSignal(String from, String kind, Object payload) async {
    if (!_pcs.containsKey(from)) {
      await _addPeer(from);
    }
    final pc = _pcs[from];
    if (pc == null) return;
    try {
      switch (kind) {
        case 'offer':
          await pc.setRemoteDescription(
              RTCSessionDescription(payload as String, 'offer'));
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          final local = await pc.getLocalDescription();
          sendSignal(from, 'answer', local?.sdp ?? '');
        case 'answer':
          await pc.setRemoteDescription(
              RTCSessionDescription(payload as String, 'answer'));
        case 'ice':
          final m = payload as Map;
          await pc.addCandidate(RTCIceCandidate(
            m['candidate'] as String?,
            m['sdpMid'] as String?,
            m['sdpMLineIndex'] as int?,
          ));
      }
    } catch (_) {
      // 对端可能已离开：丢弃过时信令，members 事件会纠正拓扑。
    }
  }

  /// TX 开关：话权授予时开启麦克风，释放/拒绝时静音。
  Future<void> setTalking(bool talking) async {
    final stream = _local;
    if (stream == null) return;
    for (final t in stream.getAudioTracks()) {
      t.enabled = talking;
    }
  }

  Future<void> stop() async {
    for (final id in _pcs.keys.toList()) {
      _removePeer(id);
    }
    final stream = _local;
    _local = null;
    if (stream != null) {
      for (final t in stream.getTracks()) {
        try {
          await t.stop();
        } catch (_) {}
      }
      try {
        await stream.dispose();
      } catch (_) {}
    }
  }

  /// flutter_webrtc 的配置为纯 Map（无 RTCIceServer 类型）。
  Map<String, dynamic> get _pcConfig => {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          if (config.hasTurn)
            {
              'urls': config.turnUrl,
              'username': config.turnUser,
              'credential': config.turnPass,
            },
        ],
      };

  Future<void> _addPeer(String peerId) async {
    final pc = await createPeerConnection(_pcConfig);
    _pcs[peerId] = pc;
    pc.onIceCandidate = (candidate) {
      sendSignal(peerId, 'ice', {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };
    final stream = _local;
    if (stream != null) {
      for (final t in stream.getAudioTracks()) {
        await pc.addTransceiver(
          track: t,
          init: RTCRtpTransceiverInit(
              direction: TransceiverDirection.SendRecv),
        );
      }
    } else {
      // 无麦克风权限：仅接收。
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init:
            RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
    }
    // glare 规避：双方 id 字典序小者发起 offer。
    if (_selfId.compareTo(peerId) < 0) {
      try {
        final offer = await pc.createOffer();
        await pc.setLocalDescription(offer);
        final local = await pc.getLocalDescription();
        sendSignal(peerId, 'offer', local?.sdp ?? '');
      } catch (_) {}
    }
  }

  void _removePeer(String id) {
    final pc = _pcs.remove(id);
    try {
      pc?.close();
    } catch (_) {}
  }
}
