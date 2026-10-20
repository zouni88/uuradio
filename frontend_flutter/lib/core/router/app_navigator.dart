import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/browse_category.dart';
import '../../domain/models/station_query.dart';
import '../../features/browse/discover/station_list_page.dart';
import '../../features/browse/filters/category_picker_page.dart';
import '../../features/favorites/favorites_page.dart';
import '../../features/player/widgets/player_page.dart';
import '../../features/search/search_page.dart';
import '../../features/settings/settings_page.dart';

/// 轻量路由：页面少，直接 push，不引入 go_router。
class AppNavigator {
  AppNavigator._();

  static void push(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  /// 分类电台列表页（榜单/国家/标签/语言共用）。
  static void openStationList(
    BuildContext context, {
    required String title,
    required StationQuery query,
  }) {
    push(context, StationListPage(title: title, query: query));
  }

  /// 分类选择页（国家/标签/语言），选中后回传 BrowseCategory。
  static Future<BrowseCategory?> openCategoryPicker(
    BuildContext context, {
    required CategoryKind kind,
  }) {
    return Navigator.of(context).push<BrowseCategory>(
      MaterialPageRoute(builder: (_) => CategoryPickerPage(kind: kind)),
    );
  }

  static void openSearch(BuildContext context) => push(context, const SearchPage());

  static void openFavorites(BuildContext context) =>
      push(context, const FavoritesPage());

  static void openSettings(BuildContext context) =>
      push(context, const SettingsPage());

  /// 播放页：底部上滑进场，关闭时向下滑动退场。
  static void openPlayer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const PlayerPage(),
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  static void openHomepage(BuildContext context, String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.host.contains('.')) return;
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
