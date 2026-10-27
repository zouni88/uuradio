import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/intercom_models.dart';
import '../player/player_controller.dart';
import '../settings/settings_controller.dart';
import 'floor_state_machine.dart';
import 'webrtc_session.dart';

/// 对讲 UI 状态。
class IntercomUiState {
  const IntercomUiState({
    this.ptt = PttState.disconnected,
    this.channel = '',
    this.members = const [],
    this.speakerNick = '',
    this.notice,
    this.micReady = false,
  });

  final PttState ptt;
  final String channel;
  final List<IntercomMember> members;

  /// 当前讲话者昵称（RX 显示）。
  final String speakerNick;

  /// 通知代码（server_required/room_full/mic_denied/floor_busy），UI 映射 l10n。
  final String? notice;
  final bool micReady;

  bool get joined => channel.isNotEmpty;

  /// 空闲且麦克风可用才允许按下讲话。
  bool get canStartTalk => ptt == PttState.idle && micReady;

  IntercomUiState copyWith({
    PttState? ptt,
    String? channel,
    List<IntercomMember>? members,
    String? speakerNick,
    Object? notice = _sentinel,
    bool? micReady,
  }) {
    return IntercomUiState(
      ptt: ptt ?? this.ptt,
      channel: channel ?? this.channel,
      members: members ?? this.members,
      speakerNick: speakerNick ?? this.speakerNick,
      notice: notice == _sentinel ? this.notice : notice as String?,
      micReady: micReady ?? this.micReady,
    );
  }

  static const Object _sentinel = Object();
}

/// 对讲控制器：信令事件 → 话权状态机 + WebRTC 网格 + 电台联动。
class IntercomController extends Notifier<IntercomUiState> {
  StreamSubscription<IntercomEvent>? _sub;
  WebrtcSession? _session;
  FloorStateMachine? _floor;
  String? _selfId;

  /// RX/TX 前电台是否在播（释放后恢复）。
  bool _wasPlaying = false;

  @override
  IntercomUiState build() {
    final repo = ref.watch(intercomRepositoryProvider);
    _sub?.cancel();
    _sub = repo.events.listen(_onEvent);
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
      _floor?.dispose();
      _floor = null;
      _session?.stop();
      _session = null;
      repo.leave();
    });
    return const IntercomUiState();
  }

  IntercomConfig get _config {
    final s = ref.read(settingsProvider);
    return IntercomConfig(
      serverUrl: s.intercomServerUrl,
      nickname: s.intercomNickname,
      turnUrl: s.intercomTurnUrl,
      turnUser: s.intercomTurnUser,
      turnPass: s.intercomTurnPass,
    );
  }

  /// 加入频道：先开麦（权限），再连信令。
  Future<void> joinChannel(String channel) async {
    final ch = channel.trim();
    if (ch.isEmpty) return;
    final config = _config;
    if (!config.hasServer) {
      state = state.copyWith(notice: 'server_required');
      return;
    }
    final repo = ref.read(intercomRepositoryProvider);
    _selfId ??= _generateId();
    _floor?.dispose();
    _floor = FloorStateMachine(
      onRequest: repo.requestTalk,
      onRelease: repo.releaseTalk,
      onStateChanged: (s) {
        if (ref.mounted) state = state.copyWith(ptt: s);
      },
    );
    _session = WebrtcSession(
      config: config,
      sendSignal: (to, kind, payload) {
        repo.sendSignaling(to: to, kind: kind, payload: payload);
      },
    );
    state = state.copyWith(
        channel: ch, ptt: PttState.connecting, notice: null, members: []);
    final micOk = await _session!.start(_selfId!);
    if (!ref.mounted) return;
    state = state.copyWith(micReady: micOk);
    if (!micOk) state = state.copyWith(notice: 'mic_denied');
    final nick = config.nickname.isNotEmpty
        ? config.nickname
        : 'OP-${_selfId!.substring(0, 4)}';
    repo.join(
      serverUrl: config.serverUrl,
      channel: ch,
      nickname: nick,
      selfId: _selfId!,
    );
  }

  /// 退出频道：断信令、销网格、关麦。
  void leaveChannel() {
    ref.read(intercomRepositoryProvider).leave();
    _floor?.dispose();
    _floor = null;
    _session?.stop();
    _session = null;
    _resumeRadio();
    state = const IntercomUiState();
  }

  /// PTT 按钮按下。
  void pointerDown() => _floor?.pointerDown();

  /// PTT 按钮松开。
  void pointerUp() => _floor?.pointerUp();

  void dismissNotice() => state = state.copyWith(notice: null);

  void _onEvent(IntercomEvent e) {
    if (!ref.mounted) return;
    switch (e) {
      case MembersChanged(:final members):
        _session?.syncPeers(
            members.where((m) => m.id != _selfId).map((m) => m.id).toList());
        final ptt = (state.ptt == PttState.connecting ||
                state.ptt == PttState.connected)
            ? PttState.idle
            : state.ptt;
        state = state.copyWith(members: members, ptt: ptt);
      case PeerSignalArrived(:final from, :final kind, :final payload):
        if (from.isNotEmpty) _session?.handleSignal(from, kind, payload);
      case FloorGranted():
        _floor?.granted();
        _session?.setTalking(true);
        _pauseRadio();
      case FloorDenied(:final reason):
        _floor?.denied();
        if (reason == 'busy') state = state.copyWith(notice: 'floor_busy');
      case FloorStarted(:final nick):
        _floor?.peerStarted();
        state = state.copyWith(speakerNick: nick);
        _pauseRadio();
      case FloorStopped():
        _floor?.peerStopped();
        state = state.copyWith(speakerNick: '');
        if (state.ptt != PttState.talking) _resumeRadio();
      case LinkChanged(:final online):
        if (online) {
          if (state.joined && state.ptt == PttState.connecting) {
            state = state.copyWith(ptt: PttState.connected);
          }
        } else {
          _floor?.reset();
          _session?.setTalking(false);
          _resumeRadio();
          if (state.joined) {
            state = state.copyWith(
                ptt: PttState.connecting, speakerNick: '');
          }
        }
      case IntercomNotice(:final code):
        if (code == 'room_full') {
          // 入房被拒：退房复位，保留提示。
          ref.read(intercomRepositoryProvider).leave();
          _floor?.dispose();
          _floor = null;
          _session?.stop();
          _session = null;
          state = const IntercomUiState(notice: 'room_full');
        } else {
          state = state.copyWith(notice: code);
        }
    }
  }

  /// 对讲优先：讲话/收听时暂停电台。
  void _pauseRadio() {
    if (ref.read(playerProvider).playing) {
      _wasPlaying = true;
      ref.read(playerProvider.notifier).pause();
    }
  }

  void _resumeRadio() {
    if (_wasPlaying) {
      _wasPlaying = false;
      ref.read(playerProvider.notifier).togglePlayPause();
    }
  }

  String _generateId() {
    final rnd = Random();
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final r = rnd.nextInt(1 << 30).toRadixString(16).padLeft(8, '0');
    return (ts + r).substring(0, 16);
  }
}

final intercomProvider =
    NotifierProvider<IntercomController, IntercomUiState>(
        IntercomController.new);
