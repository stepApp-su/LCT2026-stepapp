import 'dart:math';

import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/growth_service.dart';
import 'package:finni/domain/services/title_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/growth.dart';
import '../support/profiles.dart';
import '../support/titles.dart';

final _growth = GrowthService(GrowthRules.fromJson(growthRulesJson()));
final _titles = titleService();

PetProgress _live(Iterable<DayFacts> days, {PetProgress? from}) {
  var progress = from ?? PetProgress.initial();
  for (final facts in days) {
    progress = _growth.closeDay(progress, facts).progress;
  }
  return progress;
}

TitleFacts _factsOn(
  PetProgress progress, {
  Iterable<String> tasks = const [],
  Iterable<String> goals = const [],
  int savings = 0,
}) =>
    TitleFacts.create(
      dayNumber: progress.growthDays.last.dayNumber,
      completedTaskIds: tasks,
      reachedGoalIds: goals,
      savings: savings,
    );

TitleAward _award(
  Iterable<DayFacts> days, {
  TitleService? service,
  Iterable<String> tasks = const [],
  Iterable<String> goals = const [],
  int savings = 0,
}) {
  final progress = _live(days);
  return (service ?? _titles).award(progress,
      _factsOn(progress, tasks: tasks, goals: goals, savings: savings));
}

List<String> _owned(
  Iterable<DayFacts> days, {
  TitleService? service,
  Iterable<String> tasks = const [],
  Iterable<String> goals = const [],
  int savings = 0,
}) =>
    _award(days, service: service, tasks: tasks, goals: goals, savings: savings)
        .progress
        .earnedTitles;

List<String> _new(TitleAward award) =>
    [for (final e in award.earned) e.title.id];

PetProgress _progress(List<String> earned, String current) =>
    PetProgress.create(
        growthPoints: 0,
        stage: PetStage.egg,
        earnedTitles: earned,
        currentTitleId: current);

void main() {
  group('условия по дням', () {
    test('Планировщик: три дня с планом, не обязательно подряд', () {
      expect(_owned([planOnly(1), idleDay(2), planOnly(3)]),
          isNot(contains('planner')));
      expect(
          _owned(
              [planOnly(1), idleDay(2), planOnly(3), idleDay(4), planOnly(5)]),
          contains('planner'));
    });

    test('Планировщик: пустой или неподтверждённый план — ещё не план', () {
      final days = [
        planOnly(1),
        planOnly(2),
        dayFacts(3,
            plan: BudgetPlan.empty(60),
            spentMandatory: 0,
            spentOptional: 0,
            deposited: 0,
            paid: false,
            tasks: 0),
        dayFacts(4, confirmed: false),
      ];
      expect(_owned(days), isNot(contains('planner')));
    });

    test('Бережливый: пять дней подряд с пополнением копилки, четырёх мало',
        () {
      expect(_owned([for (var d = 1; d <= 4; d++) savedOnly(d)]),
          isNot(contains('saver')));
      expect(_owned([for (var d = 1; d <= 5; d++) savedOnly(d)]),
          contains('saver'));
    });

    test('Бережливый: пропуск номера дня или день без пополнения рвут серию',
        () {
      expect(
          _owned([
            for (final d in [1, 2, 3, 4, 6]) savedOnly(d)
          ]),
          isNot(contains('saver')));
      expect(
          _owned([
            for (var d = 1; d <= 4; d++) savedOnly(d),
            idleDay(5),
            for (var d = 6; d <= 9; d++) savedOnly(d),
          ]),
          isNot(contains('saver')));
    });

    test('Бережливый: серия засчитывается и после того, как прервалась', () {
      expect(
          _owned([
            for (var d = 1; d <= 5; d++) savedOnly(d),
            idleDay(6),
            idleDay(7),
          ]),
          contains('saver'));
    });

    test('Мастер бюджета: десять дней по плану, не обязательно подряд', () {
      final nine = [for (var d = 1; d <= 9; d++) exactDay(d * 2)];
      expect(_owned(nine), isNot(contains('budget_master')));
      expect(_owned([...nine, exactDay(20)]), contains('budget_master'));
    });

    test('Мастер бюджета: отклонение не больше 10%, без округления вверх', () {
      bool master({
        BudgetPlan? plan,
        int mandatory = 25,
        int optional = 10,
        int deposited = 20,
      }) =>
          _owned([
            for (var d = 1; d <= 10; d++)
              dayFacts(d,
                  plan: plan,
                  spentMandatory: mandatory,
                  spentOptional: optional,
                  deposited: deposited,
                  tasks: 0)
          ]).contains('budget_master');

      expect(master(mandatory: 27, optional: 11), isTrue);
      expect(master(mandatory: 23, optional: 9, deposited: 18), isTrue);
      expect(master(deposited: 60), isTrue);
      expect(master(mandatory: 28), isFalse);
      expect(master(mandatory: 22), isFalse);
      expect(master(optional: 12), isFalse);
      expect(master(deposited: 17), isFalse);
      expect(master(plan: dayPlan(savings: 5), deposited: 4), isFalse);
      expect(
          master(
              plan: dayPlan(optional: 5, savings: 5),
              optional: 5,
              deposited: 5),
          isTrue);
    });

    test('Мастер бюджета: без оплаты нужного день не в счёт, даже при плане 0',
        () {
      List<DayFacts> days({required bool paid}) => [
            for (var d = 1; d <= 10; d++)
              dayFacts(d,
                  plan: dayPlan(mandatory: 0, optional: 10, savings: 50),
                  spentMandatory: 0,
                  spentOptional: 10,
                  deposited: 50,
                  paid: paid,
                  tasks: 0)
          ];
      expect(_owned(days(paid: false)), isNot(contains('budget_master')));
      expect(_owned(days(paid: true)), contains('budget_master'));
    });

    test('Наставник: тридцать дней с делами, пустые закрытия не в счёт', () {
      final kinds = <DayFacts Function(int)>[
        planOnly,
        savedOnly,
        (d) => dayFacts(d,
            plan: BudgetPlan.empty(60),
            confirmed: false,
            spentMandatory: 0,
            spentOptional: 5,
            deposited: 0,
            paid: false,
            tasks: 0),
        (d) => dayFacts(d,
            plan: BudgetPlan.empty(60),
            confirmed: false,
            spentMandatory: 0,
            spentOptional: 0,
            deposited: 0,
            paid: false,
            tasks: 1),
      ];
      DayFacts pressedConfirm(int d) => dayFacts(d,
          plan: BudgetPlan.empty(60),
          spentMandatory: 0,
          spentOptional: 0,
          deposited: 0,
          paid: false,
          tasks: 0);
      final active = [for (var d = 1; d <= 29; d++) kinds[d % kinds.length](d)];
      final idle = [
        for (var d = 30; d <= 40; d++) d.isOdd ? pressedConfirm(d) : idleDay(d)
      ];
      expect(_owned([...active, ...idle]), isNot(contains('mentor')));
      for (final kind in kinds) {
        expect(_owned([...active, ...idle, kind(41)]), contains('mentor'));
      }
    });
  });

  group('условия по профилю', () {
    test('Знаток покупок: пройдены все задания темы, лишние не мешают', () {
      expect(_owned([idleDay(1)], tasks: [payTasks.first]),
          isNot(contains('shopping_expert')));
      expect(_owned([idleDay(1)], tasks: [...payTasks, 'other']),
          contains('shopping_expert'));
    });

    test('тема без заданий или неизвестная — звание не даётся даром', () {
      final service = titleService(titles: [
        titleJson('empty_theme', {'type': 'theme', 'themeId': 'empty'}),
        titleJson('ghost_theme', {'type': 'theme', 'themeId': 'ghost'}),
      ]);
      expect(_owned([idleDay(1)], service: service, tasks: payTasks), isEmpty);
      expect(service.problems,
          [contains('«empty_theme»'), contains('«ghost_theme»')]);
      expect(_titles.problems, isEmpty);
    });

    test('Мечтатель: первая достигнутая цель', () {
      expect(_owned([idleDay(1)]), isNot(contains('dreamer')));
      expect(_owned([idleDay(1)], goals: ['ball_rope']), contains('dreamer'));
      expect(_owned([idleDay(1)], goals: ['ball_rope', 'scooter']),
          contains('dreamer'));
    });

    test('Хранитель запаса: в копилке запас на два дня нужного', () {
      expect(_owned([dayFacts(1)], savings: 49),
          isNot(contains('reserve_keeper')));
      expect(_owned([dayFacts(1)], savings: 50), contains('reserve_keeper'));
    });

    test('Хранитель запаса: запас не в счёт, если нужное сегодня не куплено',
        () {
      expect(_owned([dayFacts(1, paid: false)], savings: 500),
          isNot(contains('reserve_keeper')));
      expect(_owned([dayFacts(1), dayFacts(2, paid: false)], savings: 500),
          isNot(contains('reserve_keeper')));
      expect(_owned([dayFacts(1, paid: false), dayFacts(2)], savings: 500),
          contains('reserve_keeper'));
    });

    test(
        'Хранитель запаса: без стоимости нужного не выдаётся и виден в проблемах',
        () {
      final service = titleService(dailyNeedsCost: 0);
      expect(_owned([dayFacts(1)], service: service, savings: 500),
          isNot(contains('reserve_keeper')));
      expect(service.problems, [contains('«reserve_keeper»')]);
      expect(() => titleService(dailyNeedsCost: -1), throwsArgumentError);
    });
  });

  group('Новичок', () {
    test('выдаётся на старте без церемонии и становится текущим', () {
      final started = _titles.start(PetProgress.initial());
      expect(started.earnedTitles, ['novice']);
      expect(started.currentTitleId, 'novice');
      expect(_titles.start(started), same(started));
    });

    test('прогресс без Новичка получает его при проверке, без церемонии', () {
      final award = _award([idleDay(1)]);
      expect(award.progress.earnedTitles, ['novice']);
      expect(award.progress.currentTitleId, 'novice');
      expect(award.earned, isEmpty);
    });

    test('Новичок не сбивает уже выбранное текущее звание', () {
      final progress =
          _live([idleDay(1)], from: _progress(['planner'], 'planner'));
      final award = _titles.award(progress, _factsOn(progress));
      expect(award.progress.earnedTitles, ['planner', 'novice']);
      expect(award.progress.currentTitleId, 'planner');
    });
  });

  group('выдача званий', () {
    test('за вечер несколько званий — в порядке каталога, текущее — последнее',
        () {
      final award = _award([for (var d = 1; d <= 5; d++) dayFacts(d)],
          tasks: payTasks, goals: ['ball_rope'], savings: 50);
      expect(_new(award),
          ['planner', 'saver', 'shopping_expert', 'reserve_keeper', 'dreamer']);
      expect(award.progress.earnedTitles, [
        'novice',
        'planner',
        'saver',
        'shopping_expert',
        'reserve_keeper',
        'dreamer',
      ]);
      expect(award.progress.currentTitleId, 'dreamer');
    });

    test(
        'полученные раньше и незнакомые звания не пропадают и не переставляются',
        () {
      final progress = _live([for (var d = 1; d <= 3; d++) planOnly(d)],
          from: _progress(['old_rank', 'dreamer'], 'old_rank'));
      final award =
          _titles.award(progress, _factsOn(progress, goals: ['ball_rope']));
      expect(award.progress.earnedTitles,
          ['old_rank', 'dreamer', 'novice', 'planner']);
      expect(_new(award), ['planner']);
      expect(award.progress.currentTitleId, 'planner');
    });

    test('новое звание сменяет текущего Новичка и выбранное вручную', () {
      final started = _live([for (var d = 1; d <= 3; d++) planOnly(d)],
          from: _titles.start(PetProgress.initial()));
      expect(started.currentTitleId, 'novice');
      final planner = _titles.award(started, _factsOn(started));
      expect(_new(planner), ['planner']);
      expect(planner.progress.currentTitleId, 'planner');

      final next =
          _live([idleDay(4)], from: _titles.choose(planner.progress, 'novice'));
      final dreamer = _titles.award(next, _factsOn(next, goals: ['ball_rope']));
      expect(_new(dreamer), ['dreamer']);
      expect(dreamer.progress.currentTitleId, 'dreamer');
    });

    test('повторная проверка того же дня ничего не выдаёт и не меняет', () {
      final progress = _live([for (var d = 1; d <= 5; d++) dayFacts(d)]);
      final facts = _factsOn(progress,
          tasks: payTasks, goals: ['ball_rope'], savings: 50);
      final first = _titles.award(progress, facts);
      final second = _titles.award(first.progress, facts);
      expect(first.earned, hasLength(5));
      expect(second.earned, isEmpty);
      expect(second.progress, same(first.progress));
    });

    test('проверка до закрытия дня или после начала следующего — ошибка вызова',
        () {
      final progress = _live([dayFacts(1), dayFacts(2)]);
      expect(
          () => _titles.award(
              PetProgress.initial(), TitleFacts.create(dayNumber: 1)),
          throwsArgumentError);
      expect(() => _titles.award(progress, TitleFacts.create(dayNumber: 3)),
          throwsArgumentError);
      expect(() => _titles.award(progress, TitleFacts.create(dayNumber: 1)),
          throwsArgumentError);
      expect(
          _titles
              .award(progress, TitleFacts.create(dayNumber: 2))
              .progress
              .earnedTitles,
          ['novice']);
    });

    test('звания не дают бонусов: меняются только полученные и текущее', () {
      final progress = _live([for (var d = 1; d <= 10; d++) exactDay(d)]);
      final after = _titles
          .award(
              progress,
              _factsOn(progress,
                  tasks: payTasks, goals: ['ball_rope'], savings: 999))
          .progress;
      expect(after.earnedTitles, hasLength(7));
      expect(
          after.copyWith(
              earnedTitles: progress.earnedTitles,
              currentTitleId: progress.currentTitleId),
          progress);
    });

    test('звание, добавленное в JSON позже, выдаётся по накопленной истории',
        () {
      final withoutSaver = titleService(titles: [
        for (final t in standardTitles())
          if (t['id'] != 'saver') t
      ]);
      final saved = _live([for (var d = 1; d <= 5; d++) savedOnly(d)]);
      final before = withoutSaver.award(saved, _factsOn(saved)).progress;
      expect(before.earnedTitles, isNot(contains('saver')));

      final next = _live([idleDay(6)], from: before);
      expect(_new(_titles.award(next, _factsOn(next))), ['saver']);
    });

    test('случайные 40 дней: звания только прибавляются, проверка идемпотентна',
        () {
      for (var seed = 0; seed < 200; seed++) {
        final random = Random(seed);
        var progress = _titles.start(PetProgress.initial());
        final tasks = <String>{};
        final goals = <String>{};
        var day = 0;
        for (var i = 0; i < 40; i++) {
          day += random.nextInt(6) == 0 ? 2 : 1;
          progress = _growth
              .closeDay(
                  progress,
                  dayFacts(day,
                      confirmed: random.nextBool(),
                      spentMandatory: random.nextInt(31),
                      spentOptional: random.nextInt(21),
                      deposited:
                          random.nextInt(3) == 0 ? 0 : random.nextInt(40),
                      paid: random.nextBool(),
                      tasks: random.nextInt(2)))
              .progress;
          if (random.nextInt(4) == 0) {
            tasks.add(payTasks[random.nextInt(payTasks.length)]);
          }
          if (random.nextInt(15) == 0) goals.add('goal_$i');
          final facts = TitleFacts.create(
              dayNumber: day,
              completedTaskIds: tasks,
              reachedGoalIds: goals,
              savings: random.nextInt(80));
          final award = _titles.award(progress, facts);
          final before = progress.earnedTitles;
          final after = award.progress.earnedTitles;
          final reason = 'seed $seed, день $day';
          expect(after.take(before.length), before, reason: reason);
          expect(after.skip(before.length), _new(award), reason: reason);
          expect(after.toSet(), hasLength(after.length), reason: reason);
          expect(after, contains(award.progress.currentTitleId),
              reason: reason);
          final again = _titles.award(award.progress, facts);
          expect(again.earned, isEmpty, reason: reason);
          expect(again.progress, same(award.progress), reason: reason);
          progress = award.progress;
        }
      }
    });
  });

  group('текущее звание и полка', () {
    test('текущее — выбранное, иначе последнее полученное из каталога', () {
      expect(_titles.current(_progress(['novice', 'planner'], 'novice'))?.id,
          'novice');
      expect(
          _titles.current(_progress(['novice', 'planner'], ''))?.id, 'planner');
      expect(_titles.current(_progress(['novice', 'old_rank'], 'old_rank'))?.id,
          'novice');
      expect(_titles.current(_progress(['novice'], 'planner'))?.id, 'novice');
      expect(_titles.current(_progress([], '')), isNull);
    });

    test('ребёнок выбирает текущее звание только из полученных', () {
      final progress = PetProgress.create(
          growthPoints: 3,
          stage: PetStage.egg,
          earnedTitles: ['novice', 'planner'],
          currentTitleId: 'planner');
      final chosen = _titles.choose(progress, 'novice');
      expect(chosen, progress.copyWith(currentTitleId: 'novice'));
      expect(_titles.choose(chosen, 'novice'), same(chosen));
      expect(() => _titles.choose(progress, 'dreamer'), throwsArgumentError);
      expect(
          () => _titles.choose(
              progress.copyWith(earnedTitles: ['novice', 'old_rank']),
              'old_rank'),
          throwsArgumentError);
    });

    test('полка — полученные звания по порядку, без повторов и неизвестных',
        () {
      final progress =
          _progress(['dreamer', 'old_rank', 'novice', 'dreamer'], 'dreamer');
      expect([for (final t in _titles.shelf(progress)) t.id],
          ['dreamer', 'novice']);
    });
  });

  group('тексты', () {
    String reason(TitleService service, String id) =>
        service.reasonOf(service.catalog.byId(id)!);

    test('объяснение «за что» собирается из условия', () {
      expect(
          reason(_titles, 'novice'), 'Начали учиться обращаться с деньгами.');
      expect(reason(_titles, 'planner'), '3 дня составляли план на день.');
      expect(reason(_titles, 'saver'), '5 дней подряд откладывали в копилку.');
      expect(reason(_titles, 'shopping_expert'),
          'Прошли все задания темы «Платежи и покупки».');
      expect(
          reason(_titles, 'reserve_keeper'), 'Отложили запас на 2 дня вперёд.');
      expect(reason(_titles, 'budget_master'),
          '10 дней покупали нужное и держались своего плана.');
    });

    test('событие получения несёт заголовок и объяснение', () {
      final event =
          _award([for (var d = 1; d <= 3; d++) planOnly(d)]).earned.single;
      expect(event.title.id, 'planner');
      expect(event.headline, 'Новое звание: «Звание planner»!');
      expect(event.reason, '3 дня составляли план на день.');
    });

    test('число в объяснении меняется вместе с условием', () {
      final service = titleService(titles: [
        titleJson(
            'planner',
            {
              'type': 'days',
              'count': 21,
              'marks': ['planMade'],
            },
            description: '{count} {day} составляли план на день.'),
        titleJson('goals', {'type': 'goals', 'count': 3},
            description: 'Целей достигнуто: {count}.'),
      ]);
      expect(reason(service, 'planner'), '21 день составляли план на день.');
      expect(reason(service, 'goals'), 'Целей достигнуто: 3.');
    });
  });

  group('новые звания — только JSON', () {
    test('девятое звание одной записью: неделя подряд с оплатой нужного', () {
      final service = titleService(titles: [
        ...standardTitles(),
        titleJson('caretaker', {
          'type': 'streak',
          'count': 7,
          'marks': ['mandatoryPaid'],
        }),
      ]);
      DayFacts paidOnly(int d) => dayFacts(d,
          plan: BudgetPlan.empty(60),
          confirmed: false,
          spentOptional: 0,
          deposited: 0,
          tasks: 0);
      expect(
          _owned([for (var d = 1; d <= 6; d++) paidOnly(d)], service: service),
          isNot(contains('caretaker')));
      expect(
          _owned([for (var d = 1; d <= 7; d++) paidOnly(d)], service: service),
          contains('caretaker'));
    });

    test('пятьдесят званий без правки кода', () {
      final service = titleService(titles: [
        for (var k = 1; k <= 50; k++)
          titleJson(
              'tasks_$k',
              {
                'type': 'days',
                'count': k,
                'marks': ['taskDone'],
              },
              description: '{count} {day} решали задания.'),
      ]);
      expect(service.catalog.titles, hasLength(50));
      final award =
          _award([for (var d = 1; d <= 37; d++) dayFacts(d)], service: service);
      expect(_new(award), [for (var k = 1; k <= 37; k++) 'tasks_$k']);
      expect(award.progress.currentTitleId, 'tasks_37');
    });

    test('признаки дня сочетаются в одном условии', () {
      final service = titleService(titles: [
        titleJson('careful_saver', {
          'type': 'days',
          'count': 2,
          'marks': ['savedAsPlanned', 'taskDone'],
        }),
      ]);
      expect(
          _owned(
              [dayFacts(1), dayFacts(2, tasks: 0), dayFacts(3, deposited: 19)],
              service: service),
          isEmpty);
      expect(
          _owned([dayFacts(1), dayFacts(2, deposited: 60)], service: service),
          ['careful_saver']);
    });
  });

  group('titles.json проверяется при загрузке', () {
    Map<String, Object?> without(Map<String, Object?> json, String key) =>
        {...json}..remove(key);

    final ok = titleJson('ok', {'type': 'start'});
    final broken = <String, (Object?, String)>{
      'неизвестный тип условия': (
        titleJson('x', {'type': 'magic'}),
        'неизвестный тип условия'
      ),
      'неизвестный признак дня': (
        titleJson('x', {
          'type': 'days',
          'count': 1,
          'marks': ['lucky'],
        }),
        'неизвестный признак дня'
      ),
      'ноль дней': (
        titleJson('x', {
          'type': 'streak',
          'count': 0,
          'marks': ['saved'],
        }),
        '≥ 1'
      ),
      'ноль целей': (titleJson('x', {'type': 'goals', 'count': 0}), '≥ 1'),
      'ноль дней запаса': (
        titleJson('x', {'type': 'reserve', 'count': 0}),
        '≥ 1'
      ),
      'нет признаков дня': (
        titleJson('x', {'type': 'days', 'count': 1, 'marks': <String>[]}),
        'хотя бы один признак'
      ),
      'признаки повторяются': (
        titleJson('x', {
          'type': 'days',
          'count': 1,
          'marks': ['saved', 'saved'],
        }),
        'повторяются'
      ),
      '«по плану» без допуска': (
        titleJson('x', {
          'type': 'days',
          'count': 1,
          'marks': ['onPlan'],
        }),
        'нужен для признака'
      ),
      'допуск без «по плану»': (
        titleJson('x', {
          'type': 'days',
          'count': 1,
          'marks': ['saved'],
          'planTolerance': {'percent': 10, 'atLeast': 0},
        }),
        'только с признаком'
      ),
      'допуск больше 100%': (
        titleJson('x', {
          'type': 'days',
          'count': 1,
          'marks': ['onPlan'],
          'planTolerance': {'percent': 101, 'atLeast': 0},
        }),
        '0..100'
      ),
      'отрицательный минимум допуска': (
        titleJson('x', {
          'type': 'days',
          'count': 1,
          'marks': ['onPlan'],
          'planTolerance': {'percent': 10, 'atLeast': -1},
        }),
        '≥ 0'
      ),
      'режим округления не да/нет': (
        titleJson('x', {
          'type': 'days',
          'count': 1,
          'marks': ['onPlan'],
          'planTolerance': {'percent': 10, 'atLeast': 0, 'roundUp': 'нет'},
        }),
        'типа bool'
      ),
      'лишнее поле в допуске': (
        titleJson('x', {
          'type': 'days',
          'count': 1,
          'marks': ['onPlan'],
          'planTolerance': {'percent': 10, 'atLeast': 0, 'bonus': 1},
        }),
        'неизвестное поле'
      ),
      'награда за звание запрещена': (
        {
          ...titleJson('x', {'type': 'start'}),
          'reward': {'coins': 10},
        },
        'неизвестное поле'
      ),
      'лишнее поле в условии': (
        titleJson('x', {'type': 'goals', 'count': 1, 'bonus': 5}),
        'неизвестное поле'
      ),
      'нет названия': (
        without(titleJson('x', {'type': 'start'}), 'title'),
        'типа String'
      ),
      'нет условия': (
        without(titleJson('x', {'type': 'start'}), 'condition'),
        'типа Map'
      ),
      'число строкой': (
        titleJson('x', {'type': 'goals', 'count': '1'}),
        'типа int'
      ),
      'признаки не списком': (
        titleJson('x', {'type': 'days', 'count': 1, 'marks': 'saved'}),
        'типа List'
      ),
      'атрибут не строкой': (
        {
          ...titleJson('x', {'type': 'start'}),
          'attributeId': 5
        },
        'типа String'
      ),
      'пустая иконка': (
        {
          ...titleJson('x', {'type': 'start'}),
          'iconId': ' '
        },
        'не может быть пустым'
      ),
      'пустая компетенция': (
        {
          ...titleJson('x', {'type': 'start'}),
          'competenceId': ''
        },
        'не может быть пустым'
      ),
      'id с пробелом': (
        titleJson('my title', {'type': 'start'}),
        'без пробелов'
      ),
      'пустая тема': (
        titleJson('x', {'type': 'theme', 'themeId': ''}),
        'не может быть пустым'
      ),
      'чужой плейсхолдер': (
        titleJson('x', {'type': 'goals', 'count': 1},
            description: '{count} {coin} за цели.'),
        'нет {coin}'
      ),
      '{day} не после числа': (
        titleJson(
            'x',
            {
              'type': 'days',
              'count': 2,
              'marks': ['saved'],
            },
            description: 'Копили {count} раза, {day} за днём.'),
        'сразу после'
      ),
      '{theme} не у темы': (
        titleJson(
            'x',
            {
              'type': 'days',
              'count': 1,
              'marks': ['saved'],
            },
            description: 'Тема «{theme}».'),
        'нет {theme}'
      ),
      '{count} у стартового звания': (
        titleJson('x', {'type': 'start'}, description: 'Старт {count}.'),
        'нет {count}'
      ),
      'запись — не объект': ('просто строка', 'ожидался объект'),
      'повтор id': (titleJson('ok', {'type': 'start'}), 'повторяется'),
    };

    for (final MapEntry(key: name, value: (record, fragment))
        in broken.entries) {
      test('битая запись пропускается с причиной: $name', () {
        final catalog = TitleCatalog.fromJson(titlesJson([ok, record]));
        expect([for (final t in catalog.titles) t.id], ['ok']);
        expect(catalog.problems, [
          allOf(contains('titles[1]'), contains(fragment)),
        ]);
      });
    }

    test('битая запись в середине не мешает следующим', () {
      final catalog = TitleCatalog.fromJson(titlesJson([
        titleJson('first', {'type': 'start'}),
        titleJson('broken', {'type': 'magic'}),
        titleJson('second', {'type': 'goals', 'count': 1}),
        titleJson('also_broken', {'type': 'goals', 'count': 0}),
        titleJson('third', {'type': 'reserve', 'count': 2}),
      ]));
      expect(
          [for (final t in catalog.titles) t.id], ['first', 'second', 'third']);
      expect(catalog.problems, [
        contains('titles[1] «broken»'),
        contains('titles[3] «also_broken»'),
      ]);
    });

    test('в причине видно, какое звание сломано', () {
      final catalog = TitleCatalog.fromJson(titlesJson([
        titleJson('saver', {'type': 'magic'})
      ]));
      expect(catalog.titles, isEmpty);
      expect(catalog.problems.single, contains('titles[0] «saver»'));
    });

    test('без общей структуры файл не загружается', () {
      final json = titlesJson();
      for (final bad in [
        without(json, 'texts'),
        without(json, 'titles'),
        without(json, 'schemaVersion'),
        {...json, 'schemaVersion': 0},
        {...json, 'titles': 'не список'},
        {
          ...json,
          'texts': {'earned': 'Новое звание!'}
        },
        {
          ...json,
          'texts': {'earned': 'Новое звание: «{title}»!', 'extra': ''}
        },
      ]) {
        expect(() => TitleCatalog.fromJson(bad), throwsArgumentError,
            reason: '$bad');
      }
    });

    test('каталог из кода тоже не принимает повтор id', () {
      final title = TitleDef.create(
          id: 'novice',
          title: 'Новичок',
          description: 'Старт.',
          iconId: 'icon',
          competenceId: 'budget_idea',
          condition: const StartCondition());
      expect(
          () => TitleCatalog.create(
              texts: TitleTexts.create(earned: '{title}'),
              titles: [title, title]),
          throwsArgumentError);
    });

    test('строгий допуск отличается от обычного и переживает JSON', () {
      final strict =
          PlanTolerance.create(percent: 10, atLeast: 0, roundUp: false);
      final lenient = PlanTolerance.create(percent: 10, atLeast: 0);
      expect(strict, isNot(lenient));
      expect(strict.allowedFor(25), 2);
      expect(lenient.allowedFor(25), 3);
      for (final tolerance in [strict, lenient]) {
        final copy = PlanTolerance.fromJson(tolerance.toJson());
        expect(copy, tolerance);
        expect(copy.hashCode, tolerance.hashCode);
      }
    });

    test('условия читаются со всеми параметрами', () {
      final catalog = TitleCatalog.fromJson(titlesJson());
      expect(catalog.problems, isEmpty);
      final master = catalog.byId('budget_master')!.condition as DaysCondition;
      expect(master.count, 10);
      expect(master.inARow, isFalse);
      expect(master.marks, {DayMark.mandatoryPaid, DayMark.onPlan});
      expect(master.planTolerance,
          PlanTolerance.create(percent: 10, atLeast: 0, roundUp: false));
      expect(
          (TitleCatalog.fromJson(titlesJson([
            titleJson('lenient', {
              'type': 'days',
              'count': 1,
              'marks': ['onPlan'],
              'planTolerance': {'percent': 10, 'atLeast': 0},
            })
          ])).byId('lenient')!.condition as DaysCondition)
              .planTolerance!
              .roundUp,
          isTrue);
      expect(
          (catalog.byId('saver')!.condition as DaysCondition).inARow, isTrue);
      expect(
          (catalog.byId('reserve_keeper')!.condition as ReserveCondition).days,
          2);
      expect(
          (catalog.byId('shopping_expert')!.condition as ThemeCondition)
              .themeId,
          'payments');
      expect(catalog.byId('novice')!.attributeId, '');
      expect(
          TitleCatalog.fromJson(titlesJson([
            titleJson('planner', {'type': 'start'},
                attributeId: 'attr_notebook')
          ])).byId('planner')!.attributeId,
          'attr_notebook');
      expect(catalog.byId('ghost'), isNull);
    });
  });

  group('факты для проверки', () {
    test('берутся из профиля: день, задания, цели, копилка', () {
      final profile = richProfile();
      final facts = TitleFacts.of(profile);
      expect(facts.dayNumber, profile.currentDay.number);
      expect(facts.completedTaskIds, profile.completedTasks.toSet());
      expect(facts.reachedGoalIds, profile.reachedGoalIds.toSet());
      expect(facts.savings, profile.wallet.savings);
    });

    test('день с первого, копилка не бывает отрицательной', () {
      expect(() => TitleFacts.create(dayNumber: 0), throwsArgumentError);
      expect(() => TitleFacts.create(dayNumber: 1, savings: -1),
          throwsArgumentError);
    });
  });
}
