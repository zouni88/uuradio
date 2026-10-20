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
                // 国家/地区：微信通讯录式字母分组 + 快速索引。
                if (widget.kind == CategoryKind.country) {
                  return IndexedCategoryList(
                    categories: filtered,
                    onSelect: Navigator.of(context).pop,
                  );
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
}

