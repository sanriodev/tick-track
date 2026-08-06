class AvatarMeta {
  final int userId;
  final DateTime updatedAt;

  AvatarMeta({
    required this.userId,
    required this.updatedAt,
  });

  factory AvatarMeta.fromJson(Map<String, dynamic> json) {
    return AvatarMeta(
      userId: int.parse('${json['userId']}'),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class Avatar extends AvatarMeta {
  final String mimeType;
  final String imageBase64;

  Avatar({
    required super.userId,
    required super.updatedAt,
    required this.mimeType,
    required this.imageBase64,
  });

  factory Avatar.fromJson(Map<String, dynamic> json) {
    return Avatar(
      userId: int.parse('${json['userId']}'),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      mimeType: json['mimeType'] as String,
      imageBase64: json['imageBase64'] as String,
    );
  }
}
