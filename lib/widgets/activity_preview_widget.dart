import 'package:ticktrack/models/activity/activity_model.dart';
import 'package:ticktrack/widgets/activity/activity_history_widget.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// The activity teaser on the home screen.
///
/// Only the card around it belongs to this widget - the entries themselves come
/// from [ActivityHistoryWidget], the same list the activity screen shows. It
/// used to render its own copy, which drifted: no profile pictures, different
/// colors, and every unknown entity type ended up as "Element".
class ActivityPreviewWidget extends StatelessWidget {
  const ActivityPreviewWidget({
    super.key,
    required this.onPressed,
    required this.activities,
    required this.isLoading,
  });

  final VoidCallback onPressed;
  final List<EventlogMessage<dynamic>> activities;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.primaryColor;

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
                  child: PhosphorIcon(
                    PhosphorIconsRegular.pulse,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Aktivitäten',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ActivityHistoryWidget(
                activities: activities,
                maxItems: 5,
                wrapInCard: false,
              ),
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
