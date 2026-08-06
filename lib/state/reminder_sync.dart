import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/models/calendar/calendar_event_model.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/state/reminder_scheduler.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/foundation.dart';

class ReminderSync {
  static final ReminderSync _instance = ReminderSync._privateConstructor();
  factory ReminderSync() => _instance;
  ReminderSync._privateConstructor();

  static const Duration _horizon = Duration(days: 60);

  static const Duration _minInterval = Duration(minutes: 5);

  DateTime? _lastSync;
  Future<void>? _running;

  final Map<int?, List<CalendarOccurrence>> _lastKnown = {};

  Future<void> sync({bool force = false}) {
    final running = _running;
    if (running != null) {
      return running;
    }
    if (AuthBackend().loggedInUser == null) {
      return Future.value();
    }
    final last = _lastSync;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < _minInterval) {
      return Future.value();
    }

    final future = _sync().catchError(
      (Object error) => debugPrint('The reminder sync failed: $error'),
    );
    _running = future;
    return future.whenComplete(() => _running = null);
  }

  Future<void> _sync() async {
    final from = DateTime.now();
    final to = from.add(_horizon);

    final sources = <({int? id, String? name})>[
      (id: null, name: null),
      for (final group in GroupContext().groups)
        (id: group.id, name: group.name),
    ];

    final calendars = <ReminderCalendar>[];
    var complete = true;
    for (final source in sources) {
      try {
        final occurrences = await Backend().getCalendarEvents(
          groupId: source.id,
          from: from,
          to: to,
        );
        _lastKnown[source.id] = occurrences;
        calendars.add(
          ReminderCalendar(
            groupName: source.name,
            occurrences: occurrences,
          ),
        );
      } catch (error) {
        complete = false;
        final which = source.name ?? 'the personal calendar';
        debugPrint('Could not load the reminders of $which: $error');
        final known = _lastKnown[source.id];
        if (known != null) {
          calendars.add(
            ReminderCalendar(groupName: source.name, occurrences: known),
          );
        }
      }
    }

    if (calendars.isEmpty) {
      debugPrint('Reminder sync skipped, no calendar at all could be loaded');
      return;
    }

    if (complete) {
      _lastSync = DateTime.now();
    }
    await ReminderScheduler().reschedule(calendars);
  }

  void reset() {
    _lastSync = null;
    _lastKnown.clear();
  }
}
