import '../models/sound_scheme.dart';

/// Выбирает, что сыграть на событие или реплику. Только выбор файлов —
/// само воспроизведение живёт в data-слое. Выключенный звук — тишина;
/// текст на экране есть всегда, так что без звука ничего не теряется.
final class SoundService {
  SoundService({required SoundScheme scheme}) : _scheme = scheme;

  static const String assetRoot = 'assets/audio/';

  final SoundScheme _scheme;

  /// Эффект события (монета, покупка, фанфары и т.д.).
  String? forEvent(String event, {required bool soundOn}) {
    final file = _scheme.events[event];
    if (file == null) {
      throw ArgumentError.value(event, 'event', 'нет такого события');
    }
    return soundOn ? assetRoot + file : null;
  }

  /// Записанная озвучка реплики, если она есть для этого вида питомца.
  /// Нет записи — вернётся null, и питомец отзовётся своим голоском.
  String? voiceFor(String phraseId,
      {required String species, required bool soundOn}) {
    if (!soundOn) return null;
    final file = _scheme.voice[species]?[phraseId];
    return file == null ? null : assetRoot + file;
  }

  /// Фоновая тема по имени; выключенная музыка — тишина.
  String? musicFor(String name, {required bool musicOn}) {
    final file = _scheme.music[name];
    if (file == null) {
      throw ArgumentError.value(name, 'name', 'нет такой темы');
    }
    return musicOn ? assetRoot + file : null;
  }

  /// Голосок питомца (смешок, писк, «гав») — на реплику без записи
  /// и на поглаживание. Варианты чередуются по номеру [turn].
  /// Вид без голоска молчит, а не ломает реплику.
  String? petSound(String species, {required int turn, required bool soundOn}) {
    if (!soundOn) return null;
    final files = _scheme.pets[species];
    if (files == null) return null;
    return assetRoot + files[turn.abs() % files.length];
  }
}
