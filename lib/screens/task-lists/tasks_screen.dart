// ignore_for_file: use_build_context_synchronously

import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/models/task/dto/create_task_dto.dart';
import 'package:ticktrack/models/task/task_api_model.dart';
import 'package:ticktrack/models/tasklist/task_list_api_model.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/widgets/app_drawer_widget.dart';
import 'package:ticktrack/widgets/option_button.dart';
import 'package:ticktrack/widgets/skeleton/skeleton_card.dart';
import 'package:blvckleg_dart_core/exception/session_expired.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bitte melde dich erneut an.')),
        );

        try {
          await AuthBackend().postLogout();
          await deleteBoxAndNavigateToLogin(context);
        } catch (e) {
          await deleteBoxAndNavigateToLogin(context);
        }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bitte melde dich erneut an.')),
        );

        try {
          await AuthBackend().postLogout();
          await deleteBoxAndNavigateToLogin(context);
        } catch (e) {
          await deleteBoxAndNavigateToLogin(context);
        }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bitte melde dich erneut an.')),
        );

        try {
          await AuthBackend().postLogout();
          await deleteBoxAndNavigateToLogin(context);
        } catch (e) {
          await deleteBoxAndNavigateToLogin(context);
        }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bitte melde dich erneut an.')),
        );

        try {
          await AuthBackend().postLogout();
          await deleteBoxAndNavigateToLogin(context);
        } catch (e) {
          await deleteBoxAndNavigateToLogin(context);
        }
      }
    }
  }

  ListView getAllListItems(List<Task> tasks) {
    return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tasks.length,
        itemBuilder: (BuildContext context, int index) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Stack(
              clipBehavior: Clip.antiAlias,
              children: [
                Positioned.fill(
                  child: Builder(
                      builder: (context) => Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10.0),
                            child: Container(
                              color: Colors.red,
                            ),
                          )),
                ),
                Slidable(
                    enabled: tasks[index].taskList?.user?.username ==
                        AuthBackend().loggedInUser?.user?.username,
                    key: UniqueKey(),
                    endActionPane: ActionPane(
                      motion: BehindMotion(),
                      extentRatio: 0.3,
                      children: [
                        SlidableAction(
                          borderRadius: BorderRadius.circular(12),
                          onPressed: (_) => {_deleteTask(tasks[index].id)},
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                        ),
                      ],
                    ),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Text("Titel",
                                      style: Theme.of(context)
                                          .primaryTextTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.light
                                                  ? Colors.grey[900]
                                                  : Colors.white)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Text(tasks[index].title,
                                      style: Theme.of(context)
                                          .primaryTextTheme
                                          .titleSmall),
                                ),
                                if (tasks[index].content != null &&
                                    tasks[index].content!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Text("Inhalt",
                                        style: Theme.of(context)
                                            .primaryTextTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                color: Theme.of(context)
                                                            .brightness ==
                                                        Brightness.light
                                                    ? Colors.grey[900]
                                                    : Colors.white)),
                                  ),
                                if (tasks[index].content != null &&
                                    tasks[index].content!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Text(tasks[index].content!,
                                        style: Theme.of(context)
                                            .primaryTextTheme
                                            .titleSmall),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: IgnorePointer(
                              ignoring: tasks[index].taskList?.user?.username !=
                                      AuthBackend()
                                          .loggedInUser
                                          ?.user
                                          ?.username &&
                                  (tasks[index].taskList?.privacyMode ==
                                          PrivacyMode.protected ||
                                      tasks[index].taskList?.privacyMode ==
                                          PrivacyMode.private),
                              child: Transform.scale(
                                scale: 1.75,
                                child: Checkbox(
                                  value: tasks[index].isDone,
                                  onChanged: (bool? value) async {
                                    tasks[index].isDone = value ?? false;
                                    await _updateTask(tasks[index]);
                                  },
                                  activeColor: Theme.of(context).primaryColor,
                                  checkColor:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  side: const BorderSide(
                                      color: Colors.grey, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
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
              tooltip: "I love my gf",
            ),
          ),
          //backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          actions: [
            OptionButton(
              onPressed: () {
                _scaffoldKey.currentState?.openEndDrawer();
              },
            )
          ],
        ),
        endDrawer: AppDrawer(),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
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
                          labelStyle:
                              Theme.of(context).primaryTextTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contentController,
                        style: Theme.of(context).primaryTextTheme.bodySmall,
                        decoration: InputDecoration(
                          labelText: 'Inhalt (optional)',
                          labelStyle:
                              Theme.of(context).primaryTextTheme.bodySmall,
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
                        style: Theme.of(context)
                            .primaryTextTheme
                            .titleSmall
                            ?.copyWith(
                              color: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? Colors.white
                                  : Colors.grey[900],
                            ),
                      ),
                    ),
                  ],
                );
              },
            );
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
                child: !isLoading
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (incompleteTasks.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Text(
                                  "Offene Tasks",
                                  style: Theme.of(context)
                                      .primaryTextTheme
                                      .displayLarge,
                                ),
                              ),
                            getAllListItems(incompleteTasks),
                            if (completeTasks.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Text(
                                  "Abgeschlossene Tasks",
                                  style: Theme.of(context)
                                      .primaryTextTheme
                                      .displayLarge,
                                ),
                              ),
                            getAllListItems(completeTasks)
                          ],
                        ),
                      )
                    : Container(),
              ),
            ],
          ),
        ));
  }
}
