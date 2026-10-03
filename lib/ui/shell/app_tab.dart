import 'package:flutter/material.dart';

enum AppTab {
  search(label: 'Search', icon: Icons.search, selectedIcon: Icons.search),
  favorites(label: 'Stars', icon: Icons.star_border, selectedIcon: Icons.star);

  const AppTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
