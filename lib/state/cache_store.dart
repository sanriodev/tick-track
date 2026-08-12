import 'dart:convert';

import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

class CacheKey {
  static String note(int id) => 'note:$id';
  static String notes(int? groupId) => 'notes:${_scope(groupId)}';
  static String taskLists(int? groupId) => 'taskLists:${_scope(groupId)}';
  static String tasksForList(int listId) => 'tasks:$listId';
  static String groups() => 'groups';
  static String ownUser() => 'ownUser';

  static String activity(int? groupId, String mode) =>
      'activity:${_scope(groupId)}:$mode';

  static String calendarMonth(int? groupId, DateTime month) =>
      'calendarMonth:${_scope(groupId)}:${month.year}-${month.month}';

  static String upcomingEvents(int? groupId) =>
      'upcomingEvents:${_scope(groupId)}';

  static String _scope(int? groupId) => groupId?.toString() ?? 'self';
}

class CachedEntry<T> {
  final List<T> items;
  final DateTime writtenAt;

  const CachedEntry({required this.items, required this.writtenAt});
}

class CachedItem<T> {
  final T item;
  final DateTime writtenAt;

  const CachedItem({required this.item, required this.writtenAt});
}

class CacheStore {
  static final CacheStore _instance = CacheStore._privateConstructor();
  factory CacheStore() => _instance;
  CacheStore._privateConstructor();

  static const String boxName = 'apiCache';
  static const String _encryptionKeyName = 'cacheEncryptionKey';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<void> openBox() async {
    final HiveAesCipher cipher = HiveAesCipher(await _encryptionKey());
    try {
      await Hive.openBox(boxName, encryptionCipher: cipher);
    } catch (_) {
      await Hive.deleteBoxFromDisk(boxName);
      await Hive.openBox(boxName, encryptionCipher: cipher);
    }
  }

  static Future<List<int>> _encryptionKey() async {
    final String? stored = await _secureStorage.read(key: _encryptionKeyName);
    if (stored != null) {
      return base64Url.decode(stored);
    }

    final List<int> key = Hive.generateSecureKey();
    await _secureStorage.write(
      key: _encryptionKeyName,
      value: base64UrlEncode(key),
    );

    return key;
  }

  Box get _box => Hive.box(boxName);

  String _userScopedKey(String key) =>
      '${AuthBackend().loggedInUser?.user?.username ?? ''}|$key';

  Future<void> writeList(String key, List<Object> items) async {
    await _write(key, items);
  }

  Future<void> writeItem(String key, Object item) async {
    await _write(key, item);
  }

  Future<void> _write(String key, Object data) async {
    final payload = <String, dynamic>{
      'writtenAt': DateTime.now().toIso8601String(),
      'data': data,
    };
    await _box.put(_userScopedKey(key), jsonEncode(payload));
  }

  CachedItem<T>? readItem<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final payload = _decodePayload(key);
    final raw = payload?['data'];
    if (payload == null || raw is! Map<String, dynamic>) {
      return null;
    }

    return CachedItem<T>(
      item: fromJson(raw),
      writtenAt: payload['writtenAt'] as DateTime,
    );
  }

  CachedEntry<T>? readList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final payload = _decodePayload(key);
    final raw = payload?['data'];
    if (payload == null || raw is! List<dynamic>) {
      return null;
    }

    return CachedEntry<T>(
      items: raw.map((e) => fromJson(e as Map<String, dynamic>)).toList(),
      writtenAt: payload['writtenAt'] as DateTime,
    );
  }

  Map<String, dynamic>? _decodePayload(String key) {
    final stored = _box.get(_userScopedKey(key));
    if (stored is! String) {
      return null;
    }

    try {
      final decoded = jsonDecode(stored) as Map<String, dynamic>;
      final writtenAt = DateTime.tryParse('${decoded['writtenAt']}');
      if (writtenAt == null) {
        return null;
      }
      return <String, dynamic>{'writtenAt': writtenAt, 'data': decoded['data']};
    } on FormatException {
      return null;
    }
  }

  Future<void> clear() async {
    await _box.clear();
  }
}
