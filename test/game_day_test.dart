import 'dart:convert';
import 'dart:io';

import 'package:finni/content/content_repository.dart';
import 'package:finni/domain/game_clock.dart';
import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/pet_name.dart';
import 'package:finni/domain/services/plan_service.dart';
import 'package:finni/domain/services/shop_service.dart';
import 'package:finni/domain/services/task_engine.dart';
import 'package:finni/ui/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/answers.dart';
import 'support/content.dart';

final class _Clock implements GameClock {
  _Clock(this.at);

  DateTime at;

  @override
  DateTime now() => at;

  @override
  int cooldownMs(String key) => 0;

  @override
  bool isNewCalendarDay(DateTime last) => DateTime(at.year, at.month, at.day)
      .isAfter(DateTime(last.year, last.month, last.day));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> config;
  late ContentBundle content;

  setUpAll(() async {
    content = await loadTestContent();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    config = jsonDecode(File('assets/content/game.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  GameController fresh([_Clock? clock]) => GameController(config,
      content: content, clock: clock ?? _Clock(DateTime(2026, 9, 28, 10)));

  void playLevel(GameController state) {
    state.startLevel();
    while (state.levelRun != null) {
      final session = state.startLevelGame();
      session.submit(rightAnswer(session.variant));
      state.finishLevelGame(session);
    }
  }

  void nextDay(GameController state) {
    expect(state.closeDay(state.day), isTrue);
    state.acknowledgeCelebration();
  }

  group('имя питомца', () {
    test('готовые имена подходят', () {
      for (final name in config['names'] as List) {
        expect(petNameProblem('$name'), isNull, reason: '$name');
      }
    });

    test('своё имя: пробелы убираются, длина и символы проверяются', () {
      expect(normalizePetName('  Рыжик   Второй '), 'Рыжик Второй');
      expect(petNameProblem(''), isNotNull);
      expect(petNameProblem('   '), isNotNull);
      expect(petNameProblem('Очень длинное имя'), isNotNull);
      expect(petNameProblem('Кот!'), isNotNull);
      expect(petNameProblem('123'), isNotNull);
      expect(petNameProblem('Рыжик'), isNull);
      expect(petNameProblem('Tom 2'), isNull);
    });

    test('грубые слова не пройдут даже латиницей и через дефис', () {
      for (final bad in ['Дурак', 'су-ка', 'Жопа', 'CYKA', 'Fuck', 'Глупыш']) {
        expect(petNameProblem(bad), isNotNull, reason: bad);
      }
    });

    test('контроллер принимает своё имя и не принимает плохое', () {
      final state = fresh();
      state.createPet('Рыжик', true);
      expect(state.petName, 'Рыжик');
      state.renamePet('  Бублик ');
      expect(state.petName, 'Бублик');
      expect(() => state.renamePet('Дурак'), throwsArgumentError);
      expect(state.petName, 'Бублик');
    });
  });

  test('заработанное за день раскладывается по плану и попадает в итоги',
      () async {
    final state = fresh();
    expect(state.earnedToday, 0);
    playLevel(state);
    final earned = state.earnedToday;
    expect(earned, state.todayLevel!.coins);
    expect(state.extraPending, earned);
    expect(state.planEarned({PlanDirection.savings: earned + 1}), isFalse);
    expect(
        state.planEarned({
          PlanDirection.savings: earned - 1,
          PlanDirection.optional: 1,
        }),
        isTrue);
    expect(state.extraPending, 0);
    expect(state.fullPlan.savings, state.plan.plan.savings + earned - 1);
    expect(state.fullPlan.income, state.plan.plan.income + earned);
    expect(state.planFactRows.last.$2, state.fullPlan.savings);
    await state.flush();
    final restored = GameController(config,
        content: content, saved: await state.repository.load());
    expect(restored.planExtra[PlanDirection.savings], earned - 1);
    nextDay(restored);
    expect(restored.extraPlanned, 0);
  });

  test('итоги дня сохраняются в дневнике', () async {
    final state = fresh();
    for (var i = 0; i < 5; i++) {
      state.changePlan(PlanDirection.mandatory, 5);
    }
    state.confirmPlan();
    expect(state.buyNow('food'), isA<PurchaseDone>());
    nextDay(state);
    expect(state.dayHistory, hasLength(1));
    final entry = state.dayHistory.single;
    expect(entry['day'], 1);
    expect((entry['rows'] as List).first, ['Обязательное', 25, 15]);
    expect('${entry['explain']}', isNotEmpty);
    await state.flush();
    final restored = GameController(config,
        content: content, saved: await state.repository.load());
    expect(restored.dayHistory.single['day'], 1);
  });

  test('у игры считается, сколько вариантов пройдено, и даётся следующий', () {
    final state = fresh();
    final task = content.tasks.byId('planning_choice_enough')!;
    expect(state.passedOf(task), 0);
    final first = state.startGame(task.id);
    expect(first.index, 0);
    first.submit(const ChoiceAnswer('no'));
    state.finishGame(first);
    expect(state.passedOf(task), 0);
    final second = state.startGame(task.id);
    expect(second.index, 0);
    second.submit(rightAnswer(second.variant));
    state.finishGame(second);
    expect(state.passedOf(task), 1);
    final third = state.startGame(task.id);
    expect(third.index, 1);
    third.submit(rightAnswer(third.variant));
    state.finishGame(third);
    expect(state.passedOf(task), 2);
    expect(task.variantCount, greaterThan(2));
  });

  test('каждый день начинается с плана', () {
    final state = fresh();
    expect(state.needsPlan, isTrue);
    state.confirmPlan();
    expect(state.needsPlan, isFalse);
    nextDay(state);
    expect(state.needsPlan, isTrue);
  });

  test('после покупки видно, как изменились шкалы', () {
    final state = fresh();
    final before = state.stats.satiety;
    expect(state.buyNow('food'), isA<PurchaseDone>());
    final shift = state.lastShifts.firstWhere((s) => s.stat == PetStat.satiety);
    expect(shift.before, before);
    expect(shift.after, state.stats.satiety);
    expect(shift.delta, greaterThan(0));
  });

  test('«Спокойной ночи» появляется, когда все дела сделаны', () {
    final clock = _Clock(DateTime(2026, 9, 28, 10));
    final state = fresh(clock);
    expect(state.bedtimeReady, isFalse);
    expect(state.bedtimeTodos,
        containsAll([BedtimeTodo.plan, BedtimeTodo.needs, BedtimeTodo.task]));
    expect(state.bedtimeReminder, isNotNull);
    for (var i = 0; i < 5; i++) {
      state.changePlan(PlanDirection.mandatory, 5);
    }
    state.confirmPlan();
    for (final need in content.economy.pet.needs) {
      expect(state.buyNow(need.itemId), isA<PurchaseDone>());
    }
    expect(state.bedtimeReminder, isNull);
    playLevel(state);
    expect(state.bedtimeTodos, contains(BedtimeTodo.plan));
    state.planEarned({PlanDirection.savings: state.extraPending});
    expect(state.bedtimeTodos, [BedtimeTodo.task]);
    state.startDaily();
    final daily = state.startDailyGame();
    daily.submit(rightAnswer(daily.variant));
    state.finishDaily(daily);
    state.planEarned({PlanDirection.savings: state.extraPending});
    expect(state.bedtimeReady, isTrue);
    expect(state.bedtimeHint, content.economy.bedtime.ready);
  });

  test('события приходят по расписанию и решаются один раз', () async {
    final state = fresh();
    expect(state.todayEvent, isNull);
    nextDay(state);
    expect(state.todayEvent, isNull);
    nextDay(state);
    expect(state.day, 3);
    final event = state.todayEvent!;
    expect(state.eventPending, isTrue);
    expect(state.bedtimeTodos, contains(BedtimeTodo.event));
    final free = event.options.firstWhere((o) => o.isFree);
    final outcome = state.resolveEvent(free.id);
    expect(outcome, isA<EventResolved>());
    expect((outcome as EventResolved).text, isNot(contains('{')));
    expect(state.eventPending, isFalse);
    expect(state.resolveEvent(free.id), isNull);
    expect(state.bedtimeTodos, isNot(contains(BedtimeTodo.event)));
    await state.flush();
    final restored = GameController(config,
        content: content, saved: await state.repository.load());
    expect(restored.eventPending, isFalse);
    nextDay(restored);
    expect(restored.todayEvent, isNull);
    nextDay(restored);
    expect(restored.day, 5);
    expect(restored.todayEvent, isNotNull);
    expect(restored.todayEvent!.id, isNot(event.id));
    expect(restored.dayHistory.map((e) => e['event']), contains(event.title));
  });

  test('долг возвращают утром, и об этом приходит новость', () async {
    final state = fresh();
    nextDay(state);
    nextDay(state);
    final event = state.todayEvent!;
    expect(event.id, 'debt');
    expect(event.style, EventStyle.book);
    expect(event.show.pages, isNotEmpty);
    final before = state.wallet.wallet.balance;
    final outcome = state.resolveEvent('lend');
    expect(outcome, isA<EventResolved>());
    expect(state.wallet.wallet.balance, before - 10);
    expect(state.paybacks, hasLength(1));
    await state.flush();
    final restored = GameController(config,
        content: content, saved: await state.repository.load());
    expect(restored.paybacks, hasLength(1));
    nextDay(restored);
    expect(restored.paybacks, isEmpty);
    expect(restored.news.single, contains('Мишка вернул долг'));
    expect(restored.news.single, contains('10 монет'));
    final back = restored.wallet.journal
        .where((t) => t.sourceId == 'payback:debt')
        .toList();
    expect(back.single.amount, 10);
    expect(back.single.dayNumber, 4);
    restored.clearNews();
    expect(restored.news, isEmpty);
  });

  test('осторожный ответ в событии приближает звание «Осторожный»', () async {
    final state = fresh();
    while (state.day < 8) {
      nextDay(state);
    }
    expect(state.todayEvent!.id, 'bank_code');
    expect(state.carefulCount, 0);
    expect(state.resolveEvent('adult'), isA<EventResolved>());
    expect(state.carefulCount, 1);
    await state.flush();
    final restored = GameController(config,
        content: content, saved: await state.repository.load());
    expect(restored.carefulCount, 1);
    final careful = [
      for (final event in content.events.events)
        for (final option in event.options)
          if (option.careful) '${event.id}/${option.id}'
    ];
    expect(careful, containsAll(['bank_code/adult', 'prize/close', 'safe_secrets/great']));
    expect(careful, isNot(contains('bank_code/tell')));
  });

  test('события: копилка, счёт карточек и подстановки из контента', () {
    final state = fresh();
    final umbrella = content.events.byId('umbrella')!;
    final savings = umbrella.options.firstWhere((o) => o.fromSavings);
    expect(savings.cost, 15);
    expect(state.eventLine('{pet}: 15 {coin}'), '${state.petName}: 15 монет');
    final swipe = content.events.byId('safe_secrets')!;
    expect(swipe.optionForScore(swipe.show.cards.length).id, 'great');
    expect(swipe.optionForScore(0).id, 'ok');
  });
}
