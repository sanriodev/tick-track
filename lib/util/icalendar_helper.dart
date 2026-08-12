import 'dart:convert';

import 'package:ticktrack/enum/event_recurrence_enum.dart';
import 'package:ticktrack/models/calendar/calendar_event_model.dart';

const String _productId = '-//TickTrack//Kalender//DE';
const String _uidDomain = 'ticktrack.app';
const String _lineBreak = '\r\n';
const int _maxLineOctets = 75;

String buildICalendar(
  Iterable<CalendarEvent> events, {
  required String calendarName,
  DateTime? createdAt,
}) {
  final stamp = _utcStamp(createdAt ?? DateTime.now());
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:$_productId',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:${_escaped(calendarName)}',
    for (final event in events) ..._eventLines(event, stamp),
    'END:VCALENDAR',
  ];

  return '${lines.map(_folded).join(_lineBreak)}$_lineBreak';
}

List<String> _eventLines(CalendarEvent event, String stamp) {
  final description = event.description?.trim() ?? '';
  final location = event.location?.trim() ?? '';

  return [
    'BEGIN:VEVENT',
    'UID:event-${event.id}@$_uidDomain',
    'DTSTAMP:$stamp',
    ..._scheduleLines(event),
    'SUMMARY:${_escaped(event.title)}',
    if (description.isNotEmpty) 'DESCRIPTION:${_escaped(description)}',
    if (location.isNotEmpty) 'LOCATION:${_escaped(location)}',
    if (event.recurrence.repeats) 'RRULE:${_recurrenceRule(event)}',
    ..._alarmLines(event),
    'END:VEVENT',
  ];
}

List<String> _scheduleLines(CalendarEvent event) {
  final endAt = _endNotBeforeStart(event);

  if (!event.allDay) {
    return [
      'DTSTART:${_utcStamp(event.startAt)}',
      'DTEND:${_utcStamp(endAt)}',
    ];
  }

  return [
    'DTSTART;VALUE=DATE:${_dateStamp(event.startAt)}',
    'DTEND;VALUE=DATE:${_dateStamp(_nextDay(endAt))}',
  ];
}

String _recurrenceRule(CalendarEvent event) {
  final frequency = 'FREQ=${_frequencyOf(event.recurrence)}';
  final seriesEnd = event.recurrenceEndDate;
  if (seriesEnd == null) {
    return frequency;
  }

  final until =
      event.allDay ? _dateStamp(seriesEnd) : _utcStamp(_endOfDay(seriesEnd));
  return '$frequency;UNTIL=$until';
}

String _frequencyOf(EventRecurrence recurrence) {
  return switch (recurrence) {
    EventRecurrence.daily => 'DAILY',
    EventRecurrence.weekly => 'WEEKLY',
    EventRecurrence.monthly => 'MONTHLY',
    EventRecurrence.yearly => 'YEARLY',
    EventRecurrence.none => 'DAILY',
  };
}

List<String> _alarmLines(CalendarEvent event) {
  final minutesBefore = event.remindMinutesBefore;
  if (minutesBefore == null) {
    return const [];
  }

  return [
    'BEGIN:VALARM',
    'ACTION:DISPLAY',
    'DESCRIPTION:${_escaped(event.title)}',
    'TRIGGER:${minutesBefore <= 0 ? 'PT0S' : '-PT${minutesBefore}M'}',
    'END:VALARM',
  ];
}

DateTime _endNotBeforeStart(CalendarEvent event) {
  return event.endAt.isBefore(event.startAt) ? event.startAt : event.endAt;
}

DateTime _nextDay(DateTime moment) {
  return DateTime(moment.year, moment.month, moment.day + 1);
}

DateTime _endOfDay(DateTime day) {
  return DateTime(day.year, day.month, day.day, 23, 59, 59);
}

String _dateStamp(DateTime day) {
  return '${_padded(day.year, 4)}${_padded(day.month, 2)}${_padded(day.day, 2)}';
}

String _utcStamp(DateTime moment) {
  final utc = moment.toUtc();
  return '${_dateStamp(utc)}T${_padded(utc.hour, 2)}'
      '${_padded(utc.minute, 2)}${_padded(utc.second, 2)}Z';
}

String _padded(int value, int length) {
  return value.toString().padLeft(length, '0');
}

String _escaped(String value) {
  return value
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\r\n', '\\n')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\n');
}

String _folded(String line) {
  final segments = <String>[];
  final segment = StringBuffer();
  var octets = 0;

  for (final rune in line.runes) {
    final character = String.fromCharCode(rune);
    final characterOctets = utf8.encode(character).length;
    final limit = segments.isEmpty ? _maxLineOctets : _maxLineOctets - 1;

    if (octets + characterOctets > limit) {
      segments.add(segment.toString());
      segment.clear();
      octets = 0;
    }
    segment.write(character);
    octets += characterOctets;
  }
  segments.add(segment.toString());

  return segments.join('$_lineBreak ');
}
