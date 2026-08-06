import 'package:ticktrack/enum/event_color_enum.dart';
import 'package:ticktrack/enum/event_recurrence_enum.dart';
import 'package:ticktrack/enum/privacy_mode_enum.dart';

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

  bool clearRecurrenceEndDate;

  EventColor? color;

  bool clearColor;

  int? remindMinutesBefore;

  bool clearReminder;

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
    this.color,
    this.clearColor = false,
    this.remindMinutesBefore,
    this.clearReminder = false,
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
      if (clearColor)
        'color': null
      else if (color != null)
        'color': color!.toJson(),
      if (clearReminder)
        'remindMinutesBefore': null
      else if (remindMinutesBefore != null)
        'remindMinutesBefore': remindMinutesBefore,
      if (privacyMode != null) 'privacyMode': privacyMode!.toJson(),
    };
  }
}
