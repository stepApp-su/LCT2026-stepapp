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

  void planDay(GameController state, int mandatory, int optional, int savings) {
    for (final (d, v) in [
      (PlanDirection.mandatory, mandatory),
      (PlanDirection.optional, optional),
      (PlanDirection.savings, savings),
    ]) {
      for (var i = 0; i < v ~/ 5; i++) {
        state.changePlan(d, 5);
      }
    }
    state.confirmPlan();
  }

  test('заработанное падает в кармашек и не меняет утренний план', () async {
    final state = fresh();
    planDay(state, 25, 10, 5);
    for (final need in content.economy.pet.needs) {
      expect(state.buyNow(need.itemId), isA<PurchaseDone>());
    }
    expect(state.saveByPlan(), isTrue);
    expect(state.earnedToday, 0);
    expect(state.pocket, 0);
    playLevel(state);
    final earned = state.earnedToday;
    expect(earned, state.todayLevel!.coins);
    expect(state.pocket, earned);
    expect(state.plan.plan.income, 40);
    expect(state.freeBalance, state.wallet.wallet.balance - earned);
    expect(state.bedtimeTodos, isNot(contains(BedtimeTodo.plan)));

    final ball = content.shop.byId('bouncy_ball')!;
    expect(ball.price, greaterThan(state.freeBalance));
    final refused = state.askToBuy(ball.id);
    expect(refused, isA<PurchaseRefused>());
    expect((refused as PurchaseRefused).textRu, state.pocketRefusal);
    expect(state.pocket, earned);

    expect(state.savePocket(), isTrue);
    expect(state.pocket, 0);
    expect(state.planFactRows.last.$3, 5);
    expect(state.dayFacts.deposited, 5);
    await state.flush();
    final restored = GameController(config,
        content: content, saved: await state.repository.load());
    expect(restored.pocketSaved, earned);
    expect(restored.pocket, 0);
    final left = restored.wallet.wallet.balance;
    expect(restored.closeDay(restored.day), isTrue);
    final pocket = (restored.celebration!['pocket'] as Map).cast<String, Object?>();
    expect(pocket, {'earned': earned, 'saved': earned, 'needs': 0, 'carry': 0});
    restored.acknowledgeCelebration();
    expect(restored.carried, left);
    expect(restored.plan.plan.income, 40 + left);
    expect(restored.pocketSaved, 0);
  });

  test('голодным лёг спать — ночью не растёт и просыпается грустнее', () {
    final state = fresh();
    planDay(state, 25, 10, 5);
    for (final need in content.economy.pet.needs) {
      expect(state.buyNow(need.itemId), isA<PurchaseDone>());
    }
    expect(state.saveByPlan(), isTrue);
    expect(state.veryHungry, isFalse);
    state.stats = PetState.create(satiety: 20, care: 80, mood: 80, cozy: 10);
    expect(state.veryHungry, isTrue);
    expect(state.hungerText, isNotEmpty);
    final before = state.progress.growthPoints;
    expect(state.closeDay(state.day), isTrue);
    expect(state.celebration!['points'], 0);
    expect(state.progress.growthPoints, before);
    expect('${state.celebration!['hungry']}', contains(state.petName));
    expect(state.stats.mood, lessThan(75));
  });

  test('сытый питомец растёт как обычно', () {
    final state = fresh();
    planDay(state, 25, 10, 5);
    for (final need in content.economy.pet.needs) {
      expect(state.buyNow(need.itemId), isA<PurchaseDone>());
    }
    expect(state.saveByPlan(), isTrue);
    expect(state.veryHungry, isFalse);
    expect(state.closeDay(state.day), isTrue);
    expect(state.celebration!['points'] as int, greaterThan(0));
    expect(state.celebration!.containsKey('hungry'), isFalse);
  });

  test('план нового дня — это все монеты в кошельке, вместе с кармашком',
      () async {
    final state = fresh();
    planDay(state, 25, 10, 5);
    playLevel(state);
    final earned = state.earnedToday;
    expect(earned, greaterThan(0));
    final left = state.wallet.wallet.balance;
    expect(left, 40 + earned);
    nextDay(state);
    expect(state.carried, left);
    expect(state.plan.plan.income, 40 + left);
    expect(state.plan.plan.income, state.wallet.wallet.balance);
    expect(state.pocket, 0);
    expect(state.earnedToday, 0);
    await state.flush();
    final restored = GameController(config,
        content: content, saved: await state.repository.load());
    expect(restored.plan.plan.income, 40 + left);
    expect(restored.carried, left);
  });

  test('на нужное кармашек доплачивает, и план остаётся честным', () {
    final state = fresh();
    planDay(state, 10, 25, 5);
    playLevel(state);
    final earned = state.earnedToday;
    final food = content.shop.byId('food')!;
    final gap = food.price - 10;
    expect(state.pocketForNeed(food), gap < earned ? gap : earned);
    final fromPocket = state.pocketForNeed(food);
    expect(state.buyNow(food.id), isA<PurchaseDone>());
    expect(state.pocketNeeds, fromPocket);
    expect(state.pocket, earned - fromPocket);
    expect(state.planFactRows.first.$3, food.price - fromPocket);
    expect(state.dayFacts.spentMandatory, food.price - fromPocket);
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

  test('на уровнях вариант игры не повторяется подряд', () {
    final state = fresh();
    for (final task in content.tasks.tasks) {
      for (final level in TaskDifficulty.values) {
        final count = task.variantsIn(TaskPool.level, level).length;
        expect(count, greaterThanOrEqualTo(3), reason: task.id);
        int? last;
        for (var i = 0; i < count * 2; i++) {
          final at = state.nextIndex(task, level, TaskPool.level);
          expect(at, isNot(last), reason: '${task.id}/${level.name}/$i');
          final session =
              state.tasks.start(task.id, level, index: at, pool: TaskPool.level);
          session.submit(rightAnswer(session.variant));
          state.finishGame(session);
          last = at;
        }
      }
    }
  });

  test('примерка показывает вещь, но ничего не покупает и не сохраняет', () {
    final state = fresh();
    final wallpaper = content.shop.items.firstWhere(
        (i) => i.kind == ShopItemKind.wallpaper && i.price > 0);
    final before = state.wallpaperId;
    final balance = state.wallet.wallet.balance;
    state.tryOn(wallpaper);
    expect(state.wallpaperId, wallpaper.id);
    expect(state.snapshot()['wallpaper'], isNot(wallpaper.id));
    state.tryOn(null);
    expect(state.wallpaperId, before);
    final bow = content.shop.byId('bow')!;
    state.tryOn(bow);
    expect(state.wornOutfit[bow.slot], bow.id);
    expect(state.outfit.containsKey(bow.slot), isFalse);
    state.tryOn(null);
    expect(state.wornOutfit, state.outfit);
    expect(state.wallet.wallet.balance, balance);
    expect(state.owned, isNot(contains(bow.id)));
  });

  TaskAnswer wrongSort(TaskVariant variant) {
    final payload = variant.payload as SortPayload;
    return SortAnswer({
      for (final card in payload.cards)
        card.id: payload.bins.firstWhere((bin) => bin != card.bin),
    });
  }

  test('звезда = монета, отложенная игра ждёт, улучшение доплачивает разницу',
      () {
    final state = fresh();
    planDay(state, 25, 10, 5);
    final run = state.startLevel()!;
    expect(run.slots.first.taskId, 'payments_sort_needs');
    final before = state.earnedToday;

    final first = state.startLevelGame();
    first.submit(wrongSort(first.variant));
    final skipped = state.finishLevelGame(first);
    expect(skipped.reward.coins, 0);
    expect(skipped.reward.stars, 0);
    expect(state.earnedToday, before);
    expect(state.levelRun!.isWaiting(0), isTrue);
    expect(state.levelRun!.currentIndex, 1);
    expect(state.tasks.isCompleted(first.task.id), isFalse);

    while (state.levelRun!.currentIndex != 0) {
      final session = state.startLevelGame();
      session.submit(rightAnswer(session.variant));
      expect(state.finishLevelGame(session).reward.stars, 3);
    }
    final again = state.startLevelGame();
    expect(again.task.id, first.task.id);
    expect(again.index, isNot(first.index));
    again.submit(wrongSort(again.variant));
    again.submit(rightAnswer(again.variant));
    final step = state.finishLevelGame(again);
    expect(step.reward.stars, 2);
    expect(step.reward.coins, run.payFor(0, 2));
    final record = step.finished!;
    expect(record.coins, run.coins - run.payFor(0, 3) + run.payFor(0, 2));
    expect(state.earnedToday - before, record.coins);

    expect(state.canImprove(0), isTrue);
    final better = state.startImprove(0);
    better.submit(rightAnswer(better.variant));
    final gain = state.finishImprove(0, better);
    expect(gain.coins, run.payFor(0, 3) - run.payFor(0, 2));
    expect(state.todayLevel!.stars.first, 3);
    expect(state.todayLevel!.coins, run.coins);
    expect(state.canImprove(0), isFalse);
    expect(state.earnedToday - before, run.coins);
  });

  test('задание дня: чем точнее, тем больше монет, сдался — ноль', () {
    final rules = content.levels.daily;
    expect(rules.forStars(3), 12);
    expect(rules.forStars(2), 8);
    expect(rules.forStars(1), 5);
    expect(rules.forStars(0), 0);
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
    expect(state.bedtimeTodos, [BedtimeTodo.task]);
    state.startDaily();
    final daily = state.startDailyGame();
    daily.submit(rightAnswer(daily.variant));
    state.finishDaily(daily);
    expect(state.pocket, greaterThan(0));
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

  test('демо-режим открывает все игры, товары и мечты и сохраняется', () async {
    final state = fresh();
    bool allGames(GameController s) =>
        content.tasks.tasks.every((t) => s.isGameUnlocked(t.id));
    final shelf = content.shop.items.where((i) => i.showInShop).length;
    expect(allGames(state), isFalse);
    expect(state.catalog.length, lessThan(shelf));
    state.setDemo(true);
    expect(allGames(state), isTrue);
    expect(state.nextUnlock, isNull);
    expect(state.catalog.length, shelf);
    expect(state.content.shop.items.where(state.itemLocked), isEmpty);
    expect(state.goals.available().length, content.goals.goals.length);
    expect(state.dailyTask, isNotNull);
    await state.flush();
    final restored = GameController(config,
        content: content, saved: await state.repository.load());
    expect(restored.demoMode, isTrue);
    expect(allGames(restored), isTrue);
    expect(restored.catalog.length, shelf);
    restored.setDemo(false);
    expect(allGames(restored), isFalse);
    expect(restored.catalog.length, lessThan(shelf));
  });
}
