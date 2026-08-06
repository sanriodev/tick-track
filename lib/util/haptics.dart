import 'package:flutter/services.dart';

abstract final class Haptics {
  static void tick() {
    HapticFeedback.selectionClick();
  }

  static void tap() {
    HapticFeedback.lightImpact();
  }

  static void warning() {
    HapticFeedback.mediumImpact();
  }
}
