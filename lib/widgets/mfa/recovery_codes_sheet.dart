import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/util/haptics.dart';

Future<void> showRecoveryCodesSheet(
  BuildContext context,
  List<String> codes,
) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Theme.of(context).cardColor,
    builder: (sheetContext) => _RecoveryCodesSheet(codes: codes),
  );
}

class _RecoveryCodesSheet extends StatelessWidget {
  const _RecoveryCodesSheet({required this.codes});

  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.mfaYourRecoveryCodes,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.mfaRecoveryCodesHint,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _buildCodeGrid(theme),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const PhosphorIcon(PhosphorIconsRegular.copy),
                    label: Text(context.l10n.copy),
                    onPressed: () => _copy(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const PhosphorIcon(PhosphorIconsRegular.shareNetwork),
                    label: Text(context.l10n.share),
                    onPressed: () => _share(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.mfaCodesSecured),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeGrid(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        codes.join('\n'),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: codes.join('\n')));
    Haptics.tap();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.mfaCodesCopied)),
    );
  }

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: codes.join('\n'),
        subject: context.l10n.mfaRecoveryCodesSubject,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
    Haptics.tap();
  }
}
