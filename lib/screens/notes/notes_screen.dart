// ignore_for_file: use_build_context_synchronously

import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/models/note/dto/update_note_dto.dart';
import 'package:ticktrack/models/note/note_api_model.dart';
import 'package:ticktrack/models/note/dto/create_note_dto.dart';
import 'package:ticktrack/state/cache_store.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/state/pin_store.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/widgets/app_options_sheet.dart';
import 'package:ticktrack/widgets/empty_state_widget.dart';
import 'package:ticktrack/widgets/group/group_context_switcher.dart';
import 'package:ticktrack/widgets/navigation/bottom_menu.dart';
import 'package:ticktrack/widgets/note_widget.dart';
import 'package:ticktrack/widgets/option_button.dart';
import 'package:ticktrack/widgets/skeleton/skeleton_card.dart';
import 'package:blvckleg_dart_core/exception/session_expired.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Note> ownNotes = [];
  List<Note> sharedNotes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    GroupContext().addListener(_onGroupContextChanged);
    PinStore().addListener(_onPinsChanged);
    getNotes();
  }

  @override
  void dispose() {
    GroupContext().removeListener(_onGroupContextChanged);
    PinStore().removeListener(_onPinsChanged);
    super.dispose();
  }

  void _onGroupContextChanged() {
    if (mounted) {
      getNotes();
    }
  }

  void _onPinsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> getNotes() async {
    final int? groupId = GroupContext().activeGroup?.id;
    final String cacheKey = CacheKey.notes(groupId);
    final cached = CacheStore().readList(cacheKey, Note.fromJson);

    if (cached != null) {
      _showNotes(cached.items);
    } else {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final fresh = await Backend().getAllNotes(groupId: groupId);
      await CacheStore().writeList(cacheKey, fresh);
      _showNotes(fresh);
      await PinStore()
          .pruneMissing(PinStore.noteKind, fresh.map((note) => note.id));
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        await showBackendError(context, e, context.l10n.actionFailed,
            alertWhenOffline: false);
      }
    }
  }

  void _showNotes(List<Note> notes) {
    final String? ownUsername = AuthBackend().loggedInUser?.user?.username;
    if (!mounted) {
      return;
    }
    setState(() {
      isLoading = false;
      ownNotes =
          notes.where((note) => note.user?.username == ownUsername).toList();
      sharedNotes =
          notes.where((note) => note.user?.username != ownUsername).toList();
    });
  }

  Future<void> createNewItem(CreateNoteDto data) async {
    setState(() {
      isLoading = true;
    });
    try {
      final backend = Backend();
      await backend.createNote(data);
      await getNotes();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (e is SessionExpiredException) {
        await showBackendError(context, e, context.l10n.sessionExpired);
      } else if (mounted) {
        await showBackendError(context, e, context.l10n.actionFailed);
      }
    }
  }

  Future<void> deleteItem(int id) async {
    setState(() {
      isLoading = true;
    });
    try {
      final backend = Backend();
      await backend.deleteNote(id);
      await getNotes();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (e is SessionExpiredException) {
        await showBackendError(context, e, context.l10n.sessionExpired);
      } else if (mounted) {
        await showBackendError(context, e, context.l10n.actionFailed);
      }
    }
  }

  Future<void> updatePrivacy(Note note, PrivacyMode mode) async {
    if (note.user?.username != AuthBackend().loggedInUser?.user?.username) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                context.l10n.privacyOwnContentOnly)),
      );
      return;
    }
    setState(() {
      isLoading = true;
    });
    try {
      final backend = Backend();
      await backend.updateNote(UpdateNoteDto(
        id: note.id,
        title: note.title,
        privacyMode: mode,
      ));
      await getNotes();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (e is SessionExpiredException) {
        await showBackendError(context, e, context.l10n.sessionExpired);
      } else if (mounted) {
        await showBackendError(context, e, context.l10n.actionFailed);
      }
    }
  }

  List<Widget> _section(String label, List<Note> notes) {
    if (notes.isEmpty) {
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
      getAllListItems(notes),
    ];
  }

  ListView getAllListItems(List<Note> notes) {
    return ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: notes.length,
        itemBuilder: (BuildContext context, int index) {
          return NoteWidget(
            onTap: () async {
              await navigateToRoute(context, 'notes-edit',
                  extra: notes[index].id, backEnabled: true);
              if (mounted) {
                await getNotes();
              }
            },
            onDeletePress: () {
              deleteItem(
                notes[index].id,
              );
            },
            onBlocked: () => getNotes(),
            onChangePrivacy: (PrivacyMode mode) {
              updatePrivacy(notes[index], mode);
            },
            note: notes[index],
          );
        });
  }

  Future<void> _showCreateNoteDialog() async {
    final nameController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            context.l10n.noteNew,
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
                  labelText: context.l10n.noteName,
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
              child: Text(context.l10n.cancel,
                  style: Theme.of(context).primaryTextTheme.titleSmall),
            ),
            ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.nameRequired)),
                    );
                    return;
                  }
                  await createNewItem(CreateNoteDto(
                    title: name,
                    content: '',
                    groupId: GroupContext().activeGroup?.id,
                  ));
                  if (mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: Text(
                  context.l10n.create,
                  style: Theme.of(context)
                      .primaryTextTheme
                      .titleSmall
                      ?.copyWith(
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.white
                            : Colors.grey[900],
                      ),
                )),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final own = PinStore().partition(
      PinStore.noteKind,
      ownNotes,
      (note) => note.id,
    );
    final shared = PinStore().partition(
      PinStore.noteKind,
      sharedNotes,
      (note) => note.id,
    );
    final pinned = [...own.pinned, ...shared.pinned];
    final hasAnyNote = ownNotes.isNotEmpty || sharedNotes.isNotEmpty;

    return Scaffold(
      bottomNavigationBar: const BottomMenu(),
      appBar: AppBar(
        title: Text(context.l10n.notes,
            style: Theme.of(context).primaryTextTheme.titleMedium),
        centerTitle: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          const GroupContextSwitcher(),
          OptionButton(
            onPressed: () {
              showAppOptionsSheet(context);
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Haptics.tap();
          _showCreateNoteDialog();
        },
        tooltip: context.l10n.noteNew,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            isLoading = true;
          });
          return await getNotes();
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
                  : !hasAnyNote
                      ? EmptyStateWidget(
                          icon: PhosphorIconsRegular.note,
                          title: context.l10n.notesEmptyTitle,
                          message: context.l10n.notesEmptyMessage,
                        )
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ..._section(context.l10n.sectionPinned, pinned),
                              ..._section(
                                  context.l10n.sectionYourNotes, own.others),
                              ..._section(context.l10n.sectionSharedNotes,
                                  shared.others),
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
