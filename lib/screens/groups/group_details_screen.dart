// ignore_for_file: use_build_context_synchronously

import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/models/block/blocked_user_model.dart';
import 'package:ticktrack/models/group/group_api_model.dart';
import 'package:ticktrack/state/avatar_store.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/widgets/app_options_sheet.dart';
import 'package:ticktrack/widgets/group/group_context_switcher.dart';
import 'package:ticktrack/widgets/option_button.dart';
import 'package:ticktrack/widgets/skeleton/skeleton_card.dart';
import 'package:ticktrack/widgets/user_avatar_widget.dart';
import 'package:blvckleg_dart_core/models/user/user_model.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:skeletonizer/skeletonizer.dart';

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
  List<BlockedUser> _blocked = [];

  bool get _isOwner =>
      _ownUser != null &&
      _group?.ownerId != null &&
      _group!.ownerId == _ownUser!.id;

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
      final group = await Backend().getGroup(activeGroup.id);
      final ownUser = _ownUser ?? await AuthBackend().getOwnUser();
      final blocked = await Backend().getBlockedUsers();
      if (!mounted) return;
      setState(() {
        _group = group;
        _ownUser = ownUser;
        _blocked = blocked;
        _isLoading = false;
      });
      AvatarStore().sync(group.members.map((member) => member.id));
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      await showBackendError(context, e, context.l10n.groupLoadFailed);
    }
  }

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
              child: Text(context.l10n.cancel),
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
        SnackBar(content: Text(context.l10n.groupTransferFirst)),
      );
      return;
    }

    final confirmed = await _confirm(
      title: context.l10n.groupLeaveTitle,
      content: Text(
        isLastMember
            ? context.l10n.groupLeaveLastMember(group.name)
            : context.l10n.groupLeaveConfirm(group.name),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      confirmLabel: context.l10n.leave,
      destructive: true,
    );
    if (!confirmed) return;

    await _run(
      () => Backend().leaveGroup(group.id),
      context.l10n.groupLeaveFailed,
    );
  }

  Future<void> _transferOwnership(User member) async {
    final group = _group;
    if (group == null) return;

    final confirmed = await _confirm(
      title: context.l10n.groupTransferTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.groupTransferMessage(member.username, group.name),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.groupTransferWarning,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
      confirmLabel: context.l10n.transfer,
    );
    if (!confirmed) return;

    await _run(
      () => Backend()
          .transferGroupOwnership(group.id, member.id)
          .then((_) => null),
      context.l10n.groupTransferFailed,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.groupTransferDone(member.username)),
        ),
      );
    }
  }

  Future<void> _removeMember(User member) async {
    final group = _group;
    if (group == null) return;

    final confirmed = await _confirm(
      title: context.l10n.groupRemoveMemberTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.groupRemoveMemberMessage(
                member.username, group.name),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.groupRemoveMemberWarning(member.username),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        ],
      ),
      confirmLabel: context.l10n.remove,
      destructive: true,
    );
    if (!confirmed) return;

    await _run(
      () => Backend().removeGroupMember(group.id, member.id).then((_) => null),
      context.l10n.groupRemoveMemberFailed,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.groupRemoveMemberDone(member.username))),
      );
    }
  }

  Future<void> _blockMember(User member) async {
    final theme = Theme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.blockUserTitle,
              style: theme.textTheme.titleMedium),
          content: Text(
            context.l10n.blockUserMessage(member.username),
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                context.l10n.block,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    await _run(
      () => Backend().blockUser(member.id),
      context.l10n.blockUserFailed,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.blockUserDone(member.username))),
      );
    }
  }

  Future<void> _unblockUser(BlockedUser blocked) async {
    await _run(
      () => Backend().unblockUser(blocked.id),
      context.l10n.unblockFailed,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.unblockDone(blocked.username)),
        ),
      );
    }
  }

  Future<void> _unblockMember(User member) async {
    await _run(
      () => Backend().unblockUser(member.id),
      context.l10n.unblockFailed,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.unblockDone(member.username)),
        ),
      );
    }
  }

  Future<void> _openAddGroup() async {
    await navigateToRoute(context, 'group-add', backEnabled: true);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title:
            Text(context.l10n.groupDetails, style: theme.primaryTextTheme.titleMedium),
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
          const GroupContextSwitcher(),
          OptionButton(
            onPressed: () {
              showAppOptionsSheet(context);
            },
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
          context.l10n.groupNone,
          style: theme.primaryTextTheme.displayLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _openAddGroup,
          icon: Icon(Icons.add, color: theme.primaryIconTheme.color),
          label: Text(
            context.l10n.groupAdd,
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
        if (_blocked.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildBlockedCard(theme),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _busy ? null : _openAddGroup,
          icon: Icon(Icons.add, color: theme.colorScheme.primary),
          label: Text(
            context.l10n.groupAddAnother,
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
            context.l10n.groupLeave,
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
              context.l10n.groupOwnerMustTransfer,
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
                    context.l10n.memberCount(group.members.length),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    owner == null
                        ? context.l10n.groupNoOwner
                        : _isOwner
                            ? context.l10n.groupOwnerIsYou(owner.username)
                            : context.l10n.groupOwnerIs(owner.username),
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
                context.l10n.members,
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
    final isBlocked = _blocked.any((b) => b.id == member.id);
    final canManage = _isOwner && !isSelf;
    final showMenu = !isSelf;

    return ListTile(
      leading: UserAvatarWidget(
        userId: member.id,
        username: member.username,
        borderColor: isGroupOwner ? theme.primaryColor : null,
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
              child: Text(context.l10n.you, style: theme.textTheme.labelSmall),
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
                  context.l10n.owner,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
            )
          : null,
      trailing: showMenu
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
                } else if (value == 'block') {
                  _blockMember(member);
                } else if (value == 'unblock') {
                  _unblockMember(member);
                }
              },
              itemBuilder: (BuildContext menuContext) => [
                if (canManage)
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
                          context.l10n.makeOwner,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                if (isBlocked)
                  PopupMenuItem(
                    value: 'unblock',
                    child: Row(
                      children: [
                        PhosphorIcon(
                          PhosphorIconsRegular.check,
                          size: 18,
                          color: theme.primaryIconTheme.color,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          context.l10n.unblock,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                else
                  PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        PhosphorIcon(
                          PhosphorIconsRegular.prohibit,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          context.l10n.blockUser,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.error),
                        ),
                      ],
                    ),
                  ),
                if (canManage)
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
                          context.l10n.removeFromGroup,
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

  Widget _buildBlockedCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                context.l10n.blockedUsers,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                context.l10n.blockedUsersHint,
                style: theme.textTheme.bodySmall,
              ),
            ),
            for (final blocked in _blocked)
              ListTile(
                leading: PhosphorIcon(
                  PhosphorIconsRegular.prohibit,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  blocked.username,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: TextButton(
                  onPressed: _busy ? null : () => _unblockUser(blocked),
                  child: Text(
                    context.l10n.unblockShort,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
              context.l10n.joinCode,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.joinCodeHint,
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
                  tooltip: context.l10n.copyCode,
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
                      SnackBar(content: Text(context.l10n.joinCodeCopied)),
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
