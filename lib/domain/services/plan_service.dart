/// План дня: раскладка дохода по трём направлениям шагом в 5 монет.
/// Больше дохода не разложить, после подтверждения план заморожен.
/// Мало на обязательное — подсказка, но не запрет.
library;

import '../models/budget_plan.dart';

enum PlanDirection { mandatory, optional, savings }

/// Подсказка «на обязательное может не хватить».
final class PlanHint {
  const PlanHint({
    required this.needed,
    required this.allocated,
  });

  final int needed;
  final int allocated;

  int get gap => needed - allocated;

  String get textRu =>
      'Обязательных расходов на $needed, ты отложил $allocated. '
      'Не хватит $gap';
}

final class PlanService {
  PlanService({
    required int income,
    this.step = 5,
    this.mandatoryCost = 0,
  }) : _plan = BudgetPlan.empty(income);

  /// Шаг раскладки в монетах.
  final int step;

  /// Сколько стоят обязательные позиции дня — для подсказки.
  final int mandatoryCost;

  BudgetPlan _plan;
  bool _confirmed = false;

  BudgetPlan get plan => _plan;
  bool get isConfirmed => _confirmed;
  int get remainder => _plan.remainder;

  /// Ставит сумму направления. Не применяет, если план подтверждён,
  /// значение отрицательное, не кратно шагу или сумма вылезает за доход.
  /// Возвращает (применилось ли, текущий остаток).
  (bool applied, int remainder) setAmount(PlanDirection direction, int value) {
    if (_confirmed) throw StateError('план уже подтверждён');
    if (value < 0) return (false, _plan.remainder);

    final next = switch (direction) {
      PlanDirection.mandatory => (
          m: value,
          o: _plan.optional,
          s: _plan.savings,
        ),
      PlanDirection.optional => (
          m: _plan.mandatory,
          o: value,
          s: _plan.savings,
        ),
      PlanDirection.savings => (
          m: _plan.mandatory,
          o: _plan.optional,
          s: value,
        ),
    };
    final total = next.m + next.o + next.s;
    if (total > _plan.income) return (false, _plan.remainder);
    // Некратный шаг — только чтобы разложить последние монеты дохода.
    if (value % step != 0 && total != _plan.income) {
      return (false, _plan.remainder);
    }
    _plan = BudgetPlan.create(
      mandatory: next.m,
      optional: next.o,
      savings: next.s,
      income: _plan.income,
    );
    return (true, _plan.remainder);
  }

  /// Прибавить шаг к направлению (кнопка «+»).
  /// Когда осталось меньше шага, добавляет остаток целиком.
  (bool applied, int remainder) increase(PlanDirection d) {
    final left = _plan.remainder;
    if (left <= 0) return (false, left);
    return setAmount(d, _amountOf(d) + (left < step ? left : step));
  }

  /// Убавить шаг (кнопка «−»); некратная сумма сначала округляется вниз.
  (bool applied, int remainder) decrease(PlanDirection d) {
    final amount = _amountOf(d);
    final cut = amount % step == 0 ? step : amount % step;
    return setAmount(d, amount - cut);
  }

  int _amountOf(PlanDirection d) => switch (d) {
        PlanDirection.mandatory => _plan.mandatory,
        PlanDirection.optional => _plan.optional,
        PlanDirection.savings => _plan.savings,
      };

  /// Подсказка, если на обязательное выделено меньше, чем оно стоит.
  /// Это лампочка, не запрет: confirm работает и с ней.
  PlanHint? hint() {
    if (mandatoryCost <= 0 || _plan.mandatory >= mandatoryCost) return null;
    return PlanHint(needed: mandatoryCost, allocated: _plan.mandatory);
  }

  /// Фиксирует план. Дальше он только для чтения.
  BudgetPlan confirm() {
    _confirmed = true;
    return _plan;
  }
}
