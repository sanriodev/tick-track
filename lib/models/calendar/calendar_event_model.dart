import 'package:ticktrack/enum/event_color_enum.dart';
import 'package:ticktrack/enum/event_recurrence_enum.dart';
import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/models/base/base_user_relation.dart';
import 'package:blvckleg_dart_core/models/user/user_model.dart';

class CalendarEvent extends BaseUserRelation {
  int id;
  String title;
  String? description;
  String? location;
  DateTime startAt;
  DateTime endAt;
  bool allDay;
  EventRecurrence recurrence;
  DateTime? recurrenceEndDate;
  EventColor? color;

  int? remindMinutesBefore;

  PrivacyMode privacyMode;
  int? groupId;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.allDay,
    required this.recurrence,
    required this.privacyMode,
    this.description,
    this.location,
    this.recurrenceEndDate,
    this.color,
    this.remindMinutesBefore,
    this.groupId,
    super.user,
    super.lastModifiedUser,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      startAt: DateTime.parse(json['startAt'] as String).toLocal(),
      endAt: DateTime.parse(json['endAt'] as String).toLocal(),
      allDay: json['allDay'] as bool? ?? false,
      recurrence: EventRecurrence.fromJson(json['recurrence']),
      recurrenceEndDate: json['recurrenceEndDate'] != null
          ? DateTime.parse(json['recurrenceEndDate'] as String).toLocal()
          : null,
      color: EventColor.fromJson(json['color']),
      remindMinutesBefore: json['remindMinutesBefore'] as int?,
      privacyMode: PrivacyMode.fromJson(json['privacyMode']),
      groupId: json['groupId'] as int?,
      user: json['user'] != null
          ? User.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      lastModifiedUser: json['lastModifiedUser'] != null
          ? User.fromJson(json['lastModifiedUser'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'startAt': startAt.toUtc().toIso8601String(),
      'endAt': endAt.toUtc().toIso8601String(),
      'allDay': allDay,
      'recurrence': recurrence.toJson(),
      'recurrenceEndDate': recurrenceEndDate?.toUtc().toIso8601String(),
      'color': color?.toJson(),
      'remindMinutesBefore': remindMinutesBefore,
      'privacyMode': privacyMode.toJson(),
      'groupId': groupId,
      'user': user?.toJson(),
      'lastModifiedUser': lastModifiedUser?.toJson(),
    };
  }
}

class CalendarOccurrence {
  final CalendarEvent event;
  final DateTime startAt;
  final DateTime endAt;

  final bool isRecurrence;

  CalendarOccurrence({
    required this.event,
    required this.startAt,
    required this.endAt,
    required this.isRecurrence,
  });

  factory CalendarOccurrence.fromJson(Map<String, dynamic> json) {
    return CalendarOccurrence(
      event: CalendarEvent.fromJson(json['event'] as Map<String, dynamic>),
      startAt: DateTime.parse(json['startAt'] as String).toLocal(),
      endAt: DateTime.parse(json['endAt'] as String).toLocal(),
      isRecurrence: json['isRecurrence'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event': event.toJson(),
      'startAt': startAt.toUtc().toIso8601String(),
      'endAt': endAt.toUtc().toIso8601String(),
      'isRecurrence': isRecurrence,
    };
  }

  DateTime get day => DateTime(startAt.year, startAt.month, startAt.day);

  bool get spansDays =>
      endAt.day != startAt.day ||
      endAt.month != startAt.month ||
      endAt.year != startAt.year;
}
