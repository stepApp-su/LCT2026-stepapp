import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:finni/content/content_loader.dart';
import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/goal_service.dart';
import 'package:finni/domain/services/pet_state_service.dart';
import 'package:finni/domain/services/shop_service.dart';
import 'package:finni/domain/services/wallet_service.dart';
import 'package:finni/domain/stop_words.dart';
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

/// Сколько покупка прибавляет к шкале.
int _gain(ShopItem item, PetStat stat) => [
      for (final e in item.effects)
        if (e.stat == stat) e.delta
    ].fold(0, (a, b) => a + b);

/// Что куплено за день — по журналу операций, как это сделает цикл дня.
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
        // Иначе последствие пропуска было бы неизбежным — наказанием.
        expect(item.minStage, PetStage.egg, reason: item.id);
        expect(item.minDay, 1, reason: item.id);
      }
    });

    test('от каждой обязательной позиции магазина зависит состояние', () {
      // ТЗ: обязательные расходы — те, от которых зависит состояние питомца.
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
    final texts = _strings(_raw('economy.json')['pet']);

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
      expect(pet.state.satiety, satiety);
      final careLoss = [
        for (final need in rules.needs)
          if (need.itemId != 'food')
            for (final e in need.missedEffects)
              if (e.stat == PetStat.care) e.delta
      ].fold(0, (a, b) => a + b);
      expect(pet.state.care, care + careLoss);
      expect(night.changes.where((c) => c.stat == PetStat.satiety), isEmpty);
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
      final goal = goals.byId('ball_rope')!;

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
}
