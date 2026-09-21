/// Единый источник времени. Прямой DateTime.now() — только внутри RealClock,
/// остальной код ходит сюда (демо-режим подменяет реализацию целиком).
abstract interface class GameClock {
  DateTime now();

  /// Кулдаун по ключу (petChores и т.п.), мс.
  int cooldownMs(String key);

  /// Наступили ли новые календарные сутки после [last].
  bool isNewCalendarDay(DateTime last);
}

/// Обычный режим: реальные часы, кулдауны из конфига.
final class RealClock implements GameClock {
  RealClock({Map<String, Duration> cooldowns = defaultCooldowns})
      : _cooldowns = Map.unmodifiable(cooldowns);

  static const Map<String, Duration> defaultCooldowns = {
    'petChores': Duration(hours: 3),
    'dailyTask': Duration(hours: 24),
  };

  final Map<String, Duration> _cooldowns;

  @override
  DateTime now() => DateTime.now();

  @override
  int cooldownMs(String key) => _cooldowns[key]?.inMilliseconds ?? 0;

  // Сравниваем календарные даты, а не разницу времени: перевод часов
  // назад не делает день «новым», повторного бонуса за вход не будет.
  @override
  bool isNewCalendarDay(DateTime last) => _isCalendarDayAfter(now(), last);
}

/// Демо-режим: кулдауны нулевые, сутки проходят по запросу.
final class DemoClock implements GameClock {
  DemoClock({DateTime? start}) : _current = start ?? DateTime(2026, 1, 1, 9, 0);

  DateTime _current;

  void advanceDay([int days = 1]) {
    _current = _current.add(Duration(days: days));
  }

  void advance(Duration step) {
    _current = _current.add(step);
  }

  @override
  DateTime now() => _current;

  @override
  int cooldownMs(String key) => 0;

  @override
  bool isNewCalendarDay(DateTime last) => true;
}

bool _isCalendarDayAfter(DateTime now, DateTime last) {
  final today = DateTime(now.year, now.month, now.day);
  final lastDay = DateTime(last.year, last.month, last.day);
  return today.isAfter(lastDay);
}
