import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../content/content_loader.dart';
import '../content/content_repository.dart';
import '../content/game_content.dart';
import '../data/game_repository.dart';
import '../domain/game_clock.dart';
import '../domain/pet_name.dart';
import '../domain/ru_words.dart';
import '../domain/text_template.dart';
import '../domain/models/models.dart';
import '../domain/services/goal_service.dart';
import '../domain/services/hint_service.dart';
import '../domain/services/day_events.dart';
import '../domain/services/day_summary_service.dart';
import '../domain/services/growth_service.dart';
import '../domain/services/level_service.dart';
import '../domain/services/title_service.dart';
import '../domain/services/pet_state_service.dart';
import '../domain/services/phrase_service.dart';
import '../domain/services/plan_service.dart';
import '../domain/services/shop_service.dart';
import '../domain/services/task_engine.dart';
import '../domain/services/wallet_service.dart';

final class GameReward {
  const GameReward({
    required this.coins,
    required this.firstTime,
    required this.withMistakes,
    required this.stars,
  });

  final int coins;
  final bool firstTime;
  final bool withMistakes;
  final int stars;
}

final class StatShift {
  const StatShift(this.stat, this.before, this.after);

  final PetStat stat;
  final int before;
  final int after;

  int get delta => after - before;

  String get label => petStatLabel(stat);
}

sealed class EventOutcome {
  const EventOutcome();
}

final class EventResolved extends EventOutcome {
  const EventResolved({
    required this.option,
    required this.text,
    required this.shifts,
  });

  final EventOption option;
  final String text;
  final List<StatShift> shifts;
}

final class EventShort extends EventOutcome {
  const EventShort({required this.gap, required this.text});

  final int gap;
  final String text;
}

final class LevelStep {
  const LevelStep({required this.reward, this.finished});

  final GameReward reward;
  final LevelRecord? finished;
}

class GameController extends ChangeNotifier {
  GameController(this.config,
      {required this.content,
      Map<String, dynamic>? saved,
      GameRepository? repository,
      GameClock? clock})
      : repository = repository ?? LocalGameRepository(),
        clock = clock ?? RealClock() {
    _restore(saved);
  }

  static const String character = 'fox';
  static const Map<String, String> _legacyItems = {'ball': 'bouncy_ball'};

  final Map<String, dynamic> config;
  final ContentBundle content;
  final GameRepository repository;
  final GameClock clock;
  late WalletService wallet;
  late PlanService plan;
  late PetState stats;
  late ShopService shop;
  late GoalService goals;
  late TaskEngine tasks;
  late PhraseService phrases;
  late PetProgress progress;
  late GrowthService growth;
  late TitleService titles;
  late LevelService levels;
  late List<LevelRecord> levelHistory;
  LevelRun? levelRun;
  DateTime? dailyDoneAt;
  late DayEventPicker eventPicker;
  late Map<int, String> eventChoices;
  late Map<PlanDirection, int> planExtra;
  late List<Map<String, dynamic>> dayHistory;
  List<StatShift> lastShifts = const [];
  late Set<String> dailyHistory;
  Map<String, Object?>? dailyRun;
  late int _day;
  Map<String, dynamic>? celebration;
  PetStage get stage => progress.stage;
  late Set<String> wishlist;
  late Map<String, String> outfit;
  late List<String> legacyCompletedTasks;
  late Map<String, int> bestStars;
  late Set<String> seenTutorials;
  late Set<String> seenCoach;
  late Map<String, String> placed;
  late Set<String> seenItems;
  late Set<String> knownWords;
  late Map<String, int> playCounts;
  late Set<String> passedVariants;
  late bool motion, simpleMode, onboarded, sound;
  late String petName;
  PhraseLine? bubble;
  String? storageError;
  bool _disposed = false;
  Timer? _bubbleTimer;
  Future<void> _pending = Future.value();

  static Future<GameController> load() async {
    final config = await GameContent.load();
    final content = await const ContentLoader().loadAll();
    final repository = LocalGameRepository();
    return GameController(config,
        content: content,
        saved: await repository.load(),
        repository: repository);
  }

  void _restore(Map<String, dynamic>? saved) {
    final data = {...config, ...?saved};
    _day = data['day'] as int;
    celebration = (data['celebration'] as Map?)?.cast<String, dynamic>();
    final journal = [
      for (final t in data['journal'] as List? ?? [])
        Transaction.fromJson((t as Map).cast<String, Object?>())
    ];
    wallet = WalletService(
        initial: Wallet.create(
            balance: data['balance'] as int, savings: data['savings'] as int),
        journal: journal);
    final params = content.economy.params;
    if (saved == null) {
      final opening = wallet.wallet.balance;
      wallet = WalletService(
          initial: Wallet.create(balance: 0, savings: wallet.wallet.savings));
      if (opening > 0) {
        wallet.earn(
            amount: opening,
            sourceId: 'day_income',
            reasonText: params.day.incomeReason,
            at: clock.now(),
            dayNumber: day);
      }
    }
    stats = PetState.fromJson((data['stats'] as Map).cast<String, Object?>());
    motion = data['motion'] != false;
    sound = data['sound'] != false;
    simpleMode = data['simpleMode'] != false;
    onboarded = data['onboarded'] == true;
    petName = data['petName'] as String? ?? 'Мони';
    growth = GrowthService(content.economy.growth);
    titles = TitleService.forContent(content.titles,
        tasks: content.tasks, shop: content.shop);
    final storedProgress = data['petProgress'] as Map?;
    if (storedProgress != null) {
      progress = PetProgress.fromJson(storedProgress.cast<String, Object?>());
    } else {
      final oldStage = PetStage.values.firstWhere(
          (s) => s.name == data['stage'],
          orElse: () => PetStage.baby);
      progress = PetProgress.create(
          growthPoints: oldStage == PetStage.egg || oldStage == PetStage.baby
              ? 0
              : growth.rules.thresholds[oldStage]!,
          stage: oldStage == PetStage.egg ? PetStage.baby : oldStage);
    }
    if (progress.stage == PetStage.egg) {
      progress = progress.copyWith(stage: PetStage.baby);
    }
    progress = titles.start(progress);
    plan = _newPlan();
    final amounts = data['plan'] as Map;
    for (final d in PlanDirection.values) {
      plan.setAmount(d, amounts[d.name] as int);
    }
    if (data['confirmed'] == true) plan.confirm();
    wishlist = {...(data['wishlist'] as List? ?? []).cast<String>()};
    outfit = (data['outfit'] as Map? ?? {}).cast<String, String>();
    legacyCompletedTasks =
        (data['legacyCompletedTasks'] as List? ?? []).cast<String>();
    final owned = [
      for (final id in (data['owned'] as List? ?? []).cast<String>())
        _legacyItems[id] ?? id
    ];
    shop = ShopService(
      catalog: content.shop,
      wallet: wallet,
      owned: owned,
      activeWallpaperId: data['wallpaper'] as String?,
      dayNumber: day,
      stage: stage,
    );
    final reached = (data['reachedGoals'] as List? ?? []).cast<String>();
    final savedGoal = saved != null && saved.containsKey('goalId')
        ? saved['goalId'] as String?
        : (config['goal'] as Map?)?['id'] as String?;
    final goalId = savedGoal != null &&
            content.goals.byId(savedGoal) != null &&
            !reached.contains(savedGoal)
        ? savedGoal
        : null;
    goals = GoalService(
      catalog: content.goals,
      wallet: wallet,
      selectedGoalId: goalId,
      reachedGoalIds: reached,
      dayNumber: day,
    );
    tasks = TaskEngine(
      catalog: content.tasks,
      rewards: params.tasks,
      completedTaskIds: (data['completedTasks'] as List? ?? []).cast<String>(),
    );
    bestStars = (data['bestStars'] as Map? ?? {}).cast<String, int>();
    seenTutorials = {...(data['seenTutorials'] as List? ?? []).cast<String>()};
    final coachSeen = data['seenCoach'] as List?;
    seenCoach = coachSeen != null
        ? {...coachSeen.cast<String>()}
        : {if (onboarded) _allCoach};
    final passed = data['passedVariants'] as List?;
    passedVariants = passed != null
        ? {...passed.cast<String>()}
        : {
            for (final id in tasks.completedTaskIds)
              if (content.tasks.byId(id) case final task?)
                task.variantKey(TaskDifficulty.easy, 0)
          };
    levels = LevelService(levels: content.levels, tasks: content.tasks);
    levelHistory = [
      for (final raw in data['levelHistory'] as List? ?? [])
        LevelRecord.fromJson((raw as Map).cast<String, Object?>())
    ];
    final storedRun = data['levelRun'] as Map?;
    final run = storedRun == null
        ? null
        : LevelRun.fromJson(storedRun.cast<String, Object?>());
    levelRun = run != null &&
            levels.fits(run) &&
            !run.isFinished &&
            run.number == levelHistory.length + 1
        ? run
        : null;
    eventPicker = DayEventPicker(
        schedule: params.events, catalog: content.events);
    eventChoices = {
      for (final e in (data['eventChoices'] as Map? ?? {}).entries)
        int.parse('${e.key}'): '${e.value}'
    };
    final extra = (data['planExtra'] as Map? ?? {}).cast<String, Object?>();
    planExtra = {
      for (final d in PlanDirection.values) d: (extra[d.name] as int?) ?? 0
    };
    dayHistory = [
      for (final raw in data['dayHistory'] as List? ?? [])
        (raw as Map).cast<String, dynamic>()
    ];
    final doneAt = data['dailyDoneAt'] as String?;
    dailyDoneAt = doneAt == null ? null : DateTime.tryParse(doneAt);
    dailyHistory = {...(data['dailyHistory'] as List? ?? []).cast<String>()};
    dailyRun = (data['dailyRun'] as Map?)?.cast<String, Object?>();
    final storedPlaced = data['placed'] as Map?;
    placed = storedPlaced != null
        ? {
            for (final e in storedPlaced.cast<String, String>().entries)
              if (_spot(e.key)?.accepts.contains(e.value) ?? false)
                e.key: e.value
          }
        : {
            for (final item in ownedItems)
              if (room.spotFor(item.id) case final spot?
                  when spot.type == RoomSpotType.item)
                spot.id: item.id
          };
    final storedSeen = data['seenItems'] as List?;
    seenItems = storedSeen != null
        ? {...storedSeen.cast<String>()}
        : {for (final item in ownedItems) item.id};
    knownWords = {...(data['knownWords'] as List? ?? []).cast<String>()};
    playCounts = (data['playCounts'] as Map? ?? {}).cast<String, int>();
    phrases = PhraseService(
        catalog: content.phrases, clock: clock, character: character);
  }

  int get day => _day;

  RoomDef get room =>
      content.rooms.rooms.firstWhere((r) => r.enabled);

  RoomSpot? _spot(String id) {
    for (final spot in room.spots) {
      if (spot.id == id) return spot;
    }
    return null;
  }

  List<RoomSpot> get itemSpots => [
        for (final spot in room.spots)
          if (spot.type == RoomSpotType.item) spot
      ];

  ShopItem? placedAt(RoomSpot spot) {
    final id = placed[spot.id];
    return id == null || !shop.isOwned(id) ? null : content.shop.byId(id);
  }

  Goal? goalAt(RoomSpot spot) {
    Goal? found;
    for (final id in goals.reachedGoalIds) {
      if (spot.accepts.contains(id)) found = content.goals.byId(id) ?? found;
    }
    return found;
  }

  List<ShopItem> spotItems(RoomSpot spot) => [
        for (final id in spot.accepts)
          if (content.shop.byId(id) case final item?) item
      ];

  bool canFill(RoomSpot spot) =>
      spot.accepts.any((id) => shop.isOwned(id));

  void place(RoomSpot spot, String? itemId) {
    if (itemId == null) {
      placed.remove(spot.id);
    } else {
      if (!spot.accepts.contains(itemId) || !shop.isOwned(itemId)) return;
      placed[spot.id] = itemId;
    }
    changed();
  }

  List<ShopItem> get wallpapers => [
        for (final item in content.shop.items)
          if (item.kind == ShopItemKind.wallpaper) item
      ];

  String get wallpaperId =>
      shop.activeWallpaperId ?? room.defaultWallpaperId;

  void applyWallpaper(String id) {
    if (shop.applyWallpaper(id)) changed();
  }

  bool get roomEmpty =>
      placed.isEmpty &&
      outfit.isEmpty &&
      wallpaperId == room.defaultWallpaperId;

  bool _roomThing(ShopItem item) =>
      item.slot.isNotEmpty ||
      item.kind == ShopItemKind.wallpaper ||
      room.spotFor(item.id) != null;

  bool get hasNewThings => ownedItems
      .any((item) => _roomThing(item) && !seenItems.contains(item.id));

  void markThingsSeen() {
    final before = seenItems.length;
    seenItems = {...seenItems, for (final item in ownedItems) item.id};
    if (seenItems.length != before) changed();
  }

  void knowWord(String id, bool known) {
    knownWords = known ? {...knownWords, id} : ({...knownWords}..remove(id));
    changed();
  }

  int timesPlayed(TaskDef task) =>
      math.max(playCounts[task.id] ?? 0, passedOf(task));

  GrowthStatus get growthStatus => growth.status(progress);
  TitleDef? get currentTitle => titles.current(progress);

  DayFacts get dayFacts => DayFacts.fromDay(
        GameDay.create(
            number: day,
            income: fullPlan.income,
            plan: fullPlan,
            planConfirmed: plan.isConfirmed,
            transactions: wallet.journal),
        mandatoryItemIds: const [],
        mandatoryOptions: [for (final need in todayNeeds) need.itemIds],
      );

  List<PetNeed> get todayNeeds => content.economy.pet.needsOn(day, stage);

  Set<String> get boughtToday => {
        for (final t in wallet.journal)
          if (t.dayNumber == day &&
              t.type == TransactionType.expense &&
              t.sourceId.startsWith('shop:'))
            t.sourceId.substring(5)
      };

  List<ShopItem> needOptions(PetNeed need) {
    final visible = {for (final item in catalog) item.id};
    final items = [
      for (final id in need.itemIds)
        if (content.shop.byId(id) case final item?)
          if (visible.contains(id)) item
    ];
    items.sort((a, b) => a.price.compareTo(b.price));
    return items;
  }

  ShopItem? boughtFor(PetNeed need) {
    final bought = boughtToday;
    for (final id in need.itemIds) {
      if (bought.contains(id)) return content.shop.byId(id);
    }
    return null;
  }

  PetNeed? needOf(ShopItem item) => content.economy.pet.needFor(item.id);

  String needTitle(PetNeed need) => fillTemplate(
      need.occasion?.title ?? need.title, {'name': petName});

  void chooseTitle(String id) {
    progress = titles.choose(progress, id);
    changed();
  }

  void acknowledgeCelebration() {
    celebration = null;
    changed();
  }

  bool closeDay(int expectedDay) {
    if (expectedDay != day || celebration != null) return false;
    final facts = dayFacts;
    final result = growth.closeDay(progress, facts);
    if (!result.counted) return false;
    final awarded = titles.award(
        result.progress,
        TitleFacts.create(
            dayNumber: day,
            completedTaskIds: tasks.completedTaskIds,
            reachedGoalIds: goals.reachedGoalIds,
            savings: wallet.wallet.savings));
    final pet = PetStateService(
        rules: content.economy.pet, initial: stats, dayNumber: day);
    final night = pet.closeDay(
        stage: stage,
        boughtItemIds: wallet.journal
            .where((t) =>
                t.dayNumber == day &&
                t.type == TransactionType.expense &&
                t.sourceId.startsWith('shop:'))
            .map((t) => t.sourceId.substring(5)),
        ownedItems:
            content.shop.items.where((item) => owned.contains(item.id)));
    final summary =
        DaySummaryService(templates: content.summaries.explain).build(
      day: GameDay.create(
          number: day,
          income: fullPlan.income,
          plan: fullPlan,
          planConfirmed: plan.isConfirmed,
          transactions: wallet.journal),
      before: stats,
      after: night.after,
      growthPoints: result.day.points,
      petName: petName,
      savedTotal: wallet.wallet.savings,
    );
    final rows = [
      for (final row in planFactRows) [row.$1, row.$2, row.$3]
    ];
    progress = awarded.progress;
    stats = night.after;
    final status = growth.status(progress);
    final thresholds = content.economy.growth.thresholds;
    final dayTransactions =
        wallet.journal.where((t) => t.dayNumber == day).toList();
    int total(TransactionType type) => dayTransactions
        .where((t) => t.type == type)
        .fold(0, (sum, t) => sum + t.amount);
    final shifts = <PetStat, List<int>>{};
    final reasons = <String>[];
    for (final change in night.changes) {
      final shift = shifts[change.stat];
      if (shift == null) {
        shifts[change.stat] = [change.before, change.after];
      } else {
        shift[1] = change.after;
      }
      if (!reasons.contains(change.reasonText)) reasons.add(change.reasonText);
    }
    celebration = {
      'kind': 'night',
      'day': day,
      'earned': total(TransactionType.income),
      'spent': total(TransactionType.expense),
      'rows': rows,
      'explain': summary.explainText,
      'factors': [
        for (final line in growth.lines(result.day))
          {
            'id': line.factor.name,
            'met': line.met,
            'points': line.points,
            'text': line.text,
          }
      ],
      'growthPoints': status.points,
      'stageFrom': thresholds[status.stage] ?? 0,
      'nextAt': status.next == null ? null : thresholds[status.next],
      'nextLabel': status.nextLabel,
      'night': [
        for (final entry in shifts.entries)
          if (entry.value[0] != entry.value[1])
            {
              'stat': entry.key.name,
              'before': entry.value[0],
              'after': entry.value[1],
            }
      ],
      'nightReasons': reasons,
      'stageUp': result.stageUp != null,
      'from': result.day.stageBefore.name,
      'to': stage.name,
      'headline':
          result.stageUp == null ? 'День $day завершён' : '$petName подрос!',
      'reason': result.stageUp?.reasonText ?? summary.explainText,
      'points': result.day.points,
      'lines': growth.lines(result.day).map((line) => line.text).toList(),
      'changes': night.changes
          .map((change) => '${pet.describe(change)}. ${change.reasonText}')
          .toList(),
      'titles': awarded.earned.map((title) => title.title.id).toList(),
    };
    dayHistory = <Map<String, dynamic>>[
      {
        'day': day,
        'rows': rows,
        'explain': summary.explainText,
        'points': result.day.points,
        'lines': celebration!['lines'],
        'changes': celebration!['changes'],
        'stageUp': result.stageUp == null ? null : stageLabel,
        'titles': [
          for (final earned in awarded.earned) earned.title.title
        ],
        if (todayEvent case final event?)
          'event': event.title,
      },
      ...dayHistory,
    ].take(30).toList();
    _day++;
    shop.setStage(stage);
    shop.startDay(day);
    goals.startDay(day);
    final params = content.economy.params;
    plan = _newPlan();
    planExtra = {for (final d in PlanDirection.values) d: 0};
    wallet.earn(
        amount: params.day.income,
        sourceId: 'day_income',
        reasonText: params.day.incomeReason,
        at: clock.now(),
        dayNumber: day);
    changed();
    return true;
  }

  PlanService _newPlan() => PlanService(
      income: content.economy.params.day.income,
      step: content.economy.params.plan.step,
      mandatoryCost: mandatoryCost);

  int get earnedToday => wallet.journal
      .where((t) =>
          t.dayNumber == day &&
          t.type == TransactionType.income &&
          t.sourceId != 'day_income')
      .fold(0, (sum, t) => sum + t.amount);

  int get extraPlanned => planExtra.values.fold(0, (a, b) => a + b);

  int get extraPending {
    final left = earnedToday - extraPlanned;
    return left < 0 ? 0 : left;
  }

  BudgetPlan get fullPlan {
    final base = plan.plan;
    return BudgetPlan.create(
      mandatory: base.mandatory + planExtra[PlanDirection.mandatory]!,
      optional: base.optional + planExtra[PlanDirection.optional]!,
      savings: base.savings + planExtra[PlanDirection.savings]!,
      income: base.income + extraPlanned,
    );
  }

  bool planEarned(Map<PlanDirection, int> parts) {
    final total = parts.values.fold(0, (a, b) => a + b);
    if (total <= 0 ||
        total > extraPending ||
        parts.values.any((value) => value < 0)) {
      return false;
    }
    planExtra = {
      for (final d in PlanDirection.values) d: planExtra[d]! + (parts[d] ?? 0)
    };
    say('plan_confirmed');
    changed();
    return true;
  }

  int _spentToday(ExpenseCategory category) => wallet.journal
      .where((t) =>
          t.dayNumber == day &&
          t.type == TransactionType.expense &&
          t.category == category)
      .fold(0, (sum, t) => sum + t.amount);

  int get _savedToday => wallet.journal
      .where((t) => t.dayNumber == day)
      .fold(
          0,
          (sum, t) =>
              sum +
              (t.type == TransactionType.toSavings
                  ? t.amount
                  : t.type == TransactionType.fromSavings
                      ? -t.amount
                      : 0));

  int planLeft(PlanDirection direction) {
    final full = fullPlan;
    return switch (direction) {
      PlanDirection.mandatory =>
        full.mandatory - _spentToday(ExpenseCategory.mandatory),
      PlanDirection.optional =>
        full.optional - _spentToday(ExpenseCategory.optional),
      PlanDirection.savings => full.savings - _savedToday,
    };
  }

  int get savingsToDeposit {
    final left = planLeft(PlanDirection.savings);
    final balance = wallet.wallet.balance;
    if (left <= 0 || balance <= 0) return 0;
    return left < balance ? left : balance;
  }

  bool saveByPlan() => saveCoins(savingsToDeposit);

  int get savedToday => _savedToday;

  bool get wantBought => _spentToday(ExpenseCategory.optional) > 0;

  PlanCheck planCheck(ShopItem item) {
    final direction = item.category == ExpenseCategory.mandatory
        ? PlanDirection.mandatory
        : PlanDirection.optional;
    final raw = planLeft(direction);
    final left = raw < 0 ? 0 : raw;
    final gap = item.price > left ? item.price - left : 0;
    var needsShort = 0;
    if (direction == PlanDirection.optional) {
      final needs = unpaidNeedsCost;
      final after = wallet.wallet.balance - item.price;
      if (needs > after) needsShort = needs - after;
    }
    final perDay = fullPlan.savings;
    final delay = direction == PlanDirection.optional && gap > 0 && perDay > 0
        ? (gap + perDay - 1) ~/ perDay
        : 0;
    return PlanCheck(
      direction: direction,
      price: item.price,
      left: left,
      gap: gap,
      needsShort: needsShort,
      delayDays: delay,
    );
  }

  List<(String, int, int)> get planFactRows {
    final full = fullPlan;
    return [
      ('Обязательное', full.mandatory, _spentToday(ExpenseCategory.mandatory)),
      ('Желаемое', full.optional, _spentToday(ExpenseCategory.optional)),
      ('Копилка', full.savings, _savedToday),
    ];
  }

  PetStage _stageOn(int dayNumber) {
    var result = PetStage.baby;
    for (final closed in progress.growthDays) {
      if (closed.dayNumber >= dayNumber) break;
      result = closed.stageAfter;
    }
    return result.index < PetStage.baby.index ? PetStage.baby : result;
  }

  GameEventDef? get todayEvent => eventPicker.pick(day, _stageOn);

  bool get eventPending =>
      todayEvent != null && !eventChoices.containsKey(day);

  String get eventHeader => content.events.texts['header']!;

  String eventText(String key, [Map<String, String> values = const {}]) =>
      fillPlurals(fillTemplate(content.events.texts[key] ?? '', values));

  void openEvent() {
    final event = todayEvent;
    if (event != null && eventPending) {
      say('event_start', facts: {'eventId': event.id});
    }
  }

  EventOutcome? resolveEvent(String optionId) {
    final event = todayEvent;
    if (event == null || !eventPending) return null;
    final option = event.option(optionId);
    if (option == null) return null;
    final now = clock.now();
    if (option.cost > 0) {
      final paid = wallet.spend(
          amount: option.cost,
          itemId: 'event_${event.id}',
          category: ExpenseCategory.optional,
          reasonText: option.journalText,
          at: now,
          dayNumber: day);
      if (paid is WalletNotEnough) {
        return EventShort(
            gap: paid.gap, text: eventText('notEnough', {'gap': '${paid.gap}'}));
      }
    } else if (option.coins > 0) {
      wallet.earn(
          amount: option.coins,
          sourceId: 'event:${event.id}',
          reasonText: option.journalText,
          at: now,
          dayNumber: day);
    }
    final shifts = _applyEffects(option.effects);
    eventChoices = {...eventChoices, day: option.id};
    say('event_resolved', facts: {'eventId': event.id});
    changed();
    return EventResolved(
        option: option, text: fillPlurals(option.resultText), shifts: shifts);
  }

  List<StatShift> _applyEffects(Iterable<StateEffect> effects) {
    final shifts = <StatShift>[];
    for (final effect in effects) {
      final before = stats.of(effect.stat);
      stats = stats.apply(effect.stat, effect.delta);
      final after = stats.of(effect.stat);
      final index = shifts.indexWhere((s) => s.stat == effect.stat);
      if (index >= 0) {
        shifts[index] = StatShift(effect.stat, shifts[index].before, after);
      } else {
        shifts.add(StatShift(effect.stat, before, after));
      }
    }
    return [
      for (final shift in shifts)
        if (shift.delta != 0) shift
    ];
  }

  List<PetNeed> get missingNeeds {
    final bought = boughtToday;
    return [
      for (final need in todayNeeds)
        if (!need.metBy(bought)) need
    ];
  }

  List<ShopItem> get unpaidNeeds => [
        for (final need in missingNeeds)
          if (content.shop.byId(need.itemId) case final item?) item
      ];

  int get unpaidNeedsCost => missingNeeds.fold(0, (sum, need) {
        final options = needOptions(need);
        final price = options.isEmpty
            ? content.shop.byId(need.itemId)?.price ?? 0
            : options.first.price;
        return sum + price;
      });

  bool get _needsAffordable => missingNeeds.any((need) {
        final options = needOptions(need);
        return options.isNotEmpty &&
            options.first.price <= wallet.wallet.balance;
      });

  List<BedtimeTodo> get bedtimeTodos {
    final affordable = _needsAffordable;
    return [
      if (!plan.isConfirmed || extraPending > 0) BedtimeTodo.plan,
      if (affordable) BedtimeTodo.needs,
      if (!levelDoneToday || dailyAvailable) BedtimeTodo.task,
      if (eventPending) BedtimeTodo.event,
    ];
  }

  bool get bedtimeReady => bedtimeTodos.isEmpty;

  String get bedtimeHint {
    final todos = bedtimeTodos;
    final texts = content.economy.bedtime;
    if (todos.isEmpty) return texts.ready;
    final first = todos.first;
    if (first == BedtimeTodo.plan && plan.isConfirmed) {
      return 'Разложим заработанные монеты по плану.';
    }
    return fillTemplate(texts.todos[first]!, {'items': _itemsText(unpaidNeeds)});
  }

  String? get bedtimeReminder {
    final unpaid = unpaidNeeds;
    if (unpaid.isEmpty) return null;
    final texts = content.economy.bedtime;
    final canShop = _needsAffordable;
    return fillTemplate(canShop ? texts.reminder : texts.shortOfMoney,
        {'items': _itemsText(unpaid)});
  }

  bool get bedtimeCanShop => _needsAffordable;

  String _itemsText(List<ShopItem> items) =>
      items.map((item) => item.titleAccusative).join(', ');

  int get mandatoryCost => todayNeeds.fold(
      0, (sum, need) => sum + (content.shop.byId(need.itemId)?.price ?? 0));

  TaskDifficulty get difficulty =>
      simpleMode ? TaskDifficulty.easy : TaskDifficulty.hard;

  Set<String> get owned => shop.owned;

  String? get equipped => outfit['head'];

  List<ShopItem> get catalog => shop.showcase();

  Goal? get currentGoal => goals.current;
  GoalView? get goalView => goals.view();
  String get goal => currentGoal?.title ?? 'выбери мечту';
  String? get goalId => currentGoal?.id;
  int get target => currentGoal?.price ?? 0;
  int get left => currentGoal?.left ?? 0;
  int? get daysToGoal => goals.eta().days;
  int? get daysWithPlan {
    final goal = currentGoal;
    final perDay = plan.plan.savings;
    if (goal == null || perDay <= 0) return null;
    return (goal.left + perDay - 1) ~/ perDay;
  }

  String get stageLabel =>
      content.economy.growth.texts.stageLabels[stage] ?? stage.name;

  List<ShopItem> get ownedItems => [
        for (final item in content.shop.items)
          if (shop.isOwned(item.id) && item.showInShop) item
      ];

  List<Goal> get reachedGoals => [
        for (final id in goals.reachedGoalIds)
          if (content.goals.byId(id) != null) content.goals.byId(id)!
      ];

  bool get needsPlan => !plan.isConfirmed;

  int get levelsDone => levelHistory.length;

  int get levelNumber => levelRun?.number ?? levelsDone + 1;

  bool get levelDoneToday =>
      levelHistory.isNotEmpty && levelHistory.last.day == day;

  int get reachedLevel => levelDoneToday ? levelsDone : levelNumber;

  bool get canEarnFromGames => !levelDoneToday;

  LevelRun get upcomingLevel =>
      levelRun ??
      levels.plan(levelNumber, simple: simpleMode, history: levelHistory);

  LevelRecord? get todayLevel => levelDoneToday ? levelHistory.last : null;

  bool isGameUnlocked(String taskId) =>
      tasks.isCompleted(taskId) || levels.unlockLevelOf(taskId) <= levelsDone;

  List<TaskDef> get practiceGames => [
        for (final task in content.tasks.tasks)
          if (isGameUnlocked(task.id)) task
      ];

  String get todayKey => LevelService.dateKey(clock.now());

  DailyRules get dailyRules => content.levels.daily;

  bool get dailyDoneToday {
    final last = dailyDoneAt;
    return last != null && !clock.isNewCalendarDay(last);
  }

  TaskDef? get dailyTask {
    final pinned = dailyRun;
    if (pinned != null && pinned['date'] == todayKey) {
      final task = content.tasks.byId(pinned['taskId'] as String);
      if (task != null) return task;
    }
    return levels.dailyPick(clock.now(), practiceGames);
  }

  bool get dailyUnlocked => dailyTask != null;

  int get dailyCoinsToday => wallet.journal
      .where((t) => t.sourceId == 'task:daily_$todayKey')
      .fold(0, (sum, t) => sum + t.amount);

  bool get dailyAvailable => dailyUnlocked && !dailyDoneToday;

  TaskDef? startDaily() {
    if (!dailyAvailable) return null;
    final task = dailyTask!;
    final pinned = dailyRun;
    if (pinned == null ||
        pinned['date'] != todayKey ||
        pinned['taskId'] != task.id) {
      dailyRun = {'date': todayKey, 'taskId': task.id};
      changed();
    }
    return task;
  }

  TaskSession startDailyGame() {
    final pinned = dailyRun;
    if (pinned == null || pinned['date'] != todayKey) {
      throw StateError('задание дня не начато');
    }
    return _start(pinned['taskId'] as String, TaskDifficulty.hard, TaskPool.daily);
  }

  GameReward finishDaily(TaskSession session) {
    if (dailyDoneToday) throw StateError('задание дня уже выполнено');
    final played = _afterGame(session);
    final coins = dailyRules.coins +
        (played.withMistakes ? 0 : dailyRules.perfectBonus);
    final now = clock.now();
    wallet.earn(
        amount: coins,
        sourceId: 'task:daily_${LevelService.dateKey(now)}',
        reasonText: levels.dailyReasonOf(session.task.title),
        at: now,
        dayNumber: day);
    dailyDoneAt = now;
    dailyHistory = {...dailyHistory, LevelService.dateKey(now)};
    dailyRun = null;
    say('task_done',
        facts: {'firstTry': !played.withMistakes}, values: {'reward': coins});
    changed();
    return GameReward(
      coins: coins,
      firstTime: played.firstTime,
      withMistakes: played.withMistakes,
      stars: played.stars,
    );
  }

  int unlockLevelOf(String taskId) => levels.unlockLevelOf(taskId);

  TaskDef? get nextUnlock => levels.nextUnlock(reachedLevel);

  LevelRun? startLevel() {
    if (levelDoneToday) return null;
    final run = levelRun;
    if (run != null) return run;
    levelRun = upcomingLevel;
    changed();
    return levelRun;
  }

  TaskSession startLevelGame() {
    final slot = levelRun?.current;
    if (slot == null) throw StateError('уровень не начат');
    return _start(slot.taskId, slot.difficulty, TaskPool.level);
  }

  LevelStep finishLevelGame(TaskSession session) {
    final run = levelRun;
    if (run == null || run.current?.taskId != session.task.id) {
      throw StateError('эта игра не из текущего уровня');
    }
    final played = _afterGame(session);
    final share = run.shareOf(run.done);
    wallet.earn(
        amount: share,
        sourceId: 'task:${session.task.id}',
        reasonText: levels.rewardReasonOf(run.number, session.task.title),
        at: clock.now(),
        dayNumber: day);
    final reward = GameReward(
      coins: share,
      firstTime: played.firstTime,
      withMistakes: played.withMistakes,
      stars: played.stars,
    );
    final next = run.withStars(reward.stars);
    LevelRecord? finished;
    if (next.isFinished) {
      finished = LevelRecord(
        number: next.number,
        day: day,
        taskIds: [for (final slot in next.slots) slot.taskId],
        stars: next.stars,
        coins: next.coins,
      );
      levelHistory = [...levelHistory, finished];
      levelRun = null;
      say('task_done',
          facts: {'firstTry': next.stars.every((star) => star == 3)},
          values: {'reward': next.coins});
    } else {
      levelRun = next;
      say('task_done',
          facts: {'firstTry': !reward.withMistakes},
          values: {'reward': share});
    }
    changed();
    return LevelStep(reward: reward, finished: finished);
  }

  int starsOf(String taskId) => bestStars[taskId] ?? 0;

  int passedOf(TaskDef task) =>
      task.variantKeys.where(passedVariants.contains).length;

  int nextIndex(TaskDef task, TaskDifficulty level,
      [TaskPool pool = TaskPool.practice]) {
    final count = task.variantsIn(pool, level).length;
    for (var i = 0; i < count; i++) {
      if (!passedVariants.contains(task.keyIn(pool, level, i))) return i;
    }
    return (day + task.order) % count;
  }

  TaskSession _start(String taskId, TaskDifficulty level,
      [TaskPool pool = TaskPool.practice]) {
    final task = content.tasks.byId(taskId);
    return tasks.start(taskId, level,
        pool: pool, index: task == null ? 0 : nextIndex(task, level, pool));
  }

  List<TutorialStep> tutorialFor(TaskDef task) =>
      content.tasks.tutorialFor(task);

  bool tutorialSeen(String taskId) => seenTutorials.contains(taskId);

  void markTutorialSeen(String taskId) {
    if (seenTutorials.add(taskId)) changed();
  }

  static const String _allCoach = '*';

  CoachCatalog get coach => content.coach;

  bool coachSeen(String id) => seenCoach.contains(_allCoach) || seenCoach.contains(id);

  void markCoachSeen(Iterable<String> ids) {
    var added = false;
    for (final id in ids) {
      added = seenCoach.add(id) || added;
    }
    if (added) changed();
  }

  void resetCoach() {
    seenCoach.clear();
    seenTutorials.clear();
    changed();
  }

  List<TutorialStep> gameCoach(TaskDef task, {required bool first}) {
    final intro = first && !coachSeen('game');
    return [
      if (intro) ...coach.gameFirst,
      ...tutorialFor(task),
      if (intro) ...coach.gameLast,
    ];
  }

  void changePlan(PlanDirection d, int delta) {
    if (plan.isConfirmed) return;
    delta > 0 ? plan.increase(d) : plan.decrease(d);
    changed();
  }

  void confirmPlan() {
    if (!plan.isConfirmed) {
      plan.confirm();
      say('plan_confirmed');
      changed();
    }
  }

  ShopItemView viewOf(ShopItem item) => shop.view(item);

  PurchaseOutcome askToBuy(String itemId) => shop.askToBuy(itemId);

  PurchaseOutcome confirmPurchase(PurchaseConfirm confirmation) {
    final outcome = shop.confirm(confirmation,
        at: clock.now(), hasUnusedTasksToday: canEarnFromGames);
    switch (outcome) {
      case PurchaseDone(:final item, :final effects, wallet: final after):
        lastShifts = _applyEffects(effects);
        wishlist.remove(item.id);
        say('purchase_done', facts: {
          'itemId': item.id,
          'itemGroup': item.group,
          'itemKind': item.kind.name,
          'balanceAfter': after.balance,
        });
        changed();
      case PurchaseNotEnough(:final gap):
        say('purchase_not_enough', values: {'gap': gap});
        _notify();
      case PurchaseConfirm() || PurchaseRefused():
        break;
    }
    return outcome;
  }

  PurchaseOutcome buyNow(String itemId) {
    final ask = askToBuy(itemId);
    return ask is PurchaseConfirm ? confirmPurchase(ask) : ask;
  }

  GoalOutcome deposit(int amount) {
    final outcome = goals.deposit(amount: amount, at: clock.now());
    if (outcome is GoalDepositDone) {
      if (outcome.justReached) {
        say('goal_reached');
      } else if (outcome.milestoneText != null) {
        say('goal_milestone', facts: {'milestone': _milestoneOf(outcome)});
      } else {
        say('savings_deposit', values: {'amount': amount});
      }
      changed();
    }
    return outcome;
  }

  int _milestoneOf(GoalDepositDone outcome) {
    final percent = outcome.view?.percent ?? 0;
    var reached = 0;
    for (final milestone in content.goals.milestones) {
      if (percent >= milestone) reached = milestone;
    }
    return reached;
  }

  bool saveCoins(int amount) =>
      amount > 0 && deposit(amount) is GoalDepositDone;

  GoalOutcome previewWithdraw(int amount) => goals.previewWithdraw(amount);

  GoalOutcome confirmWithdraw(WithdrawPreview preview) {
    final outcome = goals.withdraw(preview, at: clock.now());
    if (outcome is WithdrawDone) changed();
    return outcome;
  }

  bool withdraw(int amount) {
    if (amount <= 0) return false;
    final preview = previewWithdraw(amount);
    return preview is WithdrawPreview &&
        confirmWithdraw(preview) is WithdrawDone;
  }

  GoalOutcome askGoal(String id) => goals.askToSelect(id);

  GoalOutcome confirmGoal(GoalSelectConfirm confirmation) {
    final outcome = goals.confirmSelect(confirmation);
    if (outcome is GoalSelected) changed();
    return outcome;
  }

  void changeGoal(String id) {
    final ask = askGoal(id);
    if (ask is! GoalSelectConfirm) throw ArgumentError.value(id);
    confirmGoal(ask);
  }

  GoalOutcome claimGoal() {
    final outcome = goals.claim(at: clock.now());
    if (outcome is GoalClaimed) {
      for (final effect in outcome.effects) {
        stats = stats.apply(effect.stat, effect.delta);
      }
      say('goal_reached');
      changed();
    }
    return outcome;
  }

  TaskSession startGame(String taskId) => _start(taskId, difficulty);

  PhraseLine? reactToAnswer(TaskSession session, TaskFeedback feedback) =>
      switch (feedback.verdict) {
        TaskVerdict.correct => say('task_correct'),
        TaskVerdict.wrong =>
          say('task_wrong', facts: {'attempt': session.attempts}),
        TaskVerdict.incomplete => null,
      };

  HintService get hints => HintService(content.tasks.texts.hints);

  PhraseLine? hintFor(TaskSession session) => say('task_hint',
      facts: {'taskType': session.task.type.name.toUpperCase()});

  GameReward finishGame(TaskSession session) {
    final reward = _afterGame(session);
    changed();
    return reward;
  }

  GameReward _afterGame(TaskSession session) {
    final solved = session.isFinished;
    final completion = session.finish();
    if (solved) {
      passedVariants = {...passedVariants, session.variantKey};
      playCounts = {
        ...playCounts,
        completion.taskId: (playCounts[completion.taskId] ?? 0) + 1
      };
    }
    final stars =
        completion.withMistakes ? (completion.attempts > 2 ? 1 : 2) : 3;
    if (stars > starsOf(completion.taskId)) {
      bestStars = {...bestStars, completion.taskId: stars};
    }
    for (final effect
        in content.economy.pet.action(PetRules.taskDone)?.effects ??
            const <StateEffect>[]) {
      stats = stats.apply(effect.stat, effect.delta);
    }
    return GameReward(
      coins: 0,
      firstTime: completion.firstTime,
      withMistakes: completion.withMistakes,
      stars: stars,
    );
  }

  PhraseLine? say(
    String trigger, {
    Map<String, Object?> facts = const {},
    Map<String, Object> values = const {},
  }) {
    final line = phrases.say(trigger,
        facts: {..._facts(), ...facts}, values: {..._values(), ...values});
    if (line == null) return null;
    bubble = line;
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(const Duration(seconds: 6), () {
      if (bubble == line) {
        bubble = null;
        _notify();
      }
    });
    _notify();
    return line;
  }

  void greet() => say('app_open');

  void idle() => say('idle_30s');

  void openShop() => say('shop_open');

  void openPlanner() => say('planner_open');

  void openGames() => say('tasks_screen_open');

  void dismissBubble() {
    bubble = null;
    _notify();
  }

  Map<String, Object?> _facts() {
    final hour = clock.now().hour;
    final goal = currentGoal;
    final rules = content.economy.pet;
    return {
      'timeOfDay': hour < 12
          ? 'morning'
          : hour >= 18
              ? 'evening'
              : 'day',
      'hasGoal': goal != null,
      if (goal != null)
        'goalProgress': goal.price == 0 ? 0 : goal.saved * 100 ~/ goal.price,
      if (rules.isLow(PetStat.satiety, stats.satiety))
        'statLow': 'satiety'
      else if (rules.isLow(PetStat.care, stats.care))
        'statLow': 'care',
      'cozyLevel': content.economy.params.cozyLevels.levelFor(stats.cozy).level,
      'ownsAccessory': ownedItems.any((i) => i.kind == ShopItemKind.accessory),
      'tasksLeftToday': canEarnFromGames ? 1 : 0,
      'savingsPlanned': plan.plan.savings > 0,
      'remainderPositive': plan.remainder > 0,
      'mandatoryShort': plan.hint() != null,
    };
  }

  Map<String, Object> _values() {
    final goal = currentGoal;
    final hint = plan.hint();
    return {
      'income': plan.plan.income,
      'goalGenitive': goal?.titleGenitive ?? 'мечты',
      'days': daysToGoal ?? 0,
      'gap': hint?.gap ?? 0,
      'remainder': plan.remainder,
      'reward': 0,
      'amount': 0,
      'title': stageLabel,
    };
  }

  void postpone(String id) {
    wishlist.add(id);
    say('purchase_postponed');
    changed();
  }

  void equip(String id) {
    final item = content.shop.byId(id);
    if (item == null || !shop.isOwned(id) || item.slot.isEmpty) return;
    if (outfit[item.slot] == id) {
      outfit.remove(item.slot);
    } else {
      outfit[item.slot] = id;
    }
    changed();
  }

  void setMotion(bool value) {
    motion = value;
    changed();
  }

  void setSound(bool value) {
    sound = value;
    changed();
  }

  ({int days, int earned, int mandatory, int optional, int saved}) get report {
    var earned = 0, mandatory = 0, optional = 0, saved = 0;
    final days = <int>{};
    for (final t in wallet.journal) {
      days.add(t.dayNumber);
      switch (t.type) {
        case TransactionType.income:
          earned += t.amount;
        case TransactionType.expense:
          if (t.category == ExpenseCategory.mandatory) {
            mandatory += t.amount;
          } else {
            optional += t.amount;
          }
        case TransactionType.toSavings:
          saved += t.amount;
        case TransactionType.fromSavings:
          if (!t.sourceId.startsWith('goal:')) saved -= t.amount;
      }
    }
    return (
      days: days.isEmpty ? 1 : days.length,
      earned: earned,
      mandatory: mandatory,
      optional: optional,
      saved: saved < 0 ? 0 : saved,
    );
  }

  int habitDays(GrowthFactor factor) =>
      progress.growthDays.where((d) => d.factors.contains(factor)).length;

  void setSimple(bool value) {
    simpleMode = value;
    changed();
  }

  void renamePet(String name) {
    if (petNameProblem(name) != null) throw ArgumentError.value(name);
    petName = normalizePetName(name);
    changed();
  }

  void createPet(String name, bool simple, {String? goalId}) {
    if (petNameProblem(name) != null) throw ArgumentError.value(name);
    if (goalId != null && goalId != this.goalId) {
      final ask = askGoal(goalId);
      if (ask is GoalSelectConfirm) goals.confirmSelect(ask);
    }
    petName = normalizePetName(name);
    simpleMode = simple;
    onboarded = true;
    progress =
        titles.start(PetProgress.create(growthPoints: 0, stage: PetStage.baby));
    shop.setStage(stage);
    celebration = {
      'from': 'egg',
      'to': 'baby',
      'headline': 'Привет, $petName!',
      'reason': 'Теперь будем учиться и расти вместе.',
      'titles': <String>[]
    };
    changed();
  }

  Future<void> deleteProfile() async {
    await _pending;
    await repository.delete();
    _restore(null);
    storageError = null;
    _notify();
  }

  Future<void> resetProfile() async {
    await _pending;
    _restore(null);
    await repository.save(snapshot());
    storageError = null;
    _notify();
  }

  Map<String, dynamic> snapshot() => {
        'schemaVersion': 2,
        'day': day,
        'petProgress': progress.toJson(),
        'celebration': celebration,
        'balance': wallet.wallet.balance,
        'savings': wallet.wallet.savings,
        'plan': {
          'mandatory': plan.plan.mandatory,
          'optional': plan.plan.optional,
          'savings': plan.plan.savings
        },
        'confirmed': plan.isConfirmed,
        'stats': stats.toJson(),
        'journal': [for (final t in wallet.journal) t.toJson()],
        'motion': motion,
        'sound': sound,
        'simpleMode': simpleMode,
        'onboarded': onboarded,
        'petName': petName,
        'stage': stage.name,
        'goalId': goals.current?.id,
        'reachedGoals': goals.reachedGoalIds.toList(),
        'owned': shop.owned.toList(),
        'wallpaper': shop.activeWallpaperId,
        'wishlist': wishlist.toList(),
        'outfit': outfit,
        'completedTasks': tasks.completedTaskIds.toList(),
        'bestStars': bestStars,
        'seenTutorials': seenTutorials.toList(),
        'seenCoach': seenCoach.toList()..sort(),
        'passedVariants': passedVariants.toList()..sort(),
        'levelHistory': [for (final record in levelHistory) record.toJson()],
        'levelRun': levelRun?.toJson(),
        'dailyDoneAt': dailyDoneAt?.toIso8601String(),
        'dailyHistory': dailyHistory.toList()..sort(),
        'dailyRun': dailyRun,
        'eventChoices': {
          for (final e in eventChoices.entries) '${e.key}': e.value
        },
        'planExtra': {for (final e in planExtra.entries) e.key.name: e.value},
        'dayHistory': dayHistory,
        'legacyCompletedTasks': legacyCompletedTasks,
        'placed': placed,
        'seenItems': seenItems.toList()..sort(),
        'knownWords': knownWords.toList()..sort(),
        'playCounts': playCounts,
      };

  void changed() {
    _notify();
    final data = snapshot();
    _pending = _pending.then((_) async {
      try {
        await repository.save(data);
        storageError = null;
      } catch (_) {
        storageError = 'Не удалось сохранить. Повтори попытку перед выходом.';
      }
      _notify();
    });
  }

  Future<void> flush() => _pending;
  void retrySave() => changed();
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _bubbleTimer?.cancel();
    super.dispose();
  }
}

final class PlanCheck {
  const PlanCheck({
    required this.direction,
    required this.price,
    required this.left,
    required this.gap,
    required this.needsShort,
    required this.delayDays,
  });

  final PlanDirection direction;
  final int price;
  final int left;
  final int gap;
  final int needsShort;
  final int delayDays;

  bool get fits => gap == 0;
}
