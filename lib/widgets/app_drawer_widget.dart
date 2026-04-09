// ignore_for_file: use_build_context_synchronously

import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/screens/home/main_app_screen.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:blvckleg_dart_core/exception/session_expired.dart';
import 'package:blvckleg_dart_core/models/user/user_model.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
  );

  User? _ownUser;

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
    _getOwnUser();
  }

  Future<void> _getOwnUser() async {
    final res = await AuthBackend().getOwnUser();
    setState(() {
      _ownUser = res;
    });
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  Future<void> _changePassword(String userId, String newPassword) async {
    try {
      final backend = AuthBackend();
      if (_ownUser != null && _ownUser!.publicActivity != null) {
        await backend.patchChangePassword(userId, newPassword);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Passwort erfolgreich geändert.')),
        );
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
      }
    }
  }

  Future<void> _showChangePasswordDialogue() async {
    String newPassword = '';
    String newPasswordConfirm = '';
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Passwort ändern.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              final passwordsMatch = newPassword.isNotEmpty &&
                  newPasswordConfirm.isNotEmpty &&
                  newPassword == newPasswordConfirm;
              final showError =
                  newPasswordConfirm.isNotEmpty && !passwordsMatch;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    obscureText: true,
                    style: theme.primaryTextTheme.bodySmall,
                    decoration: InputDecoration(
                      labelText: 'Neues Passwort',
                      labelStyle: theme.primaryTextTheme.bodySmall,
                      hintStyle: theme.primaryTextTheme.bodySmall,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        newPassword = value;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    obscureText: true,
                    style: theme.primaryTextTheme.bodySmall,
                    decoration: InputDecoration(
                      labelText: 'Passwort bestätigen',
                      labelStyle: theme.primaryTextTheme.bodySmall,
                      hintStyle: theme.primaryTextTheme.bodySmall,
                      border: OutlineInputBorder(),
                      errorText:
                          showError ? 'Passwörter stimmen nicht überein' : null,
                      errorStyle: theme.primaryTextTheme.bodySmall?.copyWith(
                        color: Colors.red,
                      ),
                      errorBorder: showError
                          ? OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.red, width: 2),
                            )
                          : null,
                      focusedErrorBorder: showError
                          ? OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.red, width: 2),
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        newPasswordConfirm = value;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () async {
                if (newPasswordConfirm != newPassword ||
                    newPassword.isEmpty ||
                    _ownUser == null) {
                  return;
                }
                await _changePassword(_ownUser!.id.toString(), newPassword);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text('Bestätigen'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changeActivityPrivacy() async {
    try {
      final backend = Backend();
      if (_ownUser != null && _ownUser!.publicActivity != null) {
        await backend.setActivityPrivacy(!_ownUser!.publicActivity!);
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
      }
    }
  }

  void _showActivityDialogue() {
    final isCurrentlyPublic = _ownUser != null &&
        _ownUser!.publicActivity != null &&
        _ownUser!.publicActivity!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            isCurrentlyPublic
                ? 'Aktivitäten nicht teilen?'
                : 'Aktivitäten teilen?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          content: Text(
            isCurrentlyPublic
                ? 'Aktivitäten werden nicht länger geteilt.'
                : 'Andere Benutzer können sehen wenn Sie Einträge erstellen, aktualisieren oder löschen',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () async {
                await _changeActivityPrivacy();
                await _getOwnUser();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text('Bestätigen'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(color: Theme.of(context).canvasColor),
        child: Column(
          children: [
            Container(
              color: Theme.of(context).primaryColor,
              width: double.infinity,
              height: 205,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 20,
                      left: 15,
                      child: Text(
                        'Alina\'s App\nI love Alina',
                        style: Theme.of(context).primaryTextTheme.displayLarge?.copyWith(
                          color: Theme.of(context).brightness == Brightness.light
                              ? Colors.white
                              : Colors.grey[300],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              onTap: () {
                if (MainAppScreen.of(context)!.currentTheme == ThemeMode.dark) {
                  MainAppScreen.of(context)!.currentTheme = ThemeMode.light;
                  setState(() {
                    MainAppScreen.of(context)!.changeTheme(ThemeMode.light);
                  });
                } else {
                  MainAppScreen.of(context)!.currentTheme = ThemeMode.dark;
                  setState(() {
                    MainAppScreen.of(context)!.changeTheme(ThemeMode.dark);
                  });
                }
                setState(() {});
              },
              leading: PhosphorIcon(
                MainAppScreen.of(context)!.currentTheme == ThemeMode.dark
                    ? PhosphorIconsRegular.sun
                    : PhosphorIconsRegular.moon,
                color: Theme.of(context).primaryIconTheme.color,
              ),
              title: Text(
                'Theme ändern',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ListTile(
              onTap: () {
                _showActivityDialogue();
              },
              leading: PhosphorIcon(
                PhosphorIcons.pulse(),
                color: Theme.of(context).primaryIconTheme.color,
              ),
              title: Text(
                'Aktivität - ${_ownUser != null && _ownUser!.publicActivity != null && _ownUser!.publicActivity! ? 'Öffentlich' : 'Privat'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Spacer(),
            ListTile(
              onTap: () {
                _showChangePasswordDialogue();
              },
              leading: PhosphorIcon(
                PhosphorIconsRegular.password,
                color: Theme.of(context).primaryIconTheme.color,
              ),
              title: Text(
                'Passwort ändern',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ListTile(
              onTap: () async {
                try {
                  await AuthBackend().postLogout();
                  await deleteBoxAndNavigateToLogin(context);
                } catch (e) {
                  await deleteBoxAndNavigateToLogin(context);
                }
              },
              leading: PhosphorIcon(
                PhosphorIconsRegular.signOut,
                color: Theme.of(context).primaryIconTheme.color,
              ),
              title: Text(
                'Abmelden',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      launchUrlInBrowser(
                        Uri.parse(
                          "https://blvckleg.dev/app-legal",
                        ),
                      );
                    },
                    child: Text(
                      'Datenschutz',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            decoration: TextDecoration.underline,
                          ),
                    ),
                  ),
                  Container(
                    height: 12,
                    width: 1,
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).brightness == Brightness.light
                              ? Colors.black
                              : Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: () => showAboutDialog(
                      context: context,
                      applicationVersion: 'Version: ${_packageInfo.version}',
                      applicationName: 'Alina\'s App',
                      children: [
                        Text(
                          'Copyright: MATTEO JUEN',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        Text(
                          'Entwickelt von:',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          '• MATTEO JUEN',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                    child: Text(
                      'Version: ${_packageInfo.version}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(padding: EdgeInsets.only(top: 30)),
          ],
        ),
      ),
    );
  }
}
