import 'package:finni/domain/models/models.dart';

Map<String, Object?> growthRulesJson() => {
      'points': {
        'mandatoryPaid': 2,
        'followedPlan': 2,
        'savedAsPlanned': 2,
        'taskDone': 1,
      },
      'planTolerance': {'percent': 20, 'atLeast': 5},
      'stages': {'baby': 4, 'teen': 14, 'adult': 32},
      'texts': {
        'stageLabels': {
          'egg': 'Яйцо',
          'baby': 'Малыш',
          'teen': 'Подросток',
          'adult': 'Взрослый',
        },
        'factors': {
          'mandatoryPaid': {
            'met': 'Всё нужное куплено: +{points} к росту',
            'missed': 'Купим всё нужное — будет +{points} к росту',
            'action': 'покупали всё нужное',
          },
          'followedPlan': {
            'met': 'Потратили по плану: +{points} к росту',
            'missed': 'Потратим по плану — будет +{points} к росту',
            'action': 'тратили по плану',
          },
          'savedAsPlanned': {
            'met': 'Отложили по плану: +{points} к росту',
            'missed': 'Отложим в копилку по плану — будет +{points} к росту',
            'action': 'откладывали в копилку',
          },
          'taskDone': {
            'met': 'Задание сделано: +{points} к росту',
            'missed': 'Задание добавит +{points} к росту',
            'action': 'решали задания',
          },
        },
        'stageUp': '{name} подрастает: теперь «{stage}»!',
        'reasonOneDay': 'Сегодня мы {actions}.',
        'reasonDays': 'За {days} {day}: {actions}.',
        'reasonFallback': 'Мы многому научились вместе.',
      },
    };

BudgetPlan dayPlan({
  int mandatory = 25,
  int optional = 10,
  int savings = 20,
  int income = 60,
}) =>
    BudgetPlan.create(
      mandatory: mandatory,
      optional: optional,
      savings: savings,
      income: income,
    );

DayFacts dayFacts(
  int day, {
  BudgetPlan? plan,
  bool confirmed = true,
  int spentMandatory = 25,
  int spentOptional = 10,
  int deposited = 20,
  bool paid = true,
  int tasks = 1,
}) =>
    DayFacts.create(
      dayNumber: day,
      plan: plan ?? dayPlan(),
      planConfirmed: confirmed,
      spentMandatory: spentMandatory,
      spentOptional: spentOptional,
      deposited: deposited,
      mandatoryPaid: paid,
      tasksDone: tasks,
    );

DayFacts idleDay(int day) => dayFacts(
      day,
      plan: BudgetPlan.empty(60),
      confirmed: false,
      spentMandatory: 0,
      spentOptional: 0,
      deposited: 0,
      paid: false,
      tasks: 0,
    );
