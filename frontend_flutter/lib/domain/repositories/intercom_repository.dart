import '../models/intercom_models.dart';

/// 对讲信令数据源抽象（隔离传输实现，便于替换/测试）。
abstract class IntercomRepository {
  /// 领域事件流（成员变化 / 对端信令 / 话权仲裁 / 连接状态 / 通知）。
  Stream<IntercomEvent> get events;

  /// 连接信令服务器并加入频道；重连自动重发。
  void join({
    required String serverUrl,
    required String channel,
    required String nickname,
    required String selfId,
  });

  /// 离开频道并断开。
  void leave();

  /// 定向路由 WebRTC 信令：kind = offer | answer | ice。
  /// payload：offer/answer 为 String sdp；ice 为 Map candidate。
  void sendSignaling({
    required String to,
    required String kind,
    required Object payload,
  });

  /// 申请话权（先按先得，服务器仲裁）。
  void requestTalk();

  /// 释放话权。
  void releaseTalk();

  void dispose();
}
