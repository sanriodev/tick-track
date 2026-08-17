// ignore_for_file: use_build_context_synchronously

import 'package:blvckleg_dart_core/models/mfa/webauthn_credential_model.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:ticktrack/backend/service/mfa_service.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/widgets/mfa/mfa_credential_tile.dart';
import 'package:ticktrack/widgets/mfa/recovery_codes_sheet.dart';
import 'package:ticktrack/widgets/skeleton/skeleton_card.dart';

class MfaScreen extends StatefulWidget {
  const MfaScreen({super.key});

  static const routeName = '/mfa';

  @override
  State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  final MfaService _mfaService = MfaService();

  bool _isLoading = true;
  bool _busy = false;
  bool _mfaEnabled = false;
  bool _passkeySupported = false;
  List<WebAuthnCredential> _credentials = const <WebAuthnCredential>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final supported = await _mfaService.isPasskeySupported();
      final user = await AuthBackend().getOwnUser();
      final credentials = await AuthBackend().listMfaCredentials();
      if (!mounted) return;
      setState(() {
        _passkeySupported = supported;
        _mfaEnabled = user.mfaEnabled ?? false;
        _credentials = credentials;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      await showBackendError(
        context,
        e,
        'Zwei-Faktor-Einstellungen konnten nicht geladen werden',
      );
    }
  }

  Future<void> _registerCredential() async {
    final nickname = await _askForNickname();
    if (nickname == null) return;

    final bool wasFirstFactor = _credentials.isEmpty;
    setState(() => _busy = true);
    try {
      await _mfaService.registerCredential(nickname: nickname);
      Haptics.tap();
      _showMessage('Gerät registriert. Zwei-Faktor ist jetzt aktiv.');
      await _load();
      if (wasFirstFactor) await _offerRecoveryCodes();
    } on MfaCancelledException {
      Haptics.warning();
    } catch (e) {
      Haptics.warning();
      await showBackendError(context, e, 'Registrierung fehlgeschlagen');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteCredential(WebAuthnCredential credential) async {
    final confirmed = await _confirm(
      title: 'Gerät entfernen',
      message: 'Dieses Gerät kann sich dann nicht mehr als zweiter Faktor '
          'anmelden. Ist es dein letzter Faktor, wird MFA '
          'automatisch deaktiviert.',
      confirmLabel: 'Entfernen',
      destructive: true,
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      await AuthBackend().deleteMfaCredential(credential.credentialId);
      Haptics.tap();
      _showMessage('Gerät entfernt.');
      await _load();
    } catch (e) {
      Haptics.warning();
      await showBackendError(context, e, 'Gerät konnte nicht entfernt werden');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _regenerateRecoveryCodes() async {
    final confirmed = await _confirm(
      title: 'Neue Wiederherstellungscodes',
      message: 'Deine bisherigen Codes werden dabei ungültig.',
      confirmLabel: 'Erzeugen',
    );
    if (!confirmed) return;

    await _createAndShowRecoveryCodes();
  }

  Future<void> _offerRecoveryCodes() async {
    final wanted = await _confirm(
      title: 'Wiederherstellungscodes',
      message: 'Damit kommst du auch ohne dein Gerät wieder in deinen Account. '
          'Jetzt erzeugen?',
      confirmLabel: 'Erzeugen',
    );
    if (!wanted) return;

    await _createAndShowRecoveryCodes();
  }

  Future<void> _createAndShowRecoveryCodes() async {
    setState(() => _busy = true);
    try {
      final codes = await AuthBackend().generateRecoveryCodes();
      Haptics.tap();
      await _load();
      if (mounted) await showRecoveryCodesSheet(context, codes);
    } catch (e) {
      Haptics.warning();
      await showBackendError(context, e, 'Codes konnten nicht erzeugt werden');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enableMfa() async {
    setState(() => _busy = true);
    try {
      await AuthBackend().enableMfa();
      Haptics.tap();
      _showMessage('Zwei-Faktor ist wieder aktiv.');
      await _load();
    } catch (e) {
      Haptics.warning();
      await showBackendError(
        context,
        e,
        'Zwei-Faktor konnte nicht aktiviert werden',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disableMfa() async {
    final password = await _askForPassword();
    if (password == null) return;

    setState(() => _busy = true);
    try {
      await AuthBackend().disableMfa(password: password);
      Haptics.tap();
      _showMessage('Zwei-Faktor ist deaktiviert.');
      await _load();
    } catch (e) {
      Haptics.warning();
      await showBackendError(
        context,
        e,
        'Zwei-Faktor konnte nicht deaktiviert werden',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askForNickname() {
    final controller = TextEditingController();
    final theme = Theme.of(context);

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Gerät benennen', style: theme.textTheme.titleMedium),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          style: theme.primaryTextTheme.bodySmall,
          decoration: InputDecoration(
            labelText: 'Name (optional)',
            hintText: 'z.B. iPhone von mir',
            labelStyle: theme.primaryTextTheme.bodySmall,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Weiter'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askForPassword() {
    final controller = TextEditingController();
    final theme = Theme.of(context);

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Passwort bestätigen', style: theme.textTheme.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Zum Deaktivieren brauchen wir dein Passwort.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              style: theme.primaryTextTheme.bodySmall,
              decoration: InputDecoration(
                labelText: 'Passwort',
                labelStyle: theme.primaryTextTheme.bodySmall,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isEmpty) return;
              Navigator.of(dialogContext).pop(controller.text);
            },
            child: const Text('Deaktivieren'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final theme = Theme.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, style: theme.textTheme.titleMedium),
        content: Text(message, style: theme.textTheme.bodySmall),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              confirmLabel,
              style: destructive
                  ? TextStyle(color: theme.colorScheme.error)
                  : null,
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Zwei-Faktor',
          style: theme.primaryTextTheme.titleMedium,
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Skeletonizer(
          enabled: _isLoading,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: _isLoading
                  ? const [SkeletonCard(), SkeletonCard()]
                  : _buildContent(theme),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContent(ThemeData theme) {
    if (_hasNoFactors) {
      return [
        _buildStatusCard(theme),
        const SizedBox(height: 16),
        _buildSetupCard(theme),
      ];
    }

    return [
      _buildStatusCard(theme),
      const SizedBox(height: 16),
      if (!_mfaEnabled) ...[
        _buildEnableCard(theme),
        const SizedBox(height: 16),
      ],
      _buildCredentialsCard(theme),
      const SizedBox(height: 16),
      _buildRecoveryCard(theme),
      if (_mfaEnabled) ...[
        const SizedBox(height: 16),
        _buildDisableCard(theme),
      ],
    ];
  }

  bool get _hasNoFactors => !_mfaEnabled && _credentials.isEmpty;

  Widget _buildEnableCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: PhosphorIcon(
          PhosphorIconsRegular.shieldCheck,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          'Zwei-Faktor wieder aktivieren',
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          'Deine registrierten Geräte sind noch hinterlegt.',
          style: theme.textTheme.bodySmall,
        ),
        onTap: _busy ? null : _enableMfa,
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    final active = _mfaEnabled;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: PhosphorIcon(
          active
              ? PhosphorIconsRegular.shieldCheck
              : PhosphorIconsRegular.shieldWarning,
          color: active ? theme.colorScheme.primary : theme.disabledColor,
          size: 28,
        ),
        title: Text(
          active ? 'Zwei-Faktor ist aktiv' : 'Zwei-Faktor ist inaktiv',
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          active
              ? 'Beim Anmelden fragen wir nach deinem Gerät oder einem '
                  'Wiederherstellungscode.'
              : 'Nur dein Passwort schützt deinen Account.',
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _buildSetupCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(theme, 'Einrichten'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Registriere dieses Gerät mit Face ID, Fingerabdruck oder '
                'einem Sicherheitsschlüssel. Danach kannst du dir '
                'Wiederherstellungscodes erzeugen.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            ListTile(
              leading: PhosphorIcon(
                PhosphorIconsRegular.fingerprint,
                color: theme.primaryIconTheme.color,
              ),
              title: Text(
                'Zwei-Faktor aktivieren',
                style: theme.textTheme.titleSmall,
              ),
              subtitle: _passkeySupported
                  ? null
                  : Text(
                      'Dieses Gerät unterstützt keine Passkeys.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
              onTap: _canRegister ? _registerCredential : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialsCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(theme, 'Registrierte Geräte'),
            if (_credentials.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Kein Gerät registriert. Zwei-Faktor läuft nur über '
                  'Wiederherstellungscodes.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ..._credentials.map(
              (credential) => MfaCredentialTile(
                credential: credential,
                onDelete: _busy ? null : () => _deleteCredential(credential),
              ),
            ),
            ListTile(
              leading: PhosphorIcon(
                PhosphorIconsRegular.plus,
                color: theme.primaryIconTheme.color,
              ),
              title: Text(
                'Weiteres Gerät registrieren',
                style: theme.textTheme.titleSmall,
              ),
              onTap: _canRegister ? _registerCredential : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(theme, 'Wiederherstellung'),
            ListTile(
              leading: PhosphorIcon(
                PhosphorIconsRegular.key,
                color: theme.primaryIconTheme.color,
              ),
              title: Text(
                'Neue Codes erzeugen',
                style: theme.textTheme.titleSmall,
              ),
              subtitle: Text(
                'Einmal-Codes für den Fall, dass du kein Gerät zur Hand hast.',
                style: theme.textTheme.bodySmall,
              ),
              onTap: _busy ? null : _regenerateRecoveryCodes,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisableCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        leading: PhosphorIcon(
          PhosphorIconsRegular.shieldSlash,
          color: theme.colorScheme.error,
        ),
        title: Text(
          'Zwei-Faktor deaktivieren',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Danach schützt nur noch dein Passwort deinen Account.',
          style: theme.textTheme.bodySmall,
        ),
        onTap: _busy ? null : _disableMfa,
      ),
    );
  }

  bool get _canRegister => !_busy && _passkeySupported;

  Widget _cardTitle(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        label,
        style:
            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
