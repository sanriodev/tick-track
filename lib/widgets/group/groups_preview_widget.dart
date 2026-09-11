import 'package:ticktrack/models/group/group_api_model.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class GroupsPreviewWidget extends StatelessWidget {
  const GroupsPreviewWidget({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  static const double _tabletBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GroupContext(),
      builder: (BuildContext context, Widget? child) {
        final theme = Theme.of(context);
        final accent = theme.primaryColor;
        final groupContext = GroupContext();
        final groups = groupContext.groups;
        final activeId = groupContext.activeGroup?.id;

        final width = MediaQuery.of(context).size.width;
        final isTablet = width > _tabletBreakpoint;
        final listHeight = isTablet ? 130.0 : 100.0;
        final itemWidth = isTablet ? width / 4.6 : width / 2.4;

        return Card(
          elevation: 2.0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: PhosphorIcon(
                            PhosphorIconsRegular.usersThree,
                            color: accent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Gruppen',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${groups.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(
                    'Du bist noch in keiner Gruppe.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ),
              SizedBox(
                height: listHeight,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: groups.length + 1,
                  itemBuilder: (BuildContext listContext, int index) {
                    if (index == groups.length) {
                      return _buildAddGroupCard(listContext, itemWidth);
                    }

                    final group = groups[index];
                    return _buildGroupCard(
                      listContext,
                      group,
                      isActive: group.id == activeId,
                      itemWidth: itemWidth,
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onPressed,
                  child: Text(
                    'Mehr anzeigen',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupCard(
    BuildContext context,
    Group group, {
    required bool isActive,
    required double itemWidth,
  }) {
    final theme = Theme.of(context);
    final accent = theme.primaryColor;

    return Semantics(
      button: true,
      selected: isActive,
      label: isActive
          ? 'Gruppe ${group.name}, aktuell ausgewählt'
          : 'Zu Gruppe ${group.name} wechseln',
      excludeSemantics: true,
      child: Container(
        width: itemWidth,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: isActive
              ? accent.withValues(alpha: 0.15)
              : theme.canvasColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: isActive ? accent : theme.dividerColor,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10.0),
            onTap: isActive
                ? null
                : () async {
                    Haptics.tick();
                    await GroupContext().setActiveGroup(group);
                  },
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PhosphorIcon(
                        isActive
                            ? PhosphorIconsFill.checkCircle
                            : PhosphorIconsRegular.usersThree,
                        size: 18,
                        color:
                            isActive ? accent : theme.primaryIconTheme.color,
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Aktiv',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  Text(
                    group.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (group.members.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      group.members.length == 1
                          ? '1 Mitglied'
                          : '${group.members.length} Mitglieder',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddGroupCard(BuildContext context, double itemWidth) {
    final theme = Theme.of(context);
    final accent = theme.primaryColor;

    return Semantics(
      button: true,
      label: 'Neue Gruppe hinzufügen',
      excludeSemantics: true,
      child: Container(
        width: itemWidth,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10.0),
            onTap: () {
              Haptics.tap();
              navigateToRoute(context, 'group-add', backEnabled: true);
            },
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PhosphorIcon(
                    PhosphorIconsRegular.plusCircle,
                    size: 24,
                    color: accent,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Neue Gruppe hinzufügen',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
