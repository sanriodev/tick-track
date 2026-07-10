import 'package:blvckleg_dart_core/models/user/user_model.dart';

class Group {
  int id;
  String name;
  String joinCode;
  int? ownerId;
  List<User> members;

  Group({
    required this.id,
    required this.name,
    required this.joinCode,
    this.ownerId,
    this.members = const [],
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as int,
      name: json['name'] as String,
      joinCode: json['joinCode'] as String,
      ownerId: json['ownerId'] as int?,
      members: json['members'] != null
          ? (json['members'] as List<dynamic>)
              .map((e) => User.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'joinCode': joinCode,
      'ownerId': ownerId,
      'members': members.map((e) => e.toJson()).toList(),
    };
  }
}
