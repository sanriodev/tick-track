import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/models/note/note_api_model.dart';
import 'package:ticktrack/state/pin_store.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/util/report_helper.dart';
import 'package:ticktrack/util/share_helper.dart';
import 'package:ticktrack/widgets/slidable_underlay.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class NoteWidget extends StatefulWidget {
  final Note note;
  final void Function()? onTap;
  final void Function()? onDeletePress;
  final void Function(PrivacyMode mode)? onChangePrivacy;

  /// Called after the note's author was blocked from the report dialog, so
  /// the list can reload and drop the now hidden content.
  final void Function()? onBlocked;

  const NoteWidget({
    super.key,
    required this.note,
    this.onDeletePress,
    this.onTap,
    this.onChangePrivacy,
    this.onBlocked,
  });

  @override
  State<NoteWidget> createState() => _NoteWidgetState();
}

class _NoteWidgetState extends State<NoteWidget>
    with SingleTickerProviderStateMixin {
  /// Owned here instead of by the `Slidable` so the underlay behind it can
  /// follow which pane is open. A controller passed in from outside is not
  /// disposed by `Slidable`, so this state has to do it.
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

  bool get _isOwnNote =>
      widget.note.user?.username == AuthBackend().loggedInUser?.user?.username;

  bool get _isPinned => PinStore().isPinned(PinStore.noteKind, widget.note.id);

  Future<void> _togglePin() async {
    Haptics.tick();
    await PinStore().toggle(PinStore.noteKind, widget.note.id);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          // pin sits at the outer left, share directly next to the card
          SlidableUnderlay(
            controller: _slidableController,
            startColor: Theme.of(context).canvasColor,
            endColor: Colors.red,
          ),
          Slidable(
              // stable per note: a UniqueKey would rebuild the state on every
              // build, an index based match could carry an open pane over to
              // another note when the list changes
              key: ValueKey(widget.note.id),
              controller: _slidableController,
              startActionPane: ActionPane(
                motion: BehindMotion(),
                // two actions at the same width the end pane's single one has
                extentRatio: 0.6,
                children: [
                  SlidableAction(
                    borderRadius: slidableStartOuterRadius,
                    onPressed: (_) => _togglePin(),
                    backgroundColor: Theme.of(context).secondaryHeaderColor,
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.light
                            ? Colors.white
                            : Colors.grey[900],
                    icon: _isPinned
                        ? PhosphorIconsFill.pushPin
                        : PhosphorIconsRegular.pushPin,
                    label: _isPinned ? 'Loslösen' : 'Anpinnen',
                  ),
                  // sits between the pin and the card, so square on both
                  // sides - which is the default radius
                  SlidableAction(
                    onPressed: (_) => shareNote(context, widget.note),
                    backgroundColor: Theme.of(context).canvasColor,
                    foregroundColor: Theme.of(context).primaryIconTheme.color,
                    icon: PhosphorIconsRegular.shareNetwork,
                    label: 'Teilen',
                  ),
                ],
              ),
              endActionPane: ActionPane(
                motion: BehindMotion(),
                extentRatio: 0.3,
                children: [
                  if (_isOwnNote)
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
                        entityType: 'note',
                        entityId: widget.note.id,
                        entityLabel: 'Notiz',
                        authorId: widget.note.user?.id,
                        authorName: widget.note.user?.username,
                        onBlocked: widget.onBlocked,
                      ),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.flag,
                      label: 'Melden',
                    ),
                ],
              ),
              child: InkWell(
                onTap: widget.onTap,
                child: Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Text(
                                      "Name",
                                      style: Theme.of(context)
                                          .primaryTextTheme
                                          .titleSmall,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Text(
                                      widget.note.title,
                                      style: Theme.of(context)
                                          .primaryTextTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.light
                                                  ? Colors.grey[900]
                                                  : Colors.white),
                                    ),
                                  ),
                                  if (widget.note.content != null &&
                                      widget.note.content!.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Text(
                                        "Inhaltsvorschau",
                                        style: Theme.of(context)
                                            .primaryTextTheme
                                            .titleSmall,
                                      ),
                                    ),
                                  if (widget.note.content != null &&
                                      widget.note.content!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Text(
                                        "${widget.note.content!.length > 40 ? widget.note.content!.substring(0, 40) : widget.note.content}...",
                                        style: Theme.of(context)
                                            .primaryTextTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                overflow: TextOverflow.ellipsis,
                                                color: Theme.of(context)
                                                            .brightness ==
                                                        Brightness.light
                                                    ? Colors.grey[900]
                                                    : Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isPinned)
                                  IconButton(
                                    tooltip: 'Angepinnt - tippen zum Loslösen',
                                    onPressed: _togglePin,
                                    icon: PhosphorIcon(
                                      PhosphorIconsFill.pushPin,
                                      size: 18,
                                      color: Theme.of(context)
                                          .primaryIconTheme
                                          .color,
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 12, right: 12),
                                  child: PopupMenuButton<PrivacyMode>(
                                    enabled: widget.note.user?.username ==
                                        AuthBackend()
                                            .loggedInUser
                                            ?.user
                                            ?.username,
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
                                      privacyIconFor(widget.note.privacyMode),
                                      color: Theme.of(context)
                                          .primaryIconTheme
                                          .color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 12, bottom: 8, right: 6),
                              child: PhosphorIcon(
                                PhosphorIconsRegular.user,
                                size: 16,
                                color: Theme.of(context).primaryIconTheme.color,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: 12, bottom: 8),
                              child: Text(
                                widget.note.user != null
                                    ? widget.note.user!.username
                                    : "unknown",
                                style: Theme.of(context)
                                    .primaryTextTheme
                                    .bodySmall,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 12, bottom: 8, right: 6),
                              child: PhosphorIcon(
                                PhosphorIconsRegular.pencil,
                                size: 16,
                                color: Theme.of(context).primaryIconTheme.color,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: 12, bottom: 8),
                              child: Text(
                                widget.note.lastModifiedUser != null
                                    ? widget.note.lastModifiedUser!.username
                                    : "unknown",
                                style: Theme.of(context)
                                    .primaryTextTheme
                                    .bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )),
              )),
        ],
      ),
    );
  }
}
