import 'package:audioplayers/audioplayers.dart';

/// Проигрыватель звуковой схемы: эффекты и озвучка из assets.
/// Что играть, решает SoundService — сюда приходят готовые пути.
final class SoundPlayer {
  final AudioPlayer _effects = AudioPlayer();
  final AudioPlayer _voice = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();

  /// Короткий эффект; null (звук выключен) молча пропускается.
  Future<void> effect(String? assetPath) async {
    if (assetPath == null) return;
    await _effects.play(AssetSource(_relative(assetPath)));
  }

  /// Озвучка реплики или цепочка бормотания: сэмплы друг за другом.
  Future<void> speak(List<String> assetPaths) async {
    for (final path in assetPaths) {
      await _voice.play(AssetSource(_relative(path)));
      await _voice.onPlayerComplete.first;
    }
  }

  Future<void> stopSpeech() => _voice.stop();

  /// Бесконечная фоновая тема; null (музыка выключена) останавливает её.
  Future<void> music(String? assetPath) async {
    if (assetPath == null) {
      await _music.stop();
      return;
    }
    await _music.stop();
    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.setVolume(0.35);
    await _music.play(AssetSource(_relative(assetPath)));
  }

  void dispose() {
    _effects.dispose();
    _voice.dispose();
    _music.dispose();
  }

  // AssetSource ждёт путь без префикса assets/
  static String _relative(String assetPath) =>
      assetPath.startsWith('assets/') ? assetPath.substring(7) : assetPath;
}
