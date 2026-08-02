import 'package:flutter/material.dart';

/// The colour an event can be marked with.
///
/// Names rather than stored colour values, so each one can be rendered with a
/// shade that suits the active theme: the app is otherwise greyscale, and a
/// tone that reads well on the light background is far too dark on the dark one.
enum EventColor {
  blue,
  teal,
  green,
  yellow,
  orange,
  red,
  purple,
  pink;

  String toJson() => name;

  /// Unknown or missing values become null - an event simply has no colour then.
  static EventColor? fromJson(dynamic json) {
    if (json is String) {
      for (final value in EventColor.values) {
        if (value.name == json) {
          return value;
        }
      }
    }
    return null;
  }

  String get label => switch (this) {
        EventColor.blue => 'Blau',
        EventColor.teal => 'Türkis',
        EventColor.green => 'Grün',
        EventColor.yellow => 'Gelb',
        EventColor.orange => 'Orange',
        EventColor.red => 'Rot',
        EventColor.purple => 'Lila',
        EventColor.pink => 'Pink',
      };

  /// Darker on light backgrounds, lighter on dark ones.
  Color resolve(Brightness brightness) {
    final light = brightness == Brightness.light;
    return switch (this) {
      EventColor.blue =>
        light ? const Color(0xFF2563EB) : const Color(0xFF60A5FA),
      EventColor.teal =>
        light ? const Color(0xFF0D9488) : const Color(0xFF2DD4BF),
      EventColor.green =>
        light ? const Color(0xFF16A34A) : const Color(0xFF4ADE80),
      EventColor.yellow =>
        light ? const Color(0xFFCA8A04) : const Color(0xFFFACC15),
      EventColor.orange =>
        light ? const Color(0xFFEA580C) : const Color(0xFFFB923C),
      EventColor.red =>
        light ? const Color(0xFFDC2626) : const Color(0xFFF87171),
      EventColor.purple =>
        light ? const Color(0xFF7C3AED) : const Color(0xFFA78BFA),
      EventColor.pink =>
        light ? const Color(0xFFDB2777) : const Color(0xFFF472B6),
    };
  }
}

/// The colour to paint an event with, falling back to the theme's own accent
/// for events nobody coloured.
Color eventColorOf(BuildContext context, EventColor? color) =>
    color?.resolve(Theme.of(context).brightness) ?? Theme.of(context).primaryColor;
