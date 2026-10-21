import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iradio/features/player/widgets/shuttle_drum.dart';

void main() {
  testWidgets('纵向飞梭在 Row 中填满高度并正常渲染', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 715,
            height: 295,
            child: Row(
              children: [
                const Expanded(child: SizedBox.shrink()),
                ShuttleDrum(
                  width: 56,
                  axis: Axis.vertical,
                  onStep: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final box = tester.renderObject<RenderBox>(
      find.descendant(
        of: find.byType(ShuttleDrum),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(box.size, const Size(56, 295));
    expect(tester.takeException(), isNull);
  });

  testWidgets('纵向飞梭上下拨动触发步进', (tester) async {
    final steps = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 715,
            height: 295,
            child: Row(
              children: [
                Expanded(
                  child: ShuttleDrum(
                    width: 56,
                    axis: Axis.vertical,
                    onStep: steps.add,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 上拨 60px（> 4 格）应产生 +1（下一台）步进。
    await tester.drag(
      find.byType(ShuttleDrum),
      const Offset(0, -60),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(steps, contains(1));
  });
}
