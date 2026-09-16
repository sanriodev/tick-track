// ignore_for_file: use_build_context_synchronously

import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/screens/home/main_app_screen.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/widgets/language_toggle.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

const String _privacyUrl = 'https://blvckleg.dev/app-legal';
const String _supportUrl = 'https://tick-track.app/#support';

enum _AppOption { profile, groupDetails, logout }

Future<void> showAppOptionsSheet(BuildContext context) async {
  final option = await showModalBottomSheet<_AppOption>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => const _AppOptionsSheet(),
  );

  if (option == null || !context.mounted) return;
  await _runAppOption(context, option);
}

Future<void> _runAppOption(BuildContext context, _AppOption option) async {
  switch (option) {
    case _AppOption.profile:
      await navigateToRoute(context, 'profile', backEnabled: true);
    case _AppOption.groupDetails:
      await navigateToRoute(context, 'group-details', backEnabled: true);
    case _AppOption.logout:
      await _logout(context);
  }
}

Future<void> _logout(BuildContext context) async {
  await AuthBackend().postLogout().catchError((_) {});
  await deleteBoxAndNavigateToLogin(context);
}

class _AppOptionsSheet extends StatefulWidget {
  const _AppOptionsSheet();

  @override
  State<_AppOptionsSheet> createState() => _AppOptionsSheetState();
}

class _AppOptionsSheetState extends State<_AppOptionsSheet> {
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
  );

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _packageInfo = info);
  }

  bool get _isDarkTheme =>
      MainAppScreen.of(context)?.currentTheme == ThemeMode.dark;

  void _toggleTheme() {
    final appState = MainAppScreen.of(context);
    if (appState == null) return;

    final nextTheme = _isDarkTheme ? ThemeMode.light : ThemeMode.dark;
    appState.currentTheme = nextTheme;
    setState(() => appState.changeTheme(nextTheme));
  }

  void _selectOption(_AppOption option) {
    Navigator.of(context).pop(option);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                context.l10n.optionsTitle,
                style: theme.primaryTextTheme.titleSmall,
              ),
            ),
            _buildOptionTile(
              theme,
              icon: _isDarkTheme
                  ? PhosphorIconsRegular.sun
                  : PhosphorIconsRegular.moon,
              title: context.l10n.optionsChangeTheme,
              onTap: _toggleTheme,
            ),
            _buildLanguageTile(theme),
            const Divider(height: 1),
            _buildOptionTile(
              theme,
              icon: PhosphorIconsRegular.userCircle,
              title: context.l10n.optionsEditProfile,
              onTap: () => _selectOption(_AppOption.profile),
            ),
            _buildOptionTile(
              theme,
              icon: PhosphorIconsRegular.usersThree,
              title: context.l10n.optionsGroupOverview,
              onTap: () => _selectOption(_AppOption.groupDetails),
            ),
            const Divider(height: 1),
            _buildOptionTile(
              theme,
              icon: PhosphorIconsRegular.signOut,
              title: context.l10n.optionsSignOut,
              onTap: () => _selectOption(_AppOption.logout),
            ),
            const SizedBox(height: 24),
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageTile(ThemeData theme) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: PhosphorIcon(
        PhosphorIconsRegular.translate,
        color: theme.primaryIconTheme.color,
      ),
      title: Text(context.l10n.language, style: theme.textTheme.bodySmall),
      trailing: const LanguageToggle(compact: true),
    );
  }

  Widget _buildOptionTile(
    ThemeData theme, {
    required PhosphorIconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: PhosphorIcon(icon, color: theme.primaryIconTheme.color),
      title: Text(title, style: theme.textTheme.bodySmall),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildLinkButton(theme, label: context.l10n.privacyPolicy, url: _privacyUrl),
        _buildLinkButton(theme, label: context.l10n.support, url: _supportUrl),
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: theme.brightness == Brightness.light
                ? Colors.black
                : Colors.white,
          ),
          onPressed: _showVersionDialog,
          child: Text(
            context.l10n.versionLabel(_packageInfo.version),
            style: theme.textTheme.labelSmall,
          ),
        ),
      ],
    );
  }

  Widget _buildLinkButton(
    ThemeData theme, {
    required String label,
    required String url,
  }) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () => launchUrlInBrowser(Uri.parse(url)),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  void _showVersionDialog() {
    final theme = Theme.of(context);
    showAboutDialog(
      context: context,
      applicationVersion: context.l10n.versionLabel(_packageInfo.version),
      applicationName: 'TickTrack',
      children: [
        Text(context.l10n.copyrightLabel, style: theme.textTheme.labelSmall),
        const SizedBox(height: 20),
        Text(context.l10n.developedBy, style: theme.textTheme.labelSmall),
        Text('• MATTEO JUEN', style: theme.textTheme.labelSmall),
      ],
    );
  }
}
