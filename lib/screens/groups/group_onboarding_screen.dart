// ignore_for_file: use_build_context_synchronously, avoid_dynamic_calls

import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/models/group/group_api_model.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/widgets/group/group_add_form.dart';
import 'package:ticktrack/widgets/group/group_created_success.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class GroupOnboardingScreen extends StatefulWidget {
  const GroupOnboardingScreen({super.key});

  @override
  State<GroupOnboardingScreen> createState() => _GroupOnboardingScreenState();
}

class _GroupOnboardingScreenState extends State<GroupOnboardingScreen> {
  final PageController _pageController = PageController();

  int _currentPage = 0;
  Group? _createdGroup;

  static const int _pageCount = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showCreatedGroup(Group group) {
    setState(() => _createdGroup = group);
  }

  void _goHomeAfterJoin(Group group) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.groupJoined(group.name))),
    );
    navigateToRoute(context, 'home');
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
                    text: context.l10n.labelWithValue(title),
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

  Widget _buildActionPage() {
    final group = _createdGroup;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: group == null
              ? GroupAddForm(
                  onGroupJoined: _goHomeAfterJoin,
                  onGroupCreated: _showCreatedGroup,
                )
              : GroupCreatedSuccess(
                  group: group,
                  onContinue: () => navigateToRoute(context, 'home'),
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
            color: isActive ? theme.colorScheme.primary : theme.dividerColor,
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
                    title: context.l10n.groupOnboardingTitle,
                    text: context.l10n.groupOnboardingText,
                  ),
                  _buildInfoPage(
                    theme,
                    icon: PhosphorIconsRegular.shieldCheck,
                    title: context.l10n.privacyOnboardingTitle,
                    text: context.l10n.privacyOnboardingText,
                    extra: Column(
                      children: [
                        _buildPrivacyRow(
                          theme,
                          PhosphorIconsRegular.lock,
                          context.l10n.privacyPrivate,
                          context.l10n.privacyPrivateShort,
                        ),
                        _buildPrivacyRow(
                          theme,
                          PhosphorIconsRegular.shield,
                          context.l10n.privacyProtected,
                          context.l10n.privacyProtectedShort,
                        ),
                        _buildPrivacyRow(
                          theme,
                          PhosphorIconsRegular.eye,
                          context.l10n.privacyPublic,
                          context.l10n.privacyPublicShort,
                        ),
                      ],
                    ),
                  ),
                  _buildActionPage(),
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
                          context.l10n.next,
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
