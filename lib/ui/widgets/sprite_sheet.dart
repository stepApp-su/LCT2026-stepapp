import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const furnitureCells = {
  'rug': 0,
  'flower_pot': 1,
  'cactus': 2,
  'poster': 3,
  'clock': 4,
  'shelf': 5,
  'pouf': 6,
  'palm': 7,
  'table': 8,
  'bed': 9,
  'night_light': 10,
  'aquarium': 11,
  'bouncy_ball': 12,
  'puzzle': 13,
};
const wallpaperCells = {
  'wp_plain': 0,
  'wp_stripes': 1,
  'wp_dots': 2,
  'wp_clouds': 3,
  'wp_leaves': 4,
  'wp_stars': 5,
  'wp_space': 6,
};
const goalCells = {
  'scooter': 0,
  'telescope': 1,
  'ball_rope': 2,
  'treehouse': 3,
  'bicycle': 4,
  'trampoline': 5
};
const accessoryCells = {
  'bow': 0,
  'cap': 1,
  'glasses': 2,
  'scarf': 3,
  'bowtie': 4,
  'tshirt': 5,
  'raincoat': 6,
  'backpack': 7,
  'balloon': 8,
};
const goalRegions = [
  Rect.fromLTWH(20, 20, 300, 373),
  Rect.fromLTWH(325, 15, 309, 380),
  Rect.fromLTWH(640, 50, 305, 345),
  Rect.fromLTWH(945, 20, 290, 374),
  Rect.fromLTWH(5, 410, 325, 330),
  Rect.fromLTWH(334, 402, 302, 332),
];

class SpriteSheet {
  SpriteSheet(this.image, this.cells);
  final ui.Image image;
  final List<Rect> cells;
  static final _cache = <String, Future<SpriteSheet>>{};
  static Future<SpriteSheet> load(String path, int columns, int rows,
          {bool trim = true, List<Rect>? regions}) =>
      _cache.putIfAbsent('$path:$columns:$rows:$trim:$regions', () async {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        final pixels = trim ? await image.toByteData() : null;
        final result = <Rect>[];
        for (var cell = 0; cell < columns * rows; cell++) {
          var area = regions?[cell] ??
              Rect.fromLTWH(
                  cell % columns * image.width / columns,
                  cell ~/ columns * image.height / rows,
                  image.width / columns,
                  image.height / rows);
          if (path.endsWith('/goals.png') && cell < goalRegions.length) {
            final r = goalRegions[cell];
            area = Rect.fromLTRB(
                r.left * image.width / 1254,
                r.top * image.height / 1254,
                r.right * image.width / 1254,
                r.bottom * image.height / 1254);
          } else if (path.endsWith('/outfits.png')) {
            area = Rect.fromLTWH(
                cell == 0 ? 0 : image.width * .515,
                0,
                image.width * (cell == 0 ? .507 : .485),
                image.height.toDouble());
          } else if (trim) {
            area = area.deflate(5);
          }
          if (pixels != null) {
            var left = image.width, top = image.height, right = -1, bottom = -1;
            for (var y = area.top.ceil(); y < area.bottom.floor(); y++) {
              for (var x = area.left.ceil(); x < area.right.floor(); x++) {
                if (pixels.getUint8((y * image.width + x) * 4 + 3) < 100) {
                  continue;
                }
                if (x < left) left = x;
                if (x > right) right = x;
                if (y < top) top = y;
                if (y > bottom) bottom = y;
              }
            }
            if (right >= left) {
              area = Rect.fromLTRB(
                  left.toDouble(), top.toDouble(), right + 1, bottom + 1);
            }
          }
          result.add(area);
        }
        return SpriteSheet(image, result);
      });
}

class SheetArt extends StatelessWidget {
  const SheetArt(
      {super.key,
      required this.path,
      required this.cell,
      this.columns = 4,
      this.rows = 4,
      this.trim = true,
      this.alignment = Alignment.center,
      this.fit = BoxFit.contain});
  final String path;
  final int cell, columns, rows;
  final bool trim;
  final BoxFit fit;
  final Alignment alignment;
  @override
  Widget build(BuildContext context) => FutureBuilder<SpriteSheet>(
        future: SpriteSheet.load(path, columns, rows, trim: trim),
        builder: (context, snapshot) => snapshot.hasData
            ? CustomPaint(
                painter: _SheetPainter(snapshot.data!, cell, fit, alignment))
            : const SizedBox.shrink(),
      );
}

class _SheetPainter extends CustomPainter {
  _SheetPainter(this.sheet, this.cell, this.fit, this.alignment);
  final SpriteSheet sheet;
  final int cell;
  final BoxFit fit;
  final Alignment alignment;
  @override
  void paint(Canvas canvas, Size size) {
    final source = sheet.cells[cell];
    final fitted = applyBoxFit(fit, source.size, size);
    final from = Alignment.center.inscribe(fitted.source, source);
    final to = alignment.inscribe(fitted.destination, Offset.zero & size);
    canvas.drawImageRect(
        sheet.image, from, to, Paint()..filterQuality = FilterQuality.high);
  }

  @override
  bool shouldRepaint(covariant _SheetPainter old) =>
      old.sheet != sheet ||
      old.cell != cell ||
      old.fit != fit ||
      old.alignment != alignment;
}
