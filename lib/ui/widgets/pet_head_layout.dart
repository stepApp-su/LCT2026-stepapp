import 'dart:ui';
import '../pet_appearance.dart';

/// Bounds include the full ear silhouette, not equal atlas grid cells.
class PetHeadLayout {
  const PetHeadLayout(this.pet, this.age);
  final PetAppearance pet;
  final int age;

  static const bounds = {
    PetAppearance.puf: [
      [37, 89, 420, 356],
      [436, 87, 817, 356],
      [835, 89, 1218, 357],
      [55, 415, 415, 773],
      [448, 415, 806, 772],
      [839, 413, 1199, 774],
      [49, 802, 421, 1164],
      [441, 802, 812, 1164],
      [833, 802, 1206, 1164],
    ],
    PetAppearance.roni: [
      [59, 108, 411, 391],
      [449, 108, 802, 391],
      [842, 108, 1194, 391],
      [54, 460, 423, 764],
      [446, 459, 816, 764],
      [838, 460, 1207, 764],
      [41, 812, 434, 1145],
      [437, 811, 827, 1146],
      [830, 811, 1225, 1146],
    ],
    PetAppearance.tori: [
      [47, 107, 398, 389],
      [452, 107, 802, 389],
      [855, 107, 1206, 389],
      [35, 464, 420, 759],
      [439, 466, 821, 760],
      [838, 466, 1222, 760],
      [28, 821, 425, 1141],
      [433, 821, 826, 1141],
      [835, 821, 1231, 1141],
    ],
    PetAppearance.busya: [
      [52, 90, 413, 368],
      [446, 90, 805, 368],
      [839, 90, 1199, 368],
      [44, 460, 423, 753],
      [435, 460, 816, 753],
      [828, 460, 1209, 753],
      [25, 832, 431, 1158],
      [432, 832, 825, 1158],
      [826, 832, 1220, 1158],
    ],
    PetAppearance.leo: [
      [37, 112, 413, 382],
      [437, 112, 813, 381],
      [837, 112, 1214, 382],
      [28, 456, 421, 754],
      [428, 455, 821, 754],
      [830, 454, 1226, 756],
      [26, 814, 421, 1164],
      [427, 813, 822, 1165],
      [830, 815, 1229, 1168],
    ],
  };

  static List<Rect> regions(PetAppearance pet) => [
        for (final b in bounds[pet]!)
          Rect.fromLTRB(b[0].toDouble(), b[1].toDouble(), b[2].toDouble(),
              b[3].toDouble()),
      ];

  Rect get source => regions(pet)[age * 3];
  Offset get eyeCenter => switch (pet) {
        PetAppearance.puf => [
            const Offset(245, 272),
            const Offset(245, 684),
            const Offset(245, 1074)
          ][age],
        PetAppearance.roni => [
            const Offset(248, 284),
            const Offset(244, 652),
            const Offset(244, 1030)
          ][age],
        PetAppearance.tori => [
            const Offset(232, 288),
            const Offset(240, 650),
            const Offset(239, 1030)
          ][age],
        PetAppearance.busya => [
            const Offset(247, 267),
            const Offset(250, 643),
            const Offset(250, 1038)
          ][age],
        _ => [
            const Offset(232, 280),
            const Offset(232, 650),
            const Offset(232, 1032)
          ][age],
      };

  Offset project(Offset point, Rect target) {
    final scale = target.width / source.width;
    return Offset(target.left + (point.dx - source.left) * scale,
        target.bottom - (source.bottom - point.dy) * scale);
  }

  List<Rect> get sadPatches {
    final eye = eyeCenter;
    return [
      Rect.fromLTWH(eye.dx - 115, eye.dy - 89, 88, 48),
      Rect.fromLTWH(eye.dx + 27, eye.dy - 92, 88, 49),
      Rect.fromLTWH(
          eye.dx - 62, eye.dy + (pet == PetAppearance.puf ? 24 : 32), 124, 63),
    ];
  }
}
