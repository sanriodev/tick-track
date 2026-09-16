import 'package:ticktrack/screens/home/main_app_screen.dart';
import 'package:ticktrack/state/cache_store.dart';
import 'package:ticktrack/state/locale_store.dart';
import 'package:ticktrack/state/reminder_scheduler.dart';
import 'package:blvckleg_dart_core/util/util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await registerDartCore();
  await Hive.openBox('theme');
  await Hive.openBox('groupContext');
  await Hive.openBox('pins');
  await Hive.openBox('avatars');
  await CacheStore.openBox();
  await LocaleStore.openBox();

  final startupLocale = LocaleStore().resolveStartupLocale();
  await LocaleStore().applyToDateFormatting(startupLocale);

  await ReminderScheduler().init();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(MainAppScreen(startupLocale: startupLocale));
}
