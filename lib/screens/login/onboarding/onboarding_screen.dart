// ignore_for_file: use_build_context_synchronously, avoid_dynamic_calls

import 'dart:async';
import 'dart:convert';

import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';

enum _OnboardingStep { form, code, success }

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const routeName = '/onboarding';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();

  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _codeFocus = FocusNode();

  bool _acceptedPrivacy = false;
  bool _submitting = false;
  bool _obscure = true;
  _OnboardingStep _step = _OnboardingStep.form;

  // null = unknown (empty input or check failed/pending)
  bool? _usernameAvailable;
  bool _checkingUsername = false;
  Timer? _usernameDebounce;

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _codeCtrl.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    setState(() {
      _usernameAvailable = null;
      _checkingUsername = false;
    });

    final username = value.trim();
    if (username.isEmpty) return;

    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _checkingUsername = true);
      try {
        final available = await Backend().checkUsernameAvailable(username);
        if (!mounted || _usernameCtrl.text.trim() != username) return;
        setState(() {
          _usernameAvailable = available;
          _checkingUsername = false;
        });
      } catch (_) {
        // availability is only a hint, the backend decides on submit
        if (!mounted) return;
        setState(() => _checkingUsername = false);
      }
    });
  }

  Future<void> _showResponseError(Object e, String prefix) async {
    if (e is Response) {
      final jsonData = await json.decode(utf8.decode(e.bodyBytes));
      final String? message = jsonData['message'] as String?;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$prefix: ${message}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$prefix: ${e}')),
      );
    }
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    if (!_acceptedPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte akzeptieren Sie die Datenschutzerklärung'),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    if (!mounted) return;
    try {
      await Backend().register(
        _usernameCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
      _codeCtrl.clear();
      setState(() => _step = _OnboardingStep.code);
    } catch (e) {
      await _showResponseError(e, 'Registrierung fehlgeschlagen');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirm() async {
    final form = _codeFormKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    if (!mounted) return;
    try {
      await Backend().confirmRegistration(
        _emailCtrl.text.trim(),
        _codeCtrl.text.trim(),
      );
      setState(() => _step = _OnboardingStep.success);
    } catch (e) {
      await _showResponseError(e, 'Bestätigung fehlgeschlagen');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() => _submitting = true);
    try {
      await Backend().register(
        _usernameCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code wurde erneut gesendet')),
      );
    } catch (e) {
      await _showResponseError(e, 'Senden fehlgeschlagen');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// The account is confirmed at this point, so the "Weiter" button logs
  /// the fresh user in directly with the credentials from the form.
  Future<void> _continueWithLogin() async {
    setState(() => _submitting = true);
    try {
      await AuthBackend().postLogin(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text,
      );
      await navigateAfterAuth(context);
    } catch (e) {
      await _showResponseError(e, 'Login fehlgeschlagen');
      navigateToRoute(context, 'login');
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
          style: Theme.of(context).primaryTextTheme.titleMedium,
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        centerTitle: true,
        leading: _step == _OnboardingStep.success
            ? null
            : Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    if (_step == _OnboardingStep.code) {
                      setState(() => _step = _OnboardingStep.form);
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  color: Theme.of(context).primaryIconTheme.color,
                  tooltip: "I love my gf",
                ),
              ),
      ),
      body: SafeArea(
        child: switch (_step) {
          _OnboardingStep.form => _buildRegisterForm(theme),
          _OnboardingStep.code => _buildCodeForm(theme),
          _OnboardingStep.success => _buildSuccessView(theme),
        },
      ),
    );
  }

  Widget _buildSuccessView(ThemeData theme) {
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
                'Dein Account wurde bestätigt und ist startklar!',
                style: theme.primaryTextTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ) ??
                    theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _continueWithLogin,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.arrow_forward,
                          color: Theme.of(context).primaryIconTheme.color,
                        ),
                  label: Text(
                    'Weiter',
                    style: Theme.of(context)
                        .primaryTextTheme
                        .displayLarge
                        ?.copyWith(
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.white
                                  : Colors.grey[900],
                        ),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeForm(ThemeData theme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _codeFormKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'E-Mail bestätigen',
                  style: theme.primaryTextTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ) ??
                      theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Wir haben dir einen 5-stelligen Code an '
                  '${_emailCtrl.text.trim()} geschickt.',
                  style: theme.primaryTextTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _codeCtrl,
                  focusNode: _codeFocus,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  textAlign: TextAlign.center,
                  style: theme.primaryTextTheme.bodyLarge?.copyWith(
                    letterSpacing: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Bestätigungscode',
                    hintText: '·····',
                    labelStyle: theme.primaryTextTheme.bodySmall,
                    hintStyle: theme.primaryTextTheme.bodySmall,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().length != 5)
                      ? 'Bitte geben Sie den 5-stelligen Code ein'
                      : null,
                  onFieldSubmitted: (_) => _confirm(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _confirm,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.verified_outlined,
                            color: Theme.of(context).primaryIconTheme.color,
                          ),
                    label: Text(
                      'Bestätigen',
                      style: Theme.of(context)
                          .primaryTextTheme
                          .displayLarge
                          ?.copyWith(
                            color: Theme.of(context).brightness ==
                                    Brightness.light
                                ? Colors.white
                                : Colors.grey[900],
                          ),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _submitting ? null : _resendCode,
                  child: Text(
                    'Code erneut senden',
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

  Widget? _usernameSuffixIcon(ThemeData theme) {
    if (_checkingUsername) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_usernameAvailable == true) {
      return const Icon(Icons.check_circle_outline,
          size: 20, color: Colors.green);
    }
    if (_usernameAvailable == false) {
      return Icon(Icons.cancel_outlined,
          size: 20, color: theme.colorScheme.error);
    }
    return null;
  }

  Widget _buildRegisterForm(ThemeData theme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Account erstellen',
                  style: theme.primaryTextTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ) ??
                      theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _usernameCtrl,
                  focusNode: _usernameFocus,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.text,
                  style: theme.primaryTextTheme.bodySmall,
                  onChanged: _onUsernameChanged,
                  decoration: InputDecoration(
                    labelText: 'Benutzername',
                    hintText: 'Gewünschter Benutzername',
                    labelStyle: theme.primaryTextTheme.bodySmall,
                    hintStyle: theme.primaryTextTheme.bodySmall,
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    suffixIcon: _usernameSuffixIcon(theme),
                    helperText: _usernameAvailable == null
                        ? null
                        : _usernameAvailable!
                            ? 'Benutzername ist frei'
                            : 'Benutzername ist bereits vergeben',
                    helperStyle: theme.primaryTextTheme.bodySmall?.copyWith(
                      color: _usernameAvailable == true
                          ? Colors.green
                          : theme.colorScheme.error,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Bitte geben Sie einen Benutzernamen ein'
                      : null,
                  onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  focusNode: _emailFocus,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  style: theme.primaryTextTheme.bodySmall,
                  decoration: InputDecoration(
                    labelText: 'E-Mail-Adresse',
                    hintText: 'ihre.email@beispiel.de',
                    labelStyle: theme.primaryTextTheme.bodySmall,
                    hintStyle: theme.primaryTextTheme.bodySmall,
                    prefixIcon: const Icon(Icons.email_outlined, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Bitte geben Sie eine E-Mail-Adresse ein';
                    }
                    if (!v.contains('@')) {
                      return 'Bitte geben Sie eine gültige E-Mail-Adresse ein';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  focusNode: _passwordFocus,
                  textInputAction: TextInputAction.done,
                  obscureText: _obscure,
                  enableSuggestions: false,
                  autocorrect: false,
                  style: theme.primaryTextTheme.bodySmall,
                  decoration: InputDecoration(
                    labelText: 'Passwort',
                    hintText: 'Mindestens 8 Zeichen',
                    labelStyle: theme.primaryTextTheme.bodySmall,
                    hintStyle: theme.primaryTextTheme.bodySmall,
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    suffixIconConstraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                    suffixIcon: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border(
                          left: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 1),
                          ),
                        ),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: IconButton(
                        style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.all(Colors.transparent)),
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        iconSize: 20,
                        icon: Icon(_obscure
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        splashRadius: 20,
                      ),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 8)
                      ? 'Das Passwort muss mindestens 8 Zeichen haben'
                      : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acceptedPrivacy,
                      onChanged: (value) {
                        setState(() => _acceptedPrivacy = value ?? false);
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: RichText(
                          text: TextSpan(
                            style: theme.primaryTextTheme.bodySmall,
                            children: [
                              TextSpan(
                                text: 'Ich bin mit der ',
                              ),
                              TextSpan(
                                text: 'Datenschutzerklärung',
                                style:
                                    theme.primaryTextTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    launchUrlInBrowser(
                                      Uri.parse(
                                          'https://blvckleg.dev/app-legal'),
                                    );
                                  },
                              ),
                              TextSpan(
                                text: ' einverstanden',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.person_add_alt,
                            color: Theme.of(context).primaryIconTheme.color,
                          ),
                    label: Text(
                      'Registrieren',
                      style: Theme.of(context)
                          .primaryTextTheme
                          .displayLarge
                          ?.copyWith(
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? Colors.white
                                    : Colors.grey[900],
                          ),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
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
}
