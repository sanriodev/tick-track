// ignore_for_file: use_build_context_synchronously

import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/enum/event_color_enum.dart';
import 'package:ticktrack/models/calendar/calendar_event_model.dart';
import 'package:ticktrack/state/avatar_store.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/state/reminder_sync.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/widgets/app_drawer_widget.dart';
import 'package:ticktrack/widgets/calendar/calendar_month_grid.dart';
import 'package:ticktrack/widgets/calendar/calendar_occurrence_tile.dart';
import 'package:ticktrack/widgets/empty_state_widget.dart';
import 'package:ticktrack/widgets/group/group_context_switcher.dart';
import 'package:ticktrack/widgets/navigation/bottom_menu.dart';
import 'package:ticktrack/widgets/option_button.dart';
import 'package:ticktrack/widgets/skeleton/skeleton_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  Map<DateTime, List<CalendarOccurrence>> _byDay = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    GroupContext().addListener(_onGroupContextChanged);
    _load();
  }

  @override
  void dispose() {
    GroupContext().removeListener(_onGroupContextChanged);
    super.dispose();
  }

  void _onGroupContextChanged() {
    if (mounted) {
      _load(forceReminderSync: true);
    }
  }

  Future<void> _load({bool forceReminderSync = false}) async {
    setState(() => _isLoading = true);
    final from = DateTime(_visibleMonth.year, _visibleMonth.month)
        .subtract(const Duration(days: 7));
    final to = DateTime(_visibleMonth.year, _visibleMonth.month + 1)
        .add(const Duration(days: 7));

    try {
      final occurrences = await Backend().getCalendarEvents(
        groupId: GroupContext().activeGroup?.id,
        from: from,
        to: to,
      );
      if (!mounted) return;
      setState(() {
        _byDay = _bucketByDay(occurrences);
        _isLoading = false;
      });
      AvatarStore().sync(
        occurrences.map((o) => o.event.user?.id).whereType<int>().toSet(),
      );
      ReminderSync().sync(force: forceReminderSync);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      await showBackendError(
          context, e, 'Kalenderevents konnten nicht geladen werden');
    }
  }

  Map<DateTime, List<CalendarOccurrence>> _bucketByDay(
    List<CalendarOccurrence> occurrences,
  ) {
    final map = <DateTime, List<CalendarOccurrence>>{};
    for (final occurrence in occurrences) {
      var day = occurrence.day;
      final lastDay = DateTime(
        occurrence.endAt.year,
        occurrence.endAt.month,
        occurrence.endAt.day,
      );
      var guard = 0;
      while (!day.isAfter(lastDay) && guard < 400) {
        map.putIfAbsent(day, () => []).add(occurrence);
        day = DateTime(day.year, day.month, day.day + 1);
        guard++;
      }
    }
    for (final entry in map.entries) {
      entry.value.sort((a, b) {
        if (a.event.allDay != b.event.allDay) {
          return a.event.allDay ? -1 : 1;
        }
        return a.startAt.compareTo(b.startAt);
      });
    }
    return map;
  }

  Map<DateTime, List<EventColor?>> _colorsByDay() {
    return _byDay.map(
      (day, occurrences) => MapEntry(
        day,
        occurrences.map((occurrence) => occurrence.event.color).toList(),
      ),
    );
  }

  void _changeMonth(int delta) {
    Haptics.tick();
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      final daysInMonth =
          DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
      _selectedDay = DateTime(
        _visibleMonth.year,
        _visibleMonth.month,
        _selectedDay.day <= daysInMonth ? _selectedDay.day : 1,
      );
    });
    _load();
  }

  void _jumpToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sameMonth =
        _visibleMonth.year == today.year && _visibleMonth.month == today.month;
    Haptics.tick();
    setState(() {
      _visibleMonth = DateTime(today.year, today.month);
      _selectedDay = today;
    });
    if (!sameMonth) {
      _load();
    }
  }

  Future<void> _openEditor({CalendarEvent? event}) async {
    await navigateToRoute(
      context,
      'calendar-event-edit',
      extra: CalendarEditorArgs(event: event, day: _selectedDay),
      backEnabled: true,
    );
    if (mounted) {
      await _load(forceReminderSync: true);
    }
  }

  Future<void> _deleteEvent(CalendarEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Kalenderevent löschen?',
          style: Theme.of(context).primaryTextTheme.bodySmall,
        ),
        content: Text(
          event.recurrence.repeats
              ? '"${event.title}" wird mit allen Wiederholungen gelöscht.'
              : '"${event.title}" wird gelöscht.',
          style: Theme.of(context).primaryTextTheme.titleSmall,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Abbrechen',
                style: Theme.of(context).primaryTextTheme.titleSmall),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Löschen',
              style: Theme.of(context).primaryTextTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      await Backend().deleteCalendarEvent(event.id);
      Haptics.tap();
      await _load(forceReminderSync: true);
    } catch (e) {
      Haptics.warning();
      await showBackendError(
          context, e, 'Kalenderevent konnte nicht gelöscht werden');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _byDay[_selectedDay] ?? const [];

    return Scaffold(
      key: _scaffoldKey,
      bottomNavigationBar: const BottomMenu(),
      appBar: AppBar(
        title: Text('Kalender', style: theme.primaryTextTheme.titleMedium),
        centerTitle: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(
            tooltip: 'Zu heute',
            icon: const PhosphorIcon(PhosphorIconsRegular.calendarDot),
            color: theme.primaryIconTheme.color,
            onPressed: _jumpToToday,
          ),
          const GroupContextSwitcher(),
          OptionButton(
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Haptics.tap();
          _openEditor();
        },
        tooltip: 'Neues Kalenderevent',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(forceReminderSync: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: CalendarMonthGrid(
                visibleMonth: _visibleMonth,
                selectedDay: _selectedDay,
                eventColorsByDay: _colorsByDay(),
                onDaySelected: (day) {
                  Haptics.tick();
                  setState(() => _selectedDay = day);
                },
                onPreviousMonth: () => _changeMonth(-1),
                onNextMonth: () => _changeMonth(1),
              ),
            ),
            const SliverToBoxAdapter(child: Divider(height: 1)),
            ..._buildDaySlivers(theme, selected),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDaySlivers(
    ThemeData theme,
    List<CalendarOccurrence> selected,
  ) {
    if (_isLoading) {
      return [
        SliverToBoxAdapter(
          child: Skeletonizer(
            effect: ShimmerEffect(
              baseColor: theme.canvasColor,
              duration: const Duration(seconds: 3),
            ),
            child: const SkeletonCard(),
          ),
        ),
      ];
    }
    if (selected.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyStateWidget(
              scrollable: false,
              icon: PhosphorIconsRegular.calendarBlank,
              title: 'Nichts am ${DateFormat('d. MMMM').format(_selectedDay)}',
              message: 'Müllabfuhr, Putztag, Besuch - trag ein, was die Gruppe '
                  'wissen sollte.'),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            DateFormat('EEEE, d. MMMM y').format(_selectedDay),
            style: theme.primaryTextTheme.displayLarge,
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
        sliver: SliverList.builder(
          itemCount: selected.length,
          itemBuilder: (context, index) {
            final occurrence = selected[index];
            return CalendarOccurrenceTile(
              occurrence: occurrence,
              onTap: () => _openEditor(event: occurrence.event),
              onDelete: () => _deleteEvent(occurrence.event),
              onBlocked: _load,
            );
          },
        ),
      ),
    ];
  }
}

class CalendarEditorArgs {
  final CalendarEvent? event;
  final DateTime day;

  const CalendarEditorArgs({this.event, required this.day});
}
