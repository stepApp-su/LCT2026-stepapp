/// Профиль и сводка дня. Персональных данных тут нет и быть не должно:
/// только игровые поля, вместо возраста — переключатель сложности.
library;

import 'economy.dart';
import 'pet.dart';

/// Итог дня: план против факта + очки роста.
final class DaySummary {
  const DaySummary._({
    required this.dayNumber,
    required this.plannedMandatory,
    required this.plannedOptional,
    required this.plannedSavings,
    required this.actualMandatory,
    required this.actualOptional,
    required this.actualSavings,
    required this.growthPoints,
  });

  factory DaySummary.create({
    required int dayNumber,
    required int plannedMandatory,
    required int plannedOptional,
    required int plannedSavings,
    required int actualMandatory,
    required int actualOptional,
    required int actualSavings,
    required int growthPoints,
  }) {
    final values = [
      dayNumber, plannedMandatory, plannedOptional, plannedSavings,
      actualMandatory, actualOptional, actualSavings, growthPoints,
    ];
    if (values.any((v) => v < 0)) {
      throw ArgumentError('в сводке дня всё >= 0: $values');
    }
    return DaySummary._(
      dayNumber: dayNumber,
      plannedMandatory: plannedMandatory,
      plannedOptional: plannedOptional,
      plannedSavings: plannedSavings,
      actualMandatory: actualMandatory,
      actualOptional: actualOptional,
      actualSavings: actualSavings,
      growthPoints: growthPoints,
    );
  }

  final int dayNumber;
  final int plannedMandatory;
  final int plannedOptional;
  final int plannedSavings;
  final int actualMandatory;
  final int actualOptional;
  final int actualSavings;
  final int growthPoints;

  Map<String, Object?> toJson() => {
        'dayNumber': dayNumber,
        'plannedMandatory': plannedMandatory,
        'plannedOptional': plannedOptional,
        'plannedSavings': plannedSavings,
        'actualMandatory': actualMandatory,
        'actualOptional': actualOptional,
        'actualSavings': actualSavings,
        'growthPoints': growthPoints,
      };

  factory DaySummary.fromJson(Map<String, Object?> json) => DaySummary.create(
        dayNumber: json['dayNumber'] as int,
        plannedMandatory: json['plannedMandatory'] as int,
        plannedOptional: json['plannedOptional'] as int,
        plannedSavings: json['plannedSavings'] as int,
        actualMandatory: json['actualMandatory'] as int,
        actualOptional: json['actualOptional'] as int,
        actualSavings: json['actualSavings'] as int,
        growthPoints: json['growthPoints'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is DaySummary &&
      other.dayNumber == dayNumber &&
      other.plannedMandatory == plannedMandatory &&
      other.plannedOptional == plannedOptional &&
      other.plannedSavings == plannedSavings &&
      other.actualMandatory == actualMandatory &&
      other.actualOptional == actualOptional &&
      other.actualSavings == actualSavings &&
      other.growthPoints == growthPoints;

  @override
  int get hashCode => Object.hash(dayNumber, plannedMandatory, plannedOptional,
      plannedSavings, actualMandatory, actualOptional, actualSavings, growthPoints);
}

/// Всё, что сохраняется на устройстве.
final class Profile {
  const Profile._({
    required this.petName,
    required this.species,
    required this.palette,
    required this.simpleMode,
    required this.wallet,
    required this.state,
    required this.progress,
    required this.goalId,
    required this.goals,
    required this.currentDay,
    required this.ownedItems,
    required this.equipped,
    required this.completedTasks,
    required this.history,
  });

  factory Profile.create({
    required String petName,
    required String species,
    required int palette,
    bool simpleMode = true,
    required Wallet wallet,
    required PetState state,
    required PetProgress progress,
    String? goalId,
    List<Goal> goals = const [],
    required GameDay currentDay,
    List<String> ownedItems = const [],
    Map<String, String?> equipped = const {},
    List<String> completedTasks = const [],
    List<DaySummary> history = const [],
  }) {
    if (palette < 0) {
      throw ArgumentError.value(palette, 'palette', 'Индекс палитры ≥ 0');
    }
    return Profile._(
      petName: petName,
      species: species,
      palette: palette,
      simpleMode: simpleMode,
      wallet: wallet,
      state: state,
      progress: progress,
      goalId: goalId,
      goals: List.unmodifiable(goals),
      currentDay: currentDay,
      ownedItems: List.unmodifiable(ownedItems),
      equipped: Map.unmodifiable(equipped),
      completedTasks: List.unmodifiable(completedTasks),
      history: List.unmodifiable(history),
    );
  }

  /// Имя питомца (не ребёнка).
  final String petName;
  final String species;
  final int palette;

  /// true — «попроще», false — «посложнее».
  final bool simpleMode;

  final Wallet wallet;
  final PetState state;
  final PetProgress progress;

  final String? goalId;
  final List<Goal> goals;
  final GameDay currentDay;

  final List<String> ownedItems;
  final Map<String, String?> equipped;
  final List<String> completedTasks;
  final List<DaySummary> history;

  Profile copyWith({
    String? petName,
    int? palette,
    bool? simpleMode,
    Wallet? wallet,
    PetState? state,
    PetProgress? progress,
    String? goalId,
    List<Goal>? goals,
    GameDay? currentDay,
    List<String>? ownedItems,
    Map<String, String?>? equipped,
    List<String>? completedTasks,
    List<DaySummary>? history,
  }) =>
      Profile.create(
        petName: petName ?? this.petName,
        species: species,
        palette: palette ?? this.palette,
        simpleMode: simpleMode ?? this.simpleMode,
        wallet: wallet ?? this.wallet,
        state: state ?? this.state,
        progress: progress ?? this.progress,
        goalId: goalId ?? this.goalId,
        goals: goals ?? this.goals,
        currentDay: currentDay ?? this.currentDay,
        ownedItems: ownedItems ?? this.ownedItems,
        equipped: equipped ?? this.equipped,
        completedTasks: completedTasks ?? this.completedTasks,
        history: history ?? this.history,
      );

  Map<String, Object?> toJson() => {
        'petName': petName,
        'species': species,
        'palette': palette,
        'simpleMode': simpleMode,
        'wallet': wallet.toJson(),
        'state': state.toJson(),
        'progress': progress.toJson(),
        'goalId': goalId,
        'goals': [for (final g in goals) g.toJson()],
        'currentDay': currentDay.toJson(),
        'ownedItems': ownedItems,
        'equipped': equipped,
        'completedTasks': completedTasks,
        'history': [for (final h in history) h.toJson()],
      };

  factory Profile.fromJson(Map<String, Object?> json) => Profile.create(
        petName: json['petName'] as String,
        species: json['species'] as String,
        palette: json['palette'] as int,
        simpleMode: json['simpleMode'] as bool,
        wallet: Wallet.fromJson((json['wallet'] as Map).cast<String, Object?>()),
        state: PetState.fromJson((json['state'] as Map).cast<String, Object?>()),
        progress: PetProgress.fromJson(
            (json['progress'] as Map).cast<String, Object?>()),
        goalId: json['goalId'] as String?,
        goals: [
          for (final g in (json['goals'] as List))
            Goal.fromJson((g as Map).cast<String, Object?>())
        ],
        currentDay: GameDay.fromJson(
            (json['currentDay'] as Map).cast<String, Object?>()),
        ownedItems: (json['ownedItems'] as List).cast<String>(),
        equipped: (json['equipped'] as Map).cast<String, String?>(),
        completedTasks: (json['completedTasks'] as List).cast<String>(),
        history: [
          for (final h in (json['history'] as List))
            DaySummary.fromJson((h as Map).cast<String, Object?>())
        ],
      );
}
