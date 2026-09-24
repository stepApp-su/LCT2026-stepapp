import 'content_json.dart';
import 'economy.dart';
import 'pet.dart';

enum EventCategory { free, choice, temptation, bonus, price }

final class EventOption {
  const EventOption._({
    required this.id,
    required this.label,
    required this.cost,
    required this.coins,
    required this.effects,
    required this.resultText,
    required this.journalText,
  });

  factory EventOption.fromJson(Map<String, Object?> json) {
    final cost = jsonInt(json['cost'] ?? 0, 'options.cost', min: 0);
    final coins = jsonInt(json['coins'] ?? 0, 'options.coins', min: 0);
    if (cost > 0 && coins > 0) {
      throw ArgumentError.value(
          json['id'], 'options', 'вариант не может и тратить, и приносить монеты');
    }
    return EventOption._(
      id: jsonText(json['id'], 'options.id'),
      label: jsonText(json['label'], 'options.label'),
      cost: cost,
      coins: coins,
      effects: List.unmodifiable([
        for (final raw in jsonMaps(json['effects'] ?? const [], 'options.effects'))
          StateEffect.fromJson(raw),
      ]),
      resultText: jsonText(json['resultText'], 'options.resultText'),
      journalText: jsonText(json['journalText'], 'options.journalText'),
    );
  }

  final String id;
  final String label;
  final int cost;
  final int coins;
  final List<StateEffect> effects;
  final String resultText;
  final String journalText;

  bool get isFree => cost == 0;
}

final class PriceDelta {
  const PriceDelta._({required this.itemId, required this.delta, required this.days});

  factory PriceDelta.fromJson(Map<String, Object?> json) {
    final delta = jsonInt(json['delta'], 'priceDeltas.delta');
    if (delta == 0) {
      throw ArgumentError.value(delta, 'priceDeltas.delta', 'изменение на 0');
    }
    return PriceDelta._(
      itemId: jsonText(json['itemId'], 'priceDeltas.itemId'),
      delta: delta,
      days: jsonInt(json['days'], 'priceDeltas.days', min: 1),
    );
  }

  final String itemId;
  final int delta;
  final int days;
}

final class GameEventDef {
  const GameEventDef._({
    required this.id,
    required this.title,
    required this.category,
    required this.iconId,
    required this.minStage,
    required this.competenceIds,
    required this.situation,
    required this.options,
    required this.priceDeltas,
    required this.forAdult,
  });

  factory GameEventDef.fromJson(Map<String, Object?> json) {
    final id = jsonText(json['id'], 'id');
    final category = jsonEnum(EventCategory.values, json['category'], 'category');
    final unlock = jsonMap(json['unlock'] ?? const {}, 'unlock');
    final options = [
      for (final raw in jsonMaps(json['options'], 'options')) EventOption.fromJson(raw),
    ];
    final priceDeltas = [
      for (final raw in jsonMaps(json['priceDeltas'] ?? const [], 'priceDeltas'))
        PriceDelta.fromJson(raw),
    ];
    final competenceIds = jsonStrings(json['competenceIds'], 'competenceIds');
    if (options.isEmpty) {
      throw ArgumentError.value(id, 'options', 'событие без вариантов');
    }
    requireUniqueIds(options.map((o) => o.id), '$id.options.id');
    if (!options.any((o) => o.isFree)) {
      throw ArgumentError.value(id, 'options', 'нужен вариант без траты');
    }
    if (category == EventCategory.free && options.any((o) => !o.isFree)) {
      throw ArgumentError.value(id, 'options', 'в бесплатном событии есть трата');
    }
    if (category == EventCategory.price && priceDeltas.isEmpty) {
      throw ArgumentError.value(id, 'priceDeltas', 'не сказано, какая цена меняется');
    }
    if (competenceIds.isEmpty) {
      throw ArgumentError.value(id, 'competenceIds', 'не указана компетенция');
    }
    return GameEventDef._(
      id: id,
      title: jsonText(json['title'], 'title'),
      category: category,
      iconId: jsonText(json['iconId'], 'iconId'),
      minStage: jsonEnum(PetStage.values, unlock['minStage'] ?? PetStage.egg.name,
          'unlock.minStage'),
      competenceIds: competenceIds,
      situation: jsonText(json['situation'], 'situation'),
      options: List.unmodifiable(options),
      priceDeltas: List.unmodifiable(priceDeltas),
      forAdult: jsonText(json['forAdult'], 'forAdult'),
    );
  }

  final String id;
  final String title;
  final EventCategory category;
  final String iconId;
  final PetStage minStage;
  final List<String> competenceIds;
  final String situation;
  final List<EventOption> options;
  final List<PriceDelta> priceDeltas;
  final String forAdult;

  bool isAvailableAt(PetStage stage) => stage.index >= minStage.index;

  EventOption? option(String id) {
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }
}

final class EventSettings {
  const EventSettings._({
    required this.payFrom,
    required this.neverTouchSavings,
    required this.cooldownDays,
    required this.sequence,
  });

  factory EventSettings.fromJson(Map<String, Object?> json) => EventSettings._(
        payFrom: jsonText(json['payFrom'], 'settings.payFrom'),
        neverTouchSavings:
            jsonBool(json['neverTouchSavings'], 'settings.neverTouchSavings'),
        cooldownDays: jsonInt(json['cooldownDays'], 'settings.cooldownDays', min: 0),
        sequence: jsonStrings(json['sequence'], 'settings.sequence'),
      );

  final String payFrom;
  final bool neverTouchSavings;
  final int cooldownDays;
  final List<String> sequence;
}

final class EventCatalog {
  const EventCatalog._({
    required this.schemaVersion,
    required this.settings,
    required this.texts,
    required this.events,
  });

  static const Set<String> requiredTexts = {
    'header',
    'chooseHint',
    'notEnough',
    'postpone',
    'done',
  };

  factory EventCatalog.create({
    int schemaVersion = 1,
    required EventSettings settings,
    required Map<String, String> texts,
    required List<GameEventDef> events,
  }) {
    if (events.isEmpty) throw ArgumentError('нет ни одного события');
    requireUniqueIds(events.map((e) => e.id), 'events.id');
    final ids = {for (final event in events) event.id};
    for (final id in settings.sequence) {
      if (!ids.contains(id)) {
        throw ArgumentError.value(id, 'settings.sequence', 'нет такого события');
      }
    }
    if (settings.sequence.isEmpty) {
      throw ArgumentError.value(settings.sequence, 'settings.sequence', 'пусто');
    }
    return EventCatalog._(
      schemaVersion: schemaVersion,
      settings: settings,
      texts: Map.unmodifiable(texts),
      events: List.unmodifiable(events),
    );
  }

  factory EventCatalog.fromJson(Map<String, Object?> json) => EventCatalog.create(
        schemaVersion: jsonInt(json['schemaVersion'] ?? 1, 'schemaVersion', min: 1),
        settings: EventSettings.fromJson(jsonMap(json['settings'], 'settings')),
        texts: jsonTexts(json['texts'], 'texts', required: requiredTexts),
        events: [
          for (final raw in jsonMaps(json['events'], 'events')) GameEventDef.fromJson(raw),
        ],
      );

  final int schemaVersion;
  final EventSettings settings;
  final Map<String, String> texts;
  final List<GameEventDef> events;

  GameEventDef? byId(String id) {
    for (final event in events) {
      if (event.id == id) return event;
    }
    return null;
  }

  List<GameEventDef> availableAt(PetStage stage) => List.unmodifiable([
        for (final event in events)
          if (event.isAvailableAt(stage)) event,
      ]);

  Set<String> get competenceIds => {
        for (final event in events) ...event.competenceIds,
      };
}
