class BlockedUser {
  final int id;
  final String username;

  BlockedUser({required this.id, required this.username});

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      id: int.parse(json['id'].toString()),
      username: json['username'] as String,
    );
  }
}
