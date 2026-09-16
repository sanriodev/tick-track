import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/models/group/group_api_model.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class GroupAddForm extends StatefulWidget {
  const GroupAddForm({
    super.key,
    required this.onGroupJoined,
    required this.onGroupCreated,
  });

  final ValueChanged<Group> onGroupJoined;
  final ValueChanged<Group> onGroupCreated;

  @override
  State<GroupAddForm> createState() => _GroupAddFormState();
}

class _GroupAddFormState extends State<GroupAddForm> {
  final _createFormKey = GlobalKey<FormState>();
  final _joinCodeController = TextEditingController();
  final _nameController = TextEditingController();

  bool _joining = false;
  bool _creating = false;

  @override
  void dispose() {
    _joinCodeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _joinGroup() async {
    final joinCode = _joinCodeController.text.trim().toUpperCase();
    if (joinCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.joinCodeRequired)),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _joining = true);

    try {
      final group = await Backend().joinGroup(joinCode);
      await GroupContext().refresh();
      await GroupContext().setActiveGroup(group);
      if (mounted) widget.onGroupJoined(group);
    } catch (e) {
      if (mounted) {
        await showBackendError(context, e, context.l10n.groupJoinFailed);
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _createGroup() async {
    final form = _createFormKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _creating = true);

    try {
      final group = await Backend().createGroup(_nameController.text.trim());
      await GroupContext().refresh();
      await GroupContext().setActiveGroup(group);
      if (mounted) widget.onGroupCreated(group);
    } catch (e) {
      if (mounted) {
        await showBackendError(
          context,
          e,
          context.l10n.groupCreateFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderIcon(theme),
        const SizedBox(height: 32),
        _buildJoinSection(theme),
        const SizedBox(height: 28),
        _buildSectionDivider(theme),
        const SizedBox(height: 28),
        _buildCreateSection(theme),
      ],
    );
  }

  Widget _buildHeaderIcon(ThemeData theme) {
    return Center(
      child: Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
        ),
        child: Center(
          child: PhosphorIcon(
            PhosphorIconsRegular.usersThree,
            size: 56,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildJoinSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          theme,
          title: context.l10n.groupJoin,
          text: context.l10n.groupJoinHint,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _joinCodeController,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          style: theme.primaryTextTheme.bodySmall?.copyWith(letterSpacing: 2),
          decoration: InputDecoration(
            labelText: context.l10n.joinCode,
            hintText: context.l10n.joinCodeHintExample,
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
        OutlinedButton.icon(
          onPressed: _joining ? null : _joinGroup,
          icon: _joining
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.login, color: theme.colorScheme.primary),
          label: Text(
            context.l10n.groupJoin,
            style: theme.primaryTextTheme.displayLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateSection(ThemeData theme) {
    return Form(
      key: _createFormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            theme,
            title: context.l10n.groupCreateTitle,
            text: context.l10n.groupCreateHint,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.done,
            style: theme.primaryTextTheme.bodySmall,
            decoration: InputDecoration(
              labelText: context.l10n.groupName,
              hintText: context.l10n.groupNameHint,
              labelStyle: theme.primaryTextTheme.bodySmall,
              hintStyle: theme.primaryTextTheme.bodySmall,
              prefixIcon: const Icon(Icons.group_outlined, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? context.l10n.groupNameRequired
                : null,
            onFieldSubmitted: (_) => _createGroup(),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _creating ? null : _createGroup,
            icon: _creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.add, color: theme.primaryIconTheme.color),
            label: Text(
              context.l10n.groupCreate,
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
      ),
    );
  }

  Widget _buildSectionHeader(
    ThemeData theme, {
    required String title,
    required String text,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: theme.primaryTextTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: theme.primaryTextTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSectionDivider(ThemeData theme) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child:
              Text(context.l10n.or, style: theme.primaryTextTheme.bodySmall),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
