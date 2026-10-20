import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/widgets/neon.dart';
import '../../../domain/models/browse_category.dart';
import '../../../l10n_helper.dart';

const double _headerH = 30;
const double _itemH = 56;

/// 微信通讯录式字母分组列表：A-Z 首字母排序 + 分组头 + 右侧字母索引条。
/// 支持点按/滑动索引条快速跳转，非 A-Z 首字母归入 # 组（置底）。
class IndexedCategoryList extends StatefulWidget {
  const IndexedCategoryList({
    super.key,
    required this.categories,
    required this.onSelect,
  });

  /// 已经过搜索过滤的列表，内部负责分组与排序。
  final List<BrowseCategory> categories;
  final ValueChanged<BrowseCategory> onSelect;

  @override
  State<IndexedCategoryList> createState() => _IndexedCategoryListState();
}

class _Section {
  const _Section(this.letter, this.items);

  final String letter;
  final List<BrowseCategory> items;
}

class _IndexedCategoryListState extends State<IndexedCategoryList> {
  final ScrollController _controller = ScrollController();
  List<_Section> _sections = const [];
  bool _dragging = false;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || _sections.isEmpty || !_controller.hasClients) return;
    final idx = _sectionAtOffset(_controller.offset);
    if (idx != _activeIndex) setState(() => _activeIndex = idx);
  }

  int _sectionAtOffset(double offset) {
    var acc = 0.0;
    for (var i = 0; i < _sections.length; i++) {
      acc += _headerH + _sections[i].items.length * _itemH;
      if (offset < acc) return i;
    }
    return _sections.length - 1;
  }

  double _offsetOfSection(int index) {
    var offset = 0.0;
    for (var i = 0; i < index && i < _sections.length; i++) {
      offset += _headerH + _sections[i].items.length * _itemH;
    }
    return offset;
  }

  void _moveTo(int barIndex, {required bool smooth}) {
    if (!_controller.hasClients || _sections.isEmpty) return;
    setState(() {
      _activeIndex = barIndex.clamp(0, _sections.length - 1);
    });
    final target =
        _offsetOfSection(barIndex).clamp(0.0, _controller.position.maxScrollExtent);
    if (smooth) {
      _controller.animateTo(target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic);
    } else {
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    _sections = _buildSections(widget.categories);
    final letters = [for (final s in _sections) s.letter];

    return Stack(
      children: [
        ListView.builder(
          controller: _controller,
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: _sections.fold<int>(
              0, (n, s) => n + 1 + s.items.length),
          itemBuilder: (context, i) {
            // 先定位所在分组，再区分组头 / 条目。
            var n = i;
            for (final s in _sections) {
              if (n == 0) return _buildHeader(s.letter, scheme);
              n--;
              if (n < s.items.length) return _buildItem(s.items[n], scheme);
              n -= s.items.length;
            }
            return const SizedBox.shrink();
          },
        ),
        if (letters.length > 1)
          Positioned(
            right: 0,
            top: 12,
            bottom: 12,
            child: _LetterBar(
              letters: letters,
              activeIndex: _activeIndex.clamp(0, letters.length - 1),
              onDrag: (i) {
                _dragging = true;
                _moveTo(i, smooth: false);
              },
              onTap: (i) => _moveTo(i, smooth: true),
              onEnd: () => setState(() => _dragging = false),
            ),
          ),
        if (_dragging && _activeIndex < _sections.length)
          IgnorePointer(
            child: Center(
              child: NeonBox(
                color: scheme.primary,
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(
                    horizontal: 26, vertical: 18),
                child: NeonText(
                  _sections[_activeIndex].letter,
                  style: const TextStyle(
                      fontSize: 34, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(String letter, ColorScheme scheme) => Container(
        height: _headerH,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.28),
        child: NeonText(
          letter,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2),
        ),
      );

  Widget _buildItem(BrowseCategory c, ColorScheme scheme) {
    final l10n = context.l10n;
    return SizedBox(
      height: _itemH,
      child: ListTile(
        leading: Text(_flagEmoji(c), style: const TextStyle(fontSize: 22)),
        title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(
          l10n.stationCount(c.stationCount),
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        onTap: () => widget.onSelect(c),
      ),
    );
  }

  /// 按首字母分组：A-Z 升序，# 组置底；组内按名称排序。
  static List<_Section> _buildSections(List<BrowseCategory> categories) {
    final map = <String, List<BrowseCategory>>{};
    for (final c in categories) {
      map.putIfAbsent(_letterOf(c.name), () => []).add(c);
    }
    final sections = [
      for (final e in map.entries)
        _Section(e.key, e.value..sort(_byName)),
    ]..sort((a, b) {
        if (a.letter == '#') return 1;
        if (b.letter == '#') return -1;
        return a.letter.compareTo(b.letter);
      });
    return sections;
  }

  static int _byName(BrowseCategory a, BrowseCategory b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  static String _letterOf(String name) {
    final s = name.trim();
    if (s.isEmpty) return '#';
    final upper = s[0].toUpperCase();
    final code = upper.codeUnitAt(0);
    return (code >= 65 && code <= 90) ? upper : '#';
  }

  static String _flagEmoji(BrowseCategory c) {
    final code = c.isoCode ?? '';
    if (code.length != 2) return '🌍';
    final base = 0x1F1E6;
    final a = code.toUpperCase().codeUnitAt(0) - 65;
    final b = code.toUpperCase().codeUnitAt(1) - 65;
    if (a < 0 || a > 25 || b < 0 || b > 25) return '🌍';
    return String.fromCharCode(base + a) + String.fromCharCode(base + b);
  }
}

/// 右侧字母索引条：支持点按与上下滑动定位。
class _LetterBar extends StatelessWidget {
  const _LetterBar({
    required this.letters,
    required this.activeIndex,
    required this.onDrag,
    required this.onTap,
    required this.onEnd,
  });

  final List<String> letters;
  final int activeIndex;
  final ValueChanged<int> onDrag;
  final ValueChanged<int> onTap;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, cons) {
        // 字母条整体垂直居中：视觉位置与下方命中计算共用同一 top/slot，
        // 压缩槽位保证不溢出。
        final slot = math.min(16.0, cons.maxHeight / letters.length);
        final total = slot * letters.length;
        final top = (cons.maxHeight - total) / 2;

        int hitIndex(Offset local) =>
            ((local.dy - top) / slot).floor().clamp(0, letters.length - 1);

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: (d) => onDrag(hitIndex(d.localPosition)),
          onVerticalDragUpdate: (d) => onDrag(hitIndex(d.localPosition)),
          onVerticalDragEnd: (_) => onEnd(),
          onTapUp: (d) => onTap(hitIndex(d.localPosition)),
          child: SizedBox(
            width: 30,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < letters.length; i++)
                  SizedBox(
                    height: slot,
                    child: Center(
                      child: Text(
                        letters[i],
                        style: TextStyle(
                          fontSize: 10,
                          height: 1,
                          fontWeight:
                              i == activeIndex ? FontWeight.w800 : FontWeight.w500,
                          color: i == activeIndex
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
