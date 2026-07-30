import 'package:blvckleg_dart_core/models/user/user_model.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// The "who is behind this" line at the bottom of a note or task list card.
///
/// Creator and last editor are two separate facts: on public content anybody
/// in the group may edit, so who touched it last is worth knowing. It is only
/// spelled out when somebody other than the creator saved it - otherwise the
/// name carries nothing the creator entry does not already say.
class ContentMetaFooter extends StatelessWidget {
  /// Who created the note or list.
  final User? author;

  /// Who saved it last. Null on content from before the backend started
  /// recording it.
  final User? lastModifiedUser;

  /// Text and icon color, so the footer works on a card as well as on the
  /// darker header strip of a task list.
  final Color? color;

  const ContentMetaFooter({
    super.key,
    this.author,
    this.lastModifiedUser,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.primaryTextTheme.displayMedium?.copyWith(
      color: color ?? _mutedColor(theme),
    );
    final iconColor = color ?? _mutedColor(theme);

    final editor = lastModifiedUser;
    // by id, not by name: renaming an account must not make somebody else's
    // edit look like the creator's own
    final editedBySomebodyElse = editor != null && editor.id != author?.id;

    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        _MetaItem(
          icon: PhosphorIconsRegular.user,
          // spells out what the icon means - two bare icons next to each
          // other left the reader guessing which name was which
          tooltip: 'Erstellt von',
          label: author?.username ?? 'unbekannt',
          style: style,
          iconColor: iconColor,
        ),
        if (editedBySomebodyElse)
          _MetaItem(
            icon: PhosphorIconsRegular.pencil,
            tooltip: 'Zuletzt bearbeitet von',
            label: editor.username,
            style: style,
            iconColor: iconColor,
          ),
      ],
    );
  }

  Color? _mutedColor(ThemeData theme) =>
      theme.primaryTextTheme.displayMedium?.color?.withValues(alpha: 0.7);
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;

  /// What the icon stands for, e.g. "Erstellt von". Doubles as the screen
  /// reader label so the row is not just two names in a row.
  final String tooltip;
  final TextStyle? style;
  final Color? iconColor;

  const _MetaItem({
    required this.icon,
    required this.label,
    required this.tooltip,
    this.style,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$tooltip $label',
      child: Semantics(
        label: '$tooltip $label',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(icon, size: 13, color: iconColor),
            const SizedBox(width: 5),
            Text(label, style: style),
          ],
        ),
      ),
    );
  }
}
