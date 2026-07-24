class CreateNoteDto {
  String title;
  String? content;
  int? groupId;

  CreateNoteDto({
    required this.title,
    this.content,
    this.groupId,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      if (groupId != null) 'groupId': groupId,
    };
  }
}
