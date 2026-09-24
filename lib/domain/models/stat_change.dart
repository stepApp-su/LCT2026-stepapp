/// Изменение одной шкалы питомца вместе с причиной. Ребёнок видит не
/// «Сытость 50», а «Сытость −30: сегодня не купили еду» (ТЗ 2.5.10).
library;

import 'pet.dart';

final class StatChange {
  const StatChange._({
    required this.stat,
    required this.before,
    required this.after,
    required this.nominal,
    required this.reasonText,
  });

  factory StatChange.create({
    required PetStat stat,
    required int before,
    required int after,
    required int nominal,
    required String reasonText,
  }) {
    if (reasonText.trim().isEmpty) {
      throw ArgumentError.value(
          reasonText, 'reasonText', 'нужна причина для ребёнка');
    }
    if (nominal == 0) {
      throw ArgumentError.value(
          nominal, 'nominal', 'изменение на 0 — не изменение');
    }
    if (before < 0 || after < 0) {
      throw ArgumentError('шкала не бывает меньше нуля: $before → $after');
    }
    if (stat == PetStat.cozy && nominal < 0) {
      throw ArgumentError.value(nominal, 'nominal', 'уют только растёт');
    }
    // Пол и потолок могут только урезать изменение, но не развернуть его.
    final delta = after - before;
    if (delta != 0 &&
        (delta.sign != nominal.sign || delta.abs() > nominal.abs())) {
      throw ArgumentError('$before → $after не сходится с изменением $nominal');
    }
    return StatChange._(
      stat: stat,
      before: before,
      after: after,
      nominal: nominal,
      reasonText: reasonText.trim(),
    );
  }

  final PetStat stat;
  final int before;
  final int after;

  /// Сколько должно было измениться. Если шкала упёрлась в пол или
  /// потолок, фактическое изменение меньше: «+40» к полной сытости — это +0.
  final int nominal;

  final String reasonText;

  /// Фактическое изменение — его и показываем ребёнку.
  int get delta => after - before;

  /// Шкала упёрлась в пол или потолок.
  bool get isLimited => delta != nominal;

  Map<String, Object?> toJson() => {
        'stat': stat.name,
        'before': before,
        'after': after,
        'nominal': nominal,
        'reasonText': reasonText,
      };

  factory StatChange.fromJson(Map<String, Object?> json) => StatChange.create(
        stat: PetStat.values.byName(json['stat'] as String),
        before: json['before'] as int,
        after: json['after'] as int,
        nominal: json['nominal'] as int,
        reasonText: json['reasonText'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is StatChange &&
      other.stat == stat &&
      other.before == before &&
      other.after == after &&
      other.nominal == nominal &&
      other.reasonText == reasonText;

  @override
  int get hashCode => Object.hash(stat, before, after, nominal, reasonText);
}
