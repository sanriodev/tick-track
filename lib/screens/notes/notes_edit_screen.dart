// ignore_for_file: use_build_context_synchronously

import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/models/note/note_api_model.dart';
import 'package:ticktrack/models/note/dto/update_note_dto.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/widgets/app_drawer_widget.dart';
import 'package:ticktrack/widgets/group/group_context_switcher.dart';
import 'package:blvckleg_dart_core/exception/session_expired.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class NotesEditScreen extends StatefulWidget {
  const NotesEditScreen({super.key});

  @override
  _NotesEditScreenState createState() => _NotesEditScreenState();
}

class _NotesEditScreenState extends State<NotesEditScreen> {
  final TextEditingController _commentController = TextEditingController();
  late int id;
  Note? note;
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
    _commentController.dispose();
    super.dispose();
  }

  void _onGroupContextChanged() {
    // the shown note belongs to the previous group context, go back to the
    // notes overview of the new context
    if (mounted) {
      navigateToRoute(context, 'notes');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final extra = GoRouterState.of(context).extra;
      if (extra is int) {
        id = extra;
        _initialized = true;
        _loadNote();
      } else {
        // Gracefully handle missing payload
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fehlender Parameter für Notiz.')),
          );
          Navigator.of(context).pop();
        });
      }
    }
  }

  Future<void> _loadNote() async {
    try {
      final backend = Backend();
      note = await backend.getNote(id);
      setState(() {
        _commentController.text = note?.content ?? '';
      });
    } catch (e) {
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

  Future<void> _saveNote() async {
    try {
      final backend = Backend();
      final updatedNote = UpdateNoteDto(
        id: note?.id ?? id,
        title: note?.title ?? '',
        privacyMode: note?.privacyMode,
        content: _commentController.text,
      );
      await backend.updateNote(updatedNote);
      await _loadNote();
    } catch (e) {
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
      appBar: AppBar(
        title: Text('Notiz bearbeiten',
            style: Theme.of(context).primaryTextTheme.titleMedium),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              _saveNote();
              Navigator.of(context).pop();
            },
            color: Theme.of(context).primaryIconTheme.color,
            tooltip: "I love my gf",
          ),
        ),
        actions: [
          const GroupContextSwitcher(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              icon: const Icon(Icons.save),
              color: Theme.of(context).primaryIconTheme.color,
              onPressed: () {
                _saveNote();
              },
            ),
          ),
          IconButton(
            color: Theme.of(context).primaryIconTheme.color,
            icon: const PhosphorIcon(
              PhosphorIconsRegular.gear,
              semanticLabel: 'Einstellungen',
            ),
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
      endDrawer: AppDrawer(),
      body: Container(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.zero,
          boxShadow: const [],
          border: Border.all(
            color: Colors.transparent,
            width: 0,
            style: BorderStyle.none,
          ),
        ),
        child: TextField(
          controller: _commentController,
          enabled: note != null &&
              (note!.user?.username ==
                      AuthBackend().loggedInUser?.user?.username ||
                  note!.privacyMode == PrivacyMode.public),
          textAlignVertical: TextAlignVertical.top,
          expands: true,
          maxLines: null,
          style: Theme.of(context).primaryTextTheme.titleSmall,
          onChanged: (value) {
            if (note != null) {
              note!.content = value;
            }
          },
          decoration: InputDecoration(
            hintText: 'Notiz...',
            hintStyle: Theme.of(context).primaryTextTheme.titleSmall,
            contentPadding: const EdgeInsets.all(16.0),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
          ),
        ),
      ),
    );
  }
}
