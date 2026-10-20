// 应用内双语（zh/en），对齐 Flutter 端 arb 的 54 个 key。
// 语言 = 设置值 zh/en/system；system 由 EntryAbility 按系统语言解析后写入。

export type Lang = 'zh' | 'en';

let currentLang: Lang = 'zh';

export function setL10nLang(lang: Lang): void {
  currentLang = lang;
}

export function getL10nLang(): Lang {
  return currentLang;
}

const ZH: Record<string, string> = {
  'appTitle': 'iRadio',
  'tabDiscover': '发现',
  'tabSearch': '搜索',
  'tabFavorites': '收藏',
  'tabSettings': '设置',
  'sectionHot': '热门电台',
  'countries': '国家 / 地区',
  'tags': '标签',
  'languages': '语言',
  'viewAll': '查看全部',
  'stationCount': '{count} 个电台',
  'searchHint': '搜索电台、标签、国家…',
  'searchFilters': '筛选',
  'bitrate': '码率',
  'noResults': '没有找到匹配的电台',
  'retry': '重试',
  'loading': '加载中…',
  'errorNetwork': '网络连接失败，请检查网络',
  'errorGeneric': '出错了，请稍后重试',
  'empty': '暂无内容',
  'nowPlaying': '正在播放',
  'paused': '已暂停',
  'connecting': '连接中…',
  'playbackError': '播放失败',
  'sleepTimer': '睡眠定时器',
  'sleepOff': '不设置',
  'sleepMinutesOption': '{minutes} 分钟',
  'visitHomepage': '访问主页',
  'nowBroadcasting': '{title}',
  'favoriteAdd': '加入收藏',
  'favoriteRemove': '取消收藏',
  'favoritesSegment': '收藏',
  'historySegment': '最近播放',
  'clearHistory': '清空历史',
  'clearHistoryConfirm': '确定清空播放历史？',
  'clear': '清空',
  'cancel': '取消',
  'emptyFavorites': '还没有收藏的电台。\n点击电台右侧的心形图标即可收藏。',
  'emptyHistory': '还没有播放记录。',
  'language': '语言',
  'languageSystem': '跟随系统',
  'theme': '主题',
  'themeSystem': '跟随系统',
  'themeLight': '浅色',
  'themeDark': '深色',
  'accentColor': '主题色',
  'minBitratePref': '最低码率偏好',
  'bitrateAny': '不限',
  'bitrateKbps': '{kbps} kbps',
  'dataBackup': '数据与备份',
  'exportFavorites': '导出收藏',
  'importFavorites': '导入收藏',
  'importSuccess': '已导入 {count} 个电台',
  'importFailed': '导入失败',
  'about': '关于',
  'aboutDesc': '基于 radio-browser.info 社区数据的网络收音机播放器。',
  'spectrumFallback': '麦克风权限被拒绝，已改用模拟频谱动画'
};

const EN: Record<string, string> = {
  'appTitle': 'iRadio',
  'tabDiscover': 'Discover',
  'tabSearch': 'Search',
  'tabFavorites': 'Favorites',
  'tabSettings': 'Settings',
  'sectionHot': 'Popular stations',
  'countries': 'Countries',
  'tags': 'Tags',
  'languages': 'Languages',
  'viewAll': 'View all',
  'stationCount': '{count} stations',
  'searchHint': 'Search stations, tags, countries…',
  'searchFilters': 'Filters',
  'bitrate': 'Bitrate',
  'noResults': 'No stations found',
  'retry': 'Retry',
  'loading': 'Loading…',
  'errorNetwork': 'Network error. Please check your connection.',
  'errorGeneric': 'Something went wrong. Please try again.',
  'empty': 'Nothing here yet',
  'nowPlaying': 'Now playing',
  'paused': 'Paused',
  'connecting': 'Connecting…',
  'playbackError': 'Playback failed',
  'sleepTimer': 'Sleep timer',
  'sleepOff': 'Off',
  'sleepMinutesOption': '{minutes} min',
  'visitHomepage': 'Visit homepage',
  'nowBroadcasting': '{title}',
  'favoriteAdd': 'Add to favorites',
  'favoriteRemove': 'Remove from favorites',
  'favoritesSegment': 'Favorites',
  'historySegment': 'Recent',
  'clearHistory': 'Clear history',
  'clearHistoryConfirm': 'Clear play history?',
  'clear': 'Clear',
  'cancel': 'Cancel',
  'emptyFavorites': 'No favorites yet.\nTap the heart on any station to save it here.',
  'emptyHistory': 'No play history yet.',
  'language': 'Language',
  'languageSystem': 'System default',
  'theme': 'Theme',
  'themeSystem': 'System',
  'themeLight': 'Light',
  'themeDark': 'Dark',
  'accentColor': 'Accent color',
  'minBitratePref': 'Preferred bitrate',
  'bitrateAny': 'Any',
  'bitrateKbps': '{kbps} kbps',
  'dataBackup': 'Data & backup',
  'exportFavorites': 'Export favorites',
  'importFavorites': 'Import favorites',
  'importSuccess': 'Imported {count} stations',
  'importFailed': 'Import failed',
  'about': 'About',
  'aboutDesc': 'A network radio player powered by the radio-browser.info community.',
  'spectrumFallback': 'Microphone permission denied — using simulated visualizer'
};

/// 取文案（ArkTS 严格模式：不提供可选参数重载，避免调用点对象字面量报错）。
export function t(key: string): string {
  const table = currentLang === 'zh' ? ZH : EN;
  return table[key] ?? ZH[key] ?? key;
}

/// 取文案并替换单个 {占位符}（替代带 Record 参数的 t，规避 arkts-no-untyped-obj-literals）。
export function tf(key: string, k: string, v: string): string {
  return t(key).split(`{${k}}`).join(v);
}
