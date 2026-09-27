import 'package:finni/content/content_repository.dart';
import 'package:finni/domain/services/level_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/content.dart';

List<LevelRun> _play(LevelService service, int levels, {bool simple = false}) {
  final history = <LevelRecord>[];
  final runs = <LevelRun>[];
  for (var n = 1; n <= levels; n++) {
    final run = service.plan(n, simple: simple, history: history);
    runs.add(run);
    history.add(LevelRecord(
      number: n,
      day: n,
      taskIds: [for (final slot in run.slots) slot.taskId],
      stars: List.filled(run.slots.length, 3),
      coins: run.coins,
    ));
  }
  return runs;
}

void main() {
  late ContentBundle content;
  late LevelService service;

  setUpAll(() async {
    content = await loadTestContent();
    service = LevelService(levels: content.levels, tasks: content.tasks);
  });

  test('каждая игра открывается на своём уровне', () {
    expect(content.levels.unlocks.keys.toSet(),
        {for (final task in content.tasks.tasks) task.id});
    expect(content.issues, isEmpty);
  });

  test('первый уровень — три лёгкие новые игры', () {
    final first = service.plan(1);
    expect(first.slots, hasLength(3));
    expect(first.slots.every((slot) => !slot.isHard), isTrue);
    expect(first.slots.every((slot) => slot.isNew), isTrue);
    expect(first.coins, content.levels.tierFor(1).coins);
  });

  test('игры открываются постепенно, а не все сразу', () {
    expect(service.unlockedAt(1).length, lessThan(content.tasks.tasks.length));
    var before = 0;
    for (var n = 1; n <= 20; n++) {
      final open = service.unlockedAt(n).length;
      expect(open, greaterThanOrEqualTo(before));
      before = open;
    }
    expect(before, content.tasks.tasks.length);
  });

  test('с уровнями растут число игр и сложность, награда не падает', () {
    final runs = _play(service, 30);
    for (var i = 1; i < runs.length; i++) {
      expect(runs[i].slots.length, greaterThanOrEqualTo(runs[i - 1].slots.length));
      expect(runs[i].coins, greaterThanOrEqualTo(runs[i - 1].coins));
    }
    expect(runs.last.slots.length, greaterThan(runs.first.slots.length));
    expect(runs.last.hardCount, greaterThan(0));
    expect(runs.take(6).every((run) => run.hardCount == 0), isTrue);
  });

  test('в уровне нет повторов, закрытых игр и сложных новинок', () {
    for (final run in _play(service, 40)) {
      final ids = [for (final slot in run.slots) slot.taskId];
      expect(ids.toSet(), hasLength(ids.length), reason: 'уровень ${run.number}');
      for (final slot in run.slots) {
        expect(service.isUnlocked(slot.taskId, run.number), isTrue);
        if (slot.isNew) expect(slot.isHard, isFalse);
      }
      for (final task in service.newAt(run.number)) {
        expect(ids, contains(task.id), reason: 'новая игра на уровне ${run.number}');
      }
    }
  });

  test('за несколько уровней встречаются все открытые игры', () {
    final runs = _play(service, 24);
    final seen = {
      for (final run in runs.skip(16))
        for (final slot in run.slots) slot.taskId
    };
    expect(seen, {for (final task in content.tasks.tasks) task.id});
  });

  test('в режиме «попроще» сложные игры появляются позже', () {
    for (var n = 1; n <= 30; n++) {
      expect(service.hardFor(n, simple: true),
          lessThanOrEqualTo(service.hardFor(n)));
    }
    for (var n = 1; n <= content.levels.simpleModeDelay; n++) {
      expect(service.hardFor(n, simple: true), 0);
    }
    expect(_play(service, 30, simple: true).last.hardCount, greaterThan(0));
  });

  test('состояние уровня переживает сохранение', () {
    final run = service.plan(4).withStars(3).withStars(2);
    final restored = LevelRun.fromJson(run.toJson());
    expect(restored.number, 4);
    expect(restored.stars, [3, 2]);
    expect(restored.current?.taskId, run.slots[2].taskId);
    expect([for (final slot in restored.slots) slot.difficulty],
        [for (final slot in run.slots) slot.difficulty]);
  });

  test('следующая закрытая игра и тексты уровня', () {
    expect(service.nextUnlock(1)?.id, 'planning_choice_enough');
    expect(service.nextUnlock(99), isNull);
    expect(service.titleOf(3), contains('3'));
    expect(service.rewardReasonOf(3, 'Кассир'), allOf(contains('3'), contains('Кассир')));
    expect(service.dailyReasonOf('Кассир'), contains('Кассир'));
    expect(content.levels.tierFor(1).games, 3);
  });

  test('зарплата уровня делится на игры без потерь', () {
    for (final run in _play(service, 30)) {
      final shares = [for (var i = 0; i < run.slots.length; i++) run.shareOf(i)];
      expect(shares.fold(0, (a, b) => a + b), run.coins);
      expect(shares.every((share) => share >= 1), isTrue);
    }
  });

  test('задание дня зависит от календарной даты и выбирает из знакомых игр', () {
    final known = service.unlockedAt(5);
    final monday = DateTime(2026, 9, 28, 8);
    final first = service.dailyPick(monday, known);
    expect(known, contains(first));
    expect(service.dailyPick(monday.add(const Duration(hours: 12)), known), same(first));
    expect(service.dailyPick(monday.add(const Duration(days: 1)), known), isNot(same(first)));
    expect(service.dailyPick(monday, const []), isNull);
    expect(LevelService.dateKey(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
    expect(content.levels.daily.coins, greaterThan(0));
  });
}
