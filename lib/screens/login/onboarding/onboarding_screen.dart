// ignore_for_file: use_build_context_synchronously, avoid_dynamic_calls

import 'dart:convert';

import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const routeName = '/onboarding';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();

  bool _acceptedPrivacy = false;
  bool _submitting = false;
  bool _requestSuccess = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
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
      await Backend()
          .requestAccess(_usernameCtrl.text.trim(), _emailCtrl.text.trim());
      setState(() => _requestSuccess = true);
    } catch (e) {
      if (e is Response) {
        final jsonData = await json.decode(utf8.decode(e.bodyBytes));
        final String? message = jsonData['message'] as String?;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request failed: ${message}')),
        );
      } else {
        // Show error using innerContext which now has a ScaffoldMessenger ancestor.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request failed: ${e}')),
        );
        return;
      }
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
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              Navigator.of(context).pop();
            },
            color: Theme.of(context).primaryIconTheme.color,
            tooltip: "I love my gf",
          ),
        ),
      ),
      body: SafeArea(
        child: _requestSuccess
            ? _buildSuccessView(theme)
            : _buildRequestForm(theme),
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
                'Anfrage für einen Account geschickt, behalte dein Email-Postfach im Auge',
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
                  onPressed: () {
                    navigateToRoute(context, 'login');
                  },
                  icon: Icon(
                    Icons.arrow_back,
                    color: Theme.of(context).primaryIconTheme.color,
                  ),
                  label: Text(
                    'Zurück zum Login',
                    style: Theme.of(context).primaryTextTheme.displayLarge,
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

  Widget _buildRequestForm(ThemeData theme) {
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
                  'Zugang anfordern',
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
                  decoration: InputDecoration(
                    labelText: 'Benutzername',
                    hintText: 'Gewünschter Benutzername',
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
                      ? 'Bitte geben Sie einen Benutzernamen ein'
                      : null,
                  onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  focusNode: _emailFocus,
                  textInputAction: TextInputAction.done,
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
                            Icons.send,
                            color: Theme.of(context).primaryIconTheme.color,
                          ),
                    label: Text(
                      'Account anfordern',
                      style: Theme.of(context).primaryTextTheme.displayLarge,
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
