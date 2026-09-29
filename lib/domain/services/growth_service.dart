import '../models/models.dart';
import '../ru_words.dart';
import '../text_template.dart';

final class StageUp {
  const StageUp({
    required this.from,
    required this.to,
    required this.stageLabel,
    required this.reasonText,
    required this.days,
  });

  final PetStage from;
  final PetStage to;
  final String stageLabel;
  final String reasonText;
  final int days;
}

final class GrowthOutcome {
  const GrowthOutcome({
    required this.progress,
    required this.day,
    required this.stageUp,
    required this.counted,
  });

  final PetProgress progress;
  final GrowthDay day;
  final StageUp? stageUp;
  final bool counted;
}

final class GrowthLine {
  const GrowthLine({
    required this.factor,
    required this.met,
    required this.points,
    required this.text,
  });

  final GrowthFactor factor;
  final bool met;
  final int points;
  final String text;
}

final class GrowthStatus {
  const GrowthStatus({
    required this.stage,
    required this.stageLabel,
    required this.points,
    required this.next,
    required this.nextLabel,
    required this.pointsToNext,
  });

  final PetStage stage;
  final String stageLabel;
  final int points;
  final PetStage? next;
  final String? nextLabel;
  final int? pointsToNext;
}

final class GrowthService {
  const GrowthService(this.rules);

  final GrowthRules rules;

  Set<GrowthFactor> factorsOf(DayFacts facts) => {
        if (facts.mandatoryPaid) GrowthFactor.mandatoryPaid,
        if (facts.followsPlan(rules.planTolerance)) GrowthFactor.followedPlan,
        if (facts.savedAsPlanned) GrowthFactor.savedAsPlanned,
        if (facts.tasksDone > 0) GrowthFactor.taskDone,
      };

  int pointsFor(Set<GrowthFactor> factors) =>
      factors.fold(0, (sum, factor) => sum + rules.points[factor]!);

  /// [hungry] — питомец лёг спать голодным: день записан, но очков нет.
  GrowthOutcome closeDay(PetProgress progress, DayFacts facts,
      {bool hungry = false}) {
    for (final day in progress.growthDays) {
      if (day.dayNumber == facts.dayNumber) {
        return GrowthOutcome(
            progress: progress, day: day, stageUp: null, counted: false);
      }
    }
    final days = progress.growthDays;
    if (days.isNotEmpty && facts.dayNumber < days.last.dayNumber) {
      throw ArgumentError.value(facts.dayNumber, 'dayNumber',
          'дни не идут назад, последний ${days.last.dayNumber}');
    }

    final factors = factorsOf(facts);
    final points = hungry ? 0 : pointsFor(factors);
    final total = progress.growthPoints + points;
    final reached = rules.stageFor(total);
    final stage =
        reached.index > progress.stage.index ? reached : progress.stage;
    final day = GrowthDay.create(
      facts: facts,
      factors: factors,
      points: points,
      stageBefore: progress.stage,
      stageAfter: stage,
    );
    final next = progress.copyWith(
      growthPoints: total,
      stage: stage,
      growthDays: [...days, day],
    );
    return GrowthOutcome(
      progress: next,
      day: day,
      stageUp: stage == progress.stage ? null : _stageUp(next, progress.stage),
      counted: true,
    );
  }

  List<GrowthLine> lines(GrowthDay day) => [
        for (final factor in GrowthFactor.values)
          _line(factor, day.factors.contains(factor)),
      ];

  GrowthStatus status(PetProgress progress) {
    final stage = progress.stage;
    final hasNext = stage.index + 1 < PetStage.values.length;
    final next = hasNext ? PetStage.values[stage.index + 1] : null;
    final left =
        next == null ? null : rules.thresholds[next]! - progress.growthPoints;
    return GrowthStatus(
      stage: stage,
      stageLabel: rules.texts.stageLabels[stage]!,
      points: progress.growthPoints,
      next: next,
      nextLabel: next == null ? null : rules.texts.stageLabels[next],
      pointsToNext: left == null ? null : (left < 0 ? 0 : left),
    );
  }

  String stageUpTitle(StageUp stageUp, {required String petName}) =>
      fillTemplate(
          rules.texts.stageUp, {'name': petName, 'stage': stageUp.stageLabel});

  GrowthLine _line(GrowthFactor factor, bool met) {
    final points = rules.points[factor]!;
    final texts = rules.texts.factors[factor]!;
    return GrowthLine(
      factor: factor,
      met: met,
      points: points,
      text: fillTemplate(met ? texts.met : texts.missed, {'points': '$points'}),
    );
  }

  StageUp _stageUp(PetProgress progress, PetStage from) {
    final window = <GrowthDay>[];
    for (final day in progress.growthDays.reversed) {
      if (day.stageBefore != from) break;
      window.add(day);
    }
    final counts = {
      for (final factor in GrowthFactor.values)
        factor: window.where((day) => day.factors.contains(factor)).length
    };
    var chosen = [
      for (final factor in GrowthFactor.values)
        if (counts[factor]! > 0 && counts[factor]! * 2 >= window.length) factor
    ];
    if (chosen.isEmpty) {
      final best = counts.values.fold(0, (a, b) => a > b ? a : b);
      chosen = [
        for (final factor in GrowthFactor.values)
          if (best > 0 && counts[factor] == best) factor
      ];
    }
    chosen.sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      if (byCount != 0) return byCount;
      return _reasonPriority.indexOf(a).compareTo(_reasonPriority.indexOf(b));
    });
    final named = chosen.take(_reasonActions).toSet();
    final texts = rules.texts;
    final actions = _joinActions([
      for (final factor in GrowthFactor.values)
        if (named.contains(factor)) texts.factors[factor]!.action
    ]);
    final String reason;
    if (chosen.isEmpty) {
      reason = texts.reasonFallback;
    } else if (window.length == 1) {
      reason = fillTemplate(texts.reasonOneDay, {'actions': actions});
    } else {
      reason = fillPlurals(fillTemplate(
          texts.reasonDays, {'days': '${window.length}', 'actions': actions}));
    }
    return StageUp(
      from: from,
      to: progress.stage,
      stageLabel: texts.stageLabels[progress.stage]!,
      reasonText: reason,
      days: window.length,
    );
  }

  static const _reasonActions = 2;

  static const _reasonPriority = [
    GrowthFactor.savedAsPlanned,
    GrowthFactor.followedPlan,
    GrowthFactor.mandatoryPaid,
    GrowthFactor.taskDone,
  ];

  static String _joinActions(List<String> actions) {
    if (actions.length < 2) return actions.join();
    return '${actions.sublist(0, actions.length - 1).join(', ')} и '
        '${actions.last}';
  }
}
