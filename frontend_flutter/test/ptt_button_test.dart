import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iradio/domain/models/intercom_models.dart';
import 'package:iradio/features/intercom/widgets/ptt_button.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('按住触发 onDown、松开触发 onUp', (tester) async {
    var down = 0, up = 0;
    await tester.pumpWidget(_wrap(PttButton(
      ptt: PttState.idle,
      enabled: true,
      label: 'HOLD TO TALK',
      onDown: () => down++,
      onUp: () => up++,
    )));

    final gesture = await tester.startGesture(tester.getCenter(find.byType(PttButton)));
    await tester.pump();
    expect(down, 1);
    expect(up, 0);

    await gesture.up();
    await tester.pump();
    expect(up, 1);
  });

  testWidgets('取消（指针滑出后抬起）同样触发 onUp', (tester) async {
    var up = 0;
    await tester.pumpWidget(_wrap(PttButton(
      ptt: PttState.talking,
      enabled: true,
      label: 'TALKING',
      onDown: () {},
      onUp: () => up++,
    )));

    final gesture = await tester.startGesture(tester.getCenter(find.byType(PttButton)));
    await gesture.moveTo(const Offset(-100, -100));
    await gesture.up();
    await tester.pump();
    expect(up, greaterThanOrEqualTo(1));
  });

  testWidgets('禁用时按下不响应', (tester) async {
    var down = 0;
    await tester.pumpWidget(_wrap(PttButton(
      ptt: PttState.connected,
      enabled: false,
      label: 'OFFLINE',
      onDown: () => down++,
      onUp: () {},
    )));

    final gesture = await tester.startGesture(tester.getCenter(find.byType(PttButton)));
    await gesture.up();
    await tester.pump();
    expect(down, 0);
  });

  testWidgets('talking 态显示辉光填充（error 色边框）', (tester) async {
    await tester.pumpWidget(_wrap(PttButton(
      ptt: PttState.talking,
      enabled: true,
      label: 'TRANSMITTING',
      onDown: () {},
      onUp: () {},
    )));
    await tester.pump(const Duration(milliseconds: 200));
    final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    final deco = container.decoration as BoxDecoration;
    expect(deco.border!.top.width, 2);
  });
}
