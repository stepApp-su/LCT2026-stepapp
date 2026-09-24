/// Параметры экономики из assets/content/economy.json. Балансировка — правка
/// JSON, а не кода: учебный контент и параметры отделены от интерфейса
/// (ТЗ 3.2).
library;

import 'pet_rules.dart';

final class EconomyConfig {
  const EconomyConfig._({required this.schemaVersion, required this.pet});

  factory EconomyConfig.create({int schemaVersion = 1, required PetRules pet}) {
    if (schemaVersion < 1) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion', '≥ 1');
    }
    return EconomyConfig._(schemaVersion: schemaVersion, pet: pet);
  }

  factory EconomyConfig.fromJson(Map<String, Object?> json) =>
      EconomyConfig.create(
        schemaVersion: (json['schemaVersion'] ?? 1) as int,
        pet: PetRules.fromJson((json['pet'] as Map).cast<String, Object?>()),
      );

  final int schemaVersion;

  /// Шкалы питомца: что их двигает и где у них пороги.
  final PetRules pet;
}
