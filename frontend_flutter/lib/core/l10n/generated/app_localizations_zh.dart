// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'UURadio';

  @override
  String get tabDiscover => '发现';

  @override
  String get tabSearch => '搜索';

  @override
  String get tabFavorites => '收藏';

  @override
  String get tabSettings => '设置';

  @override
  String get sectionHot => '热门电台';

  @override
  String get countries => '国家 / 地区';

  @override
  String get tags => '标签';

  @override
  String get languages => '语言';

  @override
  String get viewAll => '查看全部';

  @override
  String stationCount(int count) {
    return '$count 个电台';
  }

  @override
  String get searchHint => '搜索电台、标签、国家…';

  @override
  String get searchFilters => '筛选';

  @override
  String get bitrate => '码率';

  @override
  String get noResults => '没有找到匹配的电台';

  @override
  String get retry => '重试';

  @override
  String get loading => '加载中…';

  @override
  String get errorNetwork => '网络连接失败，请检查网络';

  @override
  String get errorGeneric => '出错了，请稍后重试';

  @override
  String get empty => '暂无内容';

  @override
  String get nowPlaying => '正在播放';

  @override
  String get paused => '已暂停';

  @override
  String get connecting => '连接中…';

  @override
  String get playbackError => '播放失败';

  @override
  String get sleepTimer => '睡眠定时器';

  @override
  String get sleepOff => '不设置';

  @override
  String sleepMinutesOption(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get visitHomepage => '访问主页';

  @override
  String nowBroadcasting(String title) {
    return '$title';
  }

  @override
  String get favoriteAdd => '加入收藏';

  @override
  String get favoriteRemove => '取消收藏';

  @override
  String get favoritesSegment => '收藏';

  @override
  String get historySegment => '最近播放';

  @override
  String get clearHistory => '清空历史';

  @override
  String get clearHistoryConfirm => '确定清空播放历史？';

  @override
  String get clear => '清空';

  @override
  String get cancel => '取消';

  @override
  String get emptyFavorites => '还没有收藏的电台。\n点击电台右侧的心形图标即可收藏。';

  @override
  String get emptyHistory => '还没有播放记录。';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get theme => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get accentColor => '主题色';

  @override
  String get minBitratePref => '最低码率偏好';

  @override
  String get bitrateAny => '不限';

  @override
  String bitrateKbps(int kbps) {
    return '$kbps kbps';
  }

  @override
  String get dataBackup => '数据与备份';

  @override
  String get exportFavorites => '导出收藏';

  @override
  String get importFavorites => '导入收藏';

  @override
  String importSuccess(int count) {
    return '已导入 $count 个电台';
  }

  @override
  String get importFailed => '导入失败';

  @override
  String get about => '关于';

  @override
  String get aboutDesc => '基于 radio-browser.info 社区数据的网络收音机播放器。';

  @override
  String get dataSource => '数据源';

  @override
  String get dataSourceAuto => '自动发现官方镜像';

  @override
  String get dataSourceDialogTitle => 'API 数据源';

  @override
  String get dataSourceHint => '留空自动发现；可填写自建 RadioBrowser 镜像域名';

  @override
  String get dataSourceInvalid => '域名格式不正确';

  @override
  String get dataSourceSaved => '数据源已更新';

  @override
  String get dataSourceReset => '已恢复自动发现';

  @override
  String get save => '保存';

  @override
  String get spectrumFallback => '麦克风权限被拒绝，已改用模拟频谱动画';
}
