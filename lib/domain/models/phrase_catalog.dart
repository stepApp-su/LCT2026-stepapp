/// Банк реплик питомца. Никакой генерации на лету: шаблоны из
/// assets/content/phrases.json с подстановкой чисел. Характер персонажа
/// меняет только подачу — смысл, приоритет и экономика у всех одни.
library;

enum PhraseEmotion {
  happy,
  proud,
  calm,
  think,
  sympathy,
  surprised,
  celebrate,
  sleepy,
}

/// Токены, которые склоняются по стоящему перед ними числу.
const Set<String> kPluralTokens = {'coin', 'day'};

final _placeholder = RegExp(r'\{(\w+)\}');
final _letterOrDigit = RegExp(r'[0-9A-Za-zА-Яа-яЁё]');

Set<String> phrasePlaceholders(String template) =>
    {for (final m in _placeholder.allMatches(template)) m.group(1)!};

int phraseWordCount(String template) {
  var words = 0;
  for (final part in template.split(RegExp(r'\s+'))) {
    if (_letterOrDigit.hasMatch(part)) words++;
  }
  return words;
}

final class PetCharacter {
  const PetCharacter({required this.id, required this.pet, required this.voice});

  final String id;
  final String pet;

  /// Как говорит: для авторов реплик, не для кода.
  final String voice;

  factory PetCharacter.fromJson(String id, Map<String, Object?> json) =>
      PetCharacter(
        id: id,
        pet: json['pet'] as String,
        voice: (json['voice'] ?? '') as String,
      );
}

final class PhraseRules {
  const PhraseRules({
    this.maxWords = 10,
    this.samePlaceholdersInAllCharacters = true,
    this.ttsOnlyWithoutPlaceholders = true,
  });

  final int maxWords;

  /// Характер меняет подачу, а не набор подставляемых чисел.
  final bool samePlaceholdersInAllCharacters;

  /// Озвучка генерируется заранее, поэтому в озвученной реплике
  /// не может быть подставляемых чисел.
  final bool ttsOnlyWithoutPlaceholders;

  factory PhraseRules.fromJson(Map<String, Object?> json) => PhraseRules(
        maxWords: (json['maxWords'] ?? 10) as int,
        samePlaceholdersInAllCharacters:
            (json['samePlaceholdersInAllCharacters'] ?? true) as bool,
        ttsOnlyWithoutPlaceholders:
            (json['ttsOnlyWithoutPlaceholders'] ?? true) as bool,
      );
}

final class PhraseTrigger {
  const PhraseTrigger({
    required this.id,
    required this.description,
    required this.placeholders,
  });

  final String id;
  final String description;

  /// Что код обязан передать в values для этого триггера.
  final List<String> placeholders;

  factory PhraseTrigger.fromJson(String id, Map<String, Object?> json) =>
      PhraseTrigger(
        id: id,
        description: (json['description'] ?? '') as String,
        placeholders: List.unmodifiable([
          for (final p in (json['placeholders'] as List? ?? const []))
            p as String
        ]),
      );
}

final class PhraseAction {
  const PhraseAction({required this.label, required this.route});

  final String label;
  final String route;

  factory PhraseAction.fromJson(Map<String, Object?> json) => PhraseAction(
        label: json['label'] as String,
        route: json['route'] as String,
      );
}

sealed class PhraseMatcher {
  const PhraseMatcher();

  bool test(Object? fact);
}

final class ExactMatch extends PhraseMatcher {
  const ExactMatch(this.value);

  final Object? value;

  @override
  bool test(Object? fact) => fact == value;
}

final class OneOfMatch extends PhraseMatcher {
  const OneOfMatch(this.values);

  final List<Object?> values;

  @override
  bool test(Object? fact) => values.contains(fact);
}

final class AtLeastMatch extends PhraseMatcher {
  const AtLeastMatch(this.value);

  final num value;

  @override
  bool test(Object? fact) => fact is num && fact >= value;
}

final class RangeMatch extends PhraseMatcher {
  const RangeMatch({this.min, this.max});

  final num? min;
  final num? max;

  @override
  bool test(Object? fact) {
    if (fact is! num) return false;
    if (min != null && fact < min!) return false;
    if (max != null && fact > max!) return false;
    return true;
  }
}

/// Условие показа: имя факта -> как его сравнивать. Отсутствующий факт
/// условие не выполняет.
final class PhraseCondition {
  const PhraseCondition(this.matchers);

  static const PhraseCondition always = PhraseCondition({});

  final Map<String, PhraseMatcher> matchers;

  bool get isEmpty => matchers.isEmpty;

  bool matches(Map<String, Object?> facts) {
    for (final entry in matchers.entries) {
      if (!facts.containsKey(entry.key)) return false;
      if (!entry.value.test(facts[entry.key])) return false;
    }
    return true;
  }

  factory PhraseCondition.fromJson(Map<String, Object?> json) {
    final matchers = <String, PhraseMatcher>{};
    for (final entry in json.entries) {
      var key = entry.key;
      final value = entry.value;
      if (key.endsWith('AtLeastPercent')) {
        matchers[key.substring(0, key.length - 'AtLeastPercent'.length)] =
            AtLeastMatch(value as num);
      } else if (key.endsWith('AtLeast')) {
        matchers[key.substring(0, key.length - 'AtLeast'.length)] =
            AtLeastMatch(value as num);
      } else if (value is List) {
        matchers[key] = OneOfMatch(List.unmodifiable(value));
      } else if (value is Map) {
        final range = value.cast<String, Object?>();
        matchers[key] =
            RangeMatch(min: range['min'] as num?, max: range['max'] as num?);
      } else {
        matchers[key] = ExactMatch(value);
      }
    }
    return PhraseCondition(Map.unmodifiable(matchers));
  }
}

final class PhraseDef {
  const PhraseDef({
    required this.id,
    required this.category,
    required this.trigger,
    required this.condition,
    required this.priority,
    required this.cooldown,
    required this.emotion,
    required this.templates,
    required this.action,
    required this.tts,
  });

  final String id;
  final String category;
  final String trigger;
  final PhraseCondition condition;

  /// Чем выше, тем важнее сказать именно это.
  final int priority;

  final Duration cooldown;
  final PhraseEmotion emotion;

  /// Характер -> шаблон.
  final Map<String, String> templates;

  final PhraseAction? action;
  final bool tts;

  String? templateFor(String character) => templates[character];

  Set<String> get placeholders =>
      templates.isEmpty ? const {} : phrasePlaceholders(templates.values.first);

  Set<String> get valuePlaceholders =>
      placeholders.difference(kPluralTokens);

  factory PhraseDef.fromJson(Map<String, Object?> json) => PhraseDef(
        id: json['id'] as String,
        category: json['category'] as String,
        trigger: json['trigger'] as String,
        condition: json['condition'] == null
            ? PhraseCondition.always
            : PhraseCondition.fromJson(
                (json['condition'] as Map).cast<String, Object?>()),
        priority: (json['priority'] ?? 0) as int,
        cooldown: Duration(seconds: (json['cooldownSec'] ?? 0) as int),
        emotion: PhraseEmotion.values.byName(json['emotion'] as String),
        templates: Map.unmodifiable({
          for (final e in (json['templates'] as Map).entries)
            e.key as String: e.value as String
        }),
        action: json['action'] == null
            ? null
            : PhraseAction.fromJson(
                (json['action'] as Map).cast<String, Object?>()),
        tts: (json['tts'] ?? false) as bool,
      );
}

final class PhraseCatalog {
  const PhraseCatalog._({
    required this.schemaVersion,
    required this.characters,
    required this.rules,
    required this.categories,
    required this.triggers,
    required this.phrases,
  });

  factory PhraseCatalog.create({
    int schemaVersion = 1,
    required Map<String, PetCharacter> characters,
    PhraseRules rules = const PhraseRules(),
    Map<String, String> categories = const {},
    required Map<String, PhraseTrigger> triggers,
    required List<PhraseDef> phrases,
  }) {
    if (characters.isEmpty) throw ArgumentError('нет ни одного персонажа');
    if (phrases.isEmpty) throw ArgumentError('банк реплик пуст');

    final ids = <String>{};
    for (final phrase in phrases) {
      if (!ids.add(phrase.id)) {
        throw ArgumentError.value(phrase.id, 'id', 'повторяется');
      }
      if (categories.isNotEmpty && !categories.containsKey(phrase.category)) {
        throw ArgumentError.value(
            phrase.category, phrase.id, 'нет такой категории');
      }
      final trigger = triggers[phrase.trigger];
      if (trigger == null) {
        throw ArgumentError.value(
            phrase.trigger, phrase.id, 'нет такого триггера');
      }
      if (phrase.priority < 0 || phrase.cooldown.isNegative) {
        throw ArgumentError.value(
            phrase.id, 'priority/cooldown', 'отрицательное значение');
      }

      Set<String>? first;
      for (final character in characters.keys) {
        final template = phrase.templateFor(character);
        if (template == null || template.trim().isEmpty) {
          throw ArgumentError.value(
              character, phrase.id, 'нет варианта для этого характера');
        }
        if (phraseWordCount(template) > rules.maxWords) {
          throw ArgumentError.value(template, phrase.id,
              'длиннее ${rules.maxWords} слов — ребёнок не прочитает');
        }
        final used = phrasePlaceholders(template);
        first ??= used;
        if (rules.samePlaceholdersInAllCharacters && !_same(first, used)) {
          throw ArgumentError.value(character, phrase.id,
              'характер поменял набор подставляемых чисел');
        }
        for (final placeholder in used) {
          if (kPluralTokens.contains(placeholder)) continue;
          if (!trigger.placeholders.contains(placeholder)) {
            throw ArgumentError.value(placeholder, phrase.id,
                'триггер «${trigger.id}» такое число не передаёт');
          }
        }
      }
      if (rules.ttsOnlyWithoutPlaceholders &&
          phrase.tts &&
          phrase.placeholders.isNotEmpty) {
        throw ArgumentError.value(phrase.id, 'tts',
            'озвучка пишется заранее, в ней не может быть чисел');
      }
      final action = phrase.action;
      if (action != null && (action.label.isEmpty || action.route.isEmpty)) {
        throw ArgumentError.value(phrase.id, 'action', 'кнопка без текста или маршрута');
      }
    }

    return PhraseCatalog._(
      schemaVersion: schemaVersion,
      characters: Map.unmodifiable(characters),
      rules: rules,
      categories: Map.unmodifiable(categories),
      triggers: Map.unmodifiable(triggers),
      phrases: List.unmodifiable(phrases),
    );
  }

  static bool _same(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  factory PhraseCatalog.fromJson(Map<String, Object?> json) =>
      PhraseCatalog.create(
        schemaVersion: (json['schemaVersion'] ?? 1) as int,
        characters: {
          for (final e in (json['characters'] as Map).entries)
            e.key as String: PetCharacter.fromJson(
                e.key as String, (e.value as Map).cast<String, Object?>())
        },
        rules: json['rules'] == null
            ? const PhraseRules()
            : PhraseRules.fromJson(
                (json['rules'] as Map).cast<String, Object?>()),
        categories: {
          for (final e in ((json['categories'] as Map?) ?? const {}).entries)
            e.key as String: e.value as String
        },
        triggers: {
          for (final e in (json['triggers'] as Map).entries)
            e.key as String: PhraseTrigger.fromJson(
                e.key as String, (e.value as Map).cast<String, Object?>())
        },
        phrases: [
          for (final raw in (json['phrases'] as List))
            PhraseDef.fromJson((raw as Map).cast<String, Object?>())
        ],
      );

  final int schemaVersion;
  final Map<String, PetCharacter> characters;
  final PhraseRules rules;
  final Map<String, String> categories;
  final Map<String, PhraseTrigger> triggers;
  final List<PhraseDef> phrases;

  PhraseDef? byId(String id) {
    for (final phrase in phrases) {
      if (phrase.id == id) return phrase;
    }
    return null;
  }

  List<PhraseDef> byTrigger(String trigger) => List.unmodifiable(
      [for (final p in phrases) if (p.trigger == trigger) p]);

  List<PhraseDef> byCategory(String category) => List.unmodifiable(
      [for (final p in phrases) if (p.category == category) p]);
}
