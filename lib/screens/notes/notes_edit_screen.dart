// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/models/note/note_api_model.dart';
import 'package:ticktrack/models/note/dto/update_note_dto.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/util/share_helper.dart';
import 'package:ticktrack/widgets/app_drawer_widget.dart';
import 'package:ticktrack/widgets/group/group_context_switcher.dart';
import 'package:blvckleg_dart_core/exception/session_expired.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// How long typing has to pause before the note is written to the backend.
const Duration _autosaveDelay = Duration(milliseconds: 900);

enum _SaveState { idle, unsaved, saving, saved, failed }

class NotesEditScreen extends StatefulWidget {
  const NotesEditScreen({super.key});

  @override
  State<NotesEditScreen> createState() => _NotesEditScreenState();
}

class _NotesEditScreenState extends State<NotesEditScreen> {
  final TextEditingController _commentController = TextEditingController();
  late int id;
  Note? note;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _initialized = false;

  /// Pending autosave, restarted on every keystroke.
  Timer? _autosaveTimer;
  _SaveState _saveState = _SaveState.idle;

  /// The content that is known to be stored in the backend. Everything else
  /// is derived from it, so a save can be skipped when nothing changed.
  String _savedContent = '';

  bool get _hasUnsavedChanges => _commentController.text != _savedContent;

  bool get _isEditable =>
      note != null &&
      (note!.user?.username == AuthBackend().loggedInUser?.user?.username ||
          note!.privacyMode == PrivacyMode.public);

  @override
  void initState() {
    super.initState();
    GroupContext().addListener(_onGroupContextChanged);
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
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
      final loaded = await backend.getNote(id);
      setState(() {
        note = loaded;
        _savedContent = loaded.content ?? '';
        _commentController.text = _savedContent;
        _saveState = _SaveState.idle;
      });
    } catch (e) {
      if (e is SessionExpiredException) {
        await showBackendError(context, e, 'Bitte melde dich erneut an.');
      } else if (mounted) {
        await showBackendError(context, e, 'Aktion fehlgeschlagen');
      }
    }
  }

  /// Restarts the autosave countdown. Called on every keystroke, so the
  /// backend only sees a request once the user pauses.
  void _onContentChanged(String value) {
    note?.content = value;
    _autosaveTimer?.cancel();

    // back to the stored version, e.g. the user undid their edit
    final next = _hasUnsavedChanges ? _SaveState.unsaved : _SaveState.idle;
    // only the status line depends on this, so skip the rebuild while the
    // user keeps typing in an already unsaved note
    if (next != _saveState) {
      setState(() => _saveState = next);
    }

    if (next == _SaveState.unsaved) {
      _autosaveTimer = Timer(_autosaveDelay, _saveNote);
    }
  }

  /// Writes the note if anything changed. Unlike a reload-after-save this
  /// keeps the cursor and selection intact while typing continues.
  Future<void> _saveNote({bool force = false}) async {
    _autosaveTimer?.cancel();

    if (!_isEditable || (!force && !_hasUnsavedChanges)) {
      return;
    }

    final content = _commentController.text;
    setState(() => _saveState = _SaveState.saving);

    try {
      final backend = Backend();
      await backend.updateNote(UpdateNoteDto(
        id: note?.id ?? id,
        title: note?.title ?? '',
        privacyMode: note?.privacyMode,
        content: content,
      ));
      if (!mounted) {
        return;
      }
      setState(() {
        _savedContent = content;
        // the user kept typing while the request was in flight
        _saveState = _hasUnsavedChanges ? _SaveState.unsaved : _SaveState.saved;
      });
      if (_saveState == _SaveState.unsaved) {
        _autosaveTimer = Timer(_autosaveDelay, _saveNote);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saveState = _SaveState.failed);
      }
      if (e is SessionExpiredException) {
        await showBackendError(context, e, 'Bitte melde dich erneut an.');
      } else if (mounted) {
        await showBackendError(context, e, 'Aktion fehlgeschlagen');
      }
    }
  }

  /// Saves outstanding changes before the screen goes away.
  Future<void> _saveAndLeave() async {
    await _saveNote();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Extends the native text selection menu with a share entry, so a
  /// selected passage can be shared the same way the whole note can.
  Widget _buildContextMenu(BuildContext context, EditableTextState state) {
    final items = state.contextMenuButtonItems;
    final selection = _commentController.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;

    if (hasSelection && note != null) {
      items.add(
        ContextMenuButtonItem(
          label: 'Teilen',
          onPressed: () {
            state.hideToolbar();
            shareText(
              context,
              selection.textInside(_commentController.text),
              subject: note!.title,
            );
          },
        ),
      );
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: items,
    );
  }

  /// Small status line next to the title: tells the user their text is safe
  /// without them having to press anything.
  Widget? _buildSaveIndicator() {
    final style = Theme.of(context).primaryTextTheme.displayMedium;

    switch (_saveState) {
      case _SaveState.idle:
        return null;
      case _SaveState.unsaved:
        return Text('Nicht gespeichert', style: style);
      case _SaveState.saving:
        return Text('Speichert …', style: style);
      case _SaveState.saved:
        return Text('Gespeichert', style: style);
      case _SaveState.failed:
        return Text('Speichern fehlgeschlagen', style: style);
    }
  }

  @override
  Widget build(BuildContext context) {
    final indicator = _buildSaveIndicator();

    return PopScope(
      // let the pop through, but flush pending edits on the way out
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _hasUnsavedChanges) {
          _saveNote();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(note?.title ?? 'Notiz bearbeiten',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).primaryTextTheme.titleMedium),
              if (indicator != null) indicator,
            ],
          ),
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _saveAndLeave,
              color: Theme.of(context).primaryIconTheme.color,
            ),
          ),
          actions: [
            const GroupContextSwitcher(),
            if (note != null)
              IconButton(
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.shareNetwork,
                  semanticLabel: 'Notiz teilen',
                ),
                tooltip: 'Notiz teilen',
                color: Theme.of(context).primaryIconTheme.color,
                onPressed: () => shareNote(context, note!),
              ),
            if (_isEditable)
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: 'Speichern',
                color: Theme.of(context).primaryIconTheme.color,
                onPressed: () {
                  Haptics.tap();
                  _saveNote(force: true);
                },
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
          color: Theme.of(context).cardColor,
          child: TextField(
            controller: _commentController,
            enabled: _isEditable,
            textAlignVertical: TextAlignVertical.top,
            expands: true,
            maxLines: null,
            // a note is prose: full multiline keyboard with a return key,
            // sentence capitalisation and the usual assists
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            contextMenuBuilder: _buildContextMenu,
            cursorColor: Theme.of(context).primaryColor,
            scrollPadding: const EdgeInsets.all(24),
            style: Theme.of(context).primaryTextTheme.titleSmall,
            onChanged: _onContentChanged,
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
      ),
    );
  }
}
