import 'package:flutter/material.dart';

/// Theme extension providing a 5-level activity heatmap color scale
/// (index 0 = no activity, 1..4 increasing intensity).
/// Added so widgets like `ActivityGraphWidget` can obtain consistent
/// colors for light & dark mode without hardcoding color values.
class ActivityHeatmapColors extends ThemeExtension<ActivityHeatmapColors> {
  final List<Color> levels; // length 5

  const ActivityHeatmapColors({required this.levels})
      : assert(levels.length == 5);

  factory ActivityHeatmapColors.light() => ActivityHeatmapColors(levels: [
        Color(0xFFE0E0E0), // empty
        Colors.grey[400]!, // low
        Colors.grey[500]!, // medium
        Colors.grey[700]!, // high
        Colors.grey[900]!, // very high
      ]);

  factory ActivityHeatmapColors.dark() => ActivityHeatmapColors(levels: [
        Color(0xFF424242), // empty
        Colors.grey[600]!, // low
        Colors.grey[500]!, // medium
        Colors.grey[400]!, // high
        Colors.grey[300]!, // very high
      ]);

  @override
  ActivityHeatmapColors copyWith({List<Color>? levels}) {
    return ActivityHeatmapColors(levels: levels ?? this.levels);
  }

  @override
  ThemeExtension<ActivityHeatmapColors> lerp(
      covariant ThemeExtension<ActivityHeatmapColors>? other, double t) {
    if (other is! ActivityHeatmapColors) return this;
    return ActivityHeatmapColors(
      levels: List.generate(
          levels.length, (i) => Color.lerp(levels[i], other.levels[i], t)!),
    );
  }
}

ThemeData appThemeLight = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.grey,
    brightness: Brightness.light,
  ),
  primaryColor: Colors.black,
  canvasColor: Colors.grey[300],
  secondaryHeaderColor: Colors.black,
  scaffoldBackgroundColor: Colors.white,
  extensions: <ThemeExtension<dynamic>>[
    ActivityHeatmapColors.light(),
  ],
  appBarTheme: AppBarThemeData(
    foregroundColor: Colors.black,
    backgroundColor: Colors.white,
    titleTextStyle: const TextStyle(color: Colors.black),
    elevation: 0,
    surfaceTintColor: Colors.transparent,
  ),
  primaryTextTheme: textThemeLight(),
  textTheme: textThemeLight(),
  buttonTheme: ButtonThemeData(
    buttonColor: Colors.black,
    textTheme: ButtonTextTheme.primary,
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: Colors.black,
    foregroundColor: Colors.white,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
    backgroundColor: const WidgetStatePropertyAll(Colors.black),
    foregroundColor: const WidgetStatePropertyAll(Colors.white),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(fontSize: 16, color: Colors.white),
    ),
  )),
  iconButtonTheme: IconButtonThemeData(
    style: ButtonStyle(
      foregroundColor: const WidgetStatePropertyAll(Colors.white),
      backgroundColor: const WidgetStatePropertyAll(Colors.black),
    ),
  ),
  cardColor: Colors.grey[100],
  cardTheme: CardThemeData(
    color: Colors.grey[100],
    surfaceTintColor: Colors.transparent,
  ),
  progressIndicatorTheme: ProgressIndicatorThemeData(
    color: Colors.black,
  ),
  iconTheme: IconThemeData(color: Colors.black),
  primaryIconTheme: IconThemeData(color: Colors.black),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.black26, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.black, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.black26, width: 1.5),
    ),
  ),
  dialogTheme: DialogThemeData(backgroundColor: Colors.white),
  dividerColor: Colors.grey[300],
);

ThemeData appThemeDark = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.grey,
      brightness: Brightness.dark,
    ),
    primaryColor: Colors.white,
    canvasColor: Colors.grey[850],
    secondaryHeaderColor: Colors.white,
    scaffoldBackgroundColor: const Color(0xFF121212),
    extensions: <ThemeExtension<dynamic>>[
      ActivityHeatmapColors.dark(),
    ],
    appBarTheme: AppBarTheme(
      foregroundColor: Colors.white,
      backgroundColor: const Color(0xFF121212),
      titleTextStyle: const TextStyle(color: Colors.white),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: Colors.white,
      textTheme: ButtonTextTheme.primary,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: Colors.white,
    ),
    iconTheme: IconThemeData(
      color: Colors.white,
    ),
    primaryIconTheme: IconThemeData(color: Colors.white),
    elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
      backgroundColor: const WidgetStatePropertyAll(Colors.white),
      foregroundColor: const WidgetStatePropertyAll(Colors.black),
      textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 16, color: Colors.black)),
    )),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(Colors.black),
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.grey[900],
      surfaceTintColor: Colors.transparent,
    ),
    cardColor: Colors.grey[900],
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24, width: 1.5),
      ),
      labelStyle: TextStyle(color: Colors.white),
    ),
    primaryTextTheme: textThemeDark(),
    textTheme: textThemeDark(),
    dividerColor: Colors.grey[700],
    dialogTheme: DialogThemeData(backgroundColor: Colors.grey[900]));

TextTheme textThemeLight() {
  return TextTheme(
    titleLarge: TextStyle(
      color: Colors.black,
      fontSize: 23,
      height: 1.2,
      fontWeight: FontWeight.bold,
    ),
    titleMedium: TextStyle(
      color: Colors.black,
      fontSize: 20,
      height: 1.1,
      fontWeight: FontWeight.bold,
    ),
    titleSmall: TextStyle(
      color: Colors.black,
      fontSize: 14,
    ),
    displayLarge: TextStyle(
      color: Colors.black,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
    displayMedium: TextStyle(
      color: Colors.black,
      fontSize: 12,
    ),
    displaySmall: TextStyle(
      color: Colors.black,
      fontSize: 15,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(
      color: Colors.black,
      fontSize: 30,
      fontWeight: FontWeight.bold,
    ),
    bodySmall: TextStyle(
      color: Colors.black,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: TextStyle(
      color: Colors.black,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: TextStyle(
      color: Colors.black,
      fontSize: 16,
      fontWeight: FontWeight.normal,
    ),
    labelSmall: TextStyle(color: Colors.black, fontSize: 12),
  );
}

TextTheme textThemeDark() {
  return TextTheme(
    titleLarge: TextStyle(
      color: Colors.white,
      fontSize: 23,
      height: 1.2,
      fontWeight: FontWeight.bold,
    ),
    titleMedium: TextStyle(
      color: Colors.white,
      fontSize: 20,
      height: 1.1,
      fontWeight: FontWeight.bold,
    ),
    titleSmall: TextStyle(
      color: Colors.white,
      fontSize: 14,
    ),
    displayLarge: TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
    displayMedium: TextStyle(
      color: Colors.white,
      fontSize: 12,
    ),
    displaySmall: TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(
      color: Colors.white,
      fontSize: 30,
      fontWeight: FontWeight.bold,
    ),
    bodySmall: TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.normal,
    ),
    labelSmall: TextStyle(color: Colors.white, fontSize: 12),
  );
}
