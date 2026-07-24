// ignore_for_file: use_build_context_synchronously

import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/models/group/group_api_model.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/widgets/group/group_context_switcher.dart';
import 'package:ticktrack/widgets/skeleton/skeleton_card.dart';
import 'package:blvckleg_dart_core/models/user/user_model.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Overview of the active group: members, owner, invite code and everything
/// one can do with the group. Follows the active group context, so switching
/// the group in the app bar reloads the whole page.
class GroupDetailsScreen extends StatefulWidget {
  const GroupDetailsScreen({super.key});

  static const routeName = '/group-details';

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  bool _isLoading = true;
  bool _busy = false;
  Group? _group;
  User? _ownUser;

  bool get _isOwner =>
      _ownUser != null && _group?.ownerId != null && _group!.ownerId == _ownUser!.id;

  @override
  void initState() {
    super.initState();
    GroupContext().addListener(_onGroupContextChanged);
    _load();
  }

  @override
  void dispose() {
    GroupContext().removeListener(_onGroupContextChanged);
    super.dispose();
  }

  void _onGroupContextChanged() {
    if (mounted) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final activeGroup = GroupContext().activeGroup;
    if (activeGroup == null) {
      setState(() {
        _group = null;
        _isLoading = false;
      });
      return;
    }

    try {
      // the group list comes without members, the detail endpoint has them
      final group = await Backend().getGroup(activeGroup.id);
      final ownUser = _ownUser ?? await AuthBackend().getOwnUser();
      if (!mounted) return;
      setState(() {
        _group = group;
        _ownUser = ownUser;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      await showBackendError(context, e, 'Gruppe konnte nicht geladen werden');
    }
  }

  /// Runs a group action and reloads both the context and this page.
  Future<void> _run(
    Future<void> Function() action,
    String errorMessage,
  ) async {
    setState(() => _busy = true);
    try {
      await action();
      await GroupContext().refresh();
      if (!GroupContext().hasGroups) {
        navigateToRoute(context, 'group-onboarding');
        return;
      }
      await _load();
    } catch (e) {
      await showBackendError(context, e, errorMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required Widget content,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title, style: theme.textTheme.titleMedium),
          content: content,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                confirmLabel,
                style: destructive
                    ? TextStyle(color: theme.colorScheme.error)
                    : null,
              ),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _leaveGroup() async {
    final group = _group;
    if (group == null) return;

    final isLastMember = group.members.length <= 1;
    if (_isOwner && !isLastMember) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Übertrage zuerst den Gruppenbesitz an ein anderes Mitglied.',
          ),
        ),
      );
      return;
    }

    final confirmed = await _confirm(
      title: 'Gruppe verlassen?',
      content: Text(
        isLastMember
            ? 'Du bist das letzte Mitglied - die Gruppe "${group.name}" wird '
                'dadurch gelöscht. Alle Einträge dieser Gruppe gehen verloren.'
            : 'Möchtest du die Gruppe "${group.name}" wirklich verlassen? '
                'Du verlierst den Zugriff auf alle Einträge dieser Gruppe.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      confirmLabel: 'Verlassen',
      destructive: true,
    );
    if (!confirmed) return;

    await _run(
      () => Backend().leaveGroup(group.id),
      'Gruppe konnte nicht verlassen werden',
    );
  }

  Future<void> _transferOwnership(User member) async {
    final group = _group;
    if (group == null) return;

    final confirmed = await _confirm(
      title: 'Besitz übertragen?',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${member.username}" wird neuer Besitzer der Gruppe '
            '"${group.name}".',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Du gibst damit deine Besitzerrechte ab und kannst danach keine '
            'Mitglieder mehr entfernen oder den Besitz weitergeben.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
      confirmLabel: 'Übertragen',
    );
    if (!confirmed) return;

    await _run(
      () => Backend()
          .transferGroupOwnership(group.id, member.id)
          .then((_) => null),
      'Besitz konnte nicht übertragen werden',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${member.username}" ist jetzt Gruppenbesitzer.'),
        ),
      );
    }
  }

  Future<void> _removeMember(User member) async {
    final group = _group;
    if (group == null) return;

    final confirmed = await _confirm(
      title: 'Mitglied entfernen?',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${member.username}" wird aus der Gruppe "${group.name}" '
            'entfernt.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Alle Notizen, Aufgabenlisten und Aufgaben, die "${member.username}" '
            'in dieser Gruppe erstellt hat, werden dabei unwiderruflich '
            'gelöscht.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        ],
      ),
      confirmLabel: 'Entfernen',
      destructive: true,
    );
    if (!confirmed) return;

    await _run(
      () => Backend().removeGroupMember(group.id, member.id).then((_) => null),
      'Mitglied konnte nicht entfernt werden',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${member.username}" wurde entfernt.')),
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
      await _load();
    } catch (e) {
      await showBackendError(context, e, 'Beitritt fehlgeschlagen');
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
            style: theme.textTheme.titleMedium,
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
                  const SizedBox(height: 16),
                  TextFormField(
                    textCapitalization: TextCapitalization.characters,
                    style: theme.primaryTextTheme.bodySmall?.copyWith(
                      letterSpacing: 2,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Einladungscode',
                      labelStyle: theme.primaryTextTheme.bodySmall,
                      hintStyle: theme.primaryTextTheme.bodySmall,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        joinCode = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      navigateToRoute(context, 'group-create',
                          backEnabled: true);
                    },
                    icon: Icon(Icons.add, color: theme.colorScheme.primary),
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
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () async {
                final code = joinCode.trim().toUpperCase();
                if (code.isEmpty) return;
                Navigator.of(dialogContext).pop();
                await _joinGroup(code);
              },
              child: const Text('Beitreten'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Gruppendetails', style: theme.primaryTextTheme.titleMedium),
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
        actions: const [GroupContextSwitcher()],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.primaryColor,
          backgroundColor: theme.secondaryHeaderColor,
          onRefresh: _load,
          child: _isLoading
              ? Skeletonizer(
                  effect: ShimmerEffect(
                    baseColor: theme.canvasColor,
                    duration: const Duration(seconds: 3),
                  ),
                  child: const SkeletonCard(),
                )
              : _group == null
                  ? _buildNoGroup(theme)
                  : _buildDetails(theme, _group!),
        ),
      ),
    );
  }

  Widget _buildNoGroup(ThemeData theme) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        PhosphorIcon(
          PhosphorIconsRegular.usersThree,
          size: 72,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Du bist in keiner Gruppe.',
          style: theme.primaryTextTheme.displayLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _showAddGroupDialogue,
          icon: Icon(Icons.add, color: theme.primaryIconTheme.color),
          label: Text(
            'Gruppe hinzufügen',
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
      ],
    );
  }

  Widget _buildDetails(ThemeData theme, Group group) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildHeaderCard(theme, group),
        const SizedBox(height: 16),
        _buildMembersCard(theme, group),
        const SizedBox(height: 16),
        _buildJoinCodeCard(theme, group),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _busy ? null : _showAddGroupDialogue,
          icon: Icon(Icons.add, color: theme.colorScheme.primary),
          label: Text(
            'Weitere Gruppe hinzufügen',
            style: theme.primaryTextTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _leaveGroup,
          icon: PhosphorIcon(
            PhosphorIconsRegular.signOut,
            color: theme.colorScheme.error,
          ),
          label: Text(
            'Gruppe verlassen',
            style: theme.primaryTextTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: BorderSide(color: theme.colorScheme.error),
          ),
        ),
        if (_isOwner && group.members.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Als Besitzer musst du den Gruppenbesitz übertragen, bevor du '
              'die Gruppe verlassen kannst.',
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderCard(ThemeData theme, Group group) {
    final owner = group.members.where((m) => m.id == group.ownerId).firstOrNull;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: PhosphorIcon(
                PhosphorIconsRegular.usersThree,
                color: theme.primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${group.members.length} '
                    '${group.members.length == 1 ? 'Mitglied' : 'Mitglieder'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    owner != null
                        ? 'Besitzer: ${owner.username}'
                            '${_isOwner ? ' (du)' : ''}'
                        : 'Kein Besitzer',
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

  Widget _buildMembersCard(ThemeData theme, Group group) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Mitglieder',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            for (final member in group.members)
              _buildMemberTile(theme, group, member),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(ThemeData theme, Group group, User member) {
    final isSelf = member.id == _ownUser?.id;
    final isGroupOwner = member.id == group.ownerId;
    // the owner manages everyone but themselves
    final canManage = _isOwner && !isSelf;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Text(
          member.username.isNotEmpty
              ? member.username.substring(0, 1).toUpperCase()
              : '?',
          style: theme.textTheme.bodyMedium,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              member.username,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isSelf)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text('(du)', style: theme.textTheme.labelSmall),
            ),
        ],
      ),
      subtitle: isGroupOwner
          ? Row(
              children: [
                PhosphorIcon(
                  PhosphorIconsFill.crown,
                  size: 12,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Besitzer',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
            )
          : null,
      trailing: canManage
          ? PopupMenuButton<String>(
              enabled: !_busy,
              icon: PhosphorIcon(
                PhosphorIconsRegular.dotsThreeVertical,
                color: theme.primaryIconTheme.color,
              ),
              onSelected: (value) {
                if (value == 'transfer') {
                  _transferOwnership(member);
                } else if (value == 'remove') {
                  _removeMember(member);
                }
              },
              itemBuilder: (BuildContext menuContext) => [
                PopupMenuItem(
                  value: 'transfer',
                  child: Row(
                    children: [
                      PhosphorIcon(
                        PhosphorIconsRegular.crown,
                        size: 18,
                        color: theme.primaryIconTheme.color,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Zum Besitzer machen',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      PhosphorIcon(
                        PhosphorIconsRegular.userMinus,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Aus Gruppe entfernen',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildJoinCodeCard(ThemeData theme, Group group) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Einladungscode',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Mit diesem Code können andere der Gruppe beitreten.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.canvasColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: SelectableText(
                      group.joinCode,
                      style: theme.primaryTextTheme.titleMedium?.copyWith(
                        letterSpacing: 4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Einladungscode kopiert.')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
