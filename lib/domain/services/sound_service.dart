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
  /// Нет записи — вернётся null, и реплику «проговорит» бормотание.
  String? voiceFor(String phraseId,
      {required String species, required bool soundOn}) {
    if (!soundOn) return null;
    final file = _scheme.voice[species]?[phraseId];
    return file == null ? null : assetRoot + file;
  }

  /// «Бормотание»: по сэмплу на слог текста, в тембре своего питомца.
  /// Выбор детерминирован сидом — та же реплика звучит одинаково.
  List<String> babbleFor(String text,
      {required String species, required int seed, required bool soundOn}) {
    if (!soundOn) return const [];
    final samples = _scheme.babble[species];
    if (samples == null) {
      throw ArgumentError.value(species, 'species', 'нет тембра бормотания');
    }
    final syllables =
        _syllables(text).clamp(1, _scheme.babbleMaxSyllables);
    // домен без Random: свой детерминированный шаг от сида
    var mix = seed & 0x7fffffff;
    return List.unmodifiable([
      for (var i = 0; i < syllables; i++)
        assetRoot +
            samples[(mix = (mix * 1103515245 + 12345 + i) & 0x7fffffff) %
                samples.length]
    ]);
  }

  static const String _vowels = 'аеёиоуыэюяaeiouy';

  int _syllables(String text) {
    var count = 0;
    for (final code in text.toLowerCase().runes) {
      if (_vowels.contains(String.fromCharCode(code))) count++;
    }
    return count;
  }
}
