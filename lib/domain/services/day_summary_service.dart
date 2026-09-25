/// Итоги дня: план против факта по трём направлениям и объяснение
/// для ребёнка. Тексты — шаблоны из assets/content/summaries.json.
library;

import '../models/models.dart';
import '../text_template.dart';

/// Полный результат дня для экрана итогов.
final class DayResult {
  const DayResult({
    required this.summary,
    required this.diffMandatory,
    required this.diffOptional,
    required this.diffSavings,
    required this.purchases,
    required this.stateChanges,
    required this.explainText,
  });

  final DaySummary summary;

  /// Факт минус план: плюс — потратил/отложил больше, минус — меньше.
  final int diffMandatory;
  final int diffOptional;
  final int diffSavings;

  final List<Transaction> purchases;
  final Map<PetStat, int> stateChanges;
  final String explainText;
}

final class DaySummaryService {
  DaySummaryService({required Map<String, String> templates})
      : _templates = Map.unmodifiable(templates);

  final Map<String, String> _templates;

  /// Факт по кучкам считается тем же счётом, что и рост (DayFacts),
  /// иначе итоги и очки питомца разойдутся. Очки дня приходят готовыми
  /// из GrowthService.closeDay.
  DayResult build({
    required GameDay day,
    required PetState before,
    required PetState after,
    required int growthPoints,
    String petName = 'питомец',
    int savedTotal = 0,
  }) {
    final facts = DayFacts.fromDay(day, mandatoryItemIds: const []);

    var earned = 0;
    final purchases = <Transaction>[];
    for (final t in day.transactions) {
      if (t.dayNumber != day.number) continue;
      if (t.sourceId.startsWith('goal:')) continue;
      switch (t.type) {
        case TransactionType.income:
          earned += t.amount;
        case TransactionType.expense:
          purchases.add(t);
        case TransactionType.toSavings:
        case TransactionType.fromSavings:
          break;
      }
    }

    final summary = DaySummary.create(
      dayNumber: day.number,
      plannedMandatory: day.plan.mandatory,
      plannedOptional: day.plan.optional,
      plannedSavings: day.plan.savings,
      actualMandatory: facts.spentMandatory,
      actualOptional: facts.spentOptional,
      actualSavings: facts.deposited,
      growthPoints: growthPoints,
    );

    final changes = <PetStat, int>{
      for (final stat in PetStat.values)
        if (after.of(stat) != before.of(stat))
          stat: after.of(stat) - before.of(stat),
    };

    return DayResult(
      summary: summary,
      diffMandatory: facts.spentMandatory - day.plan.mandatory,
      diffOptional: facts.spentOptional - day.plan.optional,
      diffSavings: facts.deposited - day.plan.savings,
      purchases: purchases,
      stateChanges: changes,
      explainText: _explain(
        summary: summary,
        earned: earned,
        petName: petName,
        savedTotal: savedTotal,
      ),
    );
  }

  /// Одно-два коротких предложения: что произошло и что делать дальше.
  /// Сценарии по важности: не хватило на нужное — перебор желаемого —
  /// недобор копилки — пустой день — похвала — общий случай.
  String _explain({
    required DaySummary summary,
    required int earned,
    required String petName,
    required int savedTotal,
  }) {
    final s = summary;
    final spent = s.actualMandatory + s.actualOptional;

    String pick(String key, Map<String, int> nums) => fillTemplate(
          _templates[key] ?? _templates['generic'] ?? '',
          {
            'petName': petName,
            for (final e in nums.entries) e.key: '${e.value}',
          },
        );

    if (earned == 0 && spent == 0 && s.actualSavings == 0) {
      return pick('emptyDay', {});
    }
    if (s.actualMandatory < s.plannedMandatory) {
      return pick('underMandatory',
          {'gapMandatory': s.plannedMandatory - s.actualMandatory});
    }
    if (s.actualOptional > s.plannedOptional) {
      return pick('overspentOptional',
          {'overOptional': s.actualOptional - s.plannedOptional});
    }
    if (s.actualSavings > s.plannedSavings) {
      return pick('savedMore',
          {'extraSavings': s.actualSavings - s.plannedSavings});
    }
    if (s.actualSavings < s.plannedSavings) {
      return pick('underSavings', {
        'actualSavings': s.actualSavings,
        'plannedSavings': s.plannedSavings,
      });
    }
    if (s.actualMandatory == s.plannedMandatory &&
        s.actualOptional == s.plannedOptional) {
      return pick('perfect', {'savedTotal': savedTotal});
    }
    return pick('generic', {'earned': earned, 'spent': spent});
  }
}
