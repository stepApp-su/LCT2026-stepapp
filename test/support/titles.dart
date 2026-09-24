import 'package:finni/domain/models/models.dart';
import 'package:finni/domain/services/title_service.dart';

import 'growth.dart';

const payTasks = ['pay_sort', 'pay_change'];

Map<String, Object?> titleJson(
  String id,
  Map<String, Object?> condition, {
  String? description,
  String? attributeId,
}) =>
    {
      'id': id,
      'title': 'Звание $id',
      'description': description ?? 'Описание $id.',
      'iconId': 'icon_title_$id',
      'competenceId': 'budget_make',
      if (attributeId != null) 'attributeId': attributeId,
      'condition': condition,
    };

List<Map<String, Object?>> standardTitles() => [
      titleJson('novice', {'type': 'start'},
          description: 'Начали учиться обращаться с деньгами.'),
      titleJson(
          'planner',
          {
            'type': 'days',
            'count': 3,
            'marks': ['planMade'],
          },
          description: '{count} {day} составляли план на день.'),
      titleJson(
          'saver',
          {
            'type': 'streak',
            'count': 5,
            'marks': ['saved'],
          },
          description: '{count} {day} подряд откладывали в копилку.'),
      titleJson('shopping_expert', {'type': 'theme', 'themeId': 'payments'},
          description: 'Прошли все задания темы «{theme}».'),
      titleJson('reserve_keeper', {'type': 'reserve', 'count': 2},
          description: 'Отложили запас на {count} {day} вперёд.'),
      titleJson('dreamer', {'type': 'goals', 'count': 1}),
      titleJson(
          'budget_master',
          {
            'type': 'days',
            'count': 10,
            'marks': ['mandatoryPaid', 'onPlan'],
            'planTolerance': {'percent': 10, 'atLeast': 0, 'roundUp': false},
          },
          description:
              '{count} {day} покупали нужное и держались своего плана.'),
      titleJson('mentor', {
        'type': 'days',
        'count': 30,
        'marks': ['active'],
      }),
    ];

Map<String, Object?> titlesJson([List<Object?>? titles]) => {
      'schemaVersion': 1,
      'texts': {'earned': 'Новое звание: «{title}»!'},
      'titles': titles ?? standardTitles(),
    };

TitleService titleService({
  List<Object?>? titles,
  int dailyNeedsCost = 25,
}) =>
    TitleService(
      TitleCatalog.fromJson(titlesJson(titles)),
      themes: {
        'payments': ThemeTasks(title: 'Платежи и покупки', taskIds: payTasks),
        'empty': ThemeTasks(title: 'Пустая тема', taskIds: const []),
      },
      dailyNeedsCost: dailyNeedsCost,
    );

DayFacts planOnly(int day) => dayFacts(day,
    spentMandatory: 0, spentOptional: 0, deposited: 0, paid: false, tasks: 0);

DayFacts savedOnly(int day, {int amount = 10}) => dayFacts(day,
    plan: BudgetPlan.empty(60),
    confirmed: false,
    spentMandatory: 0,
    spentOptional: 0,
    deposited: amount,
    paid: false,
    tasks: 0);

DayFacts exactDay(int day, {bool paid = true}) => dayFacts(day,
    plan: dayPlan(mandatory: 25, optional: 5, savings: 30),
    spentMandatory: 25,
    spentOptional: 5,
    deposited: 30,
    paid: paid,
    tasks: 0);
