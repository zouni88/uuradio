import 'dart:async';

import '../../domain/models/intercom_models.dart';

/// 话权（PTT 按键讲话）状态机：半双工、先按先得、持有上限强制释放。
/// 纯 Dart + 回调注入，可直接单测。
/// 管理 idle ↔ requesting ↔ talking 与 listening 四个态。
class FloorStateMachine {
  FloorStateMachine({
    required this.onRequest,
    required this.onRelease,
    required this.onStateChanged,
    this.maxHold = const Duration(seconds: 60),
  });

  /// 发送 talk_req。
  final void Function() onRequest;

  /// 发送 talk_released。
  final void Function() onRelease;

  /// 状态变化回调（idle/requesting/talking/listening）。
  final void Function(PttState state) onStateChanged;

  /// 话权持有上限，超时自动释放。
  final Duration maxHold;

  PttState _state = PttState.idle;
  Timer? _timeout;

  PttState get state => _state;

  /// 按下讲话键：idle → requesting。
  void pointerDown() {
    if (_state != PttState.idle) return;
    _set(PttState.requesting);
    onRequest();
  }

  /// 松开讲话键：requesting → 取消（补发释放防服务器随后授予）；talking → 释放。
  void pointerUp() {
    switch (_state) {
      case PttState.requesting:
        _cancelTimeout();
        _set(PttState.idle);
        // 服务器对非持有者释放是无操作；发送仅为保持消息序一致。
        onRelease();
      case PttState.talking:
        release();
      default:
    }
  }

  /// 服务器授予话权。
  void granted() {
    if (_state != PttState.requesting) return;
    _set(PttState.talking);
    _cancelTimeout();
    _timeout = Timer(maxHold, release);
  }

  /// 服务器拒绝（他人持有中）。
  void denied() {
    if (_state != PttState.requesting) return;
    _set(PttState.idle);
  }

  /// 主动/超时释放。
  void release() {
    if (_state != PttState.talking) return;
    _cancelTimeout();
    _set(PttState.idle);
    onRelease();
  }

  /// 他人开始讲话：idle → listening。
  void peerStarted() {
    if (_state == PttState.idle) _set(PttState.listening);
  }

  /// 他人结束讲话。
  void peerStopped() {
    if (_state == PttState.listening) _set(PttState.idle);
  }

  /// 断线/退房重置（不发送释放消息由调用方决定）。
  void reset() {
    _cancelTimeout();
    _set(PttState.idle);
  }

  void dispose() => _cancelTimeout();

  void _set(PttState s) {
    _state = s;
    onStateChanged(s);
  }

  void _cancelTimeout() {
    _timeout?.cancel();
    _timeout = null;
  }
}
