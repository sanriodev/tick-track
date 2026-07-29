/// A user the logged in user has blocked, as returned by the block endpoint.
class BlockedUser {
  final int id;
  final String username;

  BlockedUser({required this.id, required this.username});

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      // the backend serializes the id as a string
      id: int.parse(json['id'].toString()),
      username: json['username'] as String,
    );
  }
}
