// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/state/cache_store.dart';
import 'package:ticktrack/state/avatar_store.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/widgets/app_options_sheet.dart';
import 'package:ticktrack/widgets/option_button.dart';
import 'package:ticktrack/widgets/skeleton/skeleton_card.dart';
import 'package:ticktrack/widgets/user_avatar_widget.dart';
import 'package:blvckleg_dart_core/models/user/user_model.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const routeName = '/profile';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _busy = false;
  User? _ownUser;

  bool get _mfaEnabled => _ownUser?.mfaEnabled ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = CacheStore().readItem(CacheKey.ownUser(), User.fromJson);
    if (cached != null) {
      _showUser(cached.item);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final user = await AuthBackend().getOwnUser();
      await CacheStore().writeItem(CacheKey.ownUser(), user);
      _showUser(user);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      await showBackendError(context, e, context.l10n.profileLoadFailed,
          alertWhenOffline: false);
    }
  }

  void _showUser(User user) {
    if (!mounted) {
      return;
    }
    setState(() {
      _ownUser = user;
      _isLoading = false;
    });
  }

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
      await applyRenamedUsername(stored);
      Haptics.tap();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.usernameChanged(stored))),
        );
      }
      await _load();
    } catch (e) {
      Haptics.warning();
      await showBackendError(
        context,
        e,
        context.l10n.usernameChangeFailed,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showAvatarSheet() async {
    final theme = Theme.of(context);
    final userId = _ownUser?.id;
    final hasAvatar = userId != null && AvatarStore().bytesFor(userId) != null;

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
                context.l10n.avatar,
                style: theme.primaryTextTheme.bodySmall,
              ),
            ),
            ListTile(
              leading: PhosphorIcon(
                PhosphorIconsRegular.camera,
                color: theme.primaryIconTheme.color,
              ),
              title: Text(context.l10n.imageTakePhoto,
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
              title: Text(context.l10n.imagePickFromGallery,
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
                  context.l10n.avatarRemove,
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
          SnackBar(content: Text(context.l10n.imagePermissionDenied)),
        );
      }
      return;
    }
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
          SnackBar(content: Text(context.l10n.avatarUpdated)),
        );
      }
    } catch (e) {
      Haptics.warning();
      await showBackendError(
        context,
        e,
        context.l10n.avatarSaveFailed,
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
          SnackBar(content: Text(context.l10n.avatarRemoved)),
        );
      }
    } catch (e) {
      Haptics.warning();
      await showBackendError(
        context,
        e,
        context.l10n.avatarRemoveFailed,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final theme = Theme.of(context);
    String newPassword = '';
    String newPasswordConfirm = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title:
              Text(context.l10n.passwordChange, style: theme.textTheme.titleMedium),
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
                      labelText: context.l10n.passwordNew,
                      labelStyle: theme.primaryTextTheme.bodySmall,
                      errorText:
                          tooShort ? context.l10n.passwordMinLength : null,
                    ),
                    onChanged: (value) =>
                        setDialogState(() => newPassword = value),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    obscureText: true,
                    style: theme.primaryTextTheme.bodySmall,
                    decoration: InputDecoration(
                      labelText: context.l10n.passwordConfirm,
                      labelStyle: theme.primaryTextTheme.bodySmall,
                      errorText:
                          mismatch ? context.l10n.passwordMismatch : null,
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
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                if (newPassword.length < 8 ||
                    newPassword != newPasswordConfirm) {
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(context.l10n.confirm),
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
          SnackBar(content: Text(context.l10n.passwordChanged)),
        );
      }
    } catch (e) {
      Haptics.warning();
      await showBackendError(
        context,
        e,
        context.l10n.passwordChangeFailed,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMfaSettings() async {
    await navigateToRoute(context, 'mfa', backEnabled: true);
    await _load();
  }

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
        context.l10n.settingSaveFailed,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.accountDeleteTitle,
              style: theme.textTheme.titleMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.accountDeleteMessage,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.accountDeleteWarning,
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
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                context.l10n.accountDeleteConfirm,
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
          SnackBar(content: Text(context.l10n.accountDeleted)),
        );
      }
      await deleteBoxAndNavigateToLogin(context);
    } catch (e) {
      await showBackendError(
        context,
        e,
        context.l10n.accountDeleteFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.profile, style: theme.primaryTextTheme.titleMedium),
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
          OptionButton(
            onPressed: () => showAppOptionsSheet(context),
          ),
        ],
      ),
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
                    user?.username ?? context.l10n.unknown,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? context.l10n.noEmailOnFile,
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

  Widget _buildAvatar(ThemeData theme, int? userId, String? username) {
    return Semantics(
      button: true,
      label: context.l10n.avatarChange,
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
            _cardTitle(theme, context.l10n.account),
            ListTile(
              leading: PhosphorIcon(
                PhosphorIconsRegular.identificationCard,
                color: theme.primaryIconTheme.color,
              ),
              title: Text(context.l10n.username, style: theme.textTheme.bodySmall),
              subtitle: Text(
                user?.username ?? context.l10n.unknown,
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
              child: TextFormField(
                enabled: false,
                initialValue: user?.email ?? context.l10n.unknown,
                style: theme.primaryTextTheme.bodySmall,
                decoration: InputDecoration(
                  labelText: context.l10n.email,
                  labelStyle: theme.primaryTextTheme.bodySmall,
                  helperText: context.l10n.emailNotChangeable,
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
            _cardTitle(theme, context.l10n.privacy),
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
                context.l10n.shareActivity,
                style: theme.textTheme.titleSmall,
              ),
              subtitle: Text(
                isPublic
                    ? context.l10n.shareActivityOn
                    : context.l10n.shareActivityOff,
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
            _cardTitle(theme, context.l10n.security),
            ListTile(
              leading: PhosphorIcon(
                PhosphorIconsRegular.password,
                color: theme.primaryIconTheme.color,
              ),
              title:
                  Text(context.l10n.passwordChange, style: theme.textTheme.titleSmall),
              trailing: PhosphorIcon(
                PhosphorIconsRegular.caretRight,
                color: theme.primaryIconTheme.color,
                size: 18,
              ),
              onTap: _busy ? null : _showChangePasswordDialog,
            ),
            ListTile(
              leading: PhosphorIcon(
                _mfaEnabled
                    ? PhosphorIconsRegular.shieldCheck
                    : PhosphorIconsRegular.shieldWarning,
                color: theme.primaryIconTheme.color,
              ),
              title: Text(
                context.l10n.mfaTitle,
                style: theme.textTheme.titleSmall,
              ),
              subtitle: Text(
                _mfaEnabled
                    ? context.l10n.mfaEnabledSubtitle
                    : context.l10n.mfaDisabledSubtitle,
                style: theme.textTheme.bodySmall,
              ),
              trailing: PhosphorIcon(
                PhosphorIconsRegular.caretRight,
                color: theme.primaryIconTheme.color,
                size: 18,
              ),
              onTap: _busy ? null : _openMfaSettings,
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
                context.l10n.accountDelete,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                context.l10n.accountDeleteSubtitle,
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

class _UsernameDialog extends StatefulWidget {
  final String currentUsername;

  const _UsernameDialog({required this.currentUsername});

  @override
  State<_UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<_UsernameDialog> {
  late final TextEditingController _controller;
  Timer? _debounce;

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
    if (_isUnchanged) return context.l10n.usernameCurrentHint;
    if (_available == true) return context.l10n.usernameAvailable;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title:
          Text(context.l10n.usernameChange, style: theme.textTheme.titleMedium),
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
              labelText: context.l10n.username,
              labelStyle: theme.primaryTextTheme.bodySmall,
              suffixIcon: _suffixIcon(theme),
              errorText:
                  _available == false ? context.l10n.usernameTaken : null,
              helperText: _helperText,
              helperStyle: theme.primaryTextTheme.displayMedium,
            ),
            onChanged: _onChanged,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.usernameHint,
            style: theme.primaryTextTheme.displayMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed:
              _canSubmit ? () => Navigator.of(context).pop(_value) : null,
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}
