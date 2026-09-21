/// Питомец: шкалы и взросление. У шкал есть пол — ниже не сохранить.
library;

enum PetStat { satiety, care, mood, cozy }

enum PetStage { egg, baby, teen, adult }

final class PetState {
  const PetState._({
    required this.satiety,
    required this.care,
    required this.mood,
    required this.cozy,
  });

  static const int satietyFloor = 20;
  static const int careFloor = 20;
  static const int moodFloor = 30;
  static const int cap = 100;

  factory PetState.create({
    required int satiety,
    required int care,
    required int mood,
    required int cozy,
  }) =>
      PetState._(
        satiety: satiety.clamp(satietyFloor, cap),
        care: care.clamp(careFloor, cap),
        mood: mood.clamp(moodFloor, cap),
        cozy: cozy < 0 ? 0 : cozy,
      );

  factory PetState.initial() =>
      PetState.create(satiety: 80, care: 80, mood: 80, cozy: 0);

  final int satiety;
  final int care;
  final int mood;

  final int cozy;

  int of(PetStat stat) => switch (stat) {
        PetStat.satiety => satiety,
        PetStat.care => care,
        PetStat.mood => mood,
        PetStat.cozy => cozy,
      };

  PetState apply(PetStat stat, int delta) => PetState.create(
        satiety: stat == PetStat.satiety ? satiety + delta : satiety,
        care: stat == PetStat.care ? care + delta : care,
        mood: stat == PetStat.mood ? mood + delta : mood,
        cozy: stat == PetStat.cozy ? cozy + delta : cozy,
      );

  Map<String, Object?> toJson() =>
      {'satiety': satiety, 'care': care, 'mood': mood, 'cozy': cozy};

  factory PetState.fromJson(Map<String, Object?> json) => PetState.create(
        satiety: json['satiety'] as int,
        care: json['care'] as int,
        mood: json['mood'] as int,
        cozy: json['cozy'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is PetState &&
      other.satiety == satiety &&
      other.care == care &&
      other.mood == mood &&
      other.cozy == cozy;

  @override
  int get hashCode => Object.hash(satiety, care, mood, cozy);
}

final class PetProgress {
  const PetProgress._({
    required this.growthPoints,
    required this.stage,
    required this.earnedTitles,
    required this.currentTitleId,
  });

  factory PetProgress.create({
    required int growthPoints,
    required PetStage stage,
    List<String> earnedTitles = const [],
    String currentTitleId = '',
  }) {
    if (growthPoints < 0) {
      throw ArgumentError.value(growthPoints, 'growthPoints', '>= 0');
    }
    return PetProgress._(
      growthPoints: growthPoints,
      stage: stage,
      earnedTitles: List.unmodifiable(earnedTitles),
      currentTitleId: currentTitleId,
    );
  }

  factory PetProgress.initial() =>
      PetProgress.create(growthPoints: 0, stage: PetStage.egg);

  final int growthPoints;
  final PetStage stage;

  final List<String> earnedTitles;
  final String currentTitleId;

  Map<String, Object?> toJson() => {
        'growthPoints': growthPoints,
        'stage': stage.name,
        'earnedTitles': earnedTitles,
        'currentTitleId': currentTitleId,
      };

  factory PetProgress.fromJson(Map<String, Object?> json) => PetProgress.create(
        growthPoints: json['growthPoints'] as int,
        stage: PetStage.values.byName(json['stage'] as String),
        earnedTitles:
            (json['earnedTitles'] as List).cast<String>(),
        currentTitleId: json['currentTitleId'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is PetProgress &&
      other.growthPoints == growthPoints &&
      other.stage == stage &&
      other.currentTitleId == currentTitleId &&
      _listEq(other.earnedTitles, earnedTitles);

  @override
  int get hashCode =>
      Object.hash(growthPoints, stage, currentTitleId, Object.hashAll(earnedTitles));
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
