import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'intercom_protocol.dart';

/// 信令 WebSocket 连接：心跳保活 + 指数退避重连（重连自动重发 join）。
/// 纯 Dart（无 flutter 导入），心跳在入房期间持续——对讲是主动通信会话，
/// 退后台仍需保持收听（与频谱动画的省电门控场景不同）。
class IntercomSignalingClient {
  final _incoming = StreamController<IntercomSignal>.broadcast();
  final _link = StreamController<bool>.broadcast();

  /// 下行消息流。
  Stream<IntercomSignal> get incoming => _incoming.stream;

  /// 连接状态流（true=已连上并完成 ready）。
  Stream<bool> get linkEvents => _link.stream;

  bool get online => _online;
  bool _online = false;

  String? _url;
  IntercomSignal? _join;
  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _sub;
  Timer? _heartbeat;
  Timer? _retry;
  Duration _backoff = _retryMin;
  bool _disposed = false;

  static final Duration _retryMin = const Duration(seconds: 1);
  static final Duration _retryMax = const Duration(seconds: 10);
  static const Duration _heartbeatInterval = Duration(seconds: 20);

  /// 建立连接；join 为重连后需自动重发的入房消息。
  void connect(String url, IntercomSignal join) {
    if (_disposed) return;
    _url = url;
    _join = join;
    _backoff = _retryMin;
    _open();
  }

  /// 主动断开（保留流，可再次 connect）。
  void disconnect() {
    _url = null;
    _join = null;
    _retry?.cancel();
    _teardown();
    _setLink(false);
  }

  void send(IntercomSignal signal) {
    final ch = _channel;
    if (ch != null && _online) {
      try {
        ch.sink.add(signal.encode());
      } catch (_) {
        // 发送失败由 onDone/onError 路径统一触发重连。
      }
    }
  }

  void _open() {
    final url = _url;
    final join = _join;
    if (_disposed || url == null || join == null) return;
    _teardown();
    WebSocketChannel channel;
    try {
      channel = WebSocketChannel.connect(Uri.parse(url));
    } catch (_) {
      _scheduleRetry();
      return;
    }
    _channel = channel;
    channel.ready.then((_) {
      if (_disposed || _channel != channel) return;
      _setLink(true);
      _backoff = _retryMin;
      _onlineSend(join);
      _startHeartbeat();
    }).catchError((Object _) {
      _onDown(channel);
    });
    _sub = channel.stream.listen(
      (data) {
        final raw = data is String ? data : utf8.decode(data as List<int>);
        final signal = IntercomSignal.decode(raw);
        if (signal != null) _incoming.add(signal);
      },
      onDone: () => _onDown(channel),
      onError: (Object _) => _onDown(channel),
      cancelOnError: true,
    );
  }

  void _onDown(WebSocketChannel ch) {
    if (_disposed || _channel != ch) return;
    _teardown();
    _setLink(false);
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_disposed || _url == null) return;
    _retry?.cancel();
    _retry = Timer(_backoff, () {
      _backoff = _backoff * 2 > _retryMax ? _retryMax : _backoff * 2;
      _open();
    });
  }

  void _onlineSend(IntercomSignal s) {
    try {
      _channel?.sink.add(s.encode());
    } catch (_) {}
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) {
      _onlineSend(IntercomSignal.heartbeat(
          DateTime.now().millisecondsSinceEpoch));
    });
  }

  void _teardown() {
    _heartbeat?.cancel();
    _heartbeat = null;
    final sub = _sub;
    _sub = null;
    sub?.cancel();
    final ch = _channel;
    _channel = null;
    try {
      ch?.sink.close();
    } catch (_) {}
    _online = false;
  }

  void _setLink(bool value) {
    _online = value;
    _link.add(value);
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _teardown();
    _incoming.close();
    _link.close();
  }
}
