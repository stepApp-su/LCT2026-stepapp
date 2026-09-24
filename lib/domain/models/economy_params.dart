import 'content_json.dart';

final class DayRules {
  const DayRules._({
    required this.income,
    required this.incomeReason,
    required this.tasksPerDay,
  });

  factory DayRules.fromJson(Map<String, Object?> json) => DayRules._(
        income: jsonInt(json['income'], 'day.income', min: 1),
        incomeReason: jsonText(json['incomeReason'], 'day.incomeReason'),
        tasksPerDay: jsonInt(json['tasksPerDay'], 'day.tasksPerDay', min: 1),
      );

  final int income;
  final String incomeReason;
  final int tasksPerDay;
}

final class PlanDirectionInfo {
  const PlanDirectionInfo._({
    required this.id,
    required this.label,
    required this.hint,
    required this.iconId,
  });

  factory PlanDirectionInfo.fromJson(String id, Map<String, Object?> json) =>
      PlanDirectionInfo._(
        id: id,
        label: jsonText(json['label'], 'plan.directions.$id.label'),
        hint: jsonText(json['hint'], 'plan.directions.$id.hint'),
        iconId: jsonText(json['iconId'], 'plan.directions.$id.iconId'),
      );

  final String id;
  final String label;
  final String hint;
  final String iconId;
}

final class PlanRules {
  const PlanRules._({
    required this.step,
    required this.directions,
    required this.texts,
  });

  static const Set<String> requiredDirections = {
    'mandatory',
    'optional',
    'savings',
  };

  static const Set<String> requiredTexts = {
    'available',
    'remainder',
    'allDistributed',
    'mandatoryHint',
    'confirm',
  };

  factory PlanRules.fromJson(Map<String, Object?> json) {
    final raw = jsonMap(json['directions'], 'plan.directions');
    final directions = {
      for (final entry in raw.entries)
        entry.key: PlanDirectionInfo.fromJson(
            entry.key, jsonMap(entry.value, 'plan.directions.${entry.key}')),
    };
    for (final id in requiredDirections) {
      if (!directions.containsKey(id)) {
        throw ArgumentError.value(id, 'plan.directions', 'нет направления');
      }
    }
    return PlanRules._(
      step: jsonInt(json['step'], 'plan.step', min: 1),
      directions: Map.unmodifiable(directions),
      texts: jsonTexts(json['texts'], 'plan.texts', required: requiredTexts),
    );
  }

  final int step;
  final Map<String, PlanDirectionInfo> directions;
  final Map<String, String> texts;
}

final class TaskRewardRules {
  const TaskRewardRules._({
    required this.repeatReward,
    required this.reasonTemplate,
  });

  factory TaskRewardRules.fromJson(Map<String, Object?> json) {
    final template = jsonText(json['reasonTemplate'], 'tasks.reasonTemplate');
    if (!template.contains('{taskTitle}')) {
      throw ArgumentError.value(
          template, 'tasks.reasonTemplate', 'нужно название задания {taskTitle}');
    }
    return TaskRewardRules._(
      repeatReward: jsonInt(json['repeatReward'], 'tasks.repeatReward', min: 1),
      reasonTemplate: template,
    );
  }

  final int repeatReward;
  final String reasonTemplate;
}

final class EventSchedule {
  const EventSchedule._({required this.firstDay, required this.intervalPattern});

  factory EventSchedule.fromJson(Map<String, Object?> json) {
    final pattern = jsonInts(json['intervalPattern'], 'events.intervalPattern', min: 1);
    if (pattern.isEmpty) {
      throw ArgumentError.value(pattern, 'events.intervalPattern', 'пустой шаблон');
    }
    return EventSchedule._(
      firstDay: jsonInt(json['firstDay'], 'events.firstDay', min: 1),
      intervalPattern: pattern,
    );
  }

  final int firstDay;
  final List<int> intervalPattern;

  bool isEventDay(int day) {
    var eventDay = firstDay;
    var index = 0;
    while (eventDay < day) {
      eventDay += intervalPattern[index % intervalPattern.length];
      index++;
    }
    return eventDay == day;
  }

  List<int> eventDaysUpTo(int lastDay) => List.unmodifiable([
        for (var day = 1; day <= lastDay; day++)
          if (isEventDay(day)) day,
      ]);
}

final class CozyLevel {
  const CozyLevel({
    required this.level,
    required this.title,
    required this.minCozy,
  });

  final int level;
  final String title;
  final int minCozy;
}

final class CozyLevels {
  const CozyLevels._({
    required this.levels,
    required this.stepAfterLast,
    required this.titleTemplateAfterLast,
    required this.texts,
  });

  factory CozyLevels.fromJson(Map<String, Object?> json) {
    final levels = [
      for (final raw in jsonMaps(json['levels'], 'cozyLevels.levels'))
        CozyLevel(
          level: jsonInt(raw['level'], 'cozyLevels.levels[].level', min: 1),
          title: jsonText(raw['title'], 'cozyLevels.levels[].title'),
          minCozy: jsonInt(raw['minCozy'], 'cozyLevels.levels[].minCozy', min: 0),
        ),
    ];
    if (levels.isEmpty) {
      throw ArgumentError.value(levels, 'cozyLevels.levels', 'нет уровней');
    }
    if (levels.first.minCozy != 0) {
      throw ArgumentError.value(
          levels.first.minCozy, 'cozyLevels.levels', 'первый уровень с нуля');
    }
    for (var i = 0; i < levels.length; i++) {
      if (levels[i].level != i + 1) {
        throw ArgumentError.value(
            levels[i].level, 'cozyLevels.levels', 'уровни идут подряд с единицы');
      }
      if (i > 0 && levels[i].minCozy <= levels[i - 1].minCozy) {
        throw ArgumentError.value(
            levels[i].minCozy, 'cozyLevels.levels', 'порог должен расти');
      }
    }
    final afterLast = jsonMap(json['afterLast'], 'cozyLevels.afterLast');
    final template =
        jsonText(afterLast['titleTemplate'], 'cozyLevels.afterLast.titleTemplate');
    if (!template.contains('{stars}')) {
      throw ArgumentError.value(
          template, 'cozyLevels.afterLast.titleTemplate', 'нужен {stars}');
    }
    return CozyLevels._(
      levels: List.unmodifiable(levels),
      stepAfterLast:
          jsonInt(afterLast['stepCozy'], 'cozyLevels.afterLast.stepCozy', min: 1),
      titleTemplateAfterLast: template,
      texts: jsonTexts(json['texts'], 'cozyLevels.texts',
          required: const {'badge', 'toNext', 'levelUp'}),
    );
  }

  final List<CozyLevel> levels;
  final int stepAfterLast;
  final String titleTemplateAfterLast;
  final Map<String, String> texts;

  CozyLevel levelFor(int cozy) {
    final last = levels.last;
    if (cozy >= last.minCozy) {
      final stars = (cozy - last.minCozy) ~/ stepAfterLast;
      if (stars == 0) return last;
      return CozyLevel(
        level: last.level + stars,
        title: titleTemplateAfterLast.replaceAll('{stars}', '$stars'),
        minCozy: last.minCozy + stars * stepAfterLast,
      );
    }
    var current = levels.first;
    for (final level in levels) {
      if (cozy >= level.minCozy) current = level;
    }
    return current;
  }
}

final class EconomyParams {
  const EconomyParams._({
    required this.day,
    required this.plan,
    required this.tasks,
    required this.events,
    required this.cooldownsMinutes,
    required this.cozyLevels,
  });

  factory EconomyParams.fromJson(Map<String, Object?> json) {
    final cooldowns = jsonMap(json['cooldownsMinutes'], 'cooldownsMinutes');
    return EconomyParams._(
      day: DayRules.fromJson(jsonMap(json['day'], 'day')),
      plan: PlanRules.fromJson(jsonMap(json['plan'], 'plan')),
      tasks: TaskRewardRules.fromJson(jsonMap(json['tasks'], 'tasks')),
      events: EventSchedule.fromJson(jsonMap(json['events'], 'events')),
      cooldownsMinutes: Map.unmodifiable({
        for (final entry in cooldowns.entries)
          entry.key: jsonInt(entry.value, 'cooldownsMinutes.${entry.key}', min: 0),
      }),
      cozyLevels: CozyLevels.fromJson(jsonMap(json['cozyLevels'], 'cozyLevels')),
    );
  }

  final DayRules day;
  final PlanRules plan;
  final TaskRewardRules tasks;
  final EventSchedule events;
  final Map<String, int> cooldownsMinutes;
  final CozyLevels cozyLevels;
}
