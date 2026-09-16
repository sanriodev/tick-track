// ignore_for_file: use_build_context_synchronously

import 'package:blvckleg_dart_core/models/mfa/webauthn_credential_model.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:ticktrack/l10n/l10n.dart';
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
        context.l10n.mfaLoadFailed,
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
      _showMessage(context.l10n.mfaDeviceRegistered);
      await _load();
      if (wasFirstFactor) await _offerRecoveryCodes();
    } on MfaCancelledException {
      Haptics.warning();
    } catch (e) {
      Haptics.warning();
      await showBackendError(context, e, context.l10n.mfaRegistrationFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteCredential(WebAuthnCredential credential) async {
    final confirmed = await _confirm(
      title: context.l10n.mfaRemoveDevice,
      message: context.l10n.mfaRemoveDeviceMessage,
      confirmLabel: context.l10n.remove,
      destructive: true,
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      await AuthBackend().deleteMfaCredential(credential.credentialId);
      Haptics.tap();
      _showMessage(context.l10n.mfaDeviceRemoved);
      await _load();
    } catch (e) {
      Haptics.warning();
      await showBackendError(context, e, context.l10n.mfaDeviceRemoveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _regenerateRecoveryCodes() async {
    final confirmed = await _confirm(
      title: context.l10n.mfaNewRecoveryCodes,
      message: context.l10n.mfaNewRecoveryCodesMessage,
      confirmLabel: context.l10n.generate,
    );
    if (!confirmed) return;

    await _createAndShowRecoveryCodes();
  }

  Future<void> _offerRecoveryCodes() async {
    final wanted = await _confirm(
      title: context.l10n.mfaRecoveryCodes,
      message: context.l10n.mfaRecoveryCodesOffer,
      confirmLabel: context.l10n.generate,
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
      await showBackendError(context, e, context.l10n.mfaCodesFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enableMfa() async {
    setState(() => _busy = true);
    try {
      await AuthBackend().enableMfa();
      Haptics.tap();
      _showMessage(context.l10n.mfaEnabledMessage);
      await _load();
    } catch (e) {
      Haptics.warning();
      await showBackendError(
        context,
        e,
        context.l10n.mfaEnableFailed,
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
      _showMessage(context.l10n.mfaDisabledMessage);
      await _load();
    } catch (e) {
      Haptics.warning();
      await showBackendError(
        context,
        e,
        context.l10n.mfaDisableFailed,
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
        title:
            Text(context.l10n.mfaNameDevice, style: theme.textTheme.titleMedium),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          style: theme.primaryTextTheme.bodySmall,
          decoration: InputDecoration(
            labelText: context.l10n.nameOptional,
            hintText: context.l10n.mfaDeviceNameHint,
            labelStyle: theme.primaryTextTheme.bodySmall,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(context.l10n.next),
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
        title: Text(context.l10n.mfaConfirmPassword,
            style: theme.textTheme.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.mfaPasswordNeeded,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              style: theme.primaryTextTheme.bodySmall,
              decoration: InputDecoration(
                labelText: context.l10n.password,
                labelStyle: theme.primaryTextTheme.bodySmall,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isEmpty) return;
              Navigator.of(dialogContext).pop(controller.text);
            },
            child: Text(context.l10n.disable),
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
            child: Text(context.l10n.cancel),
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
          context.l10n.mfaShort,
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
          context.l10n.mfaReEnable,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          context.l10n.mfaReEnableSubtitle,
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
          active ? context.l10n.mfaActive : context.l10n.mfaInactive,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          active
              ? context.l10n.mfaActiveSubtitle
              : context.l10n.mfaInactiveSubtitle,
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
            _cardTitle(theme, context.l10n.mfaSetup),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                context.l10n.mfaSetupHint,
                style: theme.textTheme.bodySmall,
              ),
            ),
            ListTile(
              leading: PhosphorIcon(
                PhosphorIconsRegular.fingerprint,
                color: theme.primaryIconTheme.color,
              ),
              title: Text(
                context.l10n.mfaEnable,
                style: theme.textTheme.titleSmall,
              ),
              subtitle: _passkeySupported
                  ? null
                  : Text(
                      context.l10n.mfaErrorDeviceUnsupported,
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
            _cardTitle(theme, context.l10n.mfaRegisteredDevices),
            if (_credentials.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  context.l10n.mfaNoDevice,
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
                context.l10n.mfaRegisterAnother,
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
            _cardTitle(theme, context.l10n.mfaRecovery),
            ListTile(
              leading: PhosphorIcon(
                PhosphorIconsRegular.key,
                color: theme.primaryIconTheme.color,
              ),
              title: Text(
                context.l10n.mfaGenerateCodes,
                style: theme.textTheme.titleSmall,
              ),
              subtitle: Text(
                context.l10n.mfaGenerateCodesSubtitle,
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
          context.l10n.mfaDisable,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          context.l10n.mfaDisableSubtitle,
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
