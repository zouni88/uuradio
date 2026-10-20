import 'package:flutter/material.dart';

/// 骨架屏基础块：呼吸脉冲占位块。
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = 12,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.3,
    end: 0.85,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// 电台列表行骨架（对应 StationTile 布局）。
class StationTileSkeleton extends StatelessWidget {
  const StationTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: const Row(
          children: [
            Skeleton(width: 44, height: 44),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 12, width: 140, radius: 6),
                  SizedBox(height: 8),
                  Skeleton(height: 10, width: 90, radius: 5),
                ],
              ),
            ),
            SizedBox(width: 12),
            Skeleton(width: 22, height: 22, radius: 8),
          ],
        ),
      ),
    );
  }
}

/// 电台列表加载骨架：[itemCount] 行占位。
class StationListSkeleton extends StatelessWidget {
  const StationListSkeleton({super.key, this.itemCount = 6});

  /// 行数按视口高度估算，保证铺满整个屏幕（单行高约 72）。
  factory StationListSkeleton.fill(BuildContext context) =>
      StationListSkeleton(
        itemCount: (MediaQuery.sizeOf(context).height / 72).ceil(),
      );

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < itemCount; i++) const StationTileSkeleton(),
      ],
    );
  }
}

/// 热门横滑卡片骨架（对应发现页 _HotCard 布局）。
class HotCardSkeleton extends StatelessWidget {
  const HotCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 132,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.07),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: Skeleton(width: 84, height: 84, radius: 18)),
          const Spacer(),
          Skeleton(height: 12, width: 96, radius: 6),
          const SizedBox(height: 6),
          Skeleton(height: 10, width: 72, radius: 5),
        ],
      ),
    );
  }
}

/// 热门横滑加载骨架：一排卡片占位。
class HotRailSkeleton extends StatelessWidget {
  const HotRailSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => const HotCardSkeleton(),
      ),
    );
  }
}
