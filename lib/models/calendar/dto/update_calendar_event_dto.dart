import 'package:ticktrack/enum/event_recurrence_enum.dart';
import 'package:ticktrack/enum/privacy_mode_enum.dart';

/// Partial update of an event. Only the fields that are set are sent, so a
/// screen that just flips the privacy mode does not have to know the rest.
///
/// Editing always affects the whole series - single dates of a repetition
/// cannot be moved on their own.
class UpdateCalendarEventDto {
  int id;
  String? title;
  String? description;
  String? location;
  DateTime? startAt;
  DateTime? endAt;
  bool? allDay;
  EventRecurrence? recurrence;
  DateTime? recurrenceEndDate;

  /// Sends an explicit null for the series end, which reopens a series that had
  /// one. Needed because leaving [recurrenceEndDate] null means "do not touch",
  /// and the two cases have to stay distinguishable on the wire.
  bool clearRecurrenceEndDate;

  PrivacyMode? privacyMode;

  UpdateCalendarEventDto({
    required this.id,
    this.title,
    this.description,
    this.location,
    this.startAt,
    this.endAt,
    this.allDay,
    this.recurrence,
    this.recurrenceEndDate,
    this.clearRecurrenceEndDate = false,
    this.privacyMode,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (location != null) 'location': location,
      if (startAt != null) 'startAt': startAt!.toUtc().toIso8601String(),
      if (endAt != null) 'endAt': endAt!.toUtc().toIso8601String(),
      if (allDay != null) 'allDay': allDay,
      if (recurrence != null) 'recurrence': recurrence!.toJson(),
      if (clearRecurrenceEndDate)
        'recurrenceEndDate': null
      else if (recurrenceEndDate != null)
        'recurrenceEndDate': recurrenceEndDate!.toUtc().toIso8601String(),
      if (privacyMode != null) 'privacyMode': privacyMode!.toJson(),
    };
  }
}
