import 'dart:io';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';
import 'package:ticktrack/models/note/note_api_model.dart';
import 'package:ticktrack/models/note/note_attachment_model.dart';
import 'package:ticktrack/state/note_attachment_store.dart';
import 'package:ticktrack/util/export_helper.dart';
import 'package:ticktrack/util/markdown_helper.dart';

const String _exportDirectoryName = 'note-export';
const String _markdownMimeType = 'text/markdown';

class _ExportAttachment {
  final NoteAttachment meta;
  final Uint8List bytes;

  const _ExportAttachment({required this.meta, required this.bytes});

  String get fileName => 'anhang-${meta.id}.${meta.fileExtension}';
}

Future<List<XFile>> exportNoteAsMarkdown(Note note) async {
  final attachments = await _loadReferencedAttachments(note);
  final directory = await prepareExportDirectory(_exportDirectoryName);

  final attachmentFiles = <XFile>[];
  for (final attachment in attachments) {
    attachmentFiles.add(await _writeAttachment(directory, attachment));
  }

  final markdownFile = await _writeMarkdown(
    directory,
    note,
    buildNoteMarkdownExport(note, _fileNamesById(attachments)),
  );

  return [markdownFile, ...attachmentFiles];
}

String buildNoteMarkdownExport(
  Note note,
  Map<int, String> attachmentFileNames,
) {
  final heading = '# ${note.title.trim()}';
  final body = rewriteAttachmentReferences(
    note.content?.trim() ?? '',
    attachmentFileNames,
  );

  return body.isEmpty ? '$heading\n' : '$heading\n\n$body\n';
}

Map<int, String> _fileNamesById(List<_ExportAttachment> attachments) {
  return {
    for (final attachment in attachments)
      attachment.meta.id: attachment.fileName,
  };
}

Future<List<_ExportAttachment>> _loadReferencedAttachments(Note note) async {
  final store = NoteAttachmentStore();
  final attachments = <_ExportAttachment>[];

  for (final attachmentId in referencedAttachmentIds(note.content ?? '')) {
    await _ensureLoaded(store, attachmentId);
    final meta = store.metaFor(attachmentId);
    final bytes = store.bytesFor(attachmentId);
    if (meta != null && bytes != null) {
      attachments.add(_ExportAttachment(meta: meta, bytes: bytes));
    }
  }

  return attachments;
}

Future<void> _ensureLoaded(NoteAttachmentStore store, int attachmentId) async {
  if (store.bytesFor(attachmentId) != null) {
    return;
  }
  await store.load(attachmentId);
}

Future<XFile> _writeMarkdown(
  Directory directory,
  Note note,
  String markdown,
) async {
  final fileName =
      '${safeFileName(note.title, fallback: 'notiz-${note.id}')}.md';
  final file = File('${directory.path}/$fileName');
  await file.writeAsString(markdown);

  return XFile(file.path, mimeType: _markdownMimeType, name: fileName);
}

Future<XFile> _writeAttachment(
  Directory directory,
  _ExportAttachment attachment,
) async {
  final file = File('${directory.path}/${attachment.fileName}');
  await file.writeAsBytes(attachment.bytes);

  return XFile(
    file.path,
    mimeType: attachment.meta.mimeType,
    name: attachment.fileName,
  );
}
