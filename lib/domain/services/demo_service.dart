/// Демо-режим для экспертной проверки: сброс эталонного профиля,
/// нулевые кулдауны (DemoClock) и два готовых профиля-витрины.
/// Экономика, структура дня и правила развития те же, что у ребёнка, —
/// снимаются только ожидания по времени.
library;

import '../game_clock.dart';
import '../models/models.dart';
import '../profile_codec.dart';
import '../profile_repository.dart';
import 'day_controller.dart';
import 'day_summary_service.dart';
import 'pet_state_service.dart';
import 'title_service.dart';
import 'wallet_service.dart';

/// Итог прожитого показа: профиль и все ночные сводки по порядку.
final class DemoRun {
  const DemoRun({required this.profile, required this.nights});

  final Profile profile;
  final List<Night> nights;
}

final class DemoService {
  DemoService({
    required EconomyConfig economy,
    required ShopCatalog shop,
    required GoalCatalog goals,
    required EventCatalog events,
    required TitleService titles,
    required DaySummaryService summaries,
  })  : _economy = economy,
        _shop = shop,
        _goals = goals,
        _events = events,
        _titles = titles,
        _summaries = summaries;

  final EconomyConfig _economy;
  final ShopCatalog _shop;
  final GoalCatalog _goals;
  final EventCatalog _events;
  final TitleService _titles;
  final DaySummaryService _summaries;

  /// Часы демо-режима: кулдауны нулевые, сутки идут по запросу.
  DemoClock clock() => DemoClock();

  /// Возвращает игру к эталонному состоянию (json — содержимое
  /// assets/content/test_profile.json). Битый эталон — ошибка сборки,
  /// а не молчаливый пустой профиль.
  Future<Profile> resetTestProfile(String json,
      {required ProfileRepository repository}) async {
    switch (ProfileCodec.decode(json)) {
      case ProfileLoaded(:final profile):
        await repository.reset(profile);
        return profile;
      case final other:
        throw ArgumentError('эталонный профиль не читается: $other');
    }
  }

  /// «Разумный игрок»: шесть дней по плану, мечта достигнута,
  /// комната обставлена, питомец вырос.
  Future<DemoRun> prudentPlayer() => _play(goalId: 'ball_rope', days: const [
        _DayScript(plan: (25, 5, 30), buy: [..._needs, 'treat'], deposit: 30, task: 'payments_sort_needs', taps: 3),
        _DayScript(plan: (25, 5, 30), buy: [..._needs, 'treat'], deposit: 30, task: 'planning_distribute_day', taps: 3),
        _DayScript(plan: (25, 5, 30), buy: [..._needs, 'treat'], deposit: 30, task: 'savings_distribute_days', taps: 3, claimGoal: true),
        _DayScript(plan: (25, 30, 5), buy: [..._needs, 'treat', 'rug'], deposit: 5, task: 'payments_coins_pay', taps: 3),
        _DayScript(plan: (25, 25, 10), buy: [..._needs, 'treat', 'flower_pot'], deposit: 10, task: 'planning_choice_enough', taps: 3),
        _DayScript(plan: (25, 30, 5), buy: [..._needs, 'treat', 'poster'], deposit: 5, task: 'savings_week_plan', taps: 3),
      ]);

  /// «Транжира»: шесть дней без плана, вся сдача уходит на желаемое,
  /// копилка пустая. Питомец при этом здоров и весел: разница стратегий
  /// видна по комнате и росту, а не по наказанию.
  Future<DemoRun> spendthrift() => _play(days: const [
        _DayScript(buy: [..._needs, 'treat', 'apple', 'balloon'], task: 'payments_sort_needs', taps: 3),
        _DayScript(buy: [..._needs, 'treat', 'apple', 'bow'], task: 'payments_coins_pay', taps: 3),
        _DayScript(buy: [..._needs, 'treat', 'apple', 'scarf'], taps: 3),
        _DayScript(buy: [..._needs, 'treat', 'apple', 'cap'], taps: 3),
        _DayScript(buy: [..._needs, 'treat', 'apple', 'glasses'], taps: 3),
        _DayScript(buy: [..._needs, 'treat', 'apple', 'raincoat'], taps: 3),
      ]);

  static const List<String> _needs = ['food', 'water_light', 'cleaning'];

  Future<DemoRun> _play({String? goalId, required List<_DayScript> days}) async {
    final clock = DemoClock();
    final repository = _MemoryRepository();
    final controller = DayController(
      economy: _economy,
      shop: _shop,
      events: _events,
      titles: _titles,
      summaries: _summaries,
      repository: repository,
      clock: clock,
    );
    var profile = await controller.startGame(
        petName: 'Мони', species: 'fox', palette: 0);
    if (goalId != null) profile = profile.copyWith(goalId: goalId);
    final nights = <Night>[];
    for (final script in days) {
      profile = _liveDay(profile, script, at: clock.now());
      final outcome =
          await controller.goToSleep(profile, day: profile.currentDay.number);
      final night = outcome as Night;
      nights.add(night);
      profile = night.profile;
      clock.advanceDay();
    }
    return DemoRun(profile: profile, nights: nights);
  }

  Profile _liveDay(Profile profile, _DayScript script, {required DateTime at}) {
    final day = profile.currentDay.number;
    final wallet = WalletService(
        initial: profile.wallet, journal: profile.allTransactions);
    final pet = PetStateService(
      rules: _economy.pet,
      initial: profile.state,
      dayNumber: day,
      actionsToday: profile.petActionsToday,
      changesToday: profile.petChangesToday,
    );
    final owned = {...profile.ownedItems};
    final completed = {...profile.completedTasks};
    var goalIdNow = profile.goalId;
    var reached = profile.reachedGoalIds;

    for (final id in script.buy) {
      final item = _shop.byId(id)!;
      final outcome = wallet.spend(
        amount: item.price,
        itemId: id,
        category: item.category,
        reasonText: item.diaryText,
        at: at,
        dayNumber: day,
      );
      if (outcome is! WalletOk) throw StateError('не хватило на $id');
      pet.applyPurchase(item);
      if (_shop.isUnique(item)) owned.add(id);
    }
    if (script.deposit > 0 &&
        wallet.toSavings(amount: script.deposit, at: at, dayNumber: day)
            is! WalletOk) {
      throw StateError('не хватило на копилку');
    }
    if (script.task case final task?) {
      wallet.earn(
        amount: 10,
        sourceId: 'task:$task',
        reasonText: 'Задание выполнено.',
        at: at,
        dayNumber: day,
      );
      pet.perform('task_done');
      completed.add(task);
    }
    for (var i = 0; i < script.taps; i++) {
      pet.perform('pet_tap');
    }
    if (script.claimGoal) {
      final goal = _goals.goals.firstWhere((g) => g.id == goalIdNow);
      final outcome = wallet.fromSavings(
        amount: goal.price,
        at: at,
        dayNumber: day,
        sourceId: 'goal:${goal.id}',
        reasonText: 'Мечта сбылась: ${goal.title}.',
      );
      if (outcome is! WalletOk) throw StateError('копилки мало для мечты');
      pet.applyGoalReward(goal);
      reached = [...reached, goal.id];
      goalIdNow = null;
    }

    final plan = script.plan;
    return profile.copyWith(
      wallet: wallet.wallet,
      state: pet.state,
      goalId: goalIdNow,
      ownedItems: owned.toList(),
      completedTasks: completed.toList(),
      reachedGoalIds: reached,
      journal: [
        for (final t in wallet.journal)
          if (t.dayNumber < day) t
      ],
      currentDay: profile.currentDay.copyWith(
        plan: plan == null
            ? null
            : BudgetPlan.create(
                mandatory: plan.$1,
                optional: plan.$2,
                savings: plan.$3,
                income: profile.currentDay.income,
              ),
        planConfirmed: plan != null ? true : null,
        transactions: wallet.journalOfDay(day),
      ),
      petActionsToday: pet.actionsToday,
      petChangesToday: pet.changesToday,
    );
  }
}

/// Сценарий одного дня показа: план (нужно, хочу, копилка), покупки,
/// взнос, задание, поглаживания и забор мечты.
final class _DayScript {
  const _DayScript({
    this.plan,
    this.buy = const [],
    this.deposit = 0,
    this.task,
    this.taps = 0,
    this.claimGoal = false,
  });

  final (int, int, int)? plan;
  final List<String> buy;
  final int deposit;
  final String? task;
  final int taps;
  final bool claimGoal;
}

/// Витрины живут в памяти: показ не трогает сохранение ребёнка.
final class _MemoryRepository implements ProfileRepository {
  Profile? _stored;

  @override
  Future<ProfileLoad> load() async => _stored == null
      ? const ProfileMissing()
      : ProfileLoaded(_stored!, fromVersion: ProfileCodec.currentVersion);

  @override
  Future<void> save(Profile profile) async => _stored = profile;

  @override
  Future<void> reset(Profile initial) => save(initial);

  @override
  Future<void> delete() async => _stored = null;
}
