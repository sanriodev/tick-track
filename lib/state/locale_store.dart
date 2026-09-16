import 'package:ticktrack/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

class LocaleStore {
  static const String _boxName = 'settings';
  static const String _localeKey = 'locale';

  static Future<void> openBox() async {
    await Hive.openBox(_boxName);
  }

  Locale resolveStartupLocale() => _storedLocale() ?? _deviceLocale();

  Future<void> save(Locale locale) async {
    if (!Hive.isBoxOpen(_boxName)) return;
    await Hive.box(_boxName).put(_localeKey, locale.languageCode);
  }

  Future<void> applyToDateFormatting(Locale locale) async {
    await initializeDateFormatting(locale.languageCode);
    Intl.defaultLocale = locale.languageCode;
  }

  Locale? _storedLocale() {
    if (!Hive.isBoxOpen(_boxName)) return null;
    final code = Hive.box(_boxName).get(_localeKey);
    if (code is! String) return null;
    return _supportedLocaleFor(code);
  }

  Locale _deviceLocale() {
    for (final locale in WidgetsBinding.instance.platformDispatcher.locales) {
      final supported = _supportedLocaleFor(locale.languageCode);
      if (supported != null) return supported;
    }
    return fallbackLocale;
  }

  Locale? _supportedLocaleFor(String languageCode) {
    for (final language in appLanguages) {
      if (language.code == languageCode) return language.locale;
    }
    return null;
  }
}
