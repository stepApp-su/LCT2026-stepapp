/// Шкалы питомца — сытость, уход, настроение, уют — и их связь с деньгами
/// (ТЗ 2.5.9): купили — шкала выросла, пропустили обязательное — ночью
/// немного снизилась. Рамки, которые не обходит ни один вызов:
/// — ни одна шкала не опускается ниже пола и не достигает нуля;
/// — уют только растёт;
/// — низкая шкала ничего не блокирует: питомец лишь просит;
/// — у каждого изменения есть причина словами (ТЗ 2.5.10).
library;

import '../models/models.dart';
import '../ru_words.dart';
import '../text_template.dart';

/// Питомцу чего-то хочется: «Хочется перекусить».
final class PetWish {
  const PetWish({required this.stat, required this.text});

  final PetStat stat;
  final String text;
}

/// Как питомец выглядит сейчас. Запретов здесь нет: низкое состояние
/// меняет только позу и реплику, все функции приложения доступны.
final class PetStatus {
  const PetStatus({
    required this.state,
    required this.moodLevel,
    required this.moodLabel,
    required this.wishes,
  });

  final PetState state;
  final MoodLevel moodLevel;

  /// Подпись к индикатору настроения: цвет не единственный носитель смысла.
  final String moodLabel;

  /// Низкие шкалы в порядке PetStat.values.
  final List<PetWish> wishes;

  bool isLow(PetStat stat) => wishes.any((w) => w.stat == stat);
}

/// Итог одного действия: было, стало и почему.
final class PetStateUpdate {
  const PetStateUpdate({
    required this.before,
    required this.after,
    required this.changes,
  });

  final PetState before;
  final PetState after;
  final List<StatChange> changes;

  bool get isEmpty => changes.isEmpty;
}

final class PetStateService {
  PetStateService({
    required PetRules rules,
    PetState? initial,
    int dayNumber = 1,
    Map<String, int> actionsToday = const {},
    Iterable<StatChange> changesToday = const [],
    bool isDayClosed = false,
  })  : _rules = rules,
        _state = initial ?? rules.initialState,
        _day = dayNumber,
        _actionsToday = {...actionsToday},
        _changesToday = [...changesToday],
        _dayClosed = isDayClosed {
    if (dayNumber < 1) {
      throw ArgumentError.value(dayNumber, 'dayNumber', 'Дни нумеруются с 1');
    }
    for (final MapEntry(key: id, value: count) in actionsToday.entries) {
      if (count < 0) {
        throw ArgumentError.value(count, 'actionsToday «$id»', '≥ 0');
      }
    }
  }

  final PetRules _rules;
  final Map<String, int> _actionsToday;
  final List<StatChange> _changesToday;

  PetState _state;
  int _day;
  bool _dayClosed;

  PetRules get rules => _rules;
  PetState get state => _state;
  int get dayNumber => _day;
  bool get isDayClosed => _dayClosed;

  /// Всё, что случилось со шкалами за день, — для итогов дня.
  List<StatChange> get changesToday => List.unmodifiable(_changesToday);

  /// Сохраняется в профиле, чтобы перезапуск не обнулял дневные лимиты.
  Map<String, int> get actionsToday => Map.unmodifiable(_actionsToday);

  PetStatus get status {
    final mood = _rules.moodLevelOf(_state.mood);
    return PetStatus(
      state: _state,
      moodLevel: mood.level,
      moodLabel: mood.label,
      wishes: List.unmodifiable([
        for (final stat in PetStat.values)
          if (_rules.isLow(stat, _state.of(stat)))
            PetWish(stat: stat, text: _rules.low[stat]!.text)
      ]),
    );
  }

  int timesToday(String actionId) => _actionsToday[actionId] ?? 0;

  /// Сколько раз ещё сегодня действие что-то даст; null — без лимита.
  int? leftToday(String actionId) {
    final max = _requireAction(actionId).maxPerDay;
    if (max == null) return null;
    final left = max - timesToday(actionId);
    return left < 0 ? 0 : left;
  }

  // --- что двигает шкалы днём ---------------------------------------------

  /// Покупка меняет связанный показатель питомца (ТЗ 2.5.9). Причина —
  /// та же запись, что в журнале операций.
  PetStateUpdate applyPurchase(ShopItem item) =>
      _run(item.effects, _purchaseReason(item));

  /// Достигнутая цель остаётся в комнате и добавляет уюта навсегда.
  PetStateUpdate applyGoalReward(Goal goal) => _run(
      goal.rewardEffects,
      goal.reachedText.trim().isNotEmpty
          ? goal.reachedText
          : fillTemplate(_rules.texts.goalReached, {'title': goal.title}));

  /// Бесплатное действие: погладить, выполнить задание. Сверх дневного
  /// лимита шкалы не меняются, но и запрета нет.
  PetStateUpdate perform(String actionId) {
    final action = _requireAction(actionId);
    final max = action.maxPerDay;
    if (max != null && timesToday(actionId) >= max) return _nothing();
    _actionsToday[actionId] = timesToday(actionId) + 1;
    return _run(action.effects, action.reason);
  }

  /// Сценарные события и всё, у чего нет отдельного метода.
  PetStateUpdate applyEffects(
    Iterable<StateEffect> effects, {
    required String reasonText,
  }) {
    if (reasonText.trim().isEmpty) {
      throw ArgumentError.value(
          reasonText, 'reasonText', 'нужна причина для ребёнка');
    }
    return _run(effects, reasonText);
  }

  // --- ночь -----------------------------------------------------------------

  /// Питомца уложили спать. Пропущенные обязательные покупки снижают
  /// сытость и уход, настроение немного снижается само, вещи в комнате
  /// дают свою ежедневную радость. [boughtItemIds] — что реально куплено
  /// за день. Повторный вызов за тот же день ничего не делает:
  /// последствия не удваиваются.
  PetStateUpdate closeDay({
    required Iterable<String> boughtItemIds,
    Iterable<ShopItem> ownedItems = const [],
    PetStage stage = PetStage.egg,
  }) {
    if (_dayClosed) return _nothing();
    _dayClosed = true;

    final before = _state;
    final bought = boughtItemIds.toSet();
    final changes = <StatChange>[];
    for (final need in _rules.needsOn(_day, stage)) {
      if (!need.metBy(bought)) {
        changes.addAll(_applyAll(need.missedEffects, need.missedReason));
      }
    }
    changes.addAll(_applyAll(_rules.nightlyEffects, _rules.nightlyReason));
    final counted = <String>{};
    for (final item in ownedItems) {
      if (item.dailyEffects.isEmpty || !counted.add(item.id)) continue;
      changes.addAll(_applyAll(item.dailyEffects,
          fillTemplate(_rules.texts.dailyItem, {'title': item.title})));
    }
    return PetStateUpdate(
        before: before, after: _state, changes: List.unmodifiable(changes));
  }

  /// Новый день: дневные лимиты и список изменений начинаются заново.
  /// Повторный вызов с тем же днём ничего не сбрасывает, назад дни не идут.
  void startDay(int dayNumber) {
    if (dayNumber < _day) {
      throw ArgumentError.value(
          dayNumber, 'dayNumber', 'дни не идут назад, сейчас $_day');
    }
    if (dayNumber == _day) return;
    _day = dayNumber;
    _actionsToday.clear();
    _changesToday.clear();
    _dayClosed = false;
  }

  /// «Сытость +40», «Сытость −30», «Сытость: и так на максимуме».
  String describe(StatChange change) {
    final texts = _rules.texts;
    final stat = petStatLabel(change.stat);
    if (change.delta == 0) {
      return fillTemplate(
          change.nominal > 0 ? texts.atMax : texts.atFloor, {'stat': stat});
    }
    final delta = change.delta > 0 ? '+${change.delta}' : '−${-change.delta}';
    return fillTemplate(texts.change, {'stat': stat, 'delta': delta});
  }

  // --- внутреннее -------------------------------------------------------------

  PetAction _requireAction(String actionId) =>
      _rules.action(actionId) ??
      (throw ArgumentError.value(actionId, 'actionId', 'нет такого действия'));

  String _purchaseReason(ShopItem item) => item.diaryText.trim().isNotEmpty
      ? item.diaryText
      : fillTemplate(_rules.texts.purchase,
          {'title': item.title, 'titleAccusative': item.titleAccusative});

  PetStateUpdate _nothing() =>
      PetStateUpdate(before: _state, after: _state, changes: const []);

  PetStateUpdate _run(Iterable<StateEffect> effects, String reason) {
    final before = _state;
    final changes = _applyAll(effects, reason);
    return PetStateUpdate(before: before, after: _state, changes: changes);
  }

  List<StatChange> _applyAll(Iterable<StateEffect> effects, String reason) {
    final changes = <StatChange>[];
    for (final effect in effects) {
      if (effect.delta == 0) continue;
      // Уют — витрина накопленного: снижения не применяются никогда.
      if (effect.stat == PetStat.cozy && effect.delta < 0) continue;
      // Сначала проверяем изменение, потом меняем состояние:
      // шкала не сдвинется без записи о причине.
      final next = _state.apply(effect.stat, effect.delta);
      final change = StatChange.create(
        stat: effect.stat,
        before: _state.of(effect.stat),
        after: next.of(effect.stat),
        nominal: effect.delta,
        reasonText: reason,
      );
      _state = next;
      changes.add(change);
      _changesToday.add(change);
    }
    return List.unmodifiable(changes);
  }
}
