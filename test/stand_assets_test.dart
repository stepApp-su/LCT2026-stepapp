import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finni/stand/stand_assets.dart';

class _Source extends CachingAssetBundle {
  final calls = <String, int>{};
  bool fail = false;
  @override
  Future<ByteData> load(String key) async {
    calls.update(key, (value) => value + 1, ifAbsent: () => 1);
    await Future<void>.delayed(Duration.zero);
    if (fail) throw StateError('offline');
    return ByteData(4);
  }
}

void main() {
  test('artwork is downloaded once and shared by simultaneous requests',
      () async {
    final source = _Source();
    final bundle = StandAssetBundle(source);
    final results = await Future.wait([
      bundle.load('assets/pet.png'),
      bundle.load('assets/pet.png'),
    ]);
    expect(identical(results[0], results[1]), isTrue);
    expect(await bundle.load('assets/pet.png'), same(results[0]));
    expect(source.calls['assets/pet.png'], 1);
  });

  test('failed downloads can be retried', () async {
    final source = _Source()..fail = true;
    final bundle = StandAssetBundle(source);
    await expectLater(bundle.load('assets/pet.png'), throwsStateError);
    source.fail = false;
    expect(await bundle.load('assets/pet.png'), isA<ByteData>());
    expect(source.calls['assets/pet.png'], 2);
  });

  test('artwork filter excludes sound and content files', () {
    for (final path in ['pet.png', 'room.webp', 'photo.jpg', 'icon.svg']) {
      expect(StandAssetBundle.isArtwork(path), isTrue);
    }
    for (final path in ['music.mp3', 'state.json', 'font.ttf']) {
      expect(StandAssetBundle.isArtwork(path), isFalse);
    }
  });
}
