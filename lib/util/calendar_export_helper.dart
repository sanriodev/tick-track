import 'dart:io';

import 'package:share_plus/share_plus.dart';
import 'package:ticktrack/models/calendar/calendar_event_model.dart';
import 'package:ticktrack/util/export_helper.dart';
import 'package:ticktrack/util/icalendar_helper.dart';

const String _exportDirectoryName = 'calendar-export';
const String _calendarMimeType = 'text/calendar';

Future<XFile> exportCalendarAsIcs({
  required List<CalendarEvent> events,
  required String calendarName,
}) async {
  final directory = await prepareExportDirectory(_exportDirectoryName);
  final fileName = '${safeFileName(calendarName, fallback: 'kalender')}.ics';
  final file = File('${directory.path}/$fileName');

  await file.writeAsString(
    buildICalendar(events, calendarName: calendarName),
  );

  return XFile(file.path, mimeType: _calendarMimeType, name: fileName);
}

List<CalendarEvent> distinctEventsOf(
  Iterable<CalendarOccurrence> occurrences,
) {
  final eventsById = <int, CalendarEvent>{};
  for (final occurrence in occurrences) {
    eventsById.putIfAbsent(occurrence.event.id, () => occurrence.event);
  }

  final events = eventsById.values.toList();
  events.sort((first, second) => first.startAt.compareTo(second.startAt));
  return events;
}
