import 'content_json.dart';

/// Звуковая схема из sounds.json: события, голоски питомцев
/// и заранее записанная озвучка реплик. Пути — внутри assets/audio.
final class SoundScheme {
  const SoundScheme._({
    required this.schemaVersion,
    required this.events,
    required this.pets,
    required this.voice,
    required this.music,
  });

  /// События, которые обязаны быть озвучены.
  static const List<String> requiredEvents = [
    'coin',
    'purchase',
    'task_done',
    'goal_reached',
    'stage_up',
    'title_earned',
    'sleep',
  ];

  factory SoundScheme.fromJson(Map<String, Object?> json) {
    final events = jsonTexts(json['events'], 'events',
        required: {...requiredEvents});
    final rawPets = jsonMap(json['pets'], 'pets');
    final pets = <String, List<String>>{};
    for (final entry in rawPets.entries) {
      final files = jsonStrings(entry.value, 'pets.${entry.key}');
      if (files.isEmpty) {
        throw ArgumentError.value(
            files, 'pets.${entry.key}', 'у питомца нет голоска');
      }
      if (files.toSet().length != files.length) {
        throw ArgumentError.value(
            files, 'pets.${entry.key}', 'файлы не повторяются');
      }
      pets[entry.key] = files;
    }
    if (pets.isEmpty) {
      throw ArgumentError.value(rawPets, 'pets', 'нет ни одного питомца');
    }
    final music = jsonTexts(json['music'] ?? const {}, 'music');
    final rawVoice = jsonMap(json['voice'] ?? const {}, 'voice');
    final voice = {
      for (final entry in rawVoice.entries)
        entry.key: jsonTexts(entry.value, 'voice.${entry.key}'),
    };
    return SoundScheme._(
      schemaVersion: jsonInt(json['schemaVersion'] ?? 1, 'schemaVersion', min: 1),
      events: events,
      pets: Map.unmodifiable(pets),
      voice: Map.unmodifiable(voice),
      music: music,
    );
  }

  final int schemaVersion;

  /// Событие -> файл эффекта.
  final Map<String, String> events;

  /// Вид питомца -> его голоски (смешок, писк, «гав»), по очереди.
  final Map<String, List<String>> pets;

  /// Вид питомца -> (id реплики -> файл озвучки).
  final Map<String, Map<String, String>> voice;

  /// Фоновая музыка: имя темы -> файл.
  final Map<String, String> music;

  /// Все файлы схемы одним списком — для проверки, что каждый существует.
  List<String> get allFiles => List.unmodifiable([
        ...events.values,
        ...music.values,
        for (final files in pets.values) ...files,
        for (final byPhrase in voice.values) ...byPhrase.values,
      ]);
}
