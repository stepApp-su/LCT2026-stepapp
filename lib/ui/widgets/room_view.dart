import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../theme/finni_theme.dart';
import 'emoji_art.dart';

class RoomPiece {
  const RoomPiece(this.spot, this.artId);
  final RoomSpot spot;
  final String artId;
}

class RoomLayer extends StatelessWidget {
  const RoomLayer({
    super.key,
    required this.pieces,
    this.front = false,
    this.wallpaperId,
    this.window = false,
  });

  static const int petZ = 22;

  final List<RoomPiece> pieces;
  final bool front;
  final String? wallpaperId;
  final bool window;

  static double unit(Size size) => math.min(size.width, size.height * 1.53);

  static Rect rectOf(RoomSpot spot, Size size) {
    final w = (spot.size ?? .14) * unit(size);
    return Rect.fromLTWH((spot.x ?? .5) * size.width - w / 2,
        (spot.y ?? 1) * size.height - w, w, w);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final shown = [
          for (final piece in pieces)
            if (((piece.spot.z ?? 0) > petZ) == front) piece
        ]..sort((a, b) => (a.spot.z ?? 0).compareTo(b.spot.z ?? 0));
        return Stack(clipBehavior: Clip.none, children: [
          if (!front && wallpaperId != null)
            Positioned.fill(
                child: CustomPaint(painter: WallpaperPainter(wallpaperId!))),
          if (!front && window)
            Positioned(
              left: size.width * .70,
              top: size.height * .17,
              width: size.width * .24,
              height: size.height * .31,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [FinniColors.sky, FinniColors.paper],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: FinniColors.paper, width: 4),
                ),
              ),
            ),
          for (final piece in shown)
            Positioned.fromRect(
              rect: rectOf(piece.spot, size),
              child: RoomArt(piece.artId, size: rectOf(piece.spot, size).width),
            ),
        ]);
      });
}

class WallpaperPainter extends CustomPainter {
  const WallpaperPainter(this.id);

  final String id;

  static Color baseOf(String id) => switch (id) {
        'wp_stripes' => FinniColors.paper,
        'wp_dots' => FinniColors.lavender,
        'wp_clouds' => FinniColors.sky,
        'wp_leaves' => FinniColors.mint,
        'wp_stars' => FinniColors.honey,
        'wp_space' => FinniColors.nightMid,
        _ => FinniColors.mint.withValues(alpha: .5),
      };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = baseOf(id));
    final step = math.max(18.0, size.width / 9);
    switch (id) {
      case 'wp_stripes':
        final paint = Paint()..color = FinniColors.mint;
        for (var x = 0.0; x < size.width; x += step) {
          canvas.drawRect(Rect.fromLTWH(x, 0, step / 2, size.height), paint);
        }
      case 'wp_dots':
        final paint = Paint()..color = FinniColors.paper.withValues(alpha: .8);
        for (var y = step / 2; y < size.height; y += step) {
          for (var x = step / 2; x < size.width; x += step) {
            canvas.drawCircle(Offset(x, y), step * .16, paint);
          }
        }
      case 'wp_clouds':
        final paint = Paint()..color = FinniColors.paper;
        for (final (fx, fy) in const [(.18, .22), (.55, .12), (.36, .5), (.82, .62), (.1, .74)]) {
          final c = Offset(size.width * fx, size.height * fy);
          final r = step * .45;
          canvas.drawCircle(c, r, paint);
          canvas.drawCircle(c + Offset(r * .9, r * .2), r * .75, paint);
          canvas.drawCircle(c - Offset(r * .9, -r * .2), r * .7, paint);
        }
      case 'wp_leaves' || 'wp_stars' || 'wp_space':
        final glyph = switch (id) {
          'wp_leaves' => '🍃',
          'wp_stars' => '⭐',
          _ => '✦',
        };
        final painter = TextPainter(
          text: TextSpan(
              text: glyph,
              style: TextStyle(
                  fontSize: step * .42,
                  color: id == 'wp_space' ? FinniColors.star : null)),
          textDirection: TextDirection.ltr,
        )..layout();
        var row = 0;
        for (var y = step / 3; y < size.height; y += step, row++) {
          for (var x = row.isEven ? step / 3 : step; x < size.width; x += step * 1.4) {
            painter.paint(canvas, Offset(x, y));
          }
        }
        painter.dispose();
    }
  }

  @override
  bool shouldRepaint(WallpaperPainter oldDelegate) => oldDelegate.id != id;
}
