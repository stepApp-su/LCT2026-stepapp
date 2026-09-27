import 'dart:convert';
import 'dart:math';

import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/growth_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/growth.dart';

final GrowthRules _rules = GrowthRules.fromJson(growthRulesJson());

GrowthService get _service => GrowthService(_rules);

GrowthRules _rulesWith(void Function(Map<String, Object?> json) edit) {
  final json = (jsonDecode(jsonEncode(growthRulesJson())) as Map)
      .cast<String, Object?>();
  edit(json);
  return GrowthRules.fromJson(json);
}

Map<String, Object?> _section(Map<String, Object?> json, String key) =>
    (json[key] as Map).cast<String, Object?>();

PetProgress _progress(int points, PetStage stage) =>
    PetProgress.create(growthPoints: points, stage: stage);

({PetProgress progress, List<StageUp> stageUps}) _play(
  List<DayFacts> days, {
  PetProgress? from,
  GrowthService? service,
}) {
  var progress = from ?? PetProgress.initial();
  final stageUps = <StageUp>[];
  for (final facts in days) {
    final outcome = (service ?? _service).closeDay(progress, facts);
    progress = outcome.progress;
    if (outcome.stageUp != null) stageUps.add(outcome.stageUp!);
  }
  return (progress: progress, stageUps: stageUps);
}

Transaction _tx(
  String id,
  TransactionType type,
  int amount, {
  int day = 1,
  String source = 'day_income',
  ExpenseCategory? category,
}) =>
    Transaction.create(
      id: id,
      type: type,
      amount: amount,
      sourceId: source,
      category: category,
      reasonText: 'Операция $id',
      at: DateTime(2026, 9, 24, 12),
      dayNumber: day,
    );

void main() {
  group('очки за день', () {
    test('идеальный день: три фактора ТЗ и задание — максимум 7', () {
      final factors = _service.factorsOf(dayFacts(1));
      expect(factors, GrowthFactor.values.toSet());
      expect(_service.pointsFor(factors), 7);
      expect(_rules.maxDailyPoints, 7);
    });

    test('плохой день приносит ровно 0', () {
      final factors = _service.factorsOf(idleDay(1));
      expect(factors, isEmpty);
      expect(_service.pointsFor(factors), 0);
    });

    test('пустой подтверждённый план не приносит очков «по плану»', () {
      DayFacts confirmedPlan(BudgetPlan plan, {int spentOptional = 0}) =>
          dayFacts(1,
              plan: plan,
              spentMandatory: 0,
              spentOptional: spentOptional,
              deposited: 0,
              paid: false,
              tasks: 0);
      expect(_service.factorsOf(confirmedPlan(BudgetPlan.empty(60))), isEmpty);
      expect(
          _service
              .factorsOf(confirmedPlan(BudgetPlan.empty(60), spentOptional: 5)),
          isEmpty);
      expect(
          _service.factorsOf(
              confirmedPlan(dayPlan(mandatory: 5, optional: 0, savings: 0))),
          isEmpty);
    });

    test('каждый фактор считается отдельно', () {
      expect(_service.factorsOf(dayFacts(1, confirmed: false, tasks: 0)),
          {GrowthFactor.mandatoryPaid});
      expect(
          _service.factorsOf(dayFacts(1,
              plan: dayPlan(savings: 0), deposited: 0, paid: false, tasks: 0)),
          {GrowthFactor.followedPlan});
      expect(
          _service
              .factorsOf(dayFacts(1, spentOptional: 50, paid: false, tasks: 0)),
          {GrowthFactor.savedAsPlanned});
      expect(_service.factorsOf(dayFacts(1, confirmed: false, paid: false)),
          {GrowthFactor.taskDone});
      expect(_service.pointsFor({GrowthFactor.taskDone}), 1);
    });

    test('плана нет — нет очков ни за план, ни за копилку', () {
      expect(_service.factorsOf(dayFacts(1, confirmed: false)),
          {GrowthFactor.mandatoryPaid, GrowthFactor.taskDone});
    });

    test('в копилку по плану 0 — за копилку очков нет, сколько ни отложи', () {
      final zero = dayPlan(optional: 30, savings: 0);
      expect(
          _service.factorsOf(
              dayFacts(1, plan: zero, spentOptional: 30, deposited: 0)),
          isNot(contains(GrowthFactor.savedAsPlanned)));
      expect(
          _service.factorsOf(
              dayFacts(1, plan: zero, spentOptional: 30, deposited: 10)),
          isNot(contains(GrowthFactor.savedAsPlanned)));
    });

    test('отложить больше плана — план не нарушен', () {
      expect(
          _service.factorsOf(dayFacts(1, deposited: 60)),
          containsAll(
              [GrowthFactor.followedPlan, GrowthFactor.savedAsPlanned]));
    });

    test('отложить меньше плана за пределом допуска — ни плана, ни копилки',
        () {
      final factors = _service.factorsOf(dayFacts(1, deposited: 10));
      expect(factors, isNot(contains(GrowthFactor.followedPlan)));
      expect(factors, isNot(contains(GrowthFactor.savedAsPlanned)));
    });

    test('отложить чуть меньше плана — план соблюдён, копилка не засчитана',
        () {
      final factors = _service.factorsOf(dayFacts(1, deposited: 15));
      expect(factors, contains(GrowthFactor.followedPlan));
      expect(factors, isNot(contains(GrowthFactor.savedAsPlanned)));
    });

    test('граница допуска включительно в обе стороны', () {
      bool followed(int spentOptional) => _service
          .factorsOf(dayFacts(1, spentOptional: spentOptional))
          .contains(GrowthFactor.followedPlan);
      expect(followed(15), isTrue);
      expect(followed(16), isFalse);
      expect(followed(5), isTrue);
      expect(followed(4), isFalse);
    });

    test('допуск: 20% с округлением вверх, но не меньше 5 монет', () {
      expect([
        for (final p in [0, 10, 25, 26, 30, 60, 100]) _rules.toleranceFor(p)
      ], [
        5,
        5,
        5,
        6,
        6,
        12,
        20
      ]);
    });

    test('ноль в плане направления — без деления на ноль, допуск 5', () {
      final plan = dayPlan(optional: 0, savings: 30);
      bool followed(int spent) => _service
          .factorsOf(
              dayFacts(1, plan: plan, spentOptional: spent, deposited: 30))
          .contains(GrowthFactor.followedPlan);
      expect(followed(0), isTrue);
      expect(followed(5), isTrue);
      expect(followed(6), isFalse);
    });

    test('обязательное не купили — не засчитаны ни оплата, ни план', () {
      final factors =
          _service.factorsOf(dayFacts(1, spentMandatory: 0, paid: false));
      expect(factors, isNot(contains(GrowthFactor.mandatoryPaid)));
      expect(factors, isNot(contains(GrowthFactor.followedPlan)));
    });
  });

  group('стадии и накопление', () {
    test('ровно на пороге — новая стадия, на единицу меньше — прежняя', () {
      expect({
        for (final p in [0, 3, 4, 13, 14, 31, 32, 1000]) p: _rules.stageFor(p)
      }, {
        0: PetStage.egg,
        3: PetStage.egg,
        4: PetStage.baby,
        13: PetStage.baby,
        14: PetStage.teen,
        31: PetStage.teen,
        32: PetStage.adult,
        1000: PetStage.adult,
      });
    });

    test('пять идеальных дней: три перехода, по ТЗ нужно минимум два', () {
      final result = _play([for (var d = 1; d <= 5; d++) dayFacts(d)]);
      expect(result.progress.growthPoints, 35);
      expect(result.progress.stage, PetStage.adult);
      expect([for (final up in result.stageUps) up.to],
          [PetStage.baby, PetStage.teen, PetStage.adult]);
      expect([
        for (final d in result.progress.growthDays) d.stageAfter
      ], [
        PetStage.baby,
        PetStage.teen,
        PetStage.teen,
        PetStage.teen,
        PetStage.adult,
      ]);
    });

    test('случайные дни: очки и стадия только растут, сумма сходится', () {
      for (var seed = 0; seed < 300; seed++) {
        final random = Random(seed);
        var progress = PetProgress.initial();
        var sum = 0;
        for (var day = 1; day <= 30; day++) {
          final facts = dayFacts(
            day,
            plan: dayPlan(
              mandatory: 5 * random.nextInt(8),
              optional: 5 * random.nextInt(5),
              savings: 5 * random.nextInt(5),
              income: 100,
            ),
            confirmed: random.nextBool(),
            spentMandatory: random.nextInt(50),
            spentOptional: random.nextInt(50),
            deposited: random.nextInt(50),
            paid: random.nextBool(),
            tasks: random.nextInt(3),
          );
          final outcome = _service.closeDay(progress, facts);
          final next = outcome.progress;
          expect(outcome.counted, isTrue);
          expect(
              outcome.day.points, inInclusiveRange(0, _rules.maxDailyPoints));
          expect(outcome.day.points, _service.pointsFor(outcome.day.factors));
          expect(
              next.growthPoints, greaterThanOrEqualTo(progress.growthPoints));
          expect(next.stage.index, greaterThanOrEqualTo(progress.stage.index));
          expect(next.stage, _rules.stageFor(next.growthPoints));
          expect(outcome.stageUp != null, next.stage != progress.stage);
          sum += outcome.day.points;
          progress = next;
        }
        expect(progress.growthPoints, sum, reason: 'seed $seed');
        expect(progress.growthDays, hasLength(30));
      }
    });

    test('плохой день ничего не отнимает', () {
      final outcome =
          _service.closeDay(_progress(20, PetStage.teen), idleDay(4));
      expect(outcome.day.points, 0);
      expect(outcome.progress.growthPoints, 20);
      expect(outcome.progress.stage, PetStage.teen);
      expect(outcome.stageUp, isNull);
    });

    test('стадия не понижается, даже если пороги подняли', () {
      final outcome =
          _service.closeDay(_progress(10, PetStage.adult), idleDay(9));
      expect(outcome.progress.stage, PetStage.adult);
      expect(outcome.day.stageBefore, PetStage.adult);
      expect(outcome.day.stageAfter, PetStage.adult);
    });

    test('повторное закрытие того же дня не удваивает очки', () {
      final first = _service.closeDay(PetProgress.initial(), dayFacts(1));
      final again = _service.closeDay(first.progress, dayFacts(1, tasks: 3));
      expect(again.counted, isFalse);
      expect(again.progress, first.progress);
      expect(again.day, first.day);
      expect(again.stageUp, isNull);
    });

    test('назад дни не идут, пропуск номера допустим', () {
      final third = _service.closeDay(PetProgress.initial(), dayFacts(3));
      expect(() => _service.closeDay(third.progress, dayFacts(2)),
          throwsArgumentError);
      final fifth = _service.closeDay(third.progress, dayFacts(5));
      expect([for (final d in fifth.progress.growthDays) d.dayNumber], [3, 5]);
    });

    test('при щедрых порогах можно перепрыгнуть стадию', () {
      final generous = GrowthService(
          _rulesWith((j) => j['stages'] = {'baby': 1, 'teen': 2, 'adult': 3}));
      final outcome = generous.closeDay(PetProgress.initial(), dayFacts(1));
      expect(outcome.stageUp!.from, PetStage.egg);
      expect(outcome.stageUp!.to, PetStage.adult);
      expect(outcome.stageUp!.stageLabel, 'Взрослый');
    });

    test('copyWith не теряет историю и звания', () {
      final progress = PetProgress.create(
        growthPoints: 7,
        stage: PetStage.baby,
        earnedTitles: ['novice'],
        currentTitleId: 'novice',
        growthDays: _play([dayFacts(1)]).progress.growthDays,
      );
      final renamed = progress.copyWith(currentTitleId: 'planner');
      expect(renamed.growthDays, progress.growthDays);
      expect(renamed.earnedTitles, ['novice']);
      expect(renamed.growthPoints, 7);
      expect(renamed.stage, PetStage.baby);
      expect(renamed.currentTitleId, 'planner');
      expect(progress.copyWith(), progress);
    });

    test('звания и текущее звание переносятся без изменений', () {
      final titled = PetProgress.create(
          growthPoints: 0,
          stage: PetStage.egg,
          earnedTitles: ['novice'],
          currentTitleId: 'novice');
      final next = _service.closeDay(titled, dayFacts(1)).progress;
      expect(next.earnedTitles, ['novice']);
      expect(next.currentTitleId, 'novice');
    });
  });

  group('объяснение роста', () {
    test('первая стадия за день: два главных дела — план и копилка', () {
      final up = _play([dayFacts(1)]).stageUps.single;
      expect(up.from, PetStage.egg);
      expect(up.days, 1);
      expect(up.reasonText,
          'Сегодня мы тратили по плану и откладывали в копилку.');
    });

    test('новая стадия считает только дни на прежней стадии', () {
      final up = _play([dayFacts(1), dayFacts(2)]).stageUps.last;
      expect(up.to, PetStage.teen);
      expect(up.days, 1);
      expect(up.reasonText, startsWith('Сегодня мы'));
    });

    test('несколько дней: «За 3 дня: …»', () {
      final small = [
        for (var d = 2; d <= 4; d++)
          dayFacts(d, confirmed: false, paid: true, tasks: 1)
      ];
      final up = _play([dayFacts(1), ...small]).stageUps.last;
      expect(up.to, PetStage.teen);
      expect(up.days, 3);
      expect(up.reasonText, 'За 3 дня: покупали всё нужное и решали задания.');
    });

    test('слово «день» склоняется по числу', () {
      final tasksOnly = [
        for (var d = 2; d <= 8; d++)
          dayFacts(d, confirmed: false, paid: false, tasks: 1)
      ];
      final up = _play([dayFacts(1), ...tasksOnly]).stageUps.last;
      expect(up.days, 7);
      expect(up.reasonText, 'За 7 дней: решали задания.');
    });

    test('называем дела хотя бы из половины дней, редкие — нет', () {
      final days = [
        dayFacts(2,
            confirmed: true, deposited: 0, tasks: 0, plan: dayPlan(savings: 0)),
        dayFacts(3, confirmed: false, tasks: 0),
        dayFacts(4,
            confirmed: true, deposited: 0, tasks: 0, plan: dayPlan(savings: 0)),
        dayFacts(5, confirmed: false, tasks: 1, spentOptional: 0),
      ];
      final up = _play(days, from: _progress(2, PetStage.baby)).stageUps.single;
      expect(up.days, 4);
      expect(
          up.reasonText, 'За 4 дня: покупали всё нужное и тратили по плану.');
    });

    test('редкое дело не называем, даже если есть место для второго', () {
      final days = [
        for (var d = 2; d <= 4; d++)
          dayFacts(d, confirmed: false, paid: true, tasks: 0),
        dayFacts(5, confirmed: false, paid: true, tasks: 1),
      ];
      final up = _play(days, from: _progress(5, PetStage.baby)).stageUps.single;
      expect(up.days, 4);
      expect(up.reasonText, 'За 4 дня: покупали всё нужное.');
    });

    test('если ни одно дело не набрало половины — называем самые частые', () {
      final days = [
        dayFacts(2, confirmed: false, paid: true, tasks: 0),
        dayFacts(3, confirmed: false, paid: false, tasks: 1),
        dayFacts(4, confirmed: false, paid: true, tasks: 0),
        dayFacts(5, confirmed: false, paid: false, tasks: 1),
        dayFacts(6,
            plan: dayPlan(savings: 0), deposited: 0, paid: false, tasks: 0),
      ];
      final up = _play(days, from: _progress(7, PetStage.baby)).stageUps.single;
      expect(up.days, 5);
      expect(up.reasonText, 'За 5 дней: покупали всё нужное и решали задания.');
    });

    test('без половины называем только самое частое дело, не менее частые', () {
      final days = [
        idleDay(2),
        dayFacts(3, confirmed: false, paid: false, tasks: 1),
        dayFacts(4,
            plan: dayPlan(savings: 0), deposited: 0, paid: false, tasks: 0),
        dayFacts(5, confirmed: false, paid: true, tasks: 0),
        dayFacts(6, confirmed: false, paid: true, tasks: 0),
      ];
      final up = _play(days, from: _progress(7, PetStage.baby)).stageUps.single;
      expect(up.days, 5);
      expect(up.reasonText, 'За 5 дней: покупали всё нужное.');
    });

    test('сначала самые частые дела, при равенстве — копилка раньше плана', () {
      final both = dayFacts(2,
          confirmed: true, deposited: 0, tasks: 0, plan: dayPlan(savings: 0));
      final days = [
        both,
        dayFacts(3, spentOptional: 50, tasks: 0),
        dayFacts(4,
            confirmed: true, deposited: 0, tasks: 0, plan: dayPlan(savings: 0)),
        dayFacts(5, spentOptional: 50, tasks: 0),
      ];
      final up = _play(days, from: _progress(1, PetStage.baby)).stageUps.single;
      expect(up.days, 4);
      expect(up.reasonText,
          'За 4 дня: покупали всё нужное и откладывали в копилку.');
    });

    test('при равной частоте — сначала копилка и план, не больше двух дел', () {
      final days = [
        dayFacts(2, confirmed: false, paid: true, tasks: 0),
        dayFacts(3,
            plan: dayPlan(savings: 0), deposited: 0, paid: false, tasks: 0),
        dayFacts(4, spentOptional: 50, paid: false, tasks: 0),
        dayFacts(5, confirmed: false, paid: false, tasks: 1),
      ];
      final up = _play(days, from: _progress(7, PetStage.baby)).stageUps.single;
      expect(up.days, 4);
      expect(
          up.reasonText, 'За 4 дня: тратили по плану и откладывали в копилку.');
    });

    test('если дел не было вовсе — общая фраза, а не пустота', () {
      final outcome =
          _service.closeDay(_progress(10, PetStage.egg), idleDay(3));
      expect(outcome.stageUp!.to, PetStage.baby);
      expect(outcome.stageUp!.reasonText, 'Мы многому научились вместе.');
    });

    test('заголовок: имя питомца и новая стадия', () {
      final up = _play([dayFacts(1)]).stageUps.single;
      expect(_service.stageUpTitle(up, petName: 'Мони'),
          'Мони подрастает: теперь «Малыш»!');
    });
  });

  group('строки итогов дня', () {
    test('сделанное — с очками, несделанное — подсказкой, порядок постоянный',
        () {
      final day = _service
          .closeDay(PetProgress.initial(),
              dayFacts(1, confirmed: false, paid: true, tasks: 2))
          .day;
      final lines = _service.lines(day);
      expect([for (final l in lines) l.factor], GrowthFactor.values);
      expect([for (final l in lines) l.met], [true, false, false, true]);
      expect([for (final l in lines) l.points], [2, 2, 2, 1]);
      expect([
        for (final l in lines) l.text
      ], [
        'Всё нужное куплено: +2 к росту',
        'Потратим по плану — будет +2 к росту',
        'Отложим в копилку по плану — будет +2 к росту',
        'Задание сделано: +1 к росту',
      ]);
    });
  });

  group('статус роста', () {
    test('сколько осталось до следующей стадии', () {
      final egg = _service.status(PetProgress.initial());
      expect((
        egg.stage,
        egg.stageLabel,
        egg.next,
        egg.nextLabel,
        egg.pointsToNext
      ), (
        PetStage.egg,
        'Яйцо',
        PetStage.baby,
        'Малыш',
        4
      ));
      final baby = _service.status(_progress(10, PetStage.baby));
      expect((baby.next, baby.pointsToNext), (PetStage.teen, 4));
    });

    test('у взрослого следующей стадии нет', () {
      final adult = _service.status(_progress(40, PetStage.adult));
      expect(adult.next, isNull);
      expect(adult.nextLabel, isNull);
      expect(adult.pointsToNext, isNull);
    });

    test('очков уже больше порога — осталось ноль, а не минус', () {
      expect(_service.status(_progress(20, PetStage.baby)).pointsToNext, 0);
    });
  });

  group('факты дня из журнала', () {
    GameDay day(List<Transaction> transactions, {bool confirmed = true}) =>
        GameDay.create(
          number: 1,
          income: 60,
          plan: dayPlan(),
          transactions: transactions,
          planConfirmed: confirmed,
        );

    const needs = ['food', 'water_light', 'cleaning'];

    test('траты по категориям, взносы, задания и обязательное', () {
      final facts = DayFacts.fromDay(
        day([
          _tx('1', TransactionType.income, 60),
          _tx('2', TransactionType.expense, 15,
              source: 'shop:food', category: ExpenseCategory.mandatory),
          _tx('3', TransactionType.expense, 5,
              source: 'shop:water_light', category: ExpenseCategory.mandatory),
          _tx('4', TransactionType.expense, 5,
              source: 'shop:cleaning', category: ExpenseCategory.mandatory),
          _tx('5', TransactionType.expense, 5,
              source: 'shop:treat', category: ExpenseCategory.optional),
          _tx('6', TransactionType.expense, 10, source: 'event:rain'),
          _tx('7', TransactionType.toSavings, 20, source: 'savings'),
          _tx('8', TransactionType.fromSavings, 5, source: 'savings'),
          _tx('12', TransactionType.fromSavings, 90, source: 'goal:constructor'),
          _tx('9', TransactionType.income, 12, source: 'task:sort'),
          _tx('10', TransactionType.income, 5, source: 'task:sort'),
          _tx('11', TransactionType.income, 8, source: 'task:basket'),
        ]),
        mandatoryItemIds: needs,
      );
      expect(facts.dayNumber, 1);
      expect(facts.plan, dayPlan());
      expect(facts.planConfirmed, isTrue);
      expect(facts.spentMandatory, 25);
      expect(facts.spentOptional, 15);
      expect(facts.deposited, 15);
      expect(facts.mandatoryPaid, isTrue);
      expect(facts.tasksDone, 2);
    });

    test('не всё обязательное куплено — не оплачено', () {
      final facts = DayFacts.fromDay(
        day([
          _tx('1', TransactionType.expense, 15,
              source: 'shop:food', category: ExpenseCategory.mandatory),
          _tx('2', TransactionType.expense, 5,
              source: 'shop:water_light', category: ExpenseCategory.mandatory),
        ]),
        mandatoryItemIds: needs,
      );
      expect(facts.mandatoryPaid, isFalse);
      expect(facts.spentMandatory, 20);
    });

    test('операции другого дня не считаются', () {
      final facts = DayFacts.fromDay(
        day([
          _tx('1', TransactionType.expense, 15,
              day: 2, source: 'shop:food', category: ExpenseCategory.mandatory),
          _tx('2', TransactionType.toSavings, 20, day: 2, source: 'savings'),
          _tx('3', TransactionType.income, 12, day: 2, source: 'task:sort'),
        ]),
        mandatoryItemIds: needs,
      );
      expect(facts.spentMandatory, 0);
      expect(facts.deposited, 0);
      expect(facts.tasksDone, 0);
      expect(facts.mandatoryPaid, isFalse);
    });

    test('положили и сняли в тот же день — в копилку ничего не ушло', () {
      final facts = DayFacts.fromDay(
        day([
          _tx('1', TransactionType.toSavings, 20, source: 'savings'),
          _tx('2', TransactionType.fromSavings, 20, source: 'savings'),
        ]),
        mandatoryItemIds: const [],
      );
      expect(facts.deposited, 0);
      expect(_service.factorsOf(facts),
          isNot(contains(GrowthFactor.savedAsPlanned)));
    });

    test('сняли больше, чем положили, — ноль, а не минус', () {
      final facts = DayFacts.fromDay(
        day([
          _tx('1', TransactionType.toSavings, 10, source: 'savings'),
          _tx('2', TransactionType.fromSavings, 30, source: 'savings'),
        ]),
        mandatoryItemIds: const [],
      );
      expect(facts.deposited, 0);
    });

    test('покупка цели не трата сверх плана, как бы её ни провели', () {
      final facts = DayFacts.fromDay(
        day([
          _tx('1', TransactionType.expense, 90,
              source: 'goal:scooter', category: ExpenseCategory.optional),
          _tx('2', TransactionType.income, 90, source: 'goal:scooter'),
        ]),
        mandatoryItemIds: const [],
      );
      expect(facts.spentOptional, 0);
      expect(facts.spentMandatory, 0);
      expect(facts.tasksDone, 0);
    });

    test('покупка цели из копилки не отнимает очки за копилку', () {
      final facts = DayFacts.fromDay(
        day([
          _tx('1', TransactionType.toSavings, 20, source: 'savings'),
          _tx('2', TransactionType.fromSavings, 90, source: 'goal:scooter'),
        ]),
        mandatoryItemIds: const [],
      );
      expect(facts.deposited, 20);
      expect(_service.factorsOf(facts), contains(GrowthFactor.savedAsPlanned));
    });

    test('неподтверждённый план переносится как есть', () {
      final facts = DayFacts.fromDay(day(const [], confirmed: false),
          mandatoryItemIds: const []);
      expect(facts.planConfirmed, isFalse);
      expect(facts.mandatoryPaid, isTrue);
    });

    test('факты и день роста — в JSON и обратно', () {
      for (final facts in [
        dayFacts(3, confirmed: false, paid: true, tasks: 2),
        dayFacts(4, confirmed: true, paid: false, tasks: 2),
      ]) {
        expect(DayFacts.fromJson(_viaJson(facts.toJson())), facts);
      }
      final day = _play([dayFacts(1, paid: false)]).progress.growthDays.single;
      expect(day.facts.planConfirmed, isTrue);
      expect(day.facts.mandatoryPaid, isFalse);
      expect(day.stageAfter, isNot(day.stageBefore));
      expect(GrowthDay.fromJson(_viaJson(day.toJson())), day);
    });

    test('невозможные факты не создаются', () {
      expect(() => dayFacts(0), throwsArgumentError);
      expect(() => dayFacts(1, spentMandatory: -1), throwsArgumentError);
      expect(() => dayFacts(1, spentOptional: -1), throwsArgumentError);
      expect(() => dayFacts(1, deposited: -1), throwsArgumentError);
      expect(() => dayFacts(1, tasks: -1), throwsArgumentError);
      expect(
          () => GrowthDay.create(
              facts: dayFacts(1),
              factors: const {},
              points: -1,
              stageBefore: PetStage.egg,
              stageAfter: PetStage.egg),
          throwsArgumentError);
      expect(
          () => GrowthDay.create(
              facts: dayFacts(1),
              factors: const {},
              points: 0,
              stageBefore: PetStage.teen,
              stageAfter: PetStage.baby),
          throwsArgumentError);
    });
  });

  group('история роста в прогрессе', () {
    test('сохраняется и читается обратно', () {
      final progress = _play([dayFacts(1), idleDay(2), dayFacts(3)]).progress;
      final restored = PetProgress.fromJson(_viaJson(progress.toJson()));
      expect(restored, progress);
      expect(restored.growthDays, hasLength(3));
    });

    test('старый прогресс без истории читается с пустой историей', () {
      final json = _viaJson(_progress(9, PetStage.baby).toJson())
        ..remove('growthDays');
      final restored = PetProgress.fromJson(json);
      expect(restored.growthDays, isEmpty);
      expect(restored.growthPoints, 9);
    });

    test('история не по порядку — порча', () {
      final days = _play([dayFacts(1), dayFacts(2)]).progress.growthDays;
      expect(
          () => PetProgress.create(
              growthPoints: 14,
              stage: PetStage.teen,
              growthDays: [days[1], days[0]]),
          throwsArgumentError);
    });

    test('прогресс с разной историей не равен', () {
      final a = _play([dayFacts(1)]).progress;
      final b = _play([dayFacts(1, tasks: 0)]).progress;
      expect(a, isNot(b));
      expect(a.growthDays, isNot(b.growthDays));
      final withHistory = PetProgress.create(
          growthPoints: a.growthPoints,
          stage: a.stage,
          growthDays: a.growthDays);
      final withoutHistory =
          PetProgress.create(growthPoints: a.growthPoints, stage: a.stage);
      expect(withHistory, isNot(withoutHistory));
    });

    test('дни роста с разными делами при равных очках не равны', () {
      GrowthDay day(GrowthFactor factor) => GrowthDay.create(
            facts: dayFacts(1),
            factors: {factor},
            points: 2,
            stageBefore: PetStage.egg,
            stageAfter: PetStage.egg,
          );
      expect(day(GrowthFactor.followedPlan),
          isNot(day(GrowthFactor.savedAsPlanned)));
      expect(day(GrowthFactor.followedPlan), day(GrowthFactor.followedPlan));
    });
  });

  group('правила роста проверяются при загрузке', () {
    test('пустые правила роста не загружаются', () {
      expect(() => GrowthRules.fromJson(const {}), throwsA(isA<TypeError>()));
    });

    final broken = <String, void Function(Map<String, Object?>)>{
      'нет очков за фактор': (j) => _section(j, 'points').remove('taskDone'),
      'ноль очков': (j) => _section(j, 'points')['followedPlan'] = 0,
      'незнакомый фактор': (j) => _section(j, 'points')['luck'] = 3,
      'допуск больше 100%': (j) =>
          _section(j, 'planTolerance')['percent'] = 101,
      'допуск меньше 0%': (j) => _section(j, 'planTolerance')['percent'] = -1,
      'минимальный допуск меньше 0': (j) =>
          _section(j, 'planTolerance')['atLeast'] = -1,
      'порог у яйца': (j) => _section(j, 'stages')['egg'] = 0,
      'нет порога стадии': (j) => _section(j, 'stages').remove('teen'),
      'пороги не растут': (j) => _section(j, 'stages')['teen'] = 4,
      'малыш с нуля': (j) => _section(j, 'stages')['baby'] = 0,
      'незнакомая стадия': (j) => _section(j, 'stages')['sage'] = 50,
      'нет подписи стадии': (j) =>
          _section(_section(j, 'texts'), 'stageLabels').remove('adult'),
      'пустая подпись стадии': (j) =>
          _section(_section(j, 'texts'), 'stageLabels')['baby'] = ' ',
      'нет текстов фактора': (j) =>
          _section(_section(j, 'texts'), 'factors').remove('taskDone'),
      'пустой текст фактора': (j) => _section(
          _section(_section(j, 'texts'), 'factors'),
          'followedPlan')['met'] = '',
      'заголовок без имени': (j) =>
          _section(j, 'texts')['stageUp'] = 'Теперь «{stage}»!',
      'заголовок без стадии': (j) =>
          _section(j, 'texts')['stageUp'] = '{name} растёт!',
      'объяснение за день без дел': (j) =>
          _section(j, 'texts')['reasonOneDay'] = 'Сегодня был хороший день.',
      'объяснение за дни без склонения': (j) =>
          _section(j, 'texts')['reasonDays'] = 'За {days} мы {actions}.',
      'слово «день» не сразу после числа': (j) =>
          _section(j, 'texts')['reasonDays'] = '{day} за {days}: {actions}.',
      'пустая общая фраза': (j) => _section(j, 'texts')['reasonFallback'] = '',
    };
    for (final MapEntry(key: name, value: edit) in broken.entries) {
      test('не пропускает: $name', () {
        expect(() => _rulesWith(edit), throwsArgumentError);
      });
    }
  });
}

Map<String, Object?> _viaJson(Map<String, Object?> json) =>
    (jsonDecode(jsonEncode(json)) as Map).cast<String, Object?>();
