/// Mirrors the backend's EventRecurrence, a string enum there - so the wire
/// format is the lower case name, not the index.
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

  String get label => switch (this) {
        EventRecurrence.none => 'Einmalig',
        EventRecurrence.daily => 'Täglich',
        EventRecurrence.weekly => 'Wöchentlich',
        EventRecurrence.monthly => 'Monatlich',
        EventRecurrence.yearly => 'Jährlich',
      };

  bool get repeats => this != EventRecurrence.none;
}
