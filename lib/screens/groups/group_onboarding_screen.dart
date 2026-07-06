// ignore_for_file: use_build_context_synchronously, avoid_dynamic_calls

import 'dart:convert';

import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:blvckleg_dart_core/exception/session_expired.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Shown after login when the user is not a member of any group yet.
/// Explains the group concept in a small carousel and forces the user to
/// either join a group via join code or create a new one.
class GroupOnboardingScreen extends StatefulWidget {
  const GroupOnboardingScreen({super.key});

  @override
  State<GroupOnboardingScreen> createState() => _GroupOnboardingScreenState();
}

class _GroupOnboardingScreenState extends State<GroupOnboardingScreen> {
  final PageController _pageController = PageController();
  final _joinCodeCtrl = TextEditingController();

  int _currentPage = 0;
  bool _joining = false;

  static const int _pageCount = 3;

  @override
  void dispose() {
    _pageController.dispose();
    _joinCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _joinGroup() async {
    final code = _joinCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gib einen Einladungscode ein.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _joining = true);

    try {
      final group = await Backend().joinGroup(code);
      await GroupContext().refresh();
      await GroupContext().setActiveGroup(group);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gruppe "${group.name}" beigetreten.')),
        );
        navigateToRoute(context, 'home');
      }
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
          SnackBar(content: Text('Beitritt fehlgeschlagen: $message')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Beitritt fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildInfoPage(
    ThemeData theme, {
    required PhosphorIconData icon,
    required String title,
    required String text,
    Widget? extra,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: PhosphorIcon(
                    icon,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                title,
                style: theme.primaryTextTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                text,
                style: theme.primaryTextTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (extra != null) ...[
                const SizedBox(height: 16),
                extra,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyRow(
    ThemeData theme,
    PhosphorIconData icon,
    String title,
    String text,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhosphorIcon(
            icon,
            size: 22,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.primaryTextTheme.bodySmall,
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: theme.primaryTextTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPage(ThemeData theme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Leg los!',
                style: theme.primaryTextTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tritt mit einem Einladungscode einer Gruppe bei oder erstelle deine eigene.',
                style: theme.primaryTextTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _joinCodeCtrl,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                style: theme.primaryTextTheme.bodySmall?.copyWith(
                  letterSpacing: 2,
                ),
                decoration: InputDecoration(
                  labelText: 'Einladungscode',
                  hintText: 'z.B. A2B3C4D5',
                  labelStyle: theme.primaryTextTheme.bodySmall,
                  hintStyle: theme.primaryTextTheme.bodySmall,
                  prefixIcon: const Icon(Icons.key_outlined, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onSubmitted: (_) => _joinGroup(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _joining ? null : _joinGroup,
                  icon: _joining
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.login,
                          color: theme.primaryIconTheme.color,
                        ),
                  label: Text(
                    'Gruppe beitreten',
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
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'oder',
                      style: theme.primaryTextTheme.bodySmall,
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    navigateToRoute(context, 'group-create',
                        backEnabled: true);
                  },
                  icon: Icon(
                    Icons.add,
                    color: theme.colorScheme.primary,
                  ),
                  label: Text(
                    'Neue Gruppe erstellen',
                    style: theme.primaryTextTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(color: theme.colorScheme.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDots(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pageCount, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary
                : theme.dividerColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildInfoPage(
                    theme,
                    icon: PhosphorIconsRegular.usersThree,
                    title: 'Gemeinsam organisiert',
                    text:
                        'In TickTrack passiert alles in Gruppen: Notizen, Aufgabenlisten und Aktivitäten teilst du nur mit den Mitgliedern deiner Gruppe – wie ein privater Space für Familie, WG oder Team. Du kannst in beliebig vielen Gruppen sein und oben in der App jederzeit zwischen ihnen wechseln.',
                  ),
                  _buildInfoPage(
                    theme,
                    icon: PhosphorIconsRegular.shieldCheck,
                    title: 'Du bestimmst die Privatsphäre',
                    text:
                        'Für jede Notiz und Liste legst du fest, was deine Gruppe sehen darf:',
                    extra: Column(
                      children: [
                        _buildPrivacyRow(
                          theme,
                          PhosphorIconsRegular.lock,
                          'Privat',
                          'nur du kannst den Eintrag sehen.',
                        ),
                        _buildPrivacyRow(
                          theme,
                          PhosphorIconsRegular.shield,
                          'Geschützt',
                          'deine Gruppe kann den Eintrag sehen, aber nur du kannst ihn bearbeiten.',
                        ),
                        _buildPrivacyRow(
                          theme,
                          PhosphorIconsRegular.eye,
                          'Öffentlich',
                          'deine Gruppe kann den Eintrag sehen und bearbeiten.',
                        ),
                      ],
                    ),
                  ),
                  _buildActionPage(theme),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _buildDots(theme),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: _currentPage < _pageCount - 1
                    ? ElevatedButton(
                        onPressed: _nextPage,
                        child: Text(
                          'Weiter',
                          style: theme.primaryTextTheme.displayLarge?.copyWith(
                            color: theme.brightness == Brightness.light
                                ? Colors.white
                                : Colors.grey[900],
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
