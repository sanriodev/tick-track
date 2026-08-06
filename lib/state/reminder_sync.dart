import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/state/reminder_scheduler.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/foundation.dart';

/// Loads what the device should remind about and hands it to the
/// [ReminderScheduler].
///
/// Deliberately not driven by the calendar screen: that screen shows one group
/// and one month, and rebuilding the reminders from it dropped every reminder
/// of the other groups and of the personal calendar. This asks every calendar
/// the user has for a fixed window instead, so the pending set is complete no
/// matter which group is active or which month someone is looking at.
class ReminderSync {
  static final ReminderSync _instance = ReminderSync._privateConstructor();
  factory ReminderSync() => _instance;
  ReminderSync._privateConstructor();

  /// How far ahead reminders are loaded. The scheduler only keeps the nearest
  /// [_maxScheduled] of them anyway, so a wider window buys nothing - it just
  /// makes the backend expand more repetitions.
  static const Duration _horizon = Duration(days: 60);

  /// Shortest gap between two syncs. Opening the calendar, changing the month
  /// and switching group all ask for one, and each sync is a request per
  /// calendar - without this, paging through a year would be a request storm.
  static const Duration _minInterval = Duration(minutes: 5);

  DateTime? _lastSync;
  Future<void>? _running;

  /// Rebuilds the pending reminders from all calendars.
  ///
  /// Cheap to call from anywhere: too soon after the last one it does nothing,
  /// and a caller arriving while one is in flight waits for that one instead of
  /// starting a second. Pass [force] after something actually changed - a new
  /// event, an edited reminder, a fresh login.
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

    final future = _sync();
    _running = future;
    return future.whenComplete(() => _running = null);
  }

  Future<void> _sync() async {
    final from = DateTime.now();
    final to = from.add(_horizon);

    // the personal calendar is the one without a group, and it has reminders
    // just like the group ones
    final sources = <({int? id, String? name})>[
      (id: null, name: null),
      for (final group in GroupContext().groups)
        (id: group.id, name: group.name),
    ];

    final loaded = await Future.wait(
      sources.map((source) async {
        try {
          return ReminderCalendar(
            groupName: source.name,
            occurrences: await Backend().getCalendarEvents(
              groupId: source.id,
              from: from,
              to: to,
            ),
          );
        } catch (error) {
          final which = source.name ?? 'the personal calendar';
          debugPrint('Could not load the reminders of $which: $error');
          return null;
        }
      }),
    );

    // Rescheduling starts by cancelling everything, so a partial result would
    // silently drop the reminders of whatever failed to load. Keeping the
    // pending set as it is leaves them stale at worst, and the next sync - on
    // the next calendar visit or app start - tries again.
    if (loaded.any((calendar) => calendar == null)) {
      debugPrint('Skipping the reminder sync, a calendar could not be loaded');
      return;
    }

    _lastSync = DateTime.now();
    await ReminderScheduler().reschedule(loaded.nonNulls.toList());
  }

  /// Lets the next [sync] run right away, used on logout so the following login
  /// is not held off by the interval of the previous account.
  void reset() {
    _lastSync = null;
  }
}
