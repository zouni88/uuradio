import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_navigator.dart';
import '../../core/widgets/error_retry_view.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/station_tile.dart';
import '../../l10n_helper.dart';
import '../../domain/models/browse_category.dart';
import '../../domain/models/station_query.dart';
import '../browse/discover/station_list_controller.dart';
import '../browse/filters/category_picker_page.dart';
import '../player/player_controller.dart';
import '../settings/settings_controller.dart';

/// 搜索页：名称搜索（防抖）+ 码率/分类过滤。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  StationListProvider? _provider;

  BrowseCategory? _country;
  BrowseCategory? _tag;
  BrowseCategory? _language;

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _refreshProvider);
  }

  void _refreshProvider() {
    final text = _textController.text.trim();
    setState(() {
      _provider =
          text.isEmpty ? null : makeStationListProvider(_buildQuery(text));
    });
  }

  StationQuery _buildQuery(String text) {
    final settings = ref.read(settingsProvider);
    return StationQuery(
      name: text,
      order: StationQuery.orderByClicks,
      reverse: true,
      countryCode: _country?.isoCode ?? '',
      tag: _tag?.name ?? '',
      language: _language?.name ?? '',
      minBitrate: settings.minBitrate > 0 ? settings.minBitrate : null,
    );
  }

  Future<void> _pickCategory(CategoryKind kind) async {
    final picked = await AppNavigator.openCategoryPicker(context, kind: kind);
    if (picked == null) return;
    setState(() {
      switch (kind) {
        case CategoryKind.country:
          _country = picked;
        case CategoryKind.tag:
          _tag = picked;
        case CategoryKind.language:
          _language = picked;
      }
    });
    if (_textController.text.trim().isNotEmpty) _refreshProvider();
  }

  void _setBitrate(int? bitrate) {
    ref.read(settingsProvider.notifier).setMinBitrate(bitrate ?? 0);
    if (_textController.text.trim().isNotEmpty) _refreshProvider();
  }

  void _chooseBitrate() {
    final l10n = context.l10n;
    final active = ref.read(settingsProvider).minBitrate;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in const [0, 64, 128, 192])
              ListTile(
                leading: Icon(
                  active == option
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 20,
                ),
                title: Text(option == 0
                    ? l10n.bitrateAny
                    : l10n.bitrateKbps(option)),
                onTap: () {
                  Navigator.of(context).pop();
                  _setBitrate(option);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final activeBitrate = settings.minBitrate;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabSearch)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              onChanged: _onTextChanged,
              onSubmitted: (_) => _refreshProvider(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _textController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () {
                          _textController.clear();
                          setState(() => _provider = null);
                        },
                      ),
                hintText: l10n.searchHint,
              ),
            ),
          ),
          // 过滤行
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: _country?.name ?? l10n.countries,
                  active: _country != null,
                  onTap: () => _pickCategory(CategoryKind.country),
                  onCleared: () =>
                      setState(() => _country = null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: _tag?.name ?? l10n.tags,
                  active: _tag != null,
                  onTap: () => _pickCategory(CategoryKind.tag),
                  onCleared: () => setState(() => _tag = null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: _language?.name ?? l10n.languages,
                  active: _language != null,
                  onTap: () => _pickCategory(CategoryKind.language),
                  onCleared: () => setState(() => _language = null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: activeBitrate > 0,
                  showCheckmark: false,
                  label: Text(
                    activeBitrate > 0
                        ? l10n.bitrateKbps(activeBitrate)
                        : l10n.minBitratePref,
                    style: const TextStyle(fontSize: 13),
                  ),
                  onSelected: (_) => _chooseBitrate(),
                ),
              ],
            ),
          ),
          Expanded(
            child: _provider == null
                ? Center(
                    child: Icon(Icons.search_rounded,
                        size: 56,
                        color: scheme.primary.withValues(alpha: 0.35)),
                  )
                : StationListView(provider: _provider!),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.onCleared,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: active,
      showCheckmark: false,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          if (active) ...[
            const SizedBox(width: 2),
            InkWell(
              onTap: onCleared,
              child: const Icon(Icons.close_rounded, size: 15),
            ),
          ],
        ],
      ),
      onSelected: (_) => onTap(),
    );
  }
}

/// 复用分页列表内容（无 AppBar 的 StationListPage 主体）。
class StationListView extends ConsumerWidget {
  const StationListView({super.key, required this.provider});

  final StationListProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(provider);
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axisDirection == AxisDirection.down &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 400) {
          ref.read(provider.notifier).loadMore();
        }
        return false;
      },
      child: async.when(
        loading: () => ListView(
            children: [StationListSkeleton.fill(context)]),
        error: (error, _) =>
            ErrorRetryView(error: error, onRetry: () => ref.invalidate(provider)),
        data: (stations) {
          if (stations.isEmpty) {
            return Center(
              child: Text(
                l10n.noResults,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            itemCount: stations.length + 1,
            itemBuilder: (context, index) {
              if (index == stations.length) {
                // 加载更多：行骨架占位，不用转圈。
                return const StationTileSkeleton();
              }
              final station = stations[index];
              return StationTile(
                station: station,
                onTap: () => ref.playFromBand(station, stations),
              );
            },
          );
        },
      ),
    );
  }
}
