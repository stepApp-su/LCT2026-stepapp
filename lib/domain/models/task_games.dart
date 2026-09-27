part of 'task_catalog.dart';

final class TextGroup {
  const TextGroup._(this.values);

  factory TextGroup.fromJson(Object? raw, String field, Set<String> required) =>
      TextGroup._(jsonTexts(raw, field, required: required));

  final Map<String, String> values;

  String operator [](String key) => values[key] ?? key;

  static const Set<String> hintKeys = {
    'sortStart',
    'sortWrong',
    'sortWrongMany',
    'sortRest',
    'sortReady',
    'coinsStart',
    'changeStart',
    'coinsLess',
    'coinsMore',
    'coinsMany',
    'coinsReady',
    'jarShort',
    'jarOver',
    'jarLeft',
    'jarReady',
    'daysFew',
    'daysMany',
    'daysReady',
    'orderSwap',
    'orderReady',
    'choice',
    'basketStart',
    'basketMissing',
    'basketOver',
    'basketRoom',
    'basketReady',
    'weekStart',
    'weekShort',
    'weekGoal',
    'weekReady',
    'boardAhead',
    'boardTemptation',
    'boardPiggy',
    'boardPiggyFree',
    'boardRoll',
    'boardDone',
    'stallPlan',
    'stallFits',
    'stallExtra',
    'stallMore',
    'stallResult',
    'cashierTotal',
    'cashierStart',
    'cashierLess',
    'cashierMore',
    'cashierReady',
    'cashierNext',
    'priceExtra',
    'priceCompare',
    'priceNext',
    'labelMandatory',
    'labelOptional',
    'labelSavings',
  };

  static const Set<String> boardKeys = {
    'roll',
    'wallet',
    'savings',
    'goal',
    'joy',
    'buy',
    'skip',
    'save',
    'keep',
    'income',
    'expense',
    'short',
    'finish',
    'again',
  };

  static const Set<String> stallKeys = {
    'coins',
    'goal',
    'day',
    'portions',
    'spent',
    'price',
    'open',
    'dayResult',
    'leftover',
    'missed',
    'next',
    'again',
  };

  static const Set<String> pricetagKeys = {
    'round',
    'pick',
    'total',
    'best',
    'tricky',
    'next',
    'finish',
    'again',
  };

  static const Set<String> cashierKeys = {
    'customer',
    'paid',
    'total',
    'askTotal',
    'change',
    'give',
    'right',
    'wrong',
    'wrongLine',
    'again',
  };
}

enum BoardCellKind { start, income, expense, temptation, piggy, rest, finish }

final class BoardCell {
  const BoardCell({
    required this.kind,
    required this.label,
    required this.iconId,
    required this.amount,
    required this.note,
  });

  factory BoardCell.fromJson(Map<String, Object?> json) => BoardCell(
        kind: jsonEnum(BoardCellKind.values, json['kind'], 'cells.kind'),
        label: jsonText(json['label'], 'cells.label'),
        iconId: jsonText(json['iconId'], 'cells.iconId'),
        amount: jsonInt(json['amount'] ?? 0, 'cells.amount', min: 0),
        note: (json['note'] ?? '') as String,
      );

  final BoardCellKind kind;
  final String label;
  final String iconId;
  final int amount;
  final String note;

  bool get needsDecision =>
      kind == BoardCellKind.temptation || kind == BoardCellKind.piggy;
}

final class BoardShortage {
  const BoardShortage({required this.turn, required this.cell, required this.gap});

  final int turn;
  final BoardCell cell;
  final int gap;
}

final class BoardRun {
  const BoardRun._({
    required this.payload,
    required this.turn,
    required this.position,
    required this.wallet,
    required this.savings,
    required this.joy,
    required this.pending,
    required this.shortages,
    required this.decisions,
  });

  factory BoardRun.start(BoardPayload payload) => BoardRun._(
        payload: payload,
        turn: 0,
        position: 0,
        wallet: payload.startCoins,
        savings: 0,
        joy: 0,
        pending: false,
        shortages: const [],
        decisions: const [],
      );

  static BoardRun play(BoardPayload payload, List<int> decisions) {
    var run = BoardRun.start(payload);
    var next = 0;
    while (!run.isFinished) {
      if (run.pending) {
        if (next >= decisions.length) {
          throw ArgumentError.value(decisions, 'decisions', 'решений меньше, чем клеток с выбором');
        }
        run = run.decide(decisions[next++]);
        continue;
      }
      if (!run.canRoll) {
        throw StateError('кубик закончился раньше финиша');
      }
      run = run.roll();
    }
    if (next != decisions.length) {
      throw ArgumentError.value(decisions, 'decisions', 'решений больше, чем клеток с выбором');
    }
    return run;
  }

  final BoardPayload payload;
  final int turn;
  final int position;
  final int wallet;
  final int savings;
  final int joy;
  final bool pending;
  final List<BoardShortage> shortages;
  final List<int> decisions;

  BoardCell get cell => payload.cells[position];
  bool get isFinished => position == payload.cells.length - 1;
  bool get canRoll => !pending && !isFinished && turn < payload.dice.length;
  int? get lastRoll => turn == 0 ? null : payload.dice[turn - 1];
  int? get nextRoll => turn < payload.dice.length ? payload.dice[turn] : null;

  BoardRun _copy({
    int? turn,
    int? position,
    int? wallet,
    int? savings,
    int? joy,
    bool? pending,
    List<BoardShortage>? shortages,
    List<int>? decisions,
  }) =>
      BoardRun._(
        payload: payload,
        turn: turn ?? this.turn,
        position: position ?? this.position,
        wallet: wallet ?? this.wallet,
        savings: savings ?? this.savings,
        joy: joy ?? this.joy,
        pending: pending ?? this.pending,
        shortages: shortages ?? this.shortages,
        decisions: decisions ?? this.decisions,
      );

  BoardRun roll() {
    if (!canRoll) throw StateError('сейчас бросать кубик нельзя');
    final last = payload.cells.length - 1;
    final target = position + payload.dice[turn];
    final landed = target > last ? last : target;
    final cell = payload.cells[landed];
    var money = wallet;
    var missing = shortages;
    switch (cell.kind) {
      case BoardCellKind.income:
        money += cell.amount;
      case BoardCellKind.expense:
        money -= cell.amount;
        if (money < 0) {
          missing = List.unmodifiable([
            ...shortages,
            BoardShortage(turn: turn + 1, cell: cell, gap: -money),
          ]);
          money = 0;
        }
      case BoardCellKind.start ||
            BoardCellKind.temptation ||
            BoardCellKind.piggy ||
            BoardCellKind.rest ||
            BoardCellKind.finish:
        break;
    }
    return _copy(
      turn: turn + 1,
      position: landed,
      wallet: money,
      pending: cell.needsDecision,
      shortages: missing,
    );
  }

  List<int> options() {
    if (!pending) return const [];
    final current = cell;
    if (current.kind == BoardCellKind.temptation) {
      return [0, if (wallet >= current.amount) 1];
    }
    return [for (var amount = 0; amount <= wallet; amount += payload.step) amount];
  }

  BoardRun decide(int value) {
    if (!pending) throw StateError('сейчас выбирать нечего');
    if (!options().contains(value)) {
      throw ArgumentError.value(value, 'decision', 'такого варианта нет');
    }
    final chosen = List<int>.unmodifiable([...decisions, value]);
    if (cell.kind == BoardCellKind.temptation) {
      return _copy(
        wallet: value == 1 ? wallet - cell.amount : wallet,
        joy: value == 1 ? joy + 1 : joy,
        pending: false,
        decisions: chosen,
      );
    }
    return _copy(
      wallet: wallet - value,
      savings: savings + value,
      pending: false,
      decisions: chosen,
    );
  }
}

final class BoardPayload extends TaskPayload {
  const BoardPayload({
    required this.startCoins,
    required this.step,
    required this.target,
    required this.dice,
    required this.cells,
    required this.rules,
  });

  final int startCoins;
  final int step;
  final int target;
  final List<int> dice;
  final List<BoardCell> cells;

  @override
  final List<TaskRule> rules;

  bool passes(BoardRun run) {
    for (final rule in rules) {
      final ok = switch (rule.type) {
        TaskRuleType.neverNegative => run.shortages.isEmpty,
        TaskRuleType.savingsAtLeast => run.savings >= (rule.value ?? target),
        _ => false,
      };
      if (!ok) return false;
    }
    return true;
  }

  bool get solvable {
    bool search(BoardRun run) {
      if (run.isFinished) return passes(run);
      if (run.pending) {
        for (final option in run.options().reversed) {
          if (search(run.decide(option))) return true;
        }
        return false;
      }
      if (!run.canRoll) return false;
      return search(run.roll());
    }

    return search(BoardRun.start(this));
  }
}

final class StallDay {
  const StallDay({
    required this.id,
    required this.label,
    required this.iconId,
    required this.forecast,
    required this.demand,
  });

  factory StallDay.fromJson(Map<String, Object?> json) {
    final raw = jsonMap(json['demand'], 'days.demand');
    return StallDay(
      id: jsonText(json['id'], 'days.id'),
      label: jsonText(json['label'], 'days.label'),
      iconId: jsonText(json['iconId'], 'days.iconId'),
      forecast: jsonText(json['forecast'], 'days.forecast'),
      demand: Map.unmodifiable({
        for (final entry in raw.entries)
          int.parse(entry.key): jsonInt(entry.value, 'days.demand', min: 0),
      }),
    );
  }

  final String id;
  final String label;
  final String iconId;
  final String forecast;
  final Map<int, int> demand;
}

final class StallChoice {
  const StallChoice({required this.portions, required this.price});

  final int portions;
  final int price;
}

final class StallDayResult {
  const StallDayResult({
    required this.day,
    required this.choice,
    required this.coinsBefore,
    required this.spent,
    required this.demand,
    required this.sold,
    required this.revenue,
  });

  final int day;
  final StallChoice choice;
  final int coinsBefore;
  final int spent;
  final int demand;
  final int sold;
  final int revenue;

  int get coinsAfter => coinsBefore - spent + revenue;
  int get leftover => choice.portions - sold;
  int get missed => demand - sold;
  int get profit => revenue - spent;
}

final class StallPayload extends TaskPayload {
  const StallPayload({
    required this.startCoins,
    required this.costPerPortion,
    required this.portionStep,
    required this.maxPortions,
    required this.prices,
    required this.days,
    required this.target,
    required this.rules,
  });

  final int startCoins;
  final int costPerPortion;
  final int portionStep;
  final int maxPortions;
  final List<int> prices;
  final List<StallDay> days;
  final int target;

  @override
  final List<TaskRule> rules;

  List<int> portionOptions(int coins) => [
        for (var p = 0;
            p <= maxPortions && p * costPerPortion <= coins;
            p += portionStep)
          p
      ];

  StallDayResult playDay(int index, int coins, StallChoice choice) {
    if (index < 0 || index >= days.length) {
      throw ArgumentError.value(index, 'day', 'нет такого дня');
    }
    if (!prices.contains(choice.price)) {
      throw ArgumentError.value(choice.price, 'price', 'такой цены нет');
    }
    if (!portionOptions(coins).contains(choice.portions)) {
      throw ArgumentError.value(choice.portions, 'portions', 'столько не купить');
    }
    final demand = days[index].demand[choice.price] ?? 0;
    final sold = choice.portions < demand ? choice.portions : demand;
    return StallDayResult(
      day: index + 1,
      choice: choice,
      coinsBefore: coins,
      spent: choice.portions * costPerPortion,
      demand: demand,
      sold: sold,
      revenue: sold * choice.price,
    );
  }

  List<StallDayResult> play(List<StallChoice> choices) {
    if (choices.length != days.length) {
      throw ArgumentError.value(choices.length, 'choices', 'нужно решение на каждый день');
    }
    var coins = startCoins;
    final results = <StallDayResult>[];
    for (var i = 0; i < days.length; i++) {
      final result = playDay(i, coins, choices[i]);
      results.add(result);
      coins = result.coinsAfter;
    }
    return List.unmodifiable(results);
  }

  int goalOf(List<TaskRule> rules) {
    for (final rule in rules) {
      if (rule.type == TaskRuleType.coinsAtLeast && rule.value != null) {
        return rule.value!;
      }
    }
    return target;
  }

  bool get solvable {
    final goal = goalOf(rules);
    bool search(int index, int coins) {
      if (index == days.length) return coins >= goal;
      for (final portions in portionOptions(coins).reversed) {
        for (final price in prices) {
          final result = playDay(index, coins, StallChoice(portions: portions, price: price));
          if (search(index + 1, result.coinsAfter)) return true;
        }
      }
      return false;
    }

    return search(0, startCoins);
  }
}

final class CashierItem {
  const CashierItem({required this.label, required this.iconId, required this.price});

  factory CashierItem.fromJson(Map<String, Object?> json) => CashierItem(
        label: jsonText(json['label'], 'items.label'),
        iconId: jsonText(json['iconId'], 'items.iconId'),
        price: jsonInt(json['price'], 'items.price', min: 1),
      );

  final String label;
  final String iconId;
  final int price;
}

final class CashierCustomer {
  const CashierCustomer({
    required this.id,
    required this.name,
    required this.iconId,
    required this.items,
    required this.paid,
  });

  factory CashierCustomer.fromJson(Map<String, Object?> json) => CashierCustomer(
        id: jsonText(json['id'], 'customers.id'),
        name: jsonText(json['name'], 'customers.name'),
        iconId: jsonText(json['iconId'], 'customers.iconId'),
        items: List.unmodifiable([
          for (final raw in jsonMaps(json['items'], 'customers.items'))
            CashierItem.fromJson(raw),
        ]),
        paid: jsonInt(json['paid'], 'customers.paid', min: 1),
      );

  final String id;
  final String name;
  final String iconId;
  final List<CashierItem> items;
  final int paid;

  int get total => items.fold(0, (sum, item) => sum + item.price);
  int get change => paid - total;
}

final class CashierPayload extends TaskPayload {
  const CashierPayload({
    required this.customers,
    required this.showTotal,
    required this.denominations,
    required this.rules,
  });

  final List<CashierCustomer> customers;
  final bool showTotal;
  final List<int> denominations;

  @override
  final List<TaskRule> rules;

  static int sumOf(Map<int, int> coins) {
    var sum = 0;
    coins.forEach((value, count) => sum += value * count);
    return sum;
  }

  bool canMake(int amount) {
    final reachable = List<bool>.filled(amount + 1, false)..[0] = true;
    for (var sum = 1; sum <= amount; sum++) {
      for (final coin in denominations) {
        if (coin <= sum && reachable[sum - coin]) {
          reachable[sum] = true;
          break;
        }
      }
    }
    return reachable[amount];
  }
}

enum CoachAction { next, tap, wait }

final class TutorialStep {
  const TutorialStep({
    required this.emoji,
    required this.text,
    this.target,
    this.action = CoachAction.next,
    this.until,
    this.skipIf,
  });

  factory TutorialStep.fromJson(Map<String, Object?> json) {
    final step = TutorialStep(
      emoji: jsonText(json['emoji'], 'tutorials.emoji'),
      text: jsonText(json['text'], 'tutorials.text'),
      target: jsonTextOrNull(json['target'], 'tutorials.target'),
      action: jsonEnum(CoachAction.values, json['action'] ?? CoachAction.next.name,
          'tutorials.action'),
      until: jsonTextOrNull(json['until'], 'tutorials.until'),
      skipIf: jsonTextOrNull(json['skipIf'], 'tutorials.skipIf'),
    );
    if (step.action == CoachAction.tap && step.target == null) {
      throw ArgumentError.value(step.text, 'tutorials.target', 'нажать можно только на что-то');
    }
    if (step.action == CoachAction.wait && step.until == null) {
      throw ArgumentError.value(step.text, 'tutorials.until', 'не сказано, чего ждать');
    }
    return step;
  }

  final String emoji;
  final String text;
  final String? target;
  final CoachAction action;
  final String? until;
  final String? skipIf;

  Set<String> get conditions => {
        if (until case final value?) value,
        if (skipIf case final value?) value,
      };
}

final class PriceOffer {
  const PriceOffer({
    required this.id,
    required this.label,
    required this.iconId,
    required this.tag,
    required this.detail,
    required this.pay,
    required this.fits,
    required this.why,
  });

  factory PriceOffer.fromJson(Map<String, Object?> json) => PriceOffer(
        id: jsonText(json['id'], 'offers.id'),
        label: jsonText(json['label'], 'offers.label'),
        iconId: jsonText(json['iconId'], 'offers.iconId'),
        tag: jsonTextOrNull(json['tag'], 'offers.tag'),
        detail: jsonText(json['detail'], 'offers.detail'),
        pay: jsonInt(json['pay'], 'offers.pay', min: 0),
        fits: jsonBool(json['fits'] ?? true, 'offers.fits'),
        why: jsonText(json['why'], 'offers.why'),
      );

  final String id;
  final String label;
  final String iconId;
  final String? tag;
  final String detail;
  final int pay;
  final bool fits;
  final String why;
}

final class PriceRound {
  const PriceRound({required this.id, required this.need, required this.offers});

  factory PriceRound.fromJson(Map<String, Object?> json) => PriceRound(
        id: jsonText(json['id'], 'rounds.id'),
        need: jsonText(json['need'], 'rounds.need'),
        offers: List.unmodifiable([
          for (final raw in jsonMaps(json['offers'], 'rounds.offers'))
            PriceOffer.fromJson(raw),
        ]),
      );

  final String id;
  final String need;
  final List<PriceOffer> offers;

  PriceOffer get best {
    PriceOffer? winner;
    for (final offer in offers) {
      if (!offer.fits) continue;
      if (winner == null || offer.pay < winner.pay) winner = offer;
    }
    return winner!;
  }

  PriceOffer? offer(String id) {
    for (final candidate in offers) {
      if (candidate.id == id) return candidate;
    }
    return null;
  }
}

final class PriceTagPayload extends TaskPayload {
  const PriceTagPayload({required this.rounds, required this.rules});

  final List<PriceRound> rounds;

  @override
  final List<TaskRule> rules;
}
