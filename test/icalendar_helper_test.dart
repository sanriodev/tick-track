import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ticktrack/enum/event_recurrence_enum.dart';
import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/models/calendar/calendar_event_model.dart';
import 'package:ticktrack/util/calendar_export_helper.dart';
import 'package:ticktrack/util/icalendar_helper.dart';

CalendarEvent buildEvent({
  int id = 1,
  String title = 'Putztag',
  String? description,
  String? location,
  DateTime? startAt,
  DateTime? endAt,
  bool allDay = false,
  EventRecurrence recurrence = EventRecurrence.none,
  DateTime? recurrenceEndDate,
  int? remindMinutesBefore,
}) {
  return CalendarEvent(
    id: id,
    title: title,
    description: description,
    location: location,
    startAt: startAt ?? DateTime.utc(2026, 8, 11, 10).toLocal(),
    endAt: endAt ?? DateTime.utc(2026, 8, 11, 11, 30).toLocal(),
    allDay: allDay,
    recurrence: recurrence,
    recurrenceEndDate: recurrenceEndDate,
    remindMinutesBefore: remindMinutesBefore,
    privacyMode: PrivacyMode.private,
  );
}

List<String> linesOf(String calendar) => calendar.split('\r\n');

void main() {
  final createdAt = DateTime.utc(2026, 8, 11, 8, 30, 5);

  group('buildICalendar', () {
    test('umschließt die Events mit einem gültigen Kalenderrumpf', () {
      final lines = linesOf(buildICalendar(
        [buildEvent()],
        calendarName: 'TickTrack Kalender',
        createdAt: createdAt,
      ));

      expect(lines.first, 'BEGIN:VCALENDAR');
      expect(lines, contains('VERSION:2.0'));
      expect(lines, contains('X-WR-CALNAME:TickTrack Kalender'));
      expect(lines, contains('BEGIN:VEVENT'));
      expect(lines, contains('UID:event-1@ticktrack.app'));
      expect(lines, contains('DTSTAMP:20260811T083005Z'));
      expect(lines, contains('SUMMARY:Putztag'));
      expect(lines, contains('END:VEVENT'));
      expect(lines, contains('END:VCALENDAR'));
    });

    test('endet mit einem Zeilenumbruch nach END:VCALENDAR', () {
      final calendar = buildICalendar(
        const [],
        calendarName: 'Kalender',
        createdAt: createdAt,
      );

      expect(calendar.endsWith('END:VCALENDAR\r\n'), isTrue);
    });

    test('schreibt Zeitpunkte in UTC', () {
      final lines = linesOf(buildICalendar(
        [
          buildEvent(
            startAt: DateTime.utc(2026, 8, 11, 10).toLocal(),
            endAt: DateTime.utc(2026, 8, 11, 11, 30).toLocal(),
          )
        ],
        calendarName: 'Kalender',
        createdAt: createdAt,
      ));

      expect(lines, contains('DTSTART:20260811T100000Z'));
      expect(lines, contains('DTEND:20260811T113000Z'));
    });

    test('schreibt ganztägige Events als Datum mit exklusivem Ende', () {
      final lines = linesOf(buildICalendar(
        [
          buildEvent(
            allDay: true,
            startAt: DateTime(2026, 8, 11),
            endAt: DateTime(2026, 8, 12),
          )
        ],
        calendarName: 'Kalender',
        createdAt: createdAt,
      ));

      expect(lines, contains('DTSTART;VALUE=DATE:20260811'));
      expect(lines, contains('DTEND;VALUE=DATE:20260813'));
    });

    test('korrigiert ein Ende vor dem Start', () {
      final lines = linesOf(buildICalendar(
        [
          buildEvent(
            startAt: DateTime.utc(2026, 8, 11, 10).toLocal(),
            endAt: DateTime.utc(2026, 8, 11, 9).toLocal(),
          )
        ],
        calendarName: 'Kalender',
        createdAt: createdAt,
      ));

      expect(lines, contains('DTEND:20260811T100000Z'));
    });

    test('übersetzt Wiederholungen in eine RRULE', () {
      final lines = linesOf(buildICalendar(
        [buildEvent(recurrence: EventRecurrence.weekly)],
        calendarName: 'Kalender',
        createdAt: createdAt,
      ));

      expect(lines, contains('RRULE:FREQ=WEEKLY'));
    });

    test('begrenzt eine Serie mit UNTIL', () {
      final lines = linesOf(buildICalendar(
        [
          buildEvent(
            allDay: true,
            startAt: DateTime(2026, 8, 11),
            endAt: DateTime(2026, 8, 11),
            recurrence: EventRecurrence.monthly,
            recurrenceEndDate: DateTime(2026, 12, 24),
          )
        ],
        calendarName: 'Kalender',
        createdAt: createdAt,
      ));

      expect(lines, contains('RRULE:FREQ=MONTHLY;UNTIL=20261224'));
    });

    test('lässt einmalige Events ohne RRULE', () {
      final calendar = buildICalendar(
        [buildEvent(recurrenceEndDate: DateTime(2026, 12, 24))],
        calendarName: 'Kalender',
        createdAt: createdAt,
      );

      expect(calendar.contains('RRULE'), isFalse);
    });

    test('exportiert Erinnerungen als VALARM', () {
      final lines = linesOf(buildICalendar(
        [buildEvent(remindMinutesBefore: 15)],
        calendarName: 'Kalender',
        createdAt: createdAt,
      ));

      expect(lines, contains('BEGIN:VALARM'));
      expect(lines, contains('TRIGGER:-PT15M'));
      expect(lines, contains('END:VALARM'));
    });

    test('nutzt für eine Erinnerung zum Beginn eine Nulldauer', () {
      final lines = linesOf(buildICalendar(
        [buildEvent(remindMinutesBefore: 0)],
        calendarName: 'Kalender',
        createdAt: createdAt,
      ));

      expect(lines, contains('TRIGGER:PT0S'));
    });

    test('lässt Events ohne Erinnerung ohne VALARM', () {
      final calendar = buildICalendar(
        [buildEvent()],
        calendarName: 'Kalender',
        createdAt: createdAt,
      );

      expect(calendar.contains('VALARM'), isFalse);
    });

    test('maskiert Sonderzeichen in Texten', () {
      final lines = linesOf(buildICalendar(
        [
          buildEvent(
            title: 'Putztag; Küche, Bad',
            description: 'Erste Zeile\nZweite Zeile\\Ende',
            location: 'Keller, hinten',
          )
        ],
        calendarName: 'Kalender',
        createdAt: createdAt,
      ));

      expect(lines, contains('SUMMARY:Putztag\\; Küche\\, Bad'));
      expect(lines, contains('DESCRIPTION:Erste Zeile\\nZweite Zeile\\\\Ende'));
      expect(lines, contains('LOCATION:Keller\\, hinten'));
    });

    test('lässt leere Beschreibung und leeren Ort weg', () {
      final calendar = buildICalendar(
        [buildEvent(description: '   ', location: '')],
        calendarName: 'Kalender',
        createdAt: createdAt,
      );

      expect(calendar.contains('DESCRIPTION'), isFalse);
      expect(calendar.contains('LOCATION'), isFalse);
    });

    test('faltet zu lange Zeilen auf 75 Oktette', () {
      final lines = linesOf(buildICalendar(
        [buildEvent(title: 'Müll' * 40)],
        calendarName: 'Kalender',
        createdAt: createdAt,
      ));
      final folded = lines.where((line) => line.startsWith(' ')).toList();

      expect(folded, isNotEmpty);
      for (final line in lines) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }
    });
  });

  group('distinctEventsOf', () {
    CalendarOccurrence occurrenceOf(CalendarEvent event) {
      return CalendarOccurrence(
        event: event,
        startAt: event.startAt,
        endAt: event.endAt,
        isRecurrence: false,
      );
    }

    test('behält jedes Event nur einmal', () {
      final event = buildEvent(recurrence: EventRecurrence.weekly);

      final events = distinctEventsOf(
        [occurrenceOf(event), occurrenceOf(event), occurrenceOf(event)],
      );

      expect(events.length, 1);
      expect(events.first.id, event.id);
    });

    test('sortiert nach Startzeitpunkt', () {
      final later = buildEvent(id: 2, startAt: DateTime(2026, 9, 1, 9));
      final earlier = buildEvent(id: 3, startAt: DateTime(2026, 7, 1, 9));

      final events = distinctEventsOf([
        occurrenceOf(later),
        occurrenceOf(earlier),
      ]);

      expect(events.map((event) => event.id), [3, 2]);
    });
  });
}
