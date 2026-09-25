import '../models/models.dart';

final class DayEventPicker {
  const DayEventPicker({required this.schedule, required this.catalog});

  final EventSchedule schedule;
  final EventCatalog catalog;

  GameEventDef? pick(int day, PetStage Function(int day) stageOn) {
    if (!schedule.isEventDay(day)) return null;
    final issued = <int, String>{};
    GameEventDef? chosen;
    var turn = 0;
    for (final eventDay in schedule.eventDaysUpTo(day)) {
      chosen = _choose(turn++, eventDay, stageOn(eventDay), issued);
      if (chosen != null) issued[eventDay] = chosen.id;
    }
    return chosen;
  }

  bool isSupported(GameEventDef event) => event.priceDeltas.isEmpty;

  DayEvent toDayEvent(GameEventDef event) => DayEvent.create(
        id: event.id,
        title: event.title,
        cost: event.options.fold(0, (most, o) => o.cost > most ? o.cost : most),
      );

  GameEventDef? _choose(
    int turn,
    int day,
    PetStage stage,
    Map<int, String> issued,
  ) {
    final order = catalog.settings.sequence;
    for (var shift = 0; shift < order.length; shift++) {
      final event = catalog.byId(order[(turn + shift) % order.length]);
      if (event == null ||
          !event.isAvailableAt(stage) ||
          !isSupported(event) ||
          _isResting(event.id, day, issued)) {
        continue;
      }
      return event;
    }
    return null;
  }

  bool _isResting(String eventId, int day, Map<int, String> issued) =>
      issued.entries.any((e) =>
          e.value == eventId && day - e.key <= catalog.settings.cooldownDays);
}
