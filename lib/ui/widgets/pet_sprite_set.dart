import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../domain/models/pet.dart';
import '../pet_appearance.dart';
import 'sprite_sheet.dart';
import 'pet_head_layout.dart';

/// Whole heads keep ears and facial landmarks registered across expressions.
class PetSpriteSet {
  PetSpriteSet(this.rigs, this.closed, this.sad, this.clothing);
  final Map<PetStage, ui.Image> rigs, closed, sad;
  final SpriteSheet clothing;

  static Future<SpriteSheet> bodies(PetAppearance pet) => SpriteSheet.load(
        '${pet.assets}/body.png',
        3,
        2,
        regions: [
          for (var row = 0; row < 2; row++)
            for (var col = 0; col < 3; col++)
              Rect.fromLTWH(
                  col * 512, row == 0 ? 0 : 558, 512, row == 0 ? 558 : 466),
        ],
      );

  static Future<PetSpriteSet> load(PetAppearance pet) async {
    final heads = await SpriteSheet.load('${pet.assets}/heads.png', 3, 3,
        trim: false, regions: PetHeadLayout.regions(pet));
    final body = await bodies(pet);
    final rigs = <PetStage, ui.Image>{};
    final closed = <PetStage, ui.Image>{};
    final sad = <PetStage, ui.Image>{};
    const ages = [PetStage.baby, PetStage.teen, PetStage.adult];
    final paint = Paint()..filterQuality = FilterQuality.high;
    for (var age = 0; age < ages.length; age++) {
      final neutral = heads.cells[age * 3];
      const headBox = Rect.fromLTWH(0, 0, 600, 600);
      final headSize = applyBoxFit(BoxFit.contain, neutral.size, headBox.size);
      final headTo =
          Alignment.bottomCenter.inscribe(headSize.destination, headBox);
      ui.Image? neutralFace;
      Future<ui.Image> face(int expression) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        if (neutralFace == null) {
          canvas.drawImageRect(heads.image, neutral, headTo, paint);
        } else {
          canvas.drawImage(neutralFace, Offset.zero, paint);
        }
        if (expression != 0) {
          final changed = heads.cells[age * 3 + expression];
          // Keep the neutral outline, hair and attached ears for every frame.
          final faceTop = pet == PetAppearance.puf && age > 0 ? .57 : .32;
          final mask = Rect.fromLTRB(
              headTo.left + headTo.width * .12,
              headTo.top + headTo.height * faceTop,
              headTo.right - headTo.width * .10,
              headTo.bottom - 3);
          final masks = expression == 1
              ? PetHeadLayout(pet, age).sadPatches.map((r) => Rect.fromPoints(
                  PetHeadLayout(pet, age).project(r.topLeft, headBox),
                  PetHeadLayout(pet, age).project(r.bottomRight, headBox)))
              : [mask];
          for (final mask in masks) {
            canvas.saveLayer(headBox, Paint());
            canvas.drawImageRect(heads.image, changed, headTo, paint);
            canvas.save();
            canvas.translate(mask.center.dx, mask.center.dy);
            canvas.scale(mask.width / 2, mask.height / 2);
            canvas.drawRect(
                const Rect.fromLTWH(-20, -20, 40, 40),
                Paint()
                  ..blendMode = BlendMode.dstIn
                  ..shader = ui.Gradient.radial(
                      Offset.zero,
                      1,
                      [Colors.white, Colors.white, Colors.transparent],
                      [0, .86, 1]));
            canvas.restore();
            canvas.restore();
          }
        }
        final picture = recorder.endRecording();
        final image = await picture.toImage(600, 600);
        picture.dispose();
        return image;
      }

      final normal = await face(0);
      neutralFace = normal;
      closed[ages[age]] = await face(2);
      sad[ages[age]] = await face(1);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(body.image, body.cells[0],
          const Rect.fromLTWH(42, 90, 410, 367), paint);
      final tailSize =
          applyBoxFit(BoxFit.contain, body.cells[3].size, const Size(397, 377));
      canvas.drawImageRect(
          body.image,
          body.cells[3],
          Alignment.center.inscribe(
              tailSize.destination, const Rect.fromLTWH(42, 469, 397, 377)),
          paint);
      canvas.drawImage(normal, const Offset(480, 0), paint);
      final picture = recorder.endRecording();
      rigs[ages[age]] = await picture.toImage(1774, 887);
      picture.dispose();
      normal.dispose();
    }
    return PetSpriteSet(rigs, closed, sad,
        SpriteSheet(body.image, [body.cells[1], body.cells[2]]));
  }
}
