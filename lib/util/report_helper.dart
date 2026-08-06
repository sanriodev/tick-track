import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:flutter/material.dart';

Future<void> showReportContentDialog(
  BuildContext context, {
  required String entityType,
  required int entityId,
  required String entityLabel,
  int? authorId,
  String? authorName,
  VoidCallback? onBlocked,
}) async {
  final theme = Theme.of(context);
  String reason = '';
  bool alsoBlock = false;
  final canBlock = authorId != null;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text('$entityLabel melden?', style: theme.textTheme.titleMedium),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Melde diesen Inhalt, wenn er anstößig ist oder gegen die '
                  'Nutzungsbedingungen verstößt. Der Entwickler wird '
                  'benachrichtigt und prüft die Meldung.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  maxLength: 500,
                  minLines: 1,
                  maxLines: 3,
                  style: theme.primaryTextTheme.bodySmall,
                  decoration: InputDecoration(
                    labelText: 'Grund (optional)',
                    labelStyle: theme.primaryTextTheme.bodySmall,
                    hintText: 'z.B. beleidigender Inhalt',
                    hintStyle: theme.primaryTextTheme.bodySmall,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      reason = value;
                    });
                  },
                ),
                if (canBlock)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: CheckboxListTile(
                      value: alsoBlock,
                      onChanged: (value) {
                        setDialogState(() {
                          alsoBlock = value ?? false;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      title: Text(
                        authorName != null
                            ? '"$authorName" blockieren'
                            : 'Nutzer blockieren',
                        style: theme.textTheme.bodyMedium,
                      ),
                      subtitle: Text(
                        'Alle Inhalte dieses Nutzers werden für dich '
                        'ausgeblendet.',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Melden',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      );
    },
  );
  if (confirmed != true) return;

  try {
    await Backend().reportContent(entityType, entityId, reason: reason);
    if (canBlock && alsoBlock) {
      await Backend().blockUser(authorId);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            canBlock && alsoBlock
                ? 'Meldung übermittelt und Nutzer blockiert.'
                : 'Danke, deine Meldung wurde übermittelt.',
          ),
        ),
      );
    }
    if (canBlock && alsoBlock) onBlocked?.call();
  } catch (e) {
    if (context.mounted) {
      await showBackendError(context, e, 'Meldung fehlgeschlagen');
    }
  }
}
