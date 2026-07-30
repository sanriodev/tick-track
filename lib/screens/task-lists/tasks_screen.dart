// ignore_for_file: use_build_context_synchronously

import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/models/task/dto/create_task_dto.dart';
import 'package:ticktrack/models/task/task_api_model.dart';
import 'package:ticktrack/models/tasklist/task_list_api_model.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/util/report_helper.dart';
import 'package:ticktrack/widgets/app_drawer_widget.dart';
import 'package:ticktrack/widgets/empty_state_widget.dart';
import 'package:ticktrack/widgets/group/group_context_switcher.dart';
import 'package:ticktrack/widgets/option_button.dart';
import 'package:ticktrack/widgets/skeleton/skeleton_card.dart';
import 'package:ticktrack/widgets/slidable_underlay.dart';
import 'package:blvckleg_dart_core/exception/session_expired.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

final class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Task> completeTasks = [];
  List<Task> incompleteTasks = [];
  late TaskList list;
  bool isLoading = true;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    GroupContext().addListener(_onGroupContextChanged);
  }

  @override
  void dispose() {
    GroupContext().removeListener(_onGroupContextChanged);
    super.dispose();
  }

  void _onGroupContextChanged() {
    // the shown list belongs to the previous group context, go back to the
    // task list overview of the new context
    if (mounted) {
      navigateToRoute(context, 'task-lists');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final extra = GoRouterState.of(context).extra;
      if (extra is TaskList) {
        list = extra;
        _initialized = true;
        _getTasksForList();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Fehlender Parameter für Aufgabenliste.')),
          );
          Navigator.of(context).pop();
        });
      }
    }
  }

  Future<void> _getTasksForList() async {
    try {
      setState(() {
        isLoading = true;
      });
      final backend = Backend();
      final res = await backend.getAllTasksForList(list.id);
      final complete = res.where((task) => task.isDone).toList();
      final incomplete = res.where((task) => !task.isDone).toList();
      setState(() {
        completeTasks = complete;
        incompleteTasks = incomplete;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (e is SessionExpiredException) {
        await showBackendError(context, e, 'Bitte melde dich erneut an.');
      } else if (mounted) {
        await showBackendError(context, e, 'Aktion fehlgeschlagen');
      }
    }
  }

  Future<void> _createNewTask(CreateTaskDto data) async {
    try {
      final backend = Backend();
      await backend.createTask(data);
      await _getTasksForList();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (e is SessionExpiredException) {
        await showBackendError(context, e, 'Bitte melde dich erneut an.');
      } else if (mounted) {
        await showBackendError(context, e, 'Aktion fehlgeschlagen');
      }
    }
  }

  Future<void> _deleteTask(int id) async {
    try {
      final backend = Backend();
      await backend.deleteTask(id);
      await _getTasksForList();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (e is SessionExpiredException) {
        await showBackendError(context, e, 'Bitte melde dich erneut an.');
      } else if (mounted) {
        await showBackendError(context, e, 'Aktion fehlgeschlagen');
      }
    }
  }

  Future<void> _updateTask(Task task) async {
    try {
      final backend = Backend();
      await backend.updateTask(task);
      await _getTasksForList();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (e is SessionExpiredException) {
        await showBackendError(context, e, 'Bitte melde dich erneut an.');
      } else if (mounted) {
        await showBackendError(context, e, 'Aktion fehlgeschlagen');
      }
    }
  }

  /// Whether the logged in user may tick this task off: only a protected or
  /// private list belonging to somebody else is off limits. Same rule as
  /// before, just expressed positively.
  bool _canToggle(Task task) {
    final isOwnList = task.taskList?.user?.username ==
        AuthBackend().loggedInUser?.user?.username;
    final mode = task.taskList?.privacyMode;
    return isOwnList ||
        (mode != PrivacyMode.protected && mode != PrivacyMode.private);
  }

  Widget _buildTaskCard(Task task) {
    final theme = Theme.of(context);
    final content = task.content?.trim() ?? '';
    final enabled = _canToggle(task);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 14, 8),
        child: Row(
          children: [
            // leading, like every other todo list - the thumb lands on it
            // without covering the text
            Checkbox(
              value: task.isDone,
              onChanged: enabled
                  ? (bool? value) async {
                      Haptics.tick();
                      task.isDone = value ?? false;
                      await _updateTask(task);
                    }
                  : null,
              activeColor: theme.primaryColor,
              checkColor: theme.scaffoldBackgroundColor,
              side: const BorderSide(color: Colors.grey, width: 1.5),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: theme.primaryTextTheme.displaySmall?.copyWith(
                      // a finished task stays readable but visibly steps back
                      decoration:
                          task.isDone ? TextDecoration.lineThrough : null,
                      color: task.isDone
                          ? theme.primaryTextTheme.displaySmall?.color
                              ?.withValues(alpha: 0.5)
                          : null,
                    ),
                  ),
                  if (content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.primaryTextTheme.titleSmall?.copyWith(
                          color: theme.primaryTextTheme.titleSmall?.color
                              ?.withValues(alpha: task.isDone ? 0.4 : 0.75),
                          height: 1.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Heading plus entries, or nothing at all for an empty group.
  ///
  /// Rendering an empty list is not free: a vertical [ListView] without an
  /// explicit padding adopts the vertical insets of the ambient MediaQuery, so
  /// even with zero items it keeps a height - which pushed the heading of the
  /// group below it down.
  List<Widget> _section(String label, List<Task> tasks) {
    if (tasks.isEmpty) {
      return const [];
    }
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).primaryTextTheme.displayLarge,
        ),
      ),
      getAllListItems(tasks),
    ];
  }

  ListView getAllListItems(List<Task> tasks) {
    return ListView.builder(
        shrinkWrap: true,
        // see _section: without this the list inherits the MediaQuery insets
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tasks.length,
        itemBuilder: (BuildContext context, int index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Stack(
              clipBehavior: Clip.antiAlias,
              children: [
                // no start pane on a task, so only the right side is filled
                const SlidableUnderlay(endColor: Colors.red),
                Slidable(
                    key: ValueKey(tasks[index].id),
                    endActionPane: ActionPane(
                      motion: BehindMotion(),
                      extentRatio: 0.3,
                      children: [
                        if (tasks[index].taskList?.user?.username ==
                            AuthBackend().loggedInUser?.user?.username)
                          SlidableAction(
                            borderRadius: slidableEndOuterRadius,
                            onPressed: (_) {
                              Haptics.warning();
                              _deleteTask(tasks[index].id);
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
                              entityType: 'task',
                              entityId: tasks[index].id,
                              entityLabel: 'Aufgabe',
                              authorId: tasks[index].taskList?.user?.id,
                              authorName: tasks[index].taskList?.user?.username,
                              onBlocked: () => _getTasksForList(),
                            ),
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            icon: Icons.flag,
                            label: 'Melden',
                          ),
                      ],
                    ),
                    child: _buildTaskCard(tasks[index])),
              ],
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(list.name,
              style: Theme.of(context).primaryTextTheme.titleMedium),
          centerTitle: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                Navigator.of(context).pop();
              },
              color: Theme.of(context).primaryIconTheme.color,
            ),
          ),
          //backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          actions: [
            const GroupContextSwitcher(),
            OptionButton(
              onPressed: () {
                _scaffoldKey.currentState?.openEndDrawer();
              },
            )
          ],
        ),
        endDrawer: AppDrawer(),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Haptics.tap();
            _showCreateTaskDialog();
          },
          tooltip: 'Neuer Eintrag',
          child: const Icon(Icons.add),
        ),
        body: RefreshIndicator(
          color: Theme.of(context).primaryColor,
          backgroundColor: Theme.of(context).secondaryHeaderColor,
          onRefresh: () async {
            setState(() {
              isLoading = true;
            });
            return await _getTasksForList();
          },
          child: Column(
            children: <Widget>[
              if (isLoading)
                Skeletonizer(
                    effect: ShimmerEffect(
                      baseColor: Theme.of(context).canvasColor,
                      duration: const Duration(seconds: 3),
                    ),
                    enabled: isLoading,
                    child: const SkeletonCard()),
              Expanded(
                child: isLoading
                    ? Container()
                    : completeTasks.isEmpty && incompleteTasks.isEmpty
                        ? const EmptyStateWidget(
                            icon: PhosphorIconsRegular.listChecks,
                            title: 'Diese Liste ist leer',
                            message:
                                'Lege den ersten Eintrag an - abgehakte Aufgaben '
                                'rutschen automatisch nach unten.',
                          )
                        : SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ..._section("Offene Tasks", incompleteTasks),
                                ..._section(
                                    "Abgeschlossene Tasks", completeTasks),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ));
  }

  Future<void> _showCreateTaskDialog() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Name der Aufgabe',
            style: Theme.of(context).primaryTextTheme.bodySmall,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                style: Theme.of(context).primaryTextTheme.bodySmall,
                decoration: InputDecoration(
                  labelText: 'Titel',
                  labelStyle: Theme.of(context).primaryTextTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                style: Theme.of(context).primaryTextTheme.bodySmall,
                decoration: InputDecoration(
                  labelText: 'Inhalt (optional)',
                  labelStyle: Theme.of(context).primaryTextTheme.bodySmall,
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actionsPadding: const EdgeInsets.all(16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Abbrechen',
                  style: Theme.of(context).primaryTextTheme.titleSmall),
            ),
            ElevatedButton(
              onPressed: () async {
                final t = titleController.text.trim();
                final c = contentController.text.trim();
                if (t.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bitte einen Titel eingeben.'),
                    ),
                  );
                  return;
                }
                await _createNewTask(CreateTaskDto(
                  title: t,
                  content: c,
                  taskListId: list.id,
                ));
                if (mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              style: Theme.of(context).elevatedButtonTheme.style,
              child: Text(
                'Erstellen',
                style: Theme.of(context).primaryTextTheme.titleSmall?.copyWith(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.white
                          : Colors.grey[900],
                    ),
              ),
            ),
          ],
        );
      },
    );
  }
}
