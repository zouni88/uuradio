// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'iRadio';

  @override
  String get tabDiscover => 'Discover';

  @override
  String get tabSearch => 'Search';

  @override
  String get tabFavorites => 'Favorites';

  @override
  String get tabSettings => 'Settings';

  @override
  String get sectionHot => 'Popular stations';

  @override
  String get countries => 'Countries';

  @override
  String get tags => 'Tags';

  @override
  String get languages => 'Languages';

  @override
  String get viewAll => 'View all';

  @override
  String stationCount(int count) {
    return '$count stations';
  }

  @override
  String get searchHint => 'Search stations, tags, countries…';

  @override
  String get searchFilters => 'Filters';

  @override
  String get bitrate => 'Bitrate';

  @override
  String get noResults => 'No stations found';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading…';

  @override
  String get errorNetwork => 'Network error. Please check your connection.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get empty => 'Nothing here yet';

  @override
  String get nowPlaying => 'Now playing';

  @override
  String get paused => 'Paused';

  @override
  String get connecting => 'Connecting…';

  @override
  String get playbackError => 'Playback failed';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String get sleepOff => 'Off';

  @override
  String sleepMinutesOption(int minutes) {
    return '$minutes min';
  }

  @override
  String get visitHomepage => 'Visit homepage';

  @override
  String nowBroadcasting(String title) {
    return '$title';
  }

  @override
  String get favoriteAdd => 'Add to favorites';

  @override
  String get favoriteRemove => 'Remove from favorites';

  @override
  String get favoritesSegment => 'Favorites';

  @override
  String get historySegment => 'Recent';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get clearHistoryConfirm => 'Clear play history?';

  @override
  String get clear => 'Clear';

  @override
  String get cancel => 'Cancel';

  @override
  String get emptyFavorites =>
      'No favorites yet.\nTap the heart on any station to save it here.';

  @override
  String get emptyHistory => 'No play history yet.';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get accentColor => 'Accent color';

  @override
  String get minBitratePref => 'Preferred bitrate';

  @override
  String get bitrateAny => 'Any';

  @override
  String bitrateKbps(int kbps) {
    return '$kbps kbps';
  }

  @override
  String get dataBackup => 'Data & backup';

  @override
  String get exportFavorites => 'Export favorites';

  @override
  String get importFavorites => 'Import favorites';

  @override
  String importSuccess(int count) {
    return 'Imported $count stations';
  }

  @override
  String get importFailed => 'Import failed';

  @override
  String get about => 'About';

  @override
  String get aboutDesc =>
      'A network radio player powered by the radio-browser.info community.';

  @override
  String get dataSource => 'Data source';

  @override
  String get dataSourceAuto => 'Auto-discover mirrors';

  @override
  String get dataSourceDialogTitle => 'API data source';

  @override
  String get dataSourceHint =>
      'Leave empty to auto-discover, or enter a self-hosted RadioBrowser mirror host';

  @override
  String get dataSourceInvalid => 'Invalid host format';

  @override
  String get dataSourceSaved => 'Data source updated';

  @override
  String get dataSourceReset => 'Auto-discovery restored';

  @override
  String get save => 'Save';

  @override
  String get spectrumFallback =>
      'Microphone permission denied — using simulated visualizer';
}
