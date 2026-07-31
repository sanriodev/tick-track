import 'package:ticktrack/models/calendar/calendar_event_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The next few dates on the home screen.
///
/// Shows what is coming up rather than a count - a number of appointments tells
/// nobody anything, "heute 18:00 Müll" does.
class CalendarPreviewWidget extends StatelessWidget {
  const CalendarPreviewWidget({
    super.key,
    required this.occurrences,
    required this.isLoading,
    required this.onPressed,
  });

  /// Upcoming dates, expected to be sorted ascending.
  final List<CalendarOccurrence> occurrences;
  final bool isLoading;
  final VoidCallback onPressed;

  /// "Heute", "Morgen" or the weekday with date - a bare date makes the reader
  /// work out whether it is soon.
  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = DateTime(day.year, day.month, day.day)
        .difference(today)
        .inDays;

    return switch (difference) {
      0 => 'Heute',
      1 => 'Morgen',
      _ when difference < 7 => DateFormat('EEEE').format(day),
      _ => DateFormat('d. MMM').format(day),
    };
  }

  String _label(CalendarOccurrence occurrence) {
    final day = _dayLabel(occurrence.startAt);
    if (occurrence.event.allDay) {
      return day;
    }
    return '$day, ${DateFormat('HH:mm').format(occurrence.startAt)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.secondaryHeaderColor;

    return Card(
      elevation: 2.0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.event, color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Termine',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (occurrences.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Text(
                  'Keine Termine in den nächsten Tagen',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey),
                ),
              )
            else
              ...occurrences.take(4).map(
                    (occurrence) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 84,
                            child: Text(
                              _label(occurrence),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              occurrence.event.title,
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onPressed,
                child: Text(
                  'Mehr anzeigen',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
