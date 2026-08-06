import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/models/tasklist/task_list_api_model.dart';
import 'package:ticktrack/state/pin_store.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/report_helper.dart';
import 'package:ticktrack/widgets/accordion/accordion_section.dart';
import 'package:ticktrack/widgets/accordion/task_list_accordion.dart';
import 'package:ticktrack/widgets/content_meta_footer.dart';
import 'package:ticktrack/widgets/privacy_mode_button.dart';
import 'package:ticktrack/widgets/slidable_underlay.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class TaskListWidget extends StatefulWidget {
  final int totalTasks;
  final int completedTasks;
  final int openTasks;
  final TaskList taskList;
  final void Function()? onTap;
  final void Function()? onDeletePress;
  final void Function(PrivacyMode mode)? onChangePrivacy;

  final void Function()? onBlocked;

  const TaskListWidget({
    super.key,
    required this.taskList,
    required this.totalTasks,
    required this.completedTasks,
    required this.openTasks,
    this.onDeletePress,
    this.onTap,
    this.onChangePrivacy,
    this.onBlocked,
  });

  @override
  State<TaskListWidget> createState() => _TaskListWidgetState();
}

class _TaskListWidgetState extends State<TaskListWidget>
    with SingleTickerProviderStateMixin {
  late final SlidableController _slidableController;

  @override
  void initState() {
    super.initState();
    _slidableController = SlidableController(this);
  }

  @override
  void dispose() {
    _slidableController.dispose();
    super.dispose();
  }

  bool get _isOwnList =>
      widget.taskList.user?.username ==
      AuthBackend().loggedInUser?.user?.username;

  bool get _isPinned =>
      PinStore().isPinned(PinStore.taskListKind, widget.taskList.id);

  double get _progress =>
      widget.totalTasks == 0 ? 0 : widget.completedTasks / widget.totalTasks;

  Future<void> _togglePin() async {
    Haptics.tick();
    await PinStore().toggle(PinStore.taskListKind, widget.taskList.id);
  }

  Color _headerForeground(ThemeData theme) =>
      theme.brightness == Brightness.light ? Colors.white : Colors.grey[900]!;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerFg = _headerForeground(theme);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          SlidableUnderlay(
            controller: _slidableController,
            startColor: theme.canvasColor,
            endColor: Colors.red,
          ),
          Slidable(
            key: ValueKey(widget.taskList.id),
            controller: _slidableController,
            startActionPane: ActionPane(
              motion: BehindMotion(),
              extentRatio: 0.3,
              children: [
                SlidableAction(
                  borderRadius: slidableStartOuterRadius,
                  onPressed: (_) => _togglePin(),
                  backgroundColor: theme.canvasColor,
                  foregroundColor: theme.primaryIconTheme.color,
                  icon: _isPinned
                      ? PhosphorIconsFill.pushPin
                      : PhosphorIconsRegular.pushPin,
                  label: _isPinned ? 'Loslösen' : 'Anpinnen',
                ),
              ],
            ),
            endActionPane: ActionPane(
              motion: BehindMotion(),
              extentRatio: 0.3,
              children: [
                if (_isOwnList)
                  SlidableAction(
                    borderRadius: slidableEndOuterRadius,
                    onPressed: (_) {
                      Haptics.warning();
                      widget.onDeletePress?.call();
                    },
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    icon: Icons.delete,
                  )
                else
                  SlidableAction(
                    borderRadius: slidableEndOuterRadius,
                    onPressed: (_) => showReportContentDialog(
                      context,
                      entityType: 'task_list',
                      entityId: widget.taskList.id,
                      entityLabel: 'Aufgabenliste',
                      authorId: widget.taskList.user?.id,
                      authorName: widget.taskList.user?.username,
                      onBlocked: widget.onBlocked,
                    ),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    icon: Icons.flag,
                    label: 'Melden',
                  ),
              ],
            ),
            child: TaskListAccordion(
              children: [
                TaskListAccordionSection(
                  headerBackgroundColor: theme.secondaryHeaderColor,
                  isOpen: false,
                  header: _buildHeader(theme, headerFg),
                  content: _buildContent(theme),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color headerFg) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.taskList.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.primaryTextTheme.labelLarge?.copyWith(
                      color: headerFg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        widget.totalTasks == 0
                            ? 'Noch keine Einträge'
                            : '${widget.completedTasks} von ${widget.totalTasks} erledigt',
                        style: theme.primaryTextTheme.displayMedium
                            ?.copyWith(color: headerFg.withValues(alpha: 0.85)),
                      ),
                      if (widget.totalTasks > 0) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _progress,
                              minHeight: 5,
                              backgroundColor: headerFg.withValues(alpha: 0.25),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(headerFg),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isPinned)
            IconButton(
              tooltip: 'Angepinnt - tippen zum Loslösen',
              onPressed: _togglePin,
              visualDensity: VisualDensity.compact,
              icon: PhosphorIcon(
                PhosphorIconsFill.pushPin,
                size: 18,
                color: headerFg,
              ),
            ),
          PrivacyModeButton(
            mode: widget.taskList.privacyMode,
            enabled: _isOwnList,
            color: headerFg,
            onChanged: widget.onChangePrivacy,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatChip(
                  color: theme.primaryColor,
                  label: 'Gesamt',
                  value: widget.totalTasks,
                ),
                const SizedBox(width: 18),
                _StatChip(
                  color: Colors.green,
                  label: 'Erledigt',
                  value: widget.completedTasks,
                ),
                const SizedBox(width: 18),
                _StatChip(
                  color: Colors.red,
                  label: 'Offen',
                  value: widget.openTasks,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ContentMetaFooter(
              author: widget.taskList.user,
              lastModifiedUser: widget.taskList.lastModifiedUser,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Einträge öffnen',
                  style: theme.primaryTextTheme.displaySmall,
                ),
                const SizedBox(width: 4),
                PhosphorIcon(
                  PhosphorIconsRegular.arrowRight,
                  size: 15,
                  color: theme.primaryIconTheme.color,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _StatChip({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$value',
          style: theme.primaryTextTheme.displaySmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 4),
        Text(label, style: theme.primaryTextTheme.displayMedium),
      ],
    );
  }
}
