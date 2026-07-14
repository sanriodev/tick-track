// ignore_for_file: use_build_context_synchronously, avoid_dynamic_calls

import 'dart:convert';

import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/models/group/group_api_model.dart';
import 'package:ticktrack/screens/home/main_app_screen.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:blvckleg_dart_core/exception/session_expired.dart';
import 'package:blvckleg_dart_core/models/user/user_model.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
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

  Future<void> _changePassword(String newPassword) async {
    try {
      await Backend().changeOwnPassword(newPassword);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwort erfolgreich geändert.')),
      );
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Passwort ändern fehlgeschlagen.')),
        );
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
                await _changePassword(newPassword);
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

  Future<void> _handleGroupError(Object e, String fallbackMessage) async {
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
        SnackBar(content: Text('$fallbackMessage: $message')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$fallbackMessage: $e')),
      );
    }
  }

  Future<void> _joinGroup(String joinCode) async {
    try {
      final group = await Backend().joinGroup(joinCode);
      await GroupContext().refresh();
      await GroupContext().setActiveGroup(group);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gruppe "${group.name}" beigetreten.')),
      );
    } catch (e) {
      await _handleGroupError(e, 'Beitritt fehlgeschlagen');
    }
  }

  Future<void> _showAddGroupDialogue() async {
    String joinCode = '';
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Gruppe hinzufügen',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tritt mit einem Einladungscode einer Gruppe bei:',
                    style: theme.primaryTextTheme.bodySmall,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    textCapitalization: TextCapitalization.characters,
                    style: theme.primaryTextTheme.bodySmall?.copyWith(
                      letterSpacing: 2,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Einladungscode',
                      labelStyle: theme.primaryTextTheme.bodySmall,
                      hintStyle: theme.primaryTextTheme.bodySmall,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        joinCode = value;
                      });
                    },
                  ),
                  SizedBox(height: 20),
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
                  SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
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
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () async {
                final code = joinCode.trim().toUpperCase();
                if (code.isEmpty) {
                  return;
                }
                await _joinGroup(code);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: Text('Beitreten'),
            ),
          ],
        );
      },
    );
  }

  Future<Group?> _selectGroupToLeave(List<Group> groups) async {
    return await showDialog<Group>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Welche Gruppe verlassen?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: groups.length,
              itemBuilder: (BuildContext listContext, int index) {
                final group = groups[index];
                return ListTile(
                  leading: PhosphorIcon(
                    PhosphorIconsRegular.usersThree,
                    color: Theme.of(context).primaryIconTheme.color,
                  ),
                  title: Text(
                    group.name,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () {
                    Navigator.of(dialogContext).pop(group);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('Abbrechen'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmLeaveGroup(Group group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Gruppe verlassen?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          content: Text(
            'Möchtest du die Gruppe "${group.name}" wirklich verlassen? '
            'Du verlierst den Zugriff auf alle Einträge dieser Gruppe. '
            'Verlässt das letzte Mitglied die Gruppe, wird sie gelöscht.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text('Bestätigen'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _leaveGroupFlow() async {
    final groups = GroupContext().groups;
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Du bist in keiner Gruppe.')),
      );
      return;
    }

    Group? group;
    if (groups.length == 1) {
      group = groups.first;
    } else {
      group = await _selectGroupToLeave(groups);
    }
    if (group == null) {
      return;
    }

    if (!await _confirmLeaveGroup(group)) {
      return;
    }

    try {
      await Backend().leaveGroup(group.id);
      await GroupContext().refresh();
      if (!GroupContext().hasGroups) {
        navigateToRoute(context, 'group-onboarding');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gruppe "${group.name}" verlassen.')),
      );
    } catch (e) {
      await _handleGroupError(e, 'Gruppe konnte nicht verlassen werden');
    }
  }

  Future<void> _showInviteCodeDialogue() async {
    final group = GroupContext().activeGroup;
    if (group == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Du bist in keiner Gruppe.')),
      );
      return;
    }
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Einladungscode',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mit diesem Code können andere der Gruppe "${group.name}" beitreten:',
                style: theme.primaryTextTheme.bodySmall,
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SelectableText(
                    group.joinCode,
                    style: theme.primaryTextTheme.titleMedium?.copyWith(
                      letterSpacing: 4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Einladungscode kopiert.'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('Schließen'),
            ),
          ],
        );
      },
    );
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
                        'TickTrack\nmanage tasks, take notes!',
                        style: Theme.of(context).primaryTextTheme.displayLarge?.copyWith(
                          color: Theme.of(context).brightness == Brightness.light
                              ? Colors.white
                              : Colors.grey[900],
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
            const Divider(),
            ListTile(
              onTap: () {
                _showAddGroupDialogue();
              },
              leading: PhosphorIcon(
                PhosphorIconsRegular.userPlus,
                color: Theme.of(context).primaryIconTheme.color,
              ),
              title: Text(
                'Gruppe hinzufügen',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ListTile(
              onTap: () {
                _leaveGroupFlow();
              },
              leading: PhosphorIcon(
                PhosphorIconsRegular.userMinus,
                color: Theme.of(context).primaryIconTheme.color,
              ),
              title: Text(
                'Gruppe verlassen',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ListTile(
              onTap: () {
                _showInviteCodeDialogue();
              },
              leading: PhosphorIcon(
                PhosphorIconsRegular.key,
                color: Theme.of(context).primaryIconTheme.color,
              ),
              title: Text(
                'Einladungscode',
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
                      applicationName: 'TickTrack',
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
