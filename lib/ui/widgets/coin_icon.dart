import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/finni_theme.dart';

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 24});
  final double size;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _CoinPainter());
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);
    canvas.drawCircle(
        const Offset(12, 12), 10, Paint()..color = FinniColors.honey);
    canvas.drawCircle(
        const Offset(12, 12),
        9,
        Paint()
          ..color = FinniColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8);
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5, r = i.isEven ? 5.1 : 2.4;
      final x = 12 + math.cos(angle) * r, y = 12 + math.sin(angle) * r;
      if (i == 0) {
        star.moveTo(x, y);
      } else {
        star.lineTo(x, y);
      }
    }
    canvas.drawPath(star..close(), Paint()..color = FinniColors.gold);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CoinPainter old) => false;
}
