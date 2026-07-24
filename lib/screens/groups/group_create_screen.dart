// ignore_for_file: use_build_context_synchronously, avoid_dynamic_calls

import 'dart:convert';

import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/models/group/group_api_model.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:blvckleg_dart_core/exception/session_expired.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class GroupCreateScreen extends StatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  bool _submitting = false;
  Group? _createdGroup;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      final group = await Backend().createGroup(_nameCtrl.text.trim());
      await GroupContext().refresh();
      await GroupContext().setActiveGroup(group);
      setState(() => _createdGroup = group);
    } catch (e) {
      if (e is SessionExpiredException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bitte melde dich erneut an.')),
        );
        try {
          await AuthBackend().postLogout();
          await deleteBoxAndNavigateToLogin(context);
        } catch (e) {
          await deleteBoxAndNavigateToLogin(context);
        }
      } else if (e is Response) {
        final jsonData = await json.decode(utf8.decode(e.bodyBytes));
        final String? message = jsonData['message'] as String?;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gruppe konnte nicht erstellt werden: $message')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gruppe konnte nicht erstellt werden: $e')),
        );
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
          'Gruppe erstellen',
          style: theme.primaryTextTheme.titleMedium,
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              Navigator.of(context).pop();
            },
            color: theme.primaryIconTheme.color,
          ),
        ),
      ),
      body: SafeArea(
        child: _createdGroup != null
            ? _buildSuccessView(theme)
            : _buildCreateForm(theme),
      ),
    );
  }

  Widget _buildCreateForm(ThemeData theme) {
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
                PhosphorIcon(
                  PhosphorIconsRegular.usersThree,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Deine neue Gruppe',
                  style: theme.primaryTextTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Notizen, Aufgabenlisten und Aktivitäten teilst du nur mit den Mitgliedern deiner Gruppe.',
                  style: theme.primaryTextTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.done,
                  style: theme.primaryTextTheme.bodySmall,
                  decoration: InputDecoration(
                    labelText: 'Name der Gruppe',
                    hintText: 'z.B. Familie, WG, Team',
                    labelStyle: theme.primaryTextTheme.bodySmall,
                    hintStyle: theme.primaryTextTheme.bodySmall,
                    prefixIcon: const Icon(Icons.group_outlined, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Bitte gib einen Gruppennamen ein'
                      : null,
                  onFieldSubmitted: (_) => _createGroup(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _createGroup,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.add,
                            color: theme.primaryIconTheme.color,
                          ),
                    label: Text(
                      'Gruppe erstellen',
                      style: theme.primaryTextTheme.displayLarge?.copyWith(
                        color: theme.brightness == Brightness.light
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

  Widget _buildSuccessView(ThemeData theme) {
    final group = _createdGroup!;
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
                size: 96,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Gruppe "${group.name}" erstellt!',
                style: theme.primaryTextTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Mit diesem Einladungscode können andere deiner Gruppe beitreten:',
                style: theme.primaryTextTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.canvasColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(
                      group.joinCode,
                      style: theme.primaryTextTheme.titleMedium?.copyWith(
                        letterSpacing: 4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Code kopieren',
                      icon: PhosphorIcon(
                        PhosphorIconsRegular.copy,
                        color: theme.primaryIconTheme.color,
                      ),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: group.joinCode),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Einladungscode kopiert.'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    navigateToRoute(context, 'home');
                  },
                  icon: Icon(
                    Icons.arrow_forward,
                    color: theme.primaryIconTheme.color,
                  ),
                  label: Text(
                    'Los geht\'s',
                    style: theme.primaryTextTheme.displayLarge?.copyWith(
                      color: theme.brightness == Brightness.light
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
}
