import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:finni/domain/models/pet.dart';
import 'package:finni/ui/pet_appearance.dart';
import 'package:finni/ui/widgets/pet_head_layout.dart';
import 'package:finni/ui/widgets/pet_sprite_set.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final pet in PetAppearance.values.where((pet) => pet.unifiedHead)) {
    test('${pet.name}: sadness preserves pupil pixels at every age', () async {
      final set = await PetSpriteSet.load(pet);
      try {
        const ages = [PetStage.baby, PetStage.teen, PetStage.adult];
        for (var age = 0; age < ages.length; age++) {
          final rig = set.rigs[ages[age]]!;
          final normal = (await rig.toByteData())!;
          final sad = (await set.sad[ages[age]]!.toByteData())!;
          final layout = PetHeadLayout(pet, age);
          for (final dx in [-55.0, 55.0]) {
            final eye = layout.project(layout.eyeCenter + Offset(dx, 0),
                const Rect.fromLTWH(0, 0, 600, 600));
            for (var y = eye.dy.round() - 8; y <= eye.dy.round() + 8; y++) {
              for (var x = eye.dx.round() - 8; x <= eye.dx.round() + 8; x++) {
                for (var channel = 0; channel < 4; channel++) {
                  expect(
                      sad.getUint8((y * 600 + x) * 4 + channel),
                      closeTo(
                          normal.getUint8(
                              (y * rig.width + 480 + x) * 4 + channel),
                          1),
                      reason: '${ages[age].name}, eye $dx, pixel $x,$y');
                }
              }
            }
          }
        }
      } finally {
        for (final image in [
          ...set.rigs.values,
          ...set.closed.values,
          ...set.sad.values
        ]) {
          image.dispose();
        }
      }
    });
  }
}
