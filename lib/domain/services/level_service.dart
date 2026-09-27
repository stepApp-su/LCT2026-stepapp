import '../models/models.dart';
import '../text_template.dart';

final class LevelSlot {
  const LevelSlot({
    required this.taskId,
    required this.difficulty,
    this.isNew = false,
  });

  factory LevelSlot.fromJson(Map<String, Object?> json) => LevelSlot(
        taskId: json['taskId'] as String,
        difficulty: TaskDifficulty.values.byName(json['difficulty'] as String),
        isNew: json['isNew'] == true,
      );

  final String taskId;
  final TaskDifficulty difficulty;
  final bool isNew;

  bool get isHard => difficulty == TaskDifficulty.hard;

  Map<String, Object?> toJson() => {
        'taskId': taskId,
        'difficulty': difficulty.name,
        if (isNew) 'isNew': true,
      };
}

final class LevelRun {
  LevelRun({
    required this.number,
    required this.coins,
    required List<LevelSlot> slots,
    List<int> stars = const [],
  })  : slots = List.unmodifiable(slots),
        stars = List.unmodifiable(stars) {
    if (slots.isEmpty) throw ArgumentError.value(slots, 'slots', 'пустой уровень');
    if (stars.length > slots.length) {
      throw ArgumentError.value(stars.length, 'stars', 'больше, чем игр');
    }
  }

  factory LevelRun.fromJson(Map<String, Object?> json) => LevelRun(
        number: json['number'] as int,
        coins: json['coins'] as int,
        slots: [
          for (final raw in json['slots'] as List)
            LevelSlot.fromJson((raw as Map).cast<String, Object?>())
        ],
        stars: (json['stars'] as List? ?? const []).cast<int>(),
      );

  final int number;
  final int coins;
  final List<LevelSlot> slots;
  final List<int> stars;

  int get done => stars.length;
  bool get isStarted => done > 0;
  bool get isFinished => done >= slots.length;
  LevelSlot? get current => isFinished ? null : slots[done];
  int get hardCount => slots.where((slot) => slot.isHard).length;
  int get newCount => slots.where((slot) => slot.isNew).length;

  int shareOf(int index) {
    final base = coins ~/ slots.length;
    final extra = coins % slots.length;
    return base + (index >= slots.length - extra ? 1 : 0);
  }

  LevelRun withStars(int value) => LevelRun(
        number: number,
        coins: coins,
        slots: slots,
        stars: [...stars, value],
      );

  Map<String, Object?> toJson() => {
        'number': number,
        'coins': coins,
        'slots': [for (final slot in slots) slot.toJson()],
        'stars': stars,
      };
}

final class LevelRecord {
  const LevelRecord({
    required this.number,
    required this.day,
    required this.taskIds,
    required this.stars,
    required this.coins,
  });

  factory LevelRecord.fromJson(Map<String, Object?> json) => LevelRecord(
        number: json['number'] as int,
        day: json['day'] as int,
        taskIds: (json['taskIds'] as List).cast<String>(),
        stars: (json['stars'] as List).cast<int>(),
        coins: json['coins'] as int? ?? 0,
      );

  final int number;
  final int day;
  final List<String> taskIds;
  final List<int> stars;
  final int coins;

  int get totalStars => stars.fold(0, (sum, value) => sum + value);

  Map<String, Object?> toJson() => {
        'number': number,
        'day': day,
        'taskIds': taskIds,
        'stars': stars,
        'coins': coins,
      };
}

final class LevelService {
  LevelService({required this.levels, required this.tasks});

  final LevelCatalog levels;
  final TaskCatalog tasks;

  List<TaskDef> get _ordered =>
      [...tasks.tasks]..sort((a, b) => a.order.compareTo(b.order));

  int unlockLevelOf(String taskId) => levels.unlockLevelOf(taskId);

  bool isUnlocked(String taskId, int level) => unlockLevelOf(taskId) <= level;

  List<TaskDef> unlockedAt(int level) {
    final open = [
      for (final task in _ordered)
        if (isUnlocked(task.id, level)) task
    ];
    return open.isEmpty ? _ordered : open;
  }

  List<TaskDef> newAt(int level) => [
        for (final task in _ordered)
          if (unlockLevelOf(task.id) == level) task
      ];

  TaskDef? nextUnlock(int level) {
    TaskDef? next;
    for (final task in _ordered) {
      final at = unlockLevelOf(task.id);
      if (at > level && (next == null || at < unlockLevelOf(next.id))) {
        next = task;
      }
    }
    return next;
  }

  int hardFor(int level, {bool simple = false}) {
    final shifted = simple ? level - levels.simpleModeDelay : level;
    return shifted < 1 ? 0 : levels.tierFor(shifted).hard;
  }

  String titleOf(int level) =>
      fillTemplate(levels.texts.title, {'level': '$level'});

  String rewardReasonOf(int level, String taskTitle) => fillTemplate(
      levels.texts.rewardReason, {'level': '$level', 'taskTitle': taskTitle});

  String dailyReasonOf(String taskTitle) =>
      fillTemplate(levels.texts.dailyReason, {'taskTitle': taskTitle});

  static String dateKey(DateTime at) =>
      '${at.year.toString().padLeft(4, '0')}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';

  TaskDef? dailyPick(DateTime at, Iterable<TaskDef> known) {
    final pool = [...known]..sort((a, b) => a.order.compareTo(b.order));
    if (pool.isEmpty) return null;
    final day = DateTime.utc(at.year, at.month, at.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    return pool[day % pool.length];
  }

  Map<String, int> lastPlayed(Iterable<LevelRecord> history) => {
        for (final record in history)
          for (final id in record.taskIds) id: record.number,
      };

  LevelRun plan(
    int level, {
    bool simple = false,
    Iterable<LevelRecord> history = const [],
  }) {
    if (level < 1) throw ArgumentError.value(level, 'level', '≥ 1');
    final tier = levels.tierFor(level);
    final pool = unlockedAt(level);
    final last = lastPlayed(history);
    final fresh = [
      for (final task in newAt(level))
        if (pool.contains(task)) task
    ];
    final rest = [
      for (final task in pool)
        if (!fresh.contains(task)) task
    ]..sort((a, b) {
        final byLast = (last[a.id] ?? 0).compareTo(last[b.id] ?? 0);
        return byLast != 0 ? byLast : a.order.compareTo(b.order);
      });
    final picked = <TaskDef>[...fresh.take(tier.games)];
    final types = {for (final task in picked) task.type};
    for (final task in rest) {
      if (picked.length >= tier.games) break;
      if (types.add(task.type)) picked.add(task);
    }
    for (final task in rest) {
      if (picked.length >= tier.games) break;
      if (!picked.contains(task)) picked.add(task);
    }
    final practiced = picked.where((task) => !fresh.contains(task)).toList();
    var hard = hardFor(level, simple: simple);
    if (hard > practiced.length) hard = practiced.length;
    final hardIds = {
      for (final task in practiced.skip(practiced.length - hard)) task.id
    };
    return LevelRun(
      number: level,
      coins: tier.coins,
      slots: [
        for (final task in picked)
          LevelSlot(
            taskId: task.id,
            difficulty: hardIds.contains(task.id)
                ? TaskDifficulty.hard
                : TaskDifficulty.easy,
            isNew: fresh.contains(task),
          )
      ],
    );
  }

  bool fits(LevelRun run) =>
      run.slots.every((slot) => tasks.byId(slot.taskId) != null);
}
