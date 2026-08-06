import 'package:ticktrack/screens/home/main_app_screen.dart';
import 'package:ticktrack/state/reminder_scheduler.dart';
import 'package:blvckleg_dart_core/util/util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await registerDartCore();
  await Hive.openBox('theme');
  await Hive.openBox('groupContext');
  await Hive.openBox('pins');
  await Hive.openBox('avatars');

  initializeDateFormatting('de_DE');
  Intl.defaultLocale = 'de_DE';

  await ReminderScheduler().init();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const MainAppScreen());
}
