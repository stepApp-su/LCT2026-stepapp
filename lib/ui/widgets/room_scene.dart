import 'package:flutter/material.dart';
import '../game_controller.dart';
import '../theme/finni_theme.dart';
import 'moni_scene.dart';
import 'sprite_sheet.dart';
import 'room_view.dart';
import 'room_backdrop.dart';

class RoomScene extends StatelessWidget {
  const RoomScene(
      {super.key, required this.state, this.largePet = false, this.pieces});
  final GameController state;
  final bool largePet;
  final List<RoomPiece>? pieces;

  Widget art(String id) => SheetArt(
      path: goalCells.containsKey(id)
          ? 'assets/room/goals.png'
          : 'assets/room/furniture.png',
      cell: goalCells[id] ?? furnitureCells[id]!,
      alignment: Alignment.bottomCenter);

  @override
  Widget build(BuildContext context) {
    final items = state.visibleRoomItems;
    final tint =
        roomTints[state.shop.activeWallpaperId] ?? roomTints['wp_plain']!;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight;
      Widget item(String place, double x, double y, double width,
          {bool grounded = true, double? height}) {
        final id = items[place];
        if (id == null) return const SizedBox.shrink();
        final extent = w * width;
        final itemHeight = height == null ? extent : h * height;
        return Positioned(
            left: w * x - extent / 2,
            bottom: h * (1 - y),
            width: extent,
            height: itemHeight,
            child: IgnorePointer(
                child: Semantics(
              label: state.content.shop.byId(id)?.title ??
                  state.content.goals.byId(id)?.title,
              child: Stack(clipBehavior: Clip.none, children: [
                if (grounded && id != 'rug')
                  Positioned(
                      left: extent * .12,
                      right: extent * .12,
                      bottom: -2,
                      height: extent * .07,
                      child: CustomPaint(painter: _ContactShadow())),
                Positioned.fill(child: art(id)),
              ]),
            )));
      }

      return Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
            top: 26, child: RoomBackdrop(wallpaperId: state.wallpaperId)),
        if (!roomBackgrounds.containsKey(state.wallpaperId))
          Positioned(
              left: w * .045,
              right: w * .045,
              bottom: h * .025,
              height: h * .13,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: Color.lerp(tint, FinniColors.primary, .055),
                      borderRadius: BorderRadius.circular(100)))),
        if (pieces != null) Positioned.fill(child: RoomLayer(pieces: pieces!)),
        if (pieces == null) ...[
          item('floor', .51, .985, .84, height: .19, grounded: false),
          item('wall', .21, .49, .22, grounded: false),
          item('left', .16, .885, .30),
          item('right', .86, .92, items['right'] == 'palm' ? .25 : .17),
        ],
        Positioned.fill(
            top: 14,
            bottom: h * .10,
            left: w * (largePet ? .12 : .16),
            right: w * (largePet ? .12 : .16),
            child: MoniScene(
                appearance: state.appearance,
                stage: state.stage,
                motion: state.motion,
                sad: state.petIsSad,
                onPet: state.petVoice,
                equipped: state.equipped,
                outfit: state.outfit)),
        if (pieces == null) item('toy', .20, .985, .12),
        if (pieces != null)
          Positioned.fill(child: RoomLayer(pieces: pieces!, front: true)),
      ]);
    });
  }
}

class _ContactShadow extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => canvas.drawOval(
      Offset.zero & size,
      Paint()
        ..color = FinniColors.ink.withValues(alpha: .10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  @override
  bool shouldRepaint(covariant _ContactShadow oldDelegate) => false;
}
