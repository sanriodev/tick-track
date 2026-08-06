const String groupEntityType = 'group';

const String groupMembershipEntityType = 'group_membership';

class EventlogMessage<T> {
  final String actionType;
  final String entityType;
  final String entityId;
  final String actionStatus;
  final DateTime date;
  final AcitvityUser user;
  final ActivityGroup? group;

  EventlogMessage({
    required this.actionType,
    required this.entityType,
    required this.entityId,
    required this.actionStatus,
    required this.date,
    required this.user,
    this.group,
  });

  bool get isGroupLeave =>
      entityType == groupMembershipEntityType && actionType == '4';

  String? get groupActivityText {
    final name = group?.name;
    final named = name != null ? '"$name" ' : '';

    if (entityType == groupEntityType && actionType == '1') {
      return '${user.username} hat die Gruppe ${named}erstellt';
    }
    if (entityType == groupMembershipEntityType) {
      return isGroupLeave
          ? '${user.username} hat die Gruppe ${named}verlassen'
          : '${user.username} ist der Gruppe ${named}beigetreten';
    }
    return null;
  }

  factory EventlogMessage.fromJson(Map<String, dynamic> json) {
    return EventlogMessage(
      actionType: json['actionType'] as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      actionStatus: json['actionStatus'] as String,
      user: AcitvityUser.fromJson(json['user'] as Map<String, dynamic>),
      date: DateTime.parse(json['date'] as String),
      group: json['group'] != null
          ? ActivityGroup.fromJson(json['group'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ActivityGroup {
  final int id;
  final String name;

  ActivityGroup({required this.id, required this.name});

  factory ActivityGroup.fromJson(Map<String, dynamic> json) {
    return ActivityGroup(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class EntityEvent<T> {
  T? pre;
  T? post;
  T? entity;
}

class AcitvityUser {
  String username;
  int id;

  AcitvityUser({required this.username, required this.id});

  factory AcitvityUser.fromJson(Map<String, dynamic> json) {
    return AcitvityUser(
      username: json['username'] as String,
      id: json['id'] as int,
    );
  }
}
