import 'package:flutter/material.dart';
import 'app_theme.dart';

class AvatarHelper {
  static IconData getIcon(int id) {
    switch (id) {
      case 1: return Icons.face;
      case 2: return Icons.rocket_launch;
      case 3: return Icons.pets;
      case 4: return Icons.star;
      case 5: return Icons.bolt;
      case 6: return Icons.music_note;
      case 7: return Icons.local_cafe;
      case 8: return Icons.menu_book;
      case 9: return Icons.computer;
      default: return Icons.person;
    }
  }

  static Color getColor(String? hex) {
    if (hex == null || hex.isEmpty) return SisapaTheme.blue;
    try {
      return Color(int.parse(hex));
    } catch (e) {
      return SisapaTheme.blue;
    }
  }

  static const List<Color> presetColors = [
    Color(0xFF1DA1F2),
    Colors.redAccent,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pinkAccent,
    Color(0xFF78909C),
    Color(0xFF8B4513),
    Color(0xFF607D8B),
  ];
}
