import 'package:ticktrack/l10n/l10n.dart';
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
        title: Text(context.l10n.reportTitle(entityLabel),
            style: theme.textTheme.titleMedium),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.reportHint,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  maxLength: 500,
                  minLines: 1,
                  maxLines: 3,
                  style: theme.primaryTextTheme.bodySmall,
                  decoration: InputDecoration(
                    labelText: context.l10n.reportReason,
                    labelStyle: theme.primaryTextTheme.bodySmall,
                    hintText: context.l10n.reportReasonHint,
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
                            ? context.l10n.blockNamedUser(authorName)
                            : context.l10n.blockUser,
                        style: theme.textTheme.bodyMedium,
                      ),
                      subtitle: Text(
                        context.l10n.blockUserSubtitle,
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
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              context.l10n.report,
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
                ? context.l10n.reportSentAndBlocked
                : context.l10n.reportSent,
          ),
        ),
      );
    }
    if (canBlock && alsoBlock) onBlocked?.call();
  } catch (e) {
    if (context.mounted) {
      await showBackendError(context, e, context.l10n.reportFailed);
    }
  }
}
