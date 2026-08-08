import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/models/note/note_api_model.dart';
import 'package:ticktrack/state/pin_store.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/markdown_helper.dart';
import 'package:ticktrack/util/report_helper.dart';
import 'package:ticktrack/util/share_helper.dart';
import 'package:ticktrack/widgets/content_meta_footer.dart';
import 'package:ticktrack/widgets/privacy_mode_button.dart';
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
    final theme = Theme.of(context);
    final preview = markdownToPlainText(widget.note.content ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          SlidableUnderlay(
            controller: _slidableController,
            startColor: theme.canvasColor,
            endColor: Colors.red,
          ),
          Slidable(
            key: ValueKey(widget.note.id),
            controller: _slidableController,
            startActionPane: ActionPane(
              motion: BehindMotion(),
              extentRatio: 0.6,
              children: [
                SlidableAction(
                  borderRadius: slidableStartOuterRadius,
                  onPressed: (_) => _togglePin(),
                  backgroundColor: theme.secondaryHeaderColor,
                  foregroundColor: theme.brightness == Brightness.light
                      ? Colors.white
                      : Colors.grey[900],
                  icon: _isPinned
                      ? PhosphorIconsFill.pushPin
                      : PhosphorIconsRegular.pushPin,
                  label: _isPinned ? 'Loslösen' : 'Anpinnen',
                ),
                SlidableAction(
                  onPressed: (_) => shareNote(context, widget.note),
                  backgroundColor: theme.canvasColor,
                  foregroundColor: theme.primaryIconTheme.color,
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
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                widget.note.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.primaryTextTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          if (_isPinned)
                            IconButton(
                              tooltip: 'Angepinnt - tippen zum Loslösen',
                              onPressed: _togglePin,
                              visualDensity: VisualDensity.compact,
                              icon: PhosphorIcon(
                                PhosphorIconsFill.pushPin,
                                size: 18,
                                color: theme.primaryIconTheme.color,
                              ),
                            ),
                          PrivacyModeButton(
                            mode: widget.note.privacyMode,
                            enabled: _isOwnNote,
                            onChanged: widget.onChangePrivacy,
                          ),
                        ],
                      ),
                      if (preview.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8, top: 2),
                          child: Text(
                            preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.primaryTextTheme.titleSmall?.copyWith(
                              color: theme.primaryTextTheme.titleSmall?.color
                                  ?.withValues(alpha: 0.75),
                              height: 1.35,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 12, right: 8),
                        child: ContentMetaFooter(
                          author: widget.note.user,
                          lastModifiedUser: widget.note.lastModifiedUser,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
