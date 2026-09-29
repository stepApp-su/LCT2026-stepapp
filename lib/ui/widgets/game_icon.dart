import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'artwork_bundle.dart';

enum GameIconKind {
  food,
  care,
  joy,
  cozy,
  sun,
  coin,
  pig,
  scooter,
  book,
  telescope,
  navHome,
  navPlan,
  navShop,
  navGames,
  navMore
}

class GameIcon extends StatelessWidget {
  const GameIcon(this.kind, {super.key, this.size = 28});
  final GameIconKind kind;
  final double size;
  static final _images = <String, Future<ui.Image>>{};

  static Future<void> preload() async {
    for (final kind in GameIconKind.values) {
      final path = kind.index < 4
          ? 'assets/images/hud/stats.png'
          : 'assets/images/hud/resource-${kind.name}.png';
      await _images.putIfAbsent(path, () => _load(path));
    }
  }

  static Future<ui.Image> _load(String path) async {
    final bytes = await artworkBundle.load(path);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = kind.index < 4
        ? 'assets/images/hud/stats.png'
        : 'assets/images/hud/resource-${kind.name}.png';
    return SizedBox.square(
        dimension: size,
        child: FutureBuilder<ui.Image>(
          future: _images.putIfAbsent(path, () => _load(path)),
          builder: (context, snapshot) => snapshot.hasData
              ? CustomPaint(painter: _GameIconPainter(snapshot.data!, kind))
              : const SizedBox.shrink(),
        ));
  }
}

class _GameIconPainter extends CustomPainter {
  const _GameIconPainter(this.image, this.kind);
  final ui.Image image;
  final GameIconKind kind;
  @override
  void paint(Canvas canvas, Size size) {
    const crops = [
      Rect.fromLTWH(16, 120, 365, 330),
      Rect.fromLTWH(410, 110, 350, 330),
      Rect.fromLTWH(794, 150, 330, 300),
      Rect.fromLTWH(1140, 115, 375, 340)
    ];
    final isNavigation = kind.index >= GameIconKind.navHome.index;
    final inset = isNavigation ? 85 / 1024 : .098;
    final extent = isNavigation ? 854 / 1024 : .804;
    final source = kind.index < 4
        ? crops[kind.index]
        : Rect.fromLTWH(image.width * inset, image.height * inset,
            image.width * extent, image.height * extent);
    final fitted = applyBoxFit(BoxFit.contain, source.size, size);
    final target =
        Alignment.center.inscribe(fitted.destination, Offset.zero & size);
    canvas.drawImageRect(
        image,
        source,
        target,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..blendMode = BlendMode.multiply);
  }

  @override
  bool shouldRepaint(_GameIconPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.kind != kind;
}
