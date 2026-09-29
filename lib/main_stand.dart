import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'stand/stand_assets.dart';
import 'stand/stand_launcher.dart';
import 'ui/widgets/artwork_bundle.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final assets = StandAssetBundle(rootBundle);
  artworkBundle = assets;
  runApp(StandLauncher(assets: assets));
}
