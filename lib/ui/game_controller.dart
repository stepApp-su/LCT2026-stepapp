import 'dart:async';

import 'package:flutter/foundation.dart';

import '../content/content_loader.dart';
import '../content/content_repository.dart';
import '../content/game_content.dart';
import '../data/game_repository.dart';
import '../domain/game_clock.dart';
import '../domain/models/models.dart';
import '../domain/services/goal_service.dart';
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
  late PetStage stage;
  late Set<String> wishlist;
  late Map<String, String> outfit;
  late List<String> legacyCompletedTasks;
  late List<String> paidRepeatsToday;
  late int paidRepeatsDay;
  late Map<String, int> bestStars;
  late Set<String> seenTutorials;
  late bool motion, simpleMode, onboarded;
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
    plan = PlanService(
        income: params.day.income,
        step: params.plan.step,
        mandatoryCost: mandatoryCost);
    final amounts = data['plan'] as Map;
    for (final d in PlanDirection.values) {
      plan.setAmount(d, amounts[d.name] as int);
    }
    if (data['confirmed'] == true) plan.confirm();
    stats = PetState.fromJson((data['stats'] as Map).cast<String, Object?>());
    motion = data['motion'] != false;
    simpleMode = data['simpleMode'] != false;
    onboarded = data['onboarded'] == true;
    petName = data['petName'] as String? ?? 'Мони';
    stage = PetStage.values.firstWhere((s) => s.name == data['stage'],
        orElse: () => PetStage.baby);
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
    paidRepeatsDay = data['paidRepeatsDay'] as int? ?? day;
    paidRepeatsToday = paidRepeatsDay == day
        ? (data['paidRepeatsToday'] as List? ?? []).cast<String>()
        : <String>[];
    bestStars = (data['bestStars'] as Map? ?? {}).cast<String, int>();
    seenTutorials = {...(data['seenTutorials'] as List? ?? []).cast<String>()};
    phrases = PhraseService(
        catalog: content.phrases, clock: clock, character: character);
  }

  int get day => config['day'] as int;

  int get mandatoryCost => content.shop.items
      .where((i) => i.category == ExpenseCategory.mandatory)
      .fold(0, (sum, i) => sum + i.price);

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

  bool get canEarnFromGames =>
      tasks.completedTaskIds.length < content.tasks.tasks.length ||
      paidRepeatsToday.length < content.economy.params.day.tasksPerDay;

  bool get completed => !canEarnFromGames;

  TaskDef get dailyGame {
    for (final task in content.tasks.tasks) {
      if (!tasks.isCompleted(task.id)) return task;
    }
    return content.tasks.tasks.first;
  }

  int rewardFor(TaskDef task) {
    if (!tasks.isCompleted(task.id)) return task.reward.correct;
    if (paidRepeatsToday.length >= content.economy.params.day.tasksPerDay) {
      return 0;
    }
    final repeat = content.economy.params.tasks.repeatReward;
    return repeat < task.reward.correct ? repeat : task.reward.correct;
  }

  int starsOf(String taskId) => bestStars[taskId] ?? 0;

  List<TutorialStep> tutorialFor(TaskDef task) =>
      content.tasks.tutorialFor(task);

  bool tutorialSeen(String taskId) => seenTutorials.contains(taskId);

  void markTutorialSeen(String taskId) {
    if (seenTutorials.add(taskId)) changed();
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
        for (final effect in effects) {
          stats = stats.apply(effect.stat, effect.delta);
        }
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

  TaskSession startGame(String taskId) => tasks.start(taskId, difficulty);

  PhraseLine? reactToAnswer(TaskSession session, TaskFeedback feedback) =>
      switch (feedback.verdict) {
        TaskVerdict.correct => say('task_correct'),
        TaskVerdict.wrong =>
          say('task_wrong', facts: {'attempt': session.attempts}),
        TaskVerdict.incomplete => null,
      };

  PhraseLine? hintFor(TaskSession session) => say('task_hint',
      facts: {'taskType': session.task.type.name.toUpperCase()});

  GameReward finishGame(TaskSession session) {
    final completion = session.finish();
    final limit = content.economy.params.day.tasksPerDay;
    final pays = completion.firstTime || paidRepeatsToday.length < limit;
    if (pays && !session.isCollected) {
      session.collect(wallet, at: clock.now(), dayNumber: day);
      if (!completion.firstTime) {
        if (paidRepeatsDay != day) {
          paidRepeatsDay = day;
          paidRepeatsToday = [];
        }
        paidRepeatsToday = [...paidRepeatsToday, completion.taskId];
      }
    }
    final stars = completion.withMistakes
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
    final coins = pays ? completion.coins : 0;
    if (coins > 0) {
      say('task_done',
          facts: {'firstTry': !completion.withMistakes},
          values: {'reward': coins});
    }
    changed();
    return GameReward(
      coins: coins,
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
      if (goal != null) 'goalProgress': goal.price == 0 ? 0 : goal.saved * 100 ~/ goal.price,
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

  void setSimple(bool value) {
    simpleMode = value;
    changed();
  }

  void createPet(String name, bool simple) {
    if (!(config['names'] as List).contains(name)) {
      throw ArgumentError.value(name);
    }
    petName = name;
    simpleMode = simple;
    onboarded = true;
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
        'paidRepeatsDay': paidRepeatsDay,
        'paidRepeatsToday': paidRepeatsToday,
        'bestStars': bestStars,
        'seenTutorials': seenTutorials.toList(),
        'legacyCompletedTasks': legacyCompletedTasks,
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
