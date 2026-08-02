import 'package:ticktrack/enum/event_color_enum.dart';
import 'package:ticktrack/models/calendar/calendar_event_model.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/report_helper.dart';
import 'package:ticktrack/widgets/content_meta_footer.dart';
import 'package:ticktrack/widgets/slidable_underlay.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// One date of an event in the day list.
///
/// Shows the time of *this* date, not the stored one - for a repetition those
/// differ, and the date on screen is the one that matters.
class CalendarOccurrenceTile extends StatefulWidget {
  final CalendarOccurrence occurrence;
  final void Function()? onTap;
  final void Function()? onDelete;

  /// Called after the author was blocked from the report dialog, so the calendar
  /// can reload and drop the now hidden event.
  final void Function()? onBlocked;

  const CalendarOccurrenceTile({
    super.key,
    required this.occurrence,
    this.onTap,
    this.onDelete,
    this.onBlocked,
  });

  @override
  State<CalendarOccurrenceTile> createState() => _CalendarOccurrenceTileState();
}

class _CalendarOccurrenceTileState extends State<CalendarOccurrenceTile>
    with SingleTickerProviderStateMixin {
  late final SlidableController _slidableController;

  @override
  void initState() {
    super.initState();
    _slidableController = SlidableController(this);
  }

  @override
  void dispose() {
    _slidableController.dispose();
    super.dispose();
  }

  CalendarEvent get _event => widget.occurrence.event;

  bool get _isOwnEvent =>
      _event.user?.username == AuthBackend().loggedInUser?.user?.username;

  /// "18:00 - 20:00", "Ganztägig", or a range with dates when it spans days.
  String get _timeLabel {
    if (_event.allDay) {
      if (!widget.occurrence.spansDays) {
        return 'Ganztägig';
      }
      final from = DateFormat('d.M.').format(widget.occurrence.startAt);
      final to = DateFormat('d.M.').format(widget.occurrence.endAt);
      return 'Ganztägig, $from - $to';
    }

    final time = DateFormat('HH:mm');
    final start = time.format(widget.occurrence.startAt);
    // "18:00 - 18:00" is noise for an event without a duration
    if (widget.occurrence.endAt == widget.occurrence.startAt) {
      return start;
    }
    if (!widget.occurrence.spansDays) {
      return '$start - ${time.format(widget.occurrence.endAt)}';
    }
    final endStamp = DateFormat('d.M. HH:mm').format(widget.occurrence.endAt);
    return '$start - $endStamp';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = _event.description?.trim() ?? '';
    final location = _event.location?.trim() ?? '';
    final accent = eventColorOf(context, _event.color);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          SlidableUnderlay(
            controller: _slidableController,
            startColor: theme.canvasColor,
            endColor: Colors.red,
          ),
          Slidable(
            key: ValueKey('${_event.id}-${widget.occurrence.startAt}'),
            controller: _slidableController,
            endActionPane: ActionPane(
              motion: BehindMotion(),
              extentRatio: 0.3,
              children: [
                if (_isOwnEvent)
                  SlidableAction(
                    borderRadius: slidableEndOuterRadius,
                    onPressed: (_) {
                      Haptics.warning();
                      widget.onDelete?.call();
                    },
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    icon: Icons.delete,
                  )
                else
                  SlidableAction(
                    borderRadius: slidableEndOuterRadius,
                    onPressed: (_) => showReportContentDialog(
                      context,
                      entityType: 'calendar_event',
                      entityId: _event.id,
                      entityLabel: 'Kalenderevent',
                      authorId: _event.user?.id,
                      authorName: _event.user?.username,
                      onBlocked: widget.onBlocked,
                    ),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    icon: Icons.flag,
                    label: 'Melden',
                  ),
              ],
            ),
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // spine, so a dense day is scannable by block
                      Container(
                        width: 4,
                        height: 42,
                        margin: const EdgeInsets.only(right: 12, top: 2),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    _event.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.primaryTextTheme.labelLarge
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (_event.recurrence.repeats)
                                  Tooltip(
                                    message: _event.recurrence.label,
                                    child: PhosphorIcon(
                                      PhosphorIconsRegular.repeat,
                                      size: 15,
                                      color: theme.primaryIconTheme.color
                                          ?.withValues(alpha: 0.8),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _timeLabel,
                              style: theme.primaryTextTheme.titleSmall
                                  ?.copyWith(color: accent),
                            ),
                            if (location.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    PhosphorIcon(
                                      PhosphorIconsRegular.mapPin,
                                      size: 13,
                                      color: theme
                                          .primaryTextTheme.displayMedium?.color
                                          ?.withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme
                                            .primaryTextTheme.displayMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.primaryTextTheme.titleSmall
                                      ?.copyWith(
                                    color: theme
                                        .primaryTextTheme.titleSmall?.color
                                        ?.withValues(alpha: 0.75),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: ContentMetaFooter(
                                author: _event.user,
                                lastModifiedUser: _event.lastModifiedUser,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
