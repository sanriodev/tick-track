// ignore_for_file: use_build_context_synchronously

import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/models/tasklist/dto/update_task_list_dto.dart';
import 'package:ticktrack/models/tasklist/task_list_api_model.dart';
import 'package:ticktrack/models/tasklist/dto/create_task_list_dto.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/state/pin_store.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/widgets/app_drawer_widget.dart';
import 'package:ticktrack/widgets/empty_state_widget.dart';
import 'package:ticktrack/widgets/group/group_context_switcher.dart';
import 'package:ticktrack/widgets/navigation/bottom_menu.dart';
import 'package:ticktrack/widgets/option_button.dart';
import 'package:ticktrack/widgets/skeleton/skeleton_card.dart';
import 'package:ticktrack/widgets/task_list_widget.dart';
import 'package:blvckleg_dart_core/exception/session_expired.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<TaskList> ownTaskLists = [];
  List<TaskList> sharedTaskLists = [];
  String collectionName = '';
  bool isLoading = true;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    GroupContext().addListener(_onGroupContextChanged);
    PinStore().addListener(_onPinsChanged);
    getTaskLists();
  }

  @override
  void dispose() {
    GroupContext().removeListener(_onGroupContextChanged);
    PinStore().removeListener(_onPinsChanged);
    super.dispose();
  }

  void _onGroupContextChanged() {
    if (mounted) {
      getTaskLists();
    }
  }

  void _onPinsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> getTaskLists() async {
    try {
      setState(() {
        isLoading = true;
      });
      final backend = Backend();
      final res = await backend.getAllTaskLists(
        groupId: GroupContext().activeGroup?.id,
      );
      final own = res
          .where((element) =>
              element.user!.username ==
              AuthBackend().loggedInUser?.user?.username)
          .toList();
      final shared = res
          .where((element) =>
              element.user!.username !=
              AuthBackend().loggedInUser?.user?.username)
          .toList();
      await PinStore()
          .pruneMissing(PinStore.taskListKind, res.map((list) => list.id));
      setState(() {
        ownTaskLists = own;
        sharedTaskLists = shared;
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

  Future<void> createNewItem(CreateTaskListDto data) async {
    try {
      final backend = Backend();
      await backend.createTaskList(data);
      await getTaskLists();
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

  Future<void> deleteItem(int id) async {
    try {
      final backend = Backend();
      await backend.deleteTaskList(id);
      await getTaskLists();
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

  Future<void> updatePrivacy(TaskList taskList, PrivacyMode mode) async {
    if (taskList.user?.username != AuthBackend().loggedInUser?.user?.username) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Du kannst die Privatsphäre nur bei deinen eigenen Notizen ändern.')),
      );
      return;
    }
    setState(() {
      isLoading = true;
    });
    try {
      final backend = Backend();
      await backend.updateTaskList(UpdateTaskListDto(
        id: taskList.id,
        name: taskList.name,
        privacyMode: mode,
      ));
      await getTaskLists();
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

  List<Widget> _section(String label, List<TaskList> taskLists) {
    if (taskLists.isEmpty) {
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
      getAllListItems(taskLists),
    ];
  }

  ListView getAllListItems(List<TaskList> taskLists) {
    return ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: taskLists.length,
        itemBuilder: (BuildContext context, int index) {
          return TaskListWidget(
              onTap: () async {
                await navigateToRoute(context, 'tasks',
                    extra: taskLists[index], backEnabled: true);
                if (mounted) {
                  await getTaskLists();
                }
              },
              onDeletePress: () {
                deleteItem(taskLists[index].id);
              },
              onChangePrivacy: (PrivacyMode mode) {
                updatePrivacy(taskLists[index], mode);
              },
              onBlocked: () => getTaskLists(),
              totalTasks: taskLists[index].tasks.length,
              completedTasks:
                  taskLists[index].tasks.where((test) => test.isDone).length,
              openTasks:
                  taskLists[index].tasks.where((test) => !test.isDone).length,
              taskList: taskLists[index]);
        });
  }

  Future<void> _showCreateTaskListDialog() async {
    final TextEditingController nameController =
        TextEditingController(text: collectionName);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Neue Liste',
            style: Theme.of(context).primaryTextTheme.bodySmall,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                style: Theme.of(context).primaryTextTheme.bodySmall,
                decoration: InputDecoration(
                  labelText: 'Name der Liste',
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
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Bitte einen Namen eingeben.')),
                  );
                  return;
                }
                await createNewItem(CreateTaskListDto(
                  name: name,
                  groupId: GroupContext().activeGroup?.id,
                ));
                if (mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
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

  @override
  Widget build(BuildContext context) {
    final own = PinStore().partition(
      PinStore.taskListKind,
      ownTaskLists,
      (list) => list.id,
    );
    final shared = PinStore().partition(
      PinStore.taskListKind,
      sharedTaskLists,
      (list) => list.id,
    );
    final pinned = [...own.pinned, ...shared.pinned];
    final hasAnyList = ownTaskLists.isNotEmpty || sharedTaskLists.isNotEmpty;

    return Scaffold(
      key: _scaffoldKey,
      bottomNavigationBar: const BottomMenu(),
      appBar: AppBar(
        title: Text("Aufgabenlisten",
            style: Theme.of(context).primaryTextTheme.titleMedium),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        centerTitle: false,
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
          _showCreateTaskListDialog();
        },
        tooltip: 'Neue Liste',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            isLoading = true;
          });
          return await getTaskLists();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  : !hasAnyList
                      ? const EmptyStateWidget(
                          icon: PhosphorIconsRegular.list,
                          title: 'Noch keine Aufgabenlisten',
                          message:
                              'Bündle Aufgaben in Listen und verfolge, was schon erledigt ist. '
                              'Wische eine Liste nach rechts, um sie anzupinnen.',
                        )
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ..._section("Angepinnt", pinned),
                              ..._section("Deine Listen", own.others),
                              ..._section("Geteilte Listen", shared.others),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
