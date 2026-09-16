// ignore_for_file: use_build_context_synchronously

import 'package:blvckleg_dart_core/models/auth/mfa_challenge_model.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/backend/service/mfa_service.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/helpers.dart';

class MfaChallengeScreen extends StatefulWidget {
  const MfaChallengeScreen({super.key, this.challenge});

  static const routeName = '/mfa-challenge';

  final MfaChallenge? challenge;

  @override
  State<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends State<MfaChallengeScreen> {
  final MfaService _mfaService = MfaService();
  final TextEditingController _recoveryCodeCtrl = TextEditingController();

  bool _busy = false;
  bool _showRecoveryCodeInput = false;

  @override
  void initState() {
    super.initState();
    if (widget.challenge?.supportsWebAuthn ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verifyWithPasskey());
    }
  }

  @override
  void dispose() {
    _recoveryCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyWithPasskey() async {
    final challenge = widget.challenge;
    if (challenge == null || _busy) return;

    setState(() => _busy = true);
    try {
      await _mfaService.completeLogin(challenge);
      Haptics.tap();
      await navigateAfterAuth(context);
    } on MfaCancelledException {
      Haptics.warning();
    } catch (e) {
      Haptics.warning();
      await showBackendError(context, e, context.l10n.mfaLoginFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyWithRecoveryCode() async {
    final challenge = widget.challenge;
    final code = _recoveryCodeCtrl.text.trim();
    if (challenge == null || code.isEmpty || _busy) return;

    setState(() => _busy = true);
    try {
      await AuthBackend().completeMfaWithRecoveryCode(challenge, code);
      Haptics.tap();
      await navigateAfterAuth(context);
    } catch (e) {
      Haptics.warning();
      await showBackendError(context, e, context.l10n.mfaCodeRejected);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _backToLogin() {
    navigateToRoute(context, 'login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.mfaConfirmation,
            style: theme.primaryTextTheme.titleMedium),
        backgroundColor: theme.scaffoldBackgroundColor,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: widget.challenge == null
                  ? _buildMissingChallenge(theme)
                  : _buildChallenge(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissingChallenge(ThemeData theme) {
    return Column(
      children: [
        Text(
          context.l10n.mfaChallengeExpired,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _backToLogin,
          child: Text(context.l10n.backToLogin),
        ),
      ],
    );
  }

  Widget _buildChallenge(ThemeData theme) {
    final challenge = widget.challenge!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PhosphorIcon(
          PhosphorIconsRegular.shieldCheck,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.mfaOneMoreStep,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.mfaConfirmWithDevice,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (challenge.supportsWebAuthn) _buildPasskeyButton(),
        if (challenge.supportsRecoveryCode) _buildRecoveryCodeSection(theme),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : _backToLogin,
          child: Text(context.l10n.cancel),
        ),
      ],
    );
  }

  Widget _buildPasskeyButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        icon: const PhosphorIcon(PhosphorIconsRegular.fingerprint),
        label: Text(_busy
            ? context.l10n.mfaWaitingForDevice
            : context.l10n.mfaConfirmWithDeviceButton),
        onPressed: _busy ? null : _verifyWithPasskey,
      ),
    );
  }

  Widget _buildRecoveryCodeSection(ThemeData theme) {
    if (!_showRecoveryCodeInput) {
      return TextButton(
        onPressed: _busy
            ? null
            : () => setState(() => _showRecoveryCodeInput = true),
        child: Text(context.l10n.mfaUseRecoveryCode),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        TextField(
          controller: _recoveryCodeCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: theme.primaryTextTheme.bodySmall,
          decoration: InputDecoration(
            labelText: context.l10n.mfaRecoveryCode,
            hintText: 'ABCD-EF12',
            labelStyle: theme.primaryTextTheme.bodySmall,
          ),
          onSubmitted: (_) => _verifyWithRecoveryCode(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _verifyWithRecoveryCode,
            child: Text(context.l10n.mfaConfirmCode),
          ),
        ),
      ],
    );
  }
}
