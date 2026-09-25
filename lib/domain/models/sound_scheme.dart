import 'content_json.dart';

/// Звуковая схема из sounds.json: события, «бормотание» питомцев
/// и заранее записанная озвучка реплик. Пути — внутри assets/audio.
final class SoundScheme {
  const SoundScheme._({
    required this.schemaVersion,
    required this.events,
    required this.babble,
    required this.babbleMaxSyllables,
    required this.voice,
  });

  /// События, которые обязаны быть озвучены.
  static const List<String> requiredEvents = [
    'coin',
    'purchase',
    'task_done',
    'goal_reached',
    'stage_up',
    'title_earned',
    'pet_tap',
    'sleep',
  ];

  factory SoundScheme.fromJson(Map<String, Object?> json) {
    final events = jsonTexts(json['events'], 'events',
        required: {...requiredEvents});
    final rawBabble = jsonMap(json['babble'], 'babble');
    final babble = <String, List<String>>{};
    for (final entry in rawBabble.entries) {
      final files = jsonStrings(entry.value, 'babble.${entry.key}');
      if (files.length < 3) {
        throw ArgumentError.value(files, 'babble.${entry.key}',
            'у питомца минимум 3 сэмпла бормотания');
      }
      if (files.toSet().length != files.length) {
        throw ArgumentError.value(
            files, 'babble.${entry.key}', 'сэмплы не повторяются');
      }
      babble[entry.key] = files;
    }
    if (babble.isEmpty) {
      throw ArgumentError.value(rawBabble, 'babble', 'нет ни одного питомца');
    }
    final rawVoice = jsonMap(json['voice'] ?? const {}, 'voice');
    final voice = {
      for (final entry in rawVoice.entries)
        entry.key: jsonTexts(entry.value, 'voice.${entry.key}'),
    };
    return SoundScheme._(
      schemaVersion: jsonInt(json['schemaVersion'] ?? 1, 'schemaVersion', min: 1),
      events: events,
      babble: Map.unmodifiable(babble),
      babbleMaxSyllables:
          jsonInt(json['babbleMaxSyllables'] ?? 8, 'babbleMaxSyllables', min: 1),
      voice: Map.unmodifiable(voice),
    );
  }

  final int schemaVersion;

  /// Событие -> файл эффекта.
  final Map<String, String> events;

  /// Вид питомца -> сэмплы бормотания в его тембре.
  final Map<String, List<String>> babble;

  final int babbleMaxSyllables;

  /// Вид питомца -> (id реплики -> файл озвучки).
  final Map<String, Map<String, String>> voice;

  /// Все файлы схемы одним списком — для проверки, что каждый существует.
  List<String> get allFiles => List.unmodifiable([
        ...events.values,
        for (final files in babble.values) ...files,
        for (final byPhrase in voice.values) ...byPhrase.values,
      ]);
}
