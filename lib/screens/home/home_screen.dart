// ignore_for_file: use_build_context_synchronously

import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/models/activity/activity_model.dart';
import 'package:ticktrack/models/note/note_api_model.dart';
import 'package:ticktrack/models/tasklist/task_list_api_model.dart';
import 'package:ticktrack/screens/home/main_app_screen.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/widgets/activity_preview_widget.dart';
import 'package:ticktrack/widgets/app_drawer_widget.dart';
import 'package:ticktrack/widgets/group/group_context_switcher.dart';
import 'package:ticktrack/widgets/navigation/bottom_menu.dart';
import 'package:ticktrack/widgets/notes_preview_widget.dart';
import 'package:ticktrack/widgets/option_button.dart';
import 'package:ticktrack/widgets/to_do_list_widget.dart';
import 'package:blvckleg_dart_core/exception/session_expired.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<TaskList> _taskLists = [];
  List<Note> _notes = [];
  List<EventlogMessage<dynamic>> _activities = [];

  bool isLoading = true;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    GroupContext().addListener(_onGroupContextChanged);
    _loadData();
    super.initState();
  }

  @override
  void dispose() {
    GroupContext().removeListener(_onGroupContextChanged);
    super.dispose();
  }

  void _onGroupContextChanged() {
    if (mounted) {
      _loadData();
    }
  }

  Future<void> _getTaskLists() async {
    try {
      final backend = Backend();
      final res = await backend.getAllTaskLists(
        groupId: GroupContext().activeGroup?.id,
      );
      final own = res
          .where((element) =>
              element.user!.username ==
              AuthBackend().loggedInUser?.user?.username)
          .toList();
      _taskLists = own;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _getNotes() async {
    try {
      final backend = Backend();
      final res = await backend.getAllNotes(
        groupId: GroupContext().activeGroup?.id,
      );
      final own = res
          .where((element) =>
              element.user!.username ==
              AuthBackend().loggedInUser?.user?.username)
          .toList();
      _notes = own;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _getActivities() async {
    try {
      final backend = Backend();
      // show the whole feed in the preview, same default as the activity screen
      final res = await backend.getActivity(
        'any',
        groupId: GroupContext().activeGroup?.id,
      );
      setState(() {
        _activities = res;
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
      });
      await Future.wait(
          [_getTaskLists(), _getNotes(), _getActivities()]);

      setState(() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        bottomNavigationBar: const BottomMenu(),
        appBar: AppBar(
          title: Text("Home",
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
        body: RefreshIndicator(
            onRefresh: () {
              return _loadData();
            },
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                      AuthBackend().loggedInUser?.user?.username != null
                          ? "Willkommen zurück, ${AuthBackend().loggedInUser?.user?.username}!"
                          : "Willkommen zurück!",
                      style: Theme.of(context).primaryTextTheme.displayLarge),
                  const SizedBox(height: 24),
                  TodoPreviewWidget(
                    themeMode: MainAppScreen.of(context)!.currentTheme!,
                    onPressed: () {
                      navigateToRoute(context, 'task-lists');
                    },
                    isLoading: isLoading,
                    taskLists: _taskLists,
                  ),
                  const SizedBox(height: 16),
                  NotesPreviewWidget(
                      themeMode: MainAppScreen.of(context)!.currentTheme!,
                      onPressed: () {
                        navigateToRoute(context, 'notes');
                      },
                      isLoading: isLoading,
                      notes: _notes),
                  const SizedBox(height: 16),
                  ActivityPreviewWidget(
                    onPressed: () {
                      navigateToRoute(context, 'activity');
                    },
                    isLoading: isLoading,
                    activities: _activities,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            )));
  }
}
