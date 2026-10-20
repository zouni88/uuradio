import 'package:flutter/widgets.dart';

import 'core/l10n/generated/app_localizations.dart';

export 'core/l10n/generated/app_localizations.dart';

/// 便捷取 AppLocalizations。
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
