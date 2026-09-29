import '../models/models.dart';
import '../ru_words.dart';
import '../text_template.dart';
import 'wallet_service.dart';

sealed class TaskAnswer {
  const TaskAnswer();
}

final class SortAnswer extends TaskAnswer {
  const SortAnswer(this.binByCard);

  final Map<String, String> binByCard;
}

final class CoinsAnswer extends TaskAnswer {
  const CoinsAnswer(this.coinsByDenomination);

  final Map<int, int> coinsByDenomination;
}

final class DistributeAnswer extends TaskAnswer {
  const DistributeAnswer(this.amountByCounter);

  final Map<String, int> amountByCounter;
}

final class OrderAnswer extends TaskAnswer {
  const OrderAnswer(this.itemIds);

  final List<String> itemIds;
}

final class ChoiceAnswer extends TaskAnswer {
  const ChoiceAnswer(this.optionId);

  final String optionId;
}

final class BasketAnswer extends TaskAnswer {
  const BasketAnswer(this.productIds);

  final Set<String> productIds;
}

final class WeekAnswer extends TaskAnswer {
  const WeekAnswer(this.savedByDay);

  final List<int> savedByDay;
}

final class BoardAnswer extends TaskAnswer {
  const BoardAnswer(this.decisions);

  final List<int> decisions;
}

final class StallAnswer extends TaskAnswer {
  const StallAnswer(this.choices);

  final List<StallChoice> choices;
}

final class CashierAnswer extends TaskAnswer {
  const CashierAnswer(this.changes);

  final List<Map<int, int>> changes;
}

final class PriceTagAnswer extends TaskAnswer {
  const PriceTagAnswer(this.offerIds);

  final List<String> offerIds;
}

enum TaskVerdict { correct, wrong, incomplete }

final class TaskCheck {
  const TaskCheck._({
    required this.verdict,
    required this.failCode,
    required this.explanation,
    required this.details,
    required this.placedRight,
  });

  static const String misplacedCode = 'misplaced';
  static const String overPoolCode = 'overPool';
  static const String wrongOptionCode = 'wrongOption';
  static const String missingRequiredCode = 'missingRequired';
  static const String overBudgetCode = 'overBudget';

  final TaskVerdict verdict;
  final String? failCode;
  final String explanation;
  final List<String> details;
  final Set<String> placedRight;

  bool get isCorrect => verdict == TaskVerdict.correct;
}

final class TaskFeedback {
  const TaskFeedback._({
    required this.check,
    required this.attempt,
    required this.completion,
  });

  final TaskCheck check;
  final int attempt;
  final TaskCompletion? completion;

  TaskVerdict get verdict => check.verdict;
  bool get isCorrect => check.isCorrect;
  String get explanation => check.explanation;
  bool get canRetry => completion == null;
}

final class TaskCompletion {
  const TaskCompletion._({
    required this.taskId,
    required this.coins,
    required this.firstTime,
    required this.withMistakes,
    required this.attempts,
    required this.reasonText,
  });

  final String taskId;
  final int coins;
  final bool firstTime;
  final bool withMistakes;
  final int attempts;
  final String reasonText;

  String get sourceId => 'task:$taskId';
}

final class TaskEngine {
  TaskEngine({
    required this.catalog,
    required this.rewards,
    Iterable<String> completedTaskIds = const [],
  }) : _completed = {...completedTaskIds};

  final TaskCatalog catalog;
  final TaskRewardRules rewards;
  final Set<String> _completed;

  Set<String> get completedTaskIds => Set.unmodifiable(_completed);

  bool isCompleted(String taskId) => _completed.contains(taskId);

  TaskSession start(String taskId, TaskDifficulty difficulty,
      {int index = 0, TaskPool pool = TaskPool.practice}) {
    final task = catalog.byId(taskId);
    if (task == null) {
      throw ArgumentError.value(taskId, 'taskId', 'нет такого задания');
    }
    final list = task.variantsIn(pool, difficulty);
    final at = index % list.length;
    return TaskSession._(this, task, list[at],
        index: at,
        count: list.length,
        variantKey: task.keyIn(pool, difficulty, at));
  }

  TaskCompletion _complete(TaskSession session, {bool solved = true}) {
    final task = session.task;
    final firstTime = !_completed.contains(task.id);
    if (!solved) {
      return TaskCompletion._(
        taskId: task.id,
        coins: 0,
        firstTime: firstTime,
        withMistakes: true,
        attempts: session.attempts,
        reasonText:
            fillTemplate(rewards.reasonTemplate, {'taskTitle': task.title}),
      );
    }
    final withMistakes = session.mistakes > 0;
    final full = withMistakes ? task.reward.wrong : task.reward.correct;
    final coins = firstTime
        ? full
        : rewards.repeatReward < full
            ? rewards.repeatReward
            : full;
    _completed.add(task.id);
    return TaskCompletion._(
      taskId: task.id,
      coins: coins,
      firstTime: firstTime,
      withMistakes: withMistakes,
      attempts: session.attempts,
      reasonText: fillTemplate(rewards.reasonTemplate, {'taskTitle': task.title}),
    );
  }

  TaskCheck evaluate(TaskDef task, TaskVariant variant, TaskAnswer answer) =>
      switch ((variant.payload, answer)) {
        (SortPayload p, SortAnswer a) => _sort(variant, p, a),
        (CoinsPayload p, CoinsAnswer a) => _coins(variant, p, a),
        (DistributePayload p, DistributeAnswer a) => _distribute(variant, p, a),
        (OrderPayload p, OrderAnswer a) => _order(variant, p, a),
        (ChoicePayload p, ChoiceAnswer a) => _choice(task, variant, p, a),
        (BasketPayload p, BasketAnswer a) => _basket(variant, p, a),
        (WeekPayload p, WeekAnswer a) => _week(variant, p, a),
        (BoardPayload p, BoardAnswer a) => _board(variant, p, a),
        (StallPayload p, StallAnswer a) => _stall(variant, p, a),
        (CashierPayload p, CashierAnswer a) => _cashier(variant, p, a),
        (PriceTagPayload p, PriceTagAnswer a) => _pricetag(variant, p, a),
        _ => throw ArgumentError.value(answer.runtimeType, 'answer',
            'ответ не подходит к заданию типа ${task.type.name}'),
      };

  TaskCheck _correct(TaskVariant variant, Map<String, String> values,
          {String? explanation, Set<String> placedRight = const {}}) =>
      TaskCheck._(
        verdict: TaskVerdict.correct,
        failCode: null,
        explanation: _render(explanation ?? variant.explanationCorrect, values),
        details: const [],
        placedRight: Set.unmodifiable(placedRight),
      );

  TaskCheck _wrong(
    TaskVariant variant,
    String failCode,
    Map<String, String> values, {
    String? explanation,
    List<String> details = const [],
    Set<String> placedRight = const {},
  }) =>
      TaskCheck._(
        verdict: TaskVerdict.wrong,
        failCode: failCode,
        explanation: _render(explanation ?? variant.explanationFor(failCode), values),
        details: List.unmodifiable(details),
        placedRight: Set.unmodifiable(placedRight),
      );

  TaskCheck _incomplete(String text, Map<String, String> values) => TaskCheck._(
        verdict: TaskVerdict.incomplete,
        failCode: null,
        explanation: _render(text, values),
        details: const [],
        placedRight: const {},
      );

  static String _render(String template, Map<String, String> values) =>
      fillPlurals(fillTemplate(template, values));

  static TaskRule? _firstFailed(List<TaskRule> rules, bool Function(TaskRule rule) passes) {
    for (final rule in rules) {
      if (!passes(rule)) return rule;
    }
    return null;
  }

  static Never _unsupportedRule(TaskRule rule, TaskType type) =>
      throw ArgumentError.value(
          rule.type.name, 'rules', 'правило не применяется к заданиям ${type.name}');

  TaskCheck _sort(TaskVariant variant, SortPayload payload, SortAnswer answer) {
    final cardIds = {for (final card in payload.cards) card.id};
    for (final entry in answer.binByCard.entries) {
      if (!cardIds.contains(entry.key)) {
        throw ArgumentError.value(entry.key, 'answer', 'нет такой карточки');
      }
      if (!payload.bins.contains(entry.value)) {
        throw ArgumentError.value(entry.value, 'answer', 'нет такой корзины');
      }
    }
    final left = payload.cards.length - answer.binByCard.length;
    if (left > 0) {
      return _incomplete(catalog.texts.sort.notAllPlaced, {'count': '$left'});
    }
    final misplaced = [
      for (final card in payload.cards)
        if (answer.binByCard[card.id] != card.bin) card,
    ];
    final placedRight = {
      for (final card in payload.cards)
        if (answer.binByCard[card.id] == card.bin) card.id,
    };
    if (misplaced.isEmpty) {
      return _correct(variant, const {}, placedRight: placedRight);
    }
    return _wrong(
      variant,
      TaskCheck.misplacedCode,
      {'why': misplaced.first.why},
      details: [for (final card in misplaced) card.why],
      placedRight: placedRight,
    );
  }

  TaskCheck _coins(TaskVariant variant, CoinsPayload payload, CoinsAnswer answer) {
    var sum = 0;
    var count = 0;
    for (final entry in answer.coinsByDenomination.entries) {
      final available = payload.wallet[entry.key];
      if (available == null) {
        throw ArgumentError.value(entry.key, 'answer', 'нет такой монеты');
      }
      if (entry.value < 0 || entry.value > available) {
        throw ArgumentError.value(entry.value, 'answer', 'столько монет нет');
      }
      sum += entry.key * entry.value;
      count += entry.value;
    }
    final values = {
      'onCounter': '$sum',
      'price': '${payload.price}',
      'expected': '${payload.expected}',
      if (payload.paid != null) 'paid': '${payload.paid}',
    };
    final failed = _firstFailed(payload.rules, (rule) => switch (rule.type) {
          TaskRuleType.sumAtLeast => sum >= rule.value!,
          TaskRuleType.sumAtMost => sum <= rule.value!,
          TaskRuleType.maxCoins => count <= rule.value!,
          _ => _unsupportedRule(rule, TaskType.coins),
        });
    if (failed == null) return _correct(variant, values);
    return _wrong(variant, failed.failCode, values);
  }

  TaskCheck _distribute(
      TaskVariant variant, DistributePayload payload, DistributeAnswer answer) {
    for (final id in answer.amountByCounter.keys) {
      if (payload.counter(id) == null) {
        throw ArgumentError.value(id, 'answer', 'нет такого счётчика');
      }
    }
    final amounts = <String, int>{};
    var total = 0;
    for (final counter in payload.counters) {
      final amount = answer.amountByCounter[counter.id] ?? counter.min;
      final max = counter.max;
      if (amount < counter.min || (max != null && amount > max)) {
        throw ArgumentError.value(amount, counter.id, 'вне границ счётчика');
      }
      if (amount % counter.step != 0) {
        throw ArgumentError.value(amount, counter.id, 'не кратно шагу ${counter.step}');
      }
      amounts[counter.id] = amount;
      total += amount * counter.unitValue;
    }
    final pool = payload.pool;
    final values = {
      'total': '$total',
      if (pool != null) 'remainder': '${pool - total}',
      if (payload.target != null) 'target': '${payload.target}',
    };
    if (pool != null && total > pool) {
      return _wrong(variant, TaskCheck.overPoolCode, values);
    }
    final failed = _firstFailed(payload.rules, (rule) {
      final amount = amounts[rule.counterId] ?? 0;
      return switch (rule.type) {
        TaskRuleType.atLeast => amount >= rule.value!,
        TaskRuleType.atMost => amount <= rule.value!,
        _ => _unsupportedRule(rule, TaskType.distribute),
      };
    });
    if (failed == null) return _correct(variant, values);
    return _wrong(variant, failed.failCode, values);
  }

  TaskCheck _order(TaskVariant variant, OrderPayload payload, OrderAnswer answer) {
    final byId = {for (final item in payload.items) item.id: item};
    if (answer.itemIds.length != payload.items.length ||
        answer.itemIds.toSet().length != answer.itemIds.length ||
        !answer.itemIds.every(byId.containsKey)) {
      throw ArgumentError.value(answer.itemIds, 'answer', 'нужны все карточки по разу');
    }
    final expectedRanks = [for (final item in payload.items) item.rank]..sort();
    final placed = [for (final id in answer.itemIds) byId[id]!];
    final placedRight = <String>{};
    final misplaced = <OrderItem>[];
    for (var i = 0; i < placed.length; i++) {
      if (placed[i].rank == expectedRanks[i]) {
        placedRight.add(placed[i].id);
      } else {
        misplaced.add(placed[i]);
      }
    }
    final failed = _firstFailed(payload.rules, (rule) => switch (rule.type) {
          TaskRuleType.nonDecreasingRank => misplaced.isEmpty,
          _ => _unsupportedRule(rule, TaskType.order),
        });
    if (failed == null && misplaced.isEmpty) {
      return _correct(variant, const {}, placedRight: placedRight);
    }
    return _wrong(
      variant,
      failed?.failCode ?? TaskCheck.misplacedCode,
      {'why': misplaced.first.why},
      details: [for (final item in misplaced) item.why],
      placedRight: placedRight,
    );
  }

  TaskCheck _choice(
      TaskDef task, TaskVariant variant, ChoicePayload payload, ChoiceAnswer answer) {
    ChoiceOption? chosen;
    for (final option in payload.options) {
      if (option.id == answer.optionId) chosen = option;
    }
    if (chosen == null) {
      throw ArgumentError.value(answer.optionId, 'answer', 'нет такого варианта');
    }
    if (chosen.isCorrect || task.allOptionsValid) {
      return _correct(variant, const {}, explanation: chosen.explanation);
    }
    return _wrong(variant, TaskCheck.wrongOptionCode, const {},
        explanation: chosen.explanation);
  }

  TaskCheck _basket(TaskVariant variant, BasketPayload payload, BasketAnswer answer) {
    final byId = {for (final product in payload.products) product.id: product};
    for (final id in answer.productIds) {
      if (!byId.containsKey(id)) {
        throw ArgumentError.value(id, 'answer', 'нет такого товара');
      }
    }
    var total = 0;
    for (final id in answer.productIds) {
      total += byId[id]!.price;
    }
    final missing = [
      for (final product in payload.fromList)
        if (!answer.productIds.contains(product.id)) product,
    ];
    final values = {
      'total': '$total',
      'budget': '${payload.budget}',
      'left': '${payload.budget - total}',
      'gap': '${total - payload.budget}',
      'item': [for (final product in missing) product.label.toLowerCase()].join(', '),
    };
    if (missing.isNotEmpty) {
      return _wrong(variant, TaskCheck.missingRequiredCode, values,
          details: [for (final product in missing) product.label]);
    }
    if (total > payload.budget) {
      return _wrong(variant, TaskCheck.overBudgetCode, values);
    }
    return _correct(variant, values);
  }

  TaskCheck _week(TaskVariant variant, WeekPayload payload, WeekAnswer answer) {
    if (answer.savedByDay.length != payload.days) {
      throw ArgumentError.value(
          answer.savedByDay.length, 'answer', 'нужно решение на каждый из ${payload.days} дней');
    }
    for (final saved in answer.savedByDay) {
      if (saved < 0 || saved > payload.maxSavePerDay || saved % payload.step != 0) {
        throw ArgumentError.value(saved, 'answer', 'так отложить нельзя');
      }
    }
    var wallet = 0;
    var savings = 0;
    int? shortDay;
    var shortLabel = '';
    var shortGap = 0;
    for (var day = 1; day <= payload.days; day++) {
      final saved = answer.savedByDay[day - 1];
      wallet += payload.dailyIncome - saved;
      savings += saved;
      final event = payload.eventOn(day);
      if (event != null) wallet -= event.cost;
      if (wallet < 0 && shortDay == null) {
        shortDay = day;
        shortLabel = event?.label ?? '';
        shortGap = -wallet;
      }
      if (wallet < 0) wallet = 0;
    }
    final values = {
      'wallet': '$wallet',
      'savings': '$savings',
      'target': '${payload.target}',
    };
    final failed = _firstFailed(payload.rules, (rule) => switch (rule.type) {
          TaskRuleType.neverNegative => shortDay == null,
          TaskRuleType.savingsAtLeast => savings >= rule.value!,
          _ => _unsupportedRule(rule, TaskType.week),
        });
    if (failed == null) return _correct(variant, values);
    final details = failed.type == TaskRuleType.neverNegative
        ? {'day': '$shortDay', 'label': shortLabel, 'gap': '$shortGap'}
        : {'gap': '${(failed.value ?? payload.target) - savings}'};
    return _wrong(variant, failed.failCode, {...values, ...details});
  }

  TaskCheck _board(TaskVariant variant, BoardPayload payload, BoardAnswer answer) {
    final BoardRun run;
    try {
      run = BoardRun.play(payload, answer.decisions);
    } on StateError catch (error) {
      throw ArgumentError.value(answer.decisions, 'answer', error.message);
    }
    final values = {
      'wallet': '${run.wallet}',
      'savings': '${run.savings}',
      'target': '${payload.target}',
      'joy': '${run.joy}',
    };
    final failed = _firstFailed(payload.rules, (rule) => switch (rule.type) {
          TaskRuleType.neverNegative => run.shortages.isEmpty,
          TaskRuleType.savingsAtLeast => run.savings >= rule.value!,
          _ => _unsupportedRule(rule, TaskType.board),
        });
    if (failed == null) return _correct(variant, values);
    final extra = failed.type == TaskRuleType.neverNegative
        ? {
            'label': run.shortages.first.cell.label,
            'gap': '${run.shortages.first.gap}',
          }
        : {'gap': '${failed.value! - run.savings}'};
    return _wrong(variant, failed.failCode, {...values, ...extra}, details: [
      for (final shortage in run.shortages)
        _render(catalog.texts.board['short'],
            {'label': shortage.cell.label, 'gap': '${shortage.gap}'}),
    ]);
  }

  TaskCheck _stall(TaskVariant variant, StallPayload payload, StallAnswer answer) {
    final results = payload.play(answer.choices);
    final coins = results.isEmpty ? payload.startCoins : results.last.coinsAfter;
    final texts = catalog.texts.stall;
    final details = [
      for (final result in results)
        [
          _render(texts['dayResult'], {
            'n': '${result.day}',
            'sold': '${result.sold}',
            'portions': '${result.choice.portions}',
            'revenue': '${result.revenue}',
          }),
          if (result.leftover > 0)
            _render(texts['leftover'], {'leftover': '${result.leftover}'}),
          if (result.missed > 0)
            _render(texts['missed'], {'missed': '${result.missed}'}),
        ].join(' '),
    ];
    final values = {'coins': '$coins', 'target': '${payload.target}'};
    final failed = _firstFailed(payload.rules, (rule) => switch (rule.type) {
          TaskRuleType.coinsAtLeast => coins >= rule.value!,
          _ => _unsupportedRule(rule, TaskType.stall),
        });
    if (failed == null) return _correct(variant, values);
    return _wrong(
        variant, failed.failCode, {...values, 'gap': '${failed.value! - coins}'},
        details: details);
  }

  TaskCheck _pricetag(
      TaskVariant variant, PriceTagPayload payload, PriceTagAnswer answer) {
    if (answer.offerIds.length != payload.rounds.length) {
      throw ArgumentError.value(
          answer.offerIds.length, 'answer', 'нужен выбор в каждой задаче');
    }
    final right = <String>{};
    final missed = <PriceOffer>[];
    for (var i = 0; i < payload.rounds.length; i++) {
      final round = payload.rounds[i];
      final chosen = round.offer(answer.offerIds[i]);
      if (chosen == null) {
        throw ArgumentError.value(answer.offerIds[i], 'answer', 'нет такого варианта');
      }
      if (chosen.id == round.best.id) {
        right.add(round.id);
      } else {
        missed.add(chosen);
      }
    }
    final values = {
      'count': '${right.length}',
      'total': '${payload.rounds.length}',
    };
    final failed = _firstFailed(payload.rules, (rule) => switch (rule.type) {
          TaskRuleType.bestDeal => missed.isEmpty,
          _ => _unsupportedRule(rule, TaskType.pricetag),
        });
    if (failed == null) return _correct(variant, values, placedRight: right);
    return _wrong(variant, failed.failCode, {...values, 'why': missed.first.why},
        details: [for (final offer in missed) offer.why], placedRight: right);
  }

  TaskCheck _cashier(
      TaskVariant variant, CashierPayload payload, CashierAnswer answer) {
    if (answer.changes.length != payload.customers.length) {
      throw ArgumentError.value(
          answer.changes.length, 'answer', 'нужна сдача для каждого покупателя');
    }
    final wrong = <(CashierCustomer, int)>[];
    final right = <String>{};
    for (var i = 0; i < payload.customers.length; i++) {
      final coins = answer.changes[i];
      for (final entry in coins.entries) {
        if (!payload.denominations.contains(entry.key) || entry.value < 0) {
          throw ArgumentError.value(entry.key, 'answer', 'нет такой монеты');
        }
      }
      final customer = payload.customers[i];
      final given = CashierPayload.sumOf(coins);
      if (given == customer.change) {
        right.add(customer.id);
      } else {
        wrong.add((customer, given));
      }
    }
    final failed = _firstFailed(payload.rules, (rule) => switch (rule.type) {
          TaskRuleType.exactChange => wrong.isEmpty,
          _ => _unsupportedRule(rule, TaskType.cashier),
        });
    if (failed == null) {
      return _correct(variant, {'count': '${payload.customers.length}'},
          placedRight: right);
    }
    final (first, given) = wrong.first;
    return _wrong(
      variant,
      failed.failCode,
      {
        'name': first.name,
        'total': '${first.total}',
        'paid': '${first.paid}',
        'change': '${first.change}',
        'given': '$given',
      },
      details: [
        for (final (customer, amount) in wrong)
          _render(catalog.texts.cashier['wrongLine'], {
            'name': customer.name,
            'change': '${customer.change}',
            'given': '$amount',
          }),
      ],
      placedRight: right,
    );
  }
}

final class TaskSession {
  TaskSession._(this._engine, this.task, this.variant,
      {this.index = 0, this.count = 1, required this.variantKey});

  final TaskEngine _engine;
  final TaskDef task;
  final TaskVariant variant;
  final int index;
  final int count;
  final String variantKey;

  int _attempts = 0;
  int _mistakes = 0;
  TaskCompletion? _completion;
  bool _collected = false;

  int get attempts => _attempts;
  int get mistakes => _mistakes;
  TaskCompletion? get completion => _completion;
  bool get isFinished => _completion != null;
  bool get isCollected => _collected;

  TaskFeedback submit(TaskAnswer answer) {
    if (_completion != null) {
      throw StateError('задание уже завершено');
    }
    final check = _engine.evaluate(task, variant, answer);
    if (check.verdict == TaskVerdict.incomplete) {
      return TaskFeedback._(check: check, attempt: _attempts, completion: null);
    }
    _attempts++;
    if (check.verdict == TaskVerdict.wrong) {
      _mistakes++;
      return TaskFeedback._(check: check, attempt: _attempts, completion: null);
    }
    _completion = _engine._complete(this);
    return TaskFeedback._(check: check, attempt: _attempts, completion: _completion);
  }

  TaskCompletion finish() {
    final done = _completion;
    if (done != null) return done;
    if (_attempts == 0) {
      throw StateError('сначала нужна хотя бы одна попытка');
    }
    return _completion = _engine._complete(this, solved: false);
  }

  WalletOk collect(
    WalletService wallet, {
    required DateTime at,
    required int dayNumber,
  }) {
    final done = _completion;
    if (done == null) throw StateError('задание ещё не завершено');
    if (_collected) throw StateError('награда уже получена');
    _collected = true;
    return wallet.earn(
      amount: done.coins,
      sourceId: done.sourceId,
      reasonText: done.reasonText,
      at: at,
      dayNumber: dayNumber,
    );
  }
}
