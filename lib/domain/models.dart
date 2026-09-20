/// Модели предметной области. Чистый Dart, без package:flutter.
class Task {
  final String id;
  final String title;
  final String description;
  final int reward;
  final String category;

  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.reward,
    required this.category,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        reward: json['reward'] as int,
        category: json['category'] as String,
      );
}

class ShopItem {
  final String id;
  final String title;
  final int cost;
  final String icon;

  const ShopItem({
    required this.id,
    required this.title,
    required this.cost,
    required this.icon,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
        id: json['id'] as String,
        title: json['title'] as String,
        cost: json['cost'] as int,
        icon: json['icon'] as String,
      );
}

class Goal {
  final String id;
  final String title;
  final int targetAmount;

  const Goal({
    required this.id,
    required this.title,
    required this.targetAmount,
  });

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
        id: json['id'] as String,
        title: json['title'] as String,
        targetAmount: json['targetAmount'] as int,
      );
}

class Rank {
  final String id;
  final String title;
  final int minPoints;

  const Rank({
    required this.id,
    required this.title,
    required this.minPoints,
  });

  factory Rank.fromJson(Map<String, dynamic> json) => Rank(
        id: json['id'] as String,
        title: json['title'] as String,
        minPoints: json['minPoints'] as int,
      );
}

class FinniLine {
  final String id;
  final String trigger;
  final String text;

  const FinniLine({
    required this.id,
    required this.trigger,
    required this.text,
  });

  factory FinniLine.fromJson(Map<String, dynamic> json) => FinniLine(
        id: json['id'] as String,
        trigger: json['trigger'] as String,
        text: json['text'] as String,
      );
}
