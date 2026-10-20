import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/station.dart';

/// 收藏（keepAlive：全局单例，任何页面的心形操作都实时同步）。
class FavoritesController extends Notifier<List<Station>> {
  @override
  List<Station> build() => ref.watch(playRecordRepositoryProvider).favorites();

  bool isFavorite(String uuid) =>
      ref.read(playRecordRepositoryProvider).isFavorite(uuid);

  Future<void> toggle(Station station) async {
    final repo = ref.read(playRecordRepositoryProvider);
    if (repo.isFavorite(station.uuid)) {
      await repo.removeFavorite(station.uuid);
    } else {
      await repo.addFavorite(station);
    }
    state = repo.favorites();
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesController, List<Station>>(
  FavoritesController.new,
);
