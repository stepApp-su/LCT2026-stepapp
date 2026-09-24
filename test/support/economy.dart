import 'dart:convert';
import 'dart:io';

Map<String, Object?> economyParamsJson() {
  final raw = (jsonDecode(File('assets/content/economy.json').readAsStringSync())
          as Map)
      .cast<String, Object?>();
  return {
    for (final key in const [
      'day',
      'plan',
      'tasks',
      'events',
      'cooldownsMinutes',
      'cozyLevels',
    ])
      key: raw[key],
  };
}
