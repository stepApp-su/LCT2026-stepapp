import '../models/pet.dart';
import '../models/pet_rules.dart';

/// Cozy starts at zero and is never treated as an unmet care need.
PetStat? currentPetNeed(PetState state, PetRules rules) {
  if (rules.isLow(PetStat.satiety, state.satiety)) return PetStat.satiety;
  if (rules.isLow(PetStat.care, state.care)) return PetStat.care;
  if (rules.moodLevelOf(state.mood).level ==
      rules.moodLevelOf(PetState.moodFloor).level) {
    return PetStat.mood;
  }
  return null;
}
