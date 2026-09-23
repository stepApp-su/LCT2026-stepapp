/// Каталог целей: параметры расчёта, тексты и сами цели.
/// Всё приходит из assets/content/goals.json — в коде нет ни цен,
/// ни формулировок, ни размера окна усреднения.
library;

import 'economy.dart';

/// Параметры расчёта срока. Балансировка не требует пересборки.
final class GoalSettings {
  const GoalSettings({
    this.averageWindowDays = 3,
    this.roundAverageTo = 1,
    this.milestonesPercent = const [25, 50, 75],
    this.starterRecommendationId = '',
  });

  /// Сколько последних дней с пополнением берём в среднее (ТЗ 2.5.7).
  final int averageWindowDays;

  /// До чего округляем среднее. Заодно нижняя граница: среднее никогда
  /// не станет нулём, поэтому делить на ноль не на чем.
  final int roundAverageTo;

  /// Промежуточные вехи: долгая цель обязана иметь микропраздники.
  final List<int> milestonesPercent;

  /// Какую цель советуем новичку.
  final String starterRecommendationId;

  factory GoalSettings.fromJson(Map<String, Object?> json) => GoalSettings(
        averageWindowDays: (json['averageWindowDays'] ?? 3) as int,
        roundAverageTo: (json['roundAverageTo'] ?? 1) as int,
        milestonesPercent: List.unmodifiable([
          for (final p in (json['milestonesPercent'] as List? ?? const []))
            p as int
        ]),
        starterRecommendationId:
            (json['starterRecommendationId'] ?? '') as String,
      );
}

final class EtaTexts {
  const EtaTexts({
    required this.noDeposits,
    required this.estimate,
    required this.lastStep,
    required this.reached,
  });

  /// Пополнений не было — показываем это, а не «∞» и не «N/A».
  final String noDeposits;
  final String estimate;
  final String lastStep;
  final String reached;

  factory EtaTexts.fromJson(Map<String, Object?> json) => EtaTexts(
        noDeposits: json['noDeposits'] as String,
        estimate: json['estimate'] as String,
        lastStep: json['lastStep'] as String,
        reached: json['reached'] as String,
      );
}

final class ChangeGoalTexts {
  const ChangeGoalTexts({
    required this.question,
    required this.keepSavings,
    required this.confirm,
    required this.cancel,
  });

  final String question;

  /// «Все 75 монет останутся в копилке» — смена цели ничего не обнуляет.
  final String keepSavings;
  final String confirm;
  final String cancel;

  factory ChangeGoalTexts.fromJson(Map<String, Object?> json) =>
      ChangeGoalTexts(
        question: json['question'] as String,
        keepSavings: json['keepSavings'] as String,
        confirm: json['confirm'] as String,
        cancel: json['cancel'] as String,
      );
}

final class WithdrawTexts {
  const WithdrawTexts({
    required this.question,
    required this.savedChange,
    required this.etaChange,
    required this.etaUnknown,
    required this.confirm,
    required this.cancel,
  });

  final String question;
  final String savedChange;
  final String etaChange;
  final String etaUnknown;

  /// Тон нейтральный: «Да» всегда доступно и не спрятано.
  final String confirm;
  final String cancel;

  factory WithdrawTexts.fromJson(Map<String, Object?> json) => WithdrawTexts(
        question: json['question'] as String,
        savedChange: json['savedChange'] as String,
        etaChange: json['etaChange'] as String,
        etaUnknown: json['etaUnknown'] as String,
        confirm: json['confirm'] as String,
        cancel: json['cancel'] as String,
      );
}

final class GoalJournalTexts {
  const GoalJournalTexts({
    required this.toSavings,
    required this.fromSavings,
    required this.goalReached,
  });

  final String toSavings;
  final String fromSavings;
  final String goalReached;

  factory GoalJournalTexts.fromJson(Map<String, Object?> json) =>
      GoalJournalTexts(
        toSavings: json['toSavings'] as String,
        fromSavings: json['fromSavings'] as String,
        goalReached: json['goalReached'] as String,
      );
}

final class GoalTexts {
  const GoalTexts({
    required this.starterHint,
    required this.progress,
    required this.left,
    required this.eta,
    required this.milestones,
    required this.reachedButton,
    required this.changeGoal,
    required this.withdraw,
    required this.journal,
    required this.newGoalsUnlocked,
    this.unknownGoal = 'Такой цели нет',
    this.goalLocked = 'Эта цель откроется позже',
    this.goalAlreadyReached = 'Эта цель уже достигнута',
    this.sameGoal = 'Эта цель уже выбрана',
    this.noGoalSelected = 'Сначала выбери цель',
    this.needsConfirmation = 'Сначала спросим: выбираем?',
    this.notEnoughSavings = 'В копилке пока меньше',
  });

  final String starterHint;
  final String progress;
  final String left;
  final EtaTexts eta;

  /// Процент вехи -> реплика микропраздника.
  final Map<int, String> milestones;
  final String reachedButton;
  final ChangeGoalTexts changeGoal;
  final WithdrawTexts withdraw;
  final GoalJournalTexts journal;
  final String newGoalsUnlocked;

  /// Отказы. Ребёнок их видит, значит правит их не программист.
  final String unknownGoal;
  final String goalLocked;
  final String goalAlreadyReached;
  final String sameGoal;
  final String noGoalSelected;
  final String needsConfirmation;
  final String notEnoughSavings;

  String? milestoneText(int percent) => milestones[percent];

  factory GoalTexts.fromJson(Map<String, Object?> json) {
    String text(String key, String fallback) =>
        (json[key] as String?) ?? fallback;
    return GoalTexts(
      starterHint: (json['starterHint'] ?? '') as String,
      progress: json['progress'] as String,
      left: json['left'] as String,
      eta: EtaTexts.fromJson((json['eta'] as Map).cast<String, Object?>()),
      milestones: Map.unmodifiable({
        for (final e in ((json['milestones'] as Map?) ?? const {}).entries)
          int.parse(e.key as String): e.value as String
      }),
      reachedButton: (json['reachedButton'] ?? '') as String,
      changeGoal: ChangeGoalTexts.fromJson(
          (json['changeGoal'] as Map).cast<String, Object?>()),
      withdraw: WithdrawTexts.fromJson(
          (json['withdraw'] as Map).cast<String, Object?>()),
      journal: GoalJournalTexts.fromJson(
          (json['journal'] as Map).cast<String, Object?>()),
      newGoalsUnlocked: (json['newGoalsUnlocked'] ?? '') as String,
      unknownGoal: text('unknownGoal', 'Такой цели нет'),
      goalLocked: text('goalLocked', 'Эта цель откроется позже'),
      goalAlreadyReached:
          text('goalAlreadyReached', 'Эта цель уже достигнута'),
      sameGoal: text('sameGoal', 'Эта цель уже выбрана'),
      noGoalSelected: text('noGoalSelected', 'Сначала выбери цель'),
      needsConfirmation:
          text('needsConfirmation', 'Сначала спросим: выбираем?'),
      notEnoughSavings: text('notEnoughSavings', 'В копилке пока меньше'),
    );
  }
}

final class GoalCatalog {
  const GoalCatalog._({
    required this.schemaVersion,
    required this.competenceIds,
    required this.settings,
    required this.texts,
    required this.goals,
  });

  factory GoalCatalog.create({
    int schemaVersion = 1,
    List<String> competenceIds = const [],
    GoalSettings settings = const GoalSettings(),
    required GoalTexts texts,
    required List<Goal> goals,
  }) {
    if (goals.isEmpty) {
      throw ArgumentError.value(goals, 'goals', 'каталог целей пуст');
    }
    final ids = <String>{};
    for (final goal in goals) {
      if (!ids.add(goal.id)) {
        throw ArgumentError.value(goal.id, 'id', 'повторяется в каталоге');
      }
    }
    if (settings.averageWindowDays < 1) {
      throw ArgumentError.value(settings.averageWindowDays,
          'averageWindowDays', 'окно усреднения ≥ 1 дня');
    }
    // Ноль сделал бы среднее пополнение нулевым, а деление на него —
    // бесконечным сроком. Такого ребёнок увидеть не должен.
    if (settings.roundAverageTo < 1) {
      throw ArgumentError.value(
          settings.roundAverageTo, 'roundAverageTo', 'округление ≥ 1');
    }
    for (final percent in settings.milestonesPercent) {
      if (percent <= 0 || percent >= 100) {
        throw ArgumentError.value(percent, 'milestonesPercent', 'веха 1..99');
      }
      if (!texts.milestones.containsKey(percent)) {
        throw ArgumentError.value(
            percent, 'milestones', 'нет текста для вехи');
      }
    }
    final starter = settings.starterRecommendationId;
    if (starter.isNotEmpty && !ids.contains(starter)) {
      throw ArgumentError.value(starter, 'starterRecommendationId',
          'такой цели нет в каталоге');
    }
    return GoalCatalog._(
      schemaVersion: schemaVersion,
      competenceIds: List.unmodifiable(competenceIds),
      settings: settings,
      texts: texts,
      goals: List.unmodifiable(goals),
    );
  }

  factory GoalCatalog.fromJson(Map<String, Object?> json) => GoalCatalog.create(
        schemaVersion: (json['schemaVersion'] ?? 1) as int,
        competenceIds: [
          for (final c in (json['competenceIds'] as List? ?? const []))
            c as String
        ],
        settings: json['settings'] == null
            ? const GoalSettings()
            : GoalSettings.fromJson(
                (json['settings'] as Map).cast<String, Object?>()),
        texts: GoalTexts.fromJson((json['texts'] as Map).cast<String, Object?>()),
        goals: [
          for (final raw in (json['goals'] as List))
            Goal.fromJson((raw as Map).cast<String, Object?>())
        ],
      );

  final int schemaVersion;

  /// Компетенции Единой рамки — для карты образовательного контента.
  final List<String> competenceIds;
  final GoalSettings settings;
  final GoalTexts texts;
  final List<Goal> goals;

  Goal? byId(String id) {
    for (final goal in goals) {
      if (goal.id == id) return goal;
    }
    return null;
  }

  Goal? get recommended => settings.starterRecommendationId.isEmpty
      ? null
      : byId(settings.starterRecommendationId);

  /// Вехи по возрастанию — микропраздники идут по порядку.
  List<int> get milestones =>
      List.unmodifiable([...settings.milestonesPercent]..sort());
}
