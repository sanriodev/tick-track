import 'package:ticktrack/models/group/group_api_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class GroupCreatedSuccess extends StatelessWidget {
  const GroupCreatedSuccess({
    super.key,
    required this.group,
    required this.onContinue,
  });

  final Group group;
  final VoidCallback onContinue;

  Future<void> _copyJoinCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: group.joinCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Einladungscode kopiert.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: 96,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'Gruppe "${group.name}" erstellt!',
          style: theme.primaryTextTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Mit diesem Einladungscode können andere deiner Gruppe beitreten:',
          style: theme.primaryTextTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _buildJoinCodeBox(context, theme),
        const SizedBox(height: 48),
        ElevatedButton.icon(
          onPressed: onContinue,
          icon: Icon(Icons.arrow_forward, color: theme.primaryIconTheme.color),
          label: Text(
            'Los geht\'s',
            style: theme.primaryTextTheme.displayLarge?.copyWith(
              color: theme.brightness == Brightness.light
                  ? Colors.white
                  : Colors.grey[900],
            ),
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }

  Widget _buildJoinCodeBox(BuildContext context, ThemeData theme) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: theme.canvasColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              group.joinCode,
              style: theme.primaryTextTheme.titleMedium?.copyWith(
                letterSpacing: 4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Code kopieren',
              icon: PhosphorIcon(
                PhosphorIconsRegular.copy,
                color: theme.primaryIconTheme.color,
              ),
              onPressed: () => _copyJoinCode(context),
            ),
          ],
        ),
      ),
    );
  }
}
