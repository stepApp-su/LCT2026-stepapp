import 'growth.dart';
import 'pet.dart';

final class GrowthFactorTexts {
  const GrowthFactorTexts._({
    required this.met,
    required this.missed,
    required this.action,
  });

  factory GrowthFactorTexts.create({
    required String met,
    required String missed,
    required String action,
  }) {
    _requireText(met, 'met');
    _requireText(missed, 'missed');
    _requireText(action, 'action');
    return GrowthFactorTexts._(met: met, missed: missed, action: action);
  }

  factory GrowthFactorTexts.fromJson(Map<String, Object?> json) =>
      GrowthFactorTexts.create(
        met: json['met'] as String,
        missed: json['missed'] as String,
        action: json['action'] as String,
      );

  final String met;
  final String missed;
  final String action;
}

final class GrowthTexts {
  const GrowthTexts._({
    required this.stageLabels,
    required this.factors,
    required this.stageUp,
    required this.reasonOneDay,
    required this.reasonDays,
    required this.reasonFallback,
  });

  factory GrowthTexts.create({
    required Map<PetStage, String> stageLabels,
    required Map<GrowthFactor, GrowthFactorTexts> factors,
    required String stageUp,
    required String reasonOneDay,
    required String reasonDays,
    required String reasonFallback,
  }) {
    for (final stage in PetStage.values) {
      _requireText(stageLabels[stage] ?? '', 'stageLabels.${stage.name}');
    }
    for (final factor in GrowthFactor.values) {
      if (!factors.containsKey(factor)) {
        throw ArgumentError.value(factor.name, 'factors', 'нет текстов');
      }
    }
    _requirePlaceholders(stageUp, 'stageUp', ['{name}', '{stage}']);
    _requirePlaceholders(reasonOneDay, 'reasonOneDay', ['{actions}']);
    _requirePlaceholders(
        reasonDays, 'reasonDays', ['{days} {day}', '{actions}']);
    _requireText(reasonFallback, 'reasonFallback');
    return GrowthTexts._(
      stageLabels: Map.unmodifiable(stageLabels),
      factors: Map.unmodifiable(factors),
      stageUp: stageUp,
      reasonOneDay: reasonOneDay,
      reasonDays: reasonDays,
      reasonFallback: reasonFallback,
    );
  }

  factory GrowthTexts.fromJson(Map<String, Object?> json) => GrowthTexts.create(
        stageLabels: {
          for (final e in (json['stageLabels'] as Map).entries)
            PetStage.values.byName(e.key as String): e.value as String
        },
        factors: {
          for (final e in (json['factors'] as Map).entries)
            GrowthFactor.values.byName(e.key as String):
                GrowthFactorTexts.fromJson(
                    (e.value as Map).cast<String, Object?>())
        },
        stageUp: json['stageUp'] as String,
        reasonOneDay: json['reasonOneDay'] as String,
        reasonDays: json['reasonDays'] as String,
        reasonFallback: json['reasonFallback'] as String,
      );

  final Map<PetStage, String> stageLabels;
  final Map<GrowthFactor, GrowthFactorTexts> factors;
  final String stageUp;
  final String reasonOneDay;
  final String reasonDays;
  final String reasonFallback;
}

final class GrowthRules {
  const GrowthRules._({
    required this.points,
    required this.planTolerance,
    required this.thresholds,
    required this.texts,
  });

  factory GrowthRules.create({
    required Map<GrowthFactor, int> points,
    required PlanTolerance planTolerance,
    required Map<PetStage, int> thresholds,
    required GrowthTexts texts,
  }) {
    for (final factor in GrowthFactor.values) {
      final value = points[factor];
      if (value == null || value < 1) {
        throw ArgumentError.value(value, 'points.${factor.name}', '≥ 1');
      }
    }
    if (thresholds.containsKey(PetStage.egg)) {
      throw ArgumentError.value(
          thresholds[PetStage.egg], 'stages.egg', 'яйцо — всегда с нуля');
    }
    var previous = 0;
    for (final stage in PetStage.values.skip(1)) {
      final from = thresholds[stage];
      if (from == null || from <= previous) {
        throw ArgumentError.value(from, 'stages.${stage.name}',
            'пороги строго растут, больше $previous');
      }
      previous = from;
    }
    return GrowthRules._(
      points: Map.unmodifiable(points),
      planTolerance: planTolerance,
      thresholds: Map.unmodifiable({PetStage.egg: 0, ...thresholds}),
      texts: texts,
    );
  }

  factory GrowthRules.fromJson(Map<String, Object?> json) => GrowthRules.create(
        points: {
          for (final e in (json['points'] as Map).entries)
            GrowthFactor.values.byName(e.key as String): e.value as int
        },
        planTolerance: PlanTolerance.fromJson(
            (json['planTolerance'] as Map).cast<String, Object?>()),
        thresholds: {
          for (final e in (json['stages'] as Map).entries)
            PetStage.values.byName(e.key as String): e.value as int
        },
        texts: GrowthTexts.fromJson(
            (json['texts'] as Map).cast<String, Object?>()),
      );

  final Map<GrowthFactor, int> points;
  final PlanTolerance planTolerance;
  final Map<PetStage, int> thresholds;
  final GrowthTexts texts;

  int get maxDailyPoints => points.values.fold(0, (sum, p) => sum + p);

  int toleranceFor(int planned) => planTolerance.allowedFor(planned);

  PetStage stageFor(int growthPoints) {
    var stage = PetStage.egg;
    for (final candidate in PetStage.values) {
      if (growthPoints >= thresholds[candidate]!) stage = candidate;
    }
    return stage;
  }
}

void _requireText(String text, String name) {
  if (text.trim().isEmpty) {
    throw ArgumentError.value(text, name, 'текст не может быть пустым');
  }
}

void _requirePlaceholders(String text, String name, List<String> required) {
  _requireText(text, name);
  for (final placeholder in required) {
    if (!text.contains(placeholder)) {
      throw ArgumentError.value(text, name, 'нужен $placeholder');
    }
  }
}
