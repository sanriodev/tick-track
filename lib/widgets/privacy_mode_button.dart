import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:flutter/material.dart';

class PrivacyModeButton extends StatelessWidget {
  final PrivacyMode mode;

  final bool enabled;

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
