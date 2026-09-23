/// Выбор реплики питомца: приоритет, кулдаун и никаких повторов подряд.
library;

import '../game_clock.dart';
import '../models/models.dart';
import '../ru_words.dart';
import '../text_template.dart';

final class PhraseLine {
  const PhraseLine({
    required this.id,
    required this.category,
    required this.trigger,
    required this.textRu,
    required this.emotion,
    required this.action,
    required this.tts,
  });

  final String id;
  final String category;
  final String trigger;
  final String textRu;
  final PhraseEmotion emotion;
  final PhraseAction? action;

  /// Есть заранее записанная озвучка. Текст на экране всё равно обязателен.
  final bool tts;
}

final class PhraseService {
  PhraseService({
    required PhraseCatalog catalog,
    required GameClock clock,
    required String character,
  })  : _catalog = catalog,
        _clock = clock {
    _character = _requireCharacter(character);
  }

  final PhraseCatalog _catalog;
  final GameClock _clock;
  final Map<String, DateTime> _shownAt = {};

  late String _character;
  String? _lastShownId;

  PhraseCatalog get catalog => _catalog;
  String get character => _character;
  String? get lastShownId => _lastShownId;

  String _requireCharacter(String id) {
    if (!_catalog.characters.containsKey(id)) {
      throw ArgumentError.value(id, 'character', 'нет такого персонажа');
    }
    return id;
  }

  /// Смена питомца в разделе для взрослого: реплики те же, подача другая.
  void switchCharacter(String id) => _character = _requireCharacter(id);

  /// Что питомец скажет, не отмечая реплику показанной.
  PhraseLine? preview(
    String trigger, {
    Map<String, Object?> facts = const {},
    Map<String, Object> values = const {},
  }) {
    final phrase = _select(trigger, facts);
    return phrase == null ? null : _render(phrase, values);
  }

  /// Реплика на триггер. Отмечает показ: уходит в кулдаун и не повторится
  /// следующей.
  PhraseLine? say(
    String trigger, {
    Map<String, Object?> facts = const {},
    Map<String, Object> values = const {},
  }) {
    final phrase = _select(trigger, facts);
    if (phrase == null) return null;
    final line = _render(phrase, values);
    _shownAt[phrase.id] = _clock.now();
    _lastShownId = phrase.id;
    return line;
  }

  void forget() {
    _shownAt.clear();
    _lastShownId = null;
  }

  bool isOnCooldown(String phraseId) {
    final phrase = _catalog.byId(phraseId);
    final shownAt = _shownAt[phraseId];
    if (phrase == null || shownAt == null) return false;
    return _clock.now().difference(shownAt) < phrase.cooldown;
  }

  PhraseDef? _select(String trigger, Map<String, Object?> facts) {
    final fitting = [
      for (final phrase in _catalog.byTrigger(trigger))
        if (phrase.condition.matches(facts) && !isOnCooldown(phrase.id)) phrase
    ];
    if (fitting.isEmpty) return null;

    final fresh = [for (final p in fitting) if (p.id != _lastShownId) p];
    final pool = fresh.isEmpty ? fitting : fresh;
    pool.sort(_byImportance);
    return pool.first;
  }

  int _byImportance(PhraseDef a, PhraseDef b) {
    final byPriority = b.priority.compareTo(a.priority);
    if (byPriority != 0) return byPriority;
    // Давно не звучавшая — вперёд, иначе питомец твердит одно и то же.
    final shownA = _shownAt[a.id];
    final shownB = _shownAt[b.id];
    if (shownA == null && shownB != null) return -1;
    if (shownA != null && shownB == null) return 1;
    if (shownA != null && shownB != null && shownA != shownB) {
      return shownA.compareTo(shownB);
    }
    return a.id.compareTo(b.id);
  }

  PhraseLine? lineOf(String phraseId, {Map<String, Object> values = const {}}) {
    final phrase = _catalog.byId(phraseId);
    return phrase == null ? null : _render(phrase, values);
  }

  PhraseLine _render(PhraseDef phrase, Map<String, Object> values) {
    final template = phrase.templateFor(_character)!;
    final missing = phrase.valuePlaceholders.difference(values.keys.toSet());
    if (missing.isNotEmpty) {
      throw ArgumentError.value(
          missing.join(', '), phrase.id, 'реплике не передали числа');
    }
    final filled = fillTemplate(
        template, {for (final e in values.entries) e.key: '${e.value}'});
    return PhraseLine(
      id: phrase.id,
      category: phrase.category,
      trigger: phrase.trigger,
      textRu: fillPlurals(filled),
      emotion: phrase.emotion,
      action: phrase.action,
      tts: phrase.tts,
    );
  }
}
