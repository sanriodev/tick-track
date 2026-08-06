import 'package:ticktrack/enum/event_color_enum.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

const int _maxDots = 3;

class CalendarMonthGrid extends StatelessWidget {
  final DateTime visibleMonth;
  final DateTime selectedDay;

  final Map<DateTime, List<EventColor?>> eventColorsByDay;

  final void Function(DateTime day) onDaySelected;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const CalendarMonthGrid({
    super.key,
    required this.visibleMonth,
    required this.selectedDay,
    required this.eventColorsByDay,
    required this.onDaySelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        children: [
          _buildHeader(theme),
          _buildWeekdayLabels(theme),
          const SizedBox(height: 4),
          ..._buildWeeks(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Vorheriger Monat',
          icon: const PhosphorIcon(PhosphorIconsRegular.caretLeft),
          color: theme.primaryIconTheme.color,
          onPressed: onPreviousMonth,
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM y').format(visibleMonth),
            textAlign: TextAlign.center,
            style: theme.primaryTextTheme.displayLarge,
          ),
        ),
        IconButton(
          tooltip: 'Nächster Monat',
          icon: const PhosphorIcon(PhosphorIconsRegular.caretRight),
          color: theme.primaryIconTheme.color,
          onPressed: onNextMonth,
        ),
      ],
    );
  }

  Widget _buildWeekdayLabels(ThemeData theme) {
    const labels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Center(
              child: Text(label, style: theme.primaryTextTheme.displayMedium),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildWeeks(ThemeData theme) {
    final first = DateTime(visibleMonth.year, visibleMonth.month);
    final leading = first.weekday - 1;
    final daysInMonth =
        DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    final cellCount = ((leading + daysInMonth) / 7).ceil() * 7;

    final rows = <Widget>[];
    for (var week = 0; week < cellCount / 7; week++) {
      rows.add(Row(
        children: [
          for (var weekday = 0; weekday < 7; weekday++)
            Expanded(
              child: _buildCell(theme, first, leading, week * 7 + weekday),
            ),
        ],
      ));
    }
    return rows;
  }

  Widget _buildCell(
    ThemeData theme,
    DateTime firstOfMonth,
    int leading,
    int cellIndex,
  ) {
    final day = DateTime(
      firstOfMonth.year,
      firstOfMonth.month,
      cellIndex - leading + 1,
    );
    final inMonth = day.month == firstOfMonth.month;
    final isSelected = _isSameDay(day, selectedDay);
    final isToday = _isSameDay(day, DateTime.now());

    final colors = eventColorsByDay[day] ?? const [];
    final hasEvents = colors.isNotEmpty;
    final resolved = colors
        .map((color) => color?.resolve(theme.brightness) ?? theme.primaryColor)
        .toList();
    final tint = hasEvents && !isSelected
        ? resolved.first.withValues(alpha: inMonth ? 0.22 : 0.1)
        : null;

    final textColor = isSelected
        ? (theme.brightness == Brightness.light
            ? Colors.white
            : Colors.grey[900])
        : inMonth
            ? theme.primaryTextTheme.bodySmall?.color
            : theme.primaryTextTheme.displayMedium?.color
                ?.withValues(alpha: 0.4);

    return Semantics(
      button: true,
      selected: isSelected,
      label: DateFormat('EEEE, d. MMMM').format(day) +
          (hasEvents ? ', hat Kalenderevents' : ''),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onDaySelected(day),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isSelected ? theme.primaryColor : tint,
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
                      fontWeight:
                          isToday || isSelected ? FontWeight.bold : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final color in resolved.take(_maxDots))
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: inMonth ? 1 : 0.4),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
