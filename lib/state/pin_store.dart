import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Keeps track of the notes and task lists the user pinned to the top of
/// their overviews.
///
/// Pins are a personal preference, not a property of the content - a note
/// shared inside a group can be pinned by one member without showing up
/// pinned for everyone else. They are therefore stored on the device and
/// scoped to the logged in account instead of going through the backend.
class PinStore extends ChangeNotifier {
  static final PinStore _instance = PinStore._privateConstructor();
  factory PinStore() => _instance;
  PinStore._privateConstructor();

  static const String noteKind = 'note';
  static const String taskListKind = 'task_list';

  Box get _box => Hive.box('pins');

  /// Pins of different accounts on the same device stay separate.
  String get _storageKey =>
      'pinned:${AuthBackend().loggedInUser?.user?.username ?? ''}';

  Set<String> get _pins {
    final stored = _box.get(_storageKey);
    if (stored is List) {
      return stored.map((e) => '$e').toSet();
    }
    return <String>{};
  }

  String _entryFor(String kind, int id) => '$kind:$id';

  bool isPinned(String kind, int id) => _pins.contains(_entryFor(kind, id));

  /// Flips the pin state and returns whether the item is pinned afterwards.
  Future<bool> toggle(String kind, int id) async {
    final pins = _pins;
    final entry = _entryFor(kind, id);
    final pinned = !pins.contains(entry);

    if (pinned) {
      pins.add(entry);
    } else {
      pins.remove(entry);
    }
    await _box.put(_storageKey, pins.toList());
    notifyListeners();

    return pinned;
  }

  /// Drops pins whose content no longer exists so the box cannot grow
  /// forever. [existingIds] are all ids of [kind] currently known for the
  /// active group context, so this is only safe to call with a freshly
  /// loaded, unfiltered list.
  Future<void> pruneMissing(String kind, Iterable<int> existingIds) async {
    final ids = existingIds.toSet();
    final pins = _pins;
    final stale = pins
        .where((entry) => entry.startsWith('$kind:'))
        .where((entry) => !ids.contains(int.tryParse(entry.split(':').last)))
        .toList();

    if (stale.isEmpty) {
      return;
    }
    pins.removeAll(stale);
    await _box.put(_storageKey, pins.toList());
    notifyListeners();
  }

  /// Splits a list into the pinned entries and the rest, both keeping the
  /// order they came in with.
  ({List<T> pinned, List<T> others}) partition<T>(
    String kind,
    List<T> items,
    int Function(T item) idOf,
  ) {
    final pinned = <T>[];
    final others = <T>[];
    for (final item in items) {
      if (isPinned(kind, idOf(item))) {
        pinned.add(item);
      } else {
        others.add(item);
      }
    }
    return (pinned: pinned, others: others);
  }
}
