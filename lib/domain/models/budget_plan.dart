/// План на день: сколько на обязательное, желаемое и в копилку.
/// Разложить больше дохода нельзя.
library;

final class BudgetPlan {
  const BudgetPlan._({
    required this.mandatory,
    required this.optional,
    required this.savings,
    required this.income,
  });

  factory BudgetPlan.create({
    required int mandatory,
    required int optional,
    required int savings,
    required int income,
  }) {
    for (final (name, v) in [
      ('mandatory', mandatory),
      ('optional', optional),
      ('savings', savings),
      ('income', income),
    ]) {
      if (v < 0) {
        throw ArgumentError.value(v, name, 'Суммы — целые числа ≥ 0');
      }
    }
    final plan = BudgetPlan._(
      mandatory: mandatory,
      optional: optional,
      savings: savings,
      income: income,
    );
    if (!plan.isValid) {
      throw ArgumentError(
          'разложено ${plan.distributed} при доходе $income');
    }
    return plan;
  }

  factory BudgetPlan.empty(int income) =>
      BudgetPlan.create(mandatory: 0, optional: 0, savings: 0, income: income);

  final int mandatory;
  final int optional;
  final int savings;
  final int income;

  int get distributed => mandatory + optional + savings;
  int get remainder => income - distributed;
  bool get isValid => distributed <= income;

  BudgetPlan copyWith({int? mandatory, int? optional, int? savings}) =>
      BudgetPlan.create(
        mandatory: mandatory ?? this.mandatory,
        optional: optional ?? this.optional,
        savings: savings ?? this.savings,
        income: income,
      );

  Map<String, Object?> toJson() => {
        'mandatory': mandatory,
        'optional': optional,
        'savings': savings,
        'income': income,
      };

  factory BudgetPlan.fromJson(Map<String, Object?> json) => BudgetPlan.create(
        mandatory: json['mandatory'] as int,
        optional: json['optional'] as int,
        savings: json['savings'] as int,
        income: json['income'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is BudgetPlan &&
      other.mandatory == mandatory &&
      other.optional == optional &&
      other.savings == savings &&
      other.income == income;

  @override
  int get hashCode => Object.hash(mandatory, optional, savings, income);
}
