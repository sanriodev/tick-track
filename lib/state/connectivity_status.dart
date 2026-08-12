import 'package:flutter/foundation.dart';

class ConnectivityStatus extends ChangeNotifier {
  static final ConnectivityStatus _instance =
      ConnectivityStatus._privateConstructor();
  factory ConnectivityStatus() => _instance;
  ConnectivityStatus._privateConstructor();

  bool _backendReachable = true;
  DateTime? _unreachableSince;

  bool get backendReachable => _backendReachable;
  DateTime? get unreachableSince => _unreachableSince;

  void reportReachable() {
    if (_backendReachable) {
      return;
    }
    _backendReachable = true;
    _unreachableSince = null;
    notifyListeners();
  }

  void reportUnreachable() {
    if (!_backendReachable) {
      return;
    }
    _backendReachable = false;
    _unreachableSince = DateTime.now();
    notifyListeners();
  }

  void reset() {
    _backendReachable = true;
    _unreachableSince = null;
  }
}
