import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iradio/domain/models/station.dart';
import 'package:iradio/features/player/player_controller.dart';

Station _s(String uuid) =>
    Station(uuid: uuid, name: uuid, streamUrl: 'https://x/$uuid');

void main() {
  group('TuningBandController 续载', () {
    test('分页来源：loadMore 增长波段', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final pages = [
        [_s('a'), _s('b')],
        [_s('a'), _s('b'), _s('c')],
      ];
      var call = 0;
      container.read(tuningBandProvider.notifier).set(
        pages[0],
        loadMore: () async => pages[++call],
      );
      expect(container.read(tuningBandProvider).length, 2);
      await container.read(tuningBandProvider.notifier).loadMore();
      expect(container.read(tuningBandProvider).length, 3);
    });

    test('固定列表（无回调）：loadMore 空操作', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(tuningBandProvider.notifier).set([_s('a')]);
      await container.read(tuningBandProvider.notifier).loadMore();
      expect(container.read(tuningBandProvider).length, 1);
    });

    test('加载中重入：回调只执行一次', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var calls = 0;
      container.read(tuningBandProvider.notifier).set(
        [_s('a')],
        loadMore: () async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return [_s('a'), _s('b')];
        },
      );
      final f1 = container.read(tuningBandProvider.notifier).loadMore();
      final f2 = container.read(tuningBandProvider.notifier).loadMore();
      await Future.wait([f1, f2]);
      expect(calls, 1);
    });

    test('来源耗尽：不再增长后清除 canLoadMore（允许末尾回卷）', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctrl = container.read(tuningBandProvider.notifier);
      ctrl.set([_s('a')], loadMore: () async => [_s('a')]);
      expect(ctrl.canLoadMore, true);
      await ctrl.loadMore();
      expect(ctrl.canLoadMore, false);
    });

    test('回调瞬时返回 null：保留续载回调可重试', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctrl = container.read(tuningBandProvider.notifier);
      var calls = 0;
      ctrl.set(
        [_s('a')],
        loadMore: () async => (++calls == 1) ? null : [_s('a'), _s('b')],
      );
      await ctrl.loadMore();
      expect(ctrl.canLoadMore, true);
      await ctrl.loadMore();
      expect(container.read(tuningBandProvider).length, 2);
    });

    test('切到新的固定波段会清除续载回调', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(tuningBandProvider.notifier).set(
        [_s('a')],
        loadMore: () async => [_s('a'), _s('b')],
      );
      container.read(tuningBandProvider.notifier).set([_s('x')]);
      await container.read(tuningBandProvider.notifier).loadMore();
      expect(container.read(tuningBandProvider).length, 1);
      expect(container.read(tuningBandProvider).first.uuid, 'x');
    });
  });
}
