import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:finni/content/content_loader.dart';
import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/goal_service.dart';
import 'package:finni/domain/services/growth_service.dart';
import 'package:finni/domain/services/pet_state_service.dart';
import 'package:finni/domain/services/shop_service.dart';
import 'package:finni/domain/ru_words.dart';
import 'package:finni/domain/services/wallet_service.dart';
import 'package:finni/domain/stop_words.dart';
import 'package:finni/domain/text_template.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _raw(String file) =>
    (jsonDecode(File('assets/content/$file').readAsStringSync()) as Map)
        .cast<String, Object?>();

List<String> _strings(Object? node) {
  if (node is String) return [node];
  if (node is List) return [for (final v in node) ..._strings(v)];
  if (node is Map) return [for (final v in node.values) ..._strings(v)];
  return const [];
}

int _words(String text) => text
    .split(RegExp(r'\s+'))
    .where((w) => RegExp(r'[\p{L}\d]', unicode: true).hasMatch(w))
    .length;

int _gain(ShopItem item, PetStat stat) => [
      for (final e in item.effects)
        if (e.stat == stat) e.delta
    ].fold(0, (a, b) => a + b);

List<String> _boughtOn(WalletService wallet, int day) => [
      for (final tx in wallet.journalOfDay(day))
        if (tx.type == TransactionType.expense &&
            tx.sourceId.startsWith('shop:'))
          tx.sourceId.substring('shop:'.length)
    ];

final DateTime _at = DateTime(2026, 9, 23, 18);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final economy = EconomyConfig.fromJson(_raw('economy.json'));
  final rules = economy.pet;
  final shop = ShopCatalog.fromJson(_raw('shop.json'));
  final goals = GoalCatalog.fromJson(_raw('goals.json'));

  group('economy.json', () {
    test('приложение загружает его из ассетов тем же путём, что и в работе',
        () async {
      final loaded = await const ContentLoader().loadEconomy();
      expect(loaded.schemaVersion, economy.schemaVersion);
      expect(loaded.pet.needs.map((n) => n.itemId),
          rules.needs.map((n) => n.itemId));
    });

    test('новый питомец: ни одна шкала не на нуле, просьб нет', () {
      final pet = PetStateService(rules: rules);
      for (final stat in PetStat.values) {
        expect(pet.state.of(stat), greaterThan(0), reason: stat.name);
      }
      expect(pet.status.wishes, isEmpty);
    });

    test('все обязательные действия и уровни на месте', () {
      expect(economy.schemaVersion, 1);
      expect(rules.actions.keys, containsAll(PetRules.requiredActions));
      expect(rules.moodLevels, hasLength(MoodLevel.values.length));
    });
  });

  group('обязательные покупки держат питомца в порядке', () {
    test('каждая есть в магазине и доступна с первого дня', () {
      for (final need in rules.needs) {
        final item = shop.byId(need.itemId);
        expect(item, isNotNull, reason: need.itemId);
        expect(item!.category, ExpenseCategory.mandatory, reason: item.id);
        expect(item.showInShop, isTrue, reason: item.id);
        expect(item.price, greaterThan(0), reason: item.id);
        expect(item.minStage, PetStage.egg, reason: item.id);
        expect(item.minDay, 1, reason: item.id);
      }
    });

    test('от каждой обязательной позиции магазина зависит состояние', () {
      for (final item in shop.items) {
        if (item.category != ExpenseCategory.mandatory || !item.showInShop) {
          continue;
        }
        expect(rules.needFor(item.id), isNotNull, reason: item.id);
      }
    });

    test('одна покупка полностью возмещает пропущенный день', () {
      for (final need in rules.needs) {
        final item = shop.byId(need.itemId)!;
        for (final missed in need.missedEffects) {
          expect(_gain(item, missed.stat), greaterThanOrEqualTo(-missed.delta),
              reason: '${item.id}: ${missed.stat.name}');
        }
      }
    });

    test('даже с пола одна покупка снимает «хочется»', () {
      for (final need in rules.needs) {
        final item = shop.byId(need.itemId)!;
        for (final missed in need.missedEffects) {
          final fromFloor =
              petStatFloor(missed.stat) + _gain(item, missed.stat);
          expect(fromFloor, greaterThan(rules.low[missed.stat]!.atOrBelow),
              reason: '${item.id}: ${missed.stat.name}');
        }
      }
    });
  });

  test('уют только растёт: ни товар, ни вещь в комнате, ни цель его не снижают',
      () {
    for (final item in shop.items) {
      for (final e in [...item.effects, ...item.dailyEffects]) {
        if (e.stat == PetStat.cozy) {
          expect(e.delta, greaterThan(0), reason: item.id);
        }
      }
    }
    for (final goal in goals.goals) {
      for (final e in goal.rewardEffects) {
        if (e.stat == PetStat.cozy) {
          expect(e.delta, greaterThan(0), reason: goal.id);
        }
      }
    }
  });

  group('тексты для ребёнка', () {
    final texts = _strings(_raw('economy.json'));

    test('ни одного слова из стоп-листа', () {
      for (final text in texts) {
        expect(findStopWords(text), isEmpty, reason: text);
      }
    });

    test('коротко: не длиннее десяти слов', () {
      for (final text in texts) {
        expect(_words(text), lessThanOrEqualTo(10), reason: text);
      }
    });
  });

  group('нужное на выбор', () {
    test('у каждой нужды есть варианты в магазине, все обязательные', () {
      for (final need in rules.allNeeds) {
        expect(need.title, isNotEmpty, reason: need.itemId);
        expect(need.emoji, isNotEmpty, reason: need.itemId);
        for (final id in need.itemIds) {
          final item = shop.byId(id);
          expect(item, isNotNull, reason: id);
          expect(item!.category, ExpenseCategory.mandatory, reason: id);
          expect(item.maxPerDay, 1, reason: id);
          expect(item.effects, isNotEmpty, reason: id);
        }
      }
    });

    test('ежедневное нужное открыто с первого дня, а без выбора — нет', () {
      expect(rules.needs.where((n) => n.alternatives.isNotEmpty).length,
          greaterThanOrEqualTo(2));
      for (final need in rules.needs) {
        for (final id in need.itemIds) {
          expect(shop.byId(id)!.minStage, PetStage.egg, reason: id);
        }
      }
      expect(shop.mandatoryCost,
          rules.needs.fold(0, (sum, n) => sum + shop.byId(n.itemId)!.price));
    });

    test('особая нужда появляется, только когда её товары уже в магазине', () {
      for (final need in rules.occasionalNeeds) {
        final occasion = need.occasion!;
        for (final id in need.itemIds) {
          expect(shop.byId(id)!.minStage.index,
              lessThanOrEqualTo(occasion.minStage.index),
              reason: id);
        }
        final cheapest = need.itemIds
            .map((id) => shop.byId(id)!.price)
            .reduce((a, b) => a < b ? a : b);
        expect(shop.byId(need.itemId)!.price, cheapest, reason: need.itemId);
      }
    });

    test('любой вариант нужды закрывает её пропуск', () {
      for (final need in rules.allNeeds) {
        for (final id in need.itemIds) {
          final item = shop.byId(id)!;
          expect(need.metBy([id]), isTrue, reason: id);
          for (final missed in need.missedEffects) {
            expect(_gain(item, missed.stat), greaterThan(0),
                reason: '$id: ${missed.stat.name}');
          }
        }
      }
    });

    test('в один день не больше одной особой нужды, и нужное по карману', () {
      final income = economy.params.day.income;
      for (var day = 1; day <= 60; day++) {
        final today = rules.needsOn(day, PetStage.adult);
        expect(today.where((n) => n.occasion != null).length,
            lessThanOrEqualTo(1),
            reason: 'день $day');
        final cheapest = today.fold(
            0,
            (sum, need) =>
                sum +
                need.itemIds
                    .map((id) => shop.byId(id)!.price)
                    .reduce((a, b) => a < b ? a : b));
        expect(cheapest, lessThan(income), reason: 'день $day');
      }
      expect(rules.needsOn(3, PetStage.baby).map((n) => n.itemId),
          contains('warm_socks'));
      expect(rules.needsOn(3, PetStage.egg).map((n) => n.itemId),
          isNot(contains('warm_socks')));
      expect(rules.needsOn(2, PetStage.baby).map((n) => n.itemId),
          isNot(contains('notebook')));
      expect(rules.needsOn(2, PetStage.teen).map((n) => n.itemId),
          contains('notebook'));
    });

    test('ночь: каша вместо обеда считается, пропуск особой нужды — нет', () {
      final pet = PetStateService(rules: rules, dayNumber: 3);
      final night = pet.closeDay(
          boughtItemIds: ['porridge', 'water_light', 'toothbrush'],
          stage: PetStage.baby);
      final reasons = {for (final c in night.changes) c.reasonText};
      for (final need in rules.needs) {
        expect(reasons, isNot(contains(need.missedReason)));
      }
      final cold = rules.needFor('warm_socks')!;
      expect(reasons, contains(cold.missedReason));

      final warm = PetStateService(rules: rules, dayNumber: 3).closeDay(
          boughtItemIds: ['porridge', 'water_light', 'toothbrush', 'mittens'],
          stage: PetStage.baby);
      expect({for (final c in warm.changes) c.reasonText},
          isNot(contains(cold.missedReason)));
    });

    test('день засчитан, если из каждой нужды куплено что-то одно', () {
      GameDay dayWith(List<String> ids) => GameDay.create(
            number: 3,
            income: 40,
            plan: BudgetPlan.create(
                mandatory: 25, optional: 0, savings: 15, income: 40),
            planConfirmed: true,
            transactions: [
              for (final id in ids)
                Transaction.create(
                  id: 'tx-$id',
                  type: TransactionType.expense,
                  amount: shop.byId(id)!.price,
                  sourceId: 'shop:$id',
                  category: ExpenseCategory.mandatory,
                  reasonText: 'Покупка',
                  at: _at,
                  dayNumber: 3,
                ),
            ],
          );
      final options = [
        for (final need in rules.needsOn(3, PetStage.baby)) need.itemIds
      ];
      expect(
          DayFacts.fromDay(
                  dayWith(['lunchbox', 'water_light', 'laundry', 'warm_jacket']),
                  mandatoryItemIds: const [],
                  mandatoryOptions: options)
              .mandatoryPaid,
          isTrue);
      expect(
          DayFacts.fromDay(dayWith(['food', 'water_light', 'cleaning']),
                  mandatoryItemIds: const [], mandatoryOptions: options)
              .mandatoryPaid,
          isFalse);
    });
  });

  group('вместе с кошельком, магазином и целями', () {
    test('покупка меняет баланс, журнал и шкалу с одной и той же причиной', () {
      final wallet = WalletService()
        ..earn(
            amount: 60,
            sourceId: 'day_income',
            reasonText: 'Монеты на день',
            at: _at,
            dayNumber: 1);
      final store = ShopService(catalog: shop, wallet: wallet);
      final pet = PetStateService(rules: rules);

      final ask = store.askToBuy('food') as PurchaseConfirm;
      final done = store.confirm(ask, at: _at) as PurchaseDone;
      final update = pet.applyPurchase(done.item);

      expect(done.wallet.balance, 60 - done.item.price);
      final change = update.changes.single;
      expect(change.stat, PetStat.satiety);
      expect(change.delta, greaterThan(0));
      expect(change.reasonText, done.transaction.reasonText);
    });

    test('ночь по журналу: купленное не снижается, пропущенное — да', () {
      final wallet = WalletService()
        ..earn(
            amount: 60,
            sourceId: 'day_income',
            reasonText: 'Монеты на день',
            at: _at,
            dayNumber: 1);
      final store = ShopService(catalog: shop, wallet: wallet);
      final pet = PetStateService(rules: rules);
      final done = store.confirm(store.askToBuy('food') as PurchaseConfirm,
          at: _at) as PurchaseDone;
      pet.applyPurchase(done.item);
      final satiety = pet.state.satiety;
      final care = pet.state.care;

      final night = pet.closeDay(boughtItemIds: _boughtOn(wallet, 1));
      int nightly(PetStat stat) => [
            for (final e in rules.nightlyEffects)
              if (e.stat == stat) e.delta
          ].fold(0, (a, b) => a + b);
      expect(pet.state.satiety,
          (satiety + nightly(PetStat.satiety)).clamp(PetState.satietyFloor, PetState.cap));
      final careLoss = [
        for (final need in rules.needs)
          if (need.itemId != 'food')
            for (final e in need.missedEffects)
              if (e.stat == PetStat.care) e.delta
      ].fold(0, (a, b) => a + b);
      expect(pet.state.care,
          (care + careLoss + nightly(PetStat.care)).clamp(PetState.careFloor, PetState.cap));
      expect(
          night.changes
              .where((c) => c.stat == PetStat.satiety)
              .map((c) => c.reasonText),
          everyElement(rules.nightlyReason));
    });

    test('достигнутая цель добавляет уюта навсегда, с её собственным текстом',
        () {
      final wallet = WalletService()
        ..earn(
            amount: 100,
            sourceId: 'day_income',
            reasonText: 'Монеты на день',
            at: _at,
            dayNumber: 1);
      final targets = GoalService(catalog: goals, wallet: wallet);
      final pet = PetStateService(rules: rules);
      final goal = goals.byId('constructor')!;

      targets.confirmSelect(targets.askToSelect(goal.id) as GoalSelectConfirm);
      targets.deposit(amount: goal.price, at: _at);
      final claimed = targets.claim(at: _at) as GoalClaimed;
      final update = pet.applyGoalReward(claimed.goal);

      final cozy = update.changes.single;
      expect(cozy.stat, PetStat.cozy);
      expect(cozy.delta, goal.rewardEffects.single.delta);
      expect(cozy.reasonText, goal.reachedText);
    });

    test('игрушка из магазина радует каждую ночь', () {
      final ball = shop.byId('bouncy_ball')!;
      final pet = PetStateService(
          rules: rules,
          initial: PetState.create(satiety: 80, care: 80, mood: 50, cozy: 10));
      final night = pet.closeDay(
          boughtItemIds: [for (final n in rules.needs) n.itemId],
          ownedItems: [ball]);
      final joy = night.changes.last;
      expect(joy.delta, ball.dailyEffects.single.delta);
      expect(joy.reasonText, contains(ball.title));
    });
  });

  test('тридцать дней случайной игры на настоящем каталоге: рамки держатся',
      () {
    final buyable = [
      for (final item in shop.items)
        if (item.showInShop && item.price > 0) item
    ];
    final owned = [
      for (final item in shop.items)
        if (item.dailyEffects.isNotEmpty) item
    ];
    for (var seed = 0; seed < 50; seed++) {
      final random = Random(seed);
      final pet = PetStateService(rules: rules);
      var cozy = pet.state.cozy;
      for (var day = 1; day <= 30; day++) {
        pet.startDay(day);
        final bought = <String>[];
        for (var i = random.nextInt(6); i > 0; i--) {
          final item = buyable[random.nextInt(buyable.length)];
          bought.add(item.id);
          pet.applyPurchase(item);
        }
        for (var i = random.nextInt(5); i > 0; i--) {
          pet.perform(random.nextBool() ? PetRules.petTap : PetRules.taskDone);
        }
        if (random.nextInt(10) == 0) {
          pet.applyGoalReward(goals.goals[random.nextInt(goals.goals.length)]);
        }
        pet.closeDay(boughtItemIds: bought, ownedItems: [
          for (final item in owned)
            if (random.nextBool()) item
        ]);

        final s = pet.state;
        expect(
            s.satiety, inInclusiveRange(PetState.satietyFloor, PetState.cap));
        expect(s.care, inInclusiveRange(PetState.careFloor, PetState.cap));
        expect(s.mood, inInclusiveRange(PetState.moodFloor, PetState.cap));
        expect(s.cozy, greaterThanOrEqualTo(cozy));
        cozy = s.cozy;
        for (final change in pet.changesToday) {
          expect(change.reasonText.trim(), isNotEmpty);
          expect(pet.describe(change).trim(), isNotEmpty);
        }
      }
    }
  });

  group('рост питомца на настоящих правилах', () {
    final growth = GrowthService(economy.growth);
    final needs = [for (final need in rules.needs) need.itemId];

    GameDay playDay(
      WalletService wallet,
      int day, {
      required BudgetPlan plan,
      bool confirmed = true,
      List<String> buy = const [],
      int deposit = 0,
      bool task = false,
    }) {
      wallet.earn(
          amount: plan.income,
          sourceId: 'day_income',
          reasonText: 'Монеты на день',
          at: _at,
          dayNumber: day);
      for (final id in buy) {
        final item = shop.byId(id)!;
        expect(
            wallet.spend(
                amount: item.price,
                itemId: id,
                category: item.category,
                reasonText: item.diaryText,
                at: _at,
                dayNumber: day),
            isA<WalletOk>(),
            reason: 'день $day: $id');
      }
      if (deposit > 0) {
        expect(wallet.toSavings(amount: deposit, at: _at, dayNumber: day),
            isA<WalletOk>());
      }
      if (task) {
        wallet.earn(
            amount: 12,
            sourceId: 'task:payments_sort_needs',
            reasonText: 'Задание: нужное и желаемое',
            at: _at,
            dayNumber: day);
      }
      return GameDay.create(
        number: day,
        income: plan.income,
        plan: plan,
        transactions: wallet.journalOfDay(day),
        planConfirmed: confirmed,
      );
    }

    ({PetProgress progress, List<StageUp> stageUps}) live(
        int days, GameDay Function(WalletService wallet, int day) play) {
      final wallet = WalletService();
      var progress = PetProgress.initial();
      final stageUps = <StageUp>[];
      for (var day = 1; day <= days; day++) {
        final facts =
            DayFacts.fromDay(play(wallet, day), mandatoryItemIds: needs);
        final outcome = growth.closeDay(progress, facts);
        progress = outcome.progress;
        if (outcome.stageUp != null) stageUps.add(outcome.stageUp!);
      }
      return (progress: progress, stageUps: stageUps);
    }

    test('малыш — за один идеальный день, две стадии — за пять дней', () {
      final rules = economy.growth;
      expect(rules.thresholds[PetStage.baby]!,
          lessThanOrEqualTo(rules.maxDailyPoints));
      expect(rules.thresholds[PetStage.teen]!,
          lessThanOrEqualTo(5 * rules.maxDailyPoints));
    });

    test('три фактора ТЗ весят больше задания, одними заданиями не вырасти',
        () {
      final points = economy.growth.points;
      for (final factor in [
        GrowthFactor.mandatoryPaid,
        GrowthFactor.followedPlan,
        GrowthFactor.savedAsPlanned,
      ]) {
        expect(points[factor]!, greaterThan(points[GrowthFactor.taskDone]!));
      }
      expect(5 * points[GrowthFactor.taskDone]!,
          lessThan(economy.growth.thresholds[PetStage.teen]!));
    });

    test('разумный игрок: за пять дней три новые стадии, у каждой объяснение',
        () {
      final result = live(
          5,
          (wallet, day) => playDay(wallet, day,
              plan: BudgetPlan.create(
                  mandatory: 25, optional: 10, savings: 25, income: 60),
              buy: [...needs, 'treat'],
              deposit: 25,
              task: true));
      expect(result.progress.stage, PetStage.adult);
      expect([for (final up in result.stageUps) up.to],
          [PetStage.baby, PetStage.teen, PetStage.adult]);
      for (final up in result.stageUps) {
        expect(up.reasonText, contains('откладывали в копилку'));
        expect(_words(up.reasonText), lessThanOrEqualTo(10),
            reason: up.reasonText);
        expect(findStopWords(up.reasonText), isEmpty);
        expect(growth.stageUpTitle(up, petName: 'Мони'),
            'Мони подрастает: теперь «${up.stageLabel}»!');
      }
    });

    test('транжира: всё на желаемое — к шестому дню «Подросток», не «Взрослый»',
        () {
      final result = live(
          6,
          (wallet, day) => playDay(wallet, day,
              plan: BudgetPlan.create(
                  mandatory: 25, optional: 35, savings: 0, income: 60),
              buy: [...needs, 'bouncy_ball', 'puzzle'],
              task: true));
      expect(result.progress.stage, PetStage.teen);
      expect(result.progress.growthPoints, 30);
    });

    test('без плана и покупок — яйцо, подсказки без упрёков и без пропусков',
        () {
      final result = live(
          6,
          (wallet, day) => playDay(wallet, day,
              plan: BudgetPlan.empty(60), confirmed: false));
      expect(result.progress.stage, PetStage.egg);
      expect(result.progress.growthPoints, 0);
      expect(result.progress.growthDays, hasLength(6));
      for (final day in result.progress.growthDays) {
        for (final line in growth.lines(day)) {
          expect(line.met, isFalse);
          expect(line.text, isNot(contains('{')));
          expect(findStopWords(line.text), isEmpty);
        }
      }
    });
  });

  group('рост и копилка на настоящих сервисах', () {
    final growth = GrowthService(economy.growth);
    final needs = [for (final need in rules.needs) need.itemId];

    test('пустой подтверждённый план без покупок — яйцо, без очков', () {
      final wallet = WalletService();
      var progress = PetProgress.initial();
      for (var day = 1; day <= 6; day++) {
        wallet.earn(
            amount: 60,
            sourceId: 'day_income',
            reasonText: 'Монеты на день',
            at: _at,
            dayNumber: day);
        final facts = DayFacts.fromDay(
            GameDay.create(
              number: day,
              income: 60,
              plan: BudgetPlan.empty(60),
              transactions: wallet.journalOfDay(day),
              planConfirmed: true,
            ),
            mandatoryItemIds: needs);
        progress = growth.closeDay(progress, facts).progress;
      }
      expect(progress.growthPoints, 0);
      expect(progress.stage, PetStage.egg);
    });

    test('получение цели не отнимает очки за копилку, а снятие — отнимает', () {
      final wallet = WalletService();
      final targets = GoalService(catalog: goals, wallet: wallet);
      final goal = goals.byId('constructor')!;
      final plan = BudgetPlan.create(
          mandatory: 0, optional: 0, savings: goal.price, income: 200);
      DayFacts factsOf(int day) => DayFacts.fromDay(
          GameDay.create(
            number: day,
            income: 200,
            plan: plan,
            transactions: wallet.journalOfDay(day),
            planConfirmed: true,
          ),
          mandatoryItemIds: needs);

      wallet.earn(
          amount: 200,
          sourceId: 'day_income',
          reasonText: 'Монеты на день',
          at: _at,
          dayNumber: 1);
      targets.confirmSelect(targets.askToSelect(goal.id) as GoalSelectConfirm);
      targets.deposit(amount: goal.price, at: _at);
      final claimed = targets.claim(at: _at) as GoalClaimed;
      expect(claimed.transaction.sourceId, 'goal:${goal.id}');
      final claimDay = factsOf(1);
      expect(claimDay.deposited, goal.price);
      expect(
          growth.factorsOf(claimDay),
          containsAll(
              [GrowthFactor.followedPlan, GrowthFactor.savedAsPlanned]));

      wallet.earn(
          amount: 200,
          sourceId: 'day_income',
          reasonText: 'Монеты на день',
          at: _at,
          dayNumber: 2);
      targets.startDay(2);
      targets
          .confirmSelect(targets.askToSelect('scooter') as GoalSelectConfirm);
      targets.deposit(amount: goal.price, at: _at);
      final preview = targets.previewWithdraw(goal.price) as WithdrawPreview;
      expect(targets.withdraw(preview, at: _at), isA<WithdrawDone>());
      final withdrawDay = factsOf(2);
      expect(withdrawDay.deposited, 0);
      expect(growth.factorsOf(withdrawDay),
          isNot(contains(GrowthFactor.savedAsPlanned)));
    });

    test('объяснение роста не длиннее десяти слов при любом наборе дел', () {
      final texts = economy.growth.texts;
      final actions = [
        for (final factor in GrowthFactor.values) texts.factors[factor]!.action
      ];
      final sets = [
        for (final a in actions) a,
        for (var i = 0; i < actions.length; i++)
          for (var j = i + 1; j < actions.length; j++)
            '${actions[i]} и ${actions[j]}',
      ];
      for (final joined in sets) {
        final today = fillTemplate(texts.reasonOneDay, {'actions': joined});
        expect(_words(today), lessThanOrEqualTo(10), reason: today);
        for (final days in [2, 5, 11, 21, 100]) {
          final text = fillPlurals(fillTemplate(
              texts.reasonDays, {'days': '$days', 'actions': joined}));
          expect(_words(text), lessThanOrEqualTo(10), reason: text);
          expect(text, isNot(contains('{')), reason: text);
        }
      }
      for (final stage in PetStage.values) {
        final title = fillTemplate(texts.stageUp,
            {'name': 'Мони', 'stage': texts.stageLabels[stage]!});
        expect(_words(title), lessThanOrEqualTo(10), reason: title);
      }
    });
  });
}
