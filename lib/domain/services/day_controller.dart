import '../game_clock.dart';
import '../models/models.dart';
import '../profile_repository.dart';
import '../text_template.dart';
import 'day_events.dart';
import 'day_summary_service.dart';
import 'growth_service.dart';
import 'pet_state_service.dart';
import 'title_service.dart';
import 'wallet_service.dart';

final class BedtimeReminder {
  const BedtimeReminder({
    required this.unpaid,
    required this.canShop,
    required this.text,
    required this.goShopping,
    required this.sleepAnyway,
  });

  final List<ShopItem> unpaid;
  final bool canShop;
  final String text;
  final String goShopping;
  final String sleepAnyway;
}

final class Bedtime {
  const Bedtime({
    required this.day,
    required this.todos,
    required this.hint,
    required this.reminder,
  });

  final int day;
  final List<BedtimeTodo> todos;
  final String hint;
  final BedtimeReminder? reminder;

  bool get ready => todos.isEmpty;
}

sealed class SleepOutcome {
  const SleepOutcome();
}

final class DayAlreadyClosed extends SleepOutcome {
  const DayAlreadyClosed(this.profile);

  final Profile profile;
}

final class Night extends SleepOutcome {
  const Night({
    required this.profile,
    required this.closedDay,
    required this.summary,
    required this.dayChanges,
    required this.nightChanges,
    required this.growth,
    required this.growthLines,
    required this.growthStatus,
    required this.stageUpTitle,
    required this.titles,
    required this.income,
    required this.event,
  });

  final Profile profile;
  final GameDay closedDay;
  final DayResult summary;
  final List<StatChange> dayChanges;
  final List<StatChange> nightChanges;
  final GrowthOutcome growth;
  final List<GrowthLine> growthLines;
  final GrowthStatus growthStatus;
  final String? stageUpTitle;
  final List<EarnedTitle> titles;
  final Transaction income;
  final GameEventDef? event;

  GameDay get newDay => profile.currentDay;
}

final class DayController {
  DayController({
    required EconomyConfig economy,
    required ShopCatalog shop,
    required EventCatalog events,
    required TitleService titles,
    required DaySummaryService summaries,
    required ProfileRepository repository,
    required GameClock clock,
  })  : _economy = economy,
        _shop = shop,
        _titles = titles,
        _summaries = summaries,
        _repository = repository,
        _clock = clock,
        _growth = GrowthService(economy.growth),
        _events =
            DayEventPicker(schedule: economy.params.events, catalog: events),
        _texts = PetStateService(rules: economy.pet);

  static const String incomeSource = 'day_income';
  static const String _shopSource = 'shop:';
  static const String _taskSource = 'task:';

  final EconomyConfig _economy;
  final ShopCatalog _shop;
  final TitleService _titles;
  final DaySummaryService _summaries;
  final ProfileRepository _repository;
  final GameClock _clock;
  final GrowthService _growth;
  final DayEventPicker _events;
  final PetStateService _texts;
  final Map<int, Future<SleepOutcome>> _sleeping = {};

  Future<Profile> startGame({
    required String petName,
    required String species,
    required int palette,
    bool simpleMode = true,
  }) async {
    final wallet = WalletService();
    final income = _earnIncome(wallet, 1);
    final progress = _titles.start(PetProgress.initial());
    final profile = Profile.create(
      petName: petName,
      species: species,
      palette: palette,
      simpleMode: simpleMode,
      wallet: wallet.wallet,
      state: _economy.pet.initialState,
      progress: progress,
      currentDay: _morningOf(1, income, progress),
    );
    await _repository.save(profile);
    return profile;
  }

  Bedtime checkBedtime(Profile profile) {
    final day = profile.currentDay;
    final today = _transactionsOf(profile, day.number);
    final bought = _boughtIds(today).toSet();
    final unpaid = [
      for (final need in _economy.pet.needs)
        if (!bought.contains(need.itemId))
          if (_shop.byId(need.itemId) case final item?) item
    ];
    final tasksDone = {
      for (final t in today)
        if (t.type == TransactionType.income &&
            t.sourceId.startsWith(_taskSource))
          t.sourceId
    }.length;
    final affordable = [
      for (final item in unpaid)
        if (item.price <= profile.wallet.balance) item
    ];
    final todos = [
      if (!day.planConfirmed) BedtimeTodo.plan,
      if (affordable.isNotEmpty) BedtimeTodo.needs,
      if (tasksDone < _economy.params.day.tasksPerDay) BedtimeTodo.task,
      if (day.event case final event? when !event.resolved) BedtimeTodo.event,
    ];
    final texts = _economy.bedtime;
    Map<String, String> items(List<ShopItem> list) =>
        {'items': list.map((item) => item.titleAccusative).join(', ')};
    return Bedtime(
      day: day.number,
      todos: List.unmodifiable(todos),
      hint: todos.isEmpty
          ? texts.ready
          : fillTemplate(texts.todos[todos.first]!, items(affordable)),
      reminder: unpaid.isEmpty
          ? null
          : BedtimeReminder(
              unpaid: List.unmodifiable(unpaid),
              canShop: affordable.isNotEmpty,
              text: fillTemplate(
                  affordable.isEmpty ? texts.shortOfMoney : texts.reminder,
                  items(unpaid)),
              goShopping: texts.goShopping,
              sleepAnyway: texts.sleepAnyway,
            ),
    );
  }

  Future<SleepOutcome> goToSleep(Profile profile, {required int day}) {
    final current = profile.currentDay.number;
    if (day > current) {
      throw ArgumentError.value(day, 'day', 'сейчас идёт день $current');
    }
    if (day < current) return Future.value(DayAlreadyClosed(profile));
    return _sleeping[day] ??= _closeDay(profile, day).whenComplete(() {
      _sleeping.remove(day);
    });
  }

  Future<Night> _closeDay(Profile profile, int day) async {
    final today = _transactionsOf(profile, day);
    final closedDay =
        profile.currentDay.copyWith(transactions: today, isClosed: true);

    final pet = PetStateService(
      rules: _economy.pet,
      initial: profile.state,
      dayNumber: day,
      actionsToday: profile.petActionsToday,
      changesToday: profile.petChangesToday,
    );
    final night = pet.closeDay(
      boughtItemIds: _boughtIds(today),
      ownedItems: _ownedItems(profile),
    );

    final growth = _growth.closeDay(
      profile.progress,
      DayFacts.fromDay(closedDay, mandatoryItemIds: [
        for (final need in _economy.pet.needs) need.itemId
      ]),
    );

    final summary = _summaries.build(
      day: closedDay.copyWith(transactions: [
        for (final t in today)
          if (t.sourceId != incomeSource) t
      ]),
      before: _morningState(profile),
      after: night.after,
      growthPoints: growth.day.points,
      petName: profile.petName,
      savedTotal: profile.wallet.savings,
    );

    final award = _titles.award(growth.progress, TitleFacts.of(profile));

    final wallet = WalletService(
        initial: profile.wallet, journal: profile.allTransactions);
    final income = _earnIncome(wallet, day + 1);
    final morning = _morningOf(day + 1, income, award.progress);

    final next = profile.copyWith(
      wallet: wallet.wallet,
      state: night.after,
      progress: award.progress,
      journal: profile.allTransactions,
      currentDay: morning,
      history: _withSummary(profile.history, summary.summary),
      petActionsToday: const {},
      petChangesToday: const [],
    );
    await _repository.save(next);

    final stageUp = growth.stageUp;
    return Night(
      profile: next,
      closedDay: closedDay,
      summary: summary,
      dayChanges: pet.changesToday,
      nightChanges: night.changes,
      growth: growth,
      growthLines: _growth.lines(growth.day),
      growthStatus: _growth.status(award.progress),
      stageUpTitle: stageUp == null
          ? null
          : _growth.stageUpTitle(stageUp, petName: profile.petName),
      titles: award.earned,
      income: income,
      event: morning.event == null
          ? null
          : _events.catalog.byId(morning.event!.id),
    );
  }

  String describe(StatChange change) => _texts.describe(change);

  Transaction _earnIncome(WalletService wallet, int day) => wallet
      .earn(
        amount: _economy.params.day.income,
        sourceId: incomeSource,
        reasonText: _economy.params.day.incomeReason,
        at: _clock.now(),
        dayNumber: day,
      )
      .transaction;

  GameDay _morningOf(int day, Transaction income, PetProgress progress) {
    final event = _events.pick(day, (d) => _stageOn(progress, d));
    return GameDay.create(
      number: day,
      income: income.amount,
      plan: BudgetPlan.empty(income.amount),
      transactions: [income],
      event: event == null ? null : _events.toDayEvent(event),
    );
  }

  PetStage _stageOn(PetProgress progress, int day) {
    var stage = PetStage.egg;
    for (final closed in progress.growthDays) {
      if (closed.dayNumber >= day) break;
      stage = closed.stageAfter;
    }
    return stage;
  }

  List<Transaction> _transactionsOf(Profile profile, int day) =>
      List.unmodifiable([
        for (final t in profile.allTransactions)
          if (t.dayNumber == day) t
      ]);

  List<String> _boughtIds(List<Transaction> today) => [
        for (final t in today)
          if (t.type == TransactionType.expense &&
              t.sourceId.startsWith(_shopSource))
            t.sourceId.substring(_shopSource.length)
      ];

  List<ShopItem> _ownedItems(Profile profile) => [
        for (final item in _shop.items)
          if (item.ownedAtStart || profile.ownedItems.contains(item.id)) item
      ];

  PetState _morningState(Profile profile) {
    int valueOf(PetStat stat) {
      for (final change in profile.petChangesToday) {
        if (change.stat == stat) return change.before;
      }
      return profile.state.of(stat);
    }

    return PetState.create(
      satiety: valueOf(PetStat.satiety),
      care: valueOf(PetStat.care),
      mood: valueOf(PetStat.mood),
      cozy: valueOf(PetStat.cozy),
    );
  }

  List<DaySummary> _withSummary(List<DaySummary> history, DaySummary summary) =>
      history.any((s) => s.dayNumber == summary.dayNumber)
          ? history
          : [...history, summary];
}
