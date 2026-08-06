import 'package:ticktrack/widgets/user_avatar_widget.dart';
import 'package:blvckleg_dart_core/models/user/user_model.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ContentMetaFooter extends StatelessWidget {
  final User? author;

  final User? lastModifiedUser;

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
    final editedBySomebodyElse = editor != null && editor.id != author?.id;

    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        _MetaItem(
          avatar: UserAvatarWidget(
            userId: author?.id,
            username: author?.username,
            radius: 9,
          ),
          icon: PhosphorIconsRegular.user,
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

  final Widget? avatar;

  final String tooltip;
  final TextStyle? style;
  final Color? iconColor;

  const _MetaItem({
    required this.icon,
    required this.label,
    required this.tooltip,
    this.avatar,
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
            avatar ?? PhosphorIcon(icon, size: 13, color: iconColor),
            const SizedBox(width: 5),
            Text(label, style: style),
          ],
        ),
      ),
    );
  }
}
