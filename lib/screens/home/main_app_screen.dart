import 'package:ticktrack/routes/routes.dart';
import 'package:ticktrack/state/reminder_sync.dart';
import 'package:ticktrack/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();

  static _MainAppScreenState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MainAppScreenState>();
}

class _MainAppScreenState extends State<MainAppScreen> {
  ThemeMode? currentTheme;
  late final GoRouter _router;
  late final AppLifecycleListener _lifecycleListener;

  void changeTheme(ThemeMode themeMode) {
    final themeBox = Hive.box('theme');
    if (themeMode == ThemeMode.light) {
      themeBox.put('theme', 'light');
    } else if (themeMode == ThemeMode.dark) {
      themeBox.put('theme', 'dark');
    } else {
      themeBox.put('theme', 'light');
    }
    setState(() {
      currentTheme = themeMode;
    });
  }

  ThemeMode _getThemeMode() {
    final theme = Hive.box('theme');
    if (theme.get('theme') == null) {
      theme.put('theme', 'light');
      return ThemeMode.light;
    }
    if (theme.get('theme') == 'light') {
      return ThemeMode.light;
    } else {
      return ThemeMode.dark;
    }
  }

  @override
  void initState() {
    super.initState();
    currentTheme = _getThemeMode();
    _router = createRouter();
    _lifecycleListener = AppLifecycleListener(
      onResume: () => ReminderSync().sync(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TickTrack',
      debugShowCheckedModeBanner: false,
      themeMode: currentTheme,
      theme: appThemeLight,
      darkTheme: appThemeDark,
      locale: const Locale('de', 'DE'),
      supportedLocales: const [Locale('de', 'DE')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
    );
  }
}
