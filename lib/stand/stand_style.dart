import 'package:flutter/material.dart';

class StandStyle {
  const StandStyle(this.name, this.accent, this.surface, this.rail,
      {this.dark = false,
      this.darkRail = false,
      this.radius = 10,
      this.actionMode = 0,
      this.filledIcons = false});
  final String name;
  final Color accent, surface, rail;
  final bool dark, darkRail, filledIcons;
  final double radius;
  final int actionMode;

  static const contrast = StandStyle(
      'Контраст', Color(0xff385ed1), Colors.white, Color(0xff202b40),
      darkRail: true, actionMode: 1);
}
