import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

import '../domain/models.dart';
import '../domain/models/models.dart' as domain;
import '../domain/profile_codec.dart';
import '../domain/profile_repository.dart';
import 'content_repository.dart';

/// Загрузка статического JSON-контента из assets/content.
class ContentLoader {
  const ContentLoader();

  Future<ContentBundle> loadAll() => ContentRepository(
        (file) => rootBundle.loadString('assets/content/$file'),
        onIssue: (issue) => debugPrint('Контент: $issue'),
      ).load();

  static const String shopPath = 'assets/content/shop.json';
  static const String goalsPath = 'assets/content/goals.json';
  static const String tasksPath = 'assets/content/tasks.json';
  static const String competencesPath = 'assets/content/competences.json';
  static const String phrasesPath = 'assets/content/phrases.json';
  static const String economyPath = 'assets/content/economy.json';
  static const String titlesPath = 'assets/content/titles.json';
  static const String testProfilePath = 'assets/content/test_profile.json';
  static const String soundsPath = 'assets/content/sounds.json';

  /// Старые триггеры экранов-заглушек -> триггеры банка реплик.
  static const Map<String, String> _legacyTriggers = {
    'welcome': 'app_open',
    'purchase': 'purchase_done',
    'task_completed': 'task_done',
    'not_enough_points': 'purchase_not_enough',
  };

  /// Каталог заданий целиком: темы, тексты интерфейса и сами задания.
  Future<domain.TaskCatalog> loadTaskCatalog() async {
    final raw = await rootBundle.loadString(tasksPath);
    return domain.TaskCatalog.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>());
  }

  /// Звуковая схема: события, бормотание питомцев, озвучка реплик.
  Future<domain.SoundScheme> loadSoundScheme() async {
    final raw = await rootBundle.loadString(soundsPath);
    return domain.SoundScheme.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>());
  }

  /// Параметры экономики: правила шкал питомца.
  Future<domain.EconomyConfig> loadEconomy() async {
    final raw = await rootBundle.loadString(economyPath);
    return domain.EconomyConfig.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>());
  }

  Future<domain.TitleCatalog> loadTitleCatalog() async {
    final raw = await rootBundle.loadString(titlesPath);
    final catalog = domain.TitleCatalog.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>());
    for (final problem in catalog.problems) {
      debugPrint('$titlesPath: $problem');
    }
    return catalog;
  }

  Future<domain.Profile> loadTestProfile() async {
    final result =
        ProfileCodec.decode(await rootBundle.loadString(testProfilePath));
    return switch (result) {
      ProfileLoaded(:final profile) => profile,
      ProfileUnreadable(:final reason) =>
        throw FormatException('Тестовый профиль не читается: $reason'),
      ProfileMissing() => throw const FormatException('Тестового профиля нет'),
    };
  }

  Future<domain.CompetenceCatalog> loadCompetences() async {
    final raw = await rootBundle.loadString(competencesPath);
    return domain.CompetenceCatalog.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>());
  }

  Future<List<Task>> loadTasks() async {
    final catalog = await loadTaskCatalog();
    return [
      for (final task in catalog.tasks)
        Task(
          id: task.id,
          title: task.title,
          description: task.variant(domain.TaskDifficulty.easy).intro,
          reward: task.reward.correct,
          category: catalog.theme(task.themeId)?.title ?? task.themeId,
        )
    ];
  }

  /// Каталог магазина целиком: категории, тексты, правила сравнения цен.
  Future<domain.ShopCatalog> loadShopCatalog() async {
    final raw = await rootBundle.loadString(shopPath);
    return domain.ShopCatalog.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>());
  }

  Future<List<ShopItem>> loadShopItems() async {
    final catalog = await loadShopCatalog();
    return [
      for (final item in catalog.items)
        if (item.showInShop)
          ShopItem(
            id: item.id,
            title: item.title,
            cost: item.price,
            icon: item.iconId,
          )
    ];
  }

  /// Каталог целей целиком: параметры расчёта срока, тексты и сами цели.
  Future<domain.GoalCatalog> loadGoalCatalog() async {
    final raw = await rootBundle.loadString(goalsPath);
    return domain.GoalCatalog.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>());
  }

  Future<List<Goal>> loadGoals() async {
    final catalog = await loadGoalCatalog();
    return [
      for (final goal in catalog.goals)
        Goal(id: goal.id, title: goal.title, targetAmount: goal.price)
    ];
  }

  Future<List<Rank>> loadRanks() => _loadList('assets/content/ranks.json', Rank.fromJson);

  /// Банк реплик питомца: характеры, триггеры и шаблоны.
  Future<domain.PhraseCatalog> loadPhrases() async {
    final raw = await rootBundle.loadString(phrasesPath);
    return domain.PhraseCatalog.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>());
  }

  Future<List<FinniLine>> loadFinniLines() async {
    final catalog = await loadPhrases();
    final character = catalog.characters.keys.first;
    final lines = <FinniLine>[];
    for (final entry in _legacyTriggers.entries) {
      for (final phrase in catalog.byTrigger(entry.value)) {
        if (phrase.placeholders.isEmpty) {
          lines.add(FinniLine(
            id: phrase.id,
            trigger: entry.key,
            text: phrase.templateFor(character)!,
          ));
        }
      }
    }
    return lines;
  }

  Future<List<T>> _loadList<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final raw = await rootBundle.loadString(path);
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }
}
