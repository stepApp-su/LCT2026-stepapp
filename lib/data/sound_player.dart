import 'package:audioplayers/audioplayers.dart';

/// Проигрыватель звуковой схемы: эффекты и озвучка из assets.
/// Что играть, решает SoundService — сюда приходят готовые пути.
final class SoundPlayer {
  final AudioPlayer _effects = AudioPlayer();
  final AudioPlayer _voice = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  String? _theme;
  int _speech = 0;

  /// Короткий эффект; null (звук выключен) молча пропускается.
  Future<void> effect(String? assetPath) async {
    if (assetPath == null) return;
    // до первого касания браузер звук не пускает — такие попытки пропускаем
    try {
      await _effects.play(AssetSource(_relative(assetPath)));
    } catch (_) {}
  }

  /// Озвучка реплики или цепочка бормотания: сэмплы друг за другом.
  /// Новая реплика обрывает недоговорённую старую.
  Future<void> speak(List<String> assetPaths) async {
    final turn = ++_speech;
    for (final path in assetPaths) {
      if (turn != _speech) return;
      try {
        await _voice.play(AssetSource(_relative(path)));
        await _voice.onPlayerComplete.first;
      } catch (_) {
        return;
      }
    }
  }

  Future<void> stopSpeech() {
    _speech++;
    return _voice.stop();
  }

  /// Бесконечная фоновая тема; та же тема не перезапускается,
  /// null (музыка выключена) останавливает.
  Future<void> music(String? assetPath) async {
    if (assetPath == _theme) return;
    _theme = assetPath;
    await _music.stop();
    if (assetPath == null) return;
    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.setVolume(0.35);
    await _startMusic();
  }

  /// Повтор запуска темы, если браузер не дал начать её без касания.
  Future<void> resumeMusic() async {
    if (_theme == null || _music.state == PlayerState.playing) return;
    await _startMusic();
  }

  Future<void> _startMusic() async {
    final theme = _theme;
    if (theme == null) return;
    try {
      await _music.play(AssetSource(_relative(theme)));
    } catch (_) {}
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
