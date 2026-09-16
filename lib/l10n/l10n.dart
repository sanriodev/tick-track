import 'package:ticktrack/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';

export 'package:ticktrack/l10n/generated/app_localizations.dart';

extension LocalizationsExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

class AppLanguage {
  final Locale locale;
  final String nativeName;

  const AppLanguage({required this.locale, required this.nativeName});

  String get code => locale.languageCode;
}

const List<AppLanguage> appLanguages = [
  AppLanguage(locale: Locale('en'), nativeName: 'English'),
  AppLanguage(locale: Locale('de'), nativeName: 'Deutsch'),
];

const Locale fallbackLocale = Locale('en');
