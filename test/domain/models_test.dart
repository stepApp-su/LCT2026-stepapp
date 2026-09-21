import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:finni/domain/models/models.dart';

Profile _sampleProfile() {
  final plan = BudgetPlan.create(
      mandatory: 25, optional: 5, savings: 10, income: 40);
  final tx = Transaction.create(
    id: 't1',
    type: TransactionType.expense,
    amount: 15,
    sourceId: 'shop:food',
    category: ExpenseCategory.mandatory,
    reasonText: 'Купили еду — Финни поел',
    at: DateTime(2026, 9, 21, 10, 30),
    dayNumber: 3,
  );
  final day = GameDay.create(
    number: 3,
    income: 40,
    plan: plan,
    transactions: [tx],
    event: DayEvent.create(id: 'rain', title: 'Дождик', cost: 10),
  );
  return Profile.create(
    petName: 'Мони',
    species: 'fox',
    palette: 2,
    wallet: Wallet.create(balance: 15, savings: 15),
    state: PetState.create(satiety: 85, care: 70, mood: 90, cozy: 12),
    progress: PetProgress.create(
        growthPoints: 9,
        stage: PetStage.baby,
        earnedTitles: ['novice', 'planner'],
        currentTitleId: 'planner'),
    goalId: 'moon',
    goals: [
      Goal.create(id: 'moon', title: 'Слетать на Луну', price: 150, saved: 15)
    ],
    currentDay: day,
    ownedItems: ['ball'],
    equipped: {'head': 'cap', 'neck': null},
    completedTasks: ['need_or_want'],
    history: [
      DaySummary.create(
        dayNumber: 2,
        plannedMandatory: 25, plannedOptional: 5, plannedSavings: 10,
        actualMandatory: 25, actualOptional: 13, actualSavings: 2,
        growthPoints: 5,
      )
    ],
  );
}

void main() {
  group('json туда-обратно', () {
    test('Transaction', () {
      final tx = _sampleProfile().currentDay.transactions.first;
      final restored =
          Transaction.fromJson(jsonDecode(jsonEncode(tx.toJson())));
      expect(restored, tx);
    });

    test('BudgetPlan', () {
      final plan = BudgetPlan.create(
          mandatory: 25, optional: 5, savings: 10, income: 40);
      expect(BudgetPlan.fromJson(jsonDecode(jsonEncode(plan.toJson()))), plan);
    });

    test('Wallet, Goal, ShopItem, PetState, PetProgress, DayEvent', () {
      final wallet = Wallet.create(balance: 7, savings: 40);
      expect(Wallet.fromJson(jsonDecode(jsonEncode(wallet.toJson()))), wallet);

      final goal =
          Goal.create(id: 'g', title: 'Самокат', price: 120, saved: 30);
      expect(Goal.fromJson(jsonDecode(jsonEncode(goal.toJson()))), goal);

      final item = ShopItem.create(
        id: 'food',
        title: 'Еда',
        price: 15,
        category: ExpenseCategory.mandatory,
        effects: [const StateEffect(stat: PetStat.satiety, delta: 40)],
      );
      expect(ShopItem.fromJson(jsonDecode(jsonEncode(item.toJson()))), item);

      final state = PetState.create(satiety: 50, care: 60, mood: 70, cozy: 3);
      expect(PetState.fromJson(jsonDecode(jsonEncode(state.toJson()))), state);

      final progress = PetProgress.create(
          growthPoints: 14, stage: PetStage.teen, earnedTitles: ['a']);
      expect(
          PetProgress.fromJson(jsonDecode(jsonEncode(progress.toJson()))),
          progress);

      final event = DayEvent.create(id: 'rain', title: 'Дождик', cost: 10);
      expect(DayEvent.fromJson(jsonDecode(jsonEncode(event.toJson()))), event);
    });

    test('GameDay и Profile целиком', () {
      final profile = _sampleProfile();
      final restoredDay = GameDay.fromJson(
          jsonDecode(jsonEncode(profile.currentDay.toJson())));
      expect(restoredDay, profile.currentDay);

      final restored =
          Profile.fromJson(jsonDecode(jsonEncode(profile.toJson())));
      expect(restored.petName, profile.petName);
      expect(restored.wallet, profile.wallet);
      expect(restored.state, profile.state);
      expect(restored.progress, profile.progress);
      expect(restored.goals, profile.goals);
      expect(restored.currentDay, profile.currentDay);
      expect(restored.history, profile.history);
      expect(restored.equipped, profile.equipped);
    });
  });

  group('защиты', () {
    test('операция без объяснения — ошибка', () {
      expect(
        () => Transaction.create(
          id: 't',
          type: TransactionType.income,
          amount: 5,
          sourceId: 'login',
          reasonText: '   ',
          at: DateTime(2026, 1, 1),
          dayNumber: 1,
        ),
        throwsArgumentError,
      );
    });

    test('сумма 0 или меньше — ошибка', () {
      for (final bad in [0, -5]) {
        expect(
          () => Transaction.create(
            id: 't',
            type: TransactionType.income,
            amount: bad,
            sourceId: 'login',
            reasonText: 'Бонус',
            at: DateTime(2026, 1, 1),
            dayNumber: 1,
          ),
          throwsArgumentError,
        );
      }
    });

    test('план больше дохода — ошибка', () {
      expect(
        () => BudgetPlan.create(
            mandatory: 25, optional: 20, savings: 10, income: 40),
        throwsArgumentError,
      );
      final plan = BudgetPlan.create(
          mandatory: 25, optional: 5, savings: 5, income: 40);
      expect(plan.remainder, 5);
      expect(plan.isValid, isTrue);
    });

    test('минус в кошельке — ошибка', () {
      expect(() => Wallet.create(balance: -1, savings: 0), throwsArgumentError);
      expect(() => Wallet.create(balance: 0, savings: -1), throwsArgumentError);
    });

    test('шкалы не падают ниже пола', () {
      final state =
          PetState.create(satiety: -100, care: 0, mood: 5, cozy: -3);
      expect(state.satiety, PetState.satietyFloor);
      expect(state.care, PetState.careFloor);
      expect(state.mood, PetState.moodFloor);
      expect(state.cozy, 0);
    });

    test('в профиле нет персональных полей', () {
      final keys = <String>{};
      void collect(Object? node) {
        if (node is Map) {
          for (final e in node.entries) {
            keys.add(e.key.toString().toLowerCase());
            collect(e.value);
          }
        } else if (node is List) {
          node.forEach(collect);
        }
      }

      collect(jsonDecode(jsonEncode(_sampleProfile().toJson())));
      for (final banned in [
        'realname', 'name', 'phone', 'email', 'birthdate', 'birthday',
        'deviceid', 'location', 'age', 'address'
      ]) {
        expect(keys.contains(banned), isFalse, reason: banned);
      }
    });
  });
}
