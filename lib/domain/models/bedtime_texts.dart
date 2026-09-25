enum BedtimeTodo { plan, needs, task, event }

final class BedtimeTexts {
  const BedtimeTexts._({
    required this.ready,
    required this.todos,
    required this.reminder,
    required this.shortOfMoney,
    required this.goShopping,
    required this.sleepAnyway,
  });

  factory BedtimeTexts.create({
    required String ready,
    required Map<BedtimeTodo, String> todos,
    required String reminder,
    required String shortOfMoney,
    required String goShopping,
    required String sleepAnyway,
  }) {
    _requireText(ready, 'ready');
    for (final todo in BedtimeTodo.values) {
      _requireText(todos[todo] ?? '', 'todo.${todo.name}');
    }
    _requireItems(todos[BedtimeTodo.needs]!, 'todo.needs');
    _requireItems(reminder, 'reminder');
    _requireItems(shortOfMoney, 'shortOfMoney');
    _requireText(goShopping, 'goShopping');
    _requireText(sleepAnyway, 'sleepAnyway');
    return BedtimeTexts._(
      ready: ready,
      todos: Map.unmodifiable(todos),
      reminder: reminder,
      shortOfMoney: shortOfMoney,
      goShopping: goShopping,
      sleepAnyway: sleepAnyway,
    );
  }

  factory BedtimeTexts.fromJson(Map<String, Object?> json) =>
      BedtimeTexts.create(
        ready: json['ready'] as String,
        todos: {
          for (final e in (json['todo'] as Map).entries)
            BedtimeTodo.values.byName(e.key as String): e.value as String
        },
        reminder: json['reminder'] as String,
        shortOfMoney: json['shortOfMoney'] as String,
        goShopping: json['goShopping'] as String,
        sleepAnyway: json['sleepAnyway'] as String,
      );

  final String ready;
  final Map<BedtimeTodo, String> todos;
  final String reminder;
  final String shortOfMoney;
  final String goShopping;
  final String sleepAnyway;
}

void _requireText(String text, String name) {
  if (text.trim().isEmpty) {
    throw ArgumentError.value(
        text, 'bedtime.$name', 'текст не может быть пустым');
  }
}

void _requireItems(String text, String name) {
  _requireText(text, name);
  if (!text.contains('{items}')) {
    throw ArgumentError.value(text, 'bedtime.$name', 'нужен {items}');
  }
}
