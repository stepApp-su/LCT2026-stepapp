import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'artwork_bundle.dart';

import '../theme/finni_theme.dart';
import '../../domain/models/pet.dart';
import 'moni_idle.dart';
import '../pet_appearance.dart';
import 'pet_rig_layout.dart';
import 'sprite_sheet.dart';
import 'pet_sprite_set.dart';

class MoniScene extends StatefulWidget {
  const MoniScene(
      {super.key,
      this.motion = true,
      this.appearance = PetAppearance.moni,
      this.stage = PetStage.teen,
      this.celebrationProgress,
      this.onReady,
      this.equipped,
      this.onPet,
      this.sleeping = false,
      this.sad = false,
      this.outfit = const {}});
  final bool motion;
  final PetAppearance appearance;
  final PetStage stage;
  final double? celebrationProgress;
  final VoidCallback? onReady;
  final String? equipped;
  final VoidCallback? onPet;
  final bool sleeping;
  final bool sad;
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
  SpriteSheet? clothing;
  SpriteSheet? ears;
  List<Rect> accessoryBounds = [];
  ui.Image? closedFace;
  final Map<PetStage, ui.Image> stageRigs = {};
  final Map<PetStage, ui.Image> stageFaces = {};
  final Map<PetStage, ui.Image> sadFaces = {};
  Timer? reaction;
  bool happy = false;
  int loadRevision = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final revision = ++loadRevision;
    final appearance = widget.appearance;
    if (appearance.unifiedHead) {
      final set = await PetSpriteSet.load(appearance);
      final shared =
          await SpriteSheet.load('assets/pets/shared/accessories.png', 3, 3);
      if (!mounted || revision != loadRevision) {
        for (final image in [
          ...set.rigs.values,
          ...set.closed.values,
          ...set.sad.values
        ]) {
          image.dispose();
        }
        return;
      }
      setState(() {
        rig = set.rigs[PetStage.teen];
        stageRigs
          ..addAll(set.rigs)
          ..remove(PetStage.teen);
        closedFace = set.closed[PetStage.teen];
        stageFaces
          ..addAll(set.closed)
          ..remove(PetStage.teen);
        sadFaces.addAll(set.sad);
        accessories = shared.image.clone();
        accessoryBounds = shared.cells;
        clothing = set.clothing;
      });
      widget.onReady?.call();
      return;
    }
    final images = await Future.wait(
      ['rig', 'accessories', 'rig-baby', 'rig-adult'].map((name) async {
        final folder =
            name == 'accessories' ? 'assets/pets/shared' : appearance.assets;
        final bytes = await artworkBundle.load('$folder/$name.png');
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
          targetWidth: name == 'accessories' ? null : 1774,
          targetHeight: name == 'accessories' ? null : 887,
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        return frame.image;
      }),
    );
    final bounds =
        (await SpriteSheet.load('assets/pets/shared/accessories.png', 3, 3))
            .cells;
    final fittedClothing =
        await SpriteSheet.load('${appearance.assets}/outfits.png', 2, 1);
    final fittedEars = appearance == PetAppearance.tyapa
        ? await SpriteSheet.load('${appearance.assets}/ears.png', 2, 3,
            regions: const [
                Rect.fromLTWH(100, 20, 400, 365),
                Rect.fromLTWH(560, 20, 400, 365),
                Rect.fromLTWH(100, 390, 400, 440),
                Rect.fromLTWH(560, 390, 400, 440),
                Rect.fromLTWH(50, 835, 450, 680),
                Rect.fromLTWH(560, 835, 450, 680),
              ])
        : null;
    final closed = await _makeClosedFace(images[0], appearance);
    final babyClosed = await _makeClosedFace(images[2], appearance);
    final adultClosed = await _makeClosedFace(images[3], appearance);
    final sadSheet = await SpriteSheet.load(
        '${appearance.assets}/sad.png', 1, 1,
        trim: false);
    final sadness = <PetStage, ui.Image>{};
    for (final entry in {
      PetStage.teen: images[0],
      PetStage.baby: images[2],
      PetStage.adult: images[3]
    }.entries) {
      sadness[entry.key] = await _makeSadFace(
          entry.value, sadSheet.image, appearance, entry.key);
    }
    if (!mounted || revision != loadRevision) {
      closed.dispose();
      babyClosed.dispose();
      adultClosed.dispose();
      for (final image in sadness.values) {
        image.dispose();
      }
      for (final i in images) {
        i.dispose();
      }
      return;
    }
    setState(() {
      rig = images[0];
      accessories = images[1];
      accessoryBounds = bounds;
      clothing = fittedClothing;
      ears = fittedEars;
      closedFace = closed;
      stageRigs.addAll({PetStage.baby: images[2], PetStage.adult: images[3]});
      stageFaces
          .addAll({PetStage.baby: babyClosed, PetStage.adult: adultClosed});
      sadFaces.addAll(sadness);
    });
    widget.onReady?.call();
  }

  // Keep the neutral outline; replace only the painted facial expression.
  Future<ui.Image> _makeSadFace(ui.Image neutral, ui.Image sad,
      PetAppearance appearance, PetStage stage) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const target = Rect.fromLTWH(0, 0, 510, 434);
    final source = _headSource(appearance);
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImageRect(neutral, source, target, paint);
    // Only eyebrows and mouth change. Eyes, cheeks and silhouette stay original.
    final patches = switch (appearance) {
      PetAppearance.moni => const [
          Rect.fromLTWH(82, 133, 116, 76),
          Rect.fromLTWH(298, 98, 103, 68),
          Rect.fromLTWH(188, 285, 187, 88)
        ],
      PetAppearance.pix => const [
          Rect.fromLTWH(102, 184, 109, 78),
          Rect.fromLTWH(296, 171, 93, 43),
          Rect.fromLTWH(190, 307, 190, 88)
        ],
      PetAppearance.tyapa => const [
          Rect.fromLTWH(100, 175, 108, 83),
          Rect.fromLTWH(305, 157, 91, 47),
          Rect.fromLTWH(193, 309, 187, 88)
        ],
      _ => const [
          Rect.fromLTWH(76, 162, 128, 84),
          Rect.fromLTWH(292, 119, 110, 68),
          Rect.fromLTWH(189, 319, 185, 92)
        ],
    };
    final sx = sad.width / 1774, sy = sad.height / 887;
    final sadSource = Rect.fromLTWH(source.left * sx, source.top * sy,
        source.width * sx, source.height * sy);
    final age = stage == PetStage.baby
        ? 0
        : stage == PetStage.adult
            ? 2
            : 1;
    final offsets = switch (appearance) {
      PetAppearance.moni => const [
          [Offset(8, 0), Offset(19, 16), Offset(1, 12)],
          [Offset.zero, Offset.zero, Offset(0, 1)],
          [Offset(8, 0), Offset(9, 2), Offset(6, -1)],
        ],
      PetAppearance.pix => const [
          [Offset(10, 9), Offset(19, 11), Offset(6, 4)],
          [Offset.zero, Offset.zero, Offset(-1, 0)],
          [Offset(10, 8), Offset(14, 7), Offset(4, 1)],
        ],
      PetAppearance.tyapa => const [
          [Offset(10, 23), Offset(-3, 17), Offset(7, 20)],
          [Offset.zero, Offset.zero, Offset(-1, 0)],
          [Offset(0, 1), Offset(-2, 1), Offset.zero],
        ],
      _ => const [
          [Offset(15, 2), Offset(17, 6), Offset(13, 5)],
          [Offset.zero, Offset.zero, Offset.zero],
          [Offset(6, 4), Offset(14, 7), Offset(2, 0)],
        ],
    };
    for (var i = 0; i < patches.length; i++) {
      final offset = offsets[age][i];
      final patch = patches[i].shift(offset);
      canvas.saveLayer(target, Paint());
      canvas.drawImageRect(sad, sadSource, target.shift(offset), paint);
      canvas.save();
      canvas.translate(patch.center.dx, patch.center.dy);
      canvas.scale(patch.width / 2, patch.height / 2);
      canvas.drawRect(
          const Rect.fromLTWH(-20, -20, 40, 40),
          Paint()
            ..blendMode = BlendMode.dstIn
            ..shader = ui.Gradient.radial(Offset.zero, 1,
                [Colors.white, Colors.white, Colors.transparent], [0, .75, 1]));
      canvas.restore();
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final result = await picture.toImage(510, 434);
    picture.dispose();
    return result;
  }

  Future<ui.Image> _makeClosedFace(
      ui.Image image, PetAppearance appearance) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const target = Rect.fromLTWH(0, 0, 510, 434);
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImageRect(image, _headSource(appearance), target, paint);
    canvas.saveLayer(target, Paint());
    canvas.drawImageRect(
        image, PetRigLayout(appearance, PetStage.teen).closed, target, paint);
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
    if (old.appearance != widget.appearance) {
      _disposeImages();
      rig = accessories = closedFace = null;
      clothing = null;
      ears = null;
      stageRigs.clear();
      stageFaces.clear();
      sadFaces.clear();
      reaction?.cancel();
      happy = false;
      _load();
    }
    sync();
  }

  void _disposeImages() {
    closedFace?.dispose();
    rig?.dispose();
    accessories?.dispose();
    for (final image in [
      ...stageRigs.values,
      ...stageFaces.values,
      ...sadFaces.values
    ]) {
      image.dispose();
    }
  }

  @override
  void dispose() {
    ticker.dispose();
    reaction?.cancel();
    _disposeImages();
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
                happy || widget.sleeping,
                widget.equipped,
                Map.of(widget.outfit),
                accessoryBounds,
                stageFaces[widget.stage] ?? closedFace,
                stageRigs[widget.stage] ?? rig,
                widget.stage,
                widget.celebrationProgress,
                widget.appearance,
                clothing,
                ears,
                widget.sad,
                sadFaces[widget.stage] ?? sadFaces[PetStage.teen],
              ),
              size: Size.infinite,
            ),
          ),
        ),
      );
}

Rect _headSource(PetAppearance appearance) =>
    PetRigLayout(appearance, PetStage.teen).head;

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
      this.celebrationProgress,
      this.appearance,
      this.clothing,
      this.ears,
      this.sad,
      this.sadFace);
  final bool sad;
  final ui.Image? sadFace;
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
  final PetAppearance appearance;
  final SpriteSheet? clothing;
  final SpriteSheet? ears;
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
        {double angle = 0, Offset? pivot, bool face = false, ui.Image? image}) {
      c.save();
      if (angle != 0) {
        final p = pivot ?? to.center;
        c.translate(p.dx, p.dy);
        c.rotate(angle);
        c.translate(-p.dx, -p.dy);
      }
      c.drawImageRect(image ?? (face ? faceRig! : rig!), from, to, paint);
      c.restore();
    }

    final breath = moniIdleWave(t, 4) * 1.5;
    final layout = PetRigLayout(appearance, stage);
    final selected = {...outfit.values, if (equipped != null) equipped!};
    void accessory(String id, Offset center, double width, {double angle = 0}) {
      if (!selected.contains(id) ||
          accessories == null ||
          accessoryBounds.length != 9) {
        return;
      }
      final source = accessoryBounds[accessoryCells[id]!];
      final height = width * source.height / source.width;
      c.save();
      c.translate(center.dx, center.dy);
      c.rotate(angle);
      c.drawImageRect(accessories!, source,
          Rect.fromLTWH(-width / 2, -height / 2, width, height), paint);
      c.restore();
    }

    part(
      layout.tail,
      layout.tailTarget,
      angle: moniIdleWave(t, 4) * .06 + math.sin(progress * 48) * .20 * joy,
      pivot: const Offset(254, 516),
    );
    final bodyTarget = layout.bodyTarget(breath);
    final dressed = selected.contains('raincoat')
        ? 1
        : selected.contains('tshirt')
            ? 0
            : null;
    if (dressed != null && clothing != null) {
      c.drawImageRect(
          clothing!.image, clothing!.cells[dressed], bodyTarget, paint);
    } else {
      part(layout.body, bodyTarget);
    }
    accessory('scarf', Offset(350, 448 + breath), 112, angle: -.10);
    accessory('bowtie', Offset(358, 441 + breath), 62, angle: -.13);
    accessory('balloon', Offset(458, 508 + breath), 110,
        angle: moniIdleWave(t, 2) * .035);
    c.save();
    c.translate(0, breath);
    c.translate(354, 412);
    c.rotate(moniIdleWave(t, 3) * .008);
    c.translate(-354, -412);
    final leftEar = layout.leftEar;
    final rightEar = layout.rightEar;
    void drawLeftEar() => part(
          ears?.cells[layout.age * 2] ?? layout.leftSource,
          leftEar,
          angle: layout.leftAngle +
              moniIdleWave(t, 2) * .015 -
              jump * .10 +
              encore * .08,
          pivot: layout.leftPivot,
          face: true,
          image: ears?.image,
        );
    if (!appearance.unifiedHead && appearance != PetAppearance.tyapa) {
      drawLeftEar();
    }
    if (!appearance.unifiedHead) {
      part(
        ears?.cells[layout.age * 2 + 1] ?? layout.rightSource,
        rightEar,
        angle: layout.rightAngle -
            moniIdleWave(t, 2) * .015 +
            jump * .12 -
            encore * .06,
        pivot: layout.rightPivot,
        face: true,
        image: ears?.image,
      );
    }
    final blink = (t > 2.8 && t < 2.94) ||
        (t > 6.4 && t < 6.54) ||
        (t > 10.1 && t < 10.24);
    if ((blink || happy || jump > .7 || encore > .3) && closedFace != null) {
      c.drawImageRect(
          closedFace!,
          Rect.fromLTWH(0, 0, closedFace!.width.toDouble(),
              closedFace!.height.toDouble()),
          layout.headTarget,
          paint);
    } else if (sad && sadFace != null) {
      c.drawImageRect(
          sadFace!,
          Rect.fromLTWH(
              0, 0, sadFace!.width.toDouble(), sadFace!.height.toDouble()),
          layout.headTarget,
          paint);
    } else {
      part(_headSource(appearance), layout.headTarget, face: true);
    }
    if (appearance == PetAppearance.tyapa) drawLeftEar();
    accessory(
        'bow',
        appearance == PetAppearance.tyapa
            ? const Offset(254, 296)
            : const Offset(268, 281),
        62,
        angle: -.25);
    accessory('cap', layout.capCenter, 148, angle: -.16);
    accessory('glasses', layout.glassesCenter, 166, angle: layout.glassesAngle);
    c.restore();
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _MoniPainter old) =>
      old.rig != rig ||
      old.faceRig != faceRig ||
      old.clothing != clothing ||
      old.ears != ears ||
      old.stage != stage ||
      old.celebrationProgress != celebrationProgress ||
      old.closedFace != closedFace ||
      old.t != t ||
      old.happy != happy ||
      old.sad != sad ||
      old.sadFace != sadFace ||
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
