import 'package:ticktrack/models/note/note_api_model.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareNote(BuildContext context, Note note) {
  final content = note.content?.trim() ?? '';
  return shareText(
    context,
    content.isEmpty ? note.title : '${note.title}\n\n$content',
    subject: note.title,
  );
}

Future<void> shareText(
  BuildContext context,
  String text, {
  String? subject,
}) async {
  if (text.trim().isEmpty) {
    return;
  }

  try {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
        sharePositionOrigin: _originRect(context),
      ),
    );
    Haptics.tap();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Teilen fehlgeschlagen: $e')),
      );
    }
  }
}

Rect? _originRect(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) {
    return null;
  }
  return box.localToGlobal(Offset.zero) & box.size;
}
