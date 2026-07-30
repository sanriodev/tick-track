import 'package:flutter/services.dart';

/// Central place for the app's haptic feedback so the whole app stays
/// consistent in how strong a gesture feels. Every call is fire and forget -
/// platforms without a vibration motor simply ignore it.
abstract final class Haptics {
  /// Light tick for reversible toggles: checking off a task, pinning an item.
  static void tick() {
    HapticFeedback.selectionClick();
  }

  /// Slightly heavier tap for a confirmed action, e.g. a successful save.
  static void tap() {
    HapticFeedback.lightImpact();
  }

  /// For destructive or unusual outcomes: deleting an entry, a failed action.
  static void warning() {
    HapticFeedback.mediumImpact();
  }
}
