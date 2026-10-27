import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../domain/models/browse_category.dart';
import '../../../l10n_helper.dart';
import '../discover/discover_controller.dart';
import 'indexed_category_list.dart';

/// 分类选择页种类。
enum CategoryKind { country, tag, language }

/// 国家 / 标签 / 语言 通用选择页，选中后 pop 回传 BrowseCategory。
class CategoryPickerPage extends ConsumerStatefulWidget {
  const CategoryPickerPage({super.key, required this.kind});

  final CategoryKind kind;

  @override
  ConsumerState<CategoryPickerPage> createState() => _CategoryPickerPageState();
}

class _CategoryPickerPageState extends ConsumerState<CategoryPickerPage> {
  String _filter = '';

  AsyncValue<List<BrowseCategory>> _source(WidgetRef ref) {
    return switch (widget.kind) {
      CategoryKind.country => ref.watch(countriesProvider),
      CategoryKind.tag => ref.watch(tagsProvider),
      CategoryKind.language => ref.watch(languagesProvider),
    };
  }

  void _retry() {
    ref.invalidate(countriesProvider);
    ref.invalidate(tagsProvider);
    ref.invalidate(languagesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = switch (widget.kind) {
      CategoryKind.country => l10n.countries,
      CategoryKind.tag => l10n.tags,
      CategoryKind.language => l10n.languages,
    };
    final scheme = Theme.of(context).colorScheme;
    final async = _source(ref);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: title,
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => ListView(
                  children: [StationListSkeleton.fill(context)]),
              error: (error, _) =>
                  ErrorRetryView(error: error, onRetry: _retry),
              data: (categories) {
                final filtered = _filter.isEmpty
                    ? categories
                    : categories
                        .where((c) => c.name.toLowerCase().contains(_filter))
                        .toList();
                // 国家/地区：常用置顶 + 字母分组；搜索时按电台数降序（大国优先）。
                if (widget.kind == CategoryKind.country) {
                  return _countryList(filtered);
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final category = filtered[index];
                    return ListTile(
                      leading: Icon(
                        widget.kind == CategoryKind.tag
                            ? Icons.local_offer_rounded
                            : Icons.language_rounded,
                        size: 20,
                        color: scheme.primary,
                      ),
                      title: Text(category.name),
                      trailing: Text(
                        l10n.stationCount(category.stationCount),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(category),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _selectCountry(BrowseCategory c) {
    ref.read(countryUsageProvider.notifier).record(c.isoCode ?? '');
    Navigator.of(context).pop(c);
  }

  Widget _countryList(List<BrowseCategory> filtered) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    // 搜索态：大国（电台数量多）排前面，平铺列表。
    if (_filter.isNotEmpty) {
      final sorted = [...filtered]
        ..sort((a, b) => b.stationCount.compareTo(a.stationCount));
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: sorted.length,
        itemBuilder: (context, i) {
          final c = sorted[i];
          return ListTile(
            leading: Text(countryFlagEmoji(c),
                style: const TextStyle(fontSize: 22)),
            title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text(
              l10n.stationCount(c.stationCount),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            onTap: () => _selectCountry(c),
          );
        },
      );
    }

    final frequent = _frequentOf(filtered);
    final rest = frequent.isEmpty
        ? filtered
        : filtered
            .where((c) => !frequent.any((f) => f.isoCode == c.isoCode))
            .toList();
    return Column(
      children: [
        if (frequent.isNotEmpty)
          _FrequentBar(countries: frequent, onSelect: _selectCountry),
        Expanded(
          child: IndexedCategoryList(
            categories: rest,
            onSelect: _selectCountry,
          ),
        ),
      ],
    );
  }

  /// 常用国家：历史优先，设备国家其次，不足时按电台数最多的大国兜底，上限 8。
  List<BrowseCategory> _frequentOf(List<BrowseCategory> all) {
    const cap = 8;
    final usage = ref.watch(countryUsageProvider);
    final byCode = <String, BrowseCategory>{
      for (final c in all)
        if (c.isoCode != null && c.isoCode!.isNotEmpty)
          c.isoCode!.toUpperCase(): c,
    };
    final result = <BrowseCategory>[];
    final seen = <String>{};

    void add(BrowseCategory c) {
      final code = c.isoCode?.toUpperCase();
      if (code == null || code.isEmpty || !seen.add(code)) return;
      result.add(c);
    }

    // 历史优先（次数降序，同次数按电台数降序），最多占 cap-1 席。
    final history = usage.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return (byCode[b.key.toUpperCase()]?.stationCount ?? 0)
            .compareTo(byCode[a.key.toUpperCase()]?.stationCount ?? 0);
      });
    for (final e in history) {
      if (result.length >= cap - 1) break;
      final c = byCode[e.key.toUpperCase()];
      if (c != null) add(c);
    }

    // 设备国家。
    final device = byCode[deviceCountryCode().toUpperCase()];
    if (device != null && result.length < cap) add(device);

    // 大国兜底。
    if (result.length < cap) {
      final tops = [...all]
        ..sort((a, b) => b.stationCount.compareTo(a.stationCount));
      for (final c in tops) {
        if (result.length >= cap) break;
        add(c);
      }
    }
    return result;
  }
}

/// 常用国家横滑胶囊条。
class _FrequentBar extends StatelessWidget {
  const _FrequentBar({required this.countries, required this.onSelect});

  final List<BrowseCategory> countries;
  final ValueChanged<BrowseCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            l10n.commonCountries,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: scheme.primary,
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: countries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = countries[i];
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: Material(
                  color:
                      scheme.surfaceContainerHigh.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(19),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(19),
                    onTap: () => onSelect(c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(countryFlagEmoji(c),
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13, color: scheme.onSurface),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Divider(
          height: 17,
          thickness: 0.5,
          indent: 16,
          endIndent: 16,
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ],
    );
  }
}

