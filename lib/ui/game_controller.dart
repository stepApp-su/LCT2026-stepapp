import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'pet_appearance.dart';
import 'room_layout.dart';

import '../content/content_loader.dart';
import '../content/content_repository.dart';
import '../content/game_content.dart';
import '../data/game_repository.dart';
import '../data/sound_player.dart';
import '../domain/game_clock.dart';
import 'tap_sound.dart';
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
import '../domain/services/pet_need_service.dart';
import '../domain/services/phrase_service.dart';
import '../domain/services/plan_service.dart';
import '../domain/services/shop_service.dart';
import '../domain/services/sound_service.dart';
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
      GameClock? clock,
      this.sounds,
      this.soundPlayer,
      bool ownsSoundPlayer = false})
      : repository = repository ?? LocalGameRepository(),
        clock = clock ?? RealClock(),
        _ownsSoundPlayer = ownsSoundPlayer {
    _restore(saved);
    TapSound.attach(() {
      fx('tap');
      if (sound && music) soundPlayer?.resumeMusic();
    });
  }

  late PetAppearance appearance;
  String get character => appearance.character;
  PetStat? get currentNeed => currentPetNeed(stats, content.economy.pet);
  bool get petIsSad => currentNeed != null;
  bool get veryHungry => content.economy.pet.isVeryHungry(stats);
  String get hungerText => content.economy.pet.hunger?.text ?? '';
  DateTime? _lastNeedReminder;
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
  late List<Map<String, Object?>> paybacks;
  List<String> news = const [];
  int carefulCount = 0;
  int pocketSaved = 0;
  int pocketNeeds = 0;
  int carried = 0;
  int paidBack = 0;
  late List<Map<String, dynamic>> dayHistory;
  List<StatShift> lastShifts = const [];
  late Set<String> dailyHistory;
  Map<String, Object?>? dailyRun;
  late int _day;
  Map<String, dynamic>? celebration;
  PetStage get stage => progress.stage;
  late Set<String> wishlist;
  late Set<String> hiddenRoomItems;
  late Map<String, String> roomSelection;
  Map<String, String> get visibleRoomItems => resolveRoomItems(
      roomSelection, {...shop.owned, ...goals.reachedGoalIds}, hiddenRoomItems);
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
  late Map<String, int> lastVariants;
  late bool motion, simpleMode, onboarded, sound, music, demoMode;
  String _musicTheme = 'main';
  late String petName;
  PhraseLine? bubble;
  String? storageError;
  bool _disposed = false;
  Timer? _bubbleTimer;
  Future<void> _pending = Future.value();

  // звук опционален: без схемы и плеера (в тестах) все точки молчат
  final SoundService? sounds;
  final SoundPlayer? soundPlayer;
  // чужой плеер (стенд меняет контроллеры на лету) не закрываем
  final bool _ownsSoundPlayer;

  static Future<GameController> load() async {
    const loader = ContentLoader();
    final config = await GameContent.load();
    final content = await loader.loadAll();
    final repository = LocalGameRepository();
    return GameController(config,
        content: content,
        saved: await repository.load(),
        repository: repository,
        sounds: SoundService(scheme: await loader.loadSoundScheme()),
        soundPlayer: SoundPlayer(),
        ownsSoundPlayer: true);
  }

  void _restore(Map<String, dynamic>? saved) {
    _lastNeedReminder = null;
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
    if (saved != null &&
        (data['owned'] as List? ?? []).contains('backpack') &&
        !journal.any((tx) => tx.sourceId == 'refund:backpack')) {
      wallet.earn(
          amount: 35,
          sourceId: 'refund:backpack',
          reasonText: 'Вернули монеты за рюкзак: его больше нет в магазине.',
          at: clock.now(),
          dayNumber: day);
    }
    stats = PetState.fromJson((data['stats'] as Map).cast<String, Object?>());
    motion = data['motion'] != false;
    sound = data['sound'] != false;
    music = data['music'] != false;
    simpleMode = data['simpleMode'] != false;
    demoMode = data['demoMode'] == true;
    onboarded = data['onboarded'] == true;
    appearance = PetAppearance.restore(data['character']);
    petName = data['petName'] as String? ?? appearance.name;
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
    plan = _newPlan(data['planIncome'] as int? ?? params.day.income);
    final amounts = data['plan'] as Map;
    for (final d in PlanDirection.values) {
      plan.setAmount(d, amounts[d.name] as int);
    }
    if (data['confirmed'] == true) plan.confirm();
    wishlist = {...(data['wishlist'] as List? ?? []).cast<String>()}
      ..remove('backpack');
    hiddenRoomItems = {
      ...(data['hiddenRoomItems'] as List? ?? []).cast<String>()
    };
    roomSelection =
        (data['roomSelection'] as Map? ?? {}).cast<String, String>();
    outfit = Map<String, String>.from(data['outfit'] as Map? ?? {})
      ..removeWhere((slot, id) => slot == 'back' || id == 'backpack');
    legacyCompletedTasks =
        (data['legacyCompletedTasks'] as List? ?? []).cast<String>();
    final owned = [
      for (final id in (data['owned'] as List? ?? []).cast<String>())
        if (id != 'backpack') _legacyItems[id] ?? id
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
    )..openAll = demoMode;
    shop.openAll = demoMode;
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
    lastVariants = {
      for (final e in (data['lastVariants'] as Map? ?? {}).entries)
        if (e.value is int) '${e.key}': e.value as int
    };
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
    eventPicker =
        DayEventPicker(schedule: params.events, catalog: content.events);
    eventChoices = {
      for (final e in (data['eventChoices'] as Map? ?? {}).entries)
        int.parse('${e.key}'): '${e.value}'
    };
    paybacks = [
      for (final raw in data['paybacks'] as List? ?? [])
        if (raw is Map &&
            raw['day'] is int &&
            raw['coins'] is int &&
            raw['text'] is String)
          raw.cast<String, Object?>()
    ];
    news = [...(data['news'] as List? ?? []).whereType<String>()];
    carefulCount = data['careful'] as int? ?? 0;
    pocketSaved = data['pocketSaved'] as int? ?? 0;
    pocketNeeds = data['pocketNeeds'] as int? ?? 0;
    carried = data['carried'] as int? ?? 0;
    paidBack = data['paidBack'] as int? ?? 0;
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
    if (storedPlaced == null) {
      placed.removeWhere((_, id) => hiddenRoomItems.contains(id));
      for (final entry in roomSelection.entries) {
        final candidates = roomPlaces[entry.key];
        if (candidates == null) continue;
        placed.removeWhere((_, id) => candidates.contains(id));
        if (candidates.contains(entry.value) &&
            shop.isOwned(entry.value) &&
            !hiddenRoomItems.contains(entry.value)) {
          final spot = room.spotFor(entry.value);
          if (spot != null && spot.type == RoomSpotType.item) {
            placed[spot.id] = entry.value;
          }
        }
      }
    }
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

  RoomDef get room => content.rooms.rooms.firstWhere((r) => r.enabled);

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

  ShopItem? trying;

  bool canTry(ShopItem item) =>
      item.kind == ShopItemKind.wallpaper ||
      item.slot.isNotEmpty ||
      room.spotFor(item.id)?.type == RoomSpotType.item;

  bool canBuyNow(ShopItem item) => shop.refusalFor(item) == null;

  void tryOn(ShopItem? item) {
    if (trying?.id == item?.id) return;
    trying = item == null || canTry(item) ? item : null;
    _notify();
  }

  void keepTried(ShopItem item) {
    if (!shop.isOwned(item.id)) return;
    if (item.slot.isNotEmpty) {
      if (outfit[item.slot] != item.id) equip(item.id);
      return;
    }
    final spot = room.spotFor(item.id);
    if (spot != null && spot.type == RoomSpotType.item) {
      hiddenRoomItems.remove(item.id);
      place(spot, item.id);
    }
  }

  Map<String, String> get wornOutfit {
    final item = trying;
    if (item == null || item.slot.isEmpty) return outfit;
    return {...outfit, item.slot: item.id};
  }

  ShopItem? placedAt(RoomSpot spot) {
    final item = trying;
    if (item != null && room.spotFor(item.id)?.id == spot.id) return item;
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

  bool canFill(RoomSpot spot) => spot.accepts.any((id) => shop.isOwned(id));

  void place(RoomSpot spot, String? itemId) {
    if (itemId == null) {
      placed.remove(spot.id);
    } else {
      if (!spot.accepts.contains(itemId) || !shop.isOwned(itemId)) return;
      placed[spot.id] = itemId;
    }
    fx('equip');
    changed();
  }

  List<ShopItem> get wallpapers => [
        for (final item in content.shop.items)
          if (item.kind == ShopItemKind.wallpaper) item
      ];

  String get wallpaperId => trying?.kind == ShopItemKind.wallpaper
      ? trying!.id
      : shop.activeWallpaperId ?? room.defaultWallpaperId;

  void applyWallpaper(String id) {
    if (shop.applyWallpaper(id)) {
      fx('equip');
      changed();
    }
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

  DayFacts get dayFacts {
    final raw = DayFacts.fromDay(
      GameDay.create(
          number: day,
          income: plan.plan.income,
          plan: plan.plan,
          planConfirmed: plan.isConfirmed,
          transactions: wallet.journal),
      mandatoryItemIds: const [],
      mandatoryOptions: [for (final need in todayNeeds) need.itemIds],
    );
    return DayFacts.create(
      dayNumber: raw.dayNumber,
      plan: raw.plan,
      planConfirmed: raw.planConfirmed,
      spentMandatory: math.max(0, raw.spentMandatory - pocketNeeds),
      spentOptional: raw.spentOptional,
      deposited: math.max(0, raw.deposited - pocketSaved),
      mandatoryPaid: raw.mandatoryPaid,
      tasksDone: raw.tasksDone,
    );
  }

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

  String needTitle(PetNeed need) =>
      fillTemplate(need.occasion?.title ?? need.title, {'name': petName});

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
    final hungry = veryHungry;
    final result = growth.closeDay(progress, facts, hungry: hungry);
    if (!result.counted) return false;
    final awarded = titles.award(
        result.progress,
        TitleFacts.create(
            dayNumber: day,
            completedTaskIds: tasks.completedTaskIds,
            reachedGoalIds: goals.reachedGoalIds,
            savings: wallet.wallet.savings,
            careful: carefulCount));
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
          income: plan.plan.income,
          plan: plan.plan,
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
    final carry = pocket;
    final pocketDay = {
      'earned': earnedToday,
      'saved': pocketSaved,
      'needs': pocketNeeds,
      'carry': carry,
    };
    progress = awarded.progress;
    stats = night.after;
    final status = growth.status(progress);
    final thresholds = content.economy.growth.thresholds;
    final dayTransactions =
        wallet.journal.where((t) => t.dayNumber == day).toList();
    int total(TransactionType type) => dayTransactions
        .where((t) => t.type == type && !t.sourceId.startsWith('goal:'))
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
      'pocket': pocketDay,
      'income': content.economy.params.day.income,
      if (hungry)
        'hungry': fillTemplate(
            content.economy.pet.hunger?.noGrowthText ?? '', {'name': petName}),
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
        'titles': [for (final earned in awarded.earned) earned.title.title],
        if (todayEvent case final event?) 'event': event.title,
        if (earnedToday > 0) 'pocket': pocketDay,
      },
      ...dayHistory,
    ].take(30).toList();
    fx('sleep');
    _day++;
    shop.setStage(stage);
    shop.startDay(day);
    goals.startDay(day);
    final params = content.economy.params;
    final leftover = wallet.wallet.balance;
    wallet.earn(
        amount: params.day.income,
        sourceId: 'day_income',
        reasonText: params.day.incomeReason,
        at: clock.now(),
        dayNumber: day);
    pocketSaved = 0;
    pocketNeeds = 0;
    carried = leftover;
    paidBack = _payBack();
    plan = _newPlan(params.day.income + carried + paidBack);
    changed();
    return true;
  }

  int _payBack() {
    final due = [
      for (final p in paybacks)
        if ((p['day'] as int) <= day) p
    ];
    if (due.isEmpty) return 0;
    paybacks = [
      for (final p in paybacks)
        if ((p['day'] as int) > day) p
    ];
    final lines = <String>[];
    var total = 0;
    for (final p in due) {
      final coins = p['coins'] as int;
      total += coins;
      final text = eventLine(p['text'] as String);
      wallet.earn(
          amount: coins,
          sourceId: 'payback:${p['eventId'] ?? 'event'}',
          reasonText: text,
          at: clock.now(),
          dayNumber: day);
      lines.add(fillPlurals('$text +$coins {coin}'));
    }
    news = [...news, ...lines];
    return total;
  }

  void clearNews() {
    if (news.isEmpty) return;
    news = const [];
    changed();
  }

  int get pendingPayback =>
      paybacks.fold(0, (sum, p) => sum + (p['coins'] as int));

  PlanService _newPlan(int income) => PlanService(
      income: income,
      step: content.economy.params.plan.step,
      mandatoryCost: mandatoryCost);

  static const _plannedSources = ['day_income', 'payback:', 'refund:'];

  int get earnedToday => wallet.journal
      .where((t) =>
          t.dayNumber == day &&
          t.type == TransactionType.income &&
          !_plannedSources.any(t.sourceId.startsWith))
      .fold(0, (sum, t) => sum + t.amount);

  int get pocket {
    final left = earnedToday - pocketSaved - pocketNeeds;
    final balance = wallet.wallet.balance;
    if (left <= 0 || balance <= 0) return 0;
    return left < balance ? left : balance;
  }

  int get freeBalance {
    final free = wallet.wallet.balance - pocket;
    return free < 0 ? 0 : free;
  }

  bool savePocket() {
    final amount = pocket;
    if (amount <= 0) return false;
    pocketSaved += amount;
    if (saveCoins(amount)) return true;
    pocketSaved -= amount;
    return false;
  }

  int _spentToday(ExpenseCategory category) => wallet.journal
      .where((t) =>
          t.dayNumber == day &&
          t.type == TransactionType.expense &&
          t.category == category &&
          !t.sourceId.startsWith('goal:'))
      .fold(0, (sum, t) => sum + t.amount);

  int get _savedByPlan => math.max(0, _savedToday - pocketSaved);

  int get _savedToday => wallet.journal
      .where((t) => t.dayNumber == day && !t.sourceId.startsWith('goal:'))
      .fold(
          0,
          (sum, t) =>
              sum +
              (t.type == TransactionType.toSavings
                  ? t.amount
                  : t.type == TransactionType.fromSavings
                      ? -t.amount
                      : 0));

  int get _spentMandatoryByPlan =>
      math.max(0, _spentToday(ExpenseCategory.mandatory) - pocketNeeds);

  int planLeft(PlanDirection direction) {
    final full = plan.plan;
    return switch (direction) {
      PlanDirection.mandatory => full.mandatory - _spentMandatoryByPlan,
      PlanDirection.optional =>
        full.optional - _spentToday(ExpenseCategory.optional),
      PlanDirection.savings => full.savings - _savedByPlan,
    };
  }

  int get savingsToDeposit {
    final left = planLeft(PlanDirection.savings);
    final balance = freeBalance;
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
    final perDay = plan.plan.savings;
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
    final full = plan.plan;
    return [
      ('Обязательное', full.mandatory, _spentMandatoryByPlan),
      ('Желаемое', full.optional, _spentToday(ExpenseCategory.optional)),
      ('Копилка', full.savings, _savedByPlan),
    ];
  }

  int pocketForNeed(ShopItem item) {
    if (item.category != ExpenseCategory.mandatory) return 0;
    final left = math.max(0, planLeft(PlanDirection.mandatory));
    final gap = item.price - left;
    if (gap <= 0) return 0;
    return math.min(gap, pocket);
  }

  bool blockedByPocket(ShopItem item) =>
      item.category == ExpenseCategory.optional &&
      pocket > 0 &&
      item.price <= wallet.wallet.balance &&
      item.price > freeBalance;

  PetStage _stageOn(int dayNumber) {
    if (demoMode) return PetStage.adult;
    var result = PetStage.baby;
    for (final closed in progress.growthDays) {
      if (closed.dayNumber >= dayNumber) break;
      result = closed.stageAfter;
    }
    return result.index < PetStage.baby.index ? PetStage.baby : result;
  }

  GameEventDef? get todayEvent => eventPicker.pick(day, _stageOn);

  bool get eventPending => todayEvent != null && !eventChoices.containsKey(day);

  String get eventHeader => content.events.texts['header']!;

  String eventText(String key, [Map<String, String> values = const {}]) =>
      fillPlurals(fillTemplate(content.events.texts[key] ?? '', values));

  String eventLine(String text) =>
      fillPlurals(fillTemplate(text, {'pet': petName}));

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
    if (option.fromSavings) {
      final gap = option.cost - wallet.wallet.savings;
      if (gap > 0 || !withdraw(option.cost)) {
        fx('not_enough');
        final shown = gap > 0 ? gap : option.cost;
        return EventShort(
            gap: shown, text: eventText('noSavings', {'gap': '$shown'}));
      }
    }
    if (option.cost > 0) {
      final paid = wallet.spend(
          amount: option.cost,
          itemId: 'event_${event.id}',
          category: ExpenseCategory.optional,
          reasonText: option.journalText,
          at: now,
          dayNumber: day);
      if (paid is WalletNotEnough) {
        fx('not_enough');
        return EventShort(
            gap: paid.gap,
            text: eventText('notEnough', {'gap': '${paid.gap}'}));
      }
      fx('purchase');
    } else if (option.coins > 0) {
      if (!option.toSavings) fx('coin');
      wallet.earn(
          amount: option.coins,
          sourceId: 'event:${event.id}',
          reasonText: option.journalText,
          at: now,
          dayNumber: day);
      if (option.toSavings && saveCoins(option.coins)) {
        pocketSaved += option.coins;
      }
    }
    if (option.payback case final back?) {
      paybacks = [
        ...paybacks,
        {
          'day': day + back.days,
          'coins': back.coins,
          'text': back.text,
          'eventId': event.id,
        }
      ];
    }
    if (option.careful) carefulCount++;
    final shifts = _applyEffects(option.effects);
    eventChoices = {...eventChoices, day: option.id};
    say('event_resolved', facts: {'eventId': event.id});
    changed();
    return EventResolved(
        option: option, text: eventLine(option.resultText), shifts: shifts);
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
      if (!plan.isConfirmed) BedtimeTodo.plan,
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
    return fillTemplate(
        texts.todos[first]!, {'items': _itemsText(unpaidNeeds)});
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
      demoMode ||
      tasks.isCompleted(taskId) ||
      levels.unlockLevelOf(taskId) <= levelsDone;

  bool itemLocked(ShopItem item) => !shop.isUnlocked(item);

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
    return _start(
        pinned['taskId'] as String, TaskDifficulty.hard, TaskPool.daily);
  }

  GameReward finishDaily(TaskSession session) {
    if (dailyDoneToday) throw StateError('задание дня уже выполнено');
    final solved = session.isFinished;
    final played = _afterGame(session);
    if (!solved) {
      _rememberSkip(session);
      fx('retry');
      changed();
      return GameReward(
        coins: 0,
        firstTime: played.firstTime,
        withMistakes: true,
        stars: 0,
      );
    }
    final coins = dailyRules.forStars(played.stars);
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
    fx('task_done');
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

  TaskDef? get nextUnlock =>
      demoMode ? null : levels.nextUnlock(reachedLevel);

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

  void _rememberSkip(TaskSession session) {
    lastVariants = {
      ...lastVariants,
      _variantSlot(session.variantKey): session.index,
    };
  }

  LevelStep finishLevelGame(TaskSession session) {
    final run = levelRun;
    final index = run?.currentIndex;
    if (run == null ||
        index == null ||
        run.slots[index].taskId != session.task.id) {
      throw StateError('эта игра не из текущего уровня');
    }
    final solved = session.isFinished;
    final played = _afterGame(session);
    if (!solved) _rememberSkip(session);
    final pay = run.payFor(index, played.stars);
    if (pay > 0) {
      wallet.earn(
          amount: pay,
          sourceId: 'task:${session.task.id}',
          reasonText: levels.rewardReasonOf(run.number, session.task.title),
          at: clock.now(),
          dayNumber: day);
    }
    final reward = GameReward(
      coins: pay,
      firstTime: played.firstTime,
      withMistakes: played.withMistakes,
      stars: played.stars,
    );
    final next = run.withResult(index, reward.stars);
    LevelRecord? finished;
    if (next.isFinished) {
      finished = LevelRecord(
        number: next.number,
        day: day,
        taskIds: [for (final slot in next.slots) slot.taskId],
        stars: next.stars,
        coins: next.paid,
        salary: next.coins,
        hard: [
          for (final (i, slot) in next.slots.indexed)
            if (slot.isHard) i
        ],
      );
      levelHistory = [...levelHistory, finished];
      levelRun = null;
      fx('level_done');
      say('task_done',
          facts: {'firstTry': next.stars.every((star) => star == 3)},
          values: {'reward': next.paid});
    } else {
      levelRun = next;
      fx(solved ? 'task_done' : 'retry');
      if (solved) {
        say('task_done',
            facts: {'firstTry': !reward.withMistakes}, values: {'reward': pay});
      }
    }
    changed();
    return LevelStep(reward: reward, finished: finished);
  }

  bool canImprove(int index) {
    final record = todayLevel;
    return record != null &&
        index >= 0 &&
        index < record.stars.length &&
        record.stars[index] < 3 &&
        content.tasks.byId(record.taskIds[index]) != null;
  }

  TaskSession startImprove(int index) {
    final record = todayLevel;
    if (record == null || !canImprove(index)) {
      throw StateError('эту игру уровня сейчас не улучшить');
    }
    return _start(
        record.taskIds[index], record.difficultyOf(index), TaskPool.level);
  }

  GameReward finishImprove(int index, TaskSession session) {
    final record = todayLevel;
    if (record == null || record.taskIds[index] != session.task.id) {
      throw StateError('эта игра не из сегодняшнего уровня');
    }
    final solved = session.isFinished;
    final played = _afterGame(session);
    if (!solved) _rememberSkip(session);
    final better = record.improved(index, played.stars);
    final gain = better.coins - record.coins;
    if (gain > 0) {
      wallet.earn(
          amount: gain,
          sourceId: 'task:${session.task.id}',
          reasonText: levels.rewardReasonOf(record.number, session.task.title),
          at: clock.now(),
          dayNumber: day);
      levelHistory = [
        ...levelHistory.take(levelHistory.length - 1),
        better,
      ];
      fx('round_win');
    } else {
      fx(solved ? 'task_done' : 'retry');
    }
    changed();
    return GameReward(
      coins: gain,
      firstTime: played.firstTime,
      withMistakes: played.withMistakes,
      stars: played.stars,
    );
  }

  int starsOf(String taskId) => bestStars[taskId] ?? 0;

  int passedOf(TaskDef task) =>
      task.variantKeys.where(passedVariants.contains).length;

  static String _variantSlot(String key) {
    final cut = key.lastIndexOf('/');
    return cut < 0 ? key : key.substring(0, cut);
  }

  int nextIndex(TaskDef task, TaskDifficulty level,
      [TaskPool pool = TaskPool.practice]) {
    final count = task.variantsIn(pool, level).length;
    if (count <= 1) return 0;
    final last = lastVariants[_variantSlot(task.keyIn(pool, level, 0))];
    final from = last == null ? 0 : last + 1;
    for (var i = 0; i < count; i++) {
      final at = (from + i) % count;
      if (at == last) continue;
      if (!passedVariants.contains(task.keyIn(pool, level, at))) return at;
    }
    final at = (day + task.order) % count;
    return at == last ? (at + 1) % count : at;
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

  bool coachSeen(String id) =>
      seenCoach.contains(_allCoach) || seenCoach.contains(id);

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
      fx('round_win');
      say('plan_confirmed');
      changed();
    }
  }

  ShopItemView viewOf(ShopItem item) => shop.view(item);

  String get pocketRefusal =>
      'Эти монеты ты заработал после плана. Отложи их или спланируй на завтра.';

  PurchaseOutcome askToBuy(String itemId) {
    final item = content.shop.byId(itemId);
    if (item != null && blockedByPocket(item)) {
      return PurchaseRefused(pocketRefusal);
    }
    return shop.askToBuy(itemId);
  }

  PurchaseOutcome confirmPurchase(PurchaseConfirm confirmation) {
    final wanted = confirmation.view.item;
    if (blockedByPocket(wanted)) {
      fx('not_enough');
      return PurchaseRefused(pocketRefusal);
    }
    final fromPocket = pocketForNeed(wanted);
    final outcome = shop.confirm(confirmation,
        at: clock.now(), hasUnusedTasksToday: canEarnFromGames);
    switch (outcome) {
      case PurchaseDone(:final item, :final effects, wallet: final after):
        pocketNeeds += fromPocket;
        fx('purchase');
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
        fx('not_enough');
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

  Map<String, Object>? milestone;

  void clearMilestone() {
    milestone = null;
  }

  GoalOutcome deposit(int amount) {
    final before = goals.view()?.percent ?? 0;
    final outcome = goals.deposit(amount: amount, at: clock.now());
    if (outcome is GoalDepositDone) {
      final view = outcome.view;
      if (view != null &&
          (outcome.justReached || outcome.milestoneText != null)) {
        milestone = {
          'reached': outcome.justReached,
          'text': outcome.milestoneText ?? '',
          'from': before,
          'to': view.percent,
          'saved': view.saved,
          'price': view.goal.price,
          'goal': view.goal.title,
        };
      }
      fx(outcome.justReached ? 'goal_reached' : 'coin');
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
    if (outcome is WithdrawDone) {
      fx('coin');
      changed();
    }
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
    if (outcome is GoalSelected) {
      fx('goal_select');
      changed();
    }
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
      fx('goal_reached');
      for (final effect in outcome.effects) {
        stats = stats.apply(effect.stat, effect.delta);
      }
      say('goal_reached');
      changed();
    }
    return outcome;
  }

  TaskSession startGame(String taskId) => _start(taskId, difficulty);

  PhraseLine? reactToAnswer(TaskSession session, TaskFeedback feedback) {
    switch (feedback.verdict) {
      case TaskVerdict.correct:
        return say('task_correct');
      case TaskVerdict.wrong:
        fx('miss');
        return say('task_wrong', facts: {'attempt': session.attempts});
      case TaskVerdict.incomplete:
        return null;
    }
  }

  HintService get hints => HintService(content.tasks.texts.hints);

  PhraseLine? hintFor(TaskSession session) => say('task_hint',
      facts: {'taskType': session.task.type.name.toUpperCase()});

  GameReward finishGame(TaskSession session) {
    final solved = session.isFinished;
    final reward = _afterGame(session);
    if (solved) fx('round_win');
    changed();
    return reward;
  }

  GameReward _afterGame(TaskSession session) {
    final solved = session.isFinished;
    final completion = session.finish();
    if (solved) {
      lastVariants = {
        ...lastVariants,
        _variantSlot(session.variantKey): session.index,
      };
      passedVariants = {...passedVariants, session.variantKey};
      playCounts = {
        ...playCounts,
        completion.taskId: (playCounts[completion.taskId] ?? 0) + 1
      };
    }
    final stars = !solved
        ? 0
        : completion.withMistakes
            ? (completion.attempts > 2 ? 1 : 2)
            : 3;
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
    _speak(line);
    return line;
  }

  /// Короткий эффект по id события из звуковой схемы.
  void fx(String event) {
    final path = sounds?.forEvent(event, soundOn: sound);
    if (path != null) soundPlayer?.effect(path);
  }

  /// Питомец отзывается своим голоском: смешок лисёнка, писк робота…
  void petVoice() {
    final path = sounds?.petSound(character, turn: _petTurn++, soundOn: sound);
    if (path == null) return;
    soundPlayer?.stopSpeech();
    soundPlayer?.speak([path]);
  }

  int _petTurn = 0;

  // реплика: записанный голос, а без записи — голосок питомца
  void _speak(PhraseLine line) {
    final scheme = sounds;
    final player = soundPlayer;
    if (scheme == null || player == null || !sound) return;
    final voice = scheme.voiceFor(line.id, species: character, soundOn: sound);
    if (voice != null) {
      player.stopSpeech();
      player.speak([voice]);
    } else if (_cheerful.contains(line.emotion) && !player.speaking) {
      // голосок не перебивает недоговорённую записанную фразу
      petVoice();
    }
  }

  // смешок уместен только в радостной реплике; сочувствие и сон — тишина
  static const _cheerful = {
    PhraseEmotion.happy,
    PhraseEmotion.proud,
    PhraseEmotion.celebrate,
    PhraseEmotion.surprised,
  };

  void greet() {
    // во время церемонии роста приветствие звучит поверх фанфар
    if (celebration != null) return;
    if (currentNeed != null) {
      remindNeed();
    } else {
      say('app_open');
    }
  }

  void idle() {
    if (bubble != null || celebration != null) return;
    if (currentNeed != null) {
      remindNeed();
    } else {
      say('idle_30s');
    }
  }

  bool remindNeed() {
    final need = currentNeed;
    if (need == null || bubble != null || celebration != null) return false;
    final now = clock.now();
    if (_lastNeedReminder != null &&
        now.difference(_lastNeedReminder!) < const Duration(seconds: 90)) {
      return false;
    }
    final line = say('need_reminder', facts: {'statLow': need.name});
    if (line == null) return false;
    _lastNeedReminder = now;
    return true;
  }

  void openShop() => say('shop_open');

  void openPlanner() => say('planner_open');

  void openGames() => say('tasks_screen_open');

  void dismissBubble() {
    soundPlayer?.stopSpeech();
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
      'satiety': stats.satiety,
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
    fx('equip');
    changed();
  }

  void toggleRoomItem(String id) {
    final room = content.rooms.byId('main');
    if (room == null ||
        room.spotFor(id)?.type != RoomSpotType.item ||
        !shop.isOwned(id)) {
      return;
    }
    if (!hiddenRoomItems.remove(id)) hiddenRoomItems.add(id);
    changed();
  }

  void selectRoomItem(String place, String? id) {
    final options = roomPlaces[place];
    if (options == null) return;
    if (id != null &&
        (!options.contains(id) ||
            !(shop.isOwned(id) || goals.reachedGoalIds.contains(id)))) {
      return;
    }
    roomSelection[place] = id ?? '';
    if (id != null) hiddenRoomItems.remove(id);
    changed();
  }

  void setMotion(bool value) {
    motion = value;
    changed();
  }

  void setSound(bool value) {
    sound = value;
    if (!value) soundPlayer?.stopSpeech();
    _applyMusic();
    changed();
  }

  void setMusic(bool value) {
    music = value;
    _applyMusic();
    changed();
  }

  /// Смена фоновой темы (главная — «main», ночь — «calm»).
  void musicTheme(String name) {
    if (_musicTheme == name) return;
    _musicTheme = name;
    _applyMusic();
  }

  void startMusic() => _applyMusic();

  void _applyMusic() {
    final on = sound && music;
    soundPlayer
        ?.music(on ? sounds?.musicFor(_musicTheme, musicOn: true) : null);
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
          if (t.sourceId.startsWith('goal:')) break;
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

  void setDemo(bool value) {
    demoMode = value;
    shop.openAll = value;
    goals.openAll = value;
    changed();
  }

  void renamePet(String name) {
    if (petNameProblem(name) != null) throw ArgumentError.value(name);
    petName = normalizePetName(name);
    _lastNeedReminder = null;
    changed();
  }

  void createPet(String name, bool simple,
      {String? goalId, PetAppearance pet = PetAppearance.moni}) {
    if (petNameProblem(name) != null) throw ArgumentError.value(name);
    if (goalId != null && goalId != this.goalId) {
      final ask = askGoal(goalId);
      if (ask is GoalSelectConfirm) goals.confirmSelect(ask);
    }
    petName = normalizePetName(name);
    appearance = pet;
    phrases = PhraseService(
        catalog: content.phrases, clock: clock, character: character);
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
        'planIncome': plan.plan.income,
        'stats': stats.toJson(),
        'journal': [for (final t in wallet.journal) t.toJson()],
        'motion': motion,
        'sound': sound,
        'music': music,
        'simpleMode': simpleMode,
        'demoMode': demoMode,
        'onboarded': onboarded,
        'petName': petName,
        'character': character,
        'stage': stage.name,
        'goalId': goals.current?.id,
        'reachedGoals': goals.reachedGoalIds.toList(),
        'owned': shop.owned.toList(),
        'wallpaper': shop.activeWallpaperId,
        'hiddenRoomItems': hiddenRoomItems.toList(),
        'roomSelection': Map<String, String>.of(roomSelection),
        'wishlist': wishlist.toList(),
        'outfit': outfit,
        'completedTasks': tasks.completedTaskIds.toList(),
        'bestStars': bestStars,
        'seenTutorials': seenTutorials.toList(),
        'seenCoach': seenCoach.toList()..sort(),
        'passedVariants': passedVariants.toList()..sort(),
        'lastVariants': lastVariants,
        'levelHistory': [for (final record in levelHistory) record.toJson()],
        'levelRun': levelRun?.toJson(),
        'dailyDoneAt': dailyDoneAt?.toIso8601String(),
        'dailyHistory': dailyHistory.toList()..sort(),
        'dailyRun': dailyRun,
        'eventChoices': {
          for (final e in eventChoices.entries) '${e.key}': e.value
        },
        'paybacks': paybacks,
        'news': news,
        'careful': carefulCount,
        'pocketSaved': pocketSaved,
        'pocketNeeds': pocketNeeds,
        'carried': carried,
        'paidBack': paidBack,
        'dayHistory': dayHistory,
        'legacyCompletedTasks': legacyCompletedTasks,
        'placed': placed,
        'seenItems': seenItems.toList()..sort(),
        'knownWords': knownWords.toList()..sort(),
        'playCounts': playCounts,
      };

  void changed() {
    if (bubble?.trigger == 'need_reminder' &&
        !(bubble?.id ?? '').startsWith('need_${currentNeed?.name}')) {
      _bubbleTimer?.cancel();
      soundPlayer?.stopSpeech();
      bubble = null;
    }
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
    if (_ownsSoundPlayer) {
      soundPlayer?.dispose();
    } else {
      soundPlayer?.stopSpeech();
    }
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
