import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:ticktrack/l10n/l10n.dart';

import 'package:ticktrack/enum/event_color_enum.dart';
import 'package:ticktrack/enum/event_recurrence_enum.dart';
import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/models/activity/activity_model.dart';
import 'package:ticktrack/models/calendar/calendar_event_model.dart';
import 'package:ticktrack/models/group/group_api_model.dart';
import 'package:ticktrack/models/task/task_api_model.dart';
import 'package:blvckleg_dart_core/models/user/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

T _throughJson<T>(Object model, T Function(Map<String, dynamic>) fromJson) {
  final encoded = jsonEncode(model);
  return fromJson(jsonDecode(encoded) as Map<String, dynamic>);
}

CalendarEvent _event({
  DateTime? startAt,
  EventRecurrence recurrence = EventRecurrence.none,
  EventColor? color,
  int? remindMinutesBefore,
}) {
  final start = startAt ?? DateTime(2026, 8, 11, 14, 30);
  return CalendarEvent(
    id: 1,
    title: 'Zahnarzt',
    description: 'Kontrolle',
    location: 'Innsbruck',
    startAt: start,
    endAt: start.add(const Duration(hours: 1)),
    allDay: false,
    recurrence: recurrence,
    privacyMode: PrivacyMode.protected,
    color: color,
    remindMinutesBefore: remindMinutesBefore,
    groupId: 3,
    user: User(id: 9, username: 'tester'),
  );
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('CalendarEvent', () {
    test('übersteht den Roundtrip mit allen Feldern', () {
      final original = _event(
        recurrence: EventRecurrence.weekly,
        color: EventColor.values.first,
        remindMinutesBefore: 15,
      );

      final restored = _throughJson(original, CalendarEvent.fromJson);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.description, original.description);
      expect(restored.location, original.location);
      expect(restored.allDay, original.allDay);
      expect(restored.recurrence, EventRecurrence.weekly);
      expect(restored.color, original.color);
      expect(restored.remindMinutesBefore, 15);
      expect(restored.privacyMode, PrivacyMode.protected);
      expect(restored.groupId, 3);
      expect(restored.user?.username, 'tester');
    });

    test('behält den exakten Zeitpunkt über die Zeitzone hinweg', () {
      final original = _event();

      final restored = _throughJson(original, CalendarEvent.fromJson);

      expect(restored.startAt.isAtSameMomentAs(original.startAt), isTrue);
      expect(restored.endAt.isAtSameMomentAs(original.endAt), isTrue);
      expect(restored.startAt.isUtc, isFalse);
    });

    test('optionale Felder bleiben null', () {
      final restored = _throughJson(_event(), CalendarEvent.fromJson);

      expect(restored.color, isNull);
      expect(restored.remindMinutesBefore, isNull);
      expect(restored.recurrenceEndDate, isNull);
    });
  });

  group('CalendarOccurrence', () {
    test('übersteht den Roundtrip samt eingebettetem Event', () {
      final original = CalendarOccurrence(
        event: _event(),
        startAt: DateTime(2026, 8, 11, 14, 30),
        endAt: DateTime(2026, 8, 11, 15, 30),
        isRecurrence: true,
      );

      final restored = _throughJson(original, CalendarOccurrence.fromJson);

      expect(restored.isRecurrence, isTrue);
      expect(restored.event.title, 'Zahnarzt');
      expect(restored.startAt.isAtSameMomentAs(original.startAt), isTrue);
      expect(restored.endAt.isAtSameMomentAs(original.endAt), isTrue);
    });
  });

  group('EventlogMessage', () {
    test('übersteht den Roundtrip mit Gruppe', () {
      final original = EventlogMessage<dynamic>(
        actionType: '1',
        entityType: groupEntityType,
        entityId: '42',
        actionStatus: 'ok',
        date: DateTime(2026, 8, 11, 9),
        user: AcitvityUser(username: 'tester', id: 9),
        group: ActivityGroup(id: 3, name: 'Familie'),
      );

      final restored = _throughJson(original, EventlogMessage.fromJson);

      expect(restored.actionType, '1');
      expect(restored.entityType, groupEntityType);
      expect(restored.entityId, '42');
      expect(restored.actionStatus, 'ok');
      expect(restored.user.username, 'tester');
      expect(restored.group?.name, 'Familie');
      expect(restored.date.isAtSameMomentAs(original.date), isTrue);
    });

    test('bleibt ohne Gruppe lesbar', () {
      final original = EventlogMessage<dynamic>(
        actionType: '2',
        entityType: 'note',
        entityId: '7',
        actionStatus: 'ok',
        date: DateTime(2026, 8, 11, 9),
        user: AcitvityUser(username: 'tester', id: 9),
      );

      final restored = _throughJson(original, EventlogMessage.fromJson);

      expect(restored.group, isNull);
      expect(restored.groupActivityText(l10n), isNull);
    });
  });

  group('Task und Group', () {
    test('Task übersteht den Roundtrip', () {
      final original = Task(
        id: 5,
        title: 'Einkaufen',
        content: 'Milch und Brot',
        isDone: true,
      );

      final restored = _throughJson(original, Task.fromJson);

      expect(restored.id, 5);
      expect(restored.title, 'Einkaufen');
      expect(restored.content, 'Milch und Brot');
      expect(restored.isDone, isTrue);
    });

    test('Group übersteht den Roundtrip samt Mitgliedern', () {
      final original = Group(
        id: 3,
        name: 'Familie',
        joinCode: 'A2B3C4D5',
        ownerId: 9,
        members: [User(id: 9, username: 'tester')],
      );

      final restored = _throughJson(original, Group.fromJson);

      expect(restored.id, 3);
      expect(restored.name, 'Familie');
      expect(restored.joinCode, 'A2B3C4D5');
      expect(restored.ownerId, 9);
      expect(restored.members.single.username, 'tester');
    });
  });
}
