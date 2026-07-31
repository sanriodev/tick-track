// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/state/avatar_store.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/widgets/app_drawer_widget.dart';
import 'package:ticktrack/widgets/option_button.dart';
import 'package:ticktrack/widgets/skeleton/skeleton_card.dart';
import 'package:ticktrack/widgets/user_avatar_widget.dart';
import 'package:blvckleg_dart_core/models/user/user_model.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Everything that belongs to the own account in one place: the name, the
/// address it was registered with, the password and how visible the own
/// activity is. Used to be spread over single entries in the app drawer.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const routeName = '/profile';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  bool _busy = false;
  User? _ownUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthBackend().getOwnUser();
      if (!mounted) return;
      setState(() {
        _ownUser = user;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      await showBackendError(context, e, 'Profil konnte nicht geladen werden');
    }
  }

  // ---------------------------------------------------------------- username

  Future<void> _showChangeUsernameDialog() async {
    final current = _ownUser?.username;
    if (current == null) return;

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _UsernameDialog(currentUsername: current),
    );

    if (newName != null && newName != current) {
      await _changeUsername(newName);
    }
  }

  Future<void> _changeUsername(String username) async {
    setState(() => _busy = true);
    try {
      final stored = await Backend().changeOwnUsername(username);
      // the cached session still holds the old name, and ownership of notes
      // and lists is decided by comparing against it
      await applyRenamedUsername(stored);
      Haptics.tap();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Benutzername ist jetzt "$stored".')),
        );
      }
      await _load();
    } catch (e) {
      Haptics.warning();
      await showBackendError(
        context,
        e,
        'Benutzername konnte nicht geändert werden',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------------ avatar

  /// Camera, gallery and - only when there is one - removing the picture.
  Future<void> _showAvatarSheet() async {
    final theme = Theme.of(context);
    final userId = _ownUser?.id;
    final hasAvatar =
        userId != null && AvatarStore().bytesFor(userId) != null;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.cardColor,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Profilbild',
                style: theme.primaryTextTheme.bodySmall,
              ),
            ),
            ListTile(
              leading: PhosphorIcon(
                PhosphorIconsRegular.camera,
                color: theme.primaryIconTheme.color,
              ),
              title: Text('Foto aufnehmen',
                  style: theme.primaryTextTheme.titleSmall),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickAndUpload(ImageSource.camera);
              },
            ),
            ListTile(
              leading: PhosphorIcon(
                PhosphorIconsRegular.image,
                color: theme.primaryIconTheme.color,
              ),
              title: Text('Aus Galerie wählen',
                  style: theme.primaryTextTheme.titleSmall),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickAndUpload(ImageSource.gallery);
              },
            ),
            if (hasAvatar)
              ListTile(
                leading: PhosphorIcon(
                  PhosphorIconsRegular.trash,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Profilbild entfernen',
                  style: theme.primaryTextTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _removeAvatar();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Picks an image and uploads it.
  ///
  /// The picker already downscales and re-compresses on the device: it keeps
  /// the request small on a mobile connection, and a 12 MP photo would
  /// otherwise be sent in full only for the backend to shrink it to 512px.
  Future<void> _pickAndUpload(ImageSource source) async {
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } catch (e) {
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kein Zugriff auf Kamera oder Fotos. '
              'Du kannst das in den Systemeinstellungen erlauben.',
            ),
          ),
        );
      }
      return;
    }
    // the user backed out of the picker, nothing to report
    if (picked == null) {
      return;
    }

    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      await AvatarStore().setOwn(base64Encode(bytes));
      Haptics.tap();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profilbild aktualisiert.')),
        );
      }
    } catch (e) {
      Haptics.warning();
      await showBackendError(
        context,
        e,
        'Profilbild konnte nicht gespeichert werden',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeAvatar() async {
    final userId = _ownUser?.id;
    if (userId == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await AvatarStore().removeOwn(userId);
      Haptics.tap();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profilbild entfernt.')),
        );
      }
    } catch (e) {
      Haptics.warning();
      await showBackendError(
        context,
        e,
        'Profilbild konnte nicht entfernt werden',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------- password

  Future<void> _showChangePasswordDialog() async {
    final theme = Theme.of(context);
    String newPassword = '';
    String newPasswordConfirm = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Passwort ändern', style: theme.textTheme.titleMedium),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              final tooShort = newPassword.isNotEmpty && newPassword.length < 8;
              final mismatch = newPasswordConfirm.isNotEmpty &&
                  newPassword != newPasswordConfirm;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    obscureText: true,
                    autofocus: true,
                    style: theme.primaryTextTheme.bodySmall,
                    decoration: InputDecoration(
                      labelText: 'Neues Passwort',
                      labelStyle: theme.primaryTextTheme.bodySmall,
                      errorText: tooShort ? 'Mindestens 8 Zeichen' : null,
                    ),
                    onChanged: (value) =>
                        setDialogState(() => newPassword = value),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    obscureText: true,
                    style: theme.primaryTextTheme.bodySmall,
                    decoration: InputDecoration(
                      labelText: 'Passwort bestätigen',
                      labelStyle: theme.primaryTextTheme.bodySmall,
                      errorText:
                          mismatch ? 'Passwörter stimmen nicht überein' : null,
                    ),
                    onChanged: (value) =>
                        setDialogState(() => newPasswordConfirm = value),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () {
                if (newPassword.length < 8 ||
                    newPassword != newPasswordConfirm) {
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Bestätigen'),
            ),
          ],
        );
      },
    );

    if (confirmed ?? false) {
      await _changePassword(newPassword);
    }
  }

  Future<void> _changePassword(String password) async {
    setState(() => _busy = true);
    try {
      await Backend().changeOwnPassword(password);
      Haptics.tap();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwort erfolgreich geändert.')),
        );
      }
    } catch (e) {
      Haptics.warning();
      await showBackendError(
        context,
        e,
        'Passwort ändern fehlgeschlagen',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ----------------------------------------------------------------- privacy

  Future<void> _setActivityPrivacy(bool public) async {
    setState(() => _busy = true);
    try {
      await Backend().setActivityPrivacy(public);
      Haptics.tick();
      await _load();
    } catch (e) {
      await showBackendError(
        context,
        e,
        'Einstellung konnte nicht gespeichert werden',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------------ delete

  /// Two-step confirmation: the account and everything in it is gone for
  /// good, so a single mistap must not be enough.
  Future<void> _showDeleteAccountDialog() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Account löschen?', style: theme.textTheme.titleMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dein Account wird endgültig gelöscht. Alle deine Notizen, '
                'Aufgabenlisten und Aufgaben gehen dabei unwiderruflich '
                'verloren, und du wirst aus allen Gruppen entfernt.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Das kann nicht rückgängig gemacht werden.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Endgültig löschen',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed ?? false) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    try {
      await Backend().deleteOwnAccount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dein Account wurde gelöscht.')),
        );
      }
      // the account is gone, so there is no session left to log out of
      await deleteBoxAndNavigateToLogin(context);
    } catch (e) {
      // an expired session means the account is still there - the user has to
      // sign in again before they can delete it
      await showBackendError(
        context,
        e,
        'Account konnte nicht gelöscht werden',
      );
    }
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('Profil', style: theme.primaryTextTheme.titleMedium),
        backgroundColor: theme.scaffoldBackgroundColor,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
            color: theme.primaryIconTheme.color,
          ),
        ),
        actions: [
          // no group switcher here: the profile is about the account itself,
          // nothing on this screen depends on the active group
          OptionButton(
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: const AppDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _isLoading
              ? Skeletonizer(
                  effect: ShimmerEffect(
                    baseColor: theme.canvasColor,
                    duration: const Duration(seconds: 3),
                  ),
                  child: const SkeletonCard(),
                )
              : _buildDetails(theme),
        ),
      ),
    );
  }

  Widget _buildDetails(ThemeData theme) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildHeaderCard(theme),
        const SizedBox(height: 16),
        _buildAccountCard(theme),
        const SizedBox(height: 16),
        _buildPrivacyCard(theme),
        const SizedBox(height: 16),
        _buildSecurityCard(theme),
        const SizedBox(height: 24),
        _buildDangerCard(theme),
      ],
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
    final user = _ownUser;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildAvatar(theme, user?.id, user?.username),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.username ?? 'unbekannt',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'Keine E-Mail-Adresse hinterlegt',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The own picture with a camera badge, tapping it opens the picker sheet.
  ///
  /// The badge is what makes the avatar readable as a control - a bare circle
  /// with initials looks like decoration and nobody would try tapping it.
  Widget _buildAvatar(ThemeData theme, int? userId, String? username) {
    return Semantics(
      button: true,
      label: 'Profilbild ändern',
      child: InkWell(
        onTap: _busy ? null : _showAvatarSheet,
        customBorder: const CircleBorder(),
        child: Stack(
          children: [
            UserAvatarWidget(
              userId: userId,
              username: username,
              radius: 32,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                  // lifts the badge off a picture of any color
                  border: Border.all(color: theme.cardColor, width: 2),
                ),
                child: PhosphorIcon(
                  PhosphorIconsRegular.camera,
                  size: 12,
                  color: theme.brightness == Brightness.light
                      ? Colors.white
                      : Colors.grey[900],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(ThemeData theme) {
    final user = _ownUser;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(theme, 'Konto'),
            ListTile(
              leading: PhosphorIcon(
                PhosphorIconsRegular.identificationCard,
                color: theme.primaryIconTheme.color,
              ),
              title: Text('Benutzername', style: theme.textTheme.bodySmall),
              subtitle: Text(
                user?.username ?? 'unbekannt',
                style: theme.textTheme.titleSmall,
              ),
              trailing: PhosphorIcon(
                PhosphorIconsRegular.pencilSimple,
                color: theme.primaryIconTheme.color,
                size: 20,
              ),
              onTap: _busy ? null : _showChangeUsernameDialog,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              // display only: the address identifies the account and is what
              // the confirmation mail went to. TextFormField because it owns
              // its controller - a controller built here would leak on every
              // rebuild
              child: TextFormField(
                enabled: false,
                initialValue: user?.email ?? 'unbekannt',
                style: theme.primaryTextTheme.bodySmall,
                decoration: InputDecoration(
                  labelText: 'E-Mail-Adresse',
                  labelStyle: theme.primaryTextTheme.bodySmall,
                  helperText: 'Die E-Mail-Adresse kann nicht geändert werden.',
                  helperStyle: theme.primaryTextTheme.displayMedium,
                  prefixIcon: PhosphorIcon(
                    PhosphorIconsRegular.envelopeSimple,
                    color: theme.primaryIconTheme.color,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyCard(ThemeData theme) {
    final isPublic = _ownUser?.publicActivity ?? false;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(theme, 'Privatsphäre'),
            SwitchListTile(
              value: isPublic,
              onChanged: _busy ? null : _setActivityPrivacy,
              activeThumbColor: theme.primaryColor,
              secondary: PhosphorIcon(
                isPublic
                    ? PhosphorIconsRegular.eye
                    : PhosphorIconsRegular.eyeSlash,
                color: theme.primaryIconTheme.color,
              ),
              title: Text(
                'Aktivitäten teilen',
                style: theme.textTheme.titleSmall,
              ),
              subtitle: Text(
                isPublic
                    ? 'Andere sehen, wenn du Einträge erstellst, änderst oder löschst.'
                    : 'Deine Aktivitäten bleiben privat.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(theme, 'Sicherheit'),
            ListTile(
              leading: PhosphorIcon(
                PhosphorIconsRegular.password,
                color: theme.primaryIconTheme.color,
              ),
              title: Text('Passwort ändern', style: theme.textTheme.titleSmall),
              trailing: PhosphorIcon(
                PhosphorIconsRegular.caretRight,
                color: theme.primaryIconTheme.color,
                size: 18,
              ),
              onTap: _busy ? null : _showChangePasswordDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: PhosphorIcon(
                PhosphorIconsRegular.trash,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Account löschen',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Löscht dein Konto und alle deine Inhalte unwiderruflich.',
                style: theme.textTheme.bodySmall,
              ),
              onTap: _showDeleteAccountDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardTitle(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        label,
        style:
            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Rename dialog with the same availability dry run the registration uses, so
/// a taken name is called out before the user submits.
class _UsernameDialog extends StatefulWidget {
  final String currentUsername;

  const _UsernameDialog({required this.currentUsername});

  @override
  State<_UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<_UsernameDialog> {
  late final TextEditingController _controller;
  Timer? _debounce;

  /// null = unknown: empty, unchanged, still typing or the check failed
  bool? _available;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentUsername);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String get _value => _controller.text.trim();
  bool get _isUnchanged => _value == widget.currentUsername;
  bool get _canSubmit =>
      _value.isNotEmpty && !_isUnchanged && _available != false && !_checking;

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _available = null;
      _checking = false;
    });

    final username = value.trim();
    // the own name is of course "taken" - checking it would only ever say no
    if (username.isEmpty || username == widget.currentUsername) {
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _checking = true);
      try {
        final availability =
            await Backend().checkAvailability(username: username);
        if (!mounted || _controller.text.trim() != username) return;
        setState(() {
          _available = availability.usernameAvailable;
          _checking = false;
        });
      } catch (_) {
        // availability is only a hint, the backend decides on submit
        if (!mounted) return;
        setState(() => _checking = false);
      }
    });
  }

  Widget? _suffixIcon(ThemeData theme) {
    if (_checking) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_available == true) {
      return const Icon(Icons.check_circle_outline,
          size: 20, color: Colors.green);
    }
    if (_available == false) {
      return Icon(Icons.cancel_outlined,
          size: 20, color: theme.colorScheme.error);
    }
    return null;
  }

  String? get _helperText {
    if (_value.isEmpty) return null;
    if (_isUnchanged) return 'Das ist dein aktueller Benutzername.';
    if (_available == true) return 'Der Name ist frei.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('Benutzername ändern', style: theme.textTheme.titleMedium),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            style: theme.primaryTextTheme.bodySmall,
            decoration: InputDecoration(
              labelText: 'Benutzername',
              labelStyle: theme.primaryTextTheme.bodySmall,
              suffixIcon: _suffixIcon(theme),
              errorText:
                  _available == false ? 'Dieser Name ist schon vergeben' : null,
              helperText: _helperText,
              helperStyle: theme.primaryTextTheme.displayMedium,
            ),
            onChanged: _onChanged,
          ),
          const SizedBox(height: 12),
          Text(
            'Andere sehen diesen Namen an deinen Notizen und Aufgabenlisten. '
            'Du meldest dich damit auch an.',
            style: theme.primaryTextTheme.displayMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          onPressed:
              _canSubmit ? () => Navigator.of(context).pop(_value) : null,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
