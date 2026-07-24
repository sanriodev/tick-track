import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/models/group/group_api_model.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Holds the group context of the logged in user. All content (notes,
/// task lists, activity) is created and loaded for the active group.
/// Screens listen to this notifier and reload when the context changes.
class GroupContext extends ChangeNotifier {
  static final GroupContext _instance = GroupContext._privateConstructor();
  factory GroupContext() => _instance;
  GroupContext._privateConstructor();

  List<Group> _groups = [];
  Group? _activeGroup;

  List<Group> get groups => _groups;
  Group? get activeGroup => _activeGroup;
  bool get hasGroups => _groups.isNotEmpty;
  bool get hasMultipleGroups => _groups.length > 1;

  String get _storageKey =>
      'activeGroupId:${AuthBackend().loggedInUser?.user?.username ?? ''}';

  /// Reloads the groups from the backend and restores or corrects the
  /// active group selection.
  Future<void> refresh() async {
    _groups = await Backend().getMyGroups();

    final box = Hive.box('groupContext');
    final storedId = _activeGroup?.id ?? box.get(_storageKey) as int?;

    Group? active;
    if (storedId != null) {
      for (final group in _groups) {
        if (group.id == storedId) {
          active = group;
        }
      }
    }
    active ??= _groups.isNotEmpty ? _groups.first : null;
    await _persistActive(active);
    notifyListeners();
  }

  Future<void> setActiveGroup(Group group) async {
    if (_activeGroup?.id == group.id) {
      return;
    }
    await _persistActive(group);
    notifyListeners();
  }

  Future<void> _persistActive(Group? group) async {
    _activeGroup = group;
    final box = Hive.box('groupContext');
    if (group != null) {
      await box.put(_storageKey, group.id);
    } else {
      await box.delete(_storageKey);
    }
  }

  /// Resets the in-memory state on logout. The persisted selection is kept
  /// so it can be restored on the next login of the same user.
  void clear() {
    _groups = [];
    _activeGroup = null;
  }
}
