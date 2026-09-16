import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/models/calendar/calendar_event_model.dart';
import 'package:ticktrack/models/note/note_api_model.dart';
import 'package:ticktrack/util/calendar_export_helper.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/note_export_helper.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareNote(BuildContext context, Note note) async {
  final origin = _originRect(context);

  try {
    final files = await exportNoteAsMarkdown(note);
    await SharePlus.instance.share(
      ShareParams(
        files: files,
        subject: note.title,
        sharePositionOrigin: origin,
      ),
    );
    Haptics.tap();
  } catch (e) {
    if (context.mounted) {
      _showFailure(context, e);
    }
  }
}

Future<void> shareCalendar(
  BuildContext context, {
  required List<CalendarEvent> events,
  required String calendarName,
}) async {
  final origin = _originRect(context);

  try {
    final file = await exportCalendarAsIcs(
      events: events,
      calendarName: calendarName,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        subject: calendarName,
        sharePositionOrigin: origin,
      ),
    );
    Haptics.tap();
  } catch (e) {
    if (context.mounted) {
      _showFailure(context, e);
    }
  }
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
      _showFailure(context, e);
    }
  }
}

void _showFailure(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.shareFailed('$error'))),
  );
}

Rect? _originRect(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) {
    return null;
  }
  return box.localToGlobal(Offset.zero) & box.size;
}
