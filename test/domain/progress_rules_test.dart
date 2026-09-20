import 'package:finni/domain/models.dart';
import 'package:finni/domain/progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rules = ProgressRules();
  const task = Task(
    id: 't1',
    title: 'Test',
    description: 'desc',
    reward: 10,
    category: 'test',
  );
  const item = ShopItem(id: 'i1', title: 'Item', cost: 10, icon: 'icon');

  test('completing a task adds reward once', () {
    var progress = const Progress();
    progress = rules.completeTask(progress, task);
    expect(progress.points, 10);
    expect(rules.isTaskCompleted(progress, task), isTrue);

    progress = rules.completeTask(progress, task);
    expect(progress.points, 10, reason: 'reward must not stack');
  });

  test('cannot purchase without enough points', () {
    const progress = Progress(points: 5);
    expect(rules.canAfford(progress, item), isFalse);
    final result = rules.purchase(progress, item);
    expect(result.points, 5);
  });

  test('purchase deducts points and marks item owned', () {
    const progress = Progress(points: 10);
    final result = rules.purchase(progress, item);
    expect(result.points, 0);
    expect(result.purchasedItemIds, contains('i1'));
  });

  test('current rank is highest reached threshold', () {
    const ranks = [
      Rank(id: 'r0', title: 'Новичок', minPoints: 0),
      Rank(id: 'r1', title: 'Средний', minPoints: 20),
      Rank(id: 'r2', title: 'Эксперт', minPoints: 50),
    ];
    const progress = Progress(points: 25);
    final rank = rules.currentRank(progress, ranks);
    expect(rank.id, 'r1');
  });

  test('goal progress is clamped to [0, 1]', () {
    const goal = Goal(id: 'g1', title: 'Goal', targetAmount: 20);
    expect(rules.goalProgress(const Progress(points: 0), goal), 0);
    expect(rules.goalProgress(const Progress(points: 10), goal), 0.5);
    expect(rules.goalProgress(const Progress(points: 100), goal), 1);
  });
}
