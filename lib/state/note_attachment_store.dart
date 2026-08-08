import 'dart:convert';

import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/models/note/note_attachment_model.dart';
import 'package:flutter/foundation.dart';

class NoteAttachmentStore extends ChangeNotifier {
  static final NoteAttachmentStore _instance =
      NoteAttachmentStore._privateConstructor();
  factory NoteAttachmentStore() => _instance;
  NoteAttachmentStore._privateConstructor();

  final Map<int, Uint8List> _decodedById = {};
  final Map<int, NoteAttachment> _metaById = {};
  final Set<int> _unavailableIds = {};
  final Set<int> _loadingIds = {};

  Uint8List? bytesFor(int attachmentId) => _decodedById[attachmentId];

  NoteAttachment? metaFor(int attachmentId) => _metaById[attachmentId];

  bool isUnavailable(int attachmentId) =>
      _unavailableIds.contains(attachmentId);

  bool isLoading(int attachmentId) => _loadingIds.contains(attachmentId);

  Future<List<NoteAttachment>> loadForNote(int noteId) async {
    final attachments = await Backend().getNoteAttachments(noteId);
    for (final attachment in attachments) {
      _metaById[attachment.id] = attachment;
    }
    notifyListeners();
    return attachments;
  }

  Future<void> load(int attachmentId) async {
    if (_shouldSkipLoading(attachmentId)) {
      return;
    }
    _loadingIds.add(attachmentId);
    try {
      final attachment = await Backend().getNoteAttachment(attachmentId);
      if (attachment == null) {
        _unavailableIds.add(attachmentId);
      } else {
        _remember(attachment);
      }
    } catch (error) {
      debugPrint('Attachment $attachmentId could not be loaded: $error');
      _unavailableIds.add(attachmentId);
    } finally {
      _loadingIds.remove(attachmentId);
      notifyListeners();
    }
  }

  bool _shouldSkipLoading(int attachmentId) {
    return _decodedById.containsKey(attachmentId) ||
        _loadingIds.contains(attachmentId) ||
        _unavailableIds.contains(attachmentId);
  }

  void _remember(NoteAttachmentData attachment) {
    _metaById[attachment.id] = attachment;
    _unavailableIds.remove(attachment.id);
    try {
      _decodedById[attachment.id] = base64Decode(attachment.imageBase64);
    } catch (error) {
      debugPrint('Attachment ${attachment.id} is not decodable: $error');
      _unavailableIds.add(attachment.id);
    }
  }

  void rememberUpload(NoteAttachment attachment, Uint8List bytes) {
    _metaById[attachment.id] = attachment;
    _decodedById[attachment.id] = bytes;
    _unavailableIds.remove(attachment.id);
    notifyListeners();
  }

  void forget(int attachmentId) {
    _decodedById.remove(attachmentId);
    _metaById.remove(attachmentId);
    _unavailableIds.remove(attachmentId);
    notifyListeners();
  }

  void clear() {
    _decodedById.clear();
    _metaById.clear();
    _unavailableIds.clear();
    _loadingIds.clear();
    notifyListeners();
  }
}
