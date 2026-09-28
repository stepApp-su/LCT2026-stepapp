import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:finni/domain/models/pet.dart';
import 'package:finni/ui/pet_appearance.dart';
import 'package:finni/ui/widgets/pet_rig_layout.dart';

void main() {
  test('Pix ears use matching visible dimensions at each age', () {
    for (final stage in [PetStage.baby, PetStage.teen, PetStage.adult]) {
      final layout = PetRigLayout(PetAppearance.pix, stage);
      expect(layout.leftEar.size, layout.rightEar.size);
    }
  });
  test('Ear crops follow the actual artwork of each age', () {
    for (final pet in [PetAppearance.pix, PetAppearance.bumba]) {
      final baby = PetRigLayout(pet, PetStage.baby);
      final teen = PetRigLayout(pet, PetStage.teen);
      final adult = PetRigLayout(pet, PetStage.adult);
      expect(baby.leftSource, isNot(teen.leftSource));
      expect(teen.leftSource, isNot(adult.leftSource));
      expect(baby.rightSource, isNot(teen.rightSource));
      expect(teen.rightSource, isNot(adult.rightSource));
      expect(baby.leftSource.top, greaterThan(adult.leftSource.top));
    }
  });
  test('Moni keeps the approved attachment positions', () {
    for (final stage in [PetStage.baby, PetStage.teen, PetStage.adult]) {
      final layout = PetRigLayout(PetAppearance.moni, stage);
      expect(layout.leftEar, const Rect.fromLTWH(88, 151, 203, 210));
      expect(layout.rightEar, const Rect.fromLTWH(335, 90, 179, 227));
      expect(layout.leftPivot, const Offset(258, 334));
      expect(layout.rightPivot, const Offset(371, 287));
      expect(layout.leftAngle, -.12);
      expect(layout.rightAngle, .04);
      expect(layout.tailTarget, const Rect.fromLTWH(121, 382, 162, 154));
      expect(layout.headTarget, const Rect.fromLTWH(217, 216, 255, 217));
      expect(layout.bodyTarget(0), const Rect.fromLTWH(214, 406, 209, 187));
    }
  });
  test('Tyapa ears use inward roots rather than their outer edge', () {
    for (final stage in [PetStage.baby, PetStage.teen, PetStage.adult]) {
      final layout = PetRigLayout(PetAppearance.tyapa, stage);
      expect(layout.leftSource.left, greaterThan(layout.rightSource.left));
      expect(layout.leftPivot.dx, greaterThan(layout.leftEar.center.dx));
      expect(layout.rightPivot.dx, lessThan(layout.rightEar.center.dx));
      expect(layout.leftEar.contains(layout.leftPivot), isTrue);
      expect(layout.rightEar.contains(layout.rightPivot), isTrue);
    }
  });
  test('Bumba tail keeps its source aspect ratio', () {
    const layout = PetRigLayout(PetAppearance.bumba, PetStage.adult);
    expect(layout.tailTarget.width / layout.tailTarget.height,
        closeTo(layout.tail.width / layout.tail.height, .01));
  });
  test('Other heads keep their source proportions and neck anchor', () {
    for (final pet in [
      PetAppearance.pix,
      PetAppearance.tyapa,
      PetAppearance.bumba
    ]) {
      for (final stage in [PetStage.baby, PetStage.teen, PetStage.adult]) {
        final layout = PetRigLayout(pet, stage);
        expect(layout.headTarget.width / layout.headTarget.height,
            closeTo(layout.head.width / layout.head.height, .00001));
        expect(layout.headTarget.bottom, 433);
        expect(layout.bodyTarget(0).bottom, 593);
      }
    }
  });
}
