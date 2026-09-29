import 'package:flutter_test/flutter_test.dart';
import 'package:finni/domain/services/plan_service.dart';

void main() {
  group('раскладка', () {
    test('setAmount ставит суммы, остаток считается', () {
      final p = PlanService(income: 40);
      p.setAmount(PlanDirection.mandatory, 25);
      p.setAmount(PlanDirection.optional, 5);
      final (ok, rest) = p.setAmount(PlanDirection.savings, 10);
      expect(ok, isTrue);
      expect(rest, 0);
      expect(p.plan.mandatory, 25);
      expect(p.plan.savings, 10);
    });

    test('больше дохода не разложить: значение не применяется', () {
      final p = PlanService(income: 40);
      p.setAmount(PlanDirection.mandatory, 25);
      final (ok, rest) = p.setAmount(PlanDirection.optional, 20);
      expect(ok, isFalse);
      expect(rest, 15);
      expect(p.plan.optional, 0);
    });

    test('шаг 5: некратные и отрицательные значения отбрасываются', () {
      final p = PlanService(income: 40);
      expect(p.setAmount(PlanDirection.savings, 7).$1, isFalse);
      expect(p.setAmount(PlanDirection.savings, -5).$1, isFalse);
      expect(p.plan.savings, 0);
    });

    test('остаток меньше шага можно разложить, минус сначала округляет вниз', () {
      final p = PlanService(income: 42);
      expect(p.setAmount(PlanDirection.mandatory, 40).$1, isTrue);
      expect(p.setAmount(PlanDirection.savings, 3).$1, isFalse);
      expect(p.increase(PlanDirection.savings).$1, isTrue);
      expect(p.plan.savings, 2);
      expect(p.remainder, 0);
      expect(p.increase(PlanDirection.savings).$1, isFalse);
      expect(p.decrease(PlanDirection.savings).$1, isTrue);
      expect(p.plan.savings, 0);
      p.decrease(PlanDirection.mandatory);
      expect(p.plan.mandatory, 35);
      p.increase(PlanDirection.optional);
      expect(p.plan.optional, 5);
      p.increase(PlanDirection.optional);
      expect(p.plan.optional, 7);
      p.decrease(PlanDirection.optional);
      expect(p.plan.optional, 5);
    });

    test('плюс и минус ходят по шагу и не ломают границы', () {
      final p = PlanService(income: 10);
      expect(p.increase(PlanDirection.savings).$1, isTrue); // 5
      expect(p.increase(PlanDirection.savings).$1, isTrue); // 10
      expect(p.increase(PlanDirection.savings).$1, isFalse); // доход кончился
      expect(p.plan.savings, 10);
      p.decrease(PlanDirection.savings);
      p.decrease(PlanDirection.savings);
      expect(p.decrease(PlanDirection.savings).$1, isFalse); // ниже нуля нельзя
      expect(p.plan.savings, 0);
    });
  });

  group('подсказка', () {
    test('мало на обязательное — лампочка с расчётом', () {
      final p = PlanService(income: 40, mandatoryCost: 25);
      p.setAmount(PlanDirection.mandatory, 15);
      final h = p.hint();
      expect(h, isNotNull);
      expect(h!.gap, 10);
      expect(h.textRu, contains('на 25'));
      expect(h.textRu, contains('отложил 15'));
      expect(h.textRu, contains('Не хватит 10'));
    });

    test('хватает — подсказки нет', () {
      final p = PlanService(income: 40, mandatoryCost: 25);
      p.setAmount(PlanDirection.mandatory, 25);
      expect(p.hint(), isNull);
    });

    test('подсказка не блокирует подтверждение', () {
      final p = PlanService(income: 40, mandatoryCost: 25);
      p.setAmount(PlanDirection.mandatory, 5);
      expect(p.hint(), isNotNull);
      final plan = p.confirm();
      expect(p.isConfirmed, isTrue);
      expect(plan.mandatory, 5);
    });
  });

  group('подтверждение', () {
    test('после confirm план менять нельзя', () {
      final p = PlanService(income: 40);
      p.setAmount(PlanDirection.savings, 10);
      p.confirm();
      expect(
          () => p.setAmount(PlanDirection.savings, 15), throwsStateError);
      expect(() => p.increase(PlanDirection.optional), throwsStateError);
      expect(p.plan.savings, 10);
    });
  });
}
