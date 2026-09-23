import 'package:flutter/foundation.dart';
import '../content/game_content.dart';
import '../data/game_repository.dart';
import '../domain/game_clock.dart';
import '../domain/models/models.dart';
import '../domain/services/plan_service.dart';
import '../domain/services/wallet_service.dart';

/// Координатор UI. Расчёты бюджета и кошелька выполняют доменные сервисы.
class GameController extends ChangeNotifier {
  GameController(this.config,
      {Map<String, dynamic>? saved,
      GameRepository? repository,
      GameClock? clock})
      : repository = repository ?? LocalGameRepository(),
        clock = clock ?? RealClock() {
    _restore(saved);
  }
  final Map<String, dynamic> config;
  final GameRepository repository;
  final GameClock clock;
  late WalletService wallet;
  late PlanService plan;
  late PetState stats;
  late List<ShopItem> catalog;
  late Set<String> owned, wishlist;
  late Map<String, String> outfit;
  late List<String> legacyCompletedTasks;
  late bool completed, motion, simpleMode, onboarded;
  late String petName, goalId;
  String? storageError;
  bool _disposed = false;
  Future<void> _pending = Future.value();

  static Future<GameController> load() async {
    final config = await GameContent.load();
    final repository = LocalGameRepository();
    return GameController(config,
        saved: await repository.load(), repository: repository);
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
    plan = PlanService(
        income: config['income'] as int,
        mandatoryCost: config['mandatoryCost'] as int);
    final amounts = data['plan'] as Map;
    for (final d in PlanDirection.values) {
      plan.setAmount(d, amounts[d.name] as int);
    }
    if (data['confirmed'] == true) plan.confirm();
    stats = PetState.fromJson((data['stats'] as Map).cast<String, Object?>());
    catalog = [
      for (final item in config['catalog'] as List)
        ShopItem.fromJson((item as Map).cast<String, Object?>())
    ];
    completed = data['completed'] == true;
    motion = data['motion'] != false;
    simpleMode = data['simpleMode'] != false;
    onboarded = data['onboarded'] == true;
    petName = data['petName'] as String? ?? 'Мони';
    goalId =
        data['goalId'] as String? ?? (config['goal'] as Map)['id'] as String;
    owned = {...(data['owned'] as List? ?? []).cast<String>()};
    wishlist = {...(data['wishlist'] as List? ?? []).cast<String>()};
    outfit = (data['outfit'] as Map? ?? {}).cast<String, String>();
    legacyCompletedTasks =
        (data['legacyCompletedTasks'] as List? ?? []).cast<String>();
    if (saved == null) {
      final opening = wallet.wallet.balance;
      wallet = WalletService(
          initial: Wallet.create(balance: 0, savings: wallet.wallet.savings));
      if (opening > 0) {
        wallet.earn(
            amount: opening,
            sourceId: 'day_income',
            reasonText: 'Монеты первого дня',
            at: clock.now(),
            dayNumber: day);
      }
    }
  }

  int get day => config['day'] as int;
  List<Map<String, dynamic>> get goals => (config['goals'] as List)
      .map((e) => (e as Map).cast<String, dynamic>())
      .toList();
  Map<String, dynamic> get currentGoal =>
      goals.firstWhere((g) => g['id'] == goalId);
  int get target => currentGoal['price'] as int;
  String get goal => currentGoal['title'] as String;
  int get left => (target - wallet.wallet.savings).clamp(0, target);
  int? get daysToGoal => daysFor(wallet.wallet.savings);
  int? daysFor(int amount) => plan.plan.savings > 0
      ? ((target - amount).clamp(0, target) / plan.plan.savings).ceil()
      : null;
  String? get equipped => outfit['head'];
  Map<String, dynamic> get question =>
      (config['question'] as Map).cast<String, dynamic>();
  Map<String, dynamic> details(String id) => (config['catalog'] as List)
      .cast<Map>()
      .firstWhere((e) => e['id'] == id)
      .cast<String, dynamic>();
  void changePlan(PlanDirection d, int delta) {
    if (plan.isConfirmed) return;
    delta > 0 ? plan.increase(d) : plan.decrease(d);
    changed();
  }

  void confirmPlan() {
    if (!plan.isConfirmed) {
      plan.confirm();
      changed();
    }
  }

  bool ownsAccessory(ShopItem item) =>
      details(item.id)['art'] == 'accessories' && owned.contains(item.id);
  WalletOutcome buy(ShopItem item) {
    if (ownsAccessory(item)) throw StateError('Аксессуар уже куплен');
    final result = wallet.spend(
        amount: item.price,
        itemId: item.id,
        category: item.category,
        reasonText: item.title,
        at: clock.now(),
        dayNumber: day,
        hasUnusedTasksToday: !completed,
        catalog: catalog);
    if (result is WalletOk) {
      for (final effect in item.effects) {
        stats = stats.apply(effect.stat, effect.delta);
      }
      owned.add(item.id);
      wishlist.remove(item.id);
      changed();
    }
    return result;
  }

  bool answer(int index) {
    if (index != question['correct']) return false;
    if (!completed) {
      wallet.earn(
          amount: question['reward'] as int,
          sourceId: question['id'] as String,
          reasonText: question['title'] as String,
          at: clock.now(),
          dayNumber: day);
      completed = true;
      changed();
    }
    return true;
  }

  bool saveCoins(int amount) {
    if (amount <= 0) return false;
    final result =
        wallet.toSavings(amount: amount, at: clock.now(), dayNumber: day);
    if (result is WalletOk) {
      changed();
      return true;
    }
    return false;
  }

  bool withdraw(int amount) {
    if (amount <= 0) return false;
    final result =
        wallet.fromSavings(amount: amount, at: clock.now(), dayNumber: day);
    if (result is WalletOk) {
      changed();
      return true;
    }
    return false;
  }

  void changeGoal(String id) {
    if (!goals.any((g) => g['id'] == id)) throw ArgumentError.value(id);
    goalId = id;
    changed();
  }

  void postpone(String id) {
    details(id);
    wishlist.add(id);
    changed();
  }

  void equip(String id) {
    final d = details(id);
    if (!owned.contains(id) || d['slot'] == null) return;
    final slot = d['slot'] as String;
    if (outfit[slot] == id) {
      outfit.remove(slot);
    } else {
      outfit[slot] = id;
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
        'schemaVersion': 1,
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
        'completed': completed,
        'motion': motion,
        'simpleMode': simpleMode,
        'onboarded': onboarded,
        'petName': petName,
        'goalId': goalId,
        'owned': owned.toList(),
        'wishlist': wishlist.toList(),
        'outfit': outfit,
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
    super.dispose();
  }
}
