import 'budget_plan.dart';
import 'economy.dart';
import 'pet.dart';
import 'transaction.dart';

enum GrowthFactor { mandatoryPaid, followedPlan, savedAsPlanned, taskDone }

final class PlanTolerance {
  const PlanTolerance._({
    required this.percent,
    required this.atLeast,
    required this.roundUp,
  });

  factory PlanTolerance.create({
    required int percent,
    required int atLeast,
    bool roundUp = true,
  }) {
    if (percent < 0 || percent > 100) {
      throw ArgumentError.value(percent, 'planTolerance.percent', '0..100');
    }
    if (atLeast < 0) {
      throw ArgumentError.value(atLeast, 'planTolerance.atLeast', '≥ 0');
    }
    return PlanTolerance._(
        percent: percent, atLeast: atLeast, roundUp: roundUp);
  }

  factory PlanTolerance.fromJson(Map<String, Object?> json) =>
      PlanTolerance.create(
        percent: json['percent'] as int,
        atLeast: json['atLeast'] as int,
        roundUp: (json['roundUp'] ?? true) as bool,
      );

  final int percent;
  final int atLeast;
  final bool roundUp;

  int allowedFor(int planned) {
    final byPercent = (planned * percent + (roundUp ? 99 : 0)) ~/ 100;
    return byPercent > atLeast ? byPercent : atLeast;
  }

  bool within(int planned, int actual) =>
      (actual - planned).abs() <= allowedFor(planned);

  Map<String, Object?> toJson() => {
        'percent': percent,
        'atLeast': atLeast,
        if (!roundUp) 'roundUp': false,
      };

  @override
  bool operator ==(Object other) =>
      other is PlanTolerance &&
      other.percent == percent &&
      other.atLeast == atLeast &&
      other.roundUp == roundUp;

  @override
  int get hashCode => Object.hash(percent, atLeast, roundUp);
}

final class DayFacts {
  const DayFacts._({
    required this.dayNumber,
    required this.plan,
    required this.planConfirmed,
    required this.spentMandatory,
    required this.spentOptional,
    required this.deposited,
    required this.mandatoryPaid,
    required this.tasksDone,
  });

  factory DayFacts.create({
    required int dayNumber,
    required BudgetPlan plan,
    required bool planConfirmed,
    int spentMandatory = 0,
    int spentOptional = 0,
    int deposited = 0,
    required bool mandatoryPaid,
    int tasksDone = 0,
  }) {
    if (dayNumber < 1) {
      throw ArgumentError.value(dayNumber, 'dayNumber', 'Дни нумеруются с 1');
    }
    for (final (name, value) in [
      ('spentMandatory', spentMandatory),
      ('spentOptional', spentOptional),
      ('deposited', deposited),
      ('tasksDone', tasksDone),
    ]) {
      if (value < 0) throw ArgumentError.value(value, name, '≥ 0');
    }
    return DayFacts._(
      dayNumber: dayNumber,
      plan: plan,
      planConfirmed: planConfirmed,
      spentMandatory: spentMandatory,
      spentOptional: spentOptional,
      deposited: deposited,
      mandatoryPaid: mandatoryPaid,
      tasksDone: tasksDone,
    );
  }

  factory DayFacts.fromDay(
    GameDay day, {
    required Iterable<String> mandatoryItemIds,
    Iterable<Iterable<String>> mandatoryOptions = const [],
  }) {
    var spentMandatory = 0;
    var spentOptional = 0;
    var deposited = 0;
    var withdrawn = 0;
    final bought = <String>{};
    final tasks = <String>{};
    for (final t in day.transactions) {
      if (t.dayNumber != day.number) continue;
      if (t.sourceId.startsWith(_goalSource)) continue;
      switch (t.type) {
        case TransactionType.expense:
          if (t.category == ExpenseCategory.mandatory) {
            spentMandatory += t.amount;
          } else {
            spentOptional += t.amount;
          }
          if (t.sourceId.startsWith(_shopSource)) {
            bought.add(t.sourceId.substring(_shopSource.length));
          }
        case TransactionType.toSavings:
          deposited += t.amount;
        case TransactionType.income:
          if (t.sourceId.startsWith(_taskSource)) tasks.add(t.sourceId);
        case TransactionType.fromSavings:
          withdrawn += t.amount;
      }
    }
    return DayFacts.create(
      dayNumber: day.number,
      plan: day.plan,
      planConfirmed: day.planConfirmed,
      spentMandatory: spentMandatory,
      spentOptional: spentOptional,
      deposited: deposited > withdrawn ? deposited - withdrawn : 0,
      mandatoryPaid: mandatoryItemIds.every(bought.contains) &&
          mandatoryOptions.every((options) => options.any(bought.contains)),
      tasksDone: tasks.length,
    );
  }

  static const _shopSource = 'shop:';
  static const _taskSource = 'task:';
  static const _goalSource = 'goal:';

  final int dayNumber;
  final BudgetPlan plan;
  final bool planConfirmed;
  final int spentMandatory;
  final int spentOptional;
  final int deposited;
  final bool mandatoryPaid;
  final int tasksDone;

  bool get planMade => planConfirmed && plan.distributed > 0;

  bool get active => planMade || _moneyMoved || tasksDone > 0;

  bool get savedAsPlanned =>
      planConfirmed && plan.savings > 0 && deposited >= plan.savings;

  bool followsPlan(PlanTolerance tolerance) =>
      planMade &&
      _moneyMoved &&
      tolerance.within(plan.mandatory, spentMandatory) &&
      tolerance.within(plan.optional, spentOptional) &&
      (deposited >= plan.savings || tolerance.within(plan.savings, deposited));

  bool get _moneyMoved => spentMandatory + spentOptional + deposited > 0;

  Map<String, Object?> toJson() => {
        'dayNumber': dayNumber,
        'plan': plan.toJson(),
        'planConfirmed': planConfirmed,
        'spentMandatory': spentMandatory,
        'spentOptional': spentOptional,
        'deposited': deposited,
        'mandatoryPaid': mandatoryPaid,
        'tasksDone': tasksDone,
      };

  factory DayFacts.fromJson(Map<String, Object?> json) => DayFacts.create(
        dayNumber: json['dayNumber'] as int,
        plan:
            BudgetPlan.fromJson((json['plan'] as Map).cast<String, Object?>()),
        planConfirmed: json['planConfirmed'] as bool,
        spentMandatory: json['spentMandatory'] as int,
        spentOptional: json['spentOptional'] as int,
        deposited: json['deposited'] as int,
        mandatoryPaid: json['mandatoryPaid'] as bool,
        tasksDone: json['tasksDone'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is DayFacts &&
      other.dayNumber == dayNumber &&
      other.plan == plan &&
      other.planConfirmed == planConfirmed &&
      other.spentMandatory == spentMandatory &&
      other.spentOptional == spentOptional &&
      other.deposited == deposited &&
      other.mandatoryPaid == mandatoryPaid &&
      other.tasksDone == tasksDone;

  @override
  int get hashCode => Object.hash(dayNumber, plan, planConfirmed,
      spentMandatory, spentOptional, deposited, mandatoryPaid, tasksDone);
}

final class GrowthDay {
  const GrowthDay._({
    required this.facts,
    required this.factors,
    required this.points,
    required this.stageBefore,
    required this.stageAfter,
  });

  factory GrowthDay.create({
    required DayFacts facts,
    required Set<GrowthFactor> factors,
    required int points,
    required PetStage stageBefore,
    required PetStage stageAfter,
  }) {
    if (points < 0) throw ArgumentError.value(points, 'points', '≥ 0');
    if (stageAfter.index < stageBefore.index) {
      throw ArgumentError('стадия не понижается: $stageBefore → $stageAfter');
    }
    return GrowthDay._(
      facts: facts,
      factors: Set.unmodifiable(factors),
      points: points,
      stageBefore: stageBefore,
      stageAfter: stageAfter,
    );
  }

  final DayFacts facts;
  final Set<GrowthFactor> factors;
  final int points;
  final PetStage stageBefore;
  final PetStage stageAfter;

  int get dayNumber => facts.dayNumber;

  Map<String, Object?> toJson() => {
        'facts': facts.toJson(),
        'factors': [
          for (final f in GrowthFactor.values)
            if (factors.contains(f)) f.name
        ],
        'points': points,
        'stageBefore': stageBefore.name,
        'stageAfter': stageAfter.name,
      };

  factory GrowthDay.fromJson(Map<String, Object?> json) => GrowthDay.create(
        facts:
            DayFacts.fromJson((json['facts'] as Map).cast<String, Object?>()),
        factors: {
          for (final f in json['factors'] as List)
            GrowthFactor.values.byName(f as String)
        },
        points: json['points'] as int,
        stageBefore: PetStage.values.byName(json['stageBefore'] as String),
        stageAfter: PetStage.values.byName(json['stageAfter'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is GrowthDay &&
      other.facts == facts &&
      other.points == points &&
      other.stageBefore == stageBefore &&
      other.stageAfter == stageAfter &&
      other.factors.length == factors.length &&
      other.factors.containsAll(factors);

  @override
  int get hashCode => Object.hash(
      facts, points, stageBefore, stageAfter, Object.hashAllUnordered(factors));
}
