import 'dart:math';

import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/enum/event_color_enum.dart';
import 'package:ticktrack/models/calendar/calendar_event_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

const int _daysPerWeek = 7;
const double _hourHeight = 56;
const double _timeGutterWidth = 46;
const double _minimumBlockHeight = 26;
const double _blockGap = 2;
const double _allDayChipHeight = 20;
const int _maxAllDayChips = 2;
const int _earliestDefaultHour = 7;
const int _latestDefaultHour = 21;

class CalendarWeekGrid extends StatelessWidget {
  final DateTime weekStart;
  final DateTime selectedDay;

  final Map<DateTime, List<CalendarOccurrence>> occurrencesByDay;

  final void Function(DateTime day) onDaySelected;
  final void Function(CalendarOccurrence occurrence) onOccurrenceTap;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;

  const CalendarWeekGrid({
    super.key,
    required this.weekStart,
    required this.selectedDay,
    required this.occurrencesByDay,
    required this.onDaySelected,
    required this.onOccurrenceTap,
    required this.onPreviousWeek,
    required this.onNextWeek,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _daysOfWeek();
    final hourWindow = _hourWindowOf(days);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        children: [
          _buildHeader(context, theme, days),
          _buildDayLabels(context, theme, days),
          _buildAllDayRow(context, theme, days),
          const SizedBox(height: 4),
          _buildHourGrid(context, theme, days, hourWindow),
        ],
      ),
    );
  }

  List<DateTime> _daysOfWeek() {
    return List.generate(
      _daysPerWeek,
      (index) => DateTime(weekStart.year, weekStart.month, weekStart.day + index),
    );
  }

  List<CalendarOccurrence> _allDayOccurrencesOf(DateTime day) {
    return (occurrencesByDay[day] ?? const <CalendarOccurrence>[])
        .where(_coversWholeDay)
        .toList();
  }

  List<CalendarOccurrence> _timedOccurrencesOf(DateTime day) {
    return (occurrencesByDay[day] ?? const <CalendarOccurrence>[])
        .where((occurrence) => !_coversWholeDay(occurrence))
        .toList();
  }

  bool _coversWholeDay(CalendarOccurrence occurrence) =>
      occurrence.event.allDay || occurrence.spansDays;

  _HourWindow _hourWindowOf(List<DateTime> days) {
    var firstHour = _earliestDefaultHour;
    var lastHour = _latestDefaultHour;
    for (final day in days) {
      for (final occurrence in _timedOccurrencesOf(day)) {
        firstHour = min(firstHour, occurrence.startAt.hour);
        lastHour = max(lastHour, _hourAfter(occurrence.endAt));
      }
    }
    return _HourWindow(firstHour, max(lastHour, firstHour + 1));
  }

  int _hourAfter(DateTime moment) =>
      min(24, moment.minute > 0 ? moment.hour + 1 : moment.hour);

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    List<DateTime> days,
  ) {
    final monthFormat = DateFormat.MMMd();
    return Row(
      children: [
        IconButton(
          tooltip: context.l10n.calendarPreviousWeek,
          icon: const PhosphorIcon(PhosphorIconsRegular.caretLeft),
          color: theme.primaryIconTheme.color,
          onPressed: onPreviousWeek,
        ),
        Expanded(
          child: Text(
            context.l10n.calendarWeekRange(
              monthFormat.format(days.first),
              DateFormat.yMMMd().format(days.last),
            ),
            textAlign: TextAlign.center,
            style: theme.primaryTextTheme.displayLarge,
          ),
        ),
        IconButton(
          tooltip: context.l10n.calendarNextWeek,
          icon: const PhosphorIcon(PhosphorIconsRegular.caretRight),
          color: theme.primaryIconTheme.color,
          onPressed: onNextWeek,
        ),
      ],
    );
  }

  Widget _buildDayLabels(
    BuildContext context,
    ThemeData theme,
    List<DateTime> days,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(width: _timeGutterWidth),
        for (final day in days)
          Expanded(child: _buildDayLabel(context, theme, day)),
      ],
    );
  }

  Widget _buildDayLabel(BuildContext context, ThemeData theme, DateTime day) {
    final isSelected = _isSameDay(day, selectedDay);
    final isToday = _isSameDay(day, DateTime.now());
    final textColor = isSelected
        ? (theme.brightness == Brightness.light ? Colors.white : Colors.grey[900])
        : theme.primaryTextTheme.bodySmall?.color;

    return InkWell(
      onTap: () => onDaySelected(day),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Text(
              DateFormat.E().format(day),
              style: theme.primaryTextTheme.displayMedium,
            ),
            const SizedBox(height: 2),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? theme.primaryColor : null,
                shape: BoxShape.circle,
                border: isToday && !isSelected
                    ? Border.all(color: theme.primaryColor, width: 1.5)
                    : null,
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: theme.primaryTextTheme.bodySmall?.copyWith(
                    color: textColor,
                    fontWeight: isToday || isSelected ? FontWeight.bold : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllDayRow(
    BuildContext context,
    ThemeData theme,
    List<DateTime> days,
  ) {
    final chipRows = days
        .map((day) => min(_allDayOccurrencesOf(day).length, _maxAllDayChips + 1))
        .fold(0, max);
    if (chipRows == 0) {
      return const SizedBox(height: 6);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _timeGutterWidth,
            child: Text(
              context.l10n.eventAllDay,
              textAlign: TextAlign.right,
              style: theme.primaryTextTheme.displayMedium,
            ),
          ),
          for (final day in days)
            Expanded(
              child: SizedBox(
                height: chipRows * _allDayChipHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _buildAllDayChips(context, theme, day),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildAllDayChips(
    BuildContext context,
    ThemeData theme,
    DateTime day,
  ) {
    final occurrences = _allDayOccurrencesOf(day);
    final visible = occurrences.take(_maxAllDayChips).toList();
    final hidden = occurrences.length - visible.length;

    return [
      for (final occurrence in visible)
        _buildChip(
          context,
          theme,
          occurrence.event.title,
          eventColorOf(context, occurrence.event.color),
          () => onOccurrenceTap(occurrence),
        ),
      if (hidden > 0)
        _buildChip(
          context,
          theme,
          '+$hidden',
          theme.primaryColor,
          () => onDaySelected(day),
        ),
    ];
  }

  Widget _buildChip(
    BuildContext context,
    ThemeData theme,
    String label,
    Color accent,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 1, right: 1, bottom: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: _allDayChipHeight - 2,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(4),
            border: Border(left: BorderSide(color: accent, width: 2)),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.primaryTextTheme.displayMedium?.copyWith(
              fontSize: 10,
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHourGrid(
    BuildContext context,
    ThemeData theme,
    List<DateTime> days,
    _HourWindow window,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHourLabels(theme, window),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dayWidth = constraints.maxWidth / _daysPerWeek;
              return SizedBox(
                height: window.hourCount * _hourHeight,
                child: Stack(
                  children: [
                    ..._buildHourLines(theme, window),
                    ..._buildDayDividers(theme, dayWidth, window),
                    ..._buildTimedBlocks(
                        context, theme, days, window, dayWidth),
                    ..._buildNowIndicator(theme, days, window),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHourLabels(ThemeData theme, _HourWindow window) {
    final hourFormat = DateFormat.j();
    return SizedBox(
      width: _timeGutterWidth,
      child: Column(
        children: [
          for (var hour = window.firstHour; hour < window.lastHour; hour++)
            SizedBox(
              height: _hourHeight,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  hourFormat.format(DateTime(2024, 1, 1, hour)),
                  textAlign: TextAlign.right,
                  style: theme.primaryTextTheme.displayMedium?.copyWith(
                    fontSize: 10,
                    color: theme.primaryTextTheme.displayMedium?.color
                        ?.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildHourLines(ThemeData theme, _HourWindow window) {
    return [
      for (var hour = 0; hour <= window.hourCount; hour++)
        Positioned(
          top: hour * _hourHeight,
          left: 0,
          right: 0,
          child: Divider(
            height: 1,
            thickness: 1,
            color: theme.dividerColor.withValues(alpha: 0.4),
          ),
        ),
    ];
  }

  List<Widget> _buildDayDividers(
    ThemeData theme,
    double dayWidth,
    _HourWindow window,
  ) {
    return [
      for (var dayIndex = 1; dayIndex < _daysPerWeek; dayIndex++)
        Positioned(
          left: dayIndex * dayWidth,
          top: 0,
          height: window.hourCount * _hourHeight,
          child: VerticalDivider(
            width: 1,
            thickness: 1,
            color: theme.dividerColor.withValues(alpha: 0.4),
          ),
        ),
    ];
  }

  List<Widget> _buildTimedBlocks(
    BuildContext context,
    ThemeData theme,
    List<DateTime> days,
    _HourWindow window,
    double dayWidth,
  ) {
    final blocks = <Widget>[];
    for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
      final laidOut = _layOutDay(_timedOccurrencesOf(days[dayIndex]));
      blocks.addAll(
        laidOut.map(
          (block) => _buildBlock(context, theme, block, dayIndex, dayWidth, window),
        ),
      );
    }
    return blocks;
  }

  List<_TimedBlock> _layOutDay(List<CalendarOccurrence> occurrences) {
    final blocks = occurrences.map(_TimedBlock.of).toList()
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    var cluster = <_TimedBlock>[];
    var clusterEnd = double.negativeInfinity;
    for (final block in blocks) {
      if (cluster.isNotEmpty && block.startMinute >= clusterEnd) {
        _spreadOverLanes(cluster);
        cluster = [];
      }
      cluster.add(block);
      clusterEnd = max(clusterEnd, block.endMinute);
    }
    _spreadOverLanes(cluster);
    return blocks;
  }

  void _spreadOverLanes(List<_TimedBlock> cluster) {
    final laneEnds = <double>[];
    for (final block in cluster) {
      final freeLane =
          laneEnds.indexWhere((laneEnd) => laneEnd <= block.startMinute);
      block.lane = freeLane == -1 ? laneEnds.length : freeLane;
      if (freeLane == -1) {
        laneEnds.add(block.endMinute);
      } else {
        laneEnds[freeLane] = block.endMinute;
      }
    }
    for (final block in cluster) {
      block.laneCount = laneEnds.length;
    }
  }

  Widget _buildBlock(
    BuildContext context,
    ThemeData theme,
    _TimedBlock block,
    int dayIndex,
    double dayWidth,
    _HourWindow window,
  ) {
    final accent = eventColorOf(context, block.occurrence.event.color);
    final laneWidth = (dayWidth - _blockGap) / block.laneCount;
    final height = max(
      (block.endMinute - block.startMinute) / 60 * _hourHeight,
      _minimumBlockHeight,
    );

    return Positioned(
      top: (block.startMinute - window.firstMinute) / 60 * _hourHeight,
      left: dayIndex * dayWidth + block.lane * laneWidth + _blockGap,
      width: laneWidth - _blockGap,
      height: height - _blockGap,
      child: InkWell(
        onTap: () => onOccurrenceTap(block.occurrence),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(4),
            border: Border(left: BorderSide(color: accent, width: 2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                block.occurrence.event.title,
                maxLines: height >= 44 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: theme.primaryTextTheme.displayMedium?.copyWith(
                  fontSize: 10,
                  height: 1.15,
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (height >= 58)
                Text(
                  DateFormat.jm().format(block.occurrence.startAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.primaryTextTheme.displayMedium?.copyWith(
                    fontSize: 9,
                    color: accent.withValues(alpha: 0.85),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNowIndicator(
    ThemeData theme,
    List<DateTime> days,
    _HourWindow window,
  ) {
    final now = DateTime.now();
    final dayIndex = days.indexWhere((day) => _isSameDay(day, now));
    final nowMinute = now.hour * 60 + now.minute.toDouble();
    if (dayIndex == -1 ||
        nowMinute < window.firstMinute ||
        nowMinute > window.lastMinute) {
      return const [];
    }

    return [
      Positioned(
        top: (nowMinute - window.firstMinute) / 60 * _hourHeight,
        left: 0,
        right: 0,
        child: Container(height: 1.5, color: theme.colorScheme.error),
      ),
    ];
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _HourWindow {
  final int firstHour;
  final int lastHour;

  const _HourWindow(this.firstHour, this.lastHour);

  int get hourCount => lastHour - firstHour;

  double get firstMinute => firstHour * 60;

  double get lastMinute => lastHour * 60;
}

class _TimedBlock {
  final CalendarOccurrence occurrence;
  final double startMinute;
  final double endMinute;

  int lane = 0;
  int laneCount = 1;

  _TimedBlock({
    required this.occurrence,
    required this.startMinute,
    required this.endMinute,
  });

  factory _TimedBlock.of(CalendarOccurrence occurrence) {
    final start = occurrence.startAt.hour * 60 + occurrence.startAt.minute;
    final end = occurrence.endAt.hour * 60 + occurrence.endAt.minute;
    return _TimedBlock(
      occurrence: occurrence,
      startMinute: start.toDouble(),
      endMinute: max(end, start + 15).toDouble(),
    );
  }
}
