import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:flutter/material.dart';

/// The privacy control shown in the corner of a note or task list card.
///
/// Shared by both card types so the wording of the modes stays in one place.
/// Disabled for content the user does not own - the backend rejects those
/// changes anyway, so the icon then only reports the current mode.
class PrivacyModeButton extends StatelessWidget {
  final PrivacyMode mode;

  /// Whether the user may change the mode, i.e. owns the content.
  final bool enabled;

  /// Icon color, so the button can sit on a card as well as on the darker
  /// header strip of a task list.
  final Color? color;

  final void Function(PrivacyMode mode)? onChanged;

  const PrivacyModeButton({
    super.key,
    required this.mode,
    required this.enabled,
    this.color,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<PrivacyMode>(
      enabled: enabled,
      tooltip: enabled ? 'Privatsphäre ändern' : mode.label,
      icon: Icon(privacyIconFor(mode), size: 20),
      color: theme.cardColor,
      iconColor: color ?? theme.primaryIconTheme.color,
      position: PopupMenuPosition.under,
      onSelected: (selected) {
        Haptics.tick();
        onChanged?.call(selected);
      },
      itemBuilder: (context) => [
        for (final entry in PrivacyMode.values)
          PopupMenuItem(
            value: entry,
            child: Row(
              children: [
                Icon(
                  privacyIconFor(entry),
                  size: 20,
                  color: theme.primaryIconTheme.color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.label,
                          style: theme.primaryTextTheme.bodySmall),
                      Text(
                        entry.description,
                        style: theme.primaryTextTheme.displayMedium,
                      ),
                    ],
                  ),
                ),
                // marks the mode the content currently uses
                if (entry == mode)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.check,
                      size: 18,
                      color: theme.primaryIconTheme.color,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
