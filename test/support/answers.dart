import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/task_engine.dart';

int? ruleValue(List<TaskRule> rules, TaskRuleType type, [String? counterId]) {
  for (final rule in rules) {
    if (rule.type == type && (counterId == null || rule.counterId == counterId)) {
      return rule.value;
    }
  }
  return null;
}

Map<int, int>? solveCoins(CoinsPayload payload) {
  final limit = ruleValue(payload.rules, TaskRuleType.maxCoins);
  final denominations = payload.wallet.keys.toList()..sort((a, b) => b.compareTo(a));

  Map<int, int>? search(int index, int sum, int coins, Map<int, int> taken) {
    if (limit != null && coins > limit) return null;
    if (sum == payload.expected) return taken;
    if (sum > payload.expected || index == denominations.length) return null;
    final denomination = denominations[index];
    for (var take = payload.wallet[denomination]!; take >= 0; take--) {
      final found = search(index + 1, sum + denomination * take, coins + take,
          {...taken, if (take > 0) denomination: take});
      if (found != null) return found;
    }
    return null;
  }

  return search(0, 0, 0, const {});
}

List<int>? solveWeek(WeekPayload payload) {
  final options = [
    for (var save = payload.maxSavePerDay; save >= 0; save -= payload.step) save,
  ];

  List<int>? search(int day, int wallet, int saved, List<int> plan) {
    if (day > payload.days) return saved >= payload.target ? plan : null;
    for (final save in options) {
      var left = wallet + payload.dailyIncome - save;
      final event = payload.eventOn(day);
      if (event != null) left -= event.cost;
      if (left < 0) continue;
      final found = search(day + 1, left, saved + save, [...plan, save]);
      if (found != null) return found;
    }
    return null;
  }

  return search(1, 0, 0, const []);
}

List<int>? searchBoard(BoardPayload payload, bool Function(BoardRun run) wanted) {
  List<int>? search(BoardRun run) {
    if (run.isFinished) return wanted(run) ? run.decisions : null;
    if (run.pending) {
      for (final option in run.options().reversed) {
        final found = search(run.decide(option));
        if (found != null) return found;
      }
      return null;
    }
    return run.canRoll ? search(run.roll()) : null;
  }

  return search(BoardRun.start(payload));
}

List<StallChoice>? solveStall(StallPayload payload) {
  final goal = payload.goalOf(payload.rules);
  List<StallChoice>? search(int day, int coins, List<StallChoice> plan) {
    if (day == payload.days.length) return coins >= goal ? plan : null;
    for (final portions in payload.portionOptions(coins).reversed) {
      for (final price in payload.prices) {
        final choice = StallChoice(portions: portions, price: price);
        final result = payload.playDay(day, coins, choice);
        final found = search(day + 1, result.coinsAfter, [...plan, choice]);
        if (found != null) return found;
      }
    }
    return null;
  }

  return search(0, payload.startCoins, const []);
}

Map<int, int> changeCoins(CashierPayload payload, int amount) {
  final coins = [...payload.denominations]..sort((a, b) => b.compareTo(a));
  final result = <int, int>{};
  var left = amount;
  for (final coin in coins) {
    final count = left ~/ coin;
    if (count > 0) {
      result[coin] = count;
      left -= count * coin;
    }
  }
  return result;
}

TaskAnswer rightAnswer(TaskVariant variant) => switch (variant.payload) {
      SortPayload(:final cards) => SortAnswer({for (final c in cards) c.id: c.bin}),
      CoinsPayload payload => CoinsAnswer(solveCoins(payload)!),
      DistributePayload payload => DistributeAnswer({
          for (final counter in payload.counters)
            counter.id:
                ruleValue(payload.rules, TaskRuleType.atLeast, counter.id) ?? counter.min,
        }),
      OrderPayload(:final items) =>
        OrderAnswer([for (final i in [...items]..sort((a, b) => a.rank.compareTo(b.rank))) i.id]),
      ChoicePayload(:final options) =>
        ChoiceAnswer(options.firstWhere((o) => o.isCorrect).id),
      BasketPayload payload => BasketAnswer({for (final p in payload.fromList) p.id}),
      WeekPayload payload => WeekAnswer(solveWeek(payload)!),
      BoardPayload payload =>
        BoardAnswer(searchBoard(payload, payload.passes)!),
      StallPayload payload => StallAnswer(solveStall(payload)!),
      CashierPayload payload => CashierAnswer([
          for (final customer in payload.customers)
            changeCoins(payload, customer.change),
        ]),
      PriceTagPayload(:final rounds) =>
        PriceTagAnswer([for (final round in rounds) round.best.id]),
    };
