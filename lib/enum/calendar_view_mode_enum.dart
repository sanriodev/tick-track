import 'package:ticktrack/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

enum CalendarViewMode {
  month,
  week;

  String toJson() => name;

  static CalendarViewMode fromJson(dynamic json) {
    if (json is String) {
      for (final value in CalendarViewMode.values) {
        if (value.name == json) {
          return value;
        }
      }
    }
    return CalendarViewMode.month;
  }

  CalendarViewMode get toggled =>
      this == CalendarViewMode.month
          ? CalendarViewMode.week
          : CalendarViewMode.month;

  String label(AppLocalizations l10n) => switch (this) {
        CalendarViewMode.month => l10n.calendarViewMonth,
        CalendarViewMode.week => l10n.calendarViewWeek,
      };

  IconData get icon => switch (this) {
        CalendarViewMode.month => PhosphorIconsRegular.squaresFour,
        CalendarViewMode.week => PhosphorIconsRegular.columns,
      };
}
