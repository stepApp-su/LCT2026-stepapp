import 'content_json.dart';

final class LevelTier {
  const LevelTier._({
    required this.fromLevel,
    required this.games,
    required this.hard,
    required this.coins,
  });

  factory LevelTier.create({
    required int fromLevel,
    required int games,
    required int hard,
    required int coins,
  }) {
    if (fromLevel < 1) throw ArgumentError.value(fromLevel, 'fromLevel', '≥ 1');
    if (games < 1) throw ArgumentError.value(games, 'games', '≥ 1');
    if (hard < 0 || hard > games) {
      throw ArgumentError.value(hard, 'hard', '0..$games');
    }
    if (coins < games) {
      throw ArgumentError.value(coins, 'coins', 'не меньше числа игр');
    }
    return LevelTier._(
        fromLevel: fromLevel, games: games, hard: hard, coins: coins);
  }

  factory LevelTier.fromJson(Map<String, Object?> json) => LevelTier.create(
        fromLevel: jsonInt(json['fromLevel'], 'tiers.fromLevel'),
        games: jsonInt(json['games'], 'tiers.games'),
        hard: jsonInt(json['hard'], 'tiers.hard'),
        coins: jsonInt(json['coins'], 'tiers.coins'),
      );

  final int fromLevel;
  final int games;
  final int hard;
  final int coins;
}

final class LevelUnlock {
  const LevelUnlock._({required this.taskId, required this.level});

  factory LevelUnlock.fromJson(Map<String, Object?> json) => LevelUnlock._(
        taskId: jsonText(json['taskId'], 'unlocks.taskId'),
        level: jsonInt(json['level'], 'unlocks.level', min: 1),
      );

  final String taskId;
  final int level;
}

final class LevelTexts {
  const LevelTexts._({
    required this.title,
    required this.rewardReason,
    required this.dailyReason,
  });

  factory LevelTexts.fromJson(Map<String, Object?> json) {
    final texts = jsonTexts(json, 'texts',
        required: const {'title', 'rewardReason', 'dailyReason'});
    return LevelTexts._(
      title: texts['title']!,
      rewardReason: texts['rewardReason']!,
      dailyReason: texts['dailyReason']!,
    );
  }

  final String title;
  final String rewardReason;
  final String dailyReason;
}

final class DailyRules {
  const DailyRules._({required this.coins, required this.perfectBonus});

  factory DailyRules.fromJson(Map<String, Object?> json) => DailyRules._(
        coins: jsonInt(json['coins'], 'daily.coins', min: 1),
        perfectBonus: jsonInt(json['perfectBonus'] ?? 0, 'daily.perfectBonus', min: 0),
      );

  final int coins;
  final int perfectBonus;
}

final class LevelCatalog {
  const LevelCatalog._({
    required this.schemaVersion,
    required this.texts,
    required this.daily,
    required this.simpleModeDelay,
    required this.tiers,
    required this.unlocks,
  });

  factory LevelCatalog.fromJson(Map<String, Object?> json) {
    final tiers = [
      for (final raw in jsonMaps(json['tiers'], 'tiers')) LevelTier.fromJson(raw),
    ];
    if (tiers.isEmpty || tiers.first.fromLevel != 1) {
      throw ArgumentError.value(tiers.length, 'tiers', 'первая ступень — с уровня 1');
    }
    for (var i = 1; i < tiers.length; i++) {
      if (tiers[i].fromLevel <= tiers[i - 1].fromLevel) {
        throw ArgumentError.value(
            tiers[i].fromLevel, 'tiers.fromLevel', 'ступени идут по возрастанию');
      }
    }
    final unlocks = <String, int>{};
    for (final raw in jsonMaps(json['unlocks'] ?? const [], 'unlocks')) {
      final unlock = LevelUnlock.fromJson(raw);
      if (unlocks.containsKey(unlock.taskId)) {
        throw ArgumentError.value(unlock.taskId, 'unlocks.taskId', 'повторяется');
      }
      unlocks[unlock.taskId] = unlock.level;
    }
    return LevelCatalog._(
      schemaVersion: jsonInt(json['schemaVersion'], 'schemaVersion', min: 1),
      texts: LevelTexts.fromJson(jsonMap(json['texts'], 'texts')),
      daily: DailyRules.fromJson(jsonMap(json['daily'], 'daily')),
      simpleModeDelay:
          jsonInt(json['simpleModeDelay'] ?? 0, 'simpleModeDelay', min: 0),
      tiers: List.unmodifiable(tiers),
      unlocks: Map.unmodifiable(unlocks),
    );
  }

  final int schemaVersion;
  final LevelTexts texts;
  final DailyRules daily;
  final int simpleModeDelay;
  final List<LevelTier> tiers;
  final Map<String, int> unlocks;

  LevelTier tierFor(int level) {
    var tier = tiers.first;
    for (final candidate in tiers) {
      if (candidate.fromLevel <= level) tier = candidate;
    }
    return tier;
  }

  int unlockLevelOf(String taskId) => unlocks[taskId] ?? 1;
}
