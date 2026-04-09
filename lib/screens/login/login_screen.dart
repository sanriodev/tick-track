// ignore_for_file: use_build_context_synchronously, avoid_dynamic_calls

import 'dart:async';
import 'dart:convert';
import 'package:ticktrack/util/helpers.dart';
import 'package:blvckleg_dart_core/models/settings/settings_model.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:blvckleg_dart_core/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _obscure = true;
  bool _submitting = false;

  SettingsModel? appSettings;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    final settings = await Settings().loadSettings();
    if (mounted) {
      setState(() {
        appSettings = settings;
      });
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> login(String username, String password) async {
    final authBackend = AuthBackend();
    try {
      await authBackend.postLogin(username, password);
      navigateToRoute(
        context,
        'home',
      );
    } catch (e) {
      if (e is Response) {
        final jsonData = await json.decode(utf8.decode(e.bodyBytes));
        final String? message =
            (jsonData['message'] as List?)?.first as String?;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${message}')),
        );
      } else {
        // Show error using innerContext which now has a ScaffoldMessenger ancestor.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e}')),
        );
        return;
      }
    }
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      login(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          'TickTrack',
          style: Theme.of(context).primaryTextTheme.titleMedium,
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Welcome back.',
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
                        keyboardType: TextInputType.emailAddress,
                        style: theme.primaryTextTheme.bodySmall,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email
                        ],
                        decoration: InputDecoration(
                          labelText: 'Username',
                          hintText: 'your username',
                          labelStyle: theme.primaryTextTheme.bodySmall,
                          hintStyle: theme.primaryTextTheme.bodySmall,
                          prefixIcon:
                              const Icon(Icons.person_outline, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter your username'
                            : null,
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordCtrl,
                        focusNode: _passwordFocus,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        obscureText: _obscure,
                        enableSuggestions: false,
                        autocorrect: false,
                        style: theme.primaryTextTheme.bodySmall,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'your password',
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
                                  color:
                                      theme.dividerColor.withValues(alpha: 1),
                                ),
                              ),
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: IconButton(
                              style: ButtonStyle(
                                  backgroundColor: WidgetStateProperty.all(
                                      Colors.transparent)),
                              tooltip:
                                  _obscure ? 'Show password' : 'Hide password',
                              iconSize: 20,
                              icon: Icon(_obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              splashRadius: 20,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Please enter your password'
                            : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (appSettings?.registrationEnabled ?? false)
                        const SizedBox(height: 24),
                      if (appSettings?.registrationEnabled ?? false)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () {
                              navigateToRoute(context, 'onboarding',
                                  backEnabled: true);
                            },
                            child: Text(
                              'Noch keinen Account?',
                              style: theme.primaryTextTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  Icons.login,
                                  color:
                                      Theme.of(context).primaryIconTheme.color,
                                ),
                          label: Text('Sign in',
                              style: Theme.of(context)
                                  .primaryTextTheme
                                  .displayLarge),
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
          ),
        ),
      ),
    );
  }
}
