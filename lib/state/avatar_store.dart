import 'dart:convert';

import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/models/avatar/avatar_model.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class AvatarStore extends ChangeNotifier {
  static final AvatarStore _instance = AvatarStore._privateConstructor();
  factory AvatarStore() => _instance;
  AvatarStore._privateConstructor();

  final Map<int, Uint8List> _decoded = {};

  final Set<int> _withoutAvatar = {};

  final Set<int> _inFlight = {};

  Box get _box => Hive.box('avatars');

  String get _accountScope => AuthBackend().loggedInUser?.user?.username ?? '';

  String _dataKey(int userId) => 'data:$_accountScope:$userId';
  String _versionKey(int userId) => 'version:$_accountScope:$userId';

  Uint8List? bytesFor(int userId) {
    final cached = _decoded[userId];
    if (cached != null) {
      return cached;
    }
    if (_withoutAvatar.contains(userId)) {
      return null;
    }

    final stored = _box.get(_dataKey(userId));
    if (stored is! String || stored.isEmpty) {
      return null;
    }
    try {
      final bytes = base64Decode(stored);
      _decoded[userId] = bytes;
      return bytes;
    } catch (_) {
      _box.delete(_dataKey(userId));
      _box.delete(_versionKey(userId));
      return null;
    }
  }

  Future<void> sync(Iterable<int> userIds) async {
    final wanted =
        userIds.where((id) => !_inFlight.contains(id)).toSet().toList();
    if (wanted.isEmpty) {
      return;
    }
    _inFlight.addAll(wanted);

    try {
      final metas = await Backend().getAvatarMeta(wanted);
      final withAvatar = {for (final meta in metas) meta.userId: meta};

      var changed = false;
      for (final userId in wanted) {
        if (!withAvatar.containsKey(userId)) {
          changed |= _forget(userId);
          _withoutAvatar.add(userId);
        }
      }

      final stale = withAvatar.values.where(_needsDownload).toList();
      for (final meta in stale) {
        final avatar = await Backend().getAvatar(meta.userId);
        if (avatar == null) {
          changed |= _forget(meta.userId);
          _withoutAvatar.add(meta.userId);
          continue;
        }
        await _store(avatar.userId, avatar.imageBase64, avatar.updatedAt);
        changed = true;
      }

      if (changed) {
        notifyListeners();
      }
    } catch (_) {
    } finally {
      _inFlight.removeAll(wanted);
    }
  }

  bool _needsDownload(AvatarMeta meta) {
    if (_box.get(_dataKey(meta.userId)) is! String) {
      return true;
    }
    final version = _box.get(_versionKey(meta.userId));
    return version is! String || DateTime.tryParse(version) != meta.updatedAt;
  }

  Future<void> setOwn(String imageBase64) async {
    final meta = await Backend().setOwnAvatar(imageBase64);
    await _store(meta.userId, imageBase64, meta.updatedAt);
    notifyListeners();
  }

  Future<void> removeOwn(int userId) async {
    await Backend().deleteOwnAvatar();
    _forget(userId);
    _withoutAvatar.add(userId);
    notifyListeners();
  }

  Future<void> _store(
    int userId,
    String imageBase64,
    DateTime updatedAt,
  ) async {
    final payload =
        imageBase64.replaceFirst(RegExp('^data:[^;,]*(;[^,]*)*,'), '');
    await _box.put(_dataKey(userId), payload);
    await _box.put(_versionKey(userId), updatedAt.toIso8601String());
    _withoutAvatar.remove(userId);
    try {
      _decoded[userId] = base64Decode(payload);
    } catch (_) {
      _decoded.remove(userId);
    }
  }

  bool _forget(int userId) {
    final had =
        _decoded.remove(userId) != null || _box.get(_dataKey(userId)) != null;
    _box.delete(_dataKey(userId));
    _box.delete(_versionKey(userId));
    return had;
  }

  void clear() {
    _decoded.clear();
    _withoutAvatar.clear();
    _inFlight.clear();
    notifyListeners();
  }
}
