import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finni/ui/widgets/room_view.dart';
import 'support/content.dart';

void main() {
  test('all room objects fit and furniture selection markers stay apart',
      () async {
    final content = await loadTestContent();
    final spots =
        content.rooms.byId('main')!.spots.where((s) => s.x != null).toList();
    for (final size in [
      const Size(328, 288.4),
      const Size(398, 344.4),
      const Size(328, 340),
      const Size(398, 440)
    ]) {
      for (final spot in spots) {
        for (final id in spot.accepts) {
          final rect = RoomLayer.rectOf(spot, size, artId: id);
          expect(rect.left, greaterThanOrEqualTo(0), reason: id);
          expect(rect.top, greaterThanOrEqualTo(0), reason: id);
          expect(rect.right, lessThanOrEqualTo(size.width), reason: id);
          expect(rect.bottom, lessThanOrEqualTo(size.height), reason: id);
        }
      }
      final items = spots.where((s) => s.type.name == 'item').toList();
      for (var i = 0; i < items.length; i++) {
        for (var j = i + 1; j < items.length; j++) {
          expect(
              (RoomLayer.markerOf(items[i], size) -
                      RoomLayer.markerOf(items[j], size))
                  .distance,
              greaterThanOrEqualTo(38),
              reason: '${items[i].id} / ${items[j].id} at $size');
        }
      }
    }
  });
}
