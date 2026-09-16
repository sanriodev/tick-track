import 'package:ticktrack/l10n/l10n.dart';

enum EventRecurrence {
  none,
  daily,
  weekly,
  monthly,
  yearly;

  String toJson() => name;

  static EventRecurrence fromJson(dynamic json) {
    if (json is String) {
      for (final value in EventRecurrence.values) {
        if (value.name == json) {
          return value;
        }
      }
    }
    return EventRecurrence.none;
  }

  String label(AppLocalizations l10n) => switch (this) {
        EventRecurrence.none => l10n.recurrenceNone,
        EventRecurrence.daily => l10n.recurrenceDaily,
        EventRecurrence.weekly => l10n.recurrenceWeekly,
        EventRecurrence.monthly => l10n.recurrenceMonthly,
        EventRecurrence.yearly => l10n.recurrenceYearly,
      };

  bool get repeats => this != EventRecurrence.none;
}
