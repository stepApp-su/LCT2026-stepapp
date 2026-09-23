import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/models/models.dart';

class GameContent {
  static Future<Map<String, dynamic>> load() async {
    final config =
        (jsonDecode(await rootBundle.loadString('assets/content/game.json'))
                as Map)
            .cast<String, dynamic>();
    validate(config);
    return config;
  }

  static void validate(Map<String, dynamic> config) {
    final ids = <String>{};
    for (final raw in config['catalog'] as List) {
      final item = ShopItem.fromJson((raw as Map).cast<String, Object?>());
      if (!ids.add(item.id)) {
        throw const FormatException('Повторяется id товара');
      }
      if (!['props', 'accessories'].contains(raw['art']) ||
          (raw['cell'] as int) < 0 ||
          (raw['cell'] as int) > 11) {
        throw const FormatException('Не найдена иллюстрация товара');
      }
    }
    final goalIds = <String>{};
    for (final goal in config['goals'] as List) {
      if (!goalIds.add(goal['id'] as String) || (goal['price'] as int) <= 0) {
        throw const FormatException('Некорректная цель');
      }
    }
    if (!goalIds.contains((config['goal'] as Map)['id'])) {
      throw const FormatException('Не найдена стартовая цель');
    }
    final question = config['question'] as Map;
    if ((question['correct'] as int) < 0 ||
        question['correct'] >= (question['answers'] as List).length) {
      throw const FormatException('Некорректный ответ задания');
    }
  }
}
