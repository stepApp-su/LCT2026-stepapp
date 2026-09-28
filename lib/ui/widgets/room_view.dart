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

  static Offset markerOf(RoomSpot spot, Size size) => switch (spot.id) {
        'floor_rug' => Offset(size.width * .50, size.height * .80),
        'middle_right' => Offset(size.width * .79, size.height * .81),
        _ => rectOf(spot, size).center,
      };

  static Rect rectOf(RoomSpot spot, Size size, {String? artId}) {
    final placement = switch (spot.id) {
      'window_out_left' => (.39, .24, .09, .09),
      'window_out_right' => (.50, .24, .105, .09),
      'goal_window' => (.61, .24, .09, .09),
      'wall_poster' => (.13, .50, .15, .17),
      'wall_clock' => (.27, .29, .105, .105),
      'wall_shelf' => (.83, .48, .26, .14),
      'sill_left' => (.075, .665, .11, .14),
      'sill_right' => (.21, .665, .11, .12),
      'goal_wall_left' => (.07, .85, .12, .18),
      'back_left' => (.26, .84, .24, .16),
      'back_right' => (.79, .735, .19, .14),
      'corner_right' => (.94, .735, .065, .12),
      'middle_right' => (.83, .81, .27, .115),
      'floor_rug' => (.52, .94, .40, .12),
      'front_left' => (.13, .98, .18, .12),
      'front_right' => (.90, .98, .17, .19),
      'toy_1' => (.29, .98, .075, .075),
      'toy_2' => (.56, .98, .08, .07),
      'goal_floor' => (.415, .98, .13, .09),
      'goal_wall_mid' => (.715, .98, .15, .12),
      _ => (spot.x ?? .5, spot.y ?? 1, spot.size ?? .14, spot.size ?? .14),
    };
    final scale = switch (artId) {
      'smartwatch' => .65,
      'roller_skates' || 'slime_kit' => .8,
      'drawing_tablet' || 'keyboard' || 'board_game' => .9,
      _ => 1.0,
    };
    final w = placement.$3 * size.width * scale;
    final h = placement.$4 * size.height * scale;
    return Rect.fromLTWH(placement.$1 * size.width - w / 2,
        placement.$2 * size.height - h, w, h);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final shown = [
          for (final piece in pieces)
            if (((piece.spot.z ?? 0) > petZ) == front) piece
        ]..sort((a, b) => (a.spot.id == 'middle_right' ? 14 : a.spot.z ?? 0)
            .compareTo(b.spot.id == 'middle_right' ? 14 : b.spot.z ?? 0));
        return Stack(clipBehavior: Clip.none, children: [
          if (!front)
            for (final shelf in [
              (['sill_left', 'sill_right'], .015, .665, .265),
              (
                ['window_out_left', 'window_out_right', 'goal_window'],
                .33,
                .245,
                .34
              ),
            ])
              if (pieces.any((p) => shelf.$1.contains(p.spot.id)))
                Positioned(
                  left: size.width * shelf.$2,
                  top: size.height * shelf.$3,
                  width: size.width * shelf.$4,
                  height: 8,
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFF0D4A9), Color(0xFFC49A68)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x22000000),
                          offset: Offset(0, 2),
                          blurRadius: 2)
                    ],
                  )),
                ),
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
              rect: rectOf(piece.spot, size, artId: piece.artId),
              child: RoomArt(piece.artId,
                  size: rectOf(piece.spot, size, artId: piece.artId).width),
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
        for (final (fx, fy) in const [
          (.18, .22),
          (.55, .12),
          (.36, .5),
          (.82, .62),
          (.1, .74)
        ]) {
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
          for (var x = row.isEven ? step / 3 : step;
              x < size.width;
              x += step * 1.4) {
            painter.paint(canvas, Offset(x, y));
          }
        }
        painter.dispose();
    }
  }

  @override
  bool shouldRepaint(WallpaperPainter oldDelegate) => oldDelegate.id != id;
}
