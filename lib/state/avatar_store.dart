import 'dart:convert';

import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/models/avatar/avatar_model.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Holds the profile pictures the app currently knows about.
///
/// Avatars are read far more often than they change - every member list, every
/// activity entry wants one - so they are cached on the device and only
/// refetched when the backend reports a newer version. Widgets read from the
/// cache synchronously and rebuild through the [ChangeNotifier] once a picture
/// arrives, which keeps them free of per-avatar futures.
class AvatarStore extends ChangeNotifier {
  static final AvatarStore _instance = AvatarStore._privateConstructor();
  factory AvatarStore() => _instance;
  AvatarStore._privateConstructor();

  /// Decoded pictures, kept in memory so a rebuild does not decode base64
  /// again. Only ever holds what the cache box also has.
  final Map<int, Uint8List> _decoded = {};

  /// Users we know have no picture, so their widgets stop asking.
  final Set<int> _withoutAvatar = {};

  /// Requests currently in flight, keyed by the user set they cover, to keep
  /// several avatar widgets appearing at once from firing the same call.
  final Set<int> _inFlight = {};

  Box get _box => Hive.box('avatars');

  /// Pictures of different accounts on the same device stay separate - group
  /// membership decides who may see which avatar.
  String get _accountScope =>
      AuthBackend().loggedInUser?.user?.username ?? '';

  String _dataKey(int userId) => 'data:$_accountScope:$userId';
  String _versionKey(int userId) => 'version:$_accountScope:$userId';

  /// The picture of a user if it is cached, else null. Never triggers a
  /// request - call [sync] for that.
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
      // a corrupt cache entry is not worth an error, drop it and move on
      _box.delete(_dataKey(userId));
      _box.delete(_versionKey(userId));
      return null;
    }
  }

  /// Brings the cache for [userIds] up to date: asks the backend which of them
  /// have a picture and how current it is, then downloads only what changed.
  ///
  /// Safe to call on every screen build cycle - it does nothing when everything
  /// is already current. Failures are swallowed on purpose: a missing avatar
  /// falls back to initials, and no screen should show an error over one.
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

      // everybody the backend did not name has no picture (or is not visible)
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
      // offline or a failing request - the cached state stays as it is
    } finally {
      _inFlight.removeAll(wanted);
    }
  }

  bool _needsDownload(AvatarMeta meta) {
    if (_box.get(_dataKey(meta.userId)) is! String) {
      return true;
    }
    final version = _box.get(_versionKey(meta.userId));
    return version is! String ||
        DateTime.tryParse(version) != meta.updatedAt;
  }

  /// Uploads a new picture for the own account and caches it right away, so
  /// the change is visible without a round trip.
  Future<void> setOwn(String imageBase64) async {
    final meta = await Backend().setOwnAvatar(imageBase64);
    await _store(meta.userId, imageBase64, meta.updatedAt);
    notifyListeners();
  }

  /// Removes the picture of the own account.
  ///
  /// [userId] has to be passed in because the cached session only carries the
  /// username - the id comes from the loaded profile.
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
    // the upload may carry a data: prefix, the cache stores the payload only
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

  /// Drops a user from the cache, returning whether anything was there.
  bool _forget(int userId) {
    final had = _decoded.remove(userId) != null ||
        _box.get(_dataKey(userId)) != null;
    _box.delete(_dataKey(userId));
    _box.delete(_versionKey(userId));
    return had;
  }

  /// Called on logout: the next account must not see the previous one's
  /// pictures. The box keeps its per-account entries, only the memory state
  /// and the "has no avatar" knowledge are reset.
  void clear() {
    _decoded.clear();
    _withoutAvatar.clear();
    _inFlight.clear();
    notifyListeners();
  }
}
