import 'dart:convert';

import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/profile_codec.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _at = DateTime(2026, 9, 22, 18, 30);

Transaction sampleTx(
  String id,
  TransactionType type,
  int amount,
  int day, {
  String source = 'day_income',
  ExpenseCategory? category,
  String reason = 'Монеты на день',
}) =>
    Transaction.create(
      id: id,
      type: type,
      amount: amount,
      sourceId: source,
      category: category,
      reasonText: reason,
      at: _at,
      dayNumber: day,
    );

final ProfileDefaults sampleDefaults = ProfileDefaults(
  state: PetState.create(satiety: 80, care: 80, mood: 80, cozy: 10),
  dayIncome: 60,
);

Profile richProfile() => Profile.create(
      petName: 'Пикс',
      species: 'robot',
      palette: 3,
      simpleMode: false,
      wallet: Wallet.create(balance: 65, savings: 40),
      state: PetState.create(satiety: 60, care: 40, mood: 72, cozy: 23),
      progress: PetProgress.create(
        growthPoints: 9,
        stage: PetStage.baby,
        earnedTitles: ['novice'],
        currentTitleId: 'novice',
      ),
      goalId: 'scooter',
      goals: [
        Goal.create(id: 'scooter', title: 'Самокат', price: 120, saved: 40)
      ],
      currentDay: GameDay.create(
        number: 2,
        income: 60,
        plan: BudgetPlan.create(
            mandatory: 25, optional: 10, savings: 20, income: 60),
        transactions: [
          sampleTx('d2-1', TransactionType.income, 60, 2),
          sampleTx('d2-2', TransactionType.expense, 15, 2,
              source: 'shop:food',
              category: ExpenseCategory.mandatory,
              reason: 'Купили еду на день.'),
        ],
        planConfirmed: true,
      ),
      ownedItems: ['bouncy_ball', 'cap'],
      equipped: {'head': 'cap', 'neck': null},
      completedTasks: ['payments_sort_needs'],
      history: [
        DaySummary.create(
          dayNumber: 1,
          plannedMandatory: 0,
          plannedOptional: 20,
          plannedSavings: 40,
          actualMandatory: 0,
          actualOptional: 20,
          actualSavings: 40,
          growthPoints: 4,
        )
      ],
      journal: [
        sampleTx('d1-1', TransactionType.income, 60, 1),
        sampleTx('d1-2', TransactionType.toSavings, 40, 1,
            source: 'savings', reason: 'Отложили в копилку'),
      ],
      wishlist: ['glasses'],
      reachedGoalIds: ['ball_rope'],
      activeWallpaperId: 'wp_dots',
      settings: const ProfileSettings(sound: false, motion: true),
      petActionsToday: const {'pet_tap': 2},
      petChangesToday: [
        StatChange.create(
          stat: PetStat.satiety,
          before: 50,
          after: 90,
          nominal: 40,
          reasonText: 'Купили еду на день.',
        )
      ],
    );

Profile freshProfile() => Profile.create(
      petName: 'Мони',
      species: 'fox',
      palette: 0,
      wallet: Wallet.create(balance: 60, savings: 0),
      state: sampleDefaults.state,
      progress: PetProgress.initial(),
      currentDay: GameDay.create(
        number: 1,
        income: 60,
        plan: BudgetPlan.empty(60),
        transactions: [sampleTx('d1-1', TransactionType.income, 60, 1)],
      ),
    );

Map<String, Object?> v1Snapshot() => {
      'schemaVersion': 1,
      'balance': 45,
      'savings': 15,
      'plan': {'mandatory': 25, 'optional': 10, 'savings': 15},
      'confirmed': true,
      'stats': {'satiety': 90, 'care': 75, 'mood': 95, 'cozy': 10},
      'journal': [
        sampleTx('d1-1', TransactionType.income, 60, 1,
                reason: 'Монеты первого дня')
            .toJson(),
        sampleTx('d1-2', TransactionType.toSavings, 20, 1,
                source: 'savings', reason: 'Отложил в копилку — мечта ближе')
            .toJson(),
        sampleTx('d1-3', TransactionType.fromSavings, 5, 1,
                source: 'savings', reason: 'Взял монетки из копилки')
            .toJson(),
      ],
      'completed': true,
      'motion': false,
      'simpleMode': false,
      'onboarded': true,
      'petName': 'Лаки',
      'goalId': 'scooter',
      'owned': ['bow'],
      'wishlist': ['glasses'],
      'outfit': {'head': 'bow'},
      'legacyCompletedTasks': ['task_save_jar'],
    };

Map<String, Object?> viaJson(Map<String, Object?> map) =>
    (jsonDecode(jsonEncode(map)) as Map).cast<String, Object?>();

Object? asJson(Profile profile) => jsonDecode(jsonEncode(profile.toJson()));

const _profileFields = {
  'petName',
  'species',
  'palette',
  'simpleMode',
  'wallet',
  'state',
  'progress',
  'goalId',
  'goals',
  'currentDay',
  'ownedItems',
  'equipped',
  'completedTasks',
  'history',
  'journal',
  'wishlist',
  'reachedGoalIds',
  'activeWallpaperId',
  'settings',
  'petActionsToday',
  'petChangesToday',
};

void expectSameProfile(Profile actual, Profile expected) {
  expect(expected.toJson().keys.toSet(), _profileFields,
      reason: 'у профиля новое поле — добавьте его в expectSameProfile');
  expect(actual.petName, expected.petName, reason: 'petName');
  expect(actual.species, expected.species, reason: 'species');
  expect(actual.palette, expected.palette, reason: 'palette');
  expect(actual.simpleMode, expected.simpleMode, reason: 'simpleMode');
  expect(actual.wallet, expected.wallet, reason: 'wallet');
  expect(actual.state, expected.state, reason: 'state');
  expect(actual.progress, expected.progress, reason: 'progress');
  expect(actual.goalId, expected.goalId, reason: 'goalId');
  expect(actual.goals, expected.goals, reason: 'goals');
  expect(actual.currentDay, expected.currentDay, reason: 'currentDay');
  expect(actual.currentDay.plan, expected.currentDay.plan, reason: 'plan');
  expect(actual.currentDay.transactions, expected.currentDay.transactions,
      reason: 'currentDay.transactions');
  expect(actual.currentDay.planConfirmed, expected.currentDay.planConfirmed,
      reason: 'planConfirmed');
  expect(actual.currentDay.isClosed, expected.currentDay.isClosed,
      reason: 'isClosed');
  expect(actual.currentDay.event, expected.currentDay.event, reason: 'event');
  expect(actual.ownedItems, expected.ownedItems, reason: 'ownedItems');
  expect(actual.equipped, expected.equipped, reason: 'equipped');
  expect(actual.completedTasks, expected.completedTasks,
      reason: 'completedTasks');
  expect(actual.history, expected.history, reason: 'history');
  expect(actual.journal, expected.journal, reason: 'journal');
  expect(actual.wishlist, expected.wishlist, reason: 'wishlist');
  expect(actual.reachedGoalIds, expected.reachedGoalIds,
      reason: 'reachedGoalIds');
  expect(actual.activeWallpaperId, expected.activeWallpaperId,
      reason: 'activeWallpaperId');
  expect(actual.settings, expected.settings, reason: 'settings');
  expect(actual.petActionsToday, expected.petActionsToday,
      reason: 'petActionsToday');
  expect(actual.petChangesToday, expected.petChangesToday,
      reason: 'petChangesToday');
}
