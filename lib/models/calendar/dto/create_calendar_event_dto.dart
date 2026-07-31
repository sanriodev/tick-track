import 'package:ticktrack/enum/event_recurrence_enum.dart';
import 'package:ticktrack/enum/privacy_mode_enum.dart';

class CreateCalendarEventDto {
  String title;
  String? description;
  String? location;
  DateTime startAt;
  DateTime? endAt;
  bool allDay;
  EventRecurrence recurrence;
  DateTime? recurrenceEndDate;
  PrivacyMode? privacyMode;
  int? groupId;

  CreateCalendarEventDto({
    required this.title,
    required this.startAt,
    this.endAt,
    this.allDay = false,
    this.recurrence = EventRecurrence.none,
    this.description,
    this.location,
    this.recurrenceEndDate,
    this.privacyMode,
    this.groupId,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (description != null) 'description': description,
      if (location != null) 'location': location,
      // UTC on the wire, the backend stores and compares in UTC
      'startAt': startAt.toUtc().toIso8601String(),
      if (endAt != null) 'endAt': endAt!.toUtc().toIso8601String(),
      'allDay': allDay,
      'recurrence': recurrence.toJson(),
      if (recurrenceEndDate != null)
        'recurrenceEndDate': recurrenceEndDate!.toUtc().toIso8601String(),
      if (privacyMode != null) 'privacyMode': privacyMode!.toJson(),
      if (groupId != null) 'groupId': groupId,
    };
  }
}
