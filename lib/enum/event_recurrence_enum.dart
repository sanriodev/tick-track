/// How often a calendar event repeats.
///
/// Mirrors the backend's EventRecurrence, which is a string enum there - the
/// wire format is the lower case name, not the index.
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

  /// Short name for the mode, e.g. as the title of a menu entry.
  String get label => switch (this) {
        EventRecurrence.none => 'Einmalig',
        EventRecurrence.daily => 'Täglich',
        EventRecurrence.weekly => 'Wöchentlich',
        EventRecurrence.monthly => 'Monatlich',
        EventRecurrence.yearly => 'Jährlich',
      };

  bool get repeats => this != EventRecurrence.none;
}
