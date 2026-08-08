import 'package:ticktrack/state/note_attachment_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class NoteAttachmentImage extends StatefulWidget {
  final int attachmentId;

  const NoteAttachmentImage({super.key, required this.attachmentId});

  @override
  State<NoteAttachmentImage> createState() => _NoteAttachmentImageState();
}

class _NoteAttachmentImageState extends State<NoteAttachmentImage> {
  @override
  void initState() {
    super.initState();
    NoteAttachmentStore().addListener(_onStoreChanged);
    NoteAttachmentStore().load(widget.attachmentId);
  }

  @override
  void didUpdateWidget(NoteAttachmentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachmentId != widget.attachmentId) {
      NoteAttachmentStore().load(widget.attachmentId);
    }
  }

  @override
  void dispose() {
    NoteAttachmentStore().removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = NoteAttachmentStore();
    final bytes = store.bytesFor(widget.attachmentId);

    if (bytes != null) {
      return _buildImage(bytes);
    }
    if (store.isUnavailable(widget.attachmentId)) {
      return _buildUnavailable(Theme.of(context));
    }
    return _buildPlaceholder(Theme.of(context));
  }

  Widget _buildImage(Uint8List bytes) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(bytes, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AspectRatio(
        aspectRatio: _knownAspectRatio ?? 4 / 3,
        child: Container(
          decoration: BoxDecoration(
            color: theme.canvasColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnavailable(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.canvasColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            PhosphorIcon(
              PhosphorIconsRegular.imageBroken,
              size: 18,
              color: theme.primaryIconTheme.color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bild nicht verfügbar',
                style: theme.primaryTextTheme.displayMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double? get _knownAspectRatio =>
      NoteAttachmentStore().metaFor(widget.attachmentId)?.aspectRatio;
}
