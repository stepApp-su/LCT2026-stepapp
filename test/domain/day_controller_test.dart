import 'dart:convert';
import 'dart:math';

import 'package:finni/content/content_repository.dart';
import 'package:finni/domain/game_clock.dart';
import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/profile_codec.dart';
import 'package:finni/domain/services/day_controller.dart';
import 'package:finni/domain/services/day_events.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/content.dart';
import '../support/day.dart';

late ContentBundle _content;

final _plan =
    BudgetPlan.create(mandatory: 25, optional: 10, savings: 5, income: 40);
const _needs = ['food', 'water_light', 'cleaning'];
const _sensibleBuy = [..._needs, 'treat', 'treat'];

({
  DayController controller,
  MemoryProfileRepository repository,
  DemoClock clock
}) _setup({DateTime? start}) {
  final repository = MemoryProfileRepository();
  final clock = DemoClock(start: start ?? DateTime(2026, 9, 25, 9));
  return (
    controller: dayController(_content, repository: repository, clock: clock),
    repository: repository,
    clock: clock,
  );
}

Future<Profile> _start(DayController controller) =>
    controller.startGame(petName: 'Мони', species: 'fox', palette: 0);

Future<Night> _sleep(DayController controller, Profile profile) async =>
    await controller.goToSleep(profile, day: profile.currentDay.number)
        as Night;

List<String> get _payments =>
    [for (final task in _content.tasks.byTheme('payments')) task.id];

List<String> _sensibleBuyFor(Profile profile) {
  final extra = [
    for (final need in _content.economy.pet
        .needsOn(profile.currentDay.number, profile.progress.stage))
      if (need.occasion != null) need.itemId
  ];
  if (extra.isEmpty) return _sensibleBuy;
  return ['porridge', 'water_light', 'cleaning', ...extra, 'treat', 'treat'];
}

Profile _sensibleDay(Profile profile, DemoClock clock, int index) => liveDay(
      profile,
      _content,
      at: clock.now(),
      plan: _plan,
      buy: _sensibleBuyFor(profile),
      deposit: 5,
      task: _payments[index % _payments.length],
    );

String _encoded(Profile profile) => ProfileCodec.encode(profile);

void main() {
  setUpAll(() async => _content = await loadTestContent());

  group('начало игры', () {
    test('первый день: доход с объяснением, Новичок, стартовое состояние',
        () async {
      final s = _setup();
      final profile = await s.controller.startGame(
          petName: 'Пикс', species: 'robot', palette: 3, simpleMode: false);
      final saved = await s.repository.loadProfile();
      expect(saved.petName, 'Пикс');
      expect(saved.species, 'robot');
      expect(saved.palette, 3);
      expect(saved.simpleMode, isFalse);
      final income = _content.economy.params.day;

      expect(profile.currentDay.number, 1);
      expect(profile.wallet, Wallet.create(balance: income.income, savings: 0));
      final tx = profile.currentDay.transactions.single;
      expect(tx.type, TransactionType.income);
      expect(tx.sourceId, DayController.incomeSource);
      expect(tx.amount, income.income);
      expect(tx.reasonText, income.incomeReason);
      expect(tx.dayNumber, 1);
      expect(tx.at, s.clock.now());
      expect(profile.currentDay.plan, BudgetPlan.empty(income.income));
      expect(profile.currentDay.planConfirmed, isFalse);
      expect(profile.currentDay.event, isNull);
      expect(profile.state, _content.economy.pet.initialState);
      expect(profile.progress.earnedTitles, ['novice']);
      expect(profile.progress.currentTitleId, 'novice');
      expect(profile.journal, isEmpty);
      expect(s.repository.stored, _encoded(profile));
    });
  });

  group('можно ли укладывать спать', () {
    test('свежий день: план, нужное и задание, напоминание про всё нужное',
        () async {
      final s = _setup();
      final bedtime = s.controller.checkBedtime(await _start(s.controller));
      final texts = _content.economy.bedtime;

      expect(bedtime.day, 1);
      expect(bedtime.ready, isFalse);
      expect(bedtime.todos,
          [BedtimeTodo.plan, BedtimeTodo.needs, BedtimeTodo.task]);
      expect(bedtime.hint, texts.todos[BedtimeTodo.plan]);
      final reminder = bedtime.reminder!;
      expect([for (final item in reminder.unpaid) item.id], _needs);
      expect(
          reminder.text,
          'Не купили еду на день, воду и свет, мытьё и уборку. '
          'Уложим спать так или сходим в магазин?');
      expect(reminder.goShopping, texts.goShopping);
      expect(reminder.sleepAnyway, texts.sleepAnyway);
    });

    test('подсказка называет то, что осталось купить', () async {
      final s = _setup();
      final profile = liveDay(await _start(s.controller), _content,
          at: s.clock.now(), plan: _plan, buy: ['food']);
      final bedtime = s.controller.checkBedtime(profile);
      expect(bedtime.todos, [BedtimeTodo.needs, BedtimeTodo.task]);
      expect(bedtime.hint, 'Ещё не купили воду и свет, мытьё и уборку.');
      expect([for (final item in bedtime.reminder!.unpaid) item.id],
          ['water_light', 'cleaning']);
    });

    test('всё сделано — можно спать, без напоминания', () async {
      final s = _setup();
      final bedtime = s.controller
          .checkBedtime(_sensibleDay(await _start(s.controller), s.clock, 0));
      expect(bedtime.ready, isTrue);
      expect(bedtime.todos, isEmpty);
      expect(bedtime.hint, _content.economy.bedtime.ready);
      expect(bedtime.reminder, isNull);
    });

    test('нужное не по карману — это уже не дело на сегодня, но напомним',
        () async {
      final s = _setup();
      final profile = liveDay(await _start(s.controller), _content,
          at: s.clock.now(),
          plan: _plan,
          buy: ['pouf'],
          task: 'x',
          taskReward: 4);
      expect(profile.wallet.balance, 4);
      final bedtime = s.controller.checkBedtime(profile);
      expect(bedtime.todos, isEmpty);
      expect(bedtime.ready, isTrue);
      expect(bedtime.reminder!.unpaid, hasLength(3));
      expect(bedtime.reminder!.canShop, isFalse);
      expect(
          bedtime.reminder!.text,
          'На еду на день, воду и свет, мытьё и уборку '
          'сегодня не хватило монет. Завтра купим!');

      final five = liveDay(await _start(s.controller), _content,
          at: s.clock.now(),
          plan: _plan,
          buy: ['pouf'],
          task: 'x',
          taskReward: 5);
      final enough = s.controller.checkBedtime(five);
      expect(enough.todos, [BedtimeTodo.needs]);
      expect(enough.hint, 'Ещё не купили воду и свет, мытьё и уборку.');
      expect(enough.reminder!.canShop, isTrue);
      expect(enough.reminder!.text,
          startsWith('Не купили еду на день, воду и свет, мытьё и уборку.'));
    });

    test('нерешённое событие — повод заглянуть, решённое — нет', () async {
      final s = _setup();
      final done = _sensibleDay(await _start(s.controller), s.clock, 0);
      DayEvent event({required bool resolved}) => DayEvent.create(
          id: 'rain', title: 'Дождь', cost: 0, resolved: resolved);
      expect(
          s.controller
              .checkBedtime(done.copyWith(
                  currentDay:
                      done.currentDay.copyWith(event: event(resolved: false))))
              .todos,
          [BedtimeTodo.event]);
      expect(
          s.controller
              .checkBedtime(done.copyWith(
                  currentDay:
                      done.currentDay.copyWith(event: event(resolved: true))))
              .ready,
          isTrue);
    });
  });

  group('уложить спать', () {
    test('без покупок можно: ночью шкалы снижаются с причинами', () async {
      final s = _setup();
      final night = await _sleep(s.controller, await _start(s.controller));
      final reasons = {for (final c in night.nightChanges) c.reasonText};
      final needs = _content.economy.pet.needs;

      expect(night.profile.currentDay.number, 2);
      expect(
          reasons, containsAll([for (final need in needs) need.missedReason]));
      expect(night.profile.state.satiety, PetState.satietyFloor);
      expect(night.profile.state.care, PetState.careFloor);
      for (final change in night.dayChanges) {
        expect(change.reasonText.trim(), isNotEmpty);
        expect(s.controller.describe(change), isNotEmpty);
      }
      expect(night.summary.explainText, _content.summaries.explain['emptyDay']);
      expect(night.growth.day.points, 0);
    });

    test('ночь закрывает день и сразу начинает новый — одним сохранением',
        () async {
      final s = _setup();
      final day1 = _sensibleDay(await _start(s.controller), s.clock, 0);
      s.clock.advanceDay();
      final night = await _sleep(s.controller, day1);
      final next = night.profile;

      expect(s.repository.saves, 2);
      expect(s.repository.stored, _encoded(next));
      expect(night.closedDay.number, 1);
      expect(night.closedDay.isClosed, isTrue);
      expect(night.closedDay.plan, _plan);
      expect(night.closedDay.planConfirmed, isTrue);
      expect(night.closedDay.transactions,
          day1.allTransactions.where((t) => t.dayNumber == 1));
      expect(next.journal, day1.allTransactions);
      expect(next.currentDay.number, 2);
      expect(next.currentDay.transactions, [night.income]);
      expect(night.income.dayNumber, 2);
      expect(night.income.at, s.clock.now());
      expect(next.currentDay.plan, BudgetPlan.empty(40));
      expect(next.currentDay.planConfirmed, isFalse);
      expect(next.wallet.balance, day1.wallet.balance + 40);
      expect(next.wallet.savings, day1.wallet.savings);
      expect(next.petActionsToday, isEmpty);
      expect(next.petChangesToday, isEmpty);
      expect(next.history.single, night.summary.summary);
      final bought = {
        for (final id in _sensibleBuy) _content.shop.byId(id)!.diaryText
      };
      expect(night.nightChanges.map((c) => c.reasonText),
          everyElement(isNot(isIn(bought))));
      expect(
          night.nightChanges.map((c) => c.reasonText),
          everyElement(isNot(isIn([
            for (final need in _content.economy.pet.needs) need.missedReason
          ]))));
      expect(
          night.dayChanges, [...day1.petChangesToday, ...night.nightChanges]);
      final morning = _content.economy.pet.initialState;
      expect(night.summary.stateChanges, {
        for (final stat in PetStat.values)
          if (next.state.of(stat) != morning.of(stat))
            stat: next.state.of(stat) - morning.of(stat)
      });
      expect(
          night.summary.summary,
          DaySummary.create(
              dayNumber: 1,
              plannedMandatory: 25,
              plannedOptional: 10,
              plannedSavings: 5,
              actualMandatory: 25,
              actualOptional: 10,
              actualSavings: 5,
              growthPoints: 7));
      expect(
          night.summary.explainText,
          'Ты потратил ровно столько, сколько планировал. '
          'Так держать — до мечты уже 5 монеток!');
      expect([for (final line in night.growthLines) line.met],
          [true, true, true, true]);
      expect(night.growthStatus.stageLabel, 'Малыш');
      expect(night.stageUpTitle, 'Мони подрастает: теперь «Малыш»!');
    });

    test('повторное нажатие не закрывает день дважды', () async {
      final s = _setup();
      final day1 = await _start(s.controller);
      final night = await _sleep(s.controller, day1);

      final again = await s.controller.goToSleep(night.profile, day: 1);
      expect(again, isA<DayAlreadyClosed>());
      expect((again as DayAlreadyClosed).profile, same(night.profile));
      expect(s.repository.saves, 2);
      expect(s.repository.stored, _encoded(night.profile));
      expect(() => s.controller.goToSleep(night.profile, day: 3),
          throwsArgumentError);
      expect(s.repository.saves, 2);
    });

    test('двойное нажатие во время сохранения даёт ту же ночь', () async {
      final s = _setup();
      final day1 = await _start(s.controller);
      final first = s.controller.goToSleep(day1, day: 1);
      final second = s.controller.goToSleep(day1, day: 1);
      expect(identical(await first, await second), isTrue);
      expect(s.repository.saves, 2);
    });

    test('второй день считается сам по себе: вчерашние покупки не в счёт',
        () async {
      final s = _setup();
      final first = await _sleep(
          s.controller, _sensibleDay(await _start(s.controller), s.clock, 0));
      final day2 =
          liveDay(first.profile, _content, at: s.clock.now(), plan: _plan);
      final bedtime = s.controller.checkBedtime(day2);
      expect(bedtime.todos, [BedtimeTodo.needs, BedtimeTodo.task]);
      expect([for (final item in bedtime.reminder!.unpaid) item.id], _needs);

      final second = await _sleep(s.controller, day2);
      expect(second.closedDay.transactions,
          day2.allTransactions.where((t) => t.dayNumber == 2));
      expect(
          {for (final c in second.nightChanges) c.reasonText},
          containsAll([
            for (final need in _content.economy.pet.needs) need.missedReason
          ]));
      expect(second.profile.state.satiety, first.profile.state.satiety - 50);
      expect(second.profile.state.care, first.profile.state.care - 45);
    });

    test('итоги второго дня считают изменения от утра этого дня', () async {
      final s = _setup();
      final night1 = await _sleep(s.controller, await _start(s.controller));
      final morning = night1.profile.state;
      expect(morning, isNot(_content.economy.pet.initialState));
      final night2 = await _sleep(s.controller,
          liveDay(night1.profile, _content, at: s.clock.now(), buy: ['food']));
      final evening = night2.profile.state;
      expect(night2.summary.stateChanges, {
        for (final stat in PetStat.values)
          if (evening.of(stat) != morning.of(stat))
            stat: evening.of(stat) - morning.of(stat)
      });
      expect(night2.summary.stateChanges[PetStat.satiety], 5);
    });

    test('ночь не трогает цель, вещи, наряды и настройки', () async {
      final s = _setup();
      final started = await _start(s.controller);
      final before = started.copyWith(
        goalId: 'scooter',
        goals: [
          Goal.create(id: 'scooter', title: 'Самокат', price: 120, saved: 0)
        ],
        ownedItems: ['bouncy_ball', 'cap'],
        equipped: {'head': 'cap', 'neck': null},
        wishlist: ['glasses'],
        reachedGoalIds: ['constructor'],
        activeWallpaperId: 'wp_dots',
        settings: const ProfileSettings(sound: false, motion: true),
        completedTasks: ['payments_sort_needs'],
      );
      final night = await _sleep(s.controller, before);
      for (final after in [night.profile, await s.repository.loadProfile()]) {
        expect(after.goalId, before.goalId);
        expect(after.goals.map((g) => g.toJson()),
            before.goals.map((g) => g.toJson()));
        expect(after.ownedItems, before.ownedItems);
        expect(after.equipped, before.equipped);
        expect(after.wishlist, before.wishlist);
        expect(after.reachedGoalIds, before.reachedGoalIds);
        expect(after.activeWallpaperId, before.activeWallpaperId);
        expect(after.settings, before.settings);
        expect(after.completedTasks, before.completedTasks);
        expect(after.petName, before.petName);
      }
    });

    test('объяснение дня: заработок за задание, нехватка на нужное, без плана',
        () async {
      final s = _setup();
      final start = await _start(s.controller);
      Future<String> explain(Profile lived) async =>
          (await _sleep(s.controller, lived)).summary.explainText;

      expect(
          await explain(liveDay(start, _content,
              at: s.clock.now(),
              plan: _plan,
              buy: [..._needs, 'treat'],
              deposit: 5,
              task: 'x')),
          'День прошёл! Ты заработал 10 и потратил 30 монеток. '
          'Завтра будет новый план.');
      expect(
          await explain(liveDay(start, _content,
              at: s.clock.now(), plan: _plan, deposit: 25)),
          'На нужное сегодня не хватило 25 монеток, и Мони остался без покупки. '
          'Завтра можно сначала отложить на нужное.');
      expect(
          await explain(liveDay(start, _content,
              at: s.clock.now(), buy: ['treat'], task: 'x')),
          'Сегодня плана не было: потратили 5, отложили 0 монеток. '
          'Завтра начнём с плана!');
    });

    test('сбой сохранения ничего не портит, повтор проходит один раз',
        () async {
      final s = _setup();
      final day1 = _sensibleDay(await _start(s.controller), s.clock, 0);
      final before = _encoded(day1);
      final stored = s.repository.stored;

      s.repository.failNextSave = true;
      await expectLater(_sleep(s.controller, day1), throwsStateError);
      expect(_encoded(day1), before);
      expect(s.repository.stored, stored);
      final unchanged = await s.repository.loadProfile();
      expect(unchanged.currentDay.number, 1);
      expect(s.controller.checkBedtime(unchanged).day, 1);

      final night = await _sleep(s.controller, day1);
      final saved = await s.repository.loadProfile();
      expect(saved.currentDay.number, 2);
      expect(
          saved.allTransactions
              .where((t) => t.sourceId == DayController.incomeSource),
          hasLength(2));
      expect(_encoded(saved), _encoded(night.profile));
    });
  });

  group('ночь устойчива к неаккуратному профилю', () {
    test('покупка дня, записанная в общий журнал, всё равно засчитана',
        () async {
      final s = _setup();
      final day1 = _sensibleDay(await _start(s.controller), s.clock, 0);
      final misplaced = day1.copyWith(
        journal: day1.allTransactions,
        currentDay: day1.currentDay.copyWith(transactions: const []),
      );
      final night = await _sleep(s.controller, misplaced);
      expect(night.growth.day.points, 7);
      expect(night.nightChanges.map((c) => c.reasonText),
          isNot(contains(_content.economy.pet.needs.first.missedReason)));
      expect(night.profile.journal, day1.allTransactions);
    });

    test('игрушки в комнате радуют каждую ночь', () async {
      final s = _setup();
      final start = await _start(s.controller);
      final night = await _sleep(
          s.controller, start.copyWith(ownedItems: ['bouncy_ball']));
      expect(night.nightChanges.map((c) => c.reasonText),
          contains('Попрыгунчик радует каждый день'));
    });

    test('итоги уже закрытого дня не задваиваются в истории', () async {
      final s = _setup();
      final start = await _start(s.controller);
      final stale = DaySummary.create(
          dayNumber: 1,
          plannedMandatory: 0,
          plannedOptional: 0,
          plannedSavings: 0,
          actualMandatory: 0,
          actualOptional: 0,
          actualSavings: 0,
          growthPoints: 0);
      final night =
          await _sleep(s.controller, start.copyWith(history: [stale]));
      expect(night.profile.history, [stale]);
    });
  });

  group('пять дней подряд', () {
    test('разумный игрок: каждое утро профиль читается из сохранения',
        () async {
      final s = _setup();
      var profile = await _start(s.controller);
      final points = <int>[];
      final stages = <PetStage>[];
      final titles = <List<String>>[];
      final events = <String?>[profile.currentDay.event?.id];

      for (var i = 0; i < 5; i++) {
        profile = await s.repository.loadProfile();
        profile = _sensibleDay(profile, s.clock, i);
        s.clock.advanceDay();
        final night = await _sleep(s.controller, profile);
        points.add(night.profile.progress.growthPoints);
        stages.add(night.profile.progress.stage);
        titles.add([for (final t in night.titles) t.title.id]);
        events.add(night.event?.id);
        expect(night.profile.currentDay.event?.id, night.event?.id);
      }

      expect(points, [7, 14, 21, 28, 35]);
      expect(stages, [
        PetStage.baby,
        PetStage.teen,
        PetStage.teen,
        PetStage.teen,
        PetStage.adult,
      ]);
      expect(titles, [
        <String>[],
        <String>[],
        ['planner'],
        <String>[],
        ['saver'],
      ]);
      expect(events, [null, null, 'debt', null, 'found_coins', null]);

      final last = await s.repository.loadProfile();
      expect(last.currentDay.number, 6);
      expect(last.history.map((h) => h.dayNumber), [1, 2, 3, 4, 5]);
      expect(last.progress.growthDays.map((d) => d.dayNumber), [1, 2, 3, 4, 5]);
      expect(last.wallet.savings, 25);
      expect(last.completedTasks, _payments.take(5));
      expect(_payments.length, greaterThan(5));
      expect(last.progress.earnedTitles, isNot(contains('shopping_expert')));
      expect(last.progress.currentTitleId, 'saver');
    });

    test('пассивный игрок: пять ночей без покупок, шкалы не ниже пола',
        () async {
      final s = _setup();
      var profile = await _start(s.controller);
      final satiety = <int>[];
      final care = <int>[];
      final mood = <int>[];
      final events = <String?>[];
      for (var i = 0; i < 5; i++) {
        expect(
            s.controller.checkBedtime(profile).reminder!.unpaid, hasLength(3));
        final night = await _sleep(s.controller, profile);
        profile = night.profile;
        satiety.add(profile.state.satiety);
        care.add(profile.state.care);
        mood.add(profile.state.mood);
        events.add(night.event?.id);
        expect(
            night.summary.explainText, _content.summaries.explain['emptyDay']);
      }
      expect(satiety, [10, 10, 10, 10, 10]);
      expect(care, [10, 10, 10, 10, 10]);
      expect(mood, [48, 26, 10, 10, 10]);
      expect(profile.progress.stage, PetStage.egg);
      expect(profile.progress.earnedTitles, ['novice']);
      expect(profile.wallet.balance, 240);
      expect(events, [null, 'found_coins', null, null, null]);
    });

    test('одинаковые дни — одинаковое сохранение; часы влияют только на время',
        () async {
      Future<String> play(DateTime start) async {
        final s = _setup(start: start);
        var profile = await _start(s.controller);
        for (var i = 0; i < 5; i++) {
          profile =
              (await _sleep(s.controller, _sensibleDay(profile, s.clock, i)))
                  .profile;
          s.clock.advanceDay();
        }
        return s.repository.stored!;
      }

      final first = await play(DateTime(2026, 9, 25, 9));
      expect(await play(DateTime(2026, 9, 25, 9)), first);
      final later = await play(DateTime(2027, 3, 1, 20));
      expect(later, isNot(first));
      expect(withoutMoments((jsonDecode(later) as Map).cast<String, Object?>()),
          withoutMoments((jsonDecode(first) as Map).cast<String, Object?>()));
    });

    test('случайные дни: прогресс только растёт, деньги сходятся с журналом',
        () async {
      for (var seed = 0; seed < 40; seed++) {
        final random = Random(seed);
        final s = _setup();
        var profile = await _start(s.controller);
        for (var i = 0; i < 8; i++) {
          final shop = [
            for (final item in _content.shop.items)
              if (item.price > 0 && random.nextInt(4) == 0) item.id
          ];
          final buy = <String>[];
          var left = profile.wallet.balance;
          for (final id in shop) {
            final price = _content.shop.byId(id)!.price;
            if (price <= left) {
              buy.add(id);
              left -= price;
            }
          }
          final deposit =
              left > 0 && random.nextBool() ? random.nextInt(left) : 0;
          profile = liveDay(profile, _content,
              at: s.clock.now(),
              plan: random.nextBool() ? _plan : null,
              buy: buy,
              deposit: deposit,
              task: random.nextBool() ? _payments[random.nextInt(5)] : null);
          final before = profile;
          final night = await _sleep(s.controller, before);
          final after = night.profile;
          final reason = 'seed $seed, ночь ${before.currentDay.number}';

          expect(after.currentDay.number, before.currentDay.number + 1,
              reason: reason);
          expect(after.progress.growthPoints,
              greaterThanOrEqualTo(before.progress.growthPoints),
              reason: reason);
          expect(after.progress.stage.index,
              greaterThanOrEqualTo(before.progress.stage.index),
              reason: reason);
          expect(
              after.progress.earnedTitles
                  .take(before.progress.earnedTitles.length),
              before.progress.earnedTitles,
              reason: reason);
          expect(after.state.cozy, greaterThanOrEqualTo(before.state.cozy),
              reason: reason);
          for (final stat in PetStat.values) {
            expect(
                after.state.of(stat), greaterThanOrEqualTo(petStatFloor(stat)),
                reason: reason);
          }
          expect(after.history.length, before.history.length + 1,
              reason: reason);
          expect(after.history.last.dayNumber, before.currentDay.number,
              reason: reason);
          expect(after.progress.growthDays.length,
              before.progress.growthDays.length + 1,
              reason: reason);
          expect(after.journal.map((t) => t.toJson()),
              before.allTransactions.map((t) => t.toJson()),
              reason: reason);
          expect(after.ownedItems, before.ownedItems, reason: reason);
          expect(after.completedTasks, before.completedTasks, reason: reason);

          final all = after.allTransactions;
          expect(all.map((t) => t.id).toSet(), hasLength(all.length),
              reason: reason);
          var balance = 0;
          var savings = 0;
          for (final t in all) {
            switch (t.type) {
              case TransactionType.income:
                balance += t.amount;
              case TransactionType.expense:
                balance -= t.amount;
              case TransactionType.toSavings:
                balance -= t.amount;
                savings += t.amount;
              case TransactionType.fromSavings:
                balance += t.amount;
                savings -= t.amount;
            }
          }
          expect(
              after.wallet, Wallet.create(balance: balance, savings: savings),
              reason: reason);
          expect(
              all.where((t) =>
                  t.sourceId == DayController.incomeSource &&
                  t.dayNumber == after.currentDay.number),
              hasLength(1),
              reason: reason);
          expect(
              await s.repository.loadProfile().then(_encoded), _encoded(after),
              reason: reason);
          profile = after;
        }
      }
    });
  });

  group('тексты укладывания', () {
    Map<String, Object?> json() => bedtimeTextsJson();

    test('читаются из economy.json целиком', () {
      final texts = BedtimeTexts.fromJson(json());
      expect(texts.todos.keys, BedtimeTodo.values);
      expect(texts.ready, json()['ready']);
      expect(texts.reminder, json()['reminder']);
    });

    test('без нужного текста или {items} файл не загружается', () {
      final todos = (json()['todo'] as Map).cast<String, Object?>();
      for (final broken in <Map<String, Object?>>[
        {...json(), 'ready': ' '},
        {...json(), 'reminder': 'Уложим спать?'},
        {...json(), 'goShopping': ''},
        {...json(), 'shortOfMoney': 'Завтра купим!'},
        {...json(), 'sleepAnyway': ''},
        {
          ...json(),
          'todo': {...todos}..remove('event')
        },
        {
          ...json(),
          'todo': {...todos, 'needs': 'Купим нужное.'}
        },
      ]) {
        expect(() => BedtimeTexts.fromJson(broken), throwsArgumentError,
            reason: '$broken');
      }
    });
  });

  group('события дня', () {
    DayEventPicker picker() => DayEventPicker(
        schedule: _content.economy.params.events, catalog: _content.events);

    Map<int, String> picks(PetStage stage, int upTo) => {
          for (var day = 1; day <= upTo; day++)
            if (picker().pick(day, (_) => stage) case final event?)
              day: event.id
        };

    test('только в дни расписания, по очереди из events.json', () {
      expect(picks(PetStage.adult, 25), {
        3: 'debt',
        5: 'found_coins',
        8: 'bank_code',
        10: 'umbrella',
        13: 'safe_secrets',
        15: 'friend_birthday',
        18: 'prize',
        20: 'rain',
        23: 'yard_sale',
        25: 'safe_online',
      });
      expect(picks(PetStage.adult, 25).keys,
          _content.economy.params.events.eventDaysUpTo(25));
    });

    test('событие со сменой цен не выдаётся, пока магазин их не меняет', () {
      final priced =
          _content.events.events.where((e) => e.priceDeltas.isNotEmpty);
      expect(priced, isNotEmpty);
      expect(picks(PetStage.adult, 60).values,
          isNot(contains(anyOf([for (final e in priced) e.id]))));
    });

    test('стадия ограничивает выбор, повтор — не раньше чем через перерыв', () {
      expect(picks(PetStage.egg, 20),
          {3: 'found_coins', 10: 'found_coins', 18: 'found_coins'});
      final rest = _content.events.settings.cooldownDays;
      final byEvent = <String, List<int>>{};
      for (final MapEntry(key: day, value: id)
          in picks(PetStage.baby, 60).entries) {
        byEvent.putIfAbsent(id, () => []).add(day);
      }
      for (final days in byEvent.values) {
        for (var i = 1; i < days.length; i++) {
          expect(days[i] - days[i - 1], greaterThan(rest));
        }
      }
    });

    test('выбор зависит от стадии в каждый событийный день', () {
      PetStage growing(int day) => day < 6 ? PetStage.egg : PetStage.teen;
      expect(picker().pick(3, growing)?.id, 'found_coins');
      expect(picker().pick(5, growing), isNull);
      expect(picker().pick(8, growing)?.id, 'bank_code');
      expect(picker().pick(4, growing), isNull);
    });

    test('перерыв между одинаковыми событиями включает свою границу', () {
      final everyThird = DayEventPicker(
          schedule: EventSchedule.fromJson({
            'firstDay': 1,
            'intervalPattern': [3]
          }),
          catalog: _content.events);
      final rest = _content.events.settings.cooldownDays;
      expect(rest, 6);
      expect({
        for (var day = 1; day <= 13; day++)
          if (everyThird.pick(day, (_) => PetStage.egg) case final e?) day: e.id
      }, {
        1: 'found_coins',
        10: 'found_coins'
      });
    });

    test('событие выбирается по стадии питомца утром того дня', () async {
      Future<Profile> play(List<bool> sensible) async {
        final s = _setup();
        var profile = await _start(s.controller);
        for (final (i, good) in sensible.indexed) {
          final lived = good ? _sensibleDay(profile, s.clock, i) : profile;
          profile = (await _sleep(s.controller, lived)).profile;
        }
        return profile;
      }

      expect((await play([false, true])).currentDay.event?.id, 'debt');
      expect((await play([false, false])).currentDay.event?.id, 'found_coins');
      final grownOnEventDay =
          await play([false, false, true, false, false, false, false]);
      expect(grownOnEventDay.currentDay.number, 8);
      expect(grownOnEventDay.progress.stage, PetStage.baby);
      expect(grownOnEventDay.currentDay.event?.id, 'umbrella');
    });

    test('событие дня хранит самую большую цену выбора', () {
      final gift = _content.events.byId('friend_birthday')!;
      final event = picker().toDayEvent(gift);
      expect(event.id, gift.id);
      expect(event.title, gift.title);
      expect(event.cost, 20);
      expect(event.resolved, isFalse);
    });

    test('нерешённое событие не мешает спать и не переходит на завтра',
        () async {
      final s = _setup();
      var profile = await _start(s.controller);
      for (var i = 0; i < 2; i++) {
        profile = (await _sleep(s.controller, profile)).profile;
      }
      expect(profile.currentDay.event?.id, 'found_coins');
      final night = await _sleep(s.controller, profile);
      expect(night.profile.currentDay.number, 4);
      expect(night.profile.currentDay.event, isNull);
    });
  });
}
