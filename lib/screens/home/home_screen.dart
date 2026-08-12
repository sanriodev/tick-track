// ignore_for_file: use_build_context_synchronously

import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/state/cache_store.dart';
import 'package:ticktrack/models/activity/activity_model.dart';
import 'package:ticktrack/models/base/base_user_relation.dart';
import 'package:ticktrack/models/calendar/calendar_event_model.dart';
import 'package:ticktrack/models/note/note_api_model.dart';
import 'package:ticktrack/models/tasklist/task_list_api_model.dart';
import 'package:ticktrack/screens/home/main_app_screen.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/widgets/activity_preview_widget.dart';
import 'package:ticktrack/widgets/app_drawer_widget.dart';
import 'package:ticktrack/widgets/calendar_preview_widget.dart';
import 'package:ticktrack/widgets/group/group_context_switcher.dart';
import 'package:ticktrack/widgets/navigation/bottom_menu.dart';
import 'package:ticktrack/widgets/notes_preview_widget.dart';
import 'package:ticktrack/widgets/option_button.dart';
import 'package:ticktrack/widgets/to_do_list_widget.dart';
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
  List<CalendarOccurrence> _upcoming = [];

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

  List<T> _ownEntriesOf<T extends BaseUserRelation>(List<T> entries) {
    final String? ownUsername = AuthBackend().loggedInUser?.user?.username;
    return entries
        .where((entry) => entry.user?.username == ownUsername)
        .toList();
  }

  Future<void> _getTaskLists() async {
    final String cacheKey = CacheKey.taskLists(GroupContext().activeGroup?.id);
    final res = await Backend().getAllTaskLists(
      groupId: GroupContext().activeGroup?.id,
    );
    await CacheStore().writeList(cacheKey, res);
    _taskLists = _ownEntriesOf(res);
  }

  Future<void> _getNotes() async {
    final String cacheKey = CacheKey.notes(GroupContext().activeGroup?.id);
    final res = await Backend().getAllNotes(
      groupId: GroupContext().activeGroup?.id,
    );
    await CacheStore().writeList(cacheKey, res);
    _notes = _ownEntriesOf(res);
  }

  Future<void> _getActivities() async {
    final int? groupId = GroupContext().activeGroup?.id;
    final res = await Backend().getActivity('any', groupId: groupId);
    await CacheStore().writeList(CacheKey.activity(groupId, 'any'), res);
    _activities = res;
  }

  Future<void> _getUpcomingEvents() async {
    final int? groupId = GroupContext().activeGroup?.id;
    final now = DateTime.now();
    final res = await Backend().getCalendarEvents(
      groupId: groupId,
      from: now,
      to: now.add(const Duration(days: 14)),
    );
    await CacheStore().writeList(CacheKey.upcomingEvents(groupId), res);
    _upcoming = res;
  }

  bool _showCachedData() {
    final int? groupId = GroupContext().activeGroup?.id;
    final cachedTaskLists =
        CacheStore().readList(CacheKey.taskLists(groupId), TaskList.fromJson);
    final cachedNotes =
        CacheStore().readList(CacheKey.notes(groupId), Note.fromJson);
    final cachedActivities = CacheStore().readList<EventlogMessage<dynamic>>(
      CacheKey.activity(groupId, 'any'),
      EventlogMessage.fromJson,
    );
    final cachedUpcoming = CacheStore().readList(
      CacheKey.upcomingEvents(groupId),
      CalendarOccurrence.fromJson,
    );

    if (cachedTaskLists == null && cachedNotes == null) {
      return false;
    }

    setState(() {
      _taskLists = _ownEntriesOf(cachedTaskLists?.items ?? <TaskList>[]);
      _notes = _ownEntriesOf(cachedNotes?.items ?? <Note>[]);
      _activities = cachedActivities?.items ?? _activities;
      _upcoming = cachedUpcoming?.items ?? _upcoming;
      isLoading = false;
    });

    return true;
  }

  Future<void> _loadData() async {
    if (!_showCachedData()) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      await Future.wait([
        _getTaskLists(),
        _getNotes(),
        _getActivities(),
        _getUpcomingEvents(),
      ]);

      if (!mounted) {
        return;
      }
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        await showBackendError(context, e, 'Laden fehlgeschlagen');
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
                  CalendarPreviewWidget(
                    occurrences: _upcoming,
                    isLoading: isLoading,
                    onPressed: () {
                      navigateToRoute(context, 'calendar');
                    },
                  ),
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
