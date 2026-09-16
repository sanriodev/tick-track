import 'package:ticktrack/l10n/l10n.dart';
import 'package:blvckleg_dart_core/models/mfa/webauthn_credential_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class MfaCredentialTile extends StatelessWidget {
  const MfaCredentialTile({
    super.key,
    required this.credential,
    this.onDelete,
  });

  final WebAuthnCredential credential;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: PhosphorIcon(_icon, color: theme.primaryIconTheme.color),
      title: Text(_title(context.l10n), style: theme.textTheme.titleSmall),
      subtitle:
          Text(_subtitle(context.l10n), style: theme.textTheme.bodySmall),
      trailing: IconButton(
        icon: PhosphorIcon(
          PhosphorIconsRegular.trash,
          color: theme.colorScheme.error,
          size: 20,
        ),
        tooltip: context.l10n.remove,
        onPressed: onDelete,
      ),
    );
  }

  IconData get _icon {
    if (credential.isPlatformAuthenticator) {
      return PhosphorIconsRegular.fingerprint;
    }
    return PhosphorIconsRegular.usb;
  }

  String _title(AppLocalizations l10n) {
    final nickname = credential.nickname;
    if (nickname != null && nickname.isNotEmpty) {
      return nickname;
    }
    return credential.isPlatformAuthenticator
        ? l10n.mfaThisDevice
        : l10n.mfaSecurityKey;
  }

  String _subtitle(AppLocalizations l10n) {
    final parts = <String>[
      if (credential.deviceType == WebAuthnDeviceType.multiDevice) l10n.mfaSynced,
      if (credential.createdAt != null)
        l10n.mfaRegisteredOn(_formatDate(credential.createdAt!)),
      if (credential.lastUsedAt != null)
        l10n.mfaLastUsedOn(_formatDate(credential.lastUsedAt!)),
    ];
    return parts.isEmpty ? l10n.mfaRegisteredFactor : parts.join(' · ');
  }

  String _formatDate(DateTime value) =>
      DateFormat.yMd().format(value.toLocal());
}
