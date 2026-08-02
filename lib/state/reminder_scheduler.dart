import 'package:ticktrack/models/calendar/calendar_event_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// iOS refuses to keep more than 64 pending notifications and silently drops
/// the rest, so the horizon is capped well below that.
const int _maxScheduled = 48;

/// Schedules the reminders for calendar events on the device.
///
/// Nothing here talks to a server: the OS holds the pending reminders and fires
/// them even when the app is closed. That also means only events the device has
/// already downloaded can be reminded about - [reschedule] is therefore called
/// with whatever the calendar just loaded.
class ReminderScheduler {
  static final ReminderScheduler _instance =
      ReminderScheduler._privateConstructor();
  factory ReminderScheduler() => _instance;
  ReminderScheduler._privateConstructor();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Set once the OS granted the right to post notifications. Without it
  /// scheduling is pointless, so [reschedule] turns into a no-op.
  bool _allowed = false;

  /// Whether the OS lets us schedule to the minute. Android 12+ can refuse,
  /// in which case reminders are still delivered, just batched by the system.
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

  /// Prepares the plugin and the time zone database. Safe to call more than
  /// once; failures are swallowed because a broken scheduler must never stop
  /// the app from starting.
  Future<void> init() async {
    if (_initialized) {
      return;
    }
    try {
      tz_data.initializeTimeZones();
      // the device zone, so a reminder set for 07:00 stays 07:00 across a
      // daylight saving change instead of drifting by an hour
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));

      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // asked for separately in requestPermission, so the first launch is
          // not interrupted by a system dialog
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

  /// Reads back what the OS currently allows.
  ///
  /// Needed on every start: the granted permission lives in the system, not in
  /// this object, and without asking again a restarted app would think it is
  /// not allowed to schedule anything.
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

  /// Asks the OS for permission, once. Returns whether reminders can be posted.
  ///
  /// Called the first time a user actually sets a reminder rather than on
  /// startup - a permission dialog makes more sense next to the switch that
  /// triggered it.
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
        // separate from the notification permission and refusable on its own
        _exactAllowed = await android.requestExactAlarmsPermission() ?? false;
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

  /// Replaces every pending reminder with the ones derived from [occurrences].
  ///
  /// Rebuilding the whole set instead of diffing is deliberate: an event can be
  /// moved, deleted or have its series changed between two loads, and any
  /// bookkeeping we kept would be the thing that goes stale.
  Future<void> reschedule(List<CalendarOccurrence> occurrences) async {
    await init();
    if (!_initialized || !_allowed) {
      return;
    }

    final now = DateTime.now();
    final due = <({DateTime fireAt, CalendarOccurrence occurrence})>[];
    for (final occurrence in occurrences) {
      final minutes = occurrence.event.remindMinutesBefore;
      if (minutes == null) {
        continue;
      }
      final fireAt = occurrence.startAt.subtract(Duration(minutes: minutes));
      // a reminder for a moment that has passed would fire immediately
      if (fireAt.isAfter(now)) {
        due.add((fireAt: fireAt, occurrence: occurrence));
      }
    }
    due.sort((a, b) => a.fireAt.compareTo(b.fireAt));

    try {
      await _plugin.cancelAll();
      for (final entry in due.take(_maxScheduled)) {
        await _schedule(entry.fireAt, entry.occurrence);
      }
    } catch (error) {
      debugPrint('Could not schedule reminders: $error');
    }
  }

  Future<void> _schedule(
    DateTime fireAt,
    CalendarOccurrence occurrence,
  ) async {
    final event = occurrence.event;
    try {
      await _plugin.zonedSchedule(
        _idFor(occurrence),
        event.title,
        _body(occurrence),
        tz.TZDateTime.from(fireAt, tz.local),
        _details,
        // wall clock time: 07:00 stays 07:00 when the device changes zone
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        androidScheduleMode: _exactAllowed
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } on PlatformException catch (error) {
      // Android can withdraw the exact alarm permission at any time; the
      // inexact variant always works, so a reminder is late rather than lost
      debugPrint('Falling back to an inexact reminder: ${error.message}');
      _exactAllowed = false;
      await _plugin.zonedSchedule(
        _idFor(occurrence),
        event.title,
        _body(occurrence),
        tz.TZDateTime.from(fireAt, tz.local),
        _details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// "Heute um 18:00" plus the place, so the notification says what is coming
  /// without having to open the app.
  String _body(CalendarOccurrence occurrence) {
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
    return location.isEmpty ? when : '$when · $location';
  }

  /// Stable per date of an event, so the same occurrence never ends up
  /// scheduled twice. Kept inside the 32 bit range the platforms expect.
  int _idFor(CalendarOccurrence occurrence) {
    final key = '${occurrence.event.id}@'
        '${occurrence.startAt.toUtc().toIso8601String()}';
    return key.hashCode & 0x7fffffff;
  }

  /// Drops everything pending, used on logout so the next account on this
  /// device is not reminded of the previous one's events.
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
