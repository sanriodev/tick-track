/// Entity type the backend logs a group creation under.
const String groupEntityType = 'group';

/// Entity type the backend logs joining/leaving a group under.
const String groupMembershipEntityType = 'group_membership';

class EventlogMessage<T> {
  final String actionType;
  final String entityType;
  final String entityId;
  // final EntityEvent<T> data;
  final String actionStatus;
  final DateTime date;
  final AcitvityUser user;
  final ActivityGroup? group;
  // final User? auth;

  EventlogMessage({
    required this.actionType,
    required this.entityType,
    required this.entityId,
    // required this.data,
    required this.actionStatus,
    required this.date,
    required this.user,
    this.group,
    // this.auth,
  });

  /// Someone left a group - the only membership event that is not a join.
  bool get isGroupLeave =>
      entityType == groupMembershipEntityType && actionType == '4';

  /// Ready made sentence for the group lifecycle events (created / joined /
  /// left), null for everything else. The group name is left out when the
  /// backend could not resolve it.
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

      // auth: json['auth'] != null
      //     ? User.fromJson(json['auth'] as Map<String, dynamic>)
      //     : null,
    );
  }
}

/// The group an activity happened in. Null on the message when the backend
/// could not resolve it (e.g. deletions or activity from before groups).
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
