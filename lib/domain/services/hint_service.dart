import '../models/models.dart';
import '../ru_words.dart';
import '../text_template.dart';
import 'task_engine.dart';

sealed class HintSituation {
  const HintSituation();
}

final class BoardSituation extends HintSituation {
  const BoardSituation(this.run);

  final BoardRun run;
}

final class StallSituation extends HintSituation {
  const StallSituation({
    required this.day,
    required this.coins,
    required this.portions,
    required this.price,
    required this.dayShown,
  });

  final int day;
  final int coins;
  final int portions;
  final int price;
  final bool dayShown;
}

final class CashierSituation extends HintSituation {
  const CashierSituation({
    required this.customer,
    required this.given,
    required this.answered,
  });

  final int customer;
  final int given;
  final bool answered;
}

final class PriceTagSituation extends HintSituation {
  const PriceTagSituation({required this.round, required this.picked});

  final int round;
  final bool picked;
}

final class TaskHint {
  const TaskHint(this.text, {this.ready = false});

  final String text;
  final bool ready;
}

final class HintService {
  const HintService(this.texts);

  final TextGroup texts;

  static Set<String> get keys => TextGroup.hintKeys;


  String _t(String key, [Map<String, String> values = const {}]) =>
      fillPlurals(fillTemplate(texts[key], values));

  static String _coins(int n) => '$n ${ruCoins(n)}';
  static String _portions(int n) => '$n ${ruPlural(n, 'порция', 'порции', 'порций')}';
  static String _cards(int n) => '$n ${ruPlural(n, 'карточка', 'карточки', 'карточек')}';

  TaskHint hint(TaskVariant variant, {TaskAnswer? answer, HintSituation? situation}) =>
      switch (variant.payload) {
        SortPayload payload => _sort(payload, answer is SortAnswer ? answer : null),
        CoinsPayload payload => _coinsHint(payload, answer is CoinsAnswer ? answer : null),
        DistributePayload payload =>
          _distribute(payload, answer is DistributeAnswer ? answer : null),
        OrderPayload payload => _order(payload, answer is OrderAnswer ? answer : null),
        ChoicePayload() => TaskHint(_t('choice', {'hint': variant.hint})),
        BasketPayload payload => _basket(payload, answer is BasketAnswer ? answer : null),
        WeekPayload payload => _week(payload, answer is WeekAnswer ? answer : null),
        BoardPayload payload => _board(payload,
            situation is BoardSituation ? situation.run : BoardRun.start(payload)),
        StallPayload payload =>
          _stall(payload, situation is StallSituation ? situation : null),
        CashierPayload payload =>
          _cashier(payload, situation is CashierSituation ? situation : null),
        PriceTagPayload payload =>
          _priceTag(payload, situation is PriceTagSituation ? situation : null),
      };

  TaskHint _sort(SortPayload payload, SortAnswer? answer) {
    final placed = answer?.binByCard ?? const <String, String>{};
    final wrong = [
      for (final card in payload.cards)
        if (placed[card.id] case final bin? when bin != card.bin) card
    ];
    if (wrong.length == 1) {
      return TaskHint(_t('sortWrong', {'card': wrong.first.label}));
    }
    if (wrong.length > 1) {
      return TaskHint(_t('sortWrongMany',
          {'count': _cards(wrong.length), 'card': wrong.first.label}));
    }
    final waiting = [for (final card in payload.cards) if (!placed.containsKey(card.id)) card];
    if (waiting.isEmpty) return TaskHint(_t('sortReady'), ready: true);
    if (placed.isEmpty) return TaskHint(_t('sortStart', {'card': waiting.first.label}));
    return TaskHint(
        _t('sortRest', {'count': _cards(waiting.length), 'card': waiting.first.label}));
  }

  TaskHint _coinsHint(CoinsPayload payload, CoinsAnswer? answer) {
    final counts = answer?.coinsByDenomination ?? const <int, int>{};
    var sum = 0;
    var count = 0;
    counts.forEach((coin, n) {
      sum += coin * n;
      count += n;
    });
    final need = payload.expected;
    if (sum == 0) {
      return payload.mode == CoinsMode.change
          ? TaskHint(_t('changeStart', {
              'price': _coins(payload.price),
              'paid': _coins(payload.paid ?? 0),
            }))
          : TaskHint(_t('coinsStart', {'need': _coins(need)}));
    }
    if (sum < need) {
      return TaskHint(_t('coinsLess',
          {'sum': _coins(sum), 'need': _coins(need), 'gap': _coins(need - sum)}));
    }
    if (sum > need) {
      return TaskHint(_t('coinsMore',
          {'sum': _coins(sum), 'need': _coins(need), 'gap': _coins(sum - need)}));
    }
    int? limit;
    for (final rule in payload.rules) {
      if (rule.type == TaskRuleType.maxCoins) limit = rule.value;
    }
    if (limit != null && count > limit) {
      return TaskHint(_t('coinsMany', {'count': '$count', 'max': '$limit'}));
    }
    return TaskHint(_t('coinsReady', {'need': _coins(need)}), ready: true);
  }

  TaskHint _distribute(DistributePayload payload, DistributeAnswer? answer) {
    final amounts = answer?.amountByCounter ?? const <String, int>{};
    if (payload.pool == null) return _days(payload, amounts);
    for (final rule in payload.rules) {
      final id = rule.counterId;
      final counter = id == null ? null : payload.counter(id);
      if (counter == null || rule.value == null) continue;
      final label = counter.label.isNotEmpty ? counter.label : _jarLabel(counter.id);
      final have = (amounts[id] ?? 0) * counter.unitValue;
      final limit = rule.value! * counter.unitValue;
      if (rule.type == TaskRuleType.atLeast && have < limit) {
        return TaskHint(_t('jarShort', {
          'label': label,
          'need': _coins(limit),
          'have': _coins(have),
          'gap': _coins(limit - have),
        }));
      }
      if (rule.type == TaskRuleType.atMost && have > limit) {
        return TaskHint(_t('jarOver',
            {'label': label, 'limit': _coins(limit), 'have': _coins(have)}));
      }
    }
    var used = 0;
    for (final counter in payload.counters) {
      used += (amounts[counter.id] ?? 0) * counter.unitValue;
    }
    final left = payload.pool! - used;
    if (left > 0) return TaskHint(_t('jarLeft', {'left': _coins(left)}));
    return TaskHint(_t('jarReady'), ready: true);
  }

  String _jarLabel(String id) => switch (id) {
        'mandatory' => texts['labelMandatory'],
        'optional' => texts['labelOptional'],
        'savings' => texts['labelSavings'],
        _ => id,
      };

  TaskHint _days(DistributePayload payload, Map<String, int> amounts) {
    final counter = payload.counters.first;
    final days = amounts[counter.id] ?? 0;
    final target = payload.target ?? 0;
    final sum = days * counter.unitValue;
    String dayWord(int n) => '$n ${ruDays(n)}';
    if (sum < target) {
      return TaskHint(_t('daysFew', {
        'days': dayWord(days),
        'sum': _coins(sum),
        'target': _coins(target),
        'gap': _coins(target - sum),
      }));
    }
    final fewer = days - 1;
    if (fewer >= 0 && fewer * counter.unitValue >= target) {
      return TaskHint(_t('daysMany', {
        'fewer': dayWord(fewer),
        'fewerSum': _coins(fewer * counter.unitValue),
        'target': _coins(target),
      }));
    }
    return TaskHint(_t('daysReady', {'days': dayWord(days), 'sum': _coins(sum)}),
        ready: true);
  }

  TaskHint _order(OrderPayload payload, OrderAnswer? answer) {
    final byId = {for (final item in payload.items) item.id: item};
    final order = [
      for (final id in answer?.itemIds ?? [for (final item in payload.items) item.id])
        if (byId[id] case final item?) item
    ];
    for (var i = 0; i + 1 < order.length; i++) {
      if (order[i].rank > order[i + 1].rank) {
        return TaskHint(_t('orderSwap', {'a': order[i].label, 'b': order[i + 1].label}));
      }
    }
    return TaskHint(_t('orderReady'), ready: true);
  }

  TaskHint _basket(BasketPayload payload, BasketAnswer? answer) {
    final chosen = answer?.productIds ?? const <String>{};
    final total = payload.products
        .where((p) => chosen.contains(p.id))
        .fold(0, (sum, p) => sum + p.price);
    if (total > payload.budget) {
      return TaskHint(_t('basketOver', {'gap': _coins(total - payload.budget)}));
    }
    final missing = [for (final p in payload.fromList) if (!chosen.contains(p.id)) p];
    if (missing.isNotEmpty) {
      return chosen.isEmpty
          ? TaskHint(_t('basketStart', {
              'item': missing.first.label,
              'list': _coins(payload.listCost),
              'budget': _coins(payload.budget),
            }))
          : TaskHint(_t('basketMissing', {'item': missing.first.label}));
    }
    final left = payload.budget - total;
    final canAdd = payload.products
        .any((p) => !p.onList && !chosen.contains(p.id) && p.price <= left);
    if (canAdd) return TaskHint(_t('basketRoom', {'left': _coins(left)}), ready: true);
    return TaskHint(_t('basketReady'), ready: true);
  }

  TaskHint _week(WeekPayload payload, WeekAnswer? answer) {
    final saved = answer?.savedByDay ?? const <int>[];
    if (saved.every((s) => s == 0)) {
      return TaskHint(_t('weekStart', {
        'events': [
          for (final event in payload.events) 'день ${event.day} — «${event.label}»'
        ].join(', '),
      }));
    }
    var wallet = 0;
    var savings = 0;
    for (var day = 1; day <= payload.days; day++) {
      final put = day - 1 < saved.length ? saved[day - 1] : 0;
      wallet += payload.dailyIncome - put;
      savings += put;
      final event = payload.eventOn(day);
      if (event != null) {
        if (wallet < event.cost) {
          return TaskHint(_t('weekShort', {
            'day': '$day',
            'label': event.label,
            'gap': _coins(event.cost - wallet),
          }));
        }
        wallet -= event.cost;
      }
    }
    if (savings < payload.target) {
      return TaskHint(_t('weekGoal',
          {'target': _coins(payload.target), 'gap': _coins(payload.target - savings)}));
    }
    return TaskHint(_t('weekReady'), ready: true);
  }

  TaskHint _board(BoardPayload payload, BoardRun run) {
    final gap = payload.target - run.savings;
    BoardCell? ahead;
    for (var i = run.position + 1; i < payload.cells.length; i++) {
      if (payload.cells[i].kind == BoardCellKind.expense) {
        ahead = payload.cells[i];
        break;
      }
    }
    final aheadText = ahead == null
        ? ''
        : _t('boardAhead', {'label': ahead.label, 'cost': _coins(ahead.amount)});
    if (run.isFinished) {
      return TaskHint(_t('boardDone',
          {'savings': _coins(run.savings), 'target': _coins(payload.target)}));
    }
    final cell = run.cell;
    if (run.pending && cell.kind == BoardCellKind.temptation) {
      return TaskHint(_t('boardTemptation', {
        'label': cell.label,
        'cost': _coins(cell.amount),
        'wallet': _coins(run.wallet),
        'after': _coins(run.wallet - cell.amount < 0 ? 0 : run.wallet - cell.amount),
        'ahead': aheadText,
      }));
    }
    if (run.pending && cell.kind == BoardCellKind.piggy) {
      final values = {
        'wallet': _coins(run.wallet),
        'ahead': aheadText,
        'gap': _coins(gap < 0 ? 0 : gap),
        'keep': _coins(ahead?.amount ?? 0),
      };
      return TaskHint(_t(ahead == null ? 'boardPiggyFree' : 'boardPiggy', values));
    }
    return TaskHint(_t('boardRoll', {
      'savings': _coins(run.savings),
      'target': _coins(payload.target),
      'ahead': aheadText,
    }));
  }

  TaskHint _stall(StallPayload payload, StallSituation? situation) {
    if (situation == null || situation.day >= payload.days.length) {
      return TaskHint(_t('stallResult'));
    }
    if (situation.dayShown) return TaskHint(_t('stallResult'));
    final day = payload.days[situation.day];
    final demand = day.demand[situation.price] ?? 0;
    final portions = situation.portions;
    final String advice;
    if (portions > demand) {
      advice = _t('stallExtra', {'extra': _portions(portions - demand)});
    } else if (portions < demand &&
        payload.portionOptions(situation.coins).any((p) => p > portions)) {
      advice = _t('stallMore', {'more': _portions(demand - portions)});
    } else {
      advice = _t('stallFits');
    }
    return TaskHint(_t('stallPlan', {
      'label': day.label.toLowerCase(),
      'price': _coins(situation.price),
      'demand': _portions(demand),
      'portions': _portions(portions),
      'advice': advice,
    }));
  }

  TaskHint _cashier(CashierPayload payload, CashierSituation? situation) {
    final index = situation?.customer ?? 0;
    if (index >= payload.customers.length) return TaskHint(_t('cashierNext'));
    if (situation?.answered ?? false) return TaskHint(_t('cashierNext'));
    final customer = payload.customers[index];
    final given = situation?.given ?? 0;
    if (given == 0) {
      if (!payload.showTotal && customer.items.length > 1) {
        return TaskHint(_t('cashierTotal', {
          'sum': [for (final item in customer.items) '${item.price}'].join(' + '),
          'paid': _coins(customer.paid),
        }));
      }
      return TaskHint(_t('cashierStart',
          {'total': _coins(customer.total), 'paid': _coins(customer.paid)}));
    }
    final reached = customer.total + given;
    final values = {
      'total': '${customer.total}',
      'given': '$given',
      'reached': '$reached',
      'paid': '${customer.paid}',
    };
    if (reached < customer.paid) return TaskHint(_t('cashierLess', values));
    if (reached > customer.paid) return TaskHint(_t('cashierMore', values));
    return TaskHint(_t('cashierReady'), ready: true);
  }

  TaskHint _priceTag(PriceTagPayload payload, PriceTagSituation? situation) {
    final index = situation?.round ?? 0;
    if (index >= payload.rounds.length || (situation?.picked ?? false)) {
      return TaskHint(_t('priceNext'));
    }
    final round = payload.rounds[index];
    final extra = [for (final offer in round.offers) if (!offer.fits) offer];
    if (extra.isNotEmpty) {
      return TaskHint(
          '${_t('priceExtra', {'label': extra.first.label})} ${_t('priceCompare', {'need': round.need})}');
    }
    return TaskHint(_t('priceCompare', {'need': round.need}));
  }
}
