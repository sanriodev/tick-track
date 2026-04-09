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
  primaryColor: Colors.grey[700],
  canvasColor: Colors.grey[300],
  secondaryHeaderColor: Colors.grey[700],
  scaffoldBackgroundColor: Colors.grey[200],
  extensions: <ThemeExtension<dynamic>>[
    ActivityHeatmapColors.light(),
  ],
  appBarTheme: AppBarThemeData(
    foregroundColor: Colors.grey[700],
    backgroundColor: Colors.grey[200],
    titleTextStyle: TextStyle(color: Colors.grey[800]),
    elevation: 0,
    surfaceTintColor: Colors.transparent,
  ),
  primaryTextTheme: textThemeLight(),
  textTheme: textThemeLight(),
  buttonTheme: ButtonThemeData(
    buttonColor: Colors.grey[700],
    textTheme: ButtonTextTheme.primary,
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: Colors.grey[700],
    foregroundColor: Colors.white,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(Colors.grey[700]),
    foregroundColor: const WidgetStatePropertyAll(Colors.white),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(fontSize: 16, color: Colors.white),
    ),
  )),
  iconButtonTheme: IconButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(Colors.grey[700]),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  ),
  cardColor: Colors.grey[100],
  cardTheme: CardThemeData(
    color: Colors.grey[100],
    surfaceTintColor: Colors.transparent,
  ),
  progressIndicatorTheme: ProgressIndicatorThemeData(
    color: Colors.grey[700],
  ),
  iconTheme: IconThemeData(color: Colors.grey[700]),
  primaryIconTheme: IconThemeData(color: Colors.grey[700]),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey[400]!, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey[700]!, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey[400]!, width: 1.5),
    ),
  ),
  dialogTheme: DialogThemeData(backgroundColor: Colors.grey[100]),
  dividerColor: Colors.grey[400],
);

ThemeData appThemeDark = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.grey,
      brightness: Brightness.dark,
    ),
    primaryColor: Colors.grey[900],
    canvasColor: Colors.grey[800],
    secondaryHeaderColor: Colors.grey[900],
    scaffoldBackgroundColor: const Color(0xFF303030),
    extensions: <ThemeExtension<dynamic>>[
      ActivityHeatmapColors.dark(),
    ],
    appBarTheme: AppBarTheme(
      foregroundColor: Colors.grey[900],
      backgroundColor: const Color(0xFF303030),
      titleTextStyle: TextStyle(color: Colors.grey[300]),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: Colors.grey[900],
      textTheme: ButtonTextTheme.primary,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Colors.grey[900],
      foregroundColor: Colors.grey[300],
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: Colors.grey[900],
    ),
    iconTheme: IconThemeData(
      color: Colors.grey[400],
    ),
    primaryIconTheme: IconThemeData(color: Colors.grey[400]),
    elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(Colors.grey[900]),
      foregroundColor: WidgetStatePropertyAll(Colors.grey[300]),
      textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 16, color: Colors.grey[300])),
    )),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(Colors.grey[400]),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.grey[850],
      surfaceTintColor: Colors.transparent,
    ),
    cardColor: Colors.grey[850],
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[700]!, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[500]!, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[700]!, width: 1.5),
      ),
      labelStyle: TextStyle(color: Colors.grey[400]),
    ),
    primaryTextTheme: textThemeDark(),
    textTheme: textThemeDark(),
    dividerColor: Colors.grey[700],
    dialogTheme: DialogThemeData(backgroundColor: Colors.grey[850]));

TextTheme textThemeLight() {
  return TextTheme(
    titleLarge: TextStyle(
      color: Colors.grey[800],
      fontSize: 23,
      height: 1.2,
      fontWeight: FontWeight.bold,
    ),
    titleMedium: TextStyle(
      color: Colors.grey[800],
      fontSize: 20,
      height: 1.1,
      fontWeight: FontWeight.bold,
    ),
    titleSmall: TextStyle(
      color: Colors.grey[800],
      fontSize: 14,
    ),
    displayLarge: TextStyle(
      color: Colors.grey[800],
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
    displayMedium: TextStyle(
      color: Colors.grey[800],
      fontSize: 12,
    ),
    displaySmall: TextStyle(
      color: Colors.grey[800],
      fontSize: 15,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(
      color: Colors.grey[800],
      fontSize: 30,
      fontWeight: FontWeight.bold,
    ),
    bodySmall: TextStyle(
      color: Colors.grey[800],
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: TextStyle(
      color: Colors.grey[800],
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: TextStyle(
      color: Colors.grey[800],
      fontSize: 16,
      fontWeight: FontWeight.normal,
    ),
    labelSmall: TextStyle(color: Colors.grey[800], fontSize: 12),
  );
}

TextTheme textThemeDark() {
  return TextTheme(
    titleLarge: TextStyle(
      color: Colors.grey[300],
      fontSize: 23,
      height: 1.2,
      fontWeight: FontWeight.bold,
    ),
    titleMedium: TextStyle(
      color: Colors.grey[300],
      fontSize: 20,
      height: 1.1,
      fontWeight: FontWeight.bold,
    ),
    titleSmall: TextStyle(
      color: Colors.grey[300],
      fontSize: 14,
    ),
    displayLarge: TextStyle(
      color: Colors.grey[300],
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
    displayMedium: TextStyle(
      color: Colors.grey[300],
      fontSize: 12,
    ),
    displaySmall: TextStyle(
      color: Colors.grey[300],
      fontSize: 15,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(
      color: Colors.grey[300],
      fontSize: 30,
      fontWeight: FontWeight.bold,
    ),
    bodySmall: TextStyle(
      color: Colors.grey[300],
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: TextStyle(
      color: Colors.grey[300],
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: TextStyle(
      color: Colors.grey[300],
      fontSize: 16,
      fontWeight: FontWeight.normal,
    ),
    labelSmall: TextStyle(color: Colors.grey[300], fontSize: 12),
  );
}
