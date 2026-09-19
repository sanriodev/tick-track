// ignore_for_file: use_build_context_synchronously, avoid_dynamic_calls

import 'dart:convert';

import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/util/login_name.dart';
import 'package:ticktrack/widgets/language_toggle.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:pinput/pinput.dart';

enum _ForgotPasswordStep { request, code, newPassword, success }

const int _codeLength = 5;

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  static const routeName = '/forgot-password';

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _requestFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _loginNameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();

  final _codeFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _passwordConfirmFocus = FocusNode();

  _ForgotPasswordStep _step = _ForgotPasswordStep.request;
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;

  String _resetToken = '';

  @override
  void dispose() {
    _loginNameCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    _codeFocus.dispose();
    _passwordFocus.dispose();
    _passwordConfirmFocus.dispose();
    super.dispose();
  }

  LoginName get _loginName => LoginName.of(_loginNameCtrl.text);

  Future<void> _showResponseError(Object e, String prefix) async {
    if (e is! Response) {
      _showMessage(context.l10n.errorPrefixed(prefix, '$e'));
      return;
    }
    final jsonData = await json.decode(utf8.decode(e.bodyBytes));
    final dynamic raw = jsonData['message'];
    final message = raw is List ? raw.join(', ') : (raw as String? ?? '$e');
    _showMessage(context.l10n.errorPrefixed(prefix, message));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _goBack() {
    if (_step == _ForgotPasswordStep.code) {
      setState(() => _step = _ForgotPasswordStep.request);
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _requestCode() async {
    final form = _requestFormKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      await Backend().requestPasswordReset(
        email: _loginName.email,
        username: _loginName.username,
      );
      if (!mounted) return;
      _codeCtrl.clear();
      setState(() => _step = _ForgotPasswordStep.code);
    } catch (e) {
      await _showResponseError(e, context.l10n.forgotRequestFailed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() => _submitting = true);
    try {
      await Backend().requestPasswordReset(
        email: _loginName.email,
        username: _loginName.username,
      );
      _showMessage(context.l10n.forgotCodeResent);
    } catch (e) {
      await _showResponseError(e, context.l10n.sendFailed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _verifyCode() async {
    final form = _codeFormKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      final resetToken = await Backend().verifyPasswordResetCode(
        _codeCtrl.text.trim(),
        email: _loginName.email,
        username: _loginName.username,
      );
      if (!mounted) return;
      setState(() {
        _resetToken = resetToken;
        _step = _ForgotPasswordStep.newPassword;
      });
    } catch (e) {
      await _showResponseError(e, context.l10n.forgotCodeInvalid);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _setNewPassword() async {
    final form = _passwordFormKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      await Backend().resetPassword(_resetToken, _passwordCtrl.text);
      if (!mounted) return;
      setState(() => _step = _ForgotPasswordStep.success);
    } catch (e) {
      await _showResponseError(e, context.l10n.forgotPasswordSetFailed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'TickTrack',
          style: theme.primaryTextTheme.titleMedium,
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: LanguageToggle(compact: true)),
          ),
        ],
        leading: _step == _ForgotPasswordStep.success
            ? null
            : Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _goBack,
                  color: theme.primaryIconTheme.color,
                ),
              ),
      ),
      body: SafeArea(
        child: switch (_step) {
          _ForgotPasswordStep.request => _buildRequestStep(theme),
          _ForgotPasswordStep.code => _buildCodeStep(theme),
          _ForgotPasswordStep.newPassword => _buildNewPasswordStep(theme),
          _ForgotPasswordStep.success => _buildSuccessStep(theme),
        },
      ),
    );
  }

  Widget _buildRequestStep(ThemeData theme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _requestFormKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.forgotTitle,
                  style: _titleStyle(theme),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.forgotHint,
                  style: theme.primaryTextTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _loginNameCtrl,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.emailAddress,
                  style: theme.primaryTextTheme.bodySmall,
                  decoration: InputDecoration(
                    labelText: context.l10n.usernameOrEmail,
                    hintText: context.l10n.usernameOrEmail,
                    labelStyle: theme.primaryTextTheme.bodySmall,
                    hintStyle: theme.primaryTextTheme.bodySmall,
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? context.l10n.usernameOrEmailRequired
                      : null,
                  onFieldSubmitted: (_) => _requestCode(),
                ),
                const SizedBox(height: 24),
                _buildSubmitButton(
                  label: context.l10n.forgotSendCode,
                  icon: Icons.mail_outline,
                  onPressed: _requestCode,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeStep(ThemeData theme) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: theme.primaryTextTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ) ??
          theme.textTheme.headlineSmall,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _codeFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.forgotEnterCode,
                  style: _titleStyle(theme),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.forgotCodeSent(_codeLength),
                  style: theme.primaryTextTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Pinput(
                  length: _codeLength,
                  controller: _codeCtrl,
                  focusNode: _codeFocus,
                  autofocus: true,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyDecorationWith(
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  submittedPinTheme: defaultPinTheme.copyDecorationWith(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    border: Border.all(color: theme.colorScheme.primary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorPinTheme: defaultPinTheme.copyDecorationWith(
                    border: Border.all(color: theme.colorScheme.error),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorTextStyle: theme.primaryTextTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  validator: (v) => (v == null ||
                          v.trim().length != _codeLength)
                      ? context.l10n.codeRequired(_codeLength)
                      : null,
                  onCompleted: (_) => _verifyCode(),
                ),
                const SizedBox(height: 24),
                _buildSubmitButton(
                  label: context.l10n.confirm,
                  icon: Icons.verified_outlined,
                  onPressed: _verifyCode,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _submitting ? null : _resendCode,
                  child: Text(
                    context.l10n.resendCode,
                    style: theme.primaryTextTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewPasswordStep(ThemeData theme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _passwordFormKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.passwordNew,
                  style: _titleStyle(theme),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordCtrl,
                  focusNode: _passwordFocus,
                  textInputAction: TextInputAction.next,
                  obscureText: _obscurePassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  style: theme.primaryTextTheme.bodySmall,
                  decoration: _passwordDecoration(
                    theme,
                    labelText: context.l10n.passwordNew,
                    hintText: context.l10n.passwordMinLength,
                    obscured: _obscurePassword,
                    onToggleObscured: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) => (v == null || v.length < 8)
                      ? context.l10n.passwordMinLengthError
                      : null,
                  onFieldSubmitted: (_) => _passwordConfirmFocus.requestFocus(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordConfirmCtrl,
                  focusNode: _passwordConfirmFocus,
                  textInputAction: TextInputAction.done,
                  obscureText: _obscurePasswordConfirm,
                  enableSuggestions: false,
                  autocorrect: false,
                  style: theme.primaryTextTheme.bodySmall,
                  decoration: _passwordDecoration(
                    theme,
                    labelText: context.l10n.passwordConfirm,
                    hintText: context.l10n.passwordRepeat,
                    obscured: _obscurePasswordConfirm,
                    onToggleObscured: () => setState(
                      () => _obscurePasswordConfirm = !_obscurePasswordConfirm,
                    ),
                  ),
                  validator: (v) => (v != _passwordCtrl.text)
                      ? context.l10n.passwordMismatch
                      : null,
                  onFieldSubmitted: (_) => _setNewPassword(),
                ),
                const SizedBox(height: 24),
                _buildSubmitButton(
                  label: context.l10n.forgotSetPassword,
                  icon: Icons.lock_reset,
                  onPressed: _setNewPassword,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessStep(ThemeData theme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 120,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                context.l10n.forgotSuccess,
                style: theme.primaryTextTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ) ??
                    theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              _buildSubmitButton(
                label: context.l10n.toLogin,
                icon: Icons.arrow_forward,
                onPressed: () => navigateToRoute(context, 'login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle? _titleStyle(ThemeData theme) {
    return theme.primaryTextTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ) ??
        theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700);
  }

  InputDecoration _passwordDecoration(
    ThemeData theme, {
    required String labelText,
    required String hintText,
    required bool obscured,
    required VoidCallback onToggleObscured,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: theme.primaryTextTheme.bodySmall,
      hintStyle: theme.primaryTextTheme.bodySmall,
      prefixIcon: const Icon(Icons.lock_outline, size: 20),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      suffixIcon: _passwordVisibilityToggle(theme, obscured, onToggleObscured),
    );
  }

  Widget _passwordVisibilityToggle(
    ThemeData theme,
    bool obscured,
    VoidCallback onToggle,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          left: BorderSide(color: theme.dividerColor.withValues(alpha: 1)),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: IconButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
        ),
        tooltip:
            obscured ? context.l10n.passwordShow : context.l10n.passwordHide,
        iconSize: 20,
        icon: Icon(obscured ? Icons.visibility : Icons.visibility_off),
        onPressed: onToggle,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        splashRadius: 20,
      ),
    );
  }

  Widget _buildSubmitButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _submitting ? null : onPressed,
        icon: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: Theme.of(context).primaryIconTheme.color),
        label: Text(
          label,
          style: Theme.of(context).primaryTextTheme.displayLarge?.copyWith(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.white
                    : Colors.grey[900],
              ),
        ),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    );
  }
}
