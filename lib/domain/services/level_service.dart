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
    if (stars.any((value) => value < 0 || value > 3)) {
      throw ArgumentError.value(stars, 'stars', 'от 0 до 3');
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

  int get played => stars.length;
  int get done => stars.where((value) => value > 0).length;
  bool get isStarted => played > 0;
  bool get isFinished =>
      played >= slots.length && stars.every((value) => value > 0);

  int? get currentIndex {
    if (played < slots.length) return played;
    final waiting = stars.indexWhere((value) => value == 0);
    return waiting < 0 ? null : waiting;
  }

  LevelSlot? get current =>
      currentIndex == null ? null : slots[currentIndex!];

  bool isWaiting(int index) => index < stars.length && stars[index] == 0;

  int payFor(int index, int earned) =>
      levelPay(shareOf(index), earned);

  int get paid => [
        for (var i = 0; i < stars.length; i++) payFor(i, stars[i])
      ].fold(0, (sum, value) => sum + value);
  int get hardCount => slots.where((slot) => slot.isHard).length;
  int get newCount => slots.where((slot) => slot.isNew).length;

  int shareOf(int index) {
    final base = coins ~/ slots.length;
    final extra = coins % slots.length;
    return base + (index >= slots.length - extra ? 1 : 0);
  }

  LevelRun withStars(int value) => withResult(played, value);

  LevelRun withResult(int index, int value) => LevelRun(
        number: number,
        coins: coins,
        slots: slots,
        stars: [
          for (var i = 0; i < stars.length; i++) i == index ? value : stars[i],
          if (index >= stars.length) value,
        ],
      );

  Map<String, Object?> toJson() => {
        'number': number,
        'coins': coins,
        'slots': [for (final slot in slots) slot.toJson()],
        'stars': stars,
      };
}

int levelPay(int share, int stars) =>
    (share * stars.clamp(0, 3) / 3).round();

final class LevelRecord {
  const LevelRecord({
    required this.number,
    required this.day,
    required this.taskIds,
    required this.stars,
    required this.coins,
    this.salary,
    this.hard = const [],
  });

  factory LevelRecord.fromJson(Map<String, Object?> json) => LevelRecord(
        number: json['number'] as int,
        day: json['day'] as int,
        taskIds: (json['taskIds'] as List).cast<String>(),
        stars: (json['stars'] as List).cast<int>(),
        coins: json['coins'] as int? ?? 0,
        salary: json['salary'] as int?,
        hard: (json['hard'] as List? ?? const []).cast<int>(),
      );

  final int number;
  final int day;
  final List<String> taskIds;
  final List<int> stars;
  final int coins;
  final int? salary;
  final List<int> hard;

  int get totalStars => stars.fold(0, (sum, value) => sum + value);

  int shareOf(int index) {
    final total = salary ?? stars.length * 3;
    final base = total ~/ stars.length;
    final extra = total % stars.length;
    return base + (index >= stars.length - extra ? 1 : 0);
  }

  TaskDifficulty difficultyOf(int index) =>
      hard.contains(index) ? TaskDifficulty.hard : TaskDifficulty.easy;

  LevelRecord improved(int index, int value) {
    final before = stars[index];
    if (value <= before) return this;
    return LevelRecord(
      number: number,
      day: day,
      taskIds: taskIds,
      stars: [
        for (var i = 0; i < stars.length; i++) i == index ? value : stars[i]
      ],
      coins: coins +
          levelPay(shareOf(index), value) -
          levelPay(shareOf(index), before),
      salary: salary,
      hard: hard,
    );
  }

  Map<String, Object?> toJson() => {
        'number': number,
        'day': day,
        'taskIds': taskIds,
        'stars': stars,
        'coins': coins,
        if (salary != null) 'salary': salary,
        if (hard.isNotEmpty) 'hard': hard,
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
