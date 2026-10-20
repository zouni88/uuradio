import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/play_history_entry.dart';

/// 播放历史（keepAlive：全局单例，播放器写入、页面读取）。
class HistoryController extends Notifier<List<PlayHistoryEntry>> {
  @override
  List<PlayHistoryEntry> build() =>
      ref.watch(playRecordRepositoryProvider).history();

  void refresh() => state = ref.read(playRecordRepositoryProvider).history();

  Future<void> clear() async {
    await ref.read(playRecordRepositoryProvider).clearHistory();
    refresh();
  }
}

final historyProvider =
    NotifierProvider<HistoryController, List<PlayHistoryEntry>>(
  HistoryController.new,
);
