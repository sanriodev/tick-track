import 'package:ticktrack/enum/event_recurrence_enum.dart';
import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/models/calendar/calendar_event_model.dart';
import 'package:ticktrack/state/reminder_scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notifications =
      MethodChannel('dexterous.com/flutter/local_notifications');
  const timezone = MethodChannel('flutter_timezone');

  final scheduled = <Map<Object?, Object?>>[];
  var cancelAllCalls = 0;

  setUp(() {
    scheduled.clear();
    cancelAllCalls = 0;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(timezone, (call) async {
      if (call.method == 'getLocalTimezone') {
        return 'Europe/Berlin';
      }
      return null;
    });

    messenger.setMockMethodCallHandler(notifications, (call) async {
      switch (call.method) {
        case 'initialize':
          return true;
        case 'areNotificationsEnabled':
        case 'canScheduleExactNotifications':
          return true;
        case 'cancelAll':
          cancelAllCalls++;
          return null;
        case 'zonedSchedule':
          scheduled.add(call.arguments as Map<Object?, Object?>);
          return null;
      }
      return null;
    });
  });

  List<CalendarOccurrence> series({
    required int id,
    required String title,
    required DateTime first,
    required Duration step,
    required int count,
    required EventRecurrence recurrence,
    int remindMinutesBefore = 30,
  }) {
    final event = CalendarEvent(
      id: id,
      title: title,
      startAt: first,
      endAt: first.add(const Duration(hours: 1)),
      allDay: false,
      recurrence: recurrence,
      privacyMode: PrivacyMode.protected,
      remindMinutesBefore: remindMinutesBefore,
    );
    return [
      for (var i = 0; i < count; i++)
        CalendarOccurrence(
          event: event,
          startAt: first.add(step * i),
          endAt: first.add(step * i).add(const Duration(hours: 1)),
          isRecurrence: i > 0,
        ),
    ];
  }

  List<String?> scheduledTitles() =>
      scheduled.map((entry) => entry['title'] as String?).toList();

  test('a daily series does not take the slots of the other calendars',
      () async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    await ReminderScheduler().reschedule([
      ReminderCalendar(
        occurrences: series(
          id: 1,
          title: 'Tabletten',
          first: tomorrow,
          step: const Duration(days: 1),
          count: 60,
          recurrence: EventRecurrence.daily,
        ),
      ),
      ReminderCalendar(
        groupName: 'WG',
        occurrences: series(
          id: 2,
          title: 'Müllabfuhr',
          first: tomorrow.add(const Duration(days: 3)),
          step: const Duration(days: 7),
          count: 8,
          recurrence: EventRecurrence.weekly,
        ),
      ),
      ReminderCalendar(
        groupName: 'Familie',
        occurrences: series(
          id: 3,
          title: 'Oma anrufen',
          first: tomorrow.add(const Duration(days: 50)),
          step: const Duration(days: 30),
          count: 2,
          recurrence: EventRecurrence.monthly,
        ),
      ),
    ]);

    expect(cancelAllCalls, 1);
    expect(scheduledTitles(), contains('Tabletten'));
    expect(scheduledTitles(), contains('Müllabfuhr'));
    expect(scheduledTitles(), contains('Oma anrufen'));
    expect(scheduled.length, lessThanOrEqualTo(48));
  });

  test('the group is part of the notification, the personal calendar is not',
      () async {
    final soon = DateTime.now().add(const Duration(hours: 2));

    await ReminderScheduler().reschedule([
      ReminderCalendar(
        occurrences: series(
          id: 10,
          title: 'Zahnarzt',
          first: soon,
          step: const Duration(days: 1),
          count: 1,
          recurrence: EventRecurrence.none,
        ),
      ),
      ReminderCalendar(
        groupName: 'WG',
        occurrences: series(
          id: 11,
          title: 'Müllabfuhr',
          first: soon,
          step: const Duration(days: 1),
          count: 1,
          recurrence: EventRecurrence.none,
        ),
      ),
    ]);

    final bodies = {
      for (final entry in scheduled)
        entry['title'] as String?: entry['body'] as String?,
    };
    expect(bodies['Müllabfuhr'], endsWith('· WG'));
    expect(bodies['Zahnarzt'], isNot(contains('·')));
  });

  test('reminders whose moment has passed are left out', () async {
    final inTenMinutes = DateTime.now().add(const Duration(minutes: 10));

    await ReminderScheduler().reschedule([
      ReminderCalendar(
        occurrences: [
          ...series(
            id: 20,
            title: 'Schon vorbei',
            first: inTenMinutes,
            step: const Duration(days: 1),
            count: 1,
            recurrence: EventRecurrence.none,
          ),
          ...series(
            id: 21,
            title: 'Kommt noch',
            first: inTenMinutes,
            step: const Duration(days: 1),
            count: 1,
            recurrence: EventRecurrence.none,
            remindMinutesBefore: 5,
          ),
        ],
      ),
    ]);

    expect(scheduledTitles(), ['Kommt noch']);
  });

  test('an event without a reminder is not scheduled', () async {
    final event = CalendarEvent(
      id: 30,
      title: 'Ohne Erinnerung',
      startAt: DateTime.now().add(const Duration(days: 2)),
      endAt: DateTime.now().add(const Duration(days: 2, hours: 1)),
      allDay: false,
      recurrence: EventRecurrence.none,
      privacyMode: PrivacyMode.private,
    );

    await ReminderScheduler().reschedule([
      ReminderCalendar(
        occurrences: [
          CalendarOccurrence(
            event: event,
            startAt: event.startAt,
            endAt: event.endAt,
            isRecurrence: false,
          ),
        ],
      ),
    ]);

    expect(scheduled, isEmpty);
    expect(cancelAllCalls, 1);
  });
}
