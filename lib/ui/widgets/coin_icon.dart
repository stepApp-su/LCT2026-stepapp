import 'package:flutter/material.dart';
import 'game_icon.dart';

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 24});
  final double size;
  @override
  Widget build(BuildContext context) => GameIcon(GameIconKind.coin, size: size);
}
