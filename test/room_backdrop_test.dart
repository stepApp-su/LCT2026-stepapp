import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finni/ui/widgets/room_backdrop.dart';

void main() {
  test('three room backgrounds are bundled locally', () {
    expect(roomBackgrounds.keys,
        containsAll(['wp_plain', 'wp_leaves', 'wp_space']));
    for (final path in roomBackgrounds.values) {
      expect(File(path).readAsBytesSync().take(8),
          [137, 80, 78, 71, 13, 10, 26, 10]);
    }
  });
  testWidgets('background preserves normalized room anchors without cropping',
      (tester) async {
    for (final width in [360.0, 390.0, 430.0]) {
      for (final id in roomBackgrounds.keys) {
        await tester.pumpWidget(MaterialApp(
            home: Center(
                child: SizedBox(
          width: width,
          height: 300,
          child: RoomBackdrop(wallpaperId: id),
        ))));
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.fit, BoxFit.fill);
        expect(image.alignment, Alignment.bottomCenter);
        expect(find.byType(ClipRRect), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });
  testWidgets('other wallpapers keep their solid fallback', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: RoomBackdrop(wallpaperId: 'wp_clouds')));
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
