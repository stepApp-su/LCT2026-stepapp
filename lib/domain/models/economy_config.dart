import 'growth_rules.dart';
import 'pet_rules.dart';

final class EconomyConfig {
  const EconomyConfig._({
    required this.schemaVersion,
    required this.pet,
    required this.growth,
  });

  factory EconomyConfig.create({
    int schemaVersion = 1,
    required PetRules pet,
    required GrowthRules growth,
  }) {
    if (schemaVersion < 1) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion', '≥ 1');
    }
    return EconomyConfig._(
        schemaVersion: schemaVersion, pet: pet, growth: growth);
  }

  factory EconomyConfig.fromJson(Map<String, Object?> json) =>
      EconomyConfig.create(
        schemaVersion: (json['schemaVersion'] ?? 1) as int,
        pet: PetRules.fromJson((json['pet'] as Map).cast<String, Object?>()),
        growth: GrowthRules.fromJson(
            (json['growth'] as Map).cast<String, Object?>()),
      );

  final int schemaVersion;
  final PetRules pet;
  final GrowthRules growth;
}
