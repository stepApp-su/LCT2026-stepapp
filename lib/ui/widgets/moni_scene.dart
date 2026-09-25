import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../theme/finni_theme.dart';
import '../../domain/models/pet.dart';
import 'moni_idle.dart';

class MoniScene extends StatefulWidget {
  const MoniScene(
      {super.key,
      this.motion = true,
      this.stage = PetStage.teen,
      this.celebrationProgress,
      this.onReady,
      this.equipped,
      this.onPet,
      this.outfit = const {}});
  final bool motion;
  final PetStage stage;
  final double? celebrationProgress;
  final VoidCallback? onReady;
  final String? equipped;
  final VoidCallback? onPet;
  final Map<String, String> outfit;
  @override
  State<MoniScene> createState() => _MoniSceneState();
}

class _MoniSceneState extends State<MoniScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController ticker = AnimationController(
    vsync: this,
    duration: const Duration(seconds: moniIdleSeconds),
  );
  ui.Image? rig, accessories;
  List<Rect> accessoryBounds = [];
  ui.Image? closedFace;
  final Map<PetStage, ui.Image> stageRigs = {};
  final Map<PetStage, ui.Image> stageFaces = {};
  Timer? reaction;
  bool happy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final images = await Future.wait(
      ['rig', 'accessories', 'rig-baby', 'rig-adult'].map((name) async {
        final bytes = await rootBundle.load('assets/pets/moni/$name.png');
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        return frame.image;
      }),
    );
    final bounds = await _trimCells(images[1]);
    final closed = await _makeClosedFace(images[0]);
    final babyClosed = await _makeClosedFace(images[2]);
    final adultClosed = await _makeClosedFace(images[3]);
    if (!mounted) {
      closed.dispose();
      babyClosed.dispose();
      adultClosed.dispose();
      for (final i in images) {
        i.dispose();
      }
      return;
    }
    setState(() {
      rig = images[0];
      accessories = images[1];
      accessoryBounds = bounds;
      closedFace = closed;
      stageRigs.addAll({PetStage.baby: images[2], PetStage.adult: images[3]});
      stageFaces
          .addAll({PetStage.baby: babyClosed, PetStage.adult: adultClosed});
    });
    widget.onReady?.call();
  }

  // Keep the neutral outline; replace only the painted facial expression.
  Future<ui.Image> _makeClosedFace(ui.Image image) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const target = Rect.fromLTWH(0, 0, 510, 434);
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImageRect(
        image, const Rect.fromLTWH(480, 65, 449, 383), target, paint);
    canvas.saveLayer(target, Paint());
    canvas.drawImageRect(
        image, const Rect.fromLTWH(480, 468, 450, 388), target, paint);
    canvas.save();
    canvas.translate(510 * .53, 434 * .58);
    canvas.scale(510 * .455, 434 * .385);
    canvas.drawRect(
        const Rect.fromLTWH(-2, -2, 4, 4),
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.radial(Offset.zero, 1,
              [Colors.white, Colors.white, Colors.transparent], [0, .8, 1]));
    canvas.restore();
    canvas.restore();
    final picture = recorder.endRecording();
    final result = await picture.toImage(510, 434);
    picture.dispose();
    return result;
  }

  Future<List<Rect>> _trimCells(ui.Image image) async {
    final bytes = (await image.toByteData())!;
    final cells = <Rect>[];
    final cw = image.width / 4, ch = image.height / 3;
    for (var i = 0; i < 12; i++) {
      var left = image.width, top = image.height, right = 0, bottom = 0;
      for (var y = ((i ~/ 4) * ch + 3).ceil();
          y < ((i ~/ 4 + 1) * ch - 3).floor();
          y++) {
        for (var x = ((i % 4) * cw + 3).ceil();
            x < ((i % 4 + 1) * cw - 3).floor();
            x++) {
          if (bytes.getUint8((y * image.width + x) * 4 + 3) > 70) {
            left = math.min(left, x);
            right = math.max(right, x);
            top = math.min(top, y);
            bottom = math.max(bottom, y);
          }
        }
      }
      cells.add(Rect.fromLTRB(
          left.toDouble(), top.toDouble(), right + 1.0, bottom + 1.0));
    }
    return cells;
  }

  void sync() {
    if (widget.motion && !MediaQuery.of(context).disableAnimations) {
      if (!ticker.isAnimating) ticker.repeat();
    } else {
      ticker.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sync();
  }

  @override
  void didUpdateWidget(covariant MoniScene old) {
    super.didUpdateWidget(old);
    sync();
  }

  @override
  void dispose() {
    ticker.dispose();
    reaction?.cancel();
    closedFace?.dispose();
    rig?.dispose();
    accessories?.dispose();
    for (final image in [...stageRigs.values, ...stageFaces.values]) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Твой питомец. Нажми, чтобы погладить.',
        button: true,
        child: GestureDetector(
          onTap: () {
            reaction?.cancel();
            setState(() => happy = true);
            reaction = Timer(const Duration(milliseconds: 1100), () {
              if (mounted) setState(() => happy = false);
            });
            widget.onPet?.call();
          },
          child: AnimatedBuilder(
            animation: ticker,
            builder: (context, _) => CustomPaint(
              painter: _MoniPainter(
                rig,
                accessories,
                widget.motion && !MediaQuery.disableAnimationsOf(context)
                    ? ticker.value * moniIdleSeconds
                    : 0,
                happy,
                widget.equipped,
                Map.of(widget.outfit),
                accessoryBounds,
                stageFaces[widget.stage] ?? closedFace,
                stageRigs[widget.stage] ?? rig,
                widget.stage,
                widget.celebrationProgress,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      );
}

class _MoniPainter extends CustomPainter {
  _MoniPainter(
      this.rig,
      this.accessories,
      this.t,
      this.happy,
      this.equipped,
      this.outfit,
      this.accessoryBounds,
      this.closedFace,
      this.faceRig,
      this.stage,
      this.celebrationProgress);
  final ui.Image? rig, accessories;
  final double t;
  final bool happy;
  final String? equipped;
  final Map<String, String> outfit;
  final List<Rect> accessoryBounds;
  final ui.Image? closedFace;
  final ui.Image? faceRig;
  final PetStage stage;
  final double? celebrationProgress;
  @override
  void paint(Canvas c, Size size) {
    final s = math.min(size.width / 470, size.height / 550);
    c.save();
    c.translate((size.width - 470 * s) / 2, (size.height - 550 * s) / 2);
    c.scale(s);
    c.translate(-58, -60);
    final ageScale = stage == PetStage.baby
        ? .90
        : stage == PetStage.adult
            ? 1.02
            : 1.0;
    c.translate(320, 593);
    c.scale(ageScale);
    c.translate(-320, -593);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    c.drawOval(
      const Rect.fromLTWH(184, 574, 246, 24),
      Paint()..color = FinniColors.shadow,
    );
    if (rig == null) {
      c.restore();
      return;
    }
    final progress = celebrationProgress ?? 0;
    double pulse(double start, double end) => math
        .sin(((progress - start) / (end - start)).clamp(0.0, 1.0) * math.pi);
    final jump = pulse(.30, .70);
    final encore = pulse(.74, .92);
    final anticipation = pulse(.12, .30);
    final joy = pulse(.30, 1);
    c.translate(0, anticipation * 9 - jump * 48 - encore * 19);
    c.translate(320, 593);
    c.rotate(math.sin(progress * math.pi * 6) * .035 * joy);
    c.translate(-320, -593);
    void part(Rect from, Rect to,
        {double angle = 0, Offset? pivot, bool face = false}) {
      c.save();
      if (angle != 0) {
        final p = pivot ?? to.center;
        c.translate(p.dx, p.dy);
        c.rotate(angle);
        c.translate(-p.dx, -p.dy);
      }
      c.drawImageRect(face ? faceRig! : rig!, from, to, paint);
      c.restore();
    }

    final breath = moniIdleWave(t, 4) * 1.5;
    part(
      const Rect.fromLTWH(42, 469, 397, 377),
      const Rect.fromLTWH(121, 382, 162, 154),
      angle: moniIdleWave(t, 4) * .06 + math.sin(progress * 48) * .20 * joy,
      pivot: const Offset(254, 516),
    );
    part(
      const Rect.fromLTWH(42, 90, 410, 367),
      Rect.fromLTWH(214, 406 + breath, 209, 187 - breath),
    );
    c.save();
    c.translate(0, breath);
    c.translate(354, 412);
    c.rotate(moniIdleWave(t, 3) * .008);
    c.translate(-354, -412);
    part(
      const Rect.fromLTWH(944, 48, 390, 403),
      const Rect.fromLTWH(88, 151, 203, 210),
      angle: -.12 + moniIdleWave(t, 2) * .015 - jump * .10 + encore * .08,
      pivot: const Offset(258, 334),
      face: true,
    );
    part(
      const Rect.fromLTWH(1363, 43, 399, 411),
      const Rect.fromLTWH(335, 90, 179, 227),
      angle: .04 - moniIdleWave(t, 2) * .015 + jump * .12 - encore * .06,
      pivot: const Offset(371, 287),
      face: true,
    );
    final blink = (t > 2.8 && t < 2.94) ||
        (t > 6.4 && t < 6.54) ||
        (t > 10.1 && t < 10.24);
    if ((blink || happy || jump > .7 || encore > .3) && closedFace != null) {
      c.drawImageRect(closedFace!, const Rect.fromLTWH(0, 0, 510, 434),
          const Rect.fromLTWH(217, 216, 255, 217), paint);
    } else {
      part(const Rect.fromLTWH(480, 65, 449, 383),
          const Rect.fromLTWH(217, 216, 255, 217),
          face: true);
    }
    if (accessories != null && accessoryBounds.length == 12) {
      final a = accessories!;
      final selected = {...outfit.values, if (equipped != null) equipped!};
      const placements = {
        'bow': (0, 254.0, 288.0, 62.0, -.30),
        'cap': (1, 347.0, 269.0, 148.0, -.10),
        'glasses': (2, 353.0, 371.0, 139.0, -.04),
        'scarf': (3, 332.0, 461.0, 105.0, 0.0),
        'balloon': (8, 478.0, 490.0, 72.0, .08),
      };
      for (final id in selected) {
        final placement = placements[id];
        if (placement == null) continue;
        final source = accessoryBounds[placement.$1];
        final w = placement.$4, h = w * source.height / source.width;
        c.save();
        c.translate(placement.$2, placement.$3 - h / 2);
        c.rotate(placement.$5);
        c.drawImageRect(a, source, Rect.fromLTWH(-w / 2, -h / 2, w, h), paint);
        c.restore();
      }
    }
    c.restore();
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _MoniPainter old) =>
      old.rig != rig ||
      old.faceRig != faceRig ||
      old.stage != stage ||
      old.celebrationProgress != celebrationProgress ||
      old.closedFace != closedFace ||
      old.t != t ||
      old.happy != happy ||
      old.equipped != equipped ||
      !mapEquals(old.outfit, outfit);
}

class ProductArt extends StatelessWidget {
  const ProductArt({super.key, required this.sheet, required this.cell});
  final String sheet;
  final int cell;
  @override
  Widget build(BuildContext context) => ClipRect(
        child: LayoutBuilder(
          builder: (context, c) => OverflowBox(
            alignment: Alignment(
              -1 + (cell % 4) * 2 / 3,
              -1 + (cell ~/ 4).toDouble(),
            ),
            minWidth: c.maxWidth * 4,
            maxWidth: c.maxWidth * 4,
            minHeight: c.maxHeight * 3,
            maxHeight: c.maxHeight * 3,
            child: Image.asset(
              'assets/pets/moni/$sheet.png',
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
          ),
        ),
      );
}
