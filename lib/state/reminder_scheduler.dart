import 'package:ticktrack/state/locale_store.dart';
import 'package:ticktrack/l10n/l10n.dart';
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

  NotificationDetails _detailsFor(AppLocalizations l10n) => NotificationDetails(
        android: AndroidNotificationDetails(
          'calendar_reminders',
          l10n.reminderChannelName,
          channelDescription: l10n.reminderChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  Future<AppLocalizations> _localizations() =>
      AppLocalizations.delegate.load(LocaleStore().resolveStartupLocale());

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
    final l10n = await _localizations();
    for (final entry in scheduled) {
      await _schedule(l10n, entry.fireAt, entry.occurrence, entry.groupName);
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
    AppLocalizations l10n,
    DateTime fireAt,
    CalendarOccurrence occurrence,
    String? groupName,
  ) async {
    final event = occurrence.event;
    final details = _detailsFor(l10n);
    try {
      await _plugin.zonedSchedule(
        _idFor(occurrence),
        event.title,
        _body(l10n, occurrence, groupName),
        tz.TZDateTime.from(fireAt, tz.local),
        details,
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
          _body(l10n, occurrence, groupName),
          tz.TZDateTime.from(fireAt, tz.local),
          details,
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

  String _body(
    AppLocalizations l10n,
    CalendarOccurrence occurrence,
    String? groupName,
  ) {
    final start = occurrence.startAt;
    final now = DateTime.now();
    final isToday = start.year == now.year &&
        start.month == now.month &&
        start.day == now.day;

    final when = _whenLabel(l10n, occurrence, start, isToday: isToday);
    final location = occurrence.event.location?.trim() ?? '';
    final group = groupName?.trim() ?? '';
    return [
      when,
      if (location.isNotEmpty) location,
      if (group.isNotEmpty) group,
    ].join(' · ');
  }

  String _whenLabel(
    AppLocalizations l10n,
    CalendarOccurrence occurrence,
    DateTime start, {
    required bool isToday,
  }) {
    final date = DateFormat.MMMMEEEEd().format(start);
    if (occurrence.event.allDay) {
      return isToday ? l10n.today : date;
    }
    final time = DateFormat.jm().format(start);
    return isToday ? l10n.reminderTodayAt(time) : l10n.reminderOnDateAt(date, time);
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
