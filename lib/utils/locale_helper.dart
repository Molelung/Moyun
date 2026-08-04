import 'package:daily_you/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';

/// Resolves the device locale to a supported app locale, falling back to
/// English when the device language is not supported.
Locale resolveDeviceLocale() {
  final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
  if (AppLocalizations.delegate.isSupported(deviceLocale)) {
    return deviceLocale;
  }
  final langOnly = Locale(deviceLocale.languageCode);
  return AppLocalizations.delegate.isSupported(langOnly)
      ? langOnly
      : const Locale('en');
}

/// Loads the app's localizations for the device locale.
Future<AppLocalizations> loadDeviceLocalizations() =>
    AppLocalizations.delegate.load(resolveDeviceLocale());
