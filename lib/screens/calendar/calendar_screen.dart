// ignore_for_file: use_build_context_synchronously

import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/state/cache_store.dart';
import 'package:ticktrack/enum/calendar_view_mode_enum.dart';
import 'package:ticktrack/enum/event_color_enum.dart';
import 'package:ticktrack/models/calendar/calendar_event_model.dart';
import 'package:ticktrack/state/avatar_store.dart';
import 'package:ticktrack/state/calendar_view_store.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/state/reminder_sync.dart';
import 'package:ticktrack/util/calendar_export_helper.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/util/share_helper.dart';
import 'package:ticktrack/widgets/app_options_sheet.dart';
import 'package:ticktrack/widgets/calendar/calendar_month_grid.dart';
import 'package:ticktrack/widgets/calendar/calendar_occurrence_tile.dart';
import 'package:ticktrack/widgets/calendar/calendar_week_grid.dart';
import 'package:ticktrack/widgets/empty_state_widget.dart';
import 'package:ticktrack/widgets/group/group_context_switcher.dart';
import 'package:ticktrack/widgets/navigation/bottom_menu.dart';
import 'package:ticktrack/widgets/option_button.dart';
import 'package:ticktrack/widgets/skeleton/skeleton_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:skeletonizer/skeletonizer.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _visibleMonth;
  late DateTime _selectedDay;
  late CalendarViewMode _viewMode;

  Map<DateTime, List<CalendarOccurrence>> _byDay = {};
  bool _isLoading = true;
  bool _isExporting = false;

  String _calendarNameOfYear(AppLocalizations l10n, int year) {
    final groupName = GroupContext().activeGroup?.name;
    return groupName == null
        ? l10n.calendarNameOfYear(year)
        : l10n.calendarNameOfGroupYear(groupName, year);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _viewMode = CalendarViewStore().read();
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
    final int? groupId = GroupContext().activeGroup?.id;
    final String cacheKey = CacheKey.calendarMonth(groupId, _visibleMonth);
    final cached = CacheStore().readList(cacheKey, CalendarOccurrence.fromJson);

    if (cached != null) {
      _showOccurrences(cached.items);
    } else {
      setState(() => _isLoading = true);
    }

    final from = DateTime(_visibleMonth.year, _visibleMonth.month)
        .subtract(const Duration(days: 7));
    final to = DateTime(_visibleMonth.year, _visibleMonth.month + 1)
        .add(const Duration(days: 7));

    try {
      final occurrences = await Backend().getCalendarEvents(
        groupId: groupId,
        from: from,
        to: to,
      );
      await CacheStore().writeList(cacheKey, occurrences);
      if (!mounted) return;
      _showOccurrences(occurrences);
      AvatarStore().sync(
        occurrences.map((o) => o.event.user?.id).whereType<int>().toSet(),
      );
      ReminderSync().sync(force: forceReminderSync);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      await showBackendError(
          context, e, context.l10n.eventsLoadFailed,
          alertWhenOffline: false);
    }
  }

  void _showOccurrences(List<CalendarOccurrence> occurrences) {
    if (!mounted) {
      return;
    }
    setState(() {
      _byDay = _bucketByDay(occurrences);
      _isLoading = false;
    });
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

  void _changeWeek(int delta) {
    final shifted = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day + delta * 7,
    );
    Haptics.tick();
    _moveTo(shifted);
  }

  void _moveTo(DateTime day) {
    final leavesVisibleMonth = !_isInVisibleMonth(day);
    setState(() {
      _selectedDay = day;
      _visibleMonth = DateTime(day.year, day.month);
    });
    if (leavesVisibleMonth) {
      _load();
    }
  }

  bool _isInVisibleMonth(DateTime day) =>
      day.year == _visibleMonth.year && day.month == _visibleMonth.month;

  DateTime _weekStartOf(DateTime day) =>
      DateTime(day.year, day.month, day.day - (day.weekday - 1));

  void _selectDay(DateTime day) {
    Haptics.tick();
    setState(() => _selectedDay = day);
  }

  void _selectWeekDay(DateTime day) {
    Haptics.tick();
    _moveTo(day);
  }

  Future<void> _toggleViewMode() async {
    final nextMode = _viewMode.toggled;
    Haptics.tick();
    setState(() => _viewMode = nextMode);
    await CalendarViewStore().save(nextMode);
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

  Future<List<CalendarEvent>> _loadEventsOfYear(int year) async {
    final firstDayOfYear = DateTime(year);
    final firstDayOfNextYear = DateTime(year + 1);
    final occurrences = await Backend().getCalendarEvents(
      groupId: GroupContext().activeGroup?.id,
      from: firstDayOfYear,
      to: firstDayOfNextYear,
    );
    return distinctEventsOf(occurrences);
  }

  Future<void> _exportCalendar() async {
    Haptics.tap();
    setState(() => _isExporting = true);
    final year = DateTime.now().year;

    try {
      final events = await _loadEventsOfYear(year);

      if (events.isEmpty) {
        _showMessage(context.l10n.calendarNothingToExport(year));
        return;
      }
      await shareCalendar(
        context,
        events: events,
        calendarName: _calendarNameOfYear(context.l10n, year),
      );
    } catch (e) {
      Haptics.warning();
      await showBackendError(
          context, e, context.l10n.calendarExportFailed);
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _deleteEvent(CalendarEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.l10n.eventDeleteTitle,
          style: Theme.of(context).primaryTextTheme.bodySmall,
        ),
        content: Text(
          event.recurrence.repeats
              ? context.l10n.eventDeleteSeriesMessage(event.title)
              : context.l10n.eventDeleteMessage(event.title),
          style: Theme.of(context).primaryTextTheme.titleSmall,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel,
                style: Theme.of(context).primaryTextTheme.titleSmall),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              context.l10n.delete,
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
          context, e, context.l10n.eventDeleteFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _byDay[_selectedDay] ?? const [];

    return Scaffold(
      bottomNavigationBar: const BottomMenu(),
      appBar: AppBar(
        title:
            Text(context.l10n.navCalendar, style: theme.primaryTextTheme.titleMedium),
        centerTitle: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(
            tooltip: _viewMode == CalendarViewMode.week
                ? context.l10n.calendarShowMonthView
                : context.l10n.calendarShowWeekView,
            icon: PhosphorIcon(_viewMode.toggled.icon),
            color: theme.primaryIconTheme.color,
            onPressed: _toggleViewMode,
          ),
          IconButton(
            tooltip: context.l10n.calendarJumpToToday,
            icon: const PhosphorIcon(PhosphorIconsRegular.calendarDot),
            color: theme.primaryIconTheme.color,
            onPressed: _jumpToToday,
          ),
          IconButton(
            tooltip: context.l10n.calendarExport,
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const PhosphorIcon(PhosphorIconsRegular.export),
            color: theme.primaryIconTheme.color,
            onPressed: _isExporting ? null : _exportCalendar,
          ),
          const GroupContextSwitcher(),
          OptionButton(
            onPressed: () => showAppOptionsSheet(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Haptics.tap();
          _openEditor();
        },
        tooltip: context.l10n.eventNew,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(forceReminderSync: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildGrid()),
            const SliverToBoxAdapter(child: Divider(height: 1)),
            ..._buildDaySlivers(theme, selected),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    if (_viewMode == CalendarViewMode.week) {
      return CalendarWeekGrid(
        weekStart: _weekStartOf(_selectedDay),
        selectedDay: _selectedDay,
        occurrencesByDay: _byDay,
        onDaySelected: _selectWeekDay,
        onOccurrenceTap: (occurrence) => _openEditor(event: occurrence.event),
        onPreviousWeek: () => _changeWeek(-1),
        onNextWeek: () => _changeWeek(1),
      );
    }

    return CalendarMonthGrid(
      visibleMonth: _visibleMonth,
      selectedDay: _selectedDay,
      eventColorsByDay: _colorsByDay(),
      onDaySelected: _selectDay,
      onPreviousMonth: () => _changeMonth(-1),
      onNextMonth: () => _changeMonth(1),
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
              title: context.l10n.calendarNothingOn(
                DateFormat.MMMMd().format(_selectedDay),
              ),
              message: context.l10n.calendarEmptyMessage),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            DateFormat.yMMMMEEEEd().format(_selectedDay),
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
