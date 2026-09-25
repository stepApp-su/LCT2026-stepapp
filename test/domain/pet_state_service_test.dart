import 'dart:convert';
import 'dart:math';

import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/pet_state_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/day.dart';
import '../support/economy.dart';
import '../support/growth.dart';

Map<String, Object?> _rulesJson() => {
      'initial': {'satiety': 80, 'care': 80, 'mood': 80, 'cozy': 10},
      'needs': [
        {
          'itemId': 'food',
          'missedEffects': [
            {'stat': 'satiety', 'delta': -30}
          ],
          'missedReason': 'Сегодня не купили еду',
        },
        {
          'itemId': 'water_light',
          'missedEffects': [
            {'stat': 'care', 'delta': -10}
          ],
          'missedReason': 'Сегодня не заплатили за воду и свет',
        },
        {
          'itemId': 'cleaning',
          'missedEffects': [
            {'stat': 'care', 'delta': -10}
          ],
          'missedReason': 'Сегодня обошлись без мытья и уборки',
        },
      ],
      'low': {
        'satiety': {'atOrBelow': 50, 'text': 'Хочется перекусить'},
        'care': {'atOrBelow': 30, 'text': 'Мне бы умыться'},
      },
      'nightly': {
        'effects': [
          {'stat': 'mood', 'delta': -10}
        ],
        'reason': 'Ночью настроение немного снижается',
      },
      'actions': {
        'pet_tap': {
          'effects': [
            {'stat': 'mood', 'delta': 2}
          ],
          'maxPerDay': 3,
          'reason': 'Погладили — приятно!',
        },
        'task_done': {
          'effects': [
            {'stat': 'mood', 'delta': 5}
          ],
          'reason': 'Сделали задание — стало веселее',
        },
      },
      'moodLevels': {
        'delight': {'from': 85, 'label': 'Восторг'},
        'joy': {'from': 65, 'label': 'Радость'},
        'calm': {'from': 45, 'label': 'Спокойствие'},
        'bored': {'from': 30, 'label': 'Скука'},
      },
      'texts': {
        'change': '{stat} {delta}',
        'atMax': '{stat}: и так на максимуме',
        'atFloor': '{stat}: ниже не опускается',
        'purchase': 'Купили {titleAccusative}',
        'goalReached': 'Цель достигнута: {title}',
        'dailyItem': '{title} радует каждый день',
      },
    };

final PetRules _rules = PetRules.fromJson(_rulesJson());

PetRules _rulesWith(void Function(Map<String, Object?> json) edit) {
  final json =
      (jsonDecode(jsonEncode(_rulesJson())) as Map).cast<String, Object?>();
  edit(json);
  return PetRules.fromJson(json);
}

Map<String, Object?> _section(Map<String, Object?> json, String key) =>
    (json[key] as Map).cast<String, Object?>();

Map<String, Object?> _entry(Map<String, Object?> json, String key, String id) =>
    (_section(json, key)[id] as Map).cast<String, Object?>();

Map<String, Object?> _need(Map<String, Object?> json, int index) =>
    ((json['needs'] as List)[index] as Map).cast<String, Object?>();

PetState _state(
        {int satiety = 80, int care = 80, int mood = 80, int cozy = 10}) =>
    PetState.create(satiety: satiety, care: care, mood: mood, cozy: cozy);

final ShopItem _food = ShopItem.create(
  id: 'food',
  title: 'Еда на день',
  titleAccusative: 'еду на день',
  price: 15,
  category: ExpenseCategory.mandatory,
  effects: const [StateEffect(stat: PetStat.satiety, delta: 40)],
  diaryText: 'Купили еду на день.',
);

final ShopItem _water = ShopItem.create(
  id: 'water_light',
  title: 'Вода и свет',
  price: 5,
  category: ExpenseCategory.mandatory,
  effects: const [StateEffect(stat: PetStat.care, delta: 20)],
  diaryText: 'Заплатили за воду и свет.',
);

final ShopItem _cleaning = ShopItem.create(
  id: 'cleaning',
  title: 'Мытьё и уборка',
  price: 5,
  category: ExpenseCategory.mandatory,
  effects: const [StateEffect(stat: PetStat.care, delta: 20)],
  diaryText: 'Устроили мытьё и уборку.',
);

final ShopItem _treat = ShopItem.create(
  id: 'treat',
  title: 'Лакомство',
  price: 5,
  category: ExpenseCategory.optional,
  effects: const [StateEffect(stat: PetStat.mood, delta: 8)],
  diaryText: 'Купили лакомство.',
);

final ShopItem _rug = ShopItem.create(
  id: 'rug',
  title: 'Коврик',
  price: 25,
  category: ExpenseCategory.optional,
  kind: ShopItemKind.furniture,
  effects: const [StateEffect(stat: PetStat.cozy, delta: 5)],
  diaryText: 'Постелили новый коврик.',
);

final ShopItem _ball = ShopItem.create(
  id: 'bouncy_ball',
  title: 'Попрыгунчик',
  price: 15,
  category: ExpenseCategory.optional,
  kind: ShopItemKind.toy,
  effects: const [StateEffect(stat: PetStat.mood, delta: 10)],
  dailyEffects: const [StateEffect(stat: PetStat.mood, delta: 2)],
  diaryText: 'Купили попрыгунчик.',
);

final ShopItem _cap = ShopItem.create(
  id: 'cap',
  title: 'Кепка',
  titleAccusative: 'кепку',
  price: 20,
  category: ExpenseCategory.optional,
  kind: ShopItemKind.accessory,
  effects: const [StateEffect(stat: PetStat.mood, delta: 10)],
);

final ShopItem _broken = ShopItem.create(
  id: 'broken',
  title: 'Странная вещь',
  price: 1,
  category: ExpenseCategory.optional,
  effects: const [
    StateEffect(stat: PetStat.cozy, delta: -50),
    StateEffect(stat: PetStat.satiety, delta: -500),
    StateEffect(stat: PetStat.mood, delta: 500),
    StateEffect(stat: PetStat.care, delta: 0),
  ],
  dailyEffects: const [StateEffect(stat: PetStat.cozy, delta: -7)],
  diaryText: 'Купили странную вещь.',
);

final Goal _goal = Goal.create(
  id: 'ball_rope',
  title: 'Мячик и скакалка',
  price: 90,
  rewardEffects: const [StateEffect(stat: PetStat.cozy, delta: 18)],
  reachedText: 'Мячик и скакалка теперь наши навсегда!',
);

const List<String> _allNeeds = ['food', 'water_light', 'cleaning'];

void _expectWithinBounds(PetState s) {
  expect(s.satiety, inInclusiveRange(PetState.satietyFloor, PetState.cap));
  expect(s.care, inInclusiveRange(PetState.careFloor, PetState.cap));
  expect(s.mood, inInclusiveRange(PetState.moodFloor, PetState.cap));
  expect(s.cozy, greaterThanOrEqualTo(0));
}

void _expectExplained(
    PetState from, Iterable<StatChange> changes, PetState to) {
  final running = {for (final stat in PetStat.values) stat: from.of(stat)};
  for (final change in changes) {
    expect(change.reasonText.trim(), isNotEmpty);
    expect(change.nominal, isNot(0));
    expect(change.before, running[change.stat], reason: change.reasonText);
    running[change.stat] = change.after;
  }
  for (final stat in PetStat.values) {
    expect(running[stat], to.of(stat), reason: stat.name);
  }
}

void _expectUpdateExplained(PetStateUpdate update) =>
    _expectExplained(update.before, update.changes, update.after);

void main() {
  group('шкалы никогда не опускаются ниже пола', () {
    test('сто ночей без покупок: сытость, уход и настроение ровно на полу', () {
      final pet = PetStateService(rules: _rules);
      for (var day = 1; day <= 100; day++) {
        pet.startDay(day);
        pet.closeDay(boughtItemIds: const []);
        _expectWithinBounds(pet.state);
      }
      expect(pet.state.satiety, PetState.satietyFloor);
      expect(pet.state.care, PetState.careFloor);
      expect(pet.state.mood, PetState.moodFloor);
      expect(pet.state.cozy, _rules.initialState.cozy);
    });

    test('огромный минус упирается в пол, а не в ноль', () {
      final pet = PetStateService(rules: _rules);
      final update = pet.applyEffects(const [
        StateEffect(stat: PetStat.satiety, delta: -1000),
        StateEffect(stat: PetStat.care, delta: -1000),
        StateEffect(stat: PetStat.mood, delta: -1000),
      ], reasonText: 'Сценарное событие');
      expect(pet.state.satiety, PetState.satietyFloor);
      expect(pet.state.care, PetState.careFloor);
      expect(pet.state.mood, PetState.moodFloor);
      expect([for (final c in update.changes) c.isLimited], everyElement(true));
      _expectUpdateExplained(update);
    });

    test('на полу пропуск ничего не отнимает, но причина всё равно видна', () {
      final pet = PetStateService(
          rules: _rules, initial: _state(satiety: 20, care: 20, mood: 30));
      final night = pet.closeDay(boughtItemIds: const []);
      expect(pet.state, _state(satiety: 20, care: 20, mood: 30));
      expect(night.changes, hasLength(4));
      for (final change in night.changes) {
        expect(change.delta, 0);
        expect(change.isLimited, isTrue);
        expect(pet.describe(change), contains('ниже не опускается'));
      }
    });

    test('уют не снижается ни одним вызовом', () {
      final pet = PetStateService(rules: _rules, initial: _state(cozy: 50));
      final event = pet.applyEffects(
          const [StateEffect(stat: PetStat.cozy, delta: -30)],
          reasonText: 'Событие');
      expect(event.isEmpty, isTrue);
      pet.applyPurchase(_broken);
      pet.closeDay(boughtItemIds: _allNeeds, ownedItems: [_broken]);
      expect(pet.state.cozy, 50);
      expect(pet.changesToday.where((c) => c.stat == PetStat.cozy), isEmpty);
    });

    test('случайные цепочки действий: пол, потолок, уют и причины держатся',
        () {
      final items = [
        _food,
        _water,
        _cleaning,
        _treat,
        _rug,
        _ball,
        _cap,
        _broken
      ];
      for (var seed = 0; seed < 300; seed++) {
        final random = Random(seed);
        final pet = PetStateService(
          rules: _rules,
          initial: _state(
            satiety: random.nextInt(101),
            care: random.nextInt(101),
            mood: random.nextInt(101),
            cozy: random.nextInt(200),
          ),
        );
        var day = 1;
        var dayStart = pet.state;
        var cozy = pet.state.cozy;
        for (var step = 0; step < 300; step++) {
          final before = pet.state;
          PetStateUpdate? update;
          switch (random.nextInt(8)) {
            case 0:
              update = pet.applyPurchase(items[random.nextInt(items.length)]);
            case 1:
              update = pet.perform(PetRules.petTap);
            case 2:
              update = pet.perform(PetRules.taskDone);
            case 3:
              update = pet.applyGoalReward(_goal);
            case 4:
              update = pet.applyEffects([
                StateEffect(
                  stat: PetStat.values[random.nextInt(PetStat.values.length)],
                  delta: random.nextInt(401) - 200,
                )
              ], reasonText: 'Сценарное событие');
            case 5:
              update = pet.closeDay(
                boughtItemIds: [
                  for (final id in _allNeeds)
                    if (random.nextBool()) id
                ],
                ownedItems: [
                  if (random.nextBool()) _ball,
                  if (random.nextBool()) _broken,
                  if (random.nextBool()) _rug,
                ],
              );
            case 6:
              pet.startDay(++day);
              dayStart = pet.state;
            default:
              expect(pet.status.moodLabel, isNotEmpty);
          }

          final context = 'seed $seed, шаг $step';
          _expectWithinBounds(pet.state);
          expect(pet.state.cozy, greaterThanOrEqualTo(cozy), reason: context);
          cozy = pet.state.cozy;
          if (update == null) {
            expect(pet.state, before, reason: context);
          } else {
            expect(update.before, before, reason: context);
            expect(update.after, pet.state, reason: context);
            _expectUpdateExplained(update);
          }
          _expectExplained(dayStart, pet.changesToday, pet.state);
        }
      }
    });
  });

  group('восстановление одним действием', () {
    test('покупка еды полностью возвращает пропущенный день', () {
      final pet = PetStateService(rules: _rules, initial: _state(satiety: 100));
      pet.closeDay(boughtItemIds: const ['water_light', 'cleaning']);
      expect(pet.state.satiety, 70);
      pet.startDay(2);
      pet.applyPurchase(_food);
      expect(pet.state.satiety, 100);
    });

    test('даже с пола одна покупка снимает «хочется»', () {
      final pet = PetStateService(rules: _rules);
      for (var day = 1; day <= 10; day++) {
        pet.startDay(day);
        pet.closeDay(boughtItemIds: const []);
      }
      expect(pet.status.isLow(PetStat.satiety), isTrue);
      expect(pet.status.isLow(PetStat.care), isTrue);

      pet.startDay(11);
      pet.applyPurchase(_food);
      expect(pet.status.isLow(PetStat.satiety), isFalse);
      pet.applyPurchase(_water);
      expect(pet.status.isLow(PetStat.care), isFalse);
      expect(pet.status.wishes, isEmpty);
    });

    test('после ночи без еды просьба видна сразу, после покупки — исчезает',
        () {
      final pet = PetStateService(rules: _rules);
      pet.closeDay(boughtItemIds: const ['water_light', 'cleaning']);
      expect(pet.state.satiety, 50);
      final wish = pet.status.wishes.single;
      expect(wish.stat, PetStat.satiety);
      expect(wish.text, 'Хочется перекусить');

      pet.startDay(2);
      pet.applyPurchase(_food);
      expect(pet.status.wishes, isEmpty);
    });
  });

  group('у каждого изменения есть причина', () {
    test('покупка объясняется той же записью, что и в журнале', () {
      final pet = PetStateService(rules: _rules);
      final update = pet.applyPurchase(_food);
      final change = update.changes.single;
      expect(change.stat, PetStat.satiety);
      expect(change.delta, 20);
      expect(change.nominal, 40);
      expect(change.reasonText, 'Купили еду на день.');
    });

    test('без записи для дневника причина собирается из шаблона', () {
      final pet = PetStateService(rules: _rules);
      final update = pet.applyPurchase(_cap);
      expect(update.changes.single.reasonText, 'Купили кепку');
    });

    test('цель: свой текст или шаблон', () {
      final pet = PetStateService(rules: _rules);
      expect(pet.applyGoalReward(_goal).changes.single.reasonText,
          'Мячик и скакалка теперь наши навсегда!');
      final plain = Goal.create(
        id: 'scooter',
        title: 'Самокат',
        price: 120,
        rewardEffects: const [StateEffect(stat: PetStat.cozy, delta: 24)],
      );
      final change = pet.applyGoalReward(plain).changes.single;
      expect(change.reasonText, 'Цель достигнута: Самокат');
      expect(change.delta, 24);
    });

    test('ночью у каждой пропущенной покупки своя причина', () {
      final pet = PetStateService(rules: _rules);
      final night = pet.closeDay(boughtItemIds: const []);
      expect([
        for (final c in night.changes) (c.stat, c.delta, c.reasonText)
      ], [
        (PetStat.satiety, -30, 'Сегодня не купили еду'),
        (PetStat.care, -10, 'Сегодня не заплатили за воду и свет'),
        (PetStat.care, -10, 'Сегодня обошлись без мытья и уборки'),
        (PetStat.mood, -10, 'Ночью настроение немного снижается'),
      ]);
      _expectUpdateExplained(night);
    });

    test('вещь в комнате радует каждую ночь и называет себя', () {
      final pet = PetStateService(rules: _rules, initial: _state(mood: 50));
      final night = pet.closeDay(boughtItemIds: _allNeeds, ownedItems: [_ball]);
      expect(night.changes.last.reasonText, 'Попрыгунчик радует каждый день');
      expect(night.changes.last.delta, 2);
      expect(pet.state.mood, 42);
    });

    test('без причины изменить шкалу нельзя, состояние не тронуто', () {
      final pet = PetStateService(rules: _rules);
      expect(
          () => pet.applyEffects(
              const [StateEffect(stat: PetStat.mood, delta: 5)],
              reasonText: '  '),
          throwsArgumentError);
      expect(pet.state, _rules.initialState);
      expect(pet.changesToday, isEmpty);
    });

    test('подписи изменений: плюс, минус, потолок, пол', () {
      final pet = PetStateService(rules: _rules, initial: _state(satiety: 90));
      final up = pet.applyPurchase(_food).changes.single;
      expect(pet.describe(up), 'Сытость +10');
      final full = pet.applyPurchase(_food).changes.single;
      expect(full.delta, 0);
      expect(pet.describe(full), 'Сытость: и так на максимуме');
      final down = pet.closeDay(boughtItemIds: const []).changes.first;
      expect(pet.describe(down), 'Сытость −30');
      final floor = PetStateService(rules: _rules, initial: _state(mood: 30))
          .closeDay(boughtItemIds: _allNeeds)
          .changes
          .single;
      expect(PetStateService(rules: _rules).describe(floor),
          'Настроение: ниже не опускается');
    });
  });

  group('низкое состояние ничего не блокирует', () {
    test('на полу все действия работают как обычно', () {
      final pet = PetStateService(
          rules: _rules, initial: _state(satiety: 20, care: 20, mood: 30));
      expect(pet.perform(PetRules.taskDone).changes.single.delta, 5);
      expect(pet.perform(PetRules.petTap).changes.single.delta, 2);
      expect(pet.applyPurchase(_treat).changes.single.delta, 8);
      expect(pet.applyGoalReward(_goal).changes.single.delta, 18);
      expect(pet.leftToday(PetRules.petTap), 2);
      expect(pet.closeDay(boughtItemIds: const []).isEmpty, isFalse);
      pet.startDay(2);
      expect(pet.applyPurchase(_food).changes.single.delta, 40);
    });

    test('что даёт действие, не зависит от того, как питомец себя чувствует',
        () {
      List<int> nominals(PetState initial) {
        final pet = PetStateService(rules: _rules, initial: initial);
        return [
          for (final update in [
            pet.applyPurchase(_food),
            pet.applyPurchase(_treat),
            pet.perform(PetRules.taskDone),
            pet.perform(PetRules.petTap),
            pet.applyGoalReward(_goal),
            pet.closeDay(boughtItemIds: const []),
          ])
            for (final change in update.changes) change.nominal
        ];
      }

      expect(nominals(_state(satiety: 20, care: 20, mood: 30)),
          nominals(_state(satiety: 50, care: 50, mood: 50)));
    });
  });

  group('поглаживание: не больше трёх раз за день', () {
    test('трижды по +2, дальше без изменений, но и без ошибки', () {
      final pet = PetStateService(rules: _rules, initial: _state(mood: 50));
      for (var i = 0; i < 3; i++) {
        expect(pet.perform(PetRules.petTap).changes.single.delta, 2);
      }
      final fourth = pet.perform(PetRules.petTap);
      expect(fourth.isEmpty, isTrue);
      expect(fourth.after, pet.state);
      expect(pet.state.mood, 56);
      expect(pet.timesToday(PetRules.petTap), 3);
      expect(pet.leftToday(PetRules.petTap), 0);
    });

    test('в новый день гладить снова можно', () {
      final pet = PetStateService(rules: _rules);
      for (var i = 0; i < 5; i++) {
        pet.perform(PetRules.petTap);
      }
      pet.startDay(2);
      expect(pet.leftToday(PetRules.petTap), 3);
      expect(pet.perform(PetRules.petTap).isEmpty, isFalse);
    });

    test('задания без лимита: настроение упирается только в потолок', () {
      final pet = PetStateService(rules: _rules);
      expect(pet.leftToday(PetRules.taskDone), isNull);
      for (var i = 0; i < 10; i++) {
        pet.perform(PetRules.taskDone);
      }
      expect(pet.state.mood, PetState.cap);
      expect(pet.timesToday(PetRules.taskDone), 10);
    });

    test('неизвестное действие — ошибка программиста, а не тихий ноль', () {
      final pet = PetStateService(rules: _rules);
      expect(() => pet.perform('dance'), throwsArgumentError);
      expect(() => pet.leftToday('dance'), throwsArgumentError);
      expect(pet.state, _rules.initialState);
    });
  });

  group('ночь', () {
    test('всё обязательное куплено — сытость и уход не падают', () {
      final pet = PetStateService(rules: _rules);
      final night = pet.closeDay(boughtItemIds: _allNeeds);
      expect(night.changes.single.stat, PetStat.mood);
      expect(pet.state, _state(mood: 70));
    });

    test('ничего не куплено — последствие видно по каждой шкале', () {
      final pet = PetStateService(rules: _rules);
      pet.closeDay(boughtItemIds: const []);
      expect(pet.state, _state(satiety: 50, care: 60, mood: 70));
    });

    test('лишние и незнакомые покупки не мешают', () {
      final pet = PetStateService(rules: _rules);
      pet.closeDay(boughtItemIds: const ['food', 'treat', 'rocket', 'food']);
      expect(pet.state, _state(care: 60, mood: 70));
    });

    test('повторное «спокойной ночи» за тот же день ничего не удваивает', () {
      final pet = PetStateService(rules: _rules);
      pet.closeDay(boughtItemIds: const []);
      final after = pet.state;
      final again = pet.closeDay(boughtItemIds: const [], ownedItems: [_ball]);
      expect(again.isEmpty, isTrue);
      expect(pet.state, after);
      expect(pet.isDayClosed, isTrue);
    });

    test('одна вещь радует один раз, вещи без ежедневной радости молчат', () {
      final pet = PetStateService(rules: _rules, initial: _state(mood: 50));
      final night = pet.closeDay(
          boughtItemIds: _allNeeds, ownedItems: [_ball, _ball, _rug, _cap]);
      expect(night.changes, hasLength(2));
      expect(pet.state.mood, 42);
    });

    test('порядок: пропуски, ночь, радость от вещей', () {
      final pet = PetStateService(rules: _rules, initial: _state(mood: 100));
      final night = pet
          .closeDay(boughtItemIds: const ['water_light'], ownedItems: [_ball]);
      expect([
        for (final c in night.changes) (c.stat, c.delta)
      ], [
        (PetStat.satiety, -30),
        (PetStat.care, -10),
        (PetStat.mood, -10),
        (PetStat.mood, 2),
      ]);
      expect(pet.state.mood, 92);
    });
  });

  group('новый день', () {
    test('лимиты, список изменений и ночь начинаются заново, шкалы — нет', () {
      final pet = PetStateService(rules: _rules);
      pet.applyPurchase(_food);
      pet.perform(PetRules.petTap);
      pet.closeDay(boughtItemIds: _allNeeds);
      final evening = pet.state;
      expect(pet.changesToday, hasLength(3));

      pet.startDay(2);
      expect(pet.dayNumber, 2);
      expect(pet.state, evening);
      expect(pet.changesToday, isEmpty);
      expect(pet.actionsToday, isEmpty);
      expect(pet.isDayClosed, isFalse);
      expect(pet.closeDay(boughtItemIds: _allNeeds).isEmpty, isFalse);
    });

    test('тот же день повторно ничего не сбрасывает', () {
      final pet = PetStateService(rules: _rules);
      for (var i = 0; i < 3; i++) {
        pet.perform(PetRules.petTap);
      }
      pet.closeDay(boughtItemIds: _allNeeds);
      pet.startDay(1);
      expect(pet.leftToday(PetRules.petTap), 0);
      expect(pet.isDayClosed, isTrue);
      expect(pet.changesToday, hasLength(4));
    });

    test('назад дни не идут', () {
      final pet = PetStateService(rules: _rules, dayNumber: 3);
      expect(() => pet.startDay(2), throwsArgumentError);
      expect(pet.dayNumber, 3);
    });

    test('номер дня с единицы, счётчики не отрицательные', () {
      expect(() => PetStateService(rules: _rules, dayNumber: 0),
          throwsArgumentError);
      expect(
          () => PetStateService(
              rules: _rules, actionsToday: const {PetRules.petTap: -1}),
          throwsArgumentError);
    });
  });

  group('после перезапуска', () {
    test('лимиты, список дня и ночь восстанавливаются из сохранения', () {
      final pet = PetStateService(rules: _rules);
      pet.applyPurchase(_food);
      for (var i = 0; i < 3; i++) {
        pet.perform(PetRules.petTap);
      }
      pet.closeDay(boughtItemIds: _allNeeds);

      final saved = jsonDecode(jsonEncode({
        'state': pet.state.toJson(),
        'day': pet.dayNumber,
        'actions': pet.actionsToday,
        'changes': [for (final c in pet.changesToday) c.toJson()],
        'closed': pet.isDayClosed,
      })) as Map<String, Object?>;

      final restored = PetStateService(
        rules: _rules,
        initial:
            PetState.fromJson((saved['state'] as Map).cast<String, Object?>()),
        dayNumber: saved['day'] as int,
        actionsToday: (saved['actions'] as Map).cast<String, int>(),
        changesToday: [
          for (final c in saved['changes'] as List)
            StatChange.fromJson((c as Map).cast<String, Object?>())
        ],
        isDayClosed: saved['closed'] as bool,
      );
      expect(restored.state, pet.state);
      expect(restored.changesToday, pet.changesToday);
      expect(restored.perform(PetRules.petTap).isEmpty, isTrue);
      expect(restored.closeDay(boughtItemIds: const []).isEmpty, isTrue);
      expect(restored.state, pet.state);
    });

    test('лимит в конфиге уменьшили — остаток ноль, а не минус', () {
      final pet = PetStateService(
          rules: _rules, actionsToday: const {PetRules.petTap: 5});
      expect(pet.leftToday(PetRules.petTap), 0);
      expect(pet.perform(PetRules.petTap).isEmpty, isTrue);
      expect(pet.timesToday(PetRules.petTap), 5);
    });

    test('список дня и счётчики снаружи только читаются', () {
      final pet = PetStateService(rules: _rules);
      final update = pet.applyPurchase(_food);
      pet.perform(PetRules.petTap);
      expect(() => pet.changesToday.clear(), throwsUnsupportedError);
      expect(() => update.changes.clear(), throwsUnsupportedError);
      expect(
          () => pet.actionsToday[PetRules.petTap] = 0, throwsUnsupportedError);
      expect(pet.changesToday, hasLength(2));
      expect(pet.timesToday(PetRules.petTap), 1);
    });
  });

  group('настроение и просьбы', () {
    test('уровни настроения по порогам', () {
      MoodLevel level(int mood) =>
          PetStateService(rules: _rules, initial: _state(mood: mood))
              .status
              .moodLevel;
      expect(level(100), MoodLevel.delight);
      expect(level(85), MoodLevel.delight);
      expect(level(84), MoodLevel.joy);
      expect(level(65), MoodLevel.joy);
      expect(level(64), MoodLevel.calm);
      expect(level(45), MoodLevel.calm);
      expect(level(44), MoodLevel.bored);
      expect(level(30), MoodLevel.bored);
    });

    test('у каждого уровня есть подпись, а не только цвет', () {
      for (final mood in [30, 50, 70, 90]) {
        final status =
            PetStateService(rules: _rules, initial: _state(mood: mood)).status;
        expect(status.moodLabel.trim(), isNotEmpty);
      }
    });

    test('просьбы по порядку шкал, граница порога включительно', () {
      final status = PetStateService(
              rules: _rules, initial: _state(satiety: 50, care: 30, mood: 30))
          .status;
      expect([for (final w in status.wishes) w.text],
          ['Хочется перекусить', 'Мне бы умыться']);
      final fine =
          PetStateService(rules: _rules, initial: _state(satiety: 51, care: 31))
              .status;
      expect(fine.wishes, isEmpty);
    });
  });

  group('StatChange', () {
    StatChange change({
      PetStat stat = PetStat.satiety,
      int before = 50,
      int after = 90,
      int nominal = 40,
      String reason = 'Купили еду на день.',
    }) =>
        StatChange.create(
            stat: stat,
            before: before,
            after: after,
            nominal: nominal,
            reasonText: reason);

    test('в JSON и обратно без потерь', () {
      final original = change();
      final json = jsonDecode(jsonEncode(original.toJson())) as Map;
      expect(StatChange.fromJson(json.cast<String, Object?>()), original);
    });

    test('невозможные изменения не создаются', () {
      expect(() => change(reason: ' '), throwsArgumentError);
      expect(() => change(nominal: 0, after: 50), throwsArgumentError);
      expect(() => change(stat: PetStat.cozy, nominal: -5, after: 45),
          throwsArgumentError);
      expect(() => change(after: 40), throwsArgumentError);
      expect(() => change(after: 100), throwsArgumentError);
      expect(() => change(before: -1), throwsArgumentError);
    });

    test('упор в потолок — честное +0 с отметкой', () {
      final capped = change(before: 100, after: 100);
      expect(capped.delta, 0);
      expect(capped.isLimited, isTrue);
    });
  });

  group('правила проверяются при загрузке', () {
    test('новый питомец стартует из правил: ни одна шкала не на нуле', () {
      final pet = PetStateService(rules: _rules);
      expect(pet.state, _state());
      for (final stat in PetStat.values) {
        expect(pet.state.of(stat), greaterThan(0), reason: stat.name);
      }
      expect(pet.status.wishes, isEmpty);
    });

    test('корректные правила собираются', () {
      expect(_rules.needs.map((n) => n.itemId), _allNeeds);
      expect(_rules.needFor('food')!.missedEffects.single.delta, -30);
      expect(_rules.needFor('treat'), isNull);
      expect(_rules.moodLevels.map((l) => l.level), MoodLevel.values.reversed);
      expect(_rules.isLow(PetStat.satiety, 50), isTrue);
      expect(_rules.isLow(PetStat.mood, 30), isFalse);
      expect(petStatFloor(PetStat.cozy), 0);
      expect(petStatCap(PetStat.cozy), isNull);
      expect(petStatCap(PetStat.mood), PetState.cap);
    });

    test('версия файла экономики с единицы', () {
      final json = {
        'pet': _rulesJson(),
        'growth': growthRulesJson(),
        ...economyParamsJson(),
        'bedtime': bedtimeTextsJson(),
      };
      expect(EconomyConfig.fromJson(json).schemaVersion, 1);
      expect(() => EconomyConfig.fromJson({...json, 'schemaVersion': 0}),
          throwsArgumentError);
    });

    final broken = <String, void Function(Map<String, Object?>)>{
      'нет стартового значения': (j) => _section(j, 'initial').remove('cozy'),
      'уют на старте ноль': (j) => _section(j, 'initial')['cozy'] = 0,
      'старт ниже пола': (j) => _section(j, 'initial')['satiety'] = 10,
      'старт выше потолка': (j) => _section(j, 'initial')['mood'] = 120,
      'питомец начинает с просьбы': (j) =>
          _section(j, 'initial')['satiety'] = 50,
      'незнакомая шкала на старте': (j) =>
          _section(j, 'initial')['hunger'] = 50,
      'нет обязательных покупок': (j) => j['needs'] = [],
      'покупка повторяется': (j) =>
          (j['needs'] as List).add((j['needs'] as List).first),
      'пропуск прибавляет': (j) =>
          ((_need(j, 0)['missedEffects'] as List).first as Map)['delta'] = 30,
      'пропуск на ноль': (j) =>
          ((_need(j, 0)['missedEffects'] as List).first as Map)['delta'] = 0,
      'пропуск снижает уют': (j) =>
          ((_need(j, 0)['missedEffects'] as List).first as Map)['stat'] =
              'cozy',
      'пропуск ни на что не влияет': (j) => _need(j, 0)['missedEffects'] = [],
      'пустая причина пропуска': (j) => _need(j, 1)['missedReason'] = ' ',
      'у снижаемой шкалы нет порога': (j) => _section(j, 'low').remove('care'),
      'порог ниже пола': (j) => _entry(j, 'low', 'satiety')['atOrBelow'] = 10,
      'порог на потолке': (j) => _entry(j, 'low', 'care')['atOrBelow'] = 100,
      'порог у уюта': (j) =>
          _section(j, 'low')['cozy'] = {'atOrBelow': 10, 'text': 'Пусто'},
      'пустая просьба': (j) => _entry(j, 'low', 'satiety')['text'] = '',
      'ночью снижается уют': (j) => _section(j, 'nightly')['effects'] = [
            {'stat': 'cozy', 'delta': -1}
          ],
      'ночное изменение на ноль': (j) => _section(j, 'nightly')['effects'] = [
            {'stat': 'mood', 'delta': 0}
          ],
      'ночь без причины': (j) => _section(j, 'nightly')['reason'] = '',
      'нет поглаживания': (j) => _section(j, 'actions').remove('pet_tap'),
      'нет задания': (j) => _section(j, 'actions').remove('task_done'),
      'действие отнимает': (j) =>
          ((_entry(j, 'actions', 'task_done')['effects'] as List).first
              as Map)['delta'] = -5,
      'действие на ноль': (j) =>
          ((_entry(j, 'actions', 'pet_tap')['effects'] as List).first
              as Map)['delta'] = 0,
      'действие ни на что не влияет': (j) =>
          _entry(j, 'actions', 'task_done')['effects'] = [],
      'лимит ноль': (j) => _entry(j, 'actions', 'pet_tap')['maxPerDay'] = 0,
      'действие без причины': (j) =>
          _entry(j, 'actions', 'pet_tap')['reason'] = ' ',
      'нет уровня настроения': (j) => _section(j, 'moodLevels').remove('bored'),
      'уровни не по порядку': (j) =>
          _entry(j, 'moodLevels', 'joy')['from'] = 90,
      'одинаковые пороги': (j) => _entry(j, 'moodLevels', 'calm')['from'] = 65,
      'скука начинается выше пола': (j) =>
          _entry(j, 'moodLevels', 'bored')['from'] = 40,
      'порог уровня за потолком': (j) =>
          _entry(j, 'moodLevels', 'delight')['from'] = 101,
      'пустая подпись уровня': (j) =>
          _entry(j, 'moodLevels', 'delight')['label'] = '',
      'незнакомая шкала': (j) => _section(j, 'low')['hunger'] = {
            'atOrBelow': 40,
            'text': 'Хочется есть'
          },
      'шаблон без {delta}': (j) => _section(j, 'texts')['change'] = '{stat}',
      'шаблон потолка без {stat}': (j) =>
          _section(j, 'texts')['atMax'] = 'и так на максимуме',
      'пустой шаблон': (j) => _section(j, 'texts')['purchase'] = '',
    };
    for (final MapEntry(key: name, value: edit) in broken.entries) {
      test('не пропускает: $name', () {
        expect(() => _rulesWith(edit), throwsArgumentError);
      });
    }
  });

  group('пять дней подряд', () {
    test('заботливый: всё обязательное каждый день — просьб нет ни разу', () {
      final pet = PetStateService(rules: _rules);
      for (var day = 1; day <= 5; day++) {
        pet.startDay(day);
        for (final item in [_food, _water, _cleaning]) {
          pet.applyPurchase(item);
        }
        pet.perform(PetRules.taskDone);
        pet.perform(PetRules.petTap);
        expect(pet.status.wishes, isEmpty, reason: 'день $day');
        pet.closeDay(boughtItemIds: _allNeeds);
        expect(pet.status.wishes, isEmpty, reason: 'ночь $day');
      }
      expect(pet.state.satiety, PetState.cap);
      expect(pet.state.care, PetState.cap);
    });

    test('забывчивый: пять дней без покупок — просьбы есть, всё обратимо', () {
      final pet = PetStateService(rules: _rules);
      for (var day = 1; day <= 5; day++) {
        pet.startDay(day);
        pet.closeDay(boughtItemIds: const []);
        _expectWithinBounds(pet.state);
      }
      expect(pet.status.isLow(PetStat.satiety), isTrue);
      expect(pet.status.isLow(PetStat.care), isTrue);
      expect(pet.status.moodLevel, MoodLevel.bored);

      pet.startDay(6);
      pet.applyPurchase(_food);
      pet.applyPurchase(_cleaning);
      pet.perform(PetRules.taskDone);
      expect(pet.status.wishes, isEmpty);
    });
  });
}
