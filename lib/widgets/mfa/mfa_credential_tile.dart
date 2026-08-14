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
      title: Text(_title, style: theme.textTheme.titleSmall),
      subtitle: Text(_subtitle, style: theme.textTheme.bodySmall),
      trailing: IconButton(
        icon: PhosphorIcon(
          PhosphorIconsRegular.trash,
          color: theme.colorScheme.error,
          size: 20,
        ),
        tooltip: 'Entfernen',
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

  String get _title {
    final nickname = credential.nickname;
    if (nickname != null && nickname.isNotEmpty) {
      return nickname;
    }
    return credential.isPlatformAuthenticator
        ? 'Dieses Gerät'
        : 'Sicherheitsschlüssel';
  }

  String get _subtitle {
    final parts = <String>[
      if (credential.deviceType == WebAuthnDeviceType.multiDevice)
        'synchronisiert',
      if (credential.createdAt != null)
        'registriert am ${_formatDate(credential.createdAt!)}',
      if (credential.lastUsedAt != null)
        'zuletzt genutzt am ${_formatDate(credential.lastUsedAt!)}',
    ];
    return parts.isEmpty ? 'Zweiter Faktor' : parts.join(' · ');
  }

  String _formatDate(DateTime value) =>
      DateFormat('dd.MM.yyyy').format(value.toLocal());
}
