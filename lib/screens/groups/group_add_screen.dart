import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/models/group/group_api_model.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/widgets/group/group_add_form.dart';
import 'package:ticktrack/widgets/group/group_created_success.dart';
import 'package:flutter/material.dart';

class GroupAddScreen extends StatefulWidget {
  const GroupAddScreen({super.key});

  @override
  State<GroupAddScreen> createState() => _GroupAddScreenState();
}

class _GroupAddScreenState extends State<GroupAddScreen> {
  Group? _createdGroup;

  void _showCreatedGroup(Group group) {
    setState(() => _createdGroup = group);
  }

  void _goHomeAfterJoin(Group group) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.groupJoined(group.name))),
    );
    navigateToRoute(context, 'home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = _createdGroup;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.groupAdd,
          style: theme.primaryTextTheme.titleMedium,
        ),
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
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
        ),
      ),
    );
  }
}
