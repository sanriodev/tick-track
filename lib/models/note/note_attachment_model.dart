const String attachmentUriScheme = 'tt-attachment';

class NoteAttachment {
  final int id;
  final int noteId;
  final int width;
  final int height;
  final int byteSize;
  final String mimeType;

  NoteAttachment({
    required this.id,
    required this.noteId,
    required this.width,
    required this.height,
    required this.byteSize,
    required this.mimeType,
  });

  factory NoteAttachment.fromJson(Map<String, dynamic> json) {
    return NoteAttachment(
      id: json['id'] as int,
      noteId: json['noteId'] as int,
      width: json['width'] as int,
      height: json['height'] as int,
      byteSize: json['byteSize'] as int,
      mimeType: json['mimeType'] as String,
    );
  }

  String get markdownReference => '![]($attachmentUriScheme:$id)';

  double get aspectRatio => height == 0 ? 1 : width / height;
}

class NoteAttachmentData extends NoteAttachment {
  final String imageBase64;

  NoteAttachmentData({
    required super.id,
    required super.noteId,
    required super.width,
    required super.height,
    required super.byteSize,
    required super.mimeType,
    required this.imageBase64,
  });

  factory NoteAttachmentData.fromJson(Map<String, dynamic> json) {
    return NoteAttachmentData(
      id: json['id'] as int,
      noteId: json['noteId'] as int,
      width: json['width'] as int,
      height: json['height'] as int,
      byteSize: json['byteSize'] as int,
      mimeType: json['mimeType'] as String,
      imageBase64: json['imageBase64'] as String,
    );
  }
}
