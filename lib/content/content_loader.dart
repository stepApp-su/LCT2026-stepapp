import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/models.dart';

/// Загрузка статического JSON-контента из assets/content.
class ContentLoader {
  const ContentLoader();

  Future<List<Task>> loadTasks() => _loadList('assets/content/tasks.json', Task.fromJson);

  Future<List<ShopItem>> loadShopItems() =>
      _loadList('assets/content/shop.json', ShopItem.fromJson);

  Future<List<Goal>> loadGoals() => _loadList('assets/content/goals.json', Goal.fromJson);

  Future<List<Rank>> loadRanks() => _loadList('assets/content/ranks.json', Rank.fromJson);

  Future<List<FinniLine>> loadFinniLines() =>
      _loadList('assets/content/finni_lines.json', FinniLine.fromJson);

  Future<List<T>> _loadList<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final raw = await rootBundle.loadString(path);
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }
}
