import 'models.dart';

/// Текущий прогресс ребёнка в приложении.
class Progress {
  final int points;
  final Set<String> completedTaskIds;
  final Set<String> purchasedItemIds;

  const Progress({
    this.points = 0,
    this.completedTaskIds = const {},
    this.purchasedItemIds = const {},
  });

  Progress copyWith({
    int? points,
    Set<String>? completedTaskIds,
    Set<String>? purchasedItemIds,
  }) {
    return Progress(
      points: points ?? this.points,
      completedTaskIds: completedTaskIds ?? this.completedTaskIds,
      purchasedItemIds: purchasedItemIds ?? this.purchasedItemIds,
    );
  }
}

/// Бизнес-правила: начисление очков, звания, покупки. Никакого I/O и Flutter.
class ProgressRules {
  const ProgressRules();

  bool isTaskCompleted(Progress progress, Task task) =>
      progress.completedTaskIds.contains(task.id);

  Progress completeTask(Progress progress, Task task) {
    if (isTaskCompleted(progress, task)) return progress;
    return progress.copyWith(
      points: progress.points + task.reward,
      completedTaskIds: {...progress.completedTaskIds, task.id},
    );
  }

  bool canAfford(Progress progress, ShopItem item) =>
      !progress.purchasedItemIds.contains(item.id) &&
      progress.points >= item.cost;

  Progress purchase(Progress progress, ShopItem item) {
    if (!canAfford(progress, item)) return progress;
    return progress.copyWith(
      points: progress.points - item.cost,
      purchasedItemIds: {...progress.purchasedItemIds, item.id},
    );
  }

  /// Текущее звание — последнее по списку (отсортированному по возрастанию
  /// minPoints), чей порог уже достигнут.
  Rank currentRank(Progress progress, List<Rank> ranks) {
    final sorted = [...ranks]..sort((a, b) => a.minPoints.compareTo(b.minPoints));
    Rank result = sorted.first;
    for (final rank in sorted) {
      if (progress.points >= rank.minPoints) {
        result = rank;
      }
    }
    return result;
  }

  double goalProgress(Progress progress, Goal goal) {
    if (goal.targetAmount <= 0) return 0;
    final ratio = progress.points / goal.targetAmount;
    return ratio.clamp(0, 1).toDouble();
  }
}
