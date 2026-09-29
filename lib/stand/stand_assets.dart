import 'dart:async';
import 'package:flutter/services.dart';

/// Keep downloaded artwork available to painters as well as Image widgets.
class StandAssetBundle extends CachingAssetBundle {
  StandAssetBundle(this.source);
  final AssetBundle source;
  final _loaded = <String, ByteData>{};
  final _pending = <String, Future<ByteData>>{};

  @override
  Future<ByteData> load(String key) async {
    if (_loaded.containsKey(key)) return _loaded[key]!;
    return _pending.putIfAbsent(key, () async {
      try {
        final bytes = await source.load(key);
        if (isArtwork(key)) _loaded[key] = bytes;
        return bytes;
      } finally {
        unawaited(_pending.remove(key));
      }
    });
  }

  static bool isArtwork(String key) =>
      RegExp(r'\.(png|webp|jpg|jpeg|svg)$', caseSensitive: false).hasMatch(key);

  Future<void> preload(void Function(int loaded, int total) progress) async {
    final manifest = await AssetManifest.loadFromAssetBundle(this);
    final paths = manifest.listAssets().where(isArtwork).toList();
    var next = 0, done = 0;
    progress(0, paths.length);
    await Future.wait(List.generate(4, (_) async {
      while (next < paths.length) {
        final path = paths[next++];
        await load(path);
        progress(++done, paths.length);
      }
    }));
  }
}
