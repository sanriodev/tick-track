import 'package:ticktrack/models/group/group_api_model.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// App bar field to switch the active group context. Only visible when the
/// logged in user is a member of more than one group.
class GroupContextSwitcher extends StatelessWidget {
  const GroupContextSwitcher({super.key});

  Future<void> _showGroupPicker(BuildContext context) async {
    final groupContext = GroupContext();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).canvasColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Gruppe wechseln',
                  style: Theme.of(context).primaryTextTheme.titleSmall,
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: groupContext.groups.length,
                  itemBuilder: (BuildContext listContext, int index) {
                    final group = groupContext.groups[index];
                    final isActive =
                        group.id == groupContext.activeGroup?.id;
                    return ListTile(
                      leading: PhosphorIcon(
                        isActive
                            ? PhosphorIconsFill.checkCircle
                            : PhosphorIconsRegular.usersThree,
                        color: isActive
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).primaryIconTheme.color,
                      ),
                      title: Text(
                        group.name,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: IconButton(
                        tooltip: 'Einladungscode kopieren',
                        icon: PhosphorIcon(
                          PhosphorIconsRegular.copy,
                          size: 20,
                          color: Theme.of(context).primaryIconTheme.color,
                        ),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: group.joinCode),
                          );
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Einladungscode "${group.joinCode}" kopiert.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      onTap: () async {
                        await _switchGroup(group);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _switchGroup(Group group) async {
    await GroupContext().setActiveGroup(group);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GroupContext(),
      builder: (BuildContext context, Widget? child) {
        final groupContext = GroupContext();
        if (!groupContext.hasMultipleGroups) {
          return const SizedBox.shrink();
        }
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              backgroundColor: Theme.of(context).canvasColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              _showGroupPicker(context);
            },
            icon: PhosphorIcon(
              PhosphorIconsRegular.usersThree,
              size: 18,
              color: Theme.of(context).primaryIconTheme.color,
            ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Text(
                    groupContext.activeGroup?.name ?? 'Gruppe',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                PhosphorIcon(
                  PhosphorIconsRegular.caretDown,
                  size: 14,
                  color: Theme.of(context).primaryIconTheme.color,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
