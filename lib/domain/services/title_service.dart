import '../models/models.dart';
import '../ru_words.dart';
import '../text_template.dart';

final class ThemeTasks {
  ThemeTasks({required this.title, required Iterable<String> taskIds})
      : taskIds = Set.unmodifiable(taskIds);

  final String title;
  final Set<String> taskIds;
}

final class TitleFacts {
  const TitleFacts._({
    required this.dayNumber,
    required this.completedTaskIds,
    required this.reachedGoalIds,
    required this.savings,
  });

  factory TitleFacts.create({
    required int dayNumber,
    Iterable<String> completedTaskIds = const [],
    Iterable<String> reachedGoalIds = const [],
    int savings = 0,
  }) {
    if (dayNumber < 1) {
      throw ArgumentError.value(dayNumber, 'dayNumber', 'Дни нумеруются с 1');
    }
    if (savings < 0) throw ArgumentError.value(savings, 'savings', '≥ 0');
    return TitleFacts._(
      dayNumber: dayNumber,
      completedTaskIds: Set.unmodifiable(completedTaskIds),
      reachedGoalIds: Set.unmodifiable(reachedGoalIds),
      savings: savings,
    );
  }

  factory TitleFacts.of(Profile profile) => TitleFacts.create(
        dayNumber: profile.currentDay.number,
        completedTaskIds: profile.completedTasks,
        reachedGoalIds: profile.reachedGoalIds,
        savings: profile.wallet.savings,
      );

  final int dayNumber;
  final Set<String> completedTaskIds;
  final Set<String> reachedGoalIds;
  final int savings;
}

final class EarnedTitle {
  const EarnedTitle({
    required this.title,
    required this.headline,
    required this.reason,
  });

  final TitleDef title;
  final String headline;
  final String reason;
}

final class TitleAward {
  const TitleAward({required this.progress, required this.earned});

  final PetProgress progress;
  final List<EarnedTitle> earned;
}

final class TitleService {
  TitleService(
    this.catalog, {
    required Map<String, ThemeTasks> themes,
    required this.dailyNeedsCost,
  }) : _themes = Map.unmodifiable(themes) {
    if (dailyNeedsCost < 0) {
      throw ArgumentError.value(dailyNeedsCost, 'dailyNeedsCost', '≥ 0');
    }
  }

  factory TitleService.forContent(
    TitleCatalog catalog, {
    required TaskCatalog tasks,
    required ShopCatalog shop,
  }) =>
      TitleService(
        catalog,
        themes: {
          for (final theme in tasks.themes)
            theme.id: ThemeTasks(
              title: theme.title,
              taskIds: [for (final task in tasks.byTheme(theme.id)) task.id],
            )
        },
        dailyNeedsCost: shop.mandatoryCost,
      );

  final TitleCatalog catalog;
  final int dailyNeedsCost;
  final Map<String, ThemeTasks> _themes;

  List<String> get problems => List.unmodifiable([
        for (final title in catalog.titles)
          if (_unreachable(title.condition) case final reason?)
            '«${title.id}»: $reason'
      ]);

  PetProgress start(PetProgress progress) => _grant(progress, [
        for (final title in catalog.titles)
          if (title.condition is StartCondition &&
              !progress.earnedTitles.contains(title.id))
            title
      ]);

  TitleAward award(PetProgress progress, TitleFacts facts) {
    final days = progress.growthDays;
    if (days.isEmpty || days.last.dayNumber != facts.dayNumber) {
      throw ArgumentError.value(facts.dayNumber, 'facts.dayNumber',
          'звания проверяются сразу после закрытия этого дня');
    }
    final owned = progress.earnedTitles.toSet();
    final fresh = [
      for (final title in catalog.titles)
        if (!owned.contains(title.id) && _met(title.condition, days, facts))
          title
    ];
    return TitleAward(
      progress: _grant(progress, fresh),
      earned: List.unmodifiable([
        for (final title in fresh)
          if (title.condition is! StartCondition)
            EarnedTitle(
              title: title,
              headline: headlineOf(title),
              reason: reasonOf(title),
            )
      ]),
    );
  }

  TitleDef? current(PetProgress progress) {
    final chosen = catalog.byId(progress.currentTitleId);
    if (chosen != null && progress.earnedTitles.contains(chosen.id)) {
      return chosen;
    }
    final shelf = this.shelf(progress);
    return shelf.isEmpty ? null : shelf.last;
  }

  List<TitleDef> shelf(PetProgress progress) => List.unmodifiable([
        for (final id in progress.earnedTitles.toSet())
          if (catalog.byId(id) case final title?) title
      ]);

  PetProgress choose(PetProgress progress, String titleId) {
    if (catalog.byId(titleId) == null ||
        !progress.earnedTitles.contains(titleId)) {
      throw ArgumentError.value(titleId, 'titleId', 'звание ещё не получено');
    }
    return progress.currentTitleId == titleId
        ? progress
        : progress.copyWith(currentTitleId: titleId);
  }

  String headlineOf(TitleDef title) =>
      fillTemplate(catalog.texts.earned, {'title': title.title});

  String reasonOf(TitleDef title) {
    final condition = title.condition;
    return fillPlurals(fillTemplate(title.description, {
      ...condition.values,
      if (condition is ThemeCondition)
        'theme': _themes[condition.themeId]?.title ?? condition.themeId,
    }));
  }

  PetProgress _grant(PetProgress progress, List<TitleDef> fresh) {
    final earned = [...progress.earnedTitles, for (final t in fresh) t.id];
    final ceremonial = [
      for (final t in fresh)
        if (t.condition is! StartCondition) t
    ];
    final updated =
        fresh.isEmpty ? progress : progress.copyWith(earnedTitles: earned);
    final currentId = ceremonial.isNotEmpty
        ? ceremonial.last.id
        : current(updated)?.id ?? progress.currentTitleId;
    return currentId == updated.currentTitleId
        ? updated
        : updated.copyWith(currentTitleId: currentId);
  }

  bool _met(TitleCondition condition, List<GrowthDay> days, TitleFacts facts) =>
      switch (condition) {
        StartCondition() => true,
        DaysCondition rule => (rule.inARow
                ? _longestRun(days, rule)
                : days.where((day) => _marked(day.facts, rule)).length) >=
            rule.count,
        ThemeCondition(:final themeId) => switch (_themes[themeId]) {
            final theme? => theme.taskIds.isNotEmpty &&
                facts.completedTaskIds.containsAll(theme.taskIds),
            null => false,
          },
        GoalsCondition(:final count) => facts.reachedGoalIds.length >= count,
        ReserveCondition(days: final reserveDays) => dailyNeedsCost > 0 &&
            days.last.facts.mandatoryPaid &&
            facts.savings >= reserveDays * dailyNeedsCost,
      };

  int _longestRun(List<GrowthDay> days, DaysCondition condition) {
    var best = 0;
    var run = 0;
    int? previous;
    for (final day in days) {
      if (!_marked(day.facts, condition)) {
        run = 0;
      } else if (previous != null && day.dayNumber == previous + 1) {
        run++;
      } else {
        run = 1;
      }
      previous = day.dayNumber;
      if (run > best) best = run;
    }
    return best;
  }

  bool _marked(DayFacts facts, DaysCondition condition) =>
      condition.marks.every((mark) => switch (mark) {
            DayMark.active => facts.active,
            DayMark.planMade => facts.planMade,
            DayMark.mandatoryPaid => facts.mandatoryPaid,
            DayMark.onPlan => facts.followsPlan(condition.planTolerance!),
            DayMark.saved => facts.deposited > 0,
            DayMark.savedAsPlanned => facts.savedAsPlanned,
            DayMark.taskDone => facts.tasksDone > 0,
          });

  String? _unreachable(TitleCondition condition) => switch (condition) {
        ThemeCondition(:final themeId) => switch (_themes[themeId]) {
            null => 'нет темы «$themeId»',
            ThemeTasks(:final taskIds) when taskIds.isEmpty =>
              'в теме «$themeId» нет заданий',
            _ => null,
          },
        ReserveCondition() when dailyNeedsCost == 0 =>
          'не задана стоимость нужного на день',
        _ => null,
      };
}
