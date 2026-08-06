import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/models/group/group_api_model.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

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

  void clear() {
    _groups = [];
    _activeGroup = null;
  }
}
