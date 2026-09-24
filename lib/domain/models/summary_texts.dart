import 'content_json.dart';
import 'growth.dart';

final class ConditionalText {
  const ConditionalText._({required this.id, required this.condition, required this.text});

  factory ConditionalText.fromJson(Map<String, Object?> json, String field) =>
      ConditionalText._(
        id: jsonText(json['id'], '$field.id'),
        condition: Map.unmodifiable(jsonMap(json['condition'] ?? const {}, '$field.condition')),
        text: jsonText(json['text'], '$field.text'),
      );

  final String id;
  final Map<String, Object?> condition;
  final String text;

  bool get isDefault => condition.isEmpty;
}

final class SummaryTexts {
  const SummaryTexts._({
    required this.schemaVersion,
    required this.texts,
    required this.planFactRow,
    required this.planFactRowSavings,
    required this.verdicts,
    required this.overall,
    required this.statRow,
    required this.statUnchanged,
    required this.statReasons,
    required this.pointsRow,
    required this.pointReasons,
    required this.missedRow,
    required this.missedReasons,
    required this.pointsTotal,
    required this.toNextStage,
    required this.goal,
    required this.growth,
    required this.tomorrow,
    required this.forAdult,
  });

  factory SummaryTexts.fromJson(Map<String, Object?> json) {
    final planFact = jsonMap(json['planFact'], 'planFact');
    final stats = jsonMap(json['stats'], 'stats');
    final points = jsonMap(json['points'], 'points');
    final missed = jsonMap(points['missed'], 'points.missed');
    final overall = [
      for (final raw in jsonMaps(json['overall'], 'overall'))
        ConditionalText.fromJson(raw, 'overall'),
    ];
    final tomorrow = [
      for (final raw in jsonMaps(json['tomorrow'], 'tomorrow'))
        ConditionalText.fromJson(raw, 'tomorrow'),
    ];
    if (overall.isEmpty) {
      throw ArgumentError.value(overall, 'overall', 'нет ни одного вывода');
    }
    requireUniqueIds(overall.map((t) => t.id), 'overall.id');
    requireUniqueIds(tomorrow.map((t) => t.id), 'tomorrow.id');
    if (!tomorrow.any((t) => t.isDefault)) {
      throw ArgumentError.value(tomorrow, 'tomorrow', 'нет совета на любой случай');
    }
    return SummaryTexts._(
      schemaVersion: jsonInt(json['schemaVersion'] ?? 1, 'schemaVersion', min: 1),
      texts: jsonTexts(json['texts'], 'texts', required: const {
        'header',
        'planFactHeader',
        'statsHeader',
        'pointsHeader',
        'goalHeader',
        'tomorrowHeader',
        'close',
      }),
      planFactRow: jsonText(planFact['row'], 'planFact.row'),
      planFactRowSavings: jsonText(planFact['rowSavings'], 'planFact.rowSavings'),
      verdicts: jsonTexts(planFact['verdicts'], 'planFact.verdicts',
          required: const {'exact', 'less', 'more', 'zeroPlanned'}),
      overall: List.unmodifiable(overall),
      statRow: jsonText(stats['row'], 'stats.row'),
      statUnchanged: jsonText(stats['unchanged'], 'stats.unchanged'),
      statReasons: jsonTexts(stats['reasons'], 'stats.reasons', required: const {
        'fromPurchase',
        'fromPenalty',
        'fromDecay',
        'fromTask',
        'fromEvent',
        'fromPetting',
        'fromGoal',
      }),
      pointsRow: jsonText(points['row'], 'points.row'),
      pointReasons: _byFactor(points['reasons'], 'points.reasons'),
      missedRow: jsonText(missed['row'], 'points.missed.row'),
      missedReasons: _byFactor(missed, 'points.missed'),
      pointsTotal: jsonText(points['total'], 'points.total'),
      toNextStage: jsonText(points['toNextStage'], 'points.toNextStage'),
      goal: jsonTexts(json['goal'], 'goal', required: const {
        'progress',
        'depositedToday',
        'nothingToday',
        'eta',
        'noGoal',
        'reached',
      }),
      growth: jsonTexts(json['growth'], 'growth',
          required: const {'stageUp', 'stageUpWhy', 'title', 'cozyLevel'}),
      tomorrow: List.unmodifiable(tomorrow),
      forAdult: jsonTexts(json['forAdult'], 'forAdult',
          required: const {'header', 'row', 'hint'}),
    );
  }

  static Map<GrowthFactor, String> _byFactor(Object? raw, String field) {
    final map = jsonMap(raw, field);
    return Map.unmodifiable({
      for (final factor in GrowthFactor.values)
        factor: jsonText(map[factor.name], '$field.${factor.name}'),
    });
  }

  final int schemaVersion;
  final Map<String, String> texts;
  final String planFactRow;
  final String planFactRowSavings;
  final Map<String, String> verdicts;
  final List<ConditionalText> overall;
  final String statRow;
  final String statUnchanged;
  final Map<String, String> statReasons;
  final String pointsRow;
  final Map<GrowthFactor, String> pointReasons;
  final String missedRow;
  final Map<GrowthFactor, String> missedReasons;
  final String pointsTotal;
  final String toNextStage;
  final Map<String, String> goal;
  final Map<String, String> growth;
  final List<ConditionalText> tomorrow;
  final Map<String, String> forAdult;
}
