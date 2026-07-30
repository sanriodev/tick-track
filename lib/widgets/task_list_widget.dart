import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/models/tasklist/task_list_api_model.dart';
import 'package:ticktrack/state/pin_store.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/util/report_helper.dart';
import 'package:ticktrack/widgets/accordion/accordion_section.dart';
import 'package:ticktrack/widgets/accordion/task_list_accordion.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:getwidget/components/progress_bar/gf_progress_bar.dart';
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

  /// Called after the list's author was blocked from the report dialog, so
  /// the screen can reload and drop the now hidden content.
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

class _TaskListWidgetState extends State<TaskListWidget> {
  bool get _isOwnList =>
      widget.taskList.user?.username ==
      AuthBackend().loggedInUser?.user?.username;

  bool get _isPinned =>
      PinStore().isPinned(PinStore.taskListKind, widget.taskList.id);

  Future<void> _togglePin() async {
    Haptics.tick();
    await PinStore().toggle(PinStore.taskListKind, widget.taskList.id);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          Positioned.fill(
            child: Builder(
                builder: (context) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Container(
                        color: Colors.red,
                      ),
                    )),
          ),
          Slidable(
              key: UniqueKey(),
              startActionPane: ActionPane(
                motion: BehindMotion(),
                extentRatio: 0.3,
                children: [
                  SlidableAction(
                    borderRadius: BorderRadius.circular(12),
                    onPressed: (_) => _togglePin(),
                    backgroundColor: Theme.of(context).canvasColor,
                    foregroundColor: Theme.of(context).primaryIconTheme.color,
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
                      borderRadius: BorderRadius.circular(12),
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
                      borderRadius: BorderRadius.circular(12),
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
                    headerBackgroundColor:
                        Theme.of(context).secondaryHeaderColor,
                    isOpen: false,
                    header: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          // Privacy mode button in place of the old delete button
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: PopupMenuButton<PrivacyMode>(
                              enabled: widget.taskList.user?.username ==
                                  AuthBackend().loggedInUser?.user?.username,
                              tooltip: 'Privatsphäre',
                              onSelected: (mode) =>
                                  widget.onChangePrivacy?.call(mode),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: PrivacyMode.private,
                                  child: Text(
                                      'Privat - nur du kannst sehen/bearbeiten'),
                                ),
                                const PopupMenuItem(
                                  value: PrivacyMode.protected,
                                  child: Text(
                                      'Geschützt - alle können sehen, bearbeiten nur du'),
                                ),
                                const PopupMenuItem(
                                  value: PrivacyMode.public,
                                  child: Text(
                                      'Öffentlich - alle können sehen/bearbeiten'),
                                ),
                              ],
                              child: Icon(
                                privacyIconFor(widget.taskList.privacyMode),
                                color: Theme.of(context)
                                    .primaryIconTheme
                                    ?.copyWith(
                                      color: Theme.of(context).brightness ==
                                              Brightness.light
                                          ? Colors.white
                                          : Colors.grey[900],
                                    )
                                    .color,
                              ),
                            ),
                          ),
                          if (_isPinned)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: PhosphorIcon(
                                PhosphorIconsFill.pushPin,
                                size: 18,
                                color: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? Colors.white
                                    : Colors.grey[900],
                              ),
                            ),
                          Text(
                            widget.taskList.name,
                            style: Theme.of(context)
                                .primaryTextTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.white
                                      : Colors.grey[900],
                                ),
                          ),
                        ],
                      ),
                    ),
                    content: InkWell(
                      onTap: widget.onTap,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Theme.of(context).primaryColor,
                                  size: 15,
                                ),
                                Text("Einträge gesamt: ${widget.totalTasks}",
                                    style: Theme.of(context)
                                        .primaryTextTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.light
                                                    ? Colors.grey[900]
                                                    : Colors.white)),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.circle,
                                  color: Colors.green,
                                  size: 15,
                                ),
                                Text(
                                  "Einträge abgeschlossen: ${widget.completedTasks}",
                                  style: Theme.of(context)
                                      .primaryTextTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context).brightness ==
                                                Brightness.light
                                            ? Colors.grey[900]
                                            : Colors.white,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.circle,
                                  color: Colors.red,
                                  size: 15,
                                ),
                                Text(
                                  "Einträge offen: ${widget.openTasks}",
                                  style: Theme.of(context)
                                      .primaryTextTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.light
                                              ? Colors.grey[900]
                                              : Colors.white),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 8),
                                  child: Text(
                                    "Aktueller Fortschritt",
                                    style: Theme.of(context)
                                        .primaryTextTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.light
                                                    ? Colors.grey[900]
                                                    : Colors.white),
                                  ),
                                ),
                                GFProgressBar(
                                  percentage: (widget.completedTasks /
                                              widget.totalTasks)
                                          .isNaN
                                      ? 0
                                      : (widget.completedTasks /
                                          widget.totalTasks),
                                  lineHeight: 20,
                                  backgroundColor: Colors.black26,
                                  progressBarColor:
                                      Theme.of(context).primaryColor,
                                  child: Text(
                                    "${(((widget.completedTasks / widget.totalTasks).isNaN ? 0 : (widget.completedTasks / widget.totalTasks)) * 100).toStringAsFixed(2)}%",
                                    style: Theme.of(context)
                                        .primaryTextTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: PhosphorIcon(
                                  PhosphorIconsRegular.user,
                                  size: 16,
                                  color:
                                      Theme.of(context).primaryIconTheme.color,
                                ),
                              ),
                              Text(
                                widget.taskList.user != null
                                    ? widget.taskList.user!.username
                                    : "unknown",
                                style: Theme.of(context)
                                    .primaryTextTheme
                                    .bodySmall,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: PhosphorIcon(
                                  PhosphorIconsRegular.pencil,
                                  size: 16,
                                  color:
                                      Theme.of(context).primaryIconTheme.color,
                                ),
                              ),
                              Text(
                                widget.taskList.lastModifiedUser != null
                                    ? widget.taskList.lastModifiedUser!.username
                                    : "unknown",
                                style: Theme.of(context)
                                    .primaryTextTheme
                                    .bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              )),
        ],
      ),
    );
  }
}
