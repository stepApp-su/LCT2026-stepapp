import 'dart:ui';
import '../../domain/models/pet.dart';
import '../pet_appearance.dart';

class PetRigLayout {
  const PetRigLayout(this.pet, this.stage);
  final PetAppearance pet;
  final PetStage stage;
  int get age => stage == PetStage.adult
      ? 2
      : stage == PetStage.teen
          ? 1
          : 0;
  Rect get head => switch (pet) {
        PetAppearance.moni => const Rect.fromLTWH(480, 65, 449, 383),
        PetAppearance.pix => const Rect.fromLTWH(474, 8, 500, 446),
        PetAppearance.tyapa => const Rect.fromLTWH(500, 6, 503, 458),
        PetAppearance.bumba => const Rect.fromLTWH(574, 24, 495, 445),
      };
  Rect get closed => switch (pet) {
        PetAppearance.moni => const Rect.fromLTWH(480, 468, 450, 388),
        PetAppearance.pix => const Rect.fromLTWH(474, 414, 500, 446),
        PetAppearance.tyapa => const Rect.fromLTWH(480, 385, 503, 458),
        PetAppearance.bumba => const Rect.fromLTWH(551, 410, 495, 445),
      };
  Rect get body => switch (pet) {
        PetAppearance.tyapa => const Rect.fromLTWH(30, 80, 459, 380),
        PetAppearance.bumba => const Rect.fromLTWH(94, 102, 475, 366),
        _ => const Rect.fromLTWH(42, 90, 410, 367),
      };
  Rect get tail => switch (pet) {
        PetAppearance.tyapa => const Rect.fromLTWH(35, 474, 421, 378),
        PetAppearance.bumba => const Rect.fromLTWH(32, 485, 496, 375),
        _ => const Rect.fromLTWH(42, 469, 397, 377),
      };
  Rect get leftSource => switch (pet) {
        PetAppearance.moni => const Rect.fromLTWH(944, 48, 390, 403),
        PetAppearance.pix => [
            const Rect.fromLTWH(1005, 130, 325, 295),
            const Rect.fromLTWH(982, 88, 355, 360),
            const Rect.fromLTWH(994, 31, 345, 410),
          ][age],
        PetAppearance.tyapa => const Rect.fromLTWH(1382, 64, 371, 385),
        PetAppearance.bumba => [
            const Rect.fromLTWH(1113, 141, 221, 266),
            const Rect.fromLTWH(1085, 113, 256, 327),
            const Rect.fromLTWH(1095, 76, 271, 358),
          ][age],
      };
  Rect get rightSource => switch (pet) {
        PetAppearance.moni => const Rect.fromLTWH(1363, 43, 399, 411),
        PetAppearance.pix => [
            const Rect.fromLTWH(1389, 129, 335, 296),
            const Rect.fromLTWH(1381, 82, 362, 370),
            const Rect.fromLTWH(1386, 30, 361, 416),
          ][age],
        PetAppearance.tyapa => const Rect.fromLTWH(1010, 63, 342, 383),
        PetAppearance.bumba => [
            const Rect.fromLTWH(1468, 142, 234, 276),
            const Rect.fromLTWH(1468, 99, 269, 340),
            const Rect.fromLTWH(1490, 58, 214, 377),
          ][age],
      };
  Rect get leftEar => switch (pet) {
        PetAppearance.moni => const Rect.fromLTWH(88, 151, 203, 210),
        PetAppearance.pix => [
            const Rect.fromLTWH(172, 260, 118, 108),
            const Rect.fromLTWH(165, 226, 121, 126),
            const Rect.fromLTWH(172, 163, 135, 161)
          ][age],
        PetAppearance.tyapa => [
            const Rect.fromLTWH(148, 252, 126, 142),
            const Rect.fromLTWH(139, 243, 134, 187),
            const Rect.fromLTWH(130, 239, 142, 213)
          ][age],
        PetAppearance.bumba => [
            const Rect.fromLTWH(203, 266, 61, 73),
            const Rect.fromLTWH(190, 225, 86, 110),
            const Rect.fromLTWH(181, 195, 105, 139)
          ][age],
      };
  Rect get rightEar => switch (pet) {
        PetAppearance.moni => const Rect.fromLTWH(335, 90, 179, 227),
        PetAppearance.pix => [
            const Rect.fromLTWH(370, 231, 118, 108),
            const Rect.fromLTWH(367, 197, 121, 126),
            const Rect.fromLTWH(362, 134, 135, 161)
          ][age],
        PetAppearance.tyapa => [
            const Rect.fromLTWH(375, 230, 124, 134),
            const Rect.fromLTWH(375, 219, 146, 179),
            const Rect.fromLTWH(382, 229, 146, 203)
          ][age],
        PetAppearance.bumba => [
            const Rect.fromLTWH(360, 220, 51, 62),
            const Rect.fromLTWH(358, 195, 67, 85),
            const Rect.fromLTWH(361, 180, 64, 112)
          ][age],
      };
  Offset get glassesCenter => switch (pet) {
        PetAppearance.moni => const Offset(345, 347),
        PetAppearance.pix => const Offset(348, 362),
        PetAppearance.tyapa => const Offset(353, 351),
        PetAppearance.bumba => const Offset(347, 356),
      };

  Offset get capCenter => Offset(352, switch (pet) {
    PetAppearance.moni => 258,
    PetAppearance.pix => age == 0 ? 268 : 257,
    PetAppearance.bumba => age == 0 ? 267 : 256,
    PetAppearance.tyapa => 257,
  });

  Rect backpackTarget(double breath) => Rect.fromLTWH(
      pet == PetAppearance.bumba ? 218 : 212, 422 + breath, 88, 113);

  Path get backpackStrap => Path()
    ..moveTo(292, 424)
    ..cubicTo(312, 436, 307, 471, 280, 493)
    ..quadraticBezierTo(271, 500, 263, 496);

  Rect get tailTarget => switch (pet) {
        PetAppearance.bumba => const Rect.fromLTWH(107, 401, 200, 151),
        PetAppearance.tyapa => const Rect.fromLTWH(147, 416, 126, 113),
        PetAppearance.pix => const Rect.fromLTWH(133, 401, 145, 138),
        PetAppearance.moni => const Rect.fromLTWH(121, 382, 162, 154),
      };
  Rect get headTarget => pet == PetAppearance.moni
      ? const Rect.fromLTWH(217, 216, 255, 217)
      : Rect.fromLTWH(217, 433 - 255 * head.height / head.width, 255,
          255 * head.height / head.width);
  Rect bodyTarget(double breath) => switch (pet) {
        PetAppearance.bumba =>
          Rect.fromLTWH(198, 408 + breath, 240, 185 - breath),
        PetAppearance.tyapa =>
          Rect.fromLTWH(208, 410 + breath, 221, 183 - breath),
        _ => Rect.fromLTWH(214, 406 + breath, 209, 187 - breath),
      };
  double get leftAngle => switch (pet) {
        PetAppearance.moni => -.12,
        PetAppearance.tyapa => .05,
        _ => 0,
      };
  double get rightAngle => switch (pet) {
        PetAppearance.moni => .04,
        PetAppearance.pix => -.15,
        PetAppearance.tyapa => .18,
        _ => 0,
      };
  Offset get leftPivot => switch (pet) {
        PetAppearance.moni => const Offset(258, 334),
        PetAppearance.tyapa => Offset(leftEar.right - 22, leftEar.top + 20),
        _ => Offset(leftEar.center.dx, leftEar.bottom - 15),
      };
  Offset get rightPivot => switch (pet) {
        PetAppearance.moni => const Offset(371, 287),
        PetAppearance.tyapa => Offset(rightEar.left + 22, rightEar.top + 20),
        _ => Offset(rightEar.center.dx, rightEar.bottom - 15),
      };
}
