import 'package:flutter_test/flutter_test.dart';
import 'package:iradio/domain/models/intercom_models.dart';
import 'package:iradio/features/intercom/floor_state_machine.dart';

void main() {
  late FloorStateMachine sm;
  late List<PttState> states;
  late int reqCount;
  late int releaseCount;

  setUp(() {
    states = [];
    reqCount = 0;
    releaseCount = 0;
    sm = FloorStateMachine(
      onRequest: () => reqCount++,
      onRelease: () => releaseCount++,
      onStateChanged: states.add,
    );
  });

  tearDown(() => sm.dispose());

  group('先按先得流程', () {
    test('按下 → requesting 并发 talk_req', () {
      sm.pointerDown();
      expect(sm.state, PttState.requesting);
      expect(reqCount, 1);
    });

    test('requesting 中重复按下被忽略（无重入）', () {
      sm.pointerDown();
      sm.pointerDown();
      expect(reqCount, 1);
      expect(sm.state, PttState.requesting);
    });

    test('授予 → talking；松开 → idle 并发 talk_released', () {
      sm.pointerDown();
      sm.granted();
      expect(sm.state, PttState.talking);
      sm.pointerUp();
      expect(sm.state, PttState.idle);
      expect(releaseCount, 1);
    });

    test('未授予就松开：补发释放，防服务器迟到授予', () {
      sm.pointerDown();
      sm.pointerUp();
      expect(sm.state, PttState.idle);
      expect(releaseCount, 1);
      // 迟到的 granted 不应改变状态
      sm.granted();
      expect(sm.state, PttState.idle);
    });

    test('拒绝 → idle，可再次按下', () {
      sm.pointerDown();
      sm.denied();
      expect(sm.state, PttState.idle);
      expect(releaseCount, 0);
      sm.pointerDown();
      expect(sm.state, PttState.requesting);
      expect(reqCount, 2);
    });
  });

  group('listening 转换', () {
    test('他人开始/结束讲话：idle → listening → idle', () {
      sm.peerStarted();
      expect(sm.state, PttState.listening);
      sm.peerStopped();
      expect(sm.state, PttState.idle);
    });

    test('talking 中收到 peerStarted 不抢占', () {
      sm.pointerDown();
      sm.granted();
      sm.peerStarted();
      expect(sm.state, PttState.talking);
    });

    test('listening 中按下仍可正常申请', () {
      sm.peerStarted();
      sm.pointerDown();
      expect(sm.state, PttState.listening); // 非 idle 忽略
      sm.peerStopped();
      sm.pointerDown();
      expect(sm.state, PttState.requesting);
    });
  });

  group('持有上限', () {
    test('超时自动释放并发 talk_released', () async {
      final fast = FloorStateMachine(
        onRequest: () {},
        onRelease: () => releaseCount++,
        onStateChanged: states.add,
        maxHold: const Duration(milliseconds: 30),
      );
      fast.pointerDown();
      fast.granted();
      expect(fast.state, PttState.talking);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(fast.state, PttState.idle);
      expect(releaseCount, 1);
      fast.dispose();
    });

    test('正常松开后超时定时器被取消', () async {
      final fast = FloorStateMachine(
        onRequest: () {},
        onRelease: () => releaseCount++,
        onStateChanged: states.add,
        maxHold: const Duration(milliseconds: 30),
      );
      fast.pointerDown();
      fast.granted();
      fast.pointerUp();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(releaseCount, 1); // 仅 pointerUp 那一次
      fast.dispose();
    });
  });

  test('reset 回 idle 且不发释放消息', () {
    sm.pointerDown();
    sm.granted();
    sm.reset();
    expect(sm.state, PttState.idle);
    expect(releaseCount, 0);
  });
}
