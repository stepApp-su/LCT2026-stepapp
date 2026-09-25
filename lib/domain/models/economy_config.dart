import 'economy_params.dart';
import 'growth_rules.dart';
import 'pet_rules.dart';

final class EconomyConfig {
  const EconomyConfig._({
    required this.schemaVersion,
    required this.pet,
    required this.growth,
    required this.params,
  });

  factory EconomyConfig.create({
    int schemaVersion = 1,
    required PetRules pet,
    required GrowthRules growth,
    required EconomyParams params,
  }) {
    if (schemaVersion < 1) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion', '≥ 1');
    }
    return EconomyConfig._(
        schemaVersion: schemaVersion,
        pet: pet,
        growth: growth,
        params: params);
  }

  factory EconomyConfig.fromJson(Map<String, Object?> json) =>
      EconomyConfig.create(
        schemaVersion: (json['schemaVersion'] ?? 1) as int,
        pet: PetRules.fromJson((json['pet'] as Map).cast<String, Object?>()),
        growth: GrowthRules.fromJson(
            (json['growth'] as Map).cast<String, Object?>()),
        params: EconomyParams.fromJson(json),
      );

  final int schemaVersion;
  final PetRules pet;
  final GrowthRules growth;
  final EconomyParams params;
}
