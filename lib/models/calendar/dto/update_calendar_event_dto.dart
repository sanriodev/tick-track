import 'package:ticktrack/enum/event_color_enum.dart';
import 'package:ticktrack/enum/event_recurrence_enum.dart';
import 'package:ticktrack/enum/privacy_mode_enum.dart';

/// Partial update: only fields that are set get sent, so a screen that just
/// flips the privacy mode does not have to know the rest.
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

  /// Sends an explicit null, which reopens a series that had an end. Needed
  /// because a null [recurrenceEndDate] already means "do not touch".
  bool clearRecurrenceEndDate;

  EventColor? color;

  /// Same reasoning as [clearRecurrenceEndDate]: a null [color] means "leave
  /// it", so removing a colour needs its own flag.
  bool clearColor;

  int? remindMinutesBefore;

  /// Switches the reminder off, for the same reason [clearColor] exists.
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
