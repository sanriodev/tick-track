import 'package:ticktrack/models/calendar/calendar_event_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const int _maxScheduled = 48;

class ReminderCalendar {
  final String? groupName;
  final List<CalendarOccurrence> occurrences;

  const ReminderCalendar({
    required this.occurrences,
    this.groupName,
  });
}

class _DueReminder {
  final DateTime fireAt;
  final CalendarOccurrence occurrence;
  final String? groupName;

  const _DueReminder({
    required this.fireAt,
    required this.occurrence,
    this.groupName,
  });
}

class ReminderScheduler {
  static final ReminderScheduler _instance =
      ReminderScheduler._privateConstructor();
  factory ReminderScheduler() => _instance;
  ReminderScheduler._privateConstructor();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  bool _allowed = false;

  bool _exactAllowed = true;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'calendar_reminders',
    'Erinnerungen',
    channelDescription: 'Erinnerungen an bevorstehende Kalenderevents',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(
          tz.getLocation(await FlutterTimezone.getLocalTimezone()));

      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _initialized = true;
      await _refreshPermissionState();
    } catch (error) {
      debugPrint('Reminder scheduler could not be initialized: $error');
    }
  }

  Future<void> _refreshPermissionState() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        _allowed = await android.areNotificationsEnabled() ?? false;
        _exactAllowed = await android.canScheduleExactNotifications() ?? false;
      }

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        _allowed = (await ios.checkPermissions())?.isEnabled ?? false;
      }
    } catch (error) {
      debugPrint('Could not read the notification permission: $error');
    }
  }

  Future<bool> requestPermission() async {
    await init();
    if (!_initialized) {
      return false;
    }

    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        _allowed = await android.requestNotificationsPermission() ?? false;
        _exactAllowed = await android.canScheduleExactNotifications() ?? false;
        if (!_exactAllowed) {
          _exactAllowed = await android.requestExactAlarmsPermission() ?? false;
        }
      }

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        _allowed = await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (error) {
      debugPrint('Could not request notification permission: $error');
      _allowed = false;
    }
    return _allowed;
  }

  Future<void> reschedule(List<ReminderCalendar> calendars) async {
    await init();
    if (!_initialized) {
      debugPrint('Reminders not scheduled, the scheduler is not initialized');
      return;
    }
    await _refreshPermissionState();
    if (!_allowed) {
      debugPrint('Notifications are not allowed, scheduling the reminders '
          'anyway so they work once they are');
    }

    final now = DateTime.now();
    final due = <_DueReminder>[];
    final seen = <int>{};
    for (final calendar in calendars) {
      for (final occurrence in calendar.occurrences) {
        final minutes = occurrence.event.remindMinutesBefore;
        if (minutes == null) {
          continue;
        }
        final fireAt = occurrence.startAt.subtract(Duration(minutes: minutes));
        if (!fireAt.isAfter(now) || !seen.add(_idFor(occurrence))) {
          continue;
        }
        due.add(_DueReminder(
          fireAt: fireAt,
          occurrence: occurrence,
          groupName: calendar.groupName,
        ));
      }
    }

    final scheduled = _pickSlots(due);
    try {
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('Could not clear the pending reminders: $error');
    }
    for (final entry in scheduled) {
      await _schedule(entry.fireAt, entry.occurrence, entry.groupName);
    }
    debugPrint('Reminders: ${scheduled.length} of ${due.length} upcoming '
        'scheduled across ${calendars.length} calendars '
        '(exact: $_exactAllowed, allowed: $_allowed)');
  }

  List<_DueReminder> _pickSlots(List<_DueReminder> due) {
    final byEvent = <int, List<_DueReminder>>{};
    for (final entry in due) {
      byEvent.putIfAbsent(entry.occurrence.event.id, () => []).add(entry);
    }
    for (final dates in byEvent.values) {
      dates.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    }
    final events = byEvent.values.toList()
      ..sort((a, b) => a.first.fireAt.compareTo(b.first.fireAt));

    final picked = <_DueReminder>[];
    for (var round = 0; picked.length < _maxScheduled; round++) {
      var addedInRound = false;
      for (final dates in events) {
        if (round >= dates.length) {
          continue;
        }
        picked.add(dates[round]);
        addedInRound = true;
        if (picked.length >= _maxScheduled) {
          break;
        }
      }
      if (!addedInRound) {
        break;
      }
    }
    picked.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return picked;
  }

  Future<void> _schedule(
    DateTime fireAt,
    CalendarOccurrence occurrence,
    String? groupName,
  ) async {
    final event = occurrence.event;
    try {
      await _plugin.zonedSchedule(
        _idFor(occurrence),
        event.title,
        _body(occurrence, groupName),
        tz.TZDateTime.from(fireAt, tz.local),
        _details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        androidScheduleMode: _exactAllowed
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } on PlatformException catch (error) {
      debugPrint('Falling back to an inexact reminder: ${error.message}');
      _exactAllowed = false;
      try {
        await _plugin.zonedSchedule(
          _idFor(occurrence),
          event.title,
          _body(occurrence, groupName),
          tz.TZDateTime.from(fireAt, tz.local),
          _details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.wallClockTime,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (retryError) {
        debugPrint('No reminder for ${event.title}: $retryError');
      }
    } catch (error) {
      debugPrint('No reminder for ${event.title}: $error');
    }
  }

  String _body(CalendarOccurrence occurrence, String? groupName) {
    final start = occurrence.startAt;
    final now = DateTime.now();
    final isToday = start.year == now.year &&
        start.month == now.month &&
        start.day == now.day;

    final when = occurrence.event.allDay
        ? (isToday ? 'Heute' : DateFormat('EEEE, d. MMMM').format(start))
        : isToday
            ? 'Heute um ${DateFormat('HH:mm').format(start)}'
            : DateFormat("EEEE, d. MMMM 'um' HH:mm").format(start);

    final location = occurrence.event.location?.trim() ?? '';
    final group = groupName?.trim() ?? '';
    return [
      when,
      if (location.isNotEmpty) location,
      if (group.isNotEmpty) group,
    ].join(' · ');
  }

  int _idFor(CalendarOccurrence occurrence) {
    final key = '${occurrence.event.id}@'
        '${occurrence.startAt.toUtc().toIso8601String()}';
    return key.hashCode & 0x7fffffff;
  }

  Future<void> cancelAll() async {
    await init();
    if (!_initialized) {
      return;
    }
    try {
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('Could not cancel reminders: $error');
    }
  }
}
