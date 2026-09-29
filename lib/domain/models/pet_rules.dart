/// Правила шкал питомца из assets/content/economy.json (раздел pet).
/// Числа баланса и формулировки живут в JSON, а пол и потолок шкал —
/// в модели PetState: их не ослабит ни один конфиг.
library;

import 'economy.dart';
import 'pet.dart';

/// Ниже этого шкала не опускается никогда (ТЗ: ни одна шкала не достигает
/// нуля). Для уюта пол — стартовые 0: он только растёт.
int petStatFloor(PetStat stat) => switch (stat) {
      PetStat.satiety => PetState.satietyFloor,
      PetStat.care => PetState.careFloor,
      PetStat.mood => PetState.moodFloor,
      PetStat.cozy => 0,
    };

/// Потолок шкалы; у уюта его нет.
int? petStatCap(PetStat stat) => stat == PetStat.cozy ? null : PetState.cap;

/// Уровни настроения по возрастанию. Грустного уровня нет:
/// самое низкое — лёгкая скука.
enum MoodLevel { bored, calm, joy, delight }

final class NeedOccasion {
  const NeedOccasion._({
    required this.from,
    required this.every,
    required this.minStage,
    required this.title,
    required this.hint,
  });

  factory NeedOccasion.create({
    required int from,
    required int every,
    PetStage minStage = PetStage.egg,
    required String title,
    required String hint,
  }) {
    if (from < 1) {
      throw ArgumentError.value(from, 'occasion.from', 'дни нумеруются с 1');
    }
    if (every < 1) {
      throw ArgumentError.value(every, 'occasion.every', 'шаг ≥ 1');
    }
    _requireText(title, 'occasion.title');
    _requireText(hint, 'occasion.hint');
    return NeedOccasion._(
        from: from, every: every, minStage: minStage, title: title, hint: hint);
  }

  factory NeedOccasion.fromJson(Map<String, Object?> json) =>
      NeedOccasion.create(
        from: json['from'] as int,
        every: json['every'] as int,
        minStage: PetStage.values
            .byName((json['minStage'] ?? PetStage.egg.name) as String),
        title: json['title'] as String,
        hint: json['hint'] as String,
      );

  final int from;
  final int every;
  final PetStage minStage;
  final String title;
  final String hint;

  bool activeOn(int day, PetStage stage) =>
      stage.index >= minStage.index &&
      day >= from &&
      (day - from) % every == 0;
}

/// Обязательная покупка и то, что будет со шкалами, если её пропустить.
final class PetNeed {
  const PetNeed._({
    required this.itemId,
    required this.alternatives,
    required this.title,
    required this.emoji,
    required this.occasion,
    required this.missedEffects,
    required this.missedReason,
  });

  factory PetNeed.create({
    required String itemId,
    List<String> alternatives = const [],
    String title = '',
    String emoji = '',
    NeedOccasion? occasion,
    required List<StateEffect> missedEffects,
    required String missedReason,
  }) {
    if (itemId.trim().isEmpty) {
      throw ArgumentError.value(itemId, 'itemId', 'нужен id товара');
    }
    final ids = {itemId};
    for (final id in alternatives) {
      if (id.trim().isEmpty || !ids.add(id)) {
        throw ArgumentError.value(id, 'alternatives «$itemId»',
            'пустой или повторяющийся товар');
      }
    }
    if (missedEffects.isEmpty) {
      throw ArgumentError.value(
          itemId, 'missedEffects', 'пропуск должен на что-то влиять');
    }
    for (final effect in missedEffects) {
      if (effect.delta >= 0) {
        throw ArgumentError.value(effect.delta, 'missedEffects «$itemId»',
            'пропуск только снижает шкалу');
      }
      if (effect.stat == PetStat.cozy) {
        throw ArgumentError.value(itemId, 'missedEffects', 'уют только растёт');
      }
    }
    _requireText(missedReason, 'missedReason «$itemId»');
    return PetNeed._(
      itemId: itemId,
      alternatives: List.unmodifiable(alternatives),
      title: title,
      emoji: emoji,
      occasion: occasion,
      missedEffects: List.unmodifiable(missedEffects),
      missedReason: missedReason,
    );
  }

  factory PetNeed.fromJson(Map<String, Object?> json) => PetNeed.create(
        itemId: json['itemId'] as String,
        alternatives: [
          for (final id in (json['alternatives'] as List? ?? const []))
            id as String
        ],
        title: (json['title'] ?? '') as String,
        emoji: (json['emoji'] ?? '') as String,
        occasion: json['occasion'] == null
            ? null
            : NeedOccasion.fromJson(
                (json['occasion'] as Map).cast<String, Object?>()),
        missedEffects: _effectsFromJson(json['missedEffects']),
        missedReason: json['missedReason'] as String,
      );

  final String itemId;
  final List<String> alternatives;
  final String title;
  final String emoji;
  final NeedOccasion? occasion;

  /// Что происходит ночью, если за день эту покупку не сделали.
  final List<StateEffect> missedEffects;
  final String missedReason;

  List<String> get itemIds => [itemId, ...alternatives];

  bool covers(String id) => id == itemId || alternatives.contains(id);

  bool metBy(Iterable<String> bought) => bought.any(covers);

  bool activeOn(int day, PetStage stage) =>
      occasion?.activeOn(day, stage) ?? true;
}

/// Порог «питомцу чего-то хочется»: шкала на этом значении или ниже.
/// Низкая шкала ничего не блокирует — питомец только просит.
final class PetLowRule {
  const PetLowRule._({required this.atOrBelow, required this.text});

  factory PetLowRule.create({required int atOrBelow, required String text}) {
    _requireText(text, 'low.text');
    return PetLowRule._(atOrBelow: atOrBelow, text: text);
  }

  factory PetLowRule.fromJson(Map<String, Object?> json) => PetLowRule.create(
        atOrBelow: json['atOrBelow'] as int,
        text: json['text'] as String,
      );

  final int atOrBelow;

  /// «Хочется перекусить» — просьба, а не жалоба.
  final String text;
}

/// Бесплатное действие: погладить, выполнить задание. Только прибавляет.
final class PetAction {
  const PetAction._({
    required this.id,
    required this.effects,
    required this.maxPerDay,
    required this.reason,
  });

  factory PetAction.create({
    required String id,
    required List<StateEffect> effects,
    int? maxPerDay,
    required String reason,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'нужен id действия');
    }
    if (effects.isEmpty) {
      throw ArgumentError.value(id, 'effects', 'действие ни на что не влияет');
    }
    for (final effect in effects) {
      if (effect.delta <= 0) {
        throw ArgumentError.value(
            effect.delta, 'effects «$id»', 'действие только прибавляет');
      }
    }
    if (maxPerDay != null && maxPerDay < 1) {
      throw ArgumentError.value(maxPerDay, 'maxPerDay', 'лимит за день ≥ 1');
    }
    _requireText(reason, 'reason «$id»');
    return PetAction._(
      id: id,
      effects: List.unmodifiable(effects),
      maxPerDay: maxPerDay,
      reason: reason,
    );
  }

  factory PetAction.fromJson(String id, Map<String, Object?> json) =>
      PetAction.create(
        id: id,
        effects: _effectsFromJson(json['effects']),
        maxPerDay: json['maxPerDay'] as int?,
        reason: json['reason'] as String,
      );

  final String id;
  final List<StateEffect> effects;

  /// null — без ограничения.
  final int? maxPerDay;
  final String reason;
}

/// Уровень настроения начинается с [from] и идёт до следующего уровня.
final class MoodLevelRule {
  const MoodLevelRule._({
    required this.level,
    required this.from,
    required this.label,
  });

  factory MoodLevelRule.create({
    required MoodLevel level,
    required int from,
    required String label,
  }) {
    if (from < 0 || from > PetState.cap) {
      throw ArgumentError.value(from, 'moodLevels.${level.name}', '0..100');
    }
    _requireText(label, 'moodLevels.${level.name}.label');
    return MoodLevelRule._(level: level, from: from, label: label);
  }

  factory MoodLevelRule.fromJson(MoodLevel level, Map<String, Object?> json) =>
      MoodLevelRule.create(
        level: level,
        from: json['from'] as int,
        label: json['label'] as String,
      );

  final MoodLevel level;
  final int from;

  /// Подпись рядом с индикатором: цвет не единственный носитель смысла.
  final String label;
}

final class PetTexts {
  const PetTexts._({
    required this.change,
    required this.atMax,
    required this.atFloor,
    required this.purchase,
    required this.goalReached,
    required this.dailyItem,
  });

  factory PetTexts.create({
    required String change,
    required String atMax,
    required String atFloor,
    required String purchase,
    required String goalReached,
    required String dailyItem,
  }) {
    for (final (key, text) in [
      ('change', change),
      ('atMax', atMax),
      ('atFloor', atFloor),
      ('purchase', purchase),
      ('goalReached', goalReached),
      ('dailyItem', dailyItem),
    ]) {
      _requireText(text, 'texts.$key');
    }
    if (!change.contains('{stat}') || !change.contains('{delta}')) {
      throw ArgumentError.value(
          change, 'texts.change', 'нужны {stat} и {delta}');
    }
    for (final (key, text) in [('atMax', atMax), ('atFloor', atFloor)]) {
      if (!text.contains('{stat}')) {
        throw ArgumentError.value(text, 'texts.$key', 'нужен {stat}');
      }
    }
    return PetTexts._(
      change: change,
      atMax: atMax,
      atFloor: atFloor,
      purchase: purchase,
      goalReached: goalReached,
      dailyItem: dailyItem,
    );
  }

  factory PetTexts.fromJson(Map<String, Object?> json) => PetTexts.create(
        change: json['change'] as String,
        atMax: json['atMax'] as String,
        atFloor: json['atFloor'] as String,
        purchase: json['purchase'] as String,
        goalReached: json['goalReached'] as String,
        dailyItem: json['dailyItem'] as String,
      );

  /// «Сытость +40».
  final String change;

  /// Шкала упёрлась в потолок: «Сытость: и так на максимуме».
  final String atMax;

  /// Шкала на полу: «Настроение: ниже не опускается».
  final String atFloor;

  /// Причина, если у товара нет своего текста для дневника.
  final String purchase;

  /// Причина, если у цели нет своего текста.
  final String goalReached;

  /// «Попрыгунчик радует каждый день».
  final String dailyItem;
}

/// Сильный голод: вторая ступень после «хочется перекусить».
/// Голодным лёг спать — ночью не растёт; проснулся голодным — грустнее.
final class PetHunger {
  const PetHunger._({
    required this.atOrBelow,
    required this.text,
    required this.noGrowthText,
    required this.nightAtOrBelow,
    required this.nightEffects,
    required this.nightReason,
  });

  factory PetHunger.create({
    required int atOrBelow,
    required String text,
    required String noGrowthText,
    required int nightAtOrBelow,
    required List<StateEffect> nightEffects,
    required String nightReason,
  }) {
    _requireText(text, 'hunger.text');
    _requireText(noGrowthText, 'hunger.noGrowth');
    if (atOrBelow < PetState.satietyFloor || atOrBelow >= PetState.cap) {
      throw ArgumentError.value(atOrBelow, 'hunger.atOrBelow',
          'порог между полом ${PetState.satietyFloor} и потолком');
    }
    if (nightAtOrBelow < PetState.satietyFloor ||
        nightAtOrBelow >= PetState.cap) {
      throw ArgumentError.value(nightAtOrBelow, 'hunger.night.atOrBelow',
          'порог между полом ${PetState.satietyFloor} и потолком');
    }
    for (final effect in nightEffects) {
      if (effect.delta == 0) {
        throw ArgumentError.value(
            effect.stat.name, 'hunger.night', 'изменение на 0');
      }
      if (effect.stat == PetStat.cozy && effect.delta < 0) {
        throw ArgumentError.value(
            effect.delta, 'hunger.night', 'уют только растёт');
      }
    }
    if (nightEffects.isNotEmpty) _requireText(nightReason, 'hunger.night.reason');
    return PetHunger._(
      atOrBelow: atOrBelow,
      text: text,
      noGrowthText: noGrowthText,
      nightAtOrBelow: nightAtOrBelow,
      nightEffects: List.unmodifiable(nightEffects),
      nightReason: nightReason,
    );
  }

  factory PetHunger.fromJson(Map<String, Object?> json) {
    final night =
        (json['night'] as Map?)?.cast<String, Object?>() ?? const {};
    return PetHunger.create(
      atOrBelow: json['atOrBelow'] as int,
      text: (json['text'] ?? '') as String,
      noGrowthText: (json['noGrowth'] ?? '') as String,
      nightAtOrBelow: (night['atOrBelow'] as int?) ?? PetState.satietyFloor,
      nightEffects: _effectsFromJson(night['effects']),
      nightReason: (night['reason'] ?? '') as String,
    );
  }

  /// Сытость, при которой питомцу очень хочется кушать и ночью он не растёт.
  final int atOrBelow;
  final String text;
  final String noGrowthText;

  /// Проснулся с такой сытостью или ниже — срабатывают [nightEffects].
  final int nightAtOrBelow;
  final List<StateEffect> nightEffects;
  final String nightReason;
}

final class PetRules {
  const PetRules._({
    required this.initialState,
    required this.needs,
    required this.occasionalNeeds,
    required this.low,
    required this.nightlyEffects,
    required this.nightlyReason,
    required this.actions,
    required this.moodLevels,
    required this.texts,
    required this.hunger,
  });

  /// Действия, которые вызывает код, — без них правила неполные.
  static const String petTap = 'pet_tap';
  static const String taskDone = 'task_done';
  static const Set<String> requiredActions = {petTap, taskDone};

  factory PetRules.create({
    required Map<PetStat, int> initial,
    required List<PetNeed> needs,
    List<PetNeed> occasionalNeeds = const [],
    required Map<PetStat, PetLowRule> low,
    List<StateEffect> nightlyEffects = const [],
    String nightlyReason = '',
    required Map<String, PetAction> actions,
    required List<MoodLevelRule> moodLevels,
    required PetTexts texts,
    PetHunger? hunger,
  }) {
    // Старт: ни одна шкала не стоит на нуле (даже уют), и питомец
    // не начинает игру с просьбы.
    for (final stat in PetStat.values) {
      final value = initial[stat];
      if (value == null) {
        throw ArgumentError.value(
            stat.name, 'initial', 'нет стартового значения');
      }
      final cap = petStatCap(stat);
      if (value <= 0 ||
          value < petStatFloor(stat) ||
          (cap != null && value > cap)) {
        throw ArgumentError.value(
            value, 'initial.${stat.name}', 'от пола до потолка и не ноль');
      }
      final lowRule = low[stat];
      if (lowRule != null && value <= lowRule.atOrBelow) {
        throw ArgumentError.value(value, 'initial.${stat.name}',
            'на старте питомцу уже чего-то хочется');
      }
    }

    // Обязательные расходы по ТЗ — те, от которых зависит состояние.
    if (needs.isEmpty) {
      throw ArgumentError.value(
          needs, 'needs', 'нет ни одной обязательной покупки');
    }
    for (final need in needs) {
      if (need.occasion != null) {
        throw ArgumentError.value(
            need.itemId, 'needs', 'ежедневная нужда без расписания');
      }
    }
    for (final need in occasionalNeeds) {
      if (need.occasion == null) {
        throw ArgumentError.value(
            need.itemId, 'occasionalNeeds', 'нужно расписание');
      }
    }
    final itemIds = <String>{};
    for (final need in [...needs, ...occasionalNeeds]) {
      for (final id in need.itemIds) {
        if (!itemIds.add(id)) {
          throw ArgumentError.value(id, 'needs', 'повторяется');
        }
      }
      for (final effect in need.missedEffects) {
        if (effect.stat != PetStat.mood && !low.containsKey(effect.stat)) {
          throw ArgumentError.value(effect.stat.name, 'low',
              'шкала снижается от пропуска, но порога «хочется» у неё нет');
        }
      }
    }

    for (final MapEntry(key: stat, value: rule) in low.entries) {
      if (stat == PetStat.cozy) {
        throw ArgumentError.value(stat.name, 'low', 'уют не бывает низким');
      }
      if (rule.atOrBelow < petStatFloor(stat) ||
          rule.atOrBelow >= PetState.cap) {
        throw ArgumentError.value(rule.atOrBelow, 'low.${stat.name}',
            'порог между полом ${petStatFloor(stat)} и потолком');
      }
    }

    for (final effect in nightlyEffects) {
      if (effect.delta == 0) {
        throw ArgumentError.value(
            effect.stat.name, 'nightly', 'изменение на 0');
      }
      if (effect.stat == PetStat.cozy && effect.delta < 0) {
        throw ArgumentError.value(effect.delta, 'nightly', 'уют только растёт');
      }
    }
    if (nightlyEffects.isNotEmpty) {
      _requireText(nightlyReason, 'nightly.reason');
    }
    final wish = low[PetStat.satiety];
    if (hunger != null && wish != null && hunger.atOrBelow > wish.atOrBelow) {
      throw ArgumentError.value(hunger.atOrBelow, 'hunger.atOrBelow',
          'сильный голод не выше порога «хочется»');
    }

    for (final id in requiredActions) {
      if (!actions.containsKey(id)) {
        throw ArgumentError.value(id, 'actions', 'нет обязательного действия');
      }
    }
    for (final MapEntry(key: id, value: action) in actions.entries) {
      if (action.id != id) {
        throw ArgumentError.value(id, 'actions', 'ключ не совпадает с id');
      }
    }

    // Уровни настроения покрывают всё от пола до потолка, по порядку.
    final levels = [...moodLevels]..sort((a, b) => b.from.compareTo(a.from));
    final order = [for (final rule in levels) rule.level];
    final expected = MoodLevel.values.reversed.toList();
    if (order.length != expected.length ||
        order.toSet().length != order.length ||
        !_sameOrder(order, expected)) {
      throw ArgumentError.value(order.map((l) => l.name).join(', '),
          'moodLevels', 'нужны все уровни, от восторга к скуке по убыванию');
    }
    for (var i = 1; i < levels.length; i++) {
      if (levels[i].from == levels[i - 1].from) {
        throw ArgumentError.value(
            levels[i].from, 'moodLevels', 'одинаковые пороги');
      }
    }
    if (levels.last.from > PetState.moodFloor) {
      throw ArgumentError.value(levels.last.from, 'moodLevels',
          'нижний уровень должен начинаться не выше пола ${PetState.moodFloor}');
    }

    return PetRules._(
      initialState: PetState.create(
        satiety: initial[PetStat.satiety]!,
        care: initial[PetStat.care]!,
        mood: initial[PetStat.mood]!,
        cozy: initial[PetStat.cozy]!,
      ),
      needs: List.unmodifiable(needs),
      occasionalNeeds: List.unmodifiable(occasionalNeeds),
      low: Map.unmodifiable(low),
      nightlyEffects: List.unmodifiable(nightlyEffects),
      nightlyReason: nightlyReason,
      actions: Map.unmodifiable(actions),
      moodLevels: List.unmodifiable(levels),
      texts: texts,
      hunger: hunger,
    );
  }

  factory PetRules.fromJson(Map<String, Object?> json) {
    final nightly =
        (json['nightly'] as Map?)?.cast<String, Object?>() ?? const {};
    return PetRules.create(
      initial: {
        for (final e in (json['initial'] as Map).entries)
          PetStat.values.byName(e.key as String): e.value as int
      },
      needs: [
        for (final raw in (json['needs'] as List))
          PetNeed.fromJson((raw as Map).cast<String, Object?>())
      ],
      occasionalNeeds: [
        for (final raw in (json['occasionalNeeds'] as List? ?? const []))
          PetNeed.fromJson((raw as Map).cast<String, Object?>())
      ],
      low: {
        for (final e in (json['low'] as Map).entries)
          PetStat.values.byName(e.key as String):
              PetLowRule.fromJson((e.value as Map).cast<String, Object?>())
      },
      nightlyEffects: _effectsFromJson(nightly['effects']),
      nightlyReason: (nightly['reason'] ?? '') as String,
      actions: {
        for (final e in (json['actions'] as Map).entries)
          e.key as String: PetAction.fromJson(
              e.key as String, (e.value as Map).cast<String, Object?>())
      },
      moodLevels: [
        for (final e in (json['moodLevels'] as Map).entries)
          MoodLevelRule.fromJson(MoodLevel.values.byName(e.key as String),
              (e.value as Map).cast<String, Object?>())
      ],
      texts: PetTexts.fromJson((json['texts'] as Map).cast<String, Object?>()),
      hunger: json['hunger'] == null
          ? null
          : PetHunger.fromJson(
              (json['hunger'] as Map).cast<String, Object?>()),
    );
  }

  /// С чего начинается новый питомец.
  final PetState initialState;

  /// Обязательные покупки и последствия их пропуска.
  final List<PetNeed> needs;

  final List<PetNeed> occasionalNeeds;

  List<PetNeed> get allNeeds => [...needs, ...occasionalNeeds];

  List<PetNeed> needsOn(int day, PetStage stage) => [
        ...needs,
        for (final need in occasionalNeeds)
          if (need.activeOn(day, stage)) need
      ];

  /// Пороги «хочется» по шкалам. У уюта порога нет.
  final Map<PetStat, PetLowRule> low;

  /// Что меняется каждую ночь само по себе.
  final List<StateEffect> nightlyEffects;
  final String nightlyReason;

  final Map<String, PetAction> actions;

  /// От восторга к скуке, пороги по убыванию.
  final List<MoodLevelRule> moodLevels;
  final PetTexts texts;

  /// Вторая ступень голода; без неё питомец только «хочет перекусить».
  final PetHunger? hunger;

  bool isVeryHungry(PetState state) =>
      hunger != null && state.satiety <= hunger!.atOrBelow;

  PetNeed? needFor(String itemId) {
    for (final need in allNeeds) {
      if (need.covers(itemId)) return need;
    }
    return null;
  }

  PetAction? action(String id) => actions[id];

  bool isLow(PetStat stat, int value) {
    final rule = low[stat];
    return rule != null && value <= rule.atOrBelow;
  }

  MoodLevelRule moodLevelOf(int mood) {
    for (final rule in moodLevels) {
      if (mood >= rule.from) return rule;
    }
    // Ниже пола настроения не бывает, а нижний уровень начинается не выше
    // пола, так что сюда не попасть. Но и тут без исключения — нижний уровень.
    return moodLevels.last;
  }
}

void _requireText(String text, String name) {
  if (text.trim().isEmpty) {
    throw ArgumentError.value(text, name, 'текст не может быть пустым');
  }
}

bool _sameOrder(List<MoodLevel> a, List<MoodLevel> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<StateEffect> _effectsFromJson(Object? raw) => [
      for (final e in (raw as List? ?? const []))
        StateEffect.fromJson((e as Map).cast<String, Object?>())
    ];
