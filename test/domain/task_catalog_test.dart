import 'dart:convert';
import 'dart:io';

import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/stop_words.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _raw(String file) =>
    (jsonDecode(File('assets/content/$file').readAsStringSync()) as Map)
        .cast<String, Object?>();

Map<String, Object?> _taskJson(Map<String, Object?> raw, String id) =>
    ((raw['tasks'] as List).firstWhere((t) => (t as Map)['id'] == id) as Map)
        .cast<String, Object?>();

Map<String, Object?> _variantJson(
        Map<String, Object?> raw, String id, String difficulty) =>
    ((_taskJson(raw, id)['variants'] as Map)[difficulty] as Map)
        .cast<String, Object?>();

List<String> _strings(Object? node) {
  if (node is String) return [node];
  if (node is List) return [for (final v in node) ..._strings(v)];
  if (node is Map) return [for (final v in node.values) ..._strings(v)];
  return const [];
}

bool _coinsSolvable(CoinsPayload payload) {
  int? limit;
  for (final rule in payload.rules) {
    if (rule.type == TaskRuleType.maxCoins) {
      limit = limit == null ? rule.value : (rule.value! < limit ? rule.value : limit);
    }
  }
  final denominations = payload.wallet.keys.toList()..sort();

  bool search(int index, int sum, int coins) {
    if (limit != null && coins > limit) return false;
    if (sum == payload.expected) return true;
    if (sum > payload.expected || index == denominations.length) return false;
    final denomination = denominations[index];
    for (var take = payload.wallet[denomination]!; take >= 0; take--) {
      if (search(index + 1, sum + denomination * take, coins + take)) return true;
    }
    return false;
  }

  return search(0, 0, 0);
}

bool _weekSolvable(WeekPayload payload) {
  final options = [
    for (var save = 0; save <= payload.maxSavePerDay; save += payload.step) save
  ];

  bool search(int day, int wallet, int saved) {
    if (day > payload.days) return saved >= payload.target;
    for (final save in options) {
      var left = wallet + payload.dailyIncome - save;
      if (left < 0) continue;
      final event = payload.eventOn(day);
      if (event != null) {
        left -= event.cost;
        if (left < 0) continue;
      }
      if (search(day + 1, left, saved + save)) return true;
    }
    return false;
  }

  return search(1, 0, 0);
}

int _ruleValue(TaskVariant variant, TaskRuleType type, String counterId) {
  for (final rule in variant.rules) {
    if (rule.type == type && rule.counterId == counterId) return rule.value!;
  }
  return 0;
}

void main() {
  final catalog = TaskCatalog.fromJson(_raw('tasks.json'));
  final competences = CompetenceCatalog.fromJson(_raw('competences.json'));

  group('состав', () {
    test('три темы ТЗ, в каждой минимум два задания', () {
      expect(catalog.themes.map((t) => t.id),
          containsAll(['planning', 'savings', 'payments']));
      for (final theme in catalog.themes) {
        expect(catalog.byTheme(theme.id).length, greaterThanOrEqualTo(2),
            reason: theme.id);
      }
    });

    test('заданий больше минимума, типов взаимодействия больше четырёх', () {
      expect(catalog.tasks.length, greaterThanOrEqualTo(6));
      final types = catalog.tasks.map((t) => t.type).toSet();
      expect(types.length, greaterThanOrEqualTo(4));
    });

    test('заданий с выбором ответа не больше трети', () {
      final choice = catalog.byType(TaskType.choice).length;
      expect(choice * 3, lessThanOrEqualTo(catalog.tasks.length));
    });

    test('порядок заданий не повторяется', () {
      final orders = catalog.tasks.map((t) => t.order).toList();
      expect(orders.toSet().length, orders.length);
      expect(orders, orderedEquals([...orders]..sort()));
    });

    test('у каждого задания две сложности и методика', () {
      for (final task in catalog.tasks) {
        expect(task.variants.keys, containsAll(TaskDifficulty.values),
            reason: task.id);
        expect(task.methodology.expectedSkill, isNotEmpty, reason: task.id);
        expect(task.methodology.correctLogic, isNotEmpty, reason: task.id);
      }
    });
  });

  group('компетенции', () {
    test('каждая ссылка разрешается в Единой рамке', () {
      for (final id in catalog.competenceIds()) {
        expect(competences.byId(id), isNotNull, reason: id);
      }
    });

    test('цели тоже ссылаются на существующие компетенции', () {
      final goals = GoalCatalog.fromJson(_raw('goals.json'));
      for (final id in goals.competenceIds) {
        expect(competences.byId(id), isNotNull, reason: id);
      }
    });

    test('обе сложности несут компетенцию', () {
      for (final task in catalog.tasks) {
        for (final variant in task.variants.values) {
          expect(variant.competenceIds, isNotEmpty,
              reason: '${task.id}/${variant.difficulty.name}');
        }
      }
    });

    test('покрыты все три темы Единой рамки', () {
      final areas = {
        for (final id in catalog.competenceIds()) competences.byId(id)!.area
      };
      expect(areas.length, greaterThanOrEqualTo(2));
    });
  });

  group('объяснения', () {
    test('объяснение есть при любом исходе', () {
      for (final task in catalog.tasks) {
        for (final variant in task.variants.values) {
          final where = '${task.id}/${variant.difficulty.name}';
          expect(variant.explanationFor(null), isNotEmpty, reason: where);
          expect(variant.explanationFor('что-то пошло не так'), isNotEmpty,
              reason: where);
          for (final rule in variant.rules) {
            expect(variant.explanationFor(rule.failCode), isNotEmpty,
                reason: '$where/${rule.failCode}');
          }
        }
      }
    });

    test('у каждого варианта ответа своё объяснение', () {
      for (final task in catalog.byType(TaskType.choice)) {
        for (final variant in task.variants.values) {
          final payload = variant.payload as ChoicePayload;
          for (final option in payload.options) {
            expect(option.explanation, isNotEmpty,
                reason: '${task.id}/${option.id}');
          }
        }
      }
    });

    test('у каждой карточки и позиции есть «почему»', () {
      for (final task in catalog.tasks) {
        for (final variant in task.variants.values) {
          switch (variant.payload) {
            case SortPayload(:final cards):
              for (final card in cards) {
                expect(card.why, isNotEmpty, reason: '${task.id}/${card.id}');
              }
            case OrderPayload(:final items):
              for (final item in items) {
                expect(item.why, isNotEmpty, reason: '${task.id}/${item.id}');
              }
            default:
              break;
          }
        }
      }
    });

    test('ошибка не оставляет без награды', () {
      for (final task in catalog.tasks) {
        expect(task.reward.correct, greaterThan(0), reason: task.id);
        expect(task.reward.wrong, greaterThan(0), reason: task.id);
        expect(task.reward.wrong, lessThan(task.reward.correct), reason: task.id);
      }
    });
  });

  test('стоп-лист не встречается ни в одном тексте задания', () {
    final offenders = <String>[];
    for (final text in _strings(_raw('tasks.json'))) {
      final found = findStopWords(text);
      if (found.isNotEmpty) offenders.add('$found -> $text');
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  group('задания решаемы', () {
    test('COINS: нужную сумму можно набрать имеющимися монетами', () {
      for (final task in catalog.byType(TaskType.coins)) {
        for (final variant in task.variants.values) {
          final payload = variant.payload as CoinsPayload;
          expect(payload.expected, greaterThan(0));
          expect(_coinsSolvable(payload), isTrue,
              reason: '${task.id}/${variant.difficulty.name}');
        }
      }
    });

    test('BASKET: список покупок влезает в бюджет, и остаётся на желаемое', () {
      for (final task in catalog.byType(TaskType.basket)) {
        for (final variant in task.variants.values) {
          final payload = variant.payload as BasketPayload;
          final left = payload.budget - payload.listCost;
          expect(left, greaterThanOrEqualTo(0));
          expect(payload.products.any((p) => !p.onList && p.price <= left), isTrue,
              reason: '${task.id}: на желаемое не хватает ни при каком раскладе');
        }
      }
    });

    test('DISTRIBUTE: минимумы правил умещаются в доход', () {
      for (final task in catalog.byType(TaskType.distribute)) {
        for (final variant in task.variants.values) {
          final payload = variant.payload as DistributePayload;
          final where = '${task.id}/${variant.difficulty.name}';
          final pool = payload.pool;
          if (pool != null) {
            var minimum = 0;
            for (final rule in payload.rules) {
              if (rule.type == TaskRuleType.atLeast) minimum += rule.value!;
            }
            expect(minimum, lessThanOrEqualTo(pool), reason: where);
            for (final rule in payload.rules) {
              final counter = payload.counter(rule.counterId!)!;
              expect(rule.value! % counter.step, 0, reason: '$where: шаг не даст такую сумму');
            }
          } else {
            final counter = payload.counters.single;
            final atLeast = _ruleValue(variant, TaskRuleType.atLeast, counter.id);
            final atMost = _ruleValue(variant, TaskRuleType.atMost, counter.id);
            expect(atLeast, atMost, reason: '$where: ответ не единственный');
            expect(atLeast * counter.unitValue,
                greaterThanOrEqualTo(payload.target!), reason: where);
            expect((atLeast - 1) * counter.unitValue,
                lessThan(payload.target!), reason: '$where: хватило бы и меньшего');
            expect(atLeast, lessThanOrEqualTo(counter.max ?? atLeast), reason: where);
          }
        }
      }
    });

    test('WEEK: план недели существует', () {
      for (final task in catalog.byType(TaskType.week)) {
        for (final variant in task.variants.values) {
          expect(_weekSolvable(variant.payload as WeekPayload), isTrue,
              reason: '${task.id}/${variant.difficulty.name}');
        }
      }
    });

    test('SORT: обе корзины непустые', () {
      for (final task in catalog.byType(TaskType.sort)) {
        for (final variant in task.variants.values) {
          final payload = variant.payload as SortPayload;
          for (final bin in payload.bins) {
            expect(payload.cardsOf(bin), isNotEmpty,
                reason: '${task.id}/$bin');
          }
        }
      }
    });

    test('ORDER: ранги идут подряд с единицы', () {
      for (final task in catalog.byType(TaskType.order)) {
        for (final variant in task.variants.values) {
          final payload = variant.payload as OrderPayload;
          final ranks = {for (final item in payload.items) item.rank}.toList()..sort();
          expect(ranks, orderedEquals([for (var i = 1; i <= ranks.length; i++) i]),
              reason: task.id);
        }
      }
    });
  });

  group('каталог ловит битый контент', () {
    test('ссылка на несуществующую тему', () {
      final broken = _raw('tasks.json');
      _taskJson(broken, 'payments_sort_needs')['themeId'] = 'no_such_theme';
      expect(() => TaskCatalog.fromJson(broken), throwsArgumentError);
    });

    test('правило без объяснения', () {
      final broken = _raw('tasks.json');
      final rules =
          _variantJson(broken, 'payments_coins_pay', 'easy')['rules'] as List;
      (rules.first as Map)['failCode'] = 'unknownReason';
      expect(() => TaskCatalog.fromJson(broken), throwsArgumentError);
    });

    test('пропуск в рангах', () {
      final broken = _raw('tasks.json');
      final items =
          _variantJson(broken, 'payments_order_prices', 'easy')['items'] as List;
      (items.first as Map)['rank'] = 9;
      expect(() => TaskCatalog.fromJson(broken), throwsArgumentError);
    });

    test('список покупок дороже бюджета', () {
      final broken = _raw('tasks.json');
      _variantJson(broken, 'payments_basket_shop', 'easy')['budget'] = 10;
      expect(() => TaskCatalog.fromJson(broken), throwsArgumentError);
    });

    test('неверный ответ в задании, где верны все', () {
      final broken = _raw('tasks.json');
      final options = _variantJson(broken, 'savings_choice_now_or_later', 'easy')
          ['options'] as List;
      (options.first as Map)['isCorrect'] = false;
      expect(() => TaskCatalog.fromJson(broken), throwsArgumentError);
    });

    test('карточка в несуществующей корзине', () {
      final broken = _raw('tasks.json');
      final cards =
          _variantJson(broken, 'payments_sort_needs', 'easy')['cards'] as List;
      (cards.first as Map)['bin'] = 'nowhere';
      expect(() => TaskCatalog.fromJson(broken), throwsArgumentError);
    });

    test('событие недели за пределами недели', () {
      final broken = _raw('tasks.json');
      final events =
          _variantJson(broken, 'savings_week_plan', 'easy')['events'] as List;
      (events.first as Map)['day'] = 99;
      expect(() => TaskCatalog.fromJson(broken), throwsArgumentError);
    });
  });
}
