import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../theme/finni_theme.dart';

const double storyWidth = 300;
const double storyHeight = 250;

class SceneArt extends StatelessWidget {
  const SceneArt(this.scene, {super.key});

  final String scene;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: CustomPaint(painter: ScenePainter(scene), size: Size.infinite));
}

class ScenePainter extends CustomPainter {
  const ScenePainter(this.scene);

  final String scene;

  static void _box(Canvas c, double x, double y, double w, double h, Color color,
      [double r = 0]) {
    final paint = Paint()..color = color;
    if (r == 0) {
      c.drawRect(Rect.fromLTWH(x, y, w, h), paint);
    } else {
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
          paint);
    }
  }

  static void _text(Canvas c, String text, Offset at, double size,
      {Color color = FinniColors.ink, bool center = false}) {
    final painter = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
        c, center ? at - Offset(painter.width / 2, painter.height / 2) : at);
  }

  static void _cloud(Canvas c, Offset at, double r, Color color) {
    final paint = Paint()..color = color;
    c.drawOval(Rect.fromCenter(center: at, width: r * 2.6, height: r * 1.1), paint);
    c.drawCircle(at + Offset(r * .35, -r * .35), r * .7, paint);
    c.drawCircle(at - Offset(r * .45, r * .15), r * .5, paint);
  }

  static void _tree(Canvas c, double x, double ground, double r) {
    _box(c, x - 4, ground - r * 2.2, 8, r * 2.2, FinniColors.storyWoodDark, 3);
    c.drawCircle(Offset(x, ground - r * 2.4), r, Paint()..color = FinniColors.storyTree);
    c.drawCircle(Offset(x - r * .55, ground - r * 2.0), r * .62,
        Paint()..color = FinniColors.storyTreeDark);
  }

  static void _window(Canvas c, double x, double y, double w, double h) {
    _box(c, x - 5, y - 5, w + 10, h + 10, FinniColors.paper, 8);
    _box(c, x, y, w, h, FinniColors.storyWindow, 4);
    c.drawCircle(Offset(x + w * .75, y + h * .28), h * .13,
        Paint()..color = FinniColors.storySun);
    final frame = Paint()
      ..color = FinniColors.paper
      ..strokeWidth = 5;
    c.drawLine(Offset(x + w / 2, y), Offset(x + w / 2, y + h), frame);
    c.drawLine(Offset(x, y + h / 2), Offset(x + w, y + h / 2), frame);
  }

  static void _floor(Canvas c, Color color, Color lines) {
    _box(c, 0, 180, storyWidth, 70, color);
    final paint = Paint()
      ..color = lines
      ..strokeWidth = 2;
    for (var i = 0; i < 7; i++) {
      final x = i * 56.0;
      c.drawLine(Offset(x, 180), Offset(x - 34, storyHeight), paint);
    }
  }

  static void _sparkles(Canvas c, Color color) {
    const spots = [(30.0, 40.0, 12.0), (262.0, 30.0, 16.0), (232.0, 118.0, 10.0),
      (22.0, 150.0, 14.0), (276.0, 190.0, 12.0), (70.0, 92.0, 9.0)];
    for (final (x, y, s) in spots) {
      _text(c, '✦', Offset(x, y), s, color: color, center: true);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / storyWidth, size.height / storyHeight);
    switch (scene) {
      case 'school':
        _school(canvas);
      case 'canteen':
        _canteen(canvas);
      case 'dream':
        _dream(canvas);
      case 'morning':
        _morning(canvas);
      case 'table':
        _table(canvas);
      case 'street':
        _street(canvas);
      case 'shop':
        _shop(canvas);
      case 'park':
        _park(canvas);
      case 'rain':
        _rain(canvas);
      default:
        _home(canvas);
    }
    canvas.restore();
  }

  void _school(Canvas c) {
    _box(c, 0, 0, storyWidth, 180, FinniColors.storyWall);
    _floor(c, FinniColors.storyFloor, FinniColors.storyFloorLine);
    _box(c, 0, 174, storyWidth, 8, FinniColors.storyBaseboard);
    _box(c, 18, 26, 132, 80, FinniColors.storyWoodDark, 8);
    _box(c, 24, 32, 120, 68, FinniColors.storyBoard, 4);
    _text(c, '2 + 3 = 5', const Offset(36, 46), 17, color: FinniColors.paper);
    final chalk = Paint()
      ..color = FinniColors.paper.withValues(alpha: .6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    c.drawPath(
        Path()
          ..moveTo(36, 84)
          ..quadraticBezierTo(56, 76, 76, 84)
          ..quadraticBezierTo(96, 92, 116, 84),
        chalk);
    _window(c, 196, 22, 82, 92);
    _box(c, 180, 144, 104, 10, FinniColors.storyWood, 3);
    _box(c, 188, 154, 7, 26, FinniColors.storyWoodDark);
    _box(c, 268, 154, 7, 26, FinniColors.storyWoodDark);
    _text(c, '📘', const Offset(236, 126), 18);
  }

  void _canteen(Canvas c) {
    _box(c, 0, 0, storyWidth, 180, FinniColors.warm);
    for (var i = 0; i < 9; i++) {
      _box(c, i * 36.0, 0, 18, 180, FinniColors.storyStripe);
    }
    _box(c, 0, 180, storyWidth, 70, FinniColors.storyTile);
    for (var i = 0; i < 10; i++) {
      _box(c, i * 34.0 - (i.isOdd ? 17 : 0), 186 + (i % 3) * 20.0, 17, 17,
          FinniColors.storyTileDark);
    }
    _box(c, 14, 12, 272, 58, FinniColors.paper.withValues(alpha: .92), 12);
    _text(c, 'МЕНЮ', const Offset(26, 20), 12, color: FinniColors.gold);
    const menu = [('🥪 15', 26.0), ('🍎 5', 96.0), ('🥛 6', 152.0), ('🍲 18', 210.0)];
    for (final (label, x) in menu) {
      _text(c, label, Offset(x, 42), 15);
    }
    _box(c, 0, 132, storyWidth, 12, FinniColors.storyCounterTop);
    _box(c, 0, 144, storyWidth, 36, FinniColors.storyCounter);
    _text(c, '🍲', const Offset(118, 106), 24);
    _text(c, '🥗', const Offset(152, 106), 24);
    _text(c, '🍞', const Offset(186, 108), 22);
  }

  void _dream(Canvas c) {
    c.drawRect(
        const Rect.fromLTWH(0, 0, storyWidth, storyHeight),
        Paint()
          ..shader = ui.Gradient.radial(const Offset(150, 100), 220,
              [FinniColors.storyDreamLight, FinniColors.storyDream]));
    _sparkles(c, FinniColors.storySparkle);
    c.drawOval(Rect.fromCenter(center: const Offset(150, 240), width: 240, height: 50),
        Paint()..color = FinniColors.storyDreamGround);
  }

  void _morning(Canvas c) {
    c.drawRect(
        const Rect.fromLTWH(0, 0, storyWidth, storyHeight),
        Paint()
          ..shader = ui.Gradient.linear(const Offset(0, 0), const Offset(0, 180),
              [FinniColors.storyDawn, FinniColors.storyDawnLow]));
    c.drawCircle(const Offset(236, 120), 64,
        Paint()..color = FinniColors.storySunWarm.withValues(alpha: .25));
    c.drawCircle(const Offset(236, 120), 44, Paint()..color = FinniColors.storySunWarm);
    _cloud(c, const Offset(130, 40), 18, FinniColors.paper);
    _box(c, 22, 76, 78, 104, FinniColors.storyBuilding, 4);
    c.drawPath(
        Path()
          ..moveTo(14, 80)
          ..lineTo(61, 48)
          ..lineTo(108, 80)
          ..close(),
        Paint()..color = FinniColors.storyRoof);
    _text(c, 'ШКОЛА', const Offset(61, 70), 10, color: FinniColors.paper, center: true);
    _box(c, 32, 94, 20, 20, FinniColors.storyWindow, 3);
    _box(c, 70, 94, 20, 20, FinniColors.storyWindow, 3);
    _box(c, 50, 140, 22, 40, FinniColors.storyWoodDark, 3);
    c.drawPath(
        Path()
          ..moveTo(0, 170)
          ..quadraticBezierTo(70, 140, 150, 166)
          ..quadraticBezierTo(230, 190, 300, 160)
          ..lineTo(300, 250)
          ..lineTo(0, 250)
          ..close(),
        Paint()..color = FinniColors.storyHill);
    c.drawPath(
        Path()
          ..moveTo(0, 200)
          ..quadraticBezierTo(90, 178, 170, 198)
          ..quadraticBezierTo(240, 214, 300, 194)
          ..lineTo(300, 250)
          ..lineTo(0, 250)
          ..close(),
        Paint()..color = FinniColors.storyHillDark);
  }

  void _table(Canvas c) {
    _box(c, 0, 0, storyWidth, 180, FinniColors.mint);
    for (var i = 0; i < 8; i++) {
      c.drawCircle(Offset(i * 40.0 + 12, i.isOdd ? 76 : 36), 14,
          Paint()..color = FinniColors.storyMintDot);
    }
    _box(c, 0, 180, storyWidth, 70, FinniColors.storyFloorWarm);
    _box(c, 70, 150, 160, 12, FinniColors.storyWood, 4);
    _box(c, 82, 162, 8, 28, FinniColors.storyWoodDark);
    _box(c, 210, 162, 8, 28, FinniColors.storyWoodDark);
    _text(c, '🥪', const Offset(126, 120), 28);
    _text(c, '🧃', const Offset(166, 126), 20);
  }

  void _street(Canvas c) {
    _box(c, 0, 0, storyWidth, 150, FinniColors.sky);
    c.drawCircle(const Offset(254, 36), 16, Paint()..color = FinniColors.storySun);
    _cloud(c, const Offset(96, 36), 16, FinniColors.paper);
    _box(c, 0, 150, storyWidth, 100, FinniColors.storyGrass);
    _tree(c, 44, 170, 24);
    _tree(c, 222, 172, 32);
    _box(c, 0, 196, storyWidth, 54, FinniColors.storyRoad);
    final dash = Paint()
      ..color = FinniColors.paper
      ..strokeWidth = 5;
    for (var x = 0.0; x < storyWidth; x += 34) {
      c.drawLine(Offset(x, 224), Offset(x + 20, 224), dash);
    }
  }

  void _shop(Canvas c) {
    _box(c, 0, 0, storyWidth, 180, FinniColors.storyShelf);
    for (final y in [58.0, 118.0]) {
      _box(c, 16, y, 268, 8, FinniColors.storyWood, 3);
    }
    const top = ['🧸', '🪀', '📚', '🎨', '🧩'];
    const low = ['🖍️', '🧃', '⚽', '🎈', '🪁'];
    for (var i = 0; i < top.length; i++) {
      _text(c, top[i], Offset(30 + i * 52.0, 28), 24);
      _text(c, low[i], Offset(30 + i * 52.0, 88), 24);
    }
    _box(c, 0, 180, storyWidth, 70, FinniColors.storyTile);
    _box(c, 0, 172, storyWidth, 10, FinniColors.storyCounterTop);
  }

  void _park(Canvas c) {
    _box(c, 0, 0, storyWidth, 160, FinniColors.sky);
    c.drawCircle(const Offset(40, 34), 16, Paint()..color = FinniColors.storySun);
    _cloud(c, const Offset(180, 30), 16, FinniColors.paper);
    _box(c, 0, 160, storyWidth, 90, FinniColors.storyHill);
    _tree(c, 30, 176, 22);
    _tree(c, 280, 176, 26);
    final frame = Paint()
      ..color = FinniColors.storyWoodDark
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(88, 176), const Offset(110, 88), frame);
    c.drawLine(const Offset(160, 176), const Offset(138, 88), frame);
    c.drawLine(const Offset(106, 88), const Offset(142, 88), frame);
    final rope = Paint()
      ..color = FinniColors.storyWoodDark
      ..strokeWidth = 2;
    c.drawLine(const Offset(116, 90), const Offset(116, 140), rope);
    c.drawLine(const Offset(132, 90), const Offset(132, 140), rope);
    _box(c, 110, 140, 28, 6, FinniColors.storyRoof, 2);
    c.drawPath(
        Path()
          ..moveTo(184, 176)
          ..lineTo(248, 104)
          ..lineTo(262, 104)
          ..lineTo(206, 176)
          ..close(),
        Paint()..color = FinniColors.storySlide);
    _box(c, 250, 104, 6, 72, FinniColors.storyWoodDark, 2);
  }

  void _rain(Canvas c) {
    _box(c, 0, 0, storyWidth, 170, FinniColors.storyRainSky);
    _cloud(c, const Offset(70, 30), 22, FinniColors.storyCloud);
    _cloud(c, const Offset(220, 40), 26, FinniColors.storyCloud);
    final drop = Paint()
      ..color = FinniColors.storyDrop
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final random = math.Random(7);
    for (var i = 0; i < 38; i++) {
      final x = random.nextDouble() * storyWidth;
      final y = 50 + random.nextDouble() * 150;
      c.drawLine(Offset(x, y), Offset(x - 4, y + 12), drop);
    }
    _box(c, 0, 170, storyWidth, 80, FinniColors.storyGrass);
    c.drawOval(Rect.fromCenter(center: const Offset(150, 214), width: 110, height: 16),
        Paint()..color = FinniColors.storyDrop.withValues(alpha: .5));
  }

  void _home(Canvas c) {
    _box(c, 0, 0, storyWidth, 180, FinniColors.lavender);
    final dot = Paint()..color = FinniColors.paper.withValues(alpha: .7);
    for (var y = 16.0; y < 176; y += 32) {
      for (var x = 16.0; x < storyWidth; x += 32) {
        c.drawCircle(Offset(x, y), 3.5, dot);
      }
    }
    _window(c, 24, 26, 78, 86);
    _box(c, 0, 180, storyWidth, 70, FinniColors.storyFloor);
    c.drawOval(Rect.fromCenter(center: const Offset(150, 214), width: 220, height: 44),
        Paint()..color = FinniColors.storyRug);
    _box(c, 250, 70, 6, 110, FinniColors.storyWoodDark, 3);
    c.drawPath(
        Path()
          ..moveTo(232, 72)
          ..lineTo(274, 72)
          ..lineTo(264, 44)
          ..lineTo(242, 44)
          ..close(),
        Paint()..color = FinniColors.storySun);
  }

  @override
  bool shouldRepaint(covariant ScenePainter old) => old.scene != scene;
}

class FriendArt extends StatelessWidget {
  const FriendArt({super.key, required this.kind, required this.mood});

  final FriendKind kind;
  final StoryMood mood;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: CustomPaint(painter: FriendPainter(kind, mood), size: Size.infinite));
}

class FriendPainter extends CustomPainter {
  const FriendPainter(this.kind, this.mood);

  final FriendKind kind;
  final StoryMood mood;

  @override
  void paint(Canvas c, Size size) {
    final s = math.min(size.width / 128, size.height / 156);
    c.save();
    c.translate((size.width - 128 * s) / 2, size.height - 156 * s);
    c.scale(s);
    final bunny = kind == FriendKind.bunny;
    final light = bunny ? FinniColors.furBunny : FinniColors.furBear;
    final dark = bunny ? FinniColors.furBunnyDark : FinniColors.furBearDark;
    final ear = bunny ? FinniColors.furBunnyDark : FinniColors.furBearEar;
    final inner = bunny ? FinniColors.furBunnyInner : FinniColors.furBearInner;
    final belly = bunny ? FinniColors.paper : FinniColors.furBelly;
    Paint fur(Rect bounds) => Paint()
      ..shader = ui.Gradient.radial(
          bounds.topLeft + Offset(bounds.width * .4, bounds.height * .35),
          bounds.longestSide * .8,
          [light, dark]);
    c.drawOval(const Rect.fromLTWH(24, 144, 80, 12),
        Paint()..color = FinniColors.shadow);
    final body = Path()
      ..moveTo(26, 150)
      ..quadraticBezierTo(20, 104, 64, 100)
      ..quadraticBezierTo(108, 104, 102, 150)
      ..close();
    c.drawPath(body, fur(const Rect.fromLTWH(20, 100, 88, 50)));
    c.drawOval(const Rect.fromLTWH(42, 108, 44, 40), Paint()..color = belly);
    final arm = Paint()
      ..color = dark
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    c.drawPath(
        Path()
          ..moveTo(30, 118)
          ..quadraticBezierTo(18, 128, 24, 140),
        arm);
    c.drawPath(
        Path()
          ..moveTo(98, 118)
          ..quadraticBezierTo(110, 128, 104, 140),
        arm);
    if (bunny) {
      for (final (x, tilt) in const [(40.0, -.18), (88.0, .18)]) {
        c.save();
        c.translate(x, 34);
        c.rotate(tilt);
        c.drawOval(const Rect.fromLTWH(-11, -46, 22, 58), Paint()..color = ear);
        c.drawOval(const Rect.fromLTWH(-6, -38, 12, 44), Paint()..color = inner);
        c.restore();
      }
    } else {
      for (final x in const [30.0, 98.0]) {
        c.drawCircle(Offset(x, 30), 15, Paint()..color = ear);
        c.drawCircle(Offset(x, 30), 8, Paint()..color = inner);
      }
    }
    c.drawOval(const Rect.fromLTWH(22, 20, 84, 80), fur(const Rect.fromLTWH(22, 20, 84, 80)));
    c.drawOval(const Rect.fromLTWH(46, 62, 36, 28), Paint()..color = belly);
    c.drawOval(const Rect.fromLTWH(57, 65, 14, 10), Paint()..color = FinniColors.faceInk);
    final inkLine = Paint()
      ..color = FinniColors.faceInk
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (mood == StoryMood.sad) {
      c.drawPath(
          Path()
            ..moveTo(44, 58)
            ..quadraticBezierTo(50, 62, 56, 58)
            ..moveTo(72, 58)
            ..quadraticBezierTo(78, 62, 84, 58),
          inkLine);
      c.drawPath(
          Path()
            ..moveTo(47, 64)
            ..quadraticBezierTo(44, 71, 48, 74)
            ..quadraticBezierTo(52, 71, 47, 64),
          Paint()..color = FinniColors.faceTear);
    } else {
      for (final x in const [50.0, 78.0]) {
        c.drawOval(Rect.fromCenter(center: Offset(x, 58), width: 13, height: 15),
            Paint()..color = FinniColors.faceInk);
        c.drawCircle(Offset(x + 2.5, 55), 2.4, Paint()..color = FinniColors.paper);
      }
    }
    if (mood == StoryMood.sad || mood == StoryMood.ask) {
      final brow = Paint()
        ..color = FinniColors.faceBrow
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      c.drawLine(const Offset(42, 46), const Offset(54, 50), brow);
      c.drawLine(const Offset(86, 46), const Offset(74, 50), brow);
    }
    final mouthLine = Paint()
      ..color = FinniColors.faceInk
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    switch (mood) {
      case StoryMood.sad:
        c.drawPath(
            Path()
              ..moveTo(57, 83)
              ..quadraticBezierTo(64, 77, 71, 83),
            mouthLine);
      case StoryMood.ask:
        c.drawOval(Rect.fromCenter(center: const Offset(64, 82), width: 10, height: 8),
            Paint()..color = FinniColors.faceMouth);
      case StoryMood.happy:
        c.drawPath(
            Path()
              ..moveTo(55, 78)
              ..quadraticBezierTo(64, 92, 73, 78)
              ..close(),
            Paint()..color = FinniColors.faceMouth);
        c.drawOval(Rect.fromCenter(center: const Offset(64, 84), width: 9, height: 4),
            Paint()..color = FinniColors.faceTongue);
      case StoryMood.calm:
      case StoryMood.none:
        c.drawPath(
            Path()
              ..moveTo(57, 79)
              ..quadraticBezierTo(64, 84, 71, 79),
            mouthLine);
    }
    final blush = Paint()..color = FinniColors.faceBlush.withValues(alpha: .55);
    c.drawOval(Rect.fromCenter(center: const Offset(38, 72), width: 14, height: 9), blush);
    c.drawOval(Rect.fromCenter(center: const Offset(90, 72), width: 14, height: 9), blush);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant FriendPainter old) =>
      old.kind != kind || old.mood != mood;
}

class CoinStack extends StatelessWidget {
  const CoinStack({super.key, required this.stack});

  final StoryStack stack;

  @override
  Widget build(BuildContext context) {
    final coins = math.min(7, math.max(1, (stack.amount / 3).ceil()));
    final tone = stack.good ? FinniColors.primary : FinniColors.alert;
    return Semantics(
      label: '${stack.amount} ${stack.label}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 8.0 + coins * 5,
            child: Stack(
              children: [
                for (var i = 0; i < coins; i++)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: i * 5.0,
                    child: Container(
                      height: 9,
                      decoration: BoxDecoration(
                        color: FinniColors.coinFace,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: FinniColors.coinEdge, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('${stack.amount}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: tone)),
          Text(stack.label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: FinniColors.muted)),
        ],
      ),
    );
  }
}

class StoryBubbleView extends StatelessWidget {
  const StoryBubbleView(
      {super.key,
      required this.text,
      this.name,
      this.nameColor = FinniColors.primary,
      this.tailLeft = true,
      this.color = FinniColors.paper});

  final String text;
  final String? name;
  final Color nameColor;
  final bool tailLeft;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _BubblePainter(color, tailLeft),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (name case final who?)
                Text(who,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w900, color: nameColor)),
              Text(text,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, height: 1.25)),
            ],
          ),
        ),
      );
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter(this.color, this.tailLeft);

  final Color color;
  final bool tailLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height - 10), const Radius.circular(18));
    final tailX = tailLeft ? 28.0 : size.width - 28;
    final path = Path()
      ..addRRect(body)
      ..moveTo(tailX - 9, size.height - 11)
      ..lineTo(tailX, size.height)
      ..lineTo(tailX + 9, size.height - 11)
      ..close();
    canvas.drawShadow(path, FinniColors.ink.withValues(alpha: .35), 3, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) =>
      old.color != color || old.tailLeft != tailLeft;
}

class StoryStage extends StatelessWidget {
  const StoryStage({
    super.key,
    required this.page,
    required this.pet,
    required this.petName,
    this.friend,
    this.fill,
  });

  final StoryPage page;
  final Widget pet;
  final String petName;
  final StoryFriend? friend;
  final String Function(String text)? fill;

  String _t(String text) => fill?.call(text) ?? text;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: storyWidth / storyHeight,
        child: LayoutBuilder(builder: (context, box) {
          final k = box.maxWidth / storyWidth;
          final friendShown = friend != null && page.friendMood != StoryMood.none;
          final thought = page.thought;
          final alone = !friendShown;
          final bubbles = page.bubbles.take(2).toList();
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(child: SceneArt(page.scene)),
              if (page.prop case final prop?)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 34 * k,
                  child: Center(
                      child: Text(prop,
                          style: TextStyle(fontSize: 40 * k, height: 1))),
                ),
              Positioned(
                left: alone ? (storyWidth - 150) / 2 * k : 2 * k,
                bottom: 0,
                width: 150 * k,
                height: 170 * k,
                child: IgnorePointer(child: pet),
              ),
              if (page.petEmote case final emote?)
                Positioned(
                  left: (alone ? (storyWidth - 150) / 2 + 106 : 108) * k,
                  bottom: 150 * k,
                  child: Text(emote, style: TextStyle(fontSize: 28 * k, height: 1)),
                ),
              if (friendShown)
                Positioned(
                  right: 10 * k,
                  bottom: 4 * k,
                  width: 108 * k,
                  height: 132 * k,
                  child: FriendArt(kind: friend!.kind, mood: page.friendMood),
                ),
              if (thought != null)
                Positioned(
                  left: 16 * k,
                  right: 16 * k,
                  top: 12 * k,
                  child: _ThoughtCloud(thought: thought, fill: _t),
                ),
              for (var i = 0; i < bubbles.length; i++)
                _placeBubble(bubbles[i], i, k, friendShown),
            ],
          );
        }),
      );

  Widget _placeBubble(StoryBubble bubble, int index, double k, bool friendShown) {
    final fromPet = bubble.voice == StoryVoice.pet;
    final name = switch (bubble.voice) {
      StoryVoice.pet => petName,
      StoryVoice.friend => friend?.name,
      StoryVoice.other => bubble.name,
    };
    final top = (10 + index * 74) * k;
    final child = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 196 * k),
      child: StoryBubbleView(
        text: _t(bubble.text),
        name: name,
        nameColor: fromPet ? FinniColors.primary : FinniColors.furBearDark,
        tailLeft: fromPet || !friendShown,
      ),
    );
    return fromPet || !friendShown
        ? Positioned(left: 12 * k, top: top, child: child)
        : Positioned(right: 12 * k, top: top, child: child);
  }
}

class _ThoughtCloud extends StatelessWidget {
  const _ThoughtCloud({required this.thought, required this.fill});

  final StoryThought thought;
  final String Function(String) fill;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: FinniColors.paper,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: FinniColors.shadow, blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('💭 ${fill(thought.title)}',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900, color: FinniColors.purple)),
            if (thought.stacks.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < thought.stacks.length; i++) ...[
                    if (i > 0)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(8, 0, 8, 26),
                        child: Text('+',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: FinniColors.storyPageNo)),
                      ),
                    CoinStack(stack: thought.stacks[i]),
                  ],
                  if (thought.note case final note?) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(fill(note),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: FinniColors.primary)),
                    ),
                  ],
                ],
              ),
            ] else if (thought.note case final note?) ...[
              const SizedBox(height: 4),
              Text(fill(note),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, height: 1.3)),
            ],
          ],
        ),
      );
}
