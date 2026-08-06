import 'package:flutter/material.dart';

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

Color eventColorOf(BuildContext context, EventColor? color) =>
    color?.resolve(Theme.of(context).brightness) ??
    Theme.of(context).primaryColor;
