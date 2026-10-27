import 'package:flutter_test/flutter_test.dart';
import 'package:iradio/data/network/intercom_protocol.dart';

void main() {
  group('IntercomSignal 编解码', () {
    test('join 往返：encode 后 decode 恢复全部字段', () {
      final s = IntercomSignal.join(ch: 'road-trip', nick: 'Alice', id: 'abc123');
      final back = IntercomSignal.decode(s.encode())!;
      expect(back.type, 'join');
      expect(back['ch'], 'road-trip');
      expect(back['nick'], 'Alice');
      expect(back['id'], 'abc123');
    });

    test('ice 嵌套 candidate map 往返', () {
      final s = IntercomSignal.ice('peer1', {
        'candidate': 'candidate:1 1 udp 2113937151 ...',
        'sdpMid': '0',
        'sdpMLineIndex': 0,
      });
      final back = IntercomSignal.decode(s.encode())!;
      expect(back.type, 'ice');
      expect(back['to'], 'peer1');
      final c = back['candidate'] as Map;
      expect(c['candidate'], contains('candidate:'));
      expect(c['sdpMLineIndex'], 0);
    });

    test('下行 talk_granted/talk_denied/error 可解码', () {
      expect(
          IntercomSignal.decode('{"t":"talk_granted"}')!.type, 'talk_granted');
      expect(
          IntercomSignal.decode('{"t":"talk_denied","reason":"busy"}')!['reason'],
          'busy');
      expect(
          IntercomSignal.decode('{"t":"error","code":"room_full","msg":"full"}')!
              ['code'],
          'room_full');
    });

    test('坏帧拒绝：非法 JSON / 未知类型 / 非对象', () {
      expect(IntercomSignal.decode('not json'), isNull);
      expect(IntercomSignal.decode('{"t":"bogus"}'), isNull);
      expect(IntercomSignal.decode('[1,2]'), isNull);
      expect(IntercomSignal.decode('{"no_t":1}'), isNull);
    });

    test('memberListOf 解析 joined 成员数组', () {
      final s = IntercomSignal.decode(
          '{"t":"joined","members":[{"id":"a","nick":"Alice"},{"id":"b","nick":"Bob"}]}')!;
      final list = memberListOf(s);
      expect(list, hasLength(2));
      expect(list.first['id'], 'a');
      expect(list.last['nick'], 'Bob');
    });

    test('memberListOf 缺失/非法字段返回空列表', () {
      expect(memberListOf(IntercomSignal('joined')), isEmpty);
      expect(
          memberListOf(IntercomSignal.decode('{"t":"members","members":3}')!),
          isEmpty);
    });
  });
}
