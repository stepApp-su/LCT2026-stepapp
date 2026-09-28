import 'package:flutter/material.dart';

const roomBackgrounds = {
  'wp_plain': 'assets/room/nursery.png',
  'wp_leaves': 'assets/room/garden.png',
  'wp_space': 'assets/room/space.png',
};

const roomTints = {
  'wp_plain': Color(0xffE7EFE1),
  'wp_stripes': Color(0xffEEE9DF),
  'wp_dots': Color(0xffF1E5E0),
  'wp_clouds': Color(0xffE3EDF3),
  'wp_leaves': Color(0xffE1ECDC),
  'wp_stars': Color(0xffECE6F2),
  'wp_space': Color(0xffDFE1EE),
};

class RoomBackdrop extends StatelessWidget {
  const RoomBackdrop(
      {super.key, required this.wallpaperId, this.thumbnail = false});
  final String wallpaperId;
  final bool thumbnail;

  @override
  Widget build(BuildContext context) {
    final path = roomBackgrounds[wallpaperId];
    return ExcludeSemantics(
        child: ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(thumbnail ? 28 : 150),
        bottom: Radius.circular(thumbnail ? 10 : 48),
      ),
      child: ColoredBox(
        color: roomTints[wallpaperId] ?? roomTints['wp_plain']!,
        child: path == null
            ? const SizedBox.expand()
            : Image.asset(
                path,
                fit: BoxFit.fill,
                alignment: Alignment.bottomCenter,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
              ),
      ),
    ));
  }
}
